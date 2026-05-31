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
            .lowercased()
        if !patientID.isEmpty {
            let derived = Libre3ReceiverID(accountlessUniqueID: patientID)
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

    /// Persist a successful NFC pair: PIN → keychain, the rest → app group.
    static func save(
        state: Libre3SensorState,
        mode: Libre3Mode,
        patchInfo: Libre3NFCPatchInfo
    ) throws {
        try Libre3PINStore.save(state.blePIN)
        SharedData.libre3Serial = state.serialNumber ?? patchInfo.serialNumber
        SharedData.libre3BleAddress = state.bleAddress ?? ""
        // Firmware parsed from the DiaBLE/Juggluco layout. (LibreCRKit's
        // `firmwareVersion` sits at a different offset — it's fresh-activation-
        // focused and never consumes that field; fall back to it if our parse
        // fails.)
        SharedData.libre3FirmwareVersion = Libre3PatchFields(raw: patchInfo.raw)?.firmware
            ?? patchInfo.firmwareVersion
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
        SharedData.libre3Serial = ""
        SharedData.libre3BleAddress = ""
        SharedData.libre3FirmwareVersion = ""
        SharedData.libre3Mode = nil
    }

    static var isPaired: Bool { SharedData.libre3SensorIsPaired }
}
#endif
