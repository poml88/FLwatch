//
//  Libre3StateStore.swift
//  FLwatch
//
//  Bridges the LibreCRKit `Libre3SensorState` (phone-only) and FLwatch's split
//  persistence: the secret BLE PIN → keychain (`Libre3PINStore`), the non-secret
//  metadata → app group (`SharedData`). Lives in the iOS-only `Libre3BLE/`
//  folder because it references LibreCRKit types, which are linked to the phone
//  target only (PLAN §9, R8).
//

#if os(iOS)
import Foundation
import LibreCRKit

enum Libre3StateStore {

    /// Receiver ID sent in the NFC command.
    ///
    /// For **takeover / parallel join** of a sensor the Libre 3 app activated,
    /// the sensor only accepts the receiver ID that matches the activating
    /// LibreView account: `FNV-32a(lowercased patient UUID)`. A mismatched
    /// (e.g. random) ID is rejected with NFC error `0xB1`. So when a LibreView
    /// patient ID is set we derive from it deterministically.
    ///
    /// For **fresh activation** (no patient ID), FLwatch becomes the receiver
    /// itself, so an accountless ID is fine — generate once and reuse.
    ///
    /// `Libre3ReceiverID(accountlessUniqueID:)` is the same FNV-32a the Libre 3
    /// app / DiaBLE use, so feeding it the patient UUID yields the identical ID.
    static func receiverID() -> Libre3ReceiverID {
        let patientID = SharedData.libre3LibreViewPatientId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !patientID.isEmpty {
            let derived = receiverID(
                forAccountID: patientID,
                derivation: SharedData.libre3ReceiverIDDerivation
            )
            SharedData.libre3ReceiverIDHex = derived.littleEndianHex
            return derived
        }

        let hex = SharedData.libre3ReceiverIDHex
        if !hex.isEmpty, let existing = try? Libre3ReceiverID(littleEndianHex: hex) {
            return existing
        }
        let generated = Libre3ReceiverID(accountlessUniqueID: UUID().uuidString)
        SharedData.libre3ReceiverIDHex = generated.littleEndianHex
        return generated
    }

    /// Account ID → receiver ID under `derivation`. The single place this mapping
    /// happens, so the value the diagnostic UI displays is exactly the one the
    /// next scan puts on the wire.
    ///
    /// Temporary (branch `getLbAReceiverID`) — see `Libre3ReceiverIDDerivation`.
    /// `.classic` keeps calling LibreCRKit's FNV on the lowercased ID, unchanged
    /// from what shipped; the reverse-engineered variants take the ID as entered,
    /// since that derivation has no lowercasing and case changes the result.
    static func receiverID(
        forAccountID accountID: String,
        derivation: Libre3ReceiverIDDerivation
    ) -> Libre3ReceiverID {
        if let value = derivation.newAppValue(forAccountID: accountID) {
            return Libre3ReceiverID(value)
        }
        return Libre3ReceiverID(accountlessUniqueID: accountID.lowercased())
    }

    /// Formatted preview of the above for the diagnostic UI, so the view layer
    /// needn't import LibreCRKit. Nil when `accountID` is blank — fresh
    /// activation then falls back to a generated ID.
    ///
    /// Temporary (branch `getLbAReceiverID`).
    static func receiverIDPreview(
        forAccountID accountID: String,
        derivation: Libre3ReceiverIDDerivation
    ) -> (value: UInt32, display: String, note: String?)? {
        let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let id = receiverID(forAccountID: trimmed, derivation: derivation)
        // The UUID-byte variants silently resolve to Classic on an Account ID
        // that isn't a UUID; say so rather than showing a number the label
        // doesn't match.
        let note = derivation.needsUUID && UUID(uuidString: trimmed) == nil
            ? "not a UUID — using Classic"
            : nil
        return (id.value, id.displayString, note)
    }

    /// Persist a successful NFC pair: PIN → keychain, the rest → app group.
    static func save(
        state: Libre3SensorState,
        mode: Libre3Mode,
        patchInfo: Libre3NFCPatchInfo
    ) throws {
        let serial = state.serialNumber ?? patchInfo.serialNumber

        try Libre3PINStore.save(state.blePIN)
        // A fresh NFC pair establishes new authorization material. Force the
        // next BLE connect through the full handshake, not a stale cached path.
        try? Libre3PINStore.deleteReconnectKey()
        // Every NFC re-pair must rediscover and authenticate the BLE peripheral.
        SharedData.libre3PeripheralUUID = ""
        SharedData.libre3Serial = serial
        SharedData.libre3BleAddress = state.bleAddress ?? ""
        // Firmware + lifecycle/model fields come straight from LibreCRKit's
        // patch-info parser (offsets fixed upstream in d96c914 to match what we
        // validated against DiaBLE/Juggluco). Persisted so reconnect needs no
        // NFC re-scan.
        SharedData.libre3FirmwareVersion = patchInfo.firmwareVersion
        SharedData.libre3WarmupMinutes = Int(patchInfo.warmupMinutes)
        SharedData.libre3WearDurationMinutes = Int(patchInfo.wearDurationMinutes)
        SharedData.libre3Generation = Int(patchInfo.generation)
        SharedData.libre3ProductType = Int(patchInfo.productType)
        if let receiverID = state.receiverID {
            SharedData.libre3ReceiverIDHex = receiverID.littleEndianHex
        }
        SharedData.libre3Mode = mode
    }

    /// Reassemble the persisted sensor state (app-group metadata + keychain PIN)
    /// for reconnect in Phase 3+. `nil` when nothing is paired or the PIN is
    /// missing/corrupt.
    static func loadState() -> Libre3SensorState? {
        guard SharedData.libre3SensorIsPaired,
              let pin = (try? Libre3PINStore.read()) ?? nil else {
            return nil
        }
        let receiverID = try? Libre3ReceiverID(littleEndianHex: SharedData.libre3ReceiverIDHex)
        return try? Libre3SensorState(
            serialNumber: SharedData.libre3Serial,
            blePIN: pin,
            bleAddress: SharedData.libre3BleAddress.isEmpty ? nil : SharedData.libre3BleAddress,
            receiverID: receiverID,
            source: "FLwatch persisted state"
        )
    }

    /// Forget the paired sensor (disconnect). Deliberately keeps the generated
    /// receiver ID so a re-pair reuses the same identity.
    static func clear() {
        try? Libre3PINStore.delete()
        try? Libre3PINStore.deleteReconnectKey()
        SharedData.libre3Serial = ""
        SharedData.libre3BleAddress = ""
        SharedData.libre3FirmwareVersion = ""
        SharedData.libre3Mode = nil
        SharedData.libre3PeripheralUUID = ""
        SharedData.libre3WearDurationMinutes = 0
        SharedData.libre3Generation = 0
        SharedData.libre3ProductType = 0
    }

    static var isPaired: Bool { SharedData.libre3SensorIsPaired }

    // MARK: - Cached-reconnect key (Phase-5 raw key)

    /// Persist the 16-byte Phase-5 raw key established by a successful full
    /// handshake. `runCachedReconnectHandshake` reuses this authorization key
    /// on every later connection; cached reconnects do not replace it with their
    /// fresh Phase-6 data-plane keys.
    static func saveReconnectKey(_ rawKey: Data) {
        try? Libre3PINStore.saveReconnectKey(rawKey)
    }

    /// The persisted cached-reconnect key, or `nil` if a full handshake hasn't
    /// completed since pairing or the app predates this stored material. Only
    /// this no-key establishment path runs full authorization.
    static func loadReconnectKey() -> Data? {
        (try? Libre3PINStore.readReconnectKey()) ?? nil
    }

    /// SensorType derived from the persisted patch-info model fields
    /// (productType / generation), so the rest of FLwatch shows the right
    /// sensor name and `isALibre` behaviour, mirroring how DiaBLE/Juggluco read
    /// the patch frame.
    static var sensorType: SensorType {
        switch SharedData.libre3ProductType {
        case 9: return .lingo
        default: return SharedData.libre3Generation >= 1 ? .libre3Plus : .libre3
        }
    }

    /// Stamp the resolved `SensorType` into the shared settings store, like the
    /// Dexcom/LibreLinkUp providers do on connect. Only writes when it actually
    /// changes, so it never churns the persisted snapshot.
    @MainActor
    static func stampSensorType() {
        let type = sensorType
        guard SensorSettingsStore.shared.sensorType != type else { return }
        _ = SensorSettingsStore.shared.updateSensorType(type)
    }
}
#endif
