//
//  Libre3PairingCoordinator.swift
//  FLwatch
//
//  Drives the foreground NFC pairing step for the Libre 3 direct-BLE provider.
//  Maps the user-chosen `Libre3Mode` to a LibreCRKit `Libre3NFCScanMode`, runs
//  the scan (one tap: the reader reads patch info + issues the activation/switch
//  command in a single session), then persists the resulting PIN + metadata via
//  `Libre3StateStore`.
//
//  Phase 2 stops at "paired" — it captures and stores credentials. The BLE
//  handshake, decode, and live readings come in Phase 3 (`Libre3DirectManager`).
//
//  iOS-only: references LibreCRKit + CoreNFC, both phone-target only.
//

#if os(iOS)
import Foundation
import CoreNFC
import OSLog
import LibreCRKit

@MainActor
final class Libre3PairingCoordinator: ObservableObject {

    enum PairingState: Equatable {
        case idle
        case scanning
        case paired(serial: String, bleAddress: String, firmware: String)
        case failed(message: String)
    }

    /// Result of a non-destructive `.readPatchInfo` scan — no command sent, no
    /// PIN rotation. Used to verify NFC works and to inspect the sensor before
    /// committing to a (possibly destructive) pairing action.
    struct ScannedSensorInfo: Equatable {
        let serial: String
        /// Libre 3 / Libre 3 Plus / Lingo, from productType + generation.
        let model: String
        let firmware: String
        let stateByte: UInt8
        let wearDurationMinutes: UInt16
        /// Warm-up duration in minutes (Libre 3 = 60).
        let warmupMinutes: Int?
        /// True when the sensor is fresh (state 0x01) so the recommended command
        /// is activate; false when it's already active (takeover/parallel apply).
        let isFresh: Bool

        init(patchInfo: Libre3NFCPatchInfo) {
            serial = patchInfo.serialNumber
            model = patchInfo.modelName
            firmware = patchInfo.firmwareVersion
            stateByte = patchInfo.stateByte
            wearDurationMinutes = patchInfo.wearDurationMinutes
            warmupMinutes = Int(patchInfo.warmupMinutes)
            isFresh = patchInfo.recommendedCommandCode == .activate
        }
    }

    @Published private(set) var state: PairingState
    @Published private(set) var lastScannedInfo: ScannedSensorInfo?
    @Published private(set) var calibrationResetNotice: String?

    /// Held for the lifetime of an in-flight scan so it isn't deallocated while
    /// the NFC session is open.
    private var activeReader: Libre3NFCActivationReader?

    init() {
        if Libre3StateStore.isPaired {
            state = .paired(
                serial: SharedData.libre3Serial,
                bleAddress: SharedData.libre3BleAddress,
                firmware: SharedData.libre3FirmwareVersion
            )
        } else {
            state = .idle
        }
    }

    var isPaired: Bool { Libre3StateStore.isPaired }

    /// The state to return to after a non-committal scan (read-info / cancel):
    /// the paired summary if a sensor is already stored, otherwise idle.
    private func restingState() -> PairingState {
        isPaired
            ? .paired(serial: SharedData.libre3Serial, bleAddress: SharedData.libre3BleAddress, firmware: SharedData.libre3FirmwareVersion)
            : .idle
    }

    // MARK: - Read sensor info (non-destructive)

    /// Reads patch info only (`0xA1`) — no activation/switch command, no PIN
    /// rotation. Safe to run on a sensor the vendor app is actively using.
    func readSensorInfo() async {
        guard NFCTagReaderSession.readingAvailable else {
            state = .failed(message: String(localized: "This iPhone can't scan NFC tags."))
            return
        }
        state = .scanning
        let reader = Libre3NFCActivationReader()
        activeReader = reader
        defer { activeReader = nil }

        do {
            let result = try await reader.scan(mode: .readPatchInfo)
            let info = ScannedSensorInfo(patchInfo: result.patchInfo)
            lastScannedInfo = info
            state = restingState()
            Logger.libre3.info("Read sensor info: serial=\(info.serial, privacy: .public) model=\(info.model, privacy: .public) fw=\(info.firmware, privacy: .public) warmup=\(info.warmupMinutes ?? -1, privacy: .public)min state=0x\(String(result.patchInfo.stateByte, radix: 16), privacy: .public)")
        } catch {
            if Self.isUserCancellation(error) {
                state = restingState()
                return
            }
            Logger.libre3.error("Read sensor info failed: \(String(describing: error), privacy: .public)")
            state = .failed(message: Self.friendlyMessage(for: error, mode: .takeover))
        }
    }

    // MARK: - Pairing

    func pair(mode: Libre3Mode) async {
        guard NFCTagReaderSession.readingAvailable else {
            state = .failed(message: String(localized: "This iPhone can't scan NFC tags."))
            return
        }

        state = .scanning
        let receiverID = Libre3StateStore.receiverID()
        let scanMode = Self.scanMode(for: mode, receiverID: receiverID.value)

        let reader = Libre3NFCActivationReader()
        activeReader = reader
        defer { activeReader = nil }

        do {
            let result = try await reader.scan(mode: scanMode)
            guard let activation = result.activationResponse else {
                // Only `.readPatchInfo` returns no activation; our modes always
                // issue a command, so this means the sensor didn't respond as
                // expected.
                Logger.libre3.error("Pairing (\(mode.rawValue, privacy: .public)) returned no activation response")
                state = .failed(message: String(localized: "The sensor didn't return pairing data. Move the sensor to the top of your phone and try again."))
                return
            }

            let sensorState = try activation.sensorState(
                serialNumber: result.patchInfo.serialNumber,
                receiverID: receiverID,
                source: "NFC \(mode.rawValue)"
            )
            Libre3DirectManager.shared.forgetSensor()
            try Libre3StateStore.save(state: sensorState, mode: mode, patchInfo: result.patchInfo)
            if !SharedData.libre3CalibrationSensorSerial.isEmpty,
               SharedData.libre3CalibrationSensorSerial != result.patchInfo.serialNumber {
                SharedData.resetLibre3CalibrationForNewSensor()
                calibrationResetNotice = String(localized: "The previous sensor's FLwatch calibration and calibration log were cleared. The new sensor will use its factory calibration.")
            }
            // Stamp the sensor model immediately so Settings/UI reflect it before
            // the first reading (the manager re-stamps on connect too).
            Libre3StateStore.stampSensorType()

            // Reflect "set up" for the rest of the app and kick off the BLE
            // engine: the credentials are now stored, so start connecting and
            // streaming live readings (Phase 3).
            UserDefaults.group.connected = .connected
            Libre3DirectManager.shared.start()

            Logger.libre3.info("Paired via \(mode.rawValue, privacy: .public): serial=\(result.patchInfo.serialNumber, privacy: .public) fw=\(result.patchInfo.firmwareVersion, privacy: .public) addr=\(activation.bleAddressDisplay, privacy: .private)")

            state = .paired(
                serial: sensorState.serialNumber ?? result.patchInfo.serialNumber,
                bleAddress: sensorState.bleAddress ?? activation.bleAddressDisplay,
                // Corrected firmware persisted by `save` (DiaBLE/Juggluco layout).
                firmware: SharedData.libre3FirmwareVersion
            )
        } catch {
            if Self.isUserCancellation(error) {
                Logger.libre3.info("Pairing cancelled by user")
                state = restingState()
                return
            }
            Logger.libre3.error("Pairing (\(mode.rawValue, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            state = .failed(message: Self.friendlyMessage(for: error, mode: mode))
        }
    }

    /// Forget the paired sensor and clear stored credentials.
    func disconnect() {
        Libre3DirectManager.shared.forgetSensor()
        Libre3StateStore.clear()
        UserDefaults.group.connected = .disconnected
        state = .idle
        // Tell the watch the sensor is gone so its provider-account gate closes
        // (the snapshot now carries a nil libre3Serial).
        WatchConnectivityManager.shared.sendSettingsSnapshotToWatch()
        Logger.libre3.info("Disconnected Libre 3 sensor; cleared stored state")
    }

    func clearCalibrationResetNotice() {
        calibrationResetNotice = nil
    }

    // MARK: - Mode mapping

    private static func scanMode(for mode: Libre3Mode, receiverID: UInt32) -> Libre3NFCScanMode {
        switch mode {
        case .takeover:
            // 0xA8 on an already-active sensor: rotates the PIN, FLwatch becomes
            // the receiver. The reader validates the sensor is active.
            return .switchReceiver(receiverID: receiverID)
        case .parallelJoin:
            // 0xA0 on an already-active sensor: read the existing PIN without
            // rotating it (firmware-dependent — PLAN §11).
            return .forceActivationCommand(commandCode: .activate, receiverID: receiverID)
        case .activateFresh:
            // 0xA0 on a fresh (state 0x01) sensor: irreversible, starts the wear
            // clock. The reader validates the sensor is fresh.
            return .activateFreshSensor(receiverID: receiverID)
        }
    }

    // MARK: - Error presentation

    private static func isUserCancellation(_ error: Error) -> Bool {
        guard let nfc = error as? NFCReaderError else { return false }
        return nfc.code == .readerSessionInvalidationErrorUserCanceled
    }

    private static func friendlyMessage(for error: Error, mode: Libre3Mode) -> String {
        if let nfc = error as? Libre3NFCError {
            switch nfc {
            case .unexpectedSensorState:
                switch mode {
                case .takeover, .parallelJoin:
                    return String(localized: "This sensor isn't active yet. Start it in the FreeStyle Libre 3 app first, then pair it here.")
                case .activateFresh:
                    return String(localized: "This sensor is already active. Use Take over or Parallel instead of fresh activation.")
                }
            case .readerUnavailable:
                return String(localized: "NFC scanning isn't available on this iPhone.")
            case .multipleTags, .noTag, .nonISO15693Tag:
                return String(localized: "Couldn't read the sensor. Hold the top of your phone against the sensor and hold still.")
            case .invalidActivationResponseForPatch(let commandCode, _, let raw):
                return activationCommandRejected(raw: raw, commandCode: commandCode)
            case .invalidActivationResponse(let raw):
                return activationCommandRejected(raw: raw, commandCode: nil)
            case .invalidPatchInfo:
                return String(localized: "The sensor returned unexpected data. It may be an unsupported sensor or firmware.")
            case .sessionAlreadyActive:
                return String(localized: "A scan is already in progress. Wait a moment and try again.")
            }
        }
        if let nfc = error as? NFCReaderError, nfc.code == .readerSessionInvalidationErrorSessionTimeout {
            return String(localized: "The scan timed out. Try again and hold the phone against the sensor.")
        }
        return error.localizedDescription
    }

    /// Decodes the sensor's `01 <code>` error response (after stripping `0xA5`
    /// padding) into an actionable message. Codes per DiaBLE's Libre 3 NFC
    /// notes: `0xB0`/`0xB2` expired, `0xB1` "activated by the reader" (the
    /// sensor refuses the `0xA8` switch-receiver — `0xA0`/Parallel is accepted
    /// instead), `0xC1`/`0xC2` malformed request.
    private static func activationCommandRejected(raw: Data, commandCode: NFCActivationCommandCode?) -> String {
        let stripped = Data(raw.drop(while: { $0 == 0xA5 }))
        guard stripped.count >= 2, stripped.first == 0x01 else {
            return String(localized: "The sensor returned unexpected data. It may be an unsupported sensor or firmware.")
        }
        let code = stripped[stripped.index(after: stripped.startIndex)]
        switch code {
        case 0xB1:
            // 0xB1 = "activated by the reader, not an app." Observed on BOTH
            // 0xA8 (takeover) and 0xA0 (parallel) while the sensor was in its
            // ~60-min warm-up; a working takeover (sample app, 0xA8) was on a
            // post-warm-up sensor — so this is most likely warm-up-transient.
            return String(localized: "The sensor refused pairing (0xB1). It's most likely still in its ~60-minute warm-up. Wait until warm-up finishes, then try again.")
        case 0xB0, 0xB2:
            return String(localized: "This sensor has expired.")
        case 0xC1, 0xC2:
            return String(localized: "The sensor rejected the pairing request. Try again, holding the phone steady against the sensor.")
        default:
            let hex = String(code, radix: 16, uppercase: true)
            return String(localized: "The sensor rejected pairing (error code 0x\(hex)).")
        }
    }
}

extension Libre3NFCPatchInfo {
    /// Human model name from LibreCRKit's `productType` + `generation`.
    ///
    /// (We used to parse these fields ourselves because LibreCRKit's patch-info
    /// offsets were off by the 3-byte prefix; that was fixed upstream in
    /// `d96c914`, so we now read `productType`/`generation`/`firmwareVersion`/
    /// `warmupMinutes` straight from `Libre3NFCPatchInfo`. Only this model-name
    /// mapping remains ours — the package exposes the codes, not a label.)
    var modelName: String {
        switch productType {
        case 9: return "Lingo"
        default: return generation >= 1 ? "Libre 3 Plus" : "Libre 3"
        }
    }
}
#endif
