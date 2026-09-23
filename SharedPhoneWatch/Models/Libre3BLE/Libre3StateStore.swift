//
//  Libre3StateStore.swift
//  FLwatch
//
//  Bridges the LibreCRKit `Libre3SensorState` and FLwatch's split
//  persistence: the secret BLE PIN → keychain (`Libre3PINStore`), the non-secret
//  metadata → app group (`SharedData`). The phone writes pairing state after NFC;
//  the watch later installs the same shape from its provisioning package.
//

import Foundation
import LibreCRKit
import OSLog
#if os(iOS)
import StoreKit
#endif

enum Libre3StateStoreError: Error {
    /// The installation receiver ID couldn't be written to the keychain, or the
    /// write didn't survive a read-back. Pairing must not continue: a sensor
    /// activated under an identity we can't reproduce is unreachable forever.
    case installationReceiverIDNotPersisted

    /// A vendor app is selected, but no receiver ID could be derived for it:
    /// the Account ID or matching Libre by Abbott UUID is missing with no valid
    /// developer override, or `usesLibreViewAccount` and `derivation` disagree.
    /// These are prevented upstream by `scanBlockedReason` and an invariant
    /// test, so this exists to stop the fall-through rather than to be reached.
    /// Pairing under FLwatch's
    /// own installation identity when the user named a vendor app would write an
    /// ID that app can never reproduce, stranding the sensor for its whole wear.
    case invalidReceiverIDConfiguration

    /// The watch must not acknowledge a provisioning package unless its sensor
    /// settings reached the same persistent store the BLE engine will read.
    case provisionedSensorSettingsNotPersisted

    /// A successful Security.framework return is not enough for the package
    /// acknowledgement; verify both secrets can be read back byte-for-byte.
    case provisionedSecretsNotPersisted
}

/// Complete phone-owned state needed for cached Libre 3 reconnects on the
/// watch. CoreBluetooth's peripheral UUID is intentionally absent because it is
/// local to one central and the watch must discover and bind its own.
struct Libre3ProvisionedState: Codable, Equatable, Sendable {
    let serial: String
    let bleAddress: String
    let receiverIDHex: String
    let mode: Libre3Mode?
    let firmwareVersion: String
    let warmupMinutes: Int
    let wearDurationMinutes: Int
    let generation: Int
    let productType: Int
    let sensorStartDateMillisecondsSince1970: Int64?
    let blePIN: Data
    let reconnectKey: Data?
    let calibrationSensorSerial: String
    let calibrationOffsetMgDL: Int
    let sensorSettings: SensorSettings
    let workoutLowDefaultMgDL: Int

    /// Integer wire representation keeps the provisioning digest independent
    /// of Foundation's platform-specific Double-to-JSON formatting.
    var sensorStartDate: Date? {
        sensorStartDateMillisecondsSince1970.map {
            Date(timeIntervalSince1970: TimeInterval($0) / 1_000)
        }
    }
}

struct Libre3ReceiverIDPreview: Equatable, Sendable {
    let displayString: String
    let usesOverride: Bool
}

/// The LibreCRKit fold this app applies to its account-specific input, or nil
/// when it derives nothing from an account — `.flwatchOnly` presents the
/// installation identity instead.
///
/// Lives here rather than on the type itself: `Libre3ActivatingApp` also compiles
/// into widget targets that do not link LibreCRKit and therefore cannot name
/// `Libre3ReceiverID.Derivation`. Exhaustive on purpose, and must mirror
/// `usesLibreViewAccount` — see the note there.
extension Libre3ActivatingApp {
    var derivation: Libre3ReceiverID.Derivation? {
        switch self {
        case .freeStyleLibre3:
            return .freeStyleLibre3
        case .libreByAbbottServerID, .libreByAbbott:
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
    /// sensor only accepts the receiver ID that app stored. FreeStyle Libre 3
    /// and legacy Libre by Abbott fold the Account ID; current Libre by Abbott
    /// folds a login-issued receiver UUID. A mismatched ID is rejected with NFC
    /// error `0xB1`. Developer mode may explicitly override any vendor-app ID.
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
            // required account data is already blocked by `scanBlockedReason`
            // in the connect view — this is the backstop behind it.
            guard let derived = receiverID(
                forAccountID: patientID,
                activatingApp: activatingApp
            )
            else {
                throw Libre3StateStoreError.invalidReceiverIDConfiguration
            }
            if activeReceiverIDOverride(
                for: activatingApp,
                developerModeEnabled: receiverIDOverrideDeveloperModeEnabled,
                receiverIDOverrideHex: SharedData.libre3ReceiverIDOverrideHex
            ) != nil {
                Logger.libre3.info(
                    "Resolved receiver ID using developer override for activating-app case \(activatingApp.rawValue, privacy: .public)"
                )
            } else {
                Logger.libre3.info("Resolved receiver ID using activating-app case \(activatingApp.rawValue, privacy: .public)")
            }
            return derived
        }
        let receiverID = try installationReceiverID()
        Logger.libre3.info("Resolved receiver ID using activating-app case \(Libre3ActivatingApp.flwatchOnly.rawValue, privacy: .public)")
        return receiverID
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

    /// Account data or an enabled developer override → receiver ID under
    /// `activatingApp`, or nil when neither can resolve one. The single place
    /// this mapping happens, so the UI matches the next scan.
    ///
    /// The folds themselves are LibreCRKit's, lowercasing included, so
    /// `.freeStyleLibre3` stays byte-identical to the FNV over the lowercased
    /// Account ID that shipped before this setting existed.
    static func receiverID(
        forAccountID accountID: String,
        activatingApp: Libre3ActivatingApp
    ) -> Libre3ReceiverID? {
        receiverID(
            forAccountID: accountID,
            activatingApp: activatingApp,
            developerModeEnabled: receiverIDOverrideDeveloperModeEnabled,
            receiverIDOverrideHex: SharedData.libre3ReceiverIDOverrideHex,
            libre1ReceiverUUID: SharedData.libre3Libre1ReceiverUUID,
            libre1ReceiverUUIDAccountID: SharedData.libre3Libre1ReceiverUUIDAccountId
        )
    }

    static func receiverID(
        forAccountID accountID: String,
        activatingApp: Libre3ActivatingApp,
        developerModeEnabled: Bool,
        receiverIDOverrideHex: String,
        libre1ReceiverUUID: String?,
        libre1ReceiverUUIDAccountID: String?
    ) -> Libre3ReceiverID? {
        if let override = activeReceiverIDOverride(
            for: activatingApp,
            developerModeEnabled: developerModeEnabled,
            receiverIDOverrideHex: receiverIDOverrideHex
        ) {
            return override
        }

        let accountID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty else { return nil }
        return receiverID(
            forAccountID: accountID,
            activatingApp: activatingApp,
            libre1ReceiverUUID: libre1ReceiverUUID,
            libre1ReceiverUUIDAccountID: libre1ReceiverUUIDAccountID
        )
    }

    /// Explicit-cache overload used by tests and by callers that have just
    /// fetched the UUID but have not persisted it yet.
    static func receiverID(
        forAccountID accountID: String,
        activatingApp: Libre3ActivatingApp,
        libre1ReceiverUUID: String?,
        libre1ReceiverUUIDAccountID: String?
    ) -> Libre3ReceiverID? {
        switch activatingApp {
        case .libreByAbbottServerID:
            let requestedAccountID = normalizedAccountID(accountID)
            guard !requestedAccountID.isEmpty,
                  requestedAccountID == normalizedAccountID(libre1ReceiverUUIDAccountID ?? ""),
                  let receiverUUID = libre1ReceiverUUID,
                  let uuid = UUID(uuidString: receiverUUID)
            else { return nil }
            return Libre3ReceiverID(
                accountID: uuid.uuidString.lowercased(),
                derivation: .libreByAbbott
            )
        case .freeStyleLibre3, .libreByAbbott:
            return activatingApp.derivation.map {
                Libre3ReceiverID(accountID: accountID, derivation: $0)
            }
        case .flwatchOnly:
            return nil
        }
    }

    private static func normalizedAccountID(_ accountID: String) -> String {
        accountID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Parses the developer field's unambiguous display formats and returns the
    /// canonical little-endian wire hex used in app-group storage.
    static func receiverIDOverrideLittleEndianHex(from input: String) -> String? {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.hasPrefix("0x") {
            let digits = String(input.dropFirst(2))
            guard digits.count == 8,
                  digits.unicodeScalars.allSatisfy({
                      (48...57).contains($0.value)
                          || (65...70).contains($0.value)
                          || (97...102).contains($0.value)
                  }),
                  let value = UInt32(digits, radix: 16)
            else { return nil }
            return Libre3ReceiverID(value).littleEndianHex
        }

        guard !input.isEmpty,
              input.unicodeScalars.allSatisfy({ (48...57).contains($0.value) }),
              let value = UInt32(input, radix: 10)
        else { return nil }
        return Libre3ReceiverID(value).littleEndianHex
    }

    static func receiverIDOverrideEditorText(storedLittleEndianHex: String) -> String {
        guard let receiverID = try? Libre3ReceiverID(littleEndianHex: storedLittleEndianHex)
        else { return "" }
        return String(format: "0x%08x", receiverID.value)
    }

    private static var receiverIDOverrideDeveloperModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.developerModeEnabled.rawValue)
    }

    private static func activeReceiverIDOverride(
        for activatingApp: Libre3ActivatingApp,
        developerModeEnabled: Bool,
        receiverIDOverrideHex: String
    ) -> Libre3ReceiverID? {
        guard developerModeEnabled, activatingApp.usesLibreViewAccount else { return nil }
        return try? Libre3ReceiverID(littleEndianHex: receiverIDOverrideHex)
    }

    /// Formatted preview of the above, so the view layer needn't import
    /// LibreCRKit. Nil when neither account data nor an override resolves an ID.
    static func receiverIDPreviewDetails(
        forAccountID accountID: String,
        activatingApp: Libre3ActivatingApp,
        developerModeEnabled: Bool,
        receiverIDOverrideHex: String
    ) -> Libre3ReceiverIDPreview? {
        guard activatingApp.usesLibreViewAccount else {
            // FLwatch only presents its installation identity, whatever the
            // account rows happen to hold. A keychain failure shows nothing here;
            // the scan itself reports it properly.
            return (try? installationReceiverID()).map {
                Libre3ReceiverIDPreview(displayString: $0.displayString, usesOverride: false)
            }
        }
        guard let receiverID = receiverID(
            forAccountID: accountID,
            activatingApp: activatingApp,
            developerModeEnabled: developerModeEnabled,
            receiverIDOverrideHex: receiverIDOverrideHex,
            libre1ReceiverUUID: SharedData.libre3Libre1ReceiverUUID,
            libre1ReceiverUUIDAccountID: SharedData.libre3Libre1ReceiverUUIDAccountId
        ) else { return nil }
        return Libre3ReceiverIDPreview(
            displayString: receiverID.displayString,
            usesOverride: activeReceiverIDOverride(
                for: activatingApp,
                developerModeEnabled: developerModeEnabled,
                receiverIDOverrideHex: receiverIDOverrideHex
            ) != nil
        )
    }

    /// Which app's fold produced the paired sensor's receiver ID, if it can be
    /// told.
    ///
    /// Every available vendor fold is computed from its stored account data and
    /// compared against what's on record. That is exact where it answers, and it
    /// carries the build-201 testers across: their pick lived under a different
    /// defaults key this branch removes, but its receiver ID is still stored.
    ///
    /// A paired sensor whose stored ID no known fold reproduces was activated by
    /// FLwatch, since that path presents the installation ID rather than deriving
    /// one. Nil only when there's nothing paired to reason about.
    static func inferActivatingAppFromStoredReceiverID() -> Libre3ActivatingApp? {
        inferActivatingAppFromStoredReceiverID(
            storedHex: SharedData.libre3ReceiverIDHex,
            sensorIsPaired: SharedData.libre3SensorIsPaired,
            accountID: SharedData.libre3LibreViewPatientId,
            libre1ReceiverUUID: SharedData.libre3Libre1ReceiverUUID,
            libre1ReceiverUUIDAccountID: SharedData.libre3Libre1ReceiverUUIDAccountId,
            receiverIDOverrideHex: SharedData.libre3ReceiverIDOverrideHex
        )
    }

    static func inferActivatingAppFromStoredReceiverID(
        storedHex: String,
        sensorIsPaired: Bool,
        accountID: String,
        libre1ReceiverUUID: String,
        libre1ReceiverUUIDAccountID: String,
        receiverIDOverrideHex: String = ""
    ) -> Libre3ActivatingApp? {
        guard !storedHex.isEmpty, sensorIsPaired else { return nil }
        guard !receiverIDMatchesStoredOverride(
            storedHex: storedHex,
            receiverIDOverrideHex: receiverIDOverrideHex
        ) else { return nil }
        return accountFoldMatching(
            hex: storedHex,
            accountID: accountID,
            libre1ReceiverUUID: libre1ReceiverUUID,
            libre1ReceiverUUIDAccountID: libre1ReceiverUUIDAccountID
        ) ?? .flwatchOnly
    }

    /// Which vendor app's fold over its stored account data produces `hex`, if
    /// one does. Nil means no account is stored, or the ID came from
    /// somewhere other than a fold — in practice, FLwatch generated it.
    ///
    /// Deliberately says nothing about whether a sensor is currently paired:
    /// callers that care apply that themselves, and the legacy rescue must work
    /// precisely when nothing is paired.
    static func accountFoldMatching(
        hex: String,
        accountID: String,
        libre1ReceiverUUID: String,
        libre1ReceiverUUIDAccountID: String
    ) -> Libre3ActivatingApp? {
        let accountID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty else { return nil }
        return [
            Libre3ActivatingApp.freeStyleLibre3,
            .libreByAbbottServerID,
            .libreByAbbott
        ].first {
            receiverID(
                forAccountID: accountID,
                activatingApp: $0,
                libre1ReceiverUUID: libre1ReceiverUUID,
                libre1ReceiverUUIDAccountID: libre1ReceiverUUIDAccountID
            )?.littleEndianHex == hex
        }
    }

    /// Returns the parsed legacy ID only when neither the saved override nor a
    /// known account fold claims it.
    static func legacyInstallationReceiverIDToAdopt(
        hex: String,
        accountID: String,
        libre1ReceiverUUID: String,
        libre1ReceiverUUIDAccountID: String,
        receiverIDOverrideHex: String = ""
    ) -> Libre3ReceiverID? {
        guard !hex.isEmpty,
              let candidate = try? Libre3ReceiverID(littleEndianHex: hex)
        else { return nil }
        if let override = try? Libre3ReceiverID(littleEndianHex: receiverIDOverrideHex),
           candidate == override {
            return nil
        }
        guard accountFoldMatching(
                hex: hex,
                accountID: accountID,
                libre1ReceiverUUID: libre1ReceiverUUID,
                libre1ReceiverUUIDAccountID: libre1ReceiverUUIDAccountID
              ) == nil
        else { return nil }
        return candidate
    }

    private static func receiverIDMatchesStoredOverride(
        storedHex: String,
        receiverIDOverrideHex: String
    ) -> Bool {
        guard let override = try? Libre3ReceiverID(littleEndianHex: receiverIDOverrideHex),
              let stored = try? Libre3ReceiverID(littleEndianHex: storedHex)
        else { return false }
        return stored == override
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
    /// permanent. Once there is nothing to migrate or a save succeeds, later
    /// receiver IDs are never candidates. A keychain save failure stays pending
    /// so the next launch can retry the same best-effort rescue.
    static func adoptLegacyInstallationReceiverIDIfNeeded() {
        guard !SharedData.libre3LegacyReceiverIDRescueCompleted else { return }

        let storedHex = SharedData.libre3ReceiverIDHex
        guard storedInstallationReceiverID() == nil else {
            SharedData.libre3LegacyReceiverIDRescueCompleted = true
            return
        }
        guard let legacy = legacyInstallationReceiverIDToAdopt(
            hex: storedHex,
            accountID: SharedData.libre3LibreViewPatientId,
            libre1ReceiverUUID: SharedData.libre3Libre1ReceiverUUID,
            libre1ReceiverUUIDAccountID: SharedData.libre3Libre1ReceiverUUIDAccountId,
            receiverIDOverrideHex: SharedData.libre3ReceiverIDOverrideHex
        ) else {
            SharedData.libre3LegacyReceiverIDRescueCompleted = true
            return
        }

        do {
            try Libre3PINStore.saveInstallationReceiverID(Data(legacy.littleEndianHex.utf8))
            SharedData.libre3LegacyReceiverIDRescueCompleted = true
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
#if os(iOS)
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

        // Preserve the existing storefront seed. Libre by Abbott is no longer
        // US-only, but changing this guess would silently change established
        // setup behaviour; the user can choose the current app explicitly.
        let countryCode = await Storefront.current?.countryCode

        // The picker stays live across that await, so the user may have chosen in
        // the meantime. Their choice wins over a guess.
        guard !SharedData.libre3ActivatingAppIsSet else { return }

        let seeded: Libre3ActivatingApp = countryCode == "USA" ? .libreByAbbott : .freeStyleLibre3
        SharedData.libre3ActivatingApp = seeded
        Logger.libre3.info("Seeded activating app to \(seeded.rawValue, privacy: .public) (storefront \(countryCode ?? "unknown", privacy: .public))")
    }
#endif

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

    /// Install a phone-created package on the watch without using `save`, whose
    /// NFC semantics deliberately delete cached authorization. Keychain changes
    /// are rolled back if either secret or the shared sensor-settings snapshot
    /// cannot be persisted; the caller may acknowledge only after this returns.
    @MainActor
    static func installProvisionedState(_ state: Libre3ProvisionedState) throws {
        let previousPIN = try Libre3PINStore.read()
        let previousReconnectKey = try Libre3PINStore.readReconnectKey()

        do {
            try Libre3PINStore.save(state.blePIN)
            if let reconnectKey = state.reconnectKey {
                try Libre3PINStore.saveReconnectKey(reconnectKey)
            } else {
                try Libre3PINStore.deleteReconnectKey()
            }
            guard try Libre3PINStore.read() == state.blePIN,
                  try Libre3PINStore.readReconnectKey() == state.reconnectKey else {
                throw Libre3StateStoreError.provisionedSecretsNotPersisted
            }

            let sensorType = sensorType(
                productType: state.productType,
                generation: state.generation
            )
            guard SensorSettingsStore.shared.replaceCacheAndPersist(
                sensorSettings: state.sensorSettings,
                sensorType: sensorType
            ) else {
                throw Libre3StateStoreError.provisionedSensorSettingsNotPersisted
            }
        } catch {
            restoreKeychainValue(
                previousPIN,
                save: { try Libre3PINStore.save($0) },
                delete: { try Libre3PINStore.delete() }
            )
            restoreKeychainValue(
                previousReconnectKey,
                save: { try Libre3PINStore.saveReconnectKey($0) },
                delete: { try Libre3PINStore.deleteReconnectKey() }
            )
            throw error
        }

        let sensorChanged = SharedData.libre3Serial != state.serial
        SharedData.libre3PeripheralUUID = ""
        SharedData.libre3Serial = state.serial
        SharedData.libre3BleAddress = state.bleAddress
        SharedData.libre3ReceiverIDHex = state.receiverIDHex
        SharedData.libre3Mode = state.mode
        SharedData.libre3FirmwareVersion = state.firmwareVersion
        SharedData.libre3WarmupMinutes = state.warmupMinutes
        SharedData.libre3WearDurationMinutes = state.wearDurationMinutes
        SharedData.libre3Generation = state.generation
        SharedData.libre3ProductType = state.productType
        SharedData.libre3SensorStartDate = state.sensorStartDate
        SharedData.libre3CalibrationSensorSerial = state.calibrationSensorSerial
        SharedData.libre3CalibrationOffsetMgDL = state.calibrationOffsetMgDL
        SharedData.libre3WorkoutLowDefaultMgDL = state.workoutLowDefaultMgDL

        if sensorChanged {
            SharedData.libre3LastLifeCount = 0
            SharedData.libre3LastGlucoseMgDL = 0
            SharedData.libre3LastGlucoseAt = nil
        }
    }

    private static func restoreKeychainValue(
        _ value: Data?,
        save: (Data) throws -> Void,
        delete: () throws -> Void
    ) {
        do {
            if let value {
                try save(value)
            } else {
                try delete()
            }
        } catch {
            Logger.libre3.error("Couldn't roll back a partial watch provisioning keychain write: \(String(describing: error), privacy: .public)")
        }
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
        SharedData.libre3SensorStartDate = nil
        SharedData.libre3LastLifeCount = 0
        SharedData.libre3LastGlucoseMgDL = 0
        SharedData.libre3LastGlucoseAt = nil
        SharedData.libre3WarmupMinutes = 0
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
    static func saveReconnectKey(_ rawKey: Data) throws {
        try Libre3PINStore.saveReconnectKey(rawKey)
    }

    /// The persisted cached-reconnect key, or `nil` if a phone full handshake
    /// hasn't completed since pairing or the app predates this stored material.
    /// A watch treats nil as not ready; it never establishes this key itself.
    static func loadReconnectKey() -> Data? {
        (try? Libre3PINStore.readReconnectKey()) ?? nil
    }

    /// SensorType derived from the persisted patch-info model fields
    /// (productType / generation), so the rest of FLwatch shows the right
    /// sensor name and `isALibre` behaviour, mirroring how DiaBLE/Juggluco read
    /// the patch frame.
    static var sensorType: SensorType {
        sensorType(
            productType: SharedData.libre3ProductType,
            generation: SharedData.libre3Generation
        )
    }

    private static func sensorType(productType: Int, generation: Int) -> SensorType {
        switch productType {
        case 9: return .lingo
        default: return generation >= 1 ? .libre3Plus : .libre3
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
