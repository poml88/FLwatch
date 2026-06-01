//
//  Libre3DirectManager.swift
//  FLwatch
//
//  The long-lived, phone-only BLE engine for the `.libre3BLE` provider. It owns
//  LibreCRKit's `SensorScanner` / `SensorSession` / `PairingFlow` / data-plane
//  decoder and, when it decodes a realtime reading, writes straight into the
//  shared `LibreLinkUpHistory` store — exactly like `DexcomShareProvider`, but
//  triggered by a BLE notification instead of a network call (PLAN §4).
//
//  Push, not pull: the thin `Libre3DirectProvider.reload()` only *kicks* this
//  manager (ensure connected) and reports status; it never fetches.
//
//  Concurrency (PLAN §6): this object is `@MainActor`, mirroring
//  `BluetoothHeartbeatManager` (which already proves CB-callback → MainActor
//  works in this app). Notifications are consumed in a MainActor task whose
//  `for await` hops each event off LibreCRKit's private BLE queue onto main; the
//  cheap per-minute decode runs inline on main; only the one-time auth crypto is
//  `await`-ed on the `PairingFlow` actor (off-main).
//
//  Single BLE owner: when `.libre3BLE` is active, `BluetoothHeartbeatManager` is
//  disabled (it gates itself off for this provider), so this is the only central
//  touching the sensor.
//

#if os(iOS)
import Foundation
import CoreBluetooth
import Security
import UIKit
import OSLog
import LibreCRKit

@MainActor
final class Libre3DirectManager: ObservableObject {

    static let shared = Libre3DirectManager()

    /// CoreBluetooth state-restoration identifier for this manager's central.
    /// Distinct from the heartbeat's (`…bluetoothHeartbeat`) so the two never
    /// collide; chosen in Phase 0.
    private static let restoreIdentifier = "de.poeml.philipp.LibreWrist.libre3Direct"

    /// 12 h of 1-min points is plenty for the home graph window; bounds memory.
    private static let maxBufferedReadings = 12 * 60

    // MARK: - Published state

    /// Drives the SwiftUI connect view. Every mutation also mirrors the engine's
    /// status into the app group (`didSet`) so the SHARED `Libre3DirectProvider`
    /// can read `isInErrorState` / `statusMessage` without naming this phone-only
    /// type (it compiles into the watch + widget targets too).
    @Published private(set) var connectionState: Libre3DirectConnectionState = .idle {
        didSet { publishStatusToAppGroup() }
    }
    /// Freshest displayable value (mg/dL), for the connect screen. `nil` until a
    /// reading is decoded.
    @Published private(set) var currentGlucoseMgDL: Int?

    // MARK: - Engine

    /// Created lazily on first `start()` so a cloud-only user (who never selects
    /// `.libre3BLE`) is never prompted for Bluetooth permission and never gets a
    /// second restoring central. Mirrors the heartbeat manager, which likewise
    /// only builds its `CBCentralManager` once enabled.
    private var scanner: SensorScanner?
    private var session: SensorSession?
    private var decoder: DataPlaneDecoder?
    private let assembler = DataPlaneNotificationAssembler()

    /// The single connect → authorize → stream driver. While non-nil a
    /// connection attempt or live stream is in flight.
    private var lifecycleTask: Task<Void, Never>?
    private var restorationTask: Task<Void, Never>?

    /// Rolling buffer of decoded realtime points (oldest → newest), keyed by
    /// `lifeCount` for de-duplication. Backfill of historical pages is Phase 4.
    private var recent: [LibreLinkUpGlucose] = []
    private var sensorStartDate: Date?

    private init() {
        // Observe runtime provider switches (Settings picker, or a WC settings
        // snapshot). Decoupled via NotificationCenter exactly like the heartbeat
        // manager, so this file stays out of the shared orchestrator.
        NotificationCenter.default.addObserver(
            forName: .activeCGMProviderDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.activeProviderChanged()
            }
        }
        // The shared provider's `reload()` posts this to kick the engine, rather
        // than calling us directly (it can't see this phone-only type).
        NotificationCenter.default.addObserver(
            forName: .libre3DirectReloadRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureConnected()
            }
        }
        sensorStartDate = SharedData.libre3SensorStartDate
        publishStatusToAppGroup()
    }

    /// Mirror the engine's current status into the app group so the shared
    /// `Libre3DirectProvider` can surface it without a compile-time dependency
    /// on this type.
    private func publishStatusToAppGroup() {
        SharedData.libre3EngineDidFail = connectionState.isError
        SharedData.libre3EngineStatusMessage = connectionState.message
    }

    // MARK: - Provider gating

    private var isActiveProvider: Bool { SharedData.cgmProviderKind == .libre3BLE }

    private func activeProviderChanged() {
        if isActiveProvider {
            start()
        } else {
            stop()
        }
    }

    // MARK: - Lifecycle control

    /// Called at app launch. Starts streaming only when `.libre3BLE` is the
    /// active provider; otherwise stays fully idle (no central created), so
    /// CoreBluetooth state restoration only ever resurrects the right one.
    func startIfNeeded() {
        guard isActiveProvider else { return }
        start()
    }

    /// Begin (or continue) connecting to the paired sensor and streaming.
    func start() {
        guard isActiveProvider else { return }
        guard Libre3StateStore.isPaired else {
            connectionState = .idle
            return
        }
        guard lifecycleTask == nil else { return }   // already running
        ensureScanner()
        observeRestorationIfNeeded()
        lifecycleTask = Task { [weak self] in
            await self?.runLifecycle()
        }
    }

    /// Tear down the connection and stop streaming (provider switched away, or
    /// the user disconnected the sensor).
    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        if let scanner, let session {
            scanner.disconnect(session)
        }
        session = nil
        decoder = nil
        assembler.reset()
        connectionState = .idle
    }

    /// Cheap "kick" entry point for `Libre3DirectProvider.reload()` — never does
    /// network I/O. Ensures a connection attempt is in flight; if already
    /// streaming, it's a no-op.
    func ensureConnected() {
        guard isActiveProvider else { return }
        if lifecycleTask == nil { start() }
    }

    /// Forget the in-memory session state after the stored sensor is cleared.
    /// (Credential clearing itself is `Libre3StateStore.clear()`.)
    func forgetSensor() {
        stop()
        recent.removeAll()
        sensorStartDate = nil
        currentGlucoseMgDL = nil
        SharedData.libre3SensorStartDate = nil
    }

    // MARK: - Status surfaced to the provider

    var isInErrorState: Bool { connectionState.isError }
    var statusMessage: String { connectionState.message }

    // MARK: - Connect → authorize → stream

    private func ensureScanner() {
        guard scanner == nil else { return }
        scanner = SensorScanner(
            configuration: .background(restorationIdentifier: Self.restoreIdentifier)
        )
    }

    /// Subscribe to CoreBluetooth state restoration once. On a background launch
    /// triggered by a sensor notification, iOS re-creates our central and hands
    /// back the restored peripheral; we just (re)start the lifecycle, which will
    /// retrieve and resume that peripheral by its saved identifier.
    private func observeRestorationIfNeeded() {
        guard restorationTask == nil, let scanner else { return }
        restorationTask = Task { [weak self] in
            for await event in scanner.restorationEvents() {
                guard let self else { return }
                Logger.libre3.info("Libre3 BLE state restoration: \(event.peripherals.count, privacy: .public) peripheral(s)")
                if self.isActiveProvider, Libre3StateStore.isPaired {
                    self.start()
                }
            }
        }
    }

    /// Runs the full connect loop, retrying with a bounded backoff until the
    /// task is cancelled (provider switch / disconnect). One iteration =
    /// connect → handshake → subscribe → stream-until-disconnect.
    private func runLifecycle() async {
        var backoff: UInt64 = 5
        while !Task.isCancelled {
            do {
                try await connectAuthorizeAndStream()
                // Returns when the notification stream ends (disconnect):
                // reset backoff and reconnect promptly.
                backoff = 5
            } catch is CancellationError {
                break
            } catch {
                Logger.libre3.error("Libre3 BLE lifecycle error: \(String(describing: error), privacy: .public)")
                connectionState = .failed(Self.friendlyMessage(for: error))
                try? await Task.sleep(nanoseconds: backoff * 1_000_000_000)
                backoff = min(backoff * 2, 60)
            }
            guard isActiveProvider, Libre3StateStore.isPaired else { break }
        }
        lifecycleTask = nil
    }

    private func connectAuthorizeAndStream() async throws {
        guard let scanner else { throw Libre3DirectError.notStarted }
        guard let sensorState = Libre3StateStore.loadState() else {
            throw Libre3DirectError.notPaired
        }

        // Keep the app alive long enough to complete the connect + auth burst if
        // iOS woke us in the background. Always ended (success / throw / expiry).
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "Libre3DirectAuth")
        defer {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }

        try await scanner.waitUntilReady()

        connectionState = .scanning
        let peripheral = try await discoverPeripheral(scanner: scanner)
        SharedData.libre3PeripheralUUID = peripheral.identifier.uuidString

        connectionState = .connecting
        let session = try await scanner.connect(peripheral)
        self.session = session

        connectionState = .authorizing
        let material = try await runHandshake(session: session, blePIN: sensorState.blePIN)
        let crypto = try DataPlaneCrypto(sessionMaterial: material)
        self.decoder = DataPlaneDecoder(crypto: crypto)
        assembler.reset()

        // Re-arm the data-plane CCCDs — the sensor stays silent until each
        // notify characteristic is cycled after the handshake.
        try await session.refreshDataPlaneNotifications()

        connectionState = .streaming
        Logger.libre3.info("Libre3 BLE streaming started for serial=\(sensorState.serialNumber ?? "?", privacy: .public)")

        try await consumeNotifications(session: session)
    }

    /// Find the paired sensor: prefer the saved peripheral identifier (no scan
    /// wait on reconnect); otherwise scan for the first sensor advertising the
    /// Libre service.
    private func discoverPeripheral(scanner: SensorScanner) async throws -> CBPeripheral {
        let savedUUID = SharedData.libre3PeripheralUUID
        if !savedUUID.isEmpty, let id = UUID(uuidString: savedUUID) {
            let known = await scanner.retrievePeripherals(withIdentifiers: [id])
            if let peripheral = known.first {
                return peripheral
            }
        }

        for await found in scanner.startScan() {
            scanner.stopScan()
            return found.peripheral
        }
        throw Libre3DirectError.sensorNotFound
    }

    /// Phase 1–6 first-pair authorization. All three NFC pairing modes
    /// (takeover / fresh / parallel-join) leave FLwatch holding its own BLE PIN,
    /// so each runs the command-gated *first-pair* handshake to derive its own
    /// session keys (the cached-reconnect / kAuth path is a Phase 5 optimization
    /// for subsequent connects). Phase 5 material is derived in-package from the
    /// bundled first-pair source plus our entropy.
    private func runHandshake(session: SensorSession, blePIN: Data) async throws -> Phase6SessionMaterial {
        let transport = SensorSessionTransport(session: session)
        // Use the v1 (`03 03`) app certificate from `Libre3SKBKeys`, NOT
        // LibreCRKit's bundled default `bundledFirstPair()` (the v0 `03 00`
        // cert). On a v1 sensor (fw 1.4.2.30, our test unit) the `03 00` cert is
        // rejected at the first gate (`CertificateAccepted` → immediate
        // disconnect) because `03 00`/`03 03` are version-keyed to the sensor's
        // security generation. Feeding the `03 03` cert also auto-selects the
        // matching index-1 Phase-5 static scalar (LibreCRKit's
        // `PhoneCert.phase5StaticScalarWindowOverride` keys off the `03 03`
        // prefix → `firstPairIndex1`). Verified end-to-end on hardware
        // (handshake → Phase 6 → live glucose). v0 sensors are NOT yet supported
        // (would need LibreCRKit's unfinished generic `03 00` derivation).
        //
        // `Libre3SKBKeys` is gitignored (extracted vendor key material), so it is
        // present locally but never committed. This file IS committed — keep the
        // only reference behind `#if canImport`-free direct use, which compiles
        // as long as the keys file exists in the target.
        let phoneCert = try PhoneCert(raw: Data(Libre3SKBKeys.appCertificateV1))

        // The Phase 3 phone ephemeral and the Phase 5 null entropy must come from
        // the SAME sampled entropy — first-pair derives the ephemeral keypair
        // *from* the null entropy, and the handshake later re-derives the expected
        // ephemeral public key from that entropy and checks it matches what we
        // sent in Phase 3. Generating them independently (random phoneEph + random
        // entropySource) trips `phase5EphemeralPublicKeyMismatch`. So: sample the
        // native ephemeral once, hand its keypair to PairingFlow, and feed the
        // handshake a FIXED entropy source returning that same null entropy
        // (maxEntropyAttempts: 1). Mirrors LibreCRKit's own harness
        // (`runFirstPairCandidateHandshake`) and the libre3BT sample app.
        let nativeEphemeral = try SessionKey.makeFirstPairNativeEphemeral { count in
            try Self.randomBytes(count)
        }
        let flow = PairingFlow(
            transport: transport,
            phoneCert: phoneCert,
            phoneEph: nativeEphemeral.keyPair,
            eventLogger: { message in
                Logger.libre3.debug("\(message, privacy: .public)")
            }
        )
        let result = try await flow.runCommandGatedFirstPairHandshake(
            blePIN: blePIN,
            maxEntropyAttempts: 1,
            entropySource: { count in
                try Self.fixedEntropy(nativeEphemeral.nullEntropy11A, count: count)
            }
        )
        return result.handshake.sessionMaterial
    }

    /// Fixed entropy source for the first-pair handshake: returns the exact
    /// null entropy already used to derive the Phase 3 ephemeral keypair, so the
    /// handshake's ephemeral-public-key consistency check passes. Mirrors the
    /// sample app's `fixedEntropySource`.
    private static func fixedEntropy(_ entropy: Data, count: Int) throws -> Data {
        guard count == entropy.count else {
            throw Libre3DirectError.entropySizeMismatch(expected: count, actual: entropy.count)
        }
        return entropy
    }

    /// MainActor notification pump. The `for await` hops each fragment off
    /// LibreCRKit's BLE queue onto main; assembling + decrypting one ~35-byte
    /// frame per minute is trivially cheap, so it rides main race-free (PLAN §6).
    /// Returns when the stream finishes (the session disconnected).
    private func consumeNotifications(session: SensorSession) async throws {
        for await event in session.notifications() {
            try Task.checkCancellation()
            guard let channel = DataPlaneChannel(uuidString: event.characteristic.uuidString) else {
                continue
            }
            guard let assembled = assembler.feed(fragment: event.fragment, channel: channel) else {
                continue   // waiting for the glucose suffix fragment
            }
            handle(assembled: assembled, channel: channel)
        }
    }

    private func handle(assembled: Data, channel: DataPlaneChannel) {
        guard let decoder else { return }
        do {
            let frame = try DataFrame.parse(assembled)
            let packet = try decoder.decrypt(frame: frame, channel: channel)
            switch packet.payload {
            case .realtimeGlucose(let reading):
                ingest(reading)
            case .patchStatus(let status):
                seedAnchorIfNeeded(lifeCount: Int(status.currentLifeCount))
            default:
                break   // historical / clinical pages are Phase 4
            }
        } catch {
            Logger.libre3.error("Libre3 BLE decode failed on \(channel.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Reading → history

    private func ingest(_ reading: RealtimeGlucoseReading) {
        seedAnchorIfNeeded(lifeCount: Int(reading.lifeCount))
        guard let anchor = sensorStartDate else { return }

        let settings = SensorSettingsStore.shared.sensorSettings
        guard let mapped = Libre3GlucoseMapper.makeGlucose(
            from: reading,
            sensorStartDate: anchor,
            settings: settings
        ) else {
            // Not displayable (warm-up / error / out of range): keep the link up
            // but don't surface a value.
            Logger.libre3.info("Libre3 BLE reading not displayable (lifeCount=\(reading.lifeCount, privacy: .public))")
            return
        }

        appendDeduped(mapped)
        currentGlucoseMgDL = mapped.glucose.value
        persistLastAccepted(reading)
        pushToHistory(latest: mapped)
    }

    /// Derive the wall-clock sensor-start anchor once (`now − lifeCount·60s`) and
    /// persist it so timestamps stay stable across reconnects (PLAN §8).
    private func seedAnchorIfNeeded(lifeCount: Int) {
        guard sensorStartDate == nil, lifeCount > 0 else { return }
        let anchor = Date().addingTimeInterval(-Double(lifeCount) * 60)
        sensorStartDate = anchor
        SharedData.libre3SensorStartDate = anchor
    }

    /// Insert keeping the buffer sorted oldest→newest and de-duplicated by id
    /// (`lifeCount`): a repeated reading replaces in place rather than appending.
    private func appendDeduped(_ point: LibreLinkUpGlucose) {
        if let last = recent.last, last.glucose.id == point.glucose.id {
            recent[recent.count - 1] = point
        } else {
            recent.append(point)
        }
        if recent.count > Self.maxBufferedReadings {
            recent.removeFirst(recent.count - Self.maxBufferedReadings)
        }
    }

    private func persistLastAccepted(_ reading: RealtimeGlucoseReading) {
        SharedData.libre3LastLifeCount = Int(reading.lifeCount)
        SharedData.libre3LastGlucoseMgDL = reading.currentGlucoseMgDL.map(Int.init) ?? 0
    }

    /// Write the rolling buffer into the universal sink, mirroring
    /// `DexcomShareProvider.applyEntries`. Libre is 1-min cadence so — unlike
    /// Dexcom — the minute stream is populated (smooth overlay). The graph
    /// window is the last 12 h held in `recent`.
    private func pushToHistory(latest: LibreLinkUpGlucose) {
        let maxBG = recent.map { $0.glucose.value }.max() ?? 250
        _ = LibreLinkUpHistory.shared.replaceCacheAndPersist(
            fullLibreLinkUpGlucose: recent,
            libreLinkUpGlucose: recent,
            libreLinkUpMinuteGlucose: recent,
            latestLibreLinkUpGlucose: latest,
            lastReadingDate: latest.glucose.date,
            currentGlucose: latest.glucose.value,
            currentTrendArrow: latest.trendArrow?.symbol ?? "---",
            maxBG: maxBG,
            lastSuccessfulLibreLinkUpAPICall: Date()
        )
    }

    // MARK: - Helpers

    private static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw Libre3DirectError.entropyUnavailable(status)
        }
        return Data(bytes)
    }

    private static func friendlyMessage(for error: Error) -> String {
        switch error {
        case Libre3DirectError.notPaired, Libre3DirectError.notStarted:
            return String(localized: "No sensor is paired.")
        case Libre3DirectError.sensorNotFound:
            return String(localized: "Couldn't find the sensor. Keep your phone near it.")
        case SensorScannerError.bluetoothPoweredOff:
            return String(localized: "Bluetooth is turned off.")
        case SensorScannerError.bluetoothUnauthorized:
            return String(localized: "Bluetooth permission is needed to read the sensor.")
        default:
            return String(localized: "Connection lost. Reconnecting…")
        }
    }
}

enum Libre3DirectError: Error {
    case notStarted
    case notPaired
    case sensorNotFound
    case entropyUnavailable(OSStatus)
    case entropySizeMismatch(expected: Int, actual: Int)
}
#endif
