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
import OSLog
import StoreKit

enum Libre3StateStoreError: Error {
    /// The installation receiver ID couldn't be written to the keychain, or the
    /// write didn't survive a read-back. Pairing must not continue: a sensor
    /// activated under an identity we can't reproduce is unreachable forever.
    case installationReceiverIDNotPersisted

    /// A vendor app is selected, but no receiver ID could be derived for it:
    /// either no Account ID is stored, or `usesLibreViewAccount` and `derivation`
    /// disagree. Both are prevented upstream — by `scanBlockedReason` in the
    /// connect view and by an invariant test respectively — so this exists to
    /// stop the fall-through rather than to be reached. Pairing under FLwatch's
    /// own installation identity when the user named a vendor app would write an
    /// ID that app can never reproduce, stranding the sensor for its whole wear.
    case invalidReceiverIDConfiguration
}

/// The LibreCRKit fold this app applies to a LibreView Account ID, or nil when it
/// derives nothing from an account — `.flwatchOnly` presents the installation
/// identity instead.
///
/// Lives here rather than on the type itself: `Libre3ActivatingApp` is shared
/// code, compiled into the watch and widget targets, which don't link LibreCRKit
/// and so can't name `Libre3ReceiverID.Derivation`. Exhaustive on purpose, and
/// must mirror `usesLibreViewAccount` — see the note there.
extension Libre3ActivatingApp {
    var derivation: Libre3ReceiverID.Derivation? {
        switch self {
        case .freeStyleLibre3:
            return .freeStyleLibre3
        case .libreByAbbott:
            return .libreByAbbott
        case .flwatchOnly:
            return nil
        }
    }
}

enum Libre3StateStore {

    /// Receiver ID sent in the NFC command.
    ///
    /// For **takeover / parallel join** of a sensor a vendor app activated, the
    /// sensor only accepts the receiver ID that app stored, which is a fold of
    /// the LibreView Account ID — which fold depends on which app
    /// (`Libre3ActivatingApp`). A mismatched (e.g. random, or the other app's)
    /// ID is rejected with NFC error `0xB1`.
    ///
    /// For **fresh activation** with no vendor app, FLwatch becomes the receiver
    /// itself, so an accountless ID is fine — generate once and reuse.
    static func receiverID() throws -> Libre3ReceiverID {
        let patientID = SharedData.libre3LibreViewPatientId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let activatingApp = SharedData.libre3ActivatingApp
        if activatingApp.usesLibreViewAccount {
            // Deliberately does not touch `libre3ReceiverIDHex`: that records what
            // the paired sensor actually holds, and only `save()` may write it.
            // Deriving used to write it too, which let one sensor's identity
            // overwrite another's.
            //
            // Throws instead of falling through to the installation identity: a
            // vendor app was named, and pairing under FLwatch's own ID would
            // silently produce one that app could never reproduce. The empty
            // account is already blocked by `scanBlockedReason` in the connect
            // view, which says so in plain words — this is the backstop behind it.
            guard !patientID.isEmpty,
                  let derived = receiverID(forAccountID: patientID, activatingApp: activatingApp)
            else {
                throw Libre3StateStoreError.invalidReceiverIDConfiguration
            }
            return derived
        }
        return try installationReceiverID()
    }

    /// This installation's own receiver ID, used for sensors FLwatch activates
    /// itself. Generated once and then permanent: a sensor FLwatch started can
    /// only ever be re-opened by presenting the same ID, and no vendor app can
    /// adopt it. Kept in the keychain so a reinstall doesn't strand those sensors.
    /// Stored as little-endian hex text rather than raw bytes, so the package's
    /// own `littleEndianHex` round-trip does the byte order both ways.
    ///
    /// Throws rather than returning an unpersisted ID: activating a sensor with
    /// an identity that didn't reach the keychain would strand it permanently,
    /// with no way to reconstruct what it was told. A newly generated ID is
    /// therefore read back and compared before it is handed out, since a write
    /// that silently fails to stick is as damaging as one that errors.
    static func installationReceiverID() throws -> Libre3ReceiverID {
        if let existing = storedInstallationReceiverID() {
            return existing
        }
        let generated = Libre3ReceiverID(accountlessUniqueID: UUID().uuidString)
        try Libre3PINStore.saveInstallationReceiverID(Data(generated.littleEndianHex.utf8))
        guard storedInstallationReceiverID() == generated else {
            throw Libre3StateStoreError.installationReceiverIDNotPersisted
        }
        return generated
    }

    private static func storedInstallationReceiverID() -> Libre3ReceiverID? {
        guard let stored = (try? Libre3PINStore.readInstallationReceiverID()) ?? nil,
              let hex = String(data: stored, encoding: .utf8) else { return nil }
        return try? Libre3ReceiverID(littleEndianHex: hex)
    }

    /// Account ID → receiver ID under `activatingApp`, or nil when that app
    /// derives none from an account. The single place this mapping happens, so
    /// what the UI shows is exactly what the next scan puts on the wire.
    ///
    /// The folds themselves are LibreCRKit's, lowercasing included, so
    /// `.freeStyleLibre3` stays byte-identical to the FNV over the lowercased
    /// Account ID that shipped before this setting existed.
    static func receiverID(
        forAccountID accountID: String,
        activatingApp: Libre3ActivatingApp
    ) -> Libre3ReceiverID? {
        activatingApp.derivation.map { Libre3ReceiverID(accountID: accountID, derivation: $0) }
    }

    /// Formatted preview of the above, so the view layer needn't import
    /// LibreCRKit. Nil when there's no account to derive from.
    static func receiverIDPreview(
        forAccountID accountID: String,
        activatingApp: Libre3ActivatingApp
    ) -> String? {
        guard activatingApp.usesLibreViewAccount else {
            // FLwatch only presents its installation identity, whatever the
            // account rows happen to hold. A keychain failure shows nothing here;
            // the scan itself reports it properly.
            return (try? installationReceiverID())?.displayString
        }
        let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return receiverID(forAccountID: trimmed, activatingApp: activatingApp)?.displayString
    }

    /// Which app's fold produced the paired sensor's receiver ID, if it can be
    /// told.
    ///
    /// Both folds are computed over the stored Account ID and compared against
    /// what's on record. That is exact where it answers, and it's what carries
    /// the build-201 testers across: their pick lived under a different defaults
    /// key this branch removes, but the receiver ID it produced is still stored.
    ///
    /// A paired sensor whose stored ID neither fold reproduces was activated by
    /// FLwatch, since that path presents the installation ID rather than deriving
    /// one. Nil only when there's nothing paired to reason about.
    static func inferActivatingAppFromStoredReceiverID() -> Libre3ActivatingApp? {
        let storedHex = SharedData.libre3ReceiverIDHex
        guard !storedHex.isEmpty, SharedData.libre3SensorIsPaired else { return nil }
        return accountFoldMatching(hex: storedHex) ?? .flwatchOnly
    }

    /// Which vendor app's fold over the stored Account ID produces `hex`, if
    /// either does. Nil means no account is stored, or the ID came from
    /// somewhere other than a fold — in practice, FLwatch generated it.
    ///
    /// Deliberately says nothing about whether a sensor is currently paired:
    /// callers that care apply that themselves, and the legacy rescue must work
    /// precisely when nothing is paired.
    private static func accountFoldMatching(hex: String) -> Libre3ActivatingApp? {
        let accountID = SharedData.libre3LibreViewPatientId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty else { return nil }
        return [Libre3ActivatingApp.freeStyleLibre3, .libreByAbbott].first {
            receiverID(forAccountID: accountID, activatingApp: $0)?.littleEndianHex == hex
        }
    }

    /// Rescue an FLwatch-activated sensor that predates the keychain identity.
    ///
    /// Before the split, a generated receiver ID was cached in
    /// `libre3ReceiverIDHex` — the same slot account-derived IDs used, so the next
    /// vendor pairing would overwrite it and strand the sensor. If that hex still
    /// holds an ID no account fold reproduces, it is that sensor's identity, so
    /// adopt it as this installation's before anything can overwrite it.
    ///
    /// Runs whether or not a sensor is currently paired: the old `clear()` kept
    /// the hex on disconnect, so a sensor FLwatch activated and then disconnected
    /// is exactly the case that needs rescuing, and it has no serial on record.
    ///
    /// Only ever fills an empty keychain entry: once set, the installation ID is
    /// permanent. Best-effort — a failure here strands nothing that wasn't
    /// already stranded, so it logs and moves on.
    static func adoptLegacyInstallationReceiverIDIfNeeded() {
        let storedHex = SharedData.libre3ReceiverIDHex
        guard storedInstallationReceiverID() == nil,
              !storedHex.isEmpty,
              accountFoldMatching(hex: storedHex) == nil,
              let legacy = try? Libre3ReceiverID(littleEndianHex: storedHex)
        else { return }

        do {
            try Libre3PINStore.saveInstallationReceiverID(Data(legacy.littleEndianHex.utf8))
            Logger.libre3.info("Adopted the previously cached receiver ID as this installation's identity")
        } catch {
            Logger.libre3.error("Couldn't adopt the cached receiver ID as this installation's identity: \(String(describing: error), privacy: .public)")
        }
    }

    /// Pick the initial `libre3ActivatingApp` when the user has never chosen one.
    ///
    /// Preference order: what the stored receiver ID proves, then — for a sensor
    /// paired before this setting existed — the FreeStyle Libre 3 fold that was
    /// the only one available then, and only otherwise the storefront guess.
    ///
    /// Both apps are live on the US store, so that guess is a hint, not a fact; a
    /// wrong one costs a rejected scan (`0xB1`) and a change in the picker. What
    /// it must never do is flip somebody whose setup already works, which is what
    /// the two earlier branches protect.
    ///
    /// `@MainActor` so the defaults write — which `@AppStorage` observes — lands
    /// on the main actor rather than wherever the storefront lookup resumes.
    @MainActor
    static func seedActivatingAppIfUnset() async {
        // Runs before the guard below: the rescue is about the keychain identity,
        // not the picker, and must happen even for a user who has already chosen.
        adoptLegacyInstallationReceiverIDIfNeeded()

        guard !SharedData.libre3ActivatingAppIsSet else { return }

        if let inferred = inferActivatingAppFromStoredReceiverID() {
            SharedData.libre3ActivatingApp = inferred
            Logger.libre3.info("Seeded activating app to \(inferred.rawValue, privacy: .public) (matches the stored receiver ID)")
            return
        }

        if !SharedData.libre3Serial.isEmpty {
            SharedData.libre3ActivatingApp = .freeStyleLibre3
            Logger.libre3.info("Seeded activating app to freeStyleLibre3 (already paired before this setting existed)")
            return
        }

        // Storefront country, not device locale: "Libre by Abbott" is only
        // distributed on the US store, so this reflects what the user can
        // actually have installed. Nil (no App Store account) falls through.
        let countryCode = await Storefront.current?.countryCode

        // The picker stays live across that await, so the user may have chosen in
        // the meantime. Their choice wins over a guess.
        guard !SharedData.libre3ActivatingAppIsSet else { return }

        let seeded: Libre3ActivatingApp = countryCode == "USA" ? .libreByAbbott : .freeStyleLibre3
        SharedData.libre3ActivatingApp = seeded
        Logger.libre3.info("Seeded activating app to \(seeded.rawValue, privacy: .public) (storefront \(countryCode ?? "unknown", privacy: .public))")
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

    /// Forget the paired sensor (disconnect).
    ///
    /// `libre3ReceiverIDHex` goes with it: it records what *that* sensor holds, so
    /// keeping it would leave a stale ID for the next pairing to trip over. The
    /// identity a re-pair needs is the installation ID in the keychain, which
    /// this deliberately does not touch.
    static func clear() {
        try? Libre3PINStore.delete()
        try? Libre3PINStore.deleteReconnectKey()
        SharedData.libre3Serial = ""
        SharedData.libre3ReceiverIDHex = ""
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
