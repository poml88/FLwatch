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
    /// Minutes left in the ~60-min warm-up while the sensor is warming up; `nil`
    /// once warm-up completes (or before the first lifecycle is known). Drives the
    /// "warming up" countdown in the connect view and gates display of garbage
    /// warm-up readings.
    @Published private(set) var warmupRemainingMinutes: Int?
    /// True once the sensor has passed its rated wear duration.
    @Published private(set) var sensorIsExpired = false

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
    private var stateTask: Task<Void, Never>?
    private var connectionEventTask: Task<Void, Never>?

    /// Two parallel series mirroring the LibreLinkUp model (see `LibreLinkUp.swift`):
    ///
    /// * `historicalByLifeCount` — the 5-minute graph series (sensor's downsampled
    ///   record), seeded by backfill pages and extended by the embedded historical
    ///   sample carried in each realtime reading (~15–20 min behind now). This is
    ///   the persistent graph base, filtered to the 6 h 10 m display window.
    /// * `minuteByLifeCount` — the per-minute realtime readings that fill the gap
    ///   between the last historical point (~20 min old) and now. Trimmed to those
    ///   newer than the last historical point, exactly like LibreLinkUp's `trend`.
    ///
    /// Both keyed by `lifeCount` (minutes since activation) for de-duplication.
    private var historicalByLifeCount: [Int: LibreLinkUpGlucose] = [:]
    private var minuteByLifeCount: [Int: LibreLinkUpGlucose] = [:]
    private var sensorStartDate: Date?

    /// Display window we keep + show: 6 h 10 m, matching the LibreLinkUp graph
    /// filter (`dateSixHoursTenAgo`).
    private static let displayWindowSeconds: TimeInterval = 6 * 60 * 60 + 10 * 60
    /// Bound the persisted historical series to ~12 h so the buffer can't grow
    /// without limit while still covering the display window after trimming.
    private static let historicalRetentionSeconds: TimeInterval = 12 * 60 * 60
    /// How long per-minute points are retained (bounds the buffer). The minute
    /// overlay shows points newer than the last historical sample; this only caps
    /// memory — it must NOT be used to drop recent points when history lags, which
    /// would wipe the whole overlay.
    private static let minuteRetentionMinutes = 90

    /// Accumulates patch status + realtime + historical pages and computes the
    /// per-reading quality assessment + lifecycle (warm-up / expiry) used to gate
    /// what we surface. Created per connection from the persisted sensor
    /// lifecycle fields. `nil` until the handshake completes.
    private var dataPlaneState: Libre3DataPlaneState?

    /// Guards the once-per-connection historical backfill request, fired after the
    /// first data-plane packet yields a reliable current life count.
    private var didRequestBackfill = false

    /// Set when a cached/direct reconnect is rejected (the sensor drops the
    /// link), so the NEXT connect attempt skips the cached path and runs a full
    /// handshake on its fresh connection. Reset whenever a full handshake runs.
    private var skipCachedReconnectOnce = false

    /// The newest historical (5-min) lifeCount we already held when this
    /// connection started — i.e. the persisted-store seed, captured BEFORE the
    /// realtime stream begins folding in fresh embedded historical samples. This
    /// is the backfill resume point ("gap since the last history reading"); using
    /// the live buffer max instead would resume from a sample harvested seconds
    /// ago and fetch almost nothing.
    private var backfillResumeLifeCount: UInt16?

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
        // Assign the lifecycle task BEFORE wiring the observers: the state
        // observer yields the current power state immediately on subscribe and
        // may re-enter `start()`, which must see a non-nil task and no-op rather
        // than spawn a duplicate.
        lifecycleTask = Task { [weak self] in
            await self?.runLifecycle()
        }
        observeRestorationIfNeeded()
        observeBluetoothStateIfNeeded()
        observeConnectionEventsIfNeeded()
    }

    /// Tear down the connection and stop streaming (provider switched away, or
    /// the user disconnected the sensor).
    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        restorationTask?.cancel()
        restorationTask = nil
        stateTask?.cancel()
        stateTask = nil
        connectionEventTask?.cancel()
        connectionEventTask = nil
        if let scanner, let session {
            scanner.disconnect(session)
        }
        session = nil
        decoder = nil
        dataPlaneState = nil
        didRequestBackfill = false
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
        historicalByLifeCount.removeAll()
        minuteByLifeCount.removeAll()
        backfillResumeLifeCount = nil
        sensorStartDate = nil
        currentGlucoseMgDL = nil
        warmupRemainingMinutes = nil
        sensorIsExpired = false
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

    /// Observe Bluetooth power transitions. This is essential for reconnect:
    /// when the user turns Bluetooth OFF, iOS transitions the central to
    /// `poweredOff` but does NOT deliver a peripheral disconnect, so the
    /// `notifications()` stream never finishes and `consumeNotifications` would
    /// hang forever — streaming silently dies with no recovery. So we tear the
    /// stuck session down on power-loss and restart it when power returns.
    private func observeBluetoothStateIfNeeded() {
        guard stateTask == nil, let scanner else { return }
        stateTask = Task { [weak self] in
            for await state in scanner.stateEvents() {
                guard let self else { return }
                if state == .poweredOn {
                    if self.isActiveProvider, Libre3StateStore.isPaired, self.lifecycleTask == nil {
                        Logger.libre3.info("Libre3 BLE: Bluetooth powered on — reconnecting")
                        self.start()
                    }
                } else if self.lifecycleTask != nil {
                    Logger.libre3.info("Libre3 BLE: Bluetooth unavailable (\(String(describing: state), privacy: .public)) — tearing down session")
                    self.teardownForReconnect()
                }
            }
        }
    }

    /// Observe CoreBluetooth connection events (registered per-peripheral in
    /// `connectAuthorizeAndStream`). When the app is suspended the backoff
    /// reconnect loop can't run, so a background range-loss recovery relies on
    /// iOS waking us with a `.peerConnected` event for the known peripheral —
    /// at which point we (re)start the lifecycle if it isn't already running.
    private func observeConnectionEventsIfNeeded() {
        guard connectionEventTask == nil, let scanner else { return }
        connectionEventTask = Task { [weak self] in
            for await event in scanner.connectionEvents() {
                guard let self else { return }
                guard event.event == .peerConnected else { continue }
                if self.isActiveProvider, Libre3StateStore.isPaired, self.lifecycleTask == nil {
                    Logger.libre3.info("Libre3 BLE: peripheral connection event — reconnecting")
                    self.start()
                }
            }
        }
    }

    /// Cancel the in-flight session (otherwise stuck in `consumeNotifications`,
    /// since a Bluetooth power-off yields no disconnect) and drop session state,
    /// leaving the manager ready to reconnect on the next power-on. Unlike
    /// `stop()` it keeps the restoration/state observers alive so we can come
    /// back automatically.
    private func teardownForReconnect() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        // Don't call `scanner.disconnect(session)` here: this runs only when
        // Bluetooth has gone UN-available (the state observer's non-poweredOn
        // branch), so the OS has already dropped the link and
        // `cancelPeripheralConnection` on a powered-off central is an API misuse
        // ("can only accept this command while in the powered on state"). Just
        // drop our references; the next power-on reconnect's `ensureDisconnected`
        // clears any phantom peripheral state.
        session = nil
        decoder = nil
        dataPlaneState = nil
        didRequestBackfill = false
        assembler.reset()
        currentGlucoseMgDL = nil
        warmupRemainingMinutes = nil
        connectionState = .failed(String(localized: "Bluetooth is turned off."))
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
        // Only clear when we exited on our own terms (unpaired / provider
        // switch). When cancelled by `stop()` / `teardownForReconnect()` those
        // callers own `lifecycleTask` and may have already assigned a fresh task
        // — clearing here would clobber it.
        if !Task.isCancelled {
            lifecycleTask = nil
        }
    }

    private func connectAuthorizeAndStream() async throws {
        guard let scanner else { throw Libre3DirectError.notStarted }
        guard let sensorState = Libre3StateStore.loadState() else {
            throw Libre3DirectError.notPaired
        }

        try await scanner.waitUntilReady()

        connectionState = .scanning
        let peripheral = try await discoverPeripheral(scanner: scanner)
        SharedData.libre3PeripheralUUID = peripheral.identifier.uuidString

        // First-attempt-drop fix (PLAN Phase 5): after a disconnect or state
        // restoration iOS may still report the peripheral `.connected`, so
        // `scanner.connect` skips `central.connect` and the handshake then runs
        // over a half-dead link — which reliably drops right after
        // StartAuthentication and only succeeds on the retry. Force a clean
        // `.disconnected` state first (a no-op/quick return when already
        // disconnected) so `connect` re-establishes a fresh link every time.
        await scanner.ensureDisconnected(peripheralID: peripheral.identifier)

        connectionState = .connecting
        let session = try await scanner.connect(peripheral)
        self.session = session
        // Ask iOS to wake us when it next sees this peripheral after a
        // background range loss, so reconnect doesn't rely solely on the
        // backoff loop running (it won't while suspended).
        scanner.registerForConnectionEvents(peripheralIDs: [peripheral.identifier])

        // Wrap ONLY the auth handshake burst in a background task — NOT the slow
        // `scanner.connect` above, which can wait ~30s for the Libre 3's
        // once-per-minute connection window. bluetooth-central keeps the pending
        // connect alive and wakes us on didConnect, so the wait needs no task;
        // holding one across it just trips iOS's 30s "risk of termination"
        // warning. Auth is a few seconds of paced BLE round-trips plus the
        // one-time Phase-5 scalar derivation, which must run without suspension.
        // Ended the moment streaming starts (below); the defer is the safety net
        // for the early-throw paths.
        var bgTask = UIApplication.shared.beginBackgroundTask(withName: "Libre3DirectAuth")
        defer {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        connectionState = .authorizing
        let sessionMaterial = try await authorize(session: session, sensorState: sensorState)
        let crypto = try DataPlaneCrypto(sessionMaterial: sessionMaterial)
        self.decoder = DataPlaneDecoder(crypto: crypto)
        assembler.reset()

        // Seed the data-plane state with the persisted lifecycle (warm-up /
        // wear) + last accepted reading so quality gating and reconnect backfill
        // work from the first packet.
        let savedLastLifeCount = SharedData.libre3LastLifeCount > 0
            ? UInt16(clamping: SharedData.libre3LastLifeCount) : nil
        dataPlaneState = Libre3DataPlaneState(
            warmupDurationMinutes: SharedData.libre3WarmupMinutes,
            wearDurationMinutes: SharedData.libre3WearDurationMinutes > 0
                ? SharedData.libre3WearDurationMinutes : nil,
            lastAcceptedGlucoseLifeCount: savedLastLifeCount,
            lastAcceptedGlucoseMgDL: SharedData.libre3LastGlucoseMgDL > 0
                ? UInt16(clamping: SharedData.libre3LastGlucoseMgDL) : nil
        )

        // Seed BOTH series from the persisted store so the first push after a
        // relaunch / reconnect doesn't overwrite the store with empty arrays (the
        // buffers are empty on a fresh manager — e.g. an app restart often pushes
        // a backfill page before any realtime reading, which would otherwise wipe
        // the persisted minute glucose). Backfill + realtime then merge on top.
        // Restricted to our own source so a previous provider's points are never
        // resurfaced.
        let persistedMinute = LibreLinkUpHistory.shared.libreLinkUpMinuteGlucose
            .filter { $0.glucose.source == "Libre3 BLE" }
        if historicalByLifeCount.isEmpty {
            // `fullLibreLinkUpGlucose` carries the injected live minute reading as
            // its newest element (see pushHistory). Exclude anything that's a minute
            // point so the pure 5-min series isn't polluted with a 1-min point no
            // future 5-min sample would replace.
            let minuteIDs = Set(persistedMinute.map { $0.glucose.id })
            for point in LibreLinkUpHistory.shared.fullLibreLinkUpGlucose
            where point.glucose.source == "Libre3 BLE" && !minuteIDs.contains(point.glucose.id) {
                historicalByLifeCount[point.glucose.id] = point
            }
        }
        if minuteByLifeCount.isEmpty {
            for point in persistedMinute {
                minuteByLifeCount[point.glucose.id] = point
            }
        }
        // Capture the resume point now, before realtime readings start adding
        // their embedded (~16-min-old) historical samples — otherwise the backfill
        // would resume from one of those and fetch only the last page.
        backfillResumeLifeCount = historicalByLifeCount.keys.max().map { UInt16(clamping: $0) }

        // Re-arm the data-plane CCCDs — the sensor stays silent until each notify
        // characteristic is cycled after the handshake. This is LibreCRKit's
        // validated default set (the config that completes Phase 6 and streams on
        // our test sensor). historicData/clinicalData are armed transiently inside
        // the backfill path only, so the baseline handshake/stream is untouched.
        try await session.refreshDataPlaneNotifications()

        // Stamp the sensor model now that we're authorized (mirrors how the
        // Dexcom/LLU providers set the type on connect).
        Libre3StateStore.stampSensorType()
        // Wire the graph's red low-alarm line from the notification settings,
        // like the Dexcom login path — the direct stream carries no alarm
        // thresholds of its own.
        applyManualAlarmWiring()

        // Backfill is fired from `handle(...)` after the FIRST data-plane packet,
        // once we know the real current life count (matching the sample, which
        // fires from its notification handler). Firing here with a guessed life
        // count produced `from=0`, which the patch ignores.
        didRequestBackfill = false

        connectionState = .streaming
        Logger.libre3.info("Libre3 BLE streaming started for serial=\(sensorState.serialNumber ?? "?", privacy: .public)")

        // Tell the watch the BLE sensor is paired + active (provider kind +
        // serial), so its provider-account gate opens and it renders the glucose
        // snapshots we push. Covers pair / reconnect / state restoration.
        WatchConnectivityManager.shared.sendSettingsSnapshotToWatch()

        // End the connect/auth background task BEFORE the long-lived streaming
        // loop. Streaming is sustained by the `bluetooth-central` background mode
        // (each glucoseData notification wakes the app), NOT by a UIBackgroundTask
        // — which iOS expires after a few minutes and then flags the app for
        // termination ("Background task still not ended after expiration handlers
        // were called"). Holding it across the whole session was the bug.
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        try await consumeNotifications(session: session)
    }

    /// On-demand historical backfill (the `patchControl` write), modelled on
    /// Juggluco's `fillHistory` (`Libre3GattCallback.receivedpatchstatus` →
    /// `Natives.libre3ControlHistory(1, max(lastReceived, 5))`, byte-identical to
    /// our command).
    ///
    /// The earlier breakage was NOT this write: it was adding `historicData`/
    /// `clinicalData` to LibreCRKit's off→on *refresh cycle* (disable-then-enable),
    /// which Juggluco never does — it only plain-enables them. That's reverted, so
    /// the historic channel is now plain-enabled transiently inside the backfill
    /// path (matching Juggluco), and an earlier run with exactly this shape
    /// streamed fine. Fired once after the first patch status, `from = max(5, …)`.
    private static let onDemandBackfillEnabled = true

    /// Request the one-shot historical backfill once, after the first data-plane
    /// packet has given us a reliable current life count. `from` resumes at the
    /// saved last reading (gap fill; the rest is seeded from the persisted store)
    /// or 6 h back on a first-ever connect — never 0 (the patch ignores that).
    private func requestBackfillIfNeeded(currentLifeCount: Int) {
        guard Self.onDemandBackfillEnabled else { return }
        guard !didRequestBackfill, currentLifeCount > 0,
              let session, let crypto = decoder?.crypto else { return }
        didRequestBackfill = true
        // Resume from the history we held at connect time (the persisted seed),
        // NOT the live buffer — which already contains this session's freshly
        // harvested embedded samples. Fetch only the gap, capped at 6 h 10 m.
        let from = Libre3BackfillImporter.backfillStartLifeCount(
            lastHistoricalLifeCount: backfillResumeLifeCount,
            currentLifeCount: UInt16(clamping: currentLifeCount)
        )
        Task { [weak self] in
            do {
                try await Libre3BackfillImporter.requestHistoricalBackfill(
                    session: session, crypto: crypto, fromLifeCount: from
                )
            } catch {
                self?.didRequestBackfill = false   // allow a retry on the next packet
                Logger.libre3.error("Libre3 BLE historical backfill request failed: \(String(describing: error), privacy: .public)")
            }
        }
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

    /// Authorize the freshly-connected session. Prefers the fast cached/direct
    /// reconnect (PLAN Phase 5) when we hold a reconnect key from a prior full
    /// pair, and falls back to the full command-gated first-pair handshake on
    /// any failure before Phase 6. Returns the Phase-6 session material the
    /// data-plane decoder needs.
    private func authorize(session: SensorSession, sensorState: Libre3SensorState) async throws -> Phase6SessionMaterial {
        if !skipCachedReconnectOnce, let reconnectKey = Libre3StateStore.loadReconnectKey() {
            do {
                let material = try await runCachedReconnect(
                    session: session, blePIN: sensorState.blePIN, reconnectKey: reconnectKey
                )
                Logger.libre3.info("Libre3 BLE cached reconnect succeeded")
                return material
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Cached reconnect rejected. The sensor DROPS the link on a bad
                // Phase 5 (observed on hardware), so the full handshake can't run
                // on this dead connection. Skip cached on the next attempt and
                // rethrow so the lifecycle reconnects FRESH and runs a full pair
                // (which re-establishes — and re-persists — the reconnect key).
                Logger.libre3.info("Libre3 BLE cached reconnect failed (\(String(describing: error), privacy: .public)) — reconnecting fresh for a full handshake")
                skipCachedReconnectOnce = true
                throw error
            }
        }
        skipCachedReconnectOnce = false
        let result = try await runHandshake(session: session, blePIN: sensorState.blePIN)
        // Persist this full pair's established Phase-5 raw key for the cached
        // reconnect fast path. This is the key the sensor accepts on the
        // cert/ephemeral-less reconnect — NOT the Phase-6 data-plane kEnc, which
        // hardware rejected (the sensor disconnected). The cached/direct path
        // skips the ephemeral ECDH precisely because this authorization key is
        // already established on both sides, so it reuses the same rawKey.
        Libre3StateStore.saveReconnectKey(result.phase5Material.rawKey)
        return result.handshake.sessionMaterial
    }

    /// Cached/direct reconnect: `0x11 StartAuthorization` → R1/nonce notify →
    /// Phase 5 → Phase 6, skipping the certificate + ephemeral exchange (PLAN
    /// Phase 5; LibreCRKit `runCachedReconnectHandshake`). The persisted
    /// Phase-6 kEnc is fed straight in as the Phase-5 raw key — matching
    /// LibreCRKit's `runTakeoverHandshake` default (`{ $0.kEnc }`) and
    /// Juggluco's reuse of its exported authorization material. We don't hold an
    /// Android-style 149-byte kAuth blob (a first-pair never produces one), so
    /// kEnc is the only cached key available — and the right one. Throws on
    /// sensor rejection so `authorize` can fall back to the full handshake.
    private func runCachedReconnect(session: SensorSession, blePIN: Data, reconnectKey: Data) async throws -> Phase6SessionMaterial {
        let transport = SensorSessionTransport(session: session)
        let flow = PairingFlow(
            transport: transport,
            eventLogger: { message in
                Logger.libre3.debug("\(message, privacy: .public)")
            }
        )
        let result = try await flow.runCachedReconnectHandshake(
            tail4: blePIN,
            phase5RawKey: reconnectKey
        )
        return result.sessionMaterial
    }

    /// Phase 1–6 first-pair authorization. All three NFC pairing modes
    /// (takeover / fresh / parallel-join) leave FLwatch holding its own BLE PIN,
    /// so each runs the command-gated *first-pair* handshake to derive its own
    /// session keys. The cached-reconnect path above is the Phase 5 fast path
    /// for subsequent connects. Phase 5 material is derived in-package from the
    /// bundled first-pair source plus our entropy. Returns the full derived
    /// result so the caller can persist `phase5Material.rawKey` — the
    /// established Phase-5 authorization key reused by the cached reconnect.
    private func runHandshake(session: SensorSession, blePIN: Data) async throws -> FirstPairDerivedHandshakeResult {
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
        return result
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
            // Diagnostic: surface the rarer channels (history/clinical/event/
            // factory) so we can confirm a backfill burst actually arrives,
            // separately from whether it decodes into a page below.
            switch channel {
            case .glucoseData, .patchStatus:
                break
            default:
                Logger.libre3.info("Libre3 BLE notify on \(channel.rawValue, privacy: .public): \(event.fragment.count, privacy: .public)B")
            }
            guard let assembled = assembler.feed(fragment: event.fragment, channel: channel) else {
                continue   // waiting for the glucose suffix fragment
            }
            handle(assembled: assembled, channel: channel)
        }
    }

    private func handle(assembled: Data, channel: DataPlaneChannel) {
        guard let decoder, var state = dataPlaneState else { return }
        do {
            let frame = try DataFrame.parse(assembled)
            let packet = try decoder.decrypt(frame: frame, channel: channel)
            let update = state.record(packet)
            dataPlaneState = state
            // Patch status carries the authoritative lifecycle; until the first
            // one arrives, fall back to one derived from the sensor-start anchor
            // so warm-up gating works from the very first realtime reading.
            let lifecycle = state.latestLifecycle ?? fallbackLifecycle()
            if let lifecycle { applyLifecycle(lifecycle) }
            switch update {
            case .realtimeGlucose(let reading, let recordedAssessment):
                // Re-assess with the fallback lifecycle when patch status hasn't
                // landed yet (record()'s assessment then lacks warm-up/expiry).
                let assessment = state.latestLifecycle != nil
                    ? recordedAssessment
                    : reading.currentGlucoseQualityAssessment(lifecycle: lifecycle)
                ingest(reading, assessment: assessment)
            case .historicalReadingPage(let page):
                ingestHistorical(page)
            case .patchStatus, .clinicalReadingRecord, .raw:
                break
            }
            // Once we have a real current life count (from patch status, else the
            // latest realtime reading), fire the one-shot backfill — mirroring the
            // sample, which requests it from its notification handler rather than
            // up front with a guessed life count.
            if !didRequestBackfill {
                let currentLifeCount = state.latestPatchStatus.map { Int($0.currentLifeCount) }
                    ?? state.latestRealtimeGlucose.map { Int($0.lifeCount) }
                if let currentLifeCount {
                    requestBackfillIfNeeded(currentLifeCount: currentLifeCount)
                }
            }
        } catch {
            Logger.libre3.error("Libre3 BLE decode failed on \(channel.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Reading → history

    /// Quality-gated realtime ingest. Readings the library flags as not usable
    /// (warm-up, sensor error, out of range, not actionable) update the lifecycle
    /// UI but are NOT surfaced — that's the "suppress garbage during warm-up"
    /// rule (PLAN Phase 4).
    private func ingest(_ reading: RealtimeGlucoseReading, assessment: Libre3GlucoseQualityAssessment) {
        seedAnchorIfNeeded(lifeCount: Int(reading.lifeCount))
        guard let anchor = sensorStartDate else { return }
        let settings = SensorSettingsStore.shared.sensorSettings

        // The embedded 5-minute historical sample (~15–20 min behind now) extends
        // the graph series even when no on-demand backfill arrives. It carries its
        // own data-quality, independent of the current value's usability.
        if let historical = Libre3GlucoseMapper.makeGlucose(
            fromEmbeddedHistorical: reading,
            sensorStartDate: anchor,
            settings: settings
        ) {
            historicalByLifeCount[historical.glucose.id] = historical
        }

        guard assessment.isUsable else {
            Logger.libre3.info("Libre3 BLE reading not usable (lifeCount=\(reading.lifeCount, privacy: .public)): \(String(describing: assessment.issues), privacy: .public)")
            // Still push so the embedded historical point (if any) reaches the graph.
            pushHistory()
            return
        }
        guard let mapped = Libre3GlucoseMapper.makeGlucose(
            from: reading,
            sensorStartDate: anchor,
            settings: settings
        ) else { return }

        minuteByLifeCount[mapped.glucose.id] = mapped
        currentGlucoseMgDL = mapped.glucose.value
        persistLastAccepted(reading)
        pushHistory()
        refreshLiveActivityForNewReading()
        evaluateLowGlucoseForNewReading()
    }

    /// Drive the low-glucose alert from the push model's data tick. In BLE mode
    /// there's no heartbeat coordinator to call `evaluateCurrentReading` (the
    /// cloud path's trigger — `BluetoothHeartbeatManager`), so we fire it here
    /// the moment a fresh *usable* minute reading has been written into the
    /// shared `LibreLinkUpHistory` store by `pushHistory()`.
    ///
    /// `LowGlucoseNotificationManager` is provider-agnostic — it reads the shared
    /// history + `activeProvider.staleReadingAfter` (3 min for `.libre3BLE`) and
    /// self-gates on the enabled flag and its own 5-minute repeat throttle — so
    /// it needs no Libre-3-specific knowledge. Only called on a usable reading
    /// (not warm-up/garbage, not per backfill page), mirroring
    /// `refreshLiveActivityForNewReading`.
    private func evaluateLowGlucoseForNewReading() {
        Task {
            await LowGlucoseNotificationManager.shared.evaluateCurrentReading()
        }
    }

    /// Refresh the phone's Live Activity the moment a new usable minute reading
    /// lands (the push-model "data tick"), instead of waiting for the home
    /// view's independent ~63 s foreground timer — which drifts against the
    /// sensor's ~60 s cadence and made the Live Activity skip a reading
    /// ("updates at minute 2"), and doesn't run at all while backgrounded. This
    /// mirrors the cloud path, where the heartbeat refreshes the Live Activity
    /// on each data tick (`BluetoothHeartbeatManager`). Only called on a usable
    /// realtime reading — NOT per backfill page (a burst would refresh many
    /// times) and NOT for warm-up/garbage readings. Live Activity updates are
    /// local (`Activity.update`), not budget-limited like push updates, so the
    /// per-minute cadence is fine; we deliberately do NOT `reloadAllTimelines()`
    /// here (that WOULD burn the widget budget — see `BluetoothHeartbeatManager`).
    private func refreshLiveActivityForNewReading() {
        Task {
            await LiveActivityManager.shared.refreshFromCurrentHistory(
                useLiveActivities: SharedData.useLiveActivities,
                refreshIOB: false
            )
        }
    }

    /// Fold an on-demand backfill page (5-min-spaced samples) into the historical
    /// series to seed the graph window. Displayable samples only.
    private func ingestHistorical(_ page: HistoricalReadingPage) {
        guard let anchor = sensorStartDate else {
            Logger.libre3.info("Libre3 BLE backfill page dropped (no anchor yet): lc \(page.startLifeCount, privacy: .public)..\(page.endLifeCount, privacy: .public)")
            return
        }
        let settings = SensorSettingsStore.shared.sensorSettings
        var added = 0
        for sample in page.samples {
            if let mapped = Libre3GlucoseMapper.makeGlucose(fromHistorical: sample, sensorStartDate: anchor, settings: settings) {
                historicalByLifeCount[mapped.glucose.id] = mapped
                added += 1
            }
        }
        Logger.libre3.info("Libre3 BLE backfill page lc \(page.startLifeCount, privacy: .public)..\(page.endLifeCount, privacy: .public): \(page.values.count, privacy: .public) samples, \(added, privacy: .public) displayable")
        guard added > 0 else { return }
        pushHistory()
    }

    /// Apply the decoded lifecycle to the published warm-up / expiry state.
    private func applyLifecycle(_ lifecycle: SensorLifecycle) {
        seedAnchorIfNeeded(lifeCount: lifecycle.currentLifeCountMinutes)
        warmupRemainingMinutes = lifecycle.isWarmingUp ? lifecycle.remainingWarmupMinutes : nil
        sensorIsExpired = lifecycle.isExpired
    }

    /// Lifecycle derived from the wall-clock anchor + persisted warm-up/wear
    /// durations, used to gate readings until the sensor's first patch status
    /// (which carries the authoritative life count) arrives.
    private func fallbackLifecycle() -> SensorLifecycle? {
        guard let anchor = sensorStartDate else { return nil }
        let elapsed = Int(Date().timeIntervalSince(anchor) / 60)
        let wear = SharedData.libre3WearDurationMinutes
        return SensorLifecycle(
            currentLifeCountMinutes: max(0, elapsed),
            warmupDurationMinutes: SharedData.libre3WarmupMinutes,
            wearDurationMinutes: wear > 0 ? wear : nil
        )
    }

    /// Derive the wall-clock sensor-start anchor once (`now − lifeCount·60s`) and
    /// persist it so timestamps stay stable across reconnects (PLAN §8).
    private func seedAnchorIfNeeded(lifeCount: Int) {
        guard sensorStartDate == nil, lifeCount > 0 else { return }
        let anchor = Date().addingTimeInterval(-Double(lifeCount) * 60)
        sensorStartDate = anchor
        SharedData.libre3SensorStartDate = anchor
    }

    /// Wire the graph's red low-alarm line from the low-glucose notification
    /// settings, mirroring the Dexcom login path (`DexcomShareProvider`): the
    /// direct BLE stream carries no alarm thresholds of its own, so the alarm
    /// line tracks the notification threshold when low alerts are on and is
    /// hidden (sentinel) otherwise. The user's unit + target choices (set in
    /// Settings) are preserved. Run on each connect so the line is correct even
    /// before the user opens Settings — e.g. right after switching to
    /// `.libre3BLE` with settings left over from another provider. The Settings
    /// UI keeps it live afterwards (`persistManualSensorSettings`).
    private func applyManualAlarmWiring() {
        let existing = SensorSettingsStore.shared.sensorSettings
        let alarms = SensorSettings.manualAlarms(
            notificationsEnabled: SharedData.lowGlucoseNotificationsEnabled,
            threshold: SharedData.lowGlucoseNotificationThreshold
        )
        let updated = SensorSettings(
            uom: existing.uom,
            targetLow: existing.targetLow,
            targetHigh: existing.targetHigh,
            alarmLow: alarms.low,
            alarmHigh: alarms.high
        )
        guard updated != existing else { return }
        _ = SensorSettingsStore.shared.updateSensorSettings(updated)
    }

    private func persistLastAccepted(_ reading: RealtimeGlucoseReading) {
        SharedData.libre3LastLifeCount = Int(reading.lifeCount)
        SharedData.libre3LastGlucoseMgDL = reading.currentGlucoseMgDL.map(Int.init) ?? 0
    }

    /// Build the two display series and write them into the universal sink,
    /// mirroring the LibreLinkUp model (see `LibreLinkUp.swift`):
    ///
    /// * `fullLibreLinkUpGlucose` / `libreLinkUpGlucose` — the 5-minute historical
    ///   series (the graph), the latter filtered to the 6 h 10 m display window.
    /// * `libreLinkUpMinuteGlucose` — the per-minute realtime points filling the
    ///   gap from the last historical point (~20 min old) to now, trimmed to those
    ///   newer than it (and within a 60-minute cap), so nothing duplicates the
    ///   graph once history catches up.
    /// * latest / current = the freshest realtime minute value (else newest
    ///   historical, before any realtime has arrived).
    private func pushHistory() {
        pruneBuffers()

        // ALL arrays are stored NEWEST-FIRST (descending), matching the
        // Dexcom/LibreLinkUp convention (`fullHistoryNewestFirst`,
        // `graphHistoryReversed`, `lastMeasurement = [0]`). The watch's
        // `mergeMinuteGlucose` and other consumers index `[0]`/`[1]` as the
        // newest/second-newest; storing ascending here broke that (it left a
        // stale minute point because `[1]` was the second-OLDEST graph point).
        let historicalNewestFirst = historicalByLifeCount.values.sorted { $0.glucose.id > $1.glucose.id }
        let newestHistoricalID = historicalNewestFirst.first?.glucose.id
        let windowStart = Date().addingTimeInterval(-Self.displayWindowSeconds)

        // Minute overlay: 1-min points newer than the newest 5-min historical
        // value (older ones are covered by the 5-min line). Memory is bounded by
        // `pruneBuffers`.
        let minuteNewestFirst: [LibreLinkUpGlucose]
        if let newestHistoricalID {
            minuteNewestFirst = minuteByLifeCount.values
                .filter { $0.glucose.id > newestHistoricalID }
                .sorted { $0.glucose.id > $1.glucose.id }
        } else {
            // No historical series yet (cold start before backfill / embedded
            // history): show the realtime minute points alone.
            minuteNewestFirst = minuteByLifeCount.values
                .filter { $0.glucose.date > windowStart }
                .sorted { $0.glucose.id > $1.glucose.id }
        }

        // LLU/Dexcom shape: the history array's newest element [0] is the LIVE
        // reading, so consumers that treat [0] as "current" (the graph-line
        // widgets, the watch's minute-merge boundary `libreLinkUpGlucose[1]`)
        // behave correctly and the graph line reaches "now" instead of stopping at
        // the ~17-min-old 5-min point. Prepend the latest minute reading; it's
        // replaced by a newer one on each push. The internal `historicalByLifeCount`
        // stays PURE 5-min, and the seed-from-store step skips this injected point.
        let latestMinute = minuteNewestFirst.first
        var fullNewestFirst = historicalNewestFirst
        if let latestMinute { fullNewestFirst.insert(latestMinute, at: 0) }
        let graph = fullNewestFirst.filter { $0.glucose.date > windowStart }

        guard let latest = latestMinute ?? graph.first ?? historicalNewestFirst.first else { return }
        let maxBG = (graph + minuteNewestFirst).map { $0.glucose.value }.max() ?? 250
        _ = LibreLinkUpHistory.shared.replaceCacheAndPersist(
            fullLibreLinkUpGlucose: fullNewestFirst,
            libreLinkUpGlucose: graph,
            libreLinkUpMinuteGlucose: minuteNewestFirst,
            latestLibreLinkUpGlucose: latest,
            lastReadingDate: latest.glucose.date,
            currentGlucose: latest.glucose.value,
            currentTrendArrow: latest.trendArrow?.symbol ?? "---",
            maxBG: maxBG,
            lastSuccessfulLibreLinkUpAPICall: Date()
        )

        // Push the updated history to the watch. The watch runs no BLE in v1; it
        // renders the snapshot we send (PLAN §2). Uses application-context under
        // the hood, so the rapid calls during a backfill burst coalesce to the
        // latest.
        WatchConnectivityManager.shared.sendLibreLinkUpSnapshotToWatch()
    }

    /// Bound both buffers by wall clock: keep ~12 h of historical (covers the
    /// display window after trimming) and only the most recent hour of minute
    /// points (the gap-fill never needs more).
    private func pruneBuffers() {
        let historicalCutoff = Date().addingTimeInterval(-Self.historicalRetentionSeconds)
        historicalByLifeCount = historicalByLifeCount.filter { $0.value.glucose.date > historicalCutoff }
        let minuteCutoff = Date().addingTimeInterval(-Double(Self.minuteRetentionMinutes) * 60)
        minuteByLifeCount = minuteByLifeCount.filter { $0.value.glucose.date > minuteCutoff }
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
