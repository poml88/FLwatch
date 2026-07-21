//
//  Libre3DirectManager.swift
//  FLwatch
//
//  The long-lived, phone-only BLE engine for the `.libre3BLE` provider. It owns
//  LibreCRKit's `SensorScannerNG` / `SensorSession` / `PairingFlow` / data-plane
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
import UserNotifications
import LibreCRKit

/// Layer B: transient realtime-reading status for decoded Libre 3 frames that
/// are temporarily unusable for sensor data-quality reasons. This is separate
/// from connection state, warm-up/expiry lifecycle, and Layer A replacement.
struct Libre3ReadingStatus: Equatable {
    enum Kind: Equatable {
        case recalibrating(minutes: Int)
        case dataQuality
        case unavailable
    }

    let kind: Kind
    let episodeID: Int

    var title: String {
        switch kind {
        case .recalibrating:
            String(localized: "Sensor recalibrating")
        case .dataQuality:
            String(localized: "Sensor data quality issue")
        case .unavailable:
            String(localized: "Glucose temporarily unavailable")
        }
    }

    var message: String {
        switch kind {
        case .recalibrating(let minutes):
            String.localizedStringWithFormat(
                String(localized: "No new readings for about %d min. This is normal; it will resume on its own."),
                minutes
            )
        case .dataQuality, .unavailable:
            String(localized: "Glucose temporarily unavailable. This is normal; it will resume on its own.")
        }
    }

    var symbol: String { "exclamationmark.triangle.fill" }
}

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
    /// Transient Libre 3 realtime status for decoded frames that are temporarily
    /// unusable for sensor data-quality reasons.
    @Published private(set) var currentReadingStatus: Libre3ReadingStatus?
    /// Layer A: sensor-reported attention from patch status. Kept separate from
    /// Layer B reading-quality episodes; views merge them only for display.
    /// Soft states only hint; terminal states mirror into `sensorNeedsReplacement`.
    @Published private(set) var sensorAttention: Libre3SensorAttention = .none
    /// Persistent terminal attention state for phone UI relaunch seeding.
    @Published private(set) var sensorNeedsReplacement = false
    /// Repeated credential-shaped failures deliberately stop the otherwise
    /// relentless reconnect owner until the user retries, re-pairs, or toggles
    /// the provider. Transport failures never enter this state.
    @Published private(set) var connectionRequiresUserAction = false {
        didSet { SharedData.libre3ConnectionRequiresUserAction = connectionRequiresUserAction }
    }

    // MARK: - Engine

    /// Created lazily on first `start()` so a cloud-only user (who never selects
    /// `.libre3BLE`) is never prompted for Bluetooth permission and never gets a
    /// second restoring central. Mirrors the heartbeat manager, which likewise
    /// only builds its `CBCentralManager` once enabled.
    private var scanner: SensorScannerNG?
    private var session: SensorSession?
    private var decoder: DataPlaneDecoder?
    private let assembler = DataPlaneNotificationAssembler()

    /// Receipt time of the latest glucose-channel fragment, including warm-up
    /// and undecodable frames. This is channel liveness, distinct from tracking
    /// the latest usable reading. Apart from the fresh-stream grace seed, it must
    /// never be bumped by recovery actions or anything except real glucose
    /// traffic; a future CCCD re-arm fast path must use its own timestamp so it
    /// cannot starve reconnect escalation.
    private var lastGlucoseAt: Date?
    /// Build B3 (targeted glucose CCCD re-arm) only if field diagnostics show
    /// forced reconnects with any-channel quiet < ~90 s while glucose quiet ≥
    /// threshold, more than rarely. Both stale together = the link died = B2 +
    /// the signal-loss alert are the complete answer.
    private var lastAnyChannelAt: Date?
    /// Receipt time of the latest patchStatus fragment (notify or read-fallback).
    /// Separate from lastGlucoseAt/lastAnyChannelAt so the status watchdog can
    /// never bump the glucose-liveness clocks that gate reconnect/signal-loss.
    private var lastPatchStatusAt: Date?
    /// In-session status-channel silence watchdog; lifetime matches the session.
    private var silenceWatchdogTask: Task<Void, Never>?
    /// Diagnostic-only patch-status quiet episode. Direct-read responses keep
    /// the link observable but do not count as spontaneous-notify recovery.
    private var patchStatusQuietEpisodeStartedAt: Date?
    private var didTracePatchStatusQuietEscalation = false
    private var patchStatusReadResponsePending = false
    /// Latest advancing life count that moved the signal-loss deadline.
    private var lastArmedLifeCount: UInt16?
    /// Manager-side mirror of the executor's desired deadline. Settings changes
    /// re-apply this exact value so they never restart the 20-minute clock.
    private var currentSignalLossDeadline: Date?
    private var signalLossDeadlineRecoveryStarted = false
    private var signalLossDeadlineRecovered = false

    /// The single connect → authorize → stream driver. While non-nil a
    /// connection attempt or live stream is in flight.
    private var lifecycleTask: Task<Void, Never>?
    /// User/provider intent. Recoverable CoreBluetooth callbacks may start a new
    /// attempt only while this remains true; `stop()` clears it before issuing
    /// any cancellation whose disconnect callback could otherwise reconnect.
    private var shouldMaintainConnection = false
    /// Identifies the currently-owned attempt so a cancelled/stale task cannot
    /// clear or clean up a newer attempt after suspension resumes it late.
    private var lifecycleAttemptID: UUID?
    /// Peripheral currently being adopted, connected, or streamed. Unlike
    /// `session`, this is available while an indefinite connect is still pending.
    private var lifecyclePeripheral: CBPeripheral?
    /// True only when this attempt adopted a peripheral CoreBluetooth already
    /// reported as connected. A transport failure on that potentially phantom
    /// link earns one cached-handshake retry after a real reconnect.
    private var attemptAdoptedConnectedPeripheral = false
    /// A failed connected setup is cancelled before another attempt. During that
    /// interval the cancellation itself is the standing CoreBluetooth operation;
    /// `didDisconnect` clears this gate and immediately rearms connection intent.
    private var waitingForDisconnectBeforeRearm = false
    /// Unified CoreBluetooth event consumer. `SensorScannerNG` broadcasts every
    /// central callback through this one stream, including state restoration.
    private var scannerEventTask: Task<Void, Never>?

    /// A failure streak spans attempts and is reset only by the first usable
    /// realtime glucose, never by authorization or entering `.streaming`.
    private var consecutiveReconnectFailures = 0
    private var consecutiveCredentialFailures = 0
    private var didNotifyReconnectFailing = false
    /// Wall-clock time before which another failed connect/auth lifecycle must
    /// not begin. A deadline survives suspension without extending the intended
    /// wait when the process resumes.
    private var reconnectBackoffDeadline: Date?
    /// Single cancellable wake-up for `reconnectBackoffDeadline`.
    private var backoffRearmTask: Task<Void, Never>?
    /// The next attempt must bypass the retrieved-peripheral fast path after a
    /// repeated connected-without-glucose livelock.
    private var forceFreshDiscoveryNextAttempt = false

    /// Diagnostic-only attempt state. MainActor serialization makes plain
    /// properties sufficient for the sequential connect lifecycle.
    private var lastAttemptStage = ""
    private var attemptReachedDidConnect = false
    private var attemptEndRecorded = false
    private var sessionProducedGlucose = false
    private var sessionAuthorizedViaFullHandshake = false
    private var didRecordGlucoseOnlyDeath = false
    private var rearmCompletedAt: Date?
    private var didTraceFirstPacket = false
    /// Nonessential CCCDs still awaiting a successful arm. Their initial serial
    /// pass runs beside the essential stream; failures get one retry after the
    /// first actual data-plane packet proves the authorized link is alive.
    private var failedBestEffortRearmCharacteristics = Set<CBUUID>()
    private var bestEffortRearmTask: Task<Void, Never>?
    private var bestEffortRearmPassID: UUID?
    /// Setup success is not proof of health: only usable realtime glucose resets
    /// this counter, matching the connect-without-stream livelock lesson.
    private var consecutiveNoStreamCycles = 0

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
    /// Six minutes allows roughly two missed reload opportunities beyond the
    /// normal three-minute stale-reading window before escalating to reconnect.
    private static let recoveryStaleThreshold: TimeInterval = 6 * 60
    private static let glucoseOnlyDeathRecentChannelThreshold: TimeInterval = 90
    private static let signalLossThreshold: TimeInterval = 20 * 60
    private static let reconnectEscalateUserAfter = 6
    private static let terminalCredentialFailureAfter = 12
    private static let freshDiscoveryNoStreamCycles = 3
    private static let maxBackfillFailuresPerSession = 3
    /// First two failures retry immediately, then reconnect attempts back off
    /// exponentially from 5 seconds to a five-minute cap.
    private static func reconnectBackoff(failures: Int) -> TimeInterval {
        guard failures >= 3 else { return 0 }
        let exponent = min(failures - 3, 6)
        return min(300, 5 * pow(2.0, Double(exponent)))
    }
    private static var bestEffortRearmCharacteristics: [CBUUID] {
        [
            LibreSensorGATT.Char.eventLog,
            LibreSensorGATT.Char.factoryData,
            LibreSensorGATT.Char.patchStatus,
            LibreSensorGATT.Char.historicData,
            LibreSensorGATT.Char.clinicalData,
        ]
    }
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

    /// Guards the historical backfill request once a usable realtime glucose and
    /// both response-channel CCCDs are ready. Failed requests are bounded below.
    private var didRequestBackfill = false
    private var backfillFailuresThisSession = 0

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
    private var readingStatusEpisodeID = 0
    private var lastSensorAttention: Libre3SensorAttention = .none
    /// Prevents reconnects for the same sensor anchor from repeatedly replacing
    /// the same OS-scheduled expiry reminders.
    private var lastScheduledExpiryAnchor: Date?

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
                self?.recoverIfStale()
            }
        }
        sensorStartDate = SharedData.libre3SensorStartDate
        sensorNeedsReplacement = SharedData.libre3SensorNeedsReplacement
        connectionRequiresUserAction = SharedData.libre3ConnectionRequiresUserAction
        if connectionRequiresUserAction {
            connectionState = .failed(String(localized: "Sensor authorization keeps failing. Retry the connection, or re-pair the sensor in the Connect tab."))
        }
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
            DebugMessageSingleton.shared.libreLinkUpResponseError = "none"
            start()
        } else if shouldMaintainConnection ||
                    connectionRequiresUserAction ||
                    lifecycleTask != nil ||
                    scannerEventTask != nil ||
                    session != nil ||
                    currentReadingStatus != nil {
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
        guard isActiveProvider else {
            shouldMaintainConnection = false
            return
        }
        guard Libre3StateStore.isPaired else {
            shouldMaintainConnection = false
            connectionState = .idle
            return
        }
        guard !connectionRequiresUserAction else { return }
        shouldMaintainConnection = true
        // Recover before any lifecycle-driven grace arm. This runs only when the
        // paired direct-BLE provider starts, so a cloud-provider relaunch cannot
        // arm a signal-loss alert from an old persisted Libre 3 anchor.
        recoverSignalLossDeadlineIfNeeded()
        reconcileSignalLossArming()
        // Shared `connected` is the provider-configured/paired gate for the
        // reload path (like LLU's login state), NOT transport status — transport
        // lives in Libre3DirectConnectionState. Do not wire this to BLE link
        // state. Reopens the gate after a provider round-trip (switchProvider
        // sets `.disconnected`).
        if UserDefaults.group.connected != .connected {
            UserDefaults.group.connected = .connected
        }
        ensureScanner()
        // Subscribe before the lifecycle creates any short-lived event waiter.
        // NG buffers restoration only until its first subscriber, so the long-
        // lived owner must always be that first subscriber.
        observeScannerEventsIfNeeded()
        ensureLifecycleAttempt(reason: "start")
    }

    /// Explicitly leave the terminal credential state and start a fresh streak.
    /// Ordinary reload kicks call `start()` and cannot clear the terminal gate.
    func retryConnection() {
        guard isActiveProvider, Libre3StateStore.isPaired else { return }
        clearReconnectBackoff()
        connectionRequiresUserAction = false
        consecutiveReconnectFailures = 0
        consecutiveCredentialFailures = 0
        didNotifyReconnectFailing = false
        forceFreshDiscoveryNextAttempt = true
        SensorAlertNotificationManager.shared.retractReconnectFailing()
        start()
    }

    /// Tear down the connection and stop streaming (provider switched away, or
    /// the user disconnected the sensor).
    func stop() {
        // Clear intent first: cancelling the CoreBluetooth request/session below
        // can synchronously enqueue a disconnect callback, and that callback must
        // not resurrect a provider the user just left.
        shouldMaintainConnection = false
        clearReconnectBackoff()
        waitingForDisconnectBeforeRearm = false
        setSignalLossState(deadline: nil)
        lifecycleAttemptID = nil
        lifecycleTask?.cancel()
        lifecycleTask = nil
        bestEffortRearmPassID = nil
        bestEffortRearmTask?.cancel()
        bestEffortRearmTask = nil
        silenceWatchdogTask?.cancel()
        silenceWatchdogTask = nil
        failedBestEffortRearmCharacteristics.removeAll()
        let peripheralToCancel = session?.peripheral
            ?? lifecyclePeripheral
            ?? savedPeripheralID.flatMap { scanner?.retrievePeripherals(withIdentifiers: [$0]).first }
        scannerEventTask?.cancel()
        scannerEventTask = nil
        session?.handleDisconnect(error: nil)
        if let scanner,
           scanner.centralState == .poweredOn,
           let peripheral = peripheralToCancel {
            scanner.cancelConnection(peripheral)
        }
        session = nil
        lifecyclePeripheral = nil
        decoder = nil
        dataPlaneState = nil
        didRequestBackfill = false
        backfillFailuresThisSession = 0
        assembler.reset()
        clearReadingStatus()
        consecutiveReconnectFailures = 0
        consecutiveCredentialFailures = 0
        didNotifyReconnectFailing = false
        forceFreshDiscoveryNextAttempt = false
        connectionRequiresUserAction = false
        SensorAlertNotificationManager.shared.retractReconnectFailing()
        // A stop means the direct sensor is no longer active here, so remove any
        // standing terminal sensor alert that would now be stale.
        Task { await SensorAlertNotificationManager.shared.retract() }
        connectionState = .idle
    }

    /// Reload-hook recovery: called on every foreground (63 s) and BGAppRefresh
    /// (~8–10 min) reload kick. Restarts a dropped lifecycle, and force-reconnects
    /// a session that is nominally streaming but has received no glucose-channel
    /// traffic for `recoveryStaleThreshold`. Initiates only — the reconnect itself
    /// is carried by the event-driven owner + CoreBluetooth.
    func recoverIfStale() {
        guard isActiveProvider else { return }
        // Preserve the old reload-kick behavior when the lifecycle has dropped:
        // `start()` creates the scanner and begins a fresh connection attempt.
        guard lifecycleTask != nil else {
            Libre3DiagnosticsLog.traceReconnect("reload-kick action=start")
            start()
            return
        }
        // `session` is assigned before authorization, so a reload arriving while
        // connecting/authorizing must not kill that fresh session based on the
        // previous stream's stale liveness timestamp.
        guard connectionState == .streaming,
              // Glucose can be legitimately silent during warm-up; nil also means
              // the lifecycle is not yet classified. Both are safe to skip: at
              // worst recovery waits for the next kick, without disconnecting a
              // warming sensor.
              warmupRemainingMinutes == nil,
              !sensorIsExpired,
              !sensorNeedsReplacement,
              let session,
              let scanner,
              let lastGlucoseAt,
              let lastAnyChannelAt else { return }
        let now = Date()
        let glucoseQuiet = now.timeIntervalSince(lastGlucoseAt)
        let anyChannelQuiet = now.timeIntervalSince(lastAnyChannelAt)
        guard glucoseQuiet >= Self.recoveryStaleThreshold else { return }
        if anyChannelQuiet < Self.glucoseOnlyDeathRecentChannelThreshold,
           !didRecordGlucoseOnlyDeath {
            didRecordGlucoseOnlyDeath = true
            let eventDate = Date()
            SharedData.libre3GlucoseOnlyDeathCount += 1
            SharedData.libre3GlucoseOnlyDeathLastSeen = eventDate
            Libre3DiagnosticsLog.recordNotable(
                "EVENT glucose-only death glucoseQuiet=\(Int(glucoseQuiet))s anyChannelQuiet=\(Int(anyChannelQuiet))s",
                at: eventDate
            )
        }
        // `.notice` has better retention odds than `.info` in the unified-log
        // store and collected archives; it is still not a delivery guarantee.
        Logger.libre3.notice("Libre3 BLE: glucose quiet \(Int(glucoseQuiet), privacy: .public)s, any-channel quiet \(Int(anyChannelQuiet), privacy: .public)s — forcing reconnect")
        Libre3DiagnosticsLog.record(
            "forced-reconnect glucoseQuiet=\(Int(glucoseQuiet))s anyChannelQuiet=\(Int(anyChannelQuiet))s"
        )
        Libre3DiagnosticsLog.traceReconnect("reload-kick action=force-reconnect")
        // Disconnecting ends `notifications()`, allowing the existing lifecycle
        // loop to reconnect. Coincident kicks may repeat this harmless request.
        scanner.cancelConnection(session.peripheral)
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
        clearReadingStatus()
        sensorNeedsReplacement = false
        sensorAttention = .none
        lastSensorAttention = .none
        lastScheduledExpiryAnchor = nil
        // A replacement sensor starts near lifeCount zero. Clear both the
        // persisted data-plane seed and the advancing-lifeCount arm seed, or the
        // old sensor's ~20,000-minute value would suppress arming for the new
        // sensor's entire wear.
        SharedData.libre3LastLifeCount = 0
        SharedData.libre3LastGlucoseMgDL = 0
        lastArmedLifeCount = nil
        // Forgetting follows the re-pair advice, so retract that banner. Also
        // clear expiry reminders so the prior sensor cannot alert after unpairing.
        SensorAlertNotificationManager.shared.retractReconnectFailing()
        Task { await SensorAlertNotificationManager.shared.cancelExpiryReminders() }
        SharedData.libre3SensorStartDate = nil
        SharedData.libre3SensorNeedsReplacement = false
    }

    // MARK: - Status surfaced to the provider

    var isInErrorState: Bool { connectionState.isError }
    var statusMessage: String { connectionState.message }

    // MARK: - Connect → authorize → stream

    private func ensureScanner() {
        guard scanner == nil else { return }
        scanner = SensorScannerNG(
            configuration: .background(restorationIdentifier: Self.restoreIdentifier)
        )
    }

    /// Own the one long-lived NG event subscription. Besides replacing the old
    /// state/restoration/connection-event streams, this must explicitly forward
    /// disconnects into `SensorSession`: NG deliberately leaves session ownership
    /// and invalidation to its client.
    private func observeScannerEventsIfNeeded() {
        guard scannerEventTask == nil, let scanner else { return }
        let events = scanner.events()
        scannerEventTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.handleScannerEvent(event)
                if Task.isCancelled { break }
            }
        }
    }

    private func handleScannerEvent(_ event: SensorScannerNG.Event) {
        switch event {
        case .stateChanged(let state):
            Libre3DiagnosticsLog.traceReconnect("cb-state value=\(state.rawValue)")
            switch state {
            case .poweredOn:
                if isActiveProvider, Libre3StateStore.isPaired {
                    Logger.libre3.info("Libre3 BLE: Bluetooth powered on — reconnecting")
                    start()
                }
            case .poweredOff, .unauthorized, .unsupported, .resetting:
                if shouldMaintainConnection || lifecycleTask != nil {
                    Logger.libre3.info("Libre3 BLE: Bluetooth unavailable (\(String(describing: state), privacy: .public)) — tearing down session")
                    teardownForReconnect()
                }
            case .unknown:
                // Every new central starts unknown and settles through a later
                // callback. Cancelling here would kill its fresh lifecycle.
                break
            @unknown default:
                break
            }

        case .didDiscover:
            // A short-lived discovery waiter consumes the matching event. Avoid
            // filling the bounded reconnect trace with unrelated advertisements.
            break

        case .didConnect(let peripheral):
            Libre3DiagnosticsLog.traceReconnect("cb-did-connect")
            Logger.libre3.info("Libre3 BLE didConnect: \(peripheral.identifier.uuidString, privacy: .private(mask: .hash))")
            if isSavedPeripheral(peripheral), lifecycleTask == nil {
                waitingForDisconnectBeforeRearm = false
                lifecyclePeripheral = peripheral
                ensureLifecycleAttempt(reason: "did-connect")
            }

        case .didFailToConnect(let peripheral, let error):
            let errorName = error.map { Self.compactErrorName(for: $0) } ?? "nil"
            Libre3DiagnosticsLog.traceReconnect("cb-connect-failed error=\(errorName)")
            Logger.libre3.info("Libre3 BLE didFailToConnect: \(peripheral.identifier.uuidString, privacy: .private(mask: .hash)) error=\(errorName, privacy: .public)")
            if isSavedPeripheral(peripheral), lifecycleTask == nil {
                waitingForDisconnectBeforeRearm = false
                ensureLifecycleAttempt(reason: "did-fail-to-connect")
            }

        case .didDisconnect(let peripheral, let error):
            let errorName = error.map { Self.compactErrorName(for: $0) } ?? "nil"
            Libre3DiagnosticsLog.traceReconnect("cb-did-disconnect error=\(errorName)")
            if session?.peripheral.identifier == peripheral.identifier {
                session?.handleDisconnect(error: error)
            }
            if matchesSavedPeripheral(peripheral) {
                waitingForDisconnectBeforeRearm = false
            }
            if isSavedPeripheral(peripheral), lifecycleTask == nil {
                ensureLifecycleAttempt(reason: "did-disconnect")
            }

        case .connectionEvent(let connectionEvent, let peripheral):
            Libre3DiagnosticsLog.traceReconnect("cb-connection-event value=\(connectionEvent.rawValue)")
            guard isSavedPeripheral(peripheral), lifecycleTask == nil else { return }
            switch connectionEvent {
            case .peerConnected:
                Logger.libre3.info("Libre3 BLE: peripheral connected event — adopting")
                waitingForDisconnectBeforeRearm = false
                lifecyclePeripheral = peripheral
                ensureLifecycleAttempt(reason: "peer-connected")
            case .peerDisconnected:
                waitingForDisconnectBeforeRearm = false
                ensureLifecycleAttempt(reason: "peer-disconnected")
            @unknown default:
                break
            }

        case .willRestoreState(let restoration):
            Libre3DiagnosticsLog.traceReconnect("state-restoration peripherals=\(restoration.peripherals.count)")
            Logger.libre3.info("Libre3 BLE state restoration: \(restoration.peripherals.count, privacy: .public) peripheral(s)")
            if isActiveProvider, Libre3StateStore.isPaired {
                start()
            }
        }
    }

    private var savedPeripheralID: UUID? {
        UUID(uuidString: SharedData.libre3PeripheralUUID)
    }

    private func matchesSavedPeripheral(_ peripheral: CBPeripheral) -> Bool {
        guard let savedPeripheralID else { return false }
        return peripheral.identifier == savedPeripheralID
    }

    private func isSavedPeripheral(_ peripheral: CBPeripheral) -> Bool {
        guard shouldMaintainConnection,
              isActiveProvider,
              Libre3StateStore.isPaired else { return false }
        return matchesSavedPeripheral(peripheral)
    }

    /// Cancel the in-flight session (otherwise stuck in `consumeNotifications`,
    /// since a Bluetooth power-off yields no disconnect) and drop session state,
    /// leaving the manager ready to reconnect on the next power-on. Unlike
    /// `stop()` it keeps the unified scanner event observer alive so we can come
    /// back automatically.
    private func teardownForReconnect() {
        // Deliberately do NOT cancel signal loss here. Bluetooth-off means hypo
        // protection is genuinely offline, so the OS-scheduled alert must remain
        // armed while this process may be suspended.
        clearReconnectBackoff()
        lifecycleAttemptID = nil
        lifecycleTask?.cancel()
        lifecycleTask = nil
        bestEffortRearmPassID = nil
        bestEffortRearmTask?.cancel()
        bestEffortRearmTask = nil
        silenceWatchdogTask?.cancel()
        silenceWatchdogTask = nil
        failedBestEffortRearmCharacteristics.removeAll()
        waitingForDisconnectBeforeRearm = false
        finishConnectedAttempt(traceStreamEnd: lastAttemptStage == "streaming")
        // NG clients own session invalidation. Power-off does not reliably emit
        // didDisconnect, so fail outstanding GATT work explicitly before dropping
        // the session reference.
        session?.handleDisconnect(error: nil)
        // Don't call `scanner.cancelConnection` here: this runs only when
        // Bluetooth has gone UN-available (the state observer's non-poweredOn
        // branch), so the OS has already dropped the link and
        // `cancelPeripheralConnection` on a powered-off central is an API misuse
        // ("can only accept this command while in the powered on state"). Just
        // drop our references; the next power-on attempt adopts restored state
        // first and cleans up only if its bounded setup fails.
        session = nil
        lifecyclePeripheral = nil
        decoder = nil
        dataPlaneState = nil
        didRequestBackfill = false
        backfillFailuresThisSession = 0
        assembler.reset()
        currentGlucoseMgDL = nil
        warmupRemainingMinutes = nil
        connectionState = .failed(String(localized: "Bluetooth is turned off."))
        DebugMessageSingleton.shared.libreLinkUpResponseError = "Libre3 BLE: Bluetooth unavailable"
    }

    /// Start one connect → authorize → stream attempt. Recovery is driven by
    /// completion and CoreBluetooth callbacks, with a bounded timer only after a
    /// completed failure. Otherwise an indefinite connect or disconnect cleanup
    /// request remains owned by CoreBluetooth before this process may suspend.
    private func ensureLifecycleAttempt(reason: String) {
        guard shouldMaintainConnection,
              isActiveProvider,
              Libre3StateStore.isPaired,
              lifecycleTask == nil,
              !waitingForDisconnectBeforeRearm,
              let scanner,
              scanner.centralState == .poweredOn else { return }

        if let deadline = reconnectBackoffDeadline {
            let remaining = deadline.timeIntervalSinceNow
            if remaining > 0 {
                guard backoffRearmTask == nil else { return }
                let waitSeconds = Int(remaining.rounded(.up))
                Libre3DiagnosticsLog.traceReconnect(
                    "reconnect-backoff wait=\(waitSeconds)s reason=\(reason)"
                )
                let nanoseconds = UInt64(remaining * 1_000_000_000)
                backoffRearmTask = Task { [weak self] in
                    do {
                        try await Task.sleep(nanoseconds: nanoseconds)
                    } catch {
                        return
                    }
                    guard let self, !Task.isCancelled else { return }
                    self.backoffRearmTask = nil
                    self.ensureLifecycleAttempt(reason: "backoff-elapsed")
                }
                return
            }

            // Another lifecycle trigger may observe an elapsed wall-clock
            // deadline before the sleeping task is scheduled again after resume.
            clearReconnectBackoff()
        }

        let attemptID = UUID()
        lifecycleAttemptID = attemptID
        Libre3DiagnosticsLog.traceReconnect("lifecycle-start reason=\(reason)")
        lifecycleTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.connectAuthorizeAndStream()
                self.completeLifecycleAttempt(id: attemptID, error: nil)
            } catch is CancellationError {
                self.completeCancelledLifecycleAttempt(id: attemptID)
            } catch {
                self.completeLifecycleAttempt(id: attemptID, error: error)
            }
        }
    }

    private func completeCancelledLifecycleAttempt(id: UUID) {
        guard lifecycleAttemptID == id else { return }
        lifecycleAttemptID = nil
        lifecycleTask = nil
        // Intentional stop and Bluetooth-unavailable teardown clear or defer
        // intent themselves. Any other cancellation must still restore it.
        ensureLifecycleAttempt(reason: "cancelled-attempt")
    }

    private func completeLifecycleAttempt(id: UUID, error: Error?) {
        guard lifecycleAttemptID == id else { return }
        lifecycleAttemptID = nil
        lifecycleTask = nil

        let endedStage = lastAttemptStage
        let failureClass = error.map { Self.failureClass(for: $0) } ?? "transport"
        let errorName = error.map { Self.compactErrorName(for: $0) } ?? "notificationStreamEnded"
        if let error {
            Libre3DiagnosticsLog.traceReconnect(
                "setup-failed stage=\(endedStage) class=\(failureClass) error=\(errorName)"
            )
            Logger.libre3.error("Libre3 BLE lifecycle error: \(String(describing: error), privacy: .public)")
        }
        finishConnectedAttempt(traceStreamEnd: endedStage == "streaming")

        if !sessionProducedGlucose {
            consecutiveReconnectFailures += 1
            if failureClass == "credential" {
                consecutiveCredentialFailures += 1
            } else {
                consecutiveCredentialFailures = 0
            }
        }
        if let error {
            connectionState = .failed(Self.friendlyMessage(for: error))
        } else {
            connectionState = .failed(String(localized: "Connection lost. Reconnecting…"))
        }
        if let error {
            DebugMessageSingleton.shared.libreLinkUpResponseError =
                "Libre3 BLE: \(Self.supportSafeDescription(for: error))"
        } else {
            DebugMessageSingleton.shared.libreLinkUpResponseError =
                "Libre3 BLE: notification stream ended"
        }

        // Keep transport/other escalation diagnostic-only. The signal-loss
        // dead-man already tells the user that glucose is unavailable; only a
        // credential streak may post re-pair guidance or stop reconnecting.
        if consecutiveReconnectFailures == Self.reconnectEscalateUserAfter {
            Libre3DiagnosticsLog.record(
                "reconnect-escalation failures=\(consecutiveReconnectFailures) stage=\(endedStage) class=\(failureClass) lastError=\(errorName)"
            )
        }

        if consecutiveCredentialFailures >= Self.terminalCredentialFailureAfter {
            shouldMaintainConnection = false
            connectionRequiresUserAction = true
            connectionState = .failed(String(localized: "Sensor authorization keeps failing. Retry the connection, or re-pair the sensor in the Connect tab."))
            if !didNotifyReconnectFailing {
                didNotifyReconnectFailing = true
                Libre3DiagnosticsLog.recordNotable(
                    "credential-terminal failures=\(consecutiveCredentialFailures) stage=\(endedStage) lastError=\(errorName)"
                )
                Task { await SensorAlertNotificationManager.shared.postReconnectFailing() }
            }
        }

        // A genuinely out-of-range request remains pending inside
        // `awaitConnectedPeripheral` and never reaches this completion path. If
        // CoreBluetooth does report a failed connection, pace that completed
        // failure too so marginal links cannot spin before `didConnect`.
        if shouldMaintainConnection, !sessionProducedGlucose {
            armReconnectBackoff(
                Self.reconnectBackoff(failures: consecutiveReconnectFailures)
            )
        } else {
            clearReconnectBackoff()
        }

        prepareForNextAttempt()
    }

    private func armReconnectBackoff(_ delay: TimeInterval) {
        clearReconnectBackoff()
        guard delay > 0 else { return }
        reconnectBackoffDeadline = Date().addingTimeInterval(delay)
    }

    private func clearReconnectBackoff() {
        reconnectBackoffDeadline = nil
        backoffRearmTask?.cancel()
        backoffRearmTask = nil
    }

    /// Tear down a failed authorized/connected session. If CoreBluetooth still
    /// owns a live or pending link, its cancellation is the standing operation
    /// and `didDisconnect` performs the re-arm. If already disconnected, route
    /// through the lifecycle gate, which either starts the next indefinite
    /// connect or schedules the bounded backoff wake-up.
    private func prepareForNextAttempt() {
        bestEffortRearmPassID = nil
        bestEffortRearmTask?.cancel()
        bestEffortRearmTask = nil
        silenceWatchdogTask?.cancel()
        silenceWatchdogTask = nil
        failedBestEffortRearmCharacteristics.removeAll()

        let peripheral = session?.peripheral ?? lifecyclePeripheral
        session?.handleDisconnect(error: nil)
        session = nil
        lifecyclePeripheral = nil
        decoder = nil
        dataPlaneState = nil
        didRequestBackfill = false
        backfillFailuresThisSession = 0
        assembler.reset()

        if let scanner,
           scanner.centralState == .poweredOn,
           let peripheral,
           peripheral.state != .disconnected {
            waitingForDisconnectBeforeRearm = true
            Libre3DiagnosticsLog.traceReconnect(
                "disconnect-before-rearm state=\(peripheral.state.rawValue)"
            )
            scanner.cancelConnection(peripheral)
            if peripheral.state == .disconnected {
                waitingForDisconnectBeforeRearm = false
                ensureLifecycleAttempt(reason: "cleanup-already-disconnected")
            }
            return
        }

        waitingForDisconnectBeforeRearm = false
        guard shouldMaintainConnection,
              isActiveProvider,
              Libre3StateStore.isPaired else { return }
        ensureLifecycleAttempt(reason: "attempt-ended")
    }

    private func connectAuthorizeAndStream() async throws {
        lastAttemptStage = "connect"
        attemptReachedDidConnect = false
        attemptEndRecorded = false
        sessionProducedGlucose = false
        sessionAuthorizedViaFullHandshake = false
        didRecordGlucoseOnlyDeath = false
        attemptAdoptedConnectedPeripheral = false
        rearmCompletedAt = nil
        didTraceFirstPacket = false
        failedBestEffortRearmCharacteristics.removeAll()
        bestEffortRearmPassID = nil
        bestEffortRearmTask?.cancel()
        bestEffortRearmTask = nil
        silenceWatchdogTask?.cancel()
        silenceWatchdogTask = nil
        Libre3DiagnosticsLog.traceReconnect("connect-start")

        guard let scanner else { throw Libre3DirectError.notStarted }
        guard let sensorState = Libre3StateStore.loadState() else {
            throw Libre3DirectError.notPaired
        }

        try await waitUntilScannerReady(scanner)

        connectionState = .scanning
        let peripheral = try await discoverPeripheral(scanner: scanner)
        lifecyclePeripheral = peripheral
        attemptAdoptedConnectedPeripheral = peripheral.state == .connected
        SharedData.libre3PeripheralUUID = peripheral.identifier.uuidString

        connectionState = .connecting
        let session = try await connectAndBuildSession(scanner: scanner, peripheral: peripheral)
        // Ask iOS to wake us when it next sees this peripheral after a
        // background range loss. The disconnect callback immediately restores
        // an indefinite connect intent while its background wake is still live.
        scanner.registerForConnectionEvents(peripheralIDs: [peripheral.identifier])

        // Wrap ONLY the auth handshake burst in a background task — NOT the slow
        // indefinite NG connection above, which can wait ~30s for the Libre 3's
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

        lastAttemptStage = "auth"
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
        lastArmedLifeCount = savedLastLifeCount
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

        // Rearm serially rather than as one concurrent all-or-nothing burst. The
        // field failures on glucoseData and factoryData both followed successful
        // authorization on marginal/restored links, so one missing nonessential
        // CCCD must not discard valid session keys. glucoseData and patchControl
        // are fatal; the remaining response/status channels are best effort and
        // get one opportunistic retry after real data proves the stream alive.
        lastAttemptStage = "rearm"
        try await rearmDataPlaneNotifications(session: session)
        rearmCompletedAt = Date()

        // Stamp the sensor model now that we're authorized (mirrors how the
        // Dexcom/LLU providers set the type on connect).
        Libre3StateStore.stampSensorType()
        // Wire the graph's red low-alarm line from the notification settings,
        // like the Dexcom login path — the direct stream carries no alarm
        // thresholds of its own.
        applyManualAlarmWiring()

        // Backfill waits for both a usable realtime glucose (real lifeCount) and
        // successful historicData/clinicalData arming. This avoids both the old
        // `from=0` request and a known ATT 0xFD readiness race.
        didRequestBackfill = false
        backfillFailuresThisSession = 0

        lastAttemptStage = "streaming"
        connectionState = .streaming
        Libre3DiagnosticsLog.traceReconnect("stream-start")
        startBestEffortRearmPass(session: session, isRetry: false)
        startSilenceWatchdog(session: session)
        // Give a newly authorized stream a full recovery window; subsequent
        // liveness advances come only from actual glucose-channel fragments.
        let streamingStartedAt = Date()
        lastGlucoseAt = streamingStartedAt
        lastAnyChannelAt = streamingStartedAt
        Logger.libre3.info("Libre3 BLE streaming started for serial=\(sensorState.serialNumber ?? "?", privacy: .public)")
        // Request app-wide notification auth before a terminal sensor state occurs.
        // Setup success is not the health point: reconnect advice and its streak
        // remain until the first usable realtime glucose is ingested below. If
        // the sensor is otherwise healthy, clear only stale terminal attention.
        await SensorAlertNotificationManager.shared.requestAuthorizationIfNeeded()
        if !sensorNeedsReplacement {
            await SensorAlertNotificationManager.shared.retract()
        }
        refreshExpiryReminders()

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
        finishConnectedAttempt(traceStreamEnd: true)
    }

    private func rearmDataPlaneNotifications(session: SensorSession) async throws {
        let essential = [
            LibreSensorGATT.Char.glucoseData,
            LibreSensorGATT.Char.patchControl,
        ]
        for characteristic in essential {
            try await session.refreshDataPlaneNotifications(
                characteristics: [characteristic],
                forceReArm: [characteristic]
            )
        }
        failedBestEffortRearmCharacteristics = Set(Self.bestEffortRearmCharacteristics)
    }

    private func retryBestEffortRearmsIfNeeded(session: SensorSession) {
        startBestEffortRearmPass(session: session, isRetry: true)
    }

    private func startSilenceWatchdog(session: SensorSession) {
        silenceWatchdogTask?.cancel()
        lastPatchStatusAt = Date()
        patchStatusQuietEpisodeStartedAt = nil
        didTracePatchStatusQuietEscalation = false
        patchStatusReadResponsePending = false
        silenceWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self, !Task.isCancelled, self.session === session else { return }
                let now = Date()
                let lastPatchStatusAt = self.lastPatchStatusAt ?? .distantPast
                let psQuiet = now.timeIntervalSince(lastPatchStatusAt)
                guard psQuiet >= 60 else { continue }
                if self.patchStatusQuietEpisodeStartedAt == nil {
                    self.patchStatusQuietEpisodeStartedAt = lastPatchStatusAt
                    Libre3DiagnosticsLog.traceReconnect(
                        "patchstatus-quiet-start quiet=\(Int(psQuiet))s"
                    )
                }
                if psQuiet >= 150 {
                    // Notify channel proven un-armed/stuck: one targeted off→on.
                    if !self.didTracePatchStatusQuietEscalation {
                        self.didTracePatchStatusQuietEscalation = true
                        Libre3DiagnosticsLog.traceReconnect(
                            "patchstatus-quiet-rearm quiet=\(Int(psQuiet))s"
                        )
                    }
                    try? await session.refreshDataPlaneNotifications(
                        characteristics: [LibreSensorGATT.Char.patchStatus],
                        forceReArm: [LibreSensorGATT.Char.patchStatus]
                    )
                    guard self.session === session else { return }
                }
                // Vendor-parity direct read: no CCCD churn; result returns via
                // notifications() and is handled like any patchStatus frame.
                Logger.libre3.info("Libre3 BLE patchstatus-read quiet=\(Int(psQuiet), privacy: .public)s")
                self.patchStatusReadResponsePending = true
                do {
                    _ = try await session.readPatchStatus()
                } catch {
                    self.patchStatusReadResponsePending = false
                    Logger.libre3.info("Libre3 BLE readPatchStatus failed: \(String(describing: error), privacy: .public)")
                }
                guard self.session === session else { return }
                self.lastPatchStatusAt = Date()
            }
        }
    }

    /// Nonessential CCCDs are armed serially beside the already-live essential
    /// stream. This keeps a run of 8-second best-effort timeouts from consuming
    /// the whole auth background task or delaying glucose delivery. Failed
    /// channels remain in the set for one pass after the first real packet.
    private func startBestEffortRearmPass(session: SensorSession, isRetry: Bool) {
        guard bestEffortRearmTask == nil,
              !failedBestEffortRearmCharacteristics.isEmpty,
              self.session === session else { return }

        let characteristics = failedBestEffortRearmCharacteristics.sorted {
            $0.uuidString < $1.uuidString
        }
        let passID = UUID()
        let passName = isRetry ? "retry" : "start"
        bestEffortRearmPassID = passID
        Libre3DiagnosticsLog.traceReconnect(
            "rearm-best-effort-\(passName) count=\(characteristics.count)"
        )
        bestEffortRearmTask = Task { [weak self] in
            guard let self else { return }
            for characteristic in characteristics {
                guard !Task.isCancelled, self.session === session else { return }
                let channel = Self.dataPlaneChannelName(for: characteristic)
                do {
                    try await session.refreshDataPlaneNotifications(
                        characteristics: [characteristic],
                        forceReArm: [characteristic]
                    )
                    guard self.session === session else { return }
                    self.failedBestEffortRearmCharacteristics.remove(characteristic)
                    if isRetry {
                        Libre3DiagnosticsLog.traceReconnect(
                            "rearm-best-effort-recovered channel=\(channel)"
                        )
                    }
                } catch is CancellationError {
                    return
                } catch {
                    let errorName = Self.compactErrorName(for: error)
                    let failureName = isRetry ? "retry-failed" : "failed"
                    Libre3DiagnosticsLog.traceReconnect(
                        "rearm-best-effort-\(failureName) channel=\(channel) error=\(errorName)"
                    )
                    Logger.libre3.info("Libre3 BLE best-effort re-arm failed on \(channel, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }
            guard self.bestEffortRearmPassID == passID else { return }
            self.bestEffortRearmPassID = nil
            self.bestEffortRearmTask = nil
            Libre3DiagnosticsLog.traceReconnect(
                "rearm-best-effort-complete pass=\(passName) pending=\(self.failedBestEffortRearmCharacteristics.count)"
            )
            self.requestBackfillWhenReady()
            if !isRetry, self.didTraceFirstPacket {
                self.startBestEffortRearmPass(session: session, isRetry: true)
            }
        }
    }

    /// On-demand historical backfill (the `patchControl` write), modelled on
    /// Juggluco's `fillHistory` (`Libre3GattCallback.receivedpatchstatus` →
    /// `Natives.libre3ControlHistory(1, max(lastReceived, 5))`, byte-identical to
    /// our command).
    ///
    /// The importer's transient plain-enable remains as belt-and-suspenders, but
    /// the real arming now happens in the one-time post-handshake backfill-ready
    /// off→on cycle above. Field diagnostics showed that relying on the plain
    /// enable after reconnect let iOS's cached CCCD state turn it into a no-op,
    /// causing every `patchControl` write to fail with ATT 0xFD. The earlier
    /// streaming breakage matches LibreLoop's backed-out per-retry churn; its
    /// production-validated configuration re-arms this wider set once per
    /// handshake. Fired after the first usable realtime glucose and response-
    /// channel readiness, `from = max(5, …)`.
    private static let onDemandBackfillEnabled = true

    private var backfillResponseChannelsReady: Bool {
        !failedBestEffortRearmCharacteristics.contains(LibreSensorGATT.Char.historicData)
            && !failedBestEffortRearmCharacteristics.contains(LibreSensorGATT.Char.clinicalData)
    }

    /// Backfill needs both a real realtime-glucose anchor and its response CCCDs.
    /// Either may arrive first; both the ingest path and CCCD-pass completion call
    /// here, so whichever becomes ready second launches the request immediately.
    private func requestBackfillWhenReady() {
        let latestRealtime = dataPlaneState?.latestRealtimeGlucose
        guard sessionProducedGlucose,
              backfillResponseChannelsReady,
              let latestRealtime else {
            return
        }
        requestBackfillIfNeeded(currentLifeCount: Int(latestRealtime.lifeCount))
    }

    /// Request the one-shot historical backfill once readiness is proven. `from`
    /// resumes at the saved last reading (gap fill; the rest is seeded from the
    /// persisted store) or 6 h back on a first-ever connect — never 0.
    private func requestBackfillIfNeeded(currentLifeCount: Int) {
        guard Self.onDemandBackfillEnabled else { return }
        guard !didRequestBackfill,
              backfillFailuresThisSession < Self.maxBackfillFailuresPerSession,
              backfillResponseChannelsReady,
              currentLifeCount > 0,
              let capturedSession = session, let crypto = decoder?.crypto else { return }
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
                    session: capturedSession, crypto: crypto, fromLifeCount: from
                )
                // An unstructured request can finish after disconnect or during
                // a replacement session. Only its originating live stream may
                // reconcile the shared diagnostic field.
                guard let self,
                      self.session === capturedSession,
                      self.connectionState == .streaming else { return }
                if DebugMessageSingleton.shared.libreLinkUpResponseError
                    .hasPrefix("Libre3 BLE backfill") {
                    DebugMessageSingleton.shared.libreLinkUpResponseError = "none"
                }
            } catch {
                Logger.libre3.error("Libre3 BLE historical backfill request failed: \(String(describing: error), privacy: .public)")
                guard let self,
                      self.session === capturedSession,
                      self.connectionState == .streaming else { return }
                self.backfillFailuresThisSession += 1
                let failureCount = self.backfillFailuresThisSession
                let errorName = Self.compactErrorName(for: error)
                Libre3DiagnosticsLog.traceReconnect(
                    "backfill-failed attempt=\(failureCount) error=\(errorName)"
                )
                if failureCount < Self.maxBackfillFailuresPerSession {
                    self.didRequestBackfill = false
                } else {
                    Libre3DiagnosticsLog.traceReconnect(
                        "backfill-give-up failures=\(failureCount)"
                    )
                }
                DebugMessageSingleton.shared.libreLinkUpResponseError =
                    "Libre3 BLE backfill: \(Self.supportSafeDescription(for: error))"
            }
        }
    }

    /// Find the paired sensor: prefer the saved peripheral identifier (no scan
    /// wait on reconnect). After repeated connected-without-glucose cycles,
    /// deliberately bypass that cached path and rediscover the saved peripheral
    /// through a standing CoreBluetooth scan.
    private func discoverPeripheral(scanner: SensorScannerNG) async throws -> CBPeripheral {
        let savedUUID = SharedData.libre3PeripheralUUID
        let savedID = UUID(uuidString: savedUUID)
        if !forceFreshDiscoveryNextAttempt, let id = savedID {
            let known = scanner.retrievePeripherals(withIdentifiers: [id])
            if let peripheral = known.first {
                return peripheral
            }
        }

        // iOS may evict the cached identifier after a long suspension while still
        // holding the peripheral connected on the Libre 3 service. This is a
        // different source than retrievePeripherals and recovers the held link
        // without a scan. Match the saved id strictly — never adopt a stray.
        if !forceFreshDiscoveryNextAttempt, let id = savedID {
            if let connected = scanner.retrieveConnectedPeripherals()
                .first(where: { $0.identifier == id }) {
                Libre3DiagnosticsLog.traceReconnect("reconnect-recovered-connected")
                return connected
            }
        }

        if forceFreshDiscoveryNextAttempt {
            Libre3DiagnosticsLog.traceReconnect("fresh-discovery-start")
        }

        // Subscribe before starting the scan: both operations serialize onto
        // NG's central queue, so no fast discovery can beat the waiter.
        let events = scanner.events()
        scanner.startScan()
        defer { scanner.stopScan() }
        for await event in events {
            try Task.checkCancellation()
            if case .didDiscover(let found) = event,
               savedID.map({ found.peripheral.identifier == $0 }) ?? true {
                forceFreshDiscoveryNextAttempt = false
                Libre3DiagnosticsLog.traceReconnect("fresh-discovery-found")
                return found.peripheral
            }
        }
        if Task.isCancelled { throw CancellationError() }
        throw Libre3DirectError.sensorNotFound
    }

    /// Wait for CoreBluetooth to become usable using NG's replayed state event.
    /// `.unknown` and `.resetting` are transitional; terminal radio/permission
    /// states throw the same public scanner errors as the old async wrapper.
    private func waitUntilScannerReady(_ scanner: SensorScannerNG) async throws {
        func readyResult(for state: CBManagerState) -> Result<Void, Error>? {
            switch state {
            case .poweredOn:
                return .success(())
            case .poweredOff:
                return .failure(SensorScannerError.bluetoothPoweredOff)
            case .unauthorized:
                return .failure(SensorScannerError.bluetoothUnauthorized)
            case .unsupported:
                return .failure(SensorScannerError.bluetoothUnavailable)
            case .unknown, .resetting:
                return nil
            @unknown default:
                return .failure(SensorScannerError.bluetoothUnavailable)
            }
        }

        if let result = readyResult(for: scanner.centralState) {
            return try result.get()
        }

        for await event in scanner.events() {
            try Task.checkCancellation()
            guard case .stateChanged(let state) = event,
                  let result = readyResult(for: state) else { continue }
            return try result.get()
        }
        if Task.isCancelled { throw CancellationError() }
        throw SensorScannerError.bluetoothUnavailable
    }

    /// Adopt an already-connected/restored peripheral, or leave an indefinite
    /// NG connection request standing until CoreBluetooth reaches it. A phantom
    /// restored link is allowed to fail its bounded discovery/auth work; the
    /// attempt cleanup then cancels it and rearms from `didDisconnect`.
    /// The CoreBluetooth request has no application timeout, so it remains a
    /// background wake source until connection or explicit cancellation.
    private func connectAndBuildSession(
        scanner: SensorScannerNG,
        peripheral: CBPeripheral
    ) async throws -> SensorSession {
        try await withTaskCancellationHandler {
            let connected = try await awaitConnectedPeripheral(
                scanner: scanner,
                peripheral: peripheral
            )
            attemptReachedDidConnect = true
            Libre3DiagnosticsLog.traceReconnect("did-connect")

            let newSession = SensorSession(
                peripheral: connected,
                queue: scanner.centralQueue
            )
            // Publish before discovery: the long-lived NG event owner must be
            // able to fail discovery/notify continuations if the link drops.
            session = newSession
            try await newSession.discoverAndSubscribe()
            return newSession
        } onCancel: {
            // Power-loss teardown intentionally avoids issuing CoreBluetooth
            // commands while the central is unavailable. Ordinary stop/cancel
            // still tears down an indefinite pending request immediately.
            if scanner.centralState == .poweredOn {
                scanner.cancelConnection(peripheral)
            }
        }
    }

    private func awaitConnectedPeripheral(
        scanner: SensorScannerNG,
        peripheral: CBPeripheral
    ) async throws -> CBPeripheral {
        if peripheral.state == .connected {
            return peripheral
        }

        // Register the waiter before requestConnect. NG serializes both onto its
        // central queue, preventing an immediate didConnect from being missed.
        let events = scanner.events()
        Libre3DiagnosticsLog.traceReconnect(
            "connect-intent-armed state=\(peripheral.state.rawValue)"
        )
        scanner.requestConnect(peripheral)

        for await event in events {
            try Task.checkCancellation()
            switch event {
            case .didConnect(let connected)
                where connected.identifier == peripheral.identifier:
                return connected
            case .didFailToConnect(let failed, let error)
                where failed.identifier == peripheral.identifier:
                throw SensorScannerError.connectionFailed(
                    error?.localizedDescription ?? "unknown"
                )
            case .didDisconnect(let disconnected, let error)
                where disconnected.identifier == peripheral.identifier:
                throw SensorScannerError.connectionFailed(
                    error?.localizedDescription ?? "disconnected"
                )
            case .stateChanged(.poweredOff):
                throw SensorScannerError.bluetoothPoweredOff
            case .stateChanged(.unauthorized):
                throw SensorScannerError.bluetoothUnauthorized
            case .stateChanged(.unsupported):
                throw SensorScannerError.bluetoothUnavailable
            default:
                continue
            }
        }

        if Task.isCancelled { throw CancellationError() }
        throw SensorScannerError.connectionFailed("event stream ended")
    }

    /// Authorize the freshly-connected session. Prefers the fast cached/direct
    /// reconnect (PLAN Phase 5) when we hold a reconnect key from a prior full
    /// pair. A transport failure on an adopted/restored connection retries the
    /// short cached path once after a real reconnect; other cached failures fall
    /// back to the full command-gated first-pair handshake on the next fresh
    /// connection. Returns the Phase-6 session material the decoder needs.
    ///
    /// Deliberate divergence from LibreLoop `50ea2de`: it removed this fallback,
    /// but FLwatch's Phase-5 validation log captured the full-handshake fallback
    /// succeeding on active sensor hardware, so that recovery path stays intact.
    private func authorize(session: SensorSession, sensorState: Libre3SensorState) async throws -> Phase6SessionMaterial {
        if !skipCachedReconnectOnce, let reconnectKey = Libre3StateStore.loadReconnectKey() {
            do {
                let material = try await runCachedReconnect(
                    session: session, blePIN: sensorState.blePIN, reconnectKey: reconnectKey
                )
                sessionAuthorizedViaFullHandshake = false
                Logger.libre3.info("Libre3 BLE cached reconnect succeeded")
                return material
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A restored `.connected` peripheral can be a half-dead link.
                // If that adopted link fails for transport reasons, preserve the
                // cached key and try the short handshake once more after cleanup
                // produces a real didConnect. Any failure on that fresh attempt,
                // or an explicitly credential-shaped failure now, selects the
                // hardware-validated full-handshake fallback next time.
                let retryCachedFresh = attemptAdoptedConnectedPeripheral
                    && Self.failureClass(for: error) == "transport"
                skipCachedReconnectOnce = !retryCachedFresh
                let nextPathToken = retryCachedFresh ? "cached" : "full"
                let nextPath = retryCachedFresh ? "cached handshake" : "full handshake"
                Libre3DiagnosticsLog.traceReconnect(
                    "cached-reconnect-failed adopted=\(attemptAdoptedConnectedPeripheral) next=\(nextPathToken)"
                )
                Logger.libre3.info("Libre3 BLE cached reconnect failed (\(String(describing: error), privacy: .public)) — reconnecting fresh for \(nextPath, privacy: .public)")
                throw error
            }
        }
        sessionAuthorizedViaFullHandshake = skipCachedReconnectOnce
            && Libre3StateStore.loadReconnectKey() != nil
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
        // Use LibreCRKit's bundled v1 (`03 03`) app certificate for first-pair.
        // LibreCRKit owns the matching certificate material and auto-selects the
        // index-1 Phase-5 static scalar from the `03 03` prefix.
        let phoneCert = try PhoneCert.bundled162b()

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
            if !didTraceFirstPacket, let rearmCompletedAt {
                didTraceFirstPacket = true
                Libre3DiagnosticsLog.traceReconnect(
                    "first-packet delay=\(Self.reconnectDelay(from: rearmCompletedAt, to: event.receivedAt))"
                )
                retryBestEffortRearmsIfNeeded(session: session)
            }
            lastAnyChannelAt = event.receivedAt
            // Stamp every glucose fragment before assembly/decode: warm-up and
            // malformed frames still prove that the glucose channel is alive.
            if channel == .glucoseData {
                lastGlucoseAt = event.receivedAt
            }
            if channel == .patchStatus {
                lastPatchStatusAt = event.receivedAt
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
            if channel == .patchStatus {
                if patchStatusReadResponsePending {
                    patchStatusReadResponsePending = false
                } else if let quietStartedAt = patchStatusQuietEpisodeStartedAt {
                    Libre3DiagnosticsLog.traceReconnect(
                        "patchstatus-quiet-recovered duration=\(Self.reconnectDelay(from: quietStartedAt, to: event.receivedAt))"
                    )
                    patchStatusQuietEpisodeStartedAt = nil
                    didTracePatchStatusQuietEscalation = false
                }
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
            updateSensorAttention(state.latestSensorAttention)
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
            // Layer B is updated at the single realtime suppress site. Embedded
            // history is still pushed below, but no unusable current value is
            // surfaced into the main glucose history.
            updateReadingStatus(for: reading, assessment: assessment)
            // Still push so the embedded historical point (if any) reaches the graph.
            pushHistory()
            return
        }
        guard let mapped = Libre3GlucoseMapper.makeGlucose(
            from: reading,
            sensorStartDate: anchor,
            settings: settings
        ) else { return }

        if !sessionProducedGlucose {
            sessionProducedGlucose = true
            if sessionAuthorizedViaFullHandshake {
                let eventDate = Date()
                SharedData.libre3FullHandshakeRecoveryCount += 1
                SharedData.libre3FullHandshakeRecoveryLastSeen = eventDate
                Libre3DiagnosticsLog.recordNotable(
                    "EVENT full-handshake reconnect streamed gen=\(SharedData.libre3Generation)",
                    at: eventDate
                )
            }
            clearReconnectBackoff()
            if let rearmCompletedAt {
                Libre3DiagnosticsLog.traceReconnect(
                    "first-glucose delay=\(Self.reconnectDelay(from: rearmCompletedAt, to: Date()))"
                )
            }
            consecutiveReconnectFailures = 0
            consecutiveCredentialFailures = 0
            forceFreshDiscoveryNextAttempt = false
            DebugMessageSingleton.shared.libreLinkUpResponseError = "none"
            SensorAlertNotificationManager.shared.retractReconnectFailing()
            didNotifyReconnectFailing = false
        }
        requestBackfillWhenReady()
        // Only an accepted usable realtime reading proves the connection is
        // healthy; authorization/re-arm/streaming transitions never reset this.
        consecutiveNoStreamCycles = 0

        minuteByLifeCount[mapped.glucose.id] = mapped
        currentGlucoseMgDL = mapped.glucose.value
        clearReadingStatus()
        persistLastAccepted(reading)
        pushHistory()
        refreshLiveActivityForNewReading()
        evaluateLowGlucoseForNewReading()
        armSignalLossForAdvancingReading(reading)
    }

    private func updateReadingStatus(
        for reading: RealtimeGlucoseReading,
        assessment: Libre3GlucoseQualityAssessment
    ) {
        guard let kind = readingStatusKind(for: assessment.blockingIssues, esaDuration: reading.esaDuration) else {
            clearReadingStatus()
            return
        }

        if currentReadingStatus == nil {
            readingStatusEpisodeID += 1
        }

        let status = Libre3ReadingStatus(kind: kind, episodeID: readingStatusEpisodeID)
        currentReadingStatus = status
        DebugMessageSingleton.shared.libreLinkUpOverlayError = status.message
    }

    private func readingStatusKind(
        for issues: [Libre3GlucoseQualityIssue],
        esaDuration: UInt16
    ) -> Libre3ReadingStatus.Kind? {
        // Warm-up and expiry own their UI. They can coexist with
        // `.currentGlucoseUnavailable`, so bail out before Layer B matching.
        for issue in issues {
            if case .sensorWarmup = issue {
                return nil
            }
            if case .sensorExpired = issue {
                return nil
            }
        }

        // Precedence within Layer B: ESA/recalibration is most specific, then
        // data-quality, then generic glucose-unavailable.
        for issue in issues {
            if case .sensorCondition(.esa) = issue {
                return .recalibrating(minutes: Int(esaDuration))
            }
        }

        for issue in issues {
            if case .currentDataQuality(_) = issue {
                return .dataQuality
            }
        }

        for issue in issues {
            if case .currentGlucoseUnavailable(_) = issue {
                return .unavailable
            }
        }

        return nil
    }

    private func clearReadingStatus() {
        currentReadingStatus = nil
        DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
    }

#if DEBUG
    func debugUpdateSensorAttention(_ attention: Libre3SensorAttention) {
        updateSensorAttention(attention)
    }
#endif

    /// Change-gated patch-status attention classifier. Only terminal attention
    /// (`replaceSensor` / `sensorEnded`) persists the replacement flag; unknown
    /// and soft states are logged or surfaced conservatively without affecting
    /// reconnect, credentials, watch snapshots, or notification delivery.
    private func updateSensorAttention(_ attention: Libre3SensorAttention) {
        guard attention != lastSensorAttention else { return }
        lastSensorAttention = attention
        sensorAttention = attention

        let needsReplacement = attention == .replaceSensor || attention == .sensorEnded
        if sensorNeedsReplacement != needsReplacement {
            sensorNeedsReplacement = needsReplacement
            SharedData.libre3SensorNeedsReplacement = needsReplacement
        }

        switch attention {
        case .replaceSensor:
            Libre3DiagnosticsLog.record("attention-replaceSensor")
        case .sensorEnded:
            Libre3DiagnosticsLog.record("attention-sensorEnded")
        case .checkSensor:
            Libre3DiagnosticsLog.record("attention-checkSensor")
        case .unknown(let code):
            Libre3DiagnosticsLog.record("attention-unknown code=\(code)")
        case .none:
            Libre3DiagnosticsLog.record("attention-none")
        }

        // This is the single change-gated notification trigger for sensor-reported
        // attention transitions; terminal states post, recovery/soft states retract.
        Task { await SensorAlertNotificationManager.shared.update(for: attention) }

        // Terminal and unknown states use `.notice` because it is retained more
        // reliably than `.info` in unified-log archives — better odds, not a guarantee.
        switch attention {
        case .replaceSensor, .sensorEnded:
            // Terminal sensor attention owns the recovery action. Prevent a
            // correct replacement alert being followed by a bogus proximity
            // alert 20 minutes later.
            setSignalLossState(deadline: nil)
            Logger.libre3.notice("Libre3 BLE attention terminal \(String(describing: attention), privacy: .public)")
        case .checkSensor:
            Logger.libre3.info("Libre3 BLE attention checkSensor")
        case .unknown(let code):
            Logger.libre3.notice("Libre3 BLE attention unknown \(code, privacy: .public)")
        case .none:
            break
        }
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

    private func armSignalLossForAdvancingReading(_ reading: RealtimeGlucoseReading) {
        // This is an OS-scheduled dead-man switch, not an in-process watchdog:
        // a suspended or killed app cannot execute code to detect the silence it
        // is supposed to report, while Notification Center can fire autonomously.
        // Only an advancing lifeCount proves a new minute arrived. Duplicate
        // frames must not postpone the deadline; this comparison depends on
        // `forgetSensor()` resetting the old sensor's much larger life count.
        guard reading.lifeCount > (lastArmedLifeCount ?? 0) else { return }
        lastArmedLifeCount = reading.lifeCount
        setSignalLossState(deadline: Date().addingTimeInterval(Self.signalLossThreshold))
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
        reconcileSignalLossArming()
    }

    /// Reconciles lifecycle and user policy with the manager's current
    /// signal-loss deadline. This is the single grace-arm policy site; realtime
    /// advancing readings remain the only path that moves an existing deadline.
    private func reconcileSignalLossArming() {
        // Deadline recovery must complete before grace arming. Otherwise a
        // relaunch could replace an earlier, nearer OS deadline with a fresh
        // 20-minute window. Recovery explicitly re-enters this method afterward.
        guard signalLossDeadlineRecovered else { return }

        guard SharedData.libre3SignalLossAlertEnabled else {
            setSignalLossState(deadline: nil)
            return
        }

        if sensorNeedsReplacement {
            setSignalLossState(deadline: nil)
            return
        }

        let lifecycle = dataPlaneState?.latestLifecycle ?? fallbackLifecycle()
        // A nil lifecycle is unknown, not proof that the sensor is active.
        // Fresh pairs can be warming before either patch status or a persisted
        // anchor can classify them, so preserve the current state and do not
        // grace-arm or cancel until classification exists.
        guard let lifecycle else { return }
        guard !lifecycle.isWarmingUp, !lifecycle.isExpired else {
            setSignalLossState(deadline: nil)
            return
        }

        if currentSignalLossDeadline == nil {
            setSignalLossState(deadline: Date().addingTimeInterval(Self.signalLossThreshold))
        }
    }

    /// Reconciles a signal-loss settings change, then bumps the executor revision
    /// with the unchanged deadline so critical-level changes replace the pending
    /// request without restarting its clock.
    func signalLossSettingsChanged() {
        reconcileSignalLossArming()
        // A theoretical settings change before startup recovery completes cannot
        // re-apply the pending request here. Recovery completion remains
        // authoritative and reconciles immediately afterward; in normal use it
        // finishes during launch, before Settings can be changed.
        guard signalLossDeadlineRecovered else { return }
        SensorAlertNotificationManager.shared.setSignalLossState(
            deadline: currentSignalLossDeadline
        )
    }

    private func setSignalLossState(deadline: Date?) {
        currentSignalLossDeadline = deadline
        SensorAlertNotificationManager.shared.setSignalLossState(deadline: deadline)
    }

    private func recoverSignalLossDeadlineIfNeeded() {
        guard !signalLossDeadlineRecoveryStarted else { return }
        signalLossDeadlineRecoveryStarted = true
        Task { [weak self] in
            let deadline = await SensorAlertNotificationManager.shared.pendingSignalLossDeadline()
            let deliveredNotifications = await UNUserNotificationCenter.current().deliveredNotifications()
            guard let self else { return }
            // Best-effort observation with date-keyed deduplication: a banner the
            // user taps or clears before this query is missed, and a re-fired alert
            // may coalesce. This is not a definitive count of alerts users saw.
            if let delivered = deliveredNotifications.first(where: {
                $0.request.identifier == SensorAlertNotificationManager.signalLossIdentifier
            }), SharedData.libre3LastRecordedSignalLossDeliveryDate != delivered.date {
                Libre3DiagnosticsLog.recordNotable("signal-loss-delivered", at: delivered.date)
                SharedData.libre3LastRecordedSignalLossDeliveryDate = delivered.date
            }
            // Mirror only: adopting an existing request must not reschedule it.
            if let deadline {
                self.currentSignalLossDeadline = deadline
            }
            self.signalLossDeadlineRecovered = true
            // Deliberate repeat policy: if an outage notification already fired,
            // a process relaunch finds no pending request and may grace-arm one
            // more 20-minute warning. A warm resume is not guaranteed to repeat.
            // This favors another warning over silently remaining offline without
            // persisting per-outage bookkeeping.
            self.reconcileSignalLossArming()
        }
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

    private func refreshExpiryReminders() {
        guard let anchor = sensorStartDate else { return }
        // Wear duration is the sensor-reported value persisted at pairing; skip
        // scheduling until it is known instead of guessing a default lifetime.
        let wear = SharedData.libre3WearDurationMinutes
        guard wear > 0 else { return }
        // A new sensor gets a new start anchor; reconnects to the same sensor keep
        // the existing one-shot notification requests untouched.
        guard lastScheduledExpiryAnchor != anchor else { return }
        lastScheduledExpiryAnchor = anchor
        Task { await SensorAlertNotificationManager.shared.scheduleExpiryReminders(
            sensorStartDate: anchor, wearDurationMinutes: wear) }
    }

    /// Derive the wall-clock sensor-start anchor once (`now − lifeCount·60s`) and
    /// persist it so timestamps stay stable across reconnects (PLAN §8).
    private func seedAnchorIfNeeded(lifeCount: Int) {
        guard sensorStartDate == nil, lifeCount > 0 else { return }
        let anchor = Date().addingTimeInterval(-Double(lifeCount) * 60)
        sensorStartDate = anchor
        SharedData.libre3SensorStartDate = anchor
        // First reliable anchor derivation is the earliest point where expiry
        // reminders can be scheduled for a newly paired sensor.
        refreshExpiryReminders()
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
        // `graphHistoryReversed`, `lastMeasurement = [0]`). Order by wall-clock
        // date because Libre 3 lifeCount resets to 0 on each new sensor; use
        // lifeCount only as a stable tie-breaker for equal timestamps.
        let newestFirst: (LibreLinkUpGlucose, LibreLinkUpGlucose) -> Bool = { lhs, rhs in
            if lhs.glucose.date == rhs.glucose.date {
                return lhs.glucose.id > rhs.glucose.id
            }
            return lhs.glucose.date > rhs.glucose.date
        }
        let historicalNewestFirst = historicalByLifeCount.values.sorted(by: newestFirst)
        let newestHistoricalDate = historicalNewestFirst.first?.glucose.date
        let windowStart = Date().addingTimeInterval(-Self.displayWindowSeconds)

        // Minute overlay: 1-min points newer than the newest 5-min historical
        // value (older ones are covered by the 5-min line). Memory is bounded by
        // `pruneBuffers`.
        let minuteNewestFirst: [LibreLinkUpGlucose]
        if let newestHistoricalDate {
            minuteNewestFirst = minuteByLifeCount.values
                .filter { $0.glucose.date > newestHistoricalDate }
                .sorted(by: newestFirst)
        } else {
            // No historical series yet (cold start before backfill / embedded
            // history): show the realtime minute points alone.
            minuteNewestFirst = minuteByLifeCount.values
                .filter { $0.glucose.date > windowStart }
                .sorted(by: newestFirst)
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

    private func finishConnectedAttempt(traceStreamEnd: Bool) {
        guard attemptReachedDidConnect, !attemptEndRecorded else { return }
        attemptEndRecorded = true

        if !sessionProducedGlucose {
            consecutiveNoStreamCycles += 1
            if consecutiveNoStreamCycles == Self.freshDiscoveryNoStreamCycles {
                forceFreshDiscoveryNextAttempt = true
                Libre3DiagnosticsLog.recordNotable(
                    "no-stream-livelock cycles=\(Self.freshDiscoveryNoStreamCycles) action=fresh-discovery"
                )
            }
        }

        if traceStreamEnd {
            Libre3DiagnosticsLog.traceReconnect(
                "stream-ended streamed=\(sessionProducedGlucose) no-stream-cycles=\(consecutiveNoStreamCycles)"
            )
        }
    }

    // MARK: - Helpers

    private static func reconnectDelay(from start: Date, to end: Date) -> String {
        String(format: "%.1fs", max(0, end.timeIntervalSince(start)))
    }

    private static func dataPlaneChannelName(for characteristic: CBUUID) -> String {
        DataPlaneChannel(uuidString: characteristic.uuidString)?.rawValue
            ?? characteristic.uuidString
    }

    /// Recovery disposition is deliberately per case, not per enum type:
    /// `writeTimeout` remains transport even though PairingFlow owns the case.
    private static func failureClass(for error: Error) -> String {
        if let pairingError = error as? PairingFlowError {
            switch pairingError {
            case .phase6VerificationFailed,
                 .phase5EphemeralPublicKeyMismatch,
                 .unexpectedCommandResponse,
                 .sensorCertificateVerificationFailed:
                return "credential"
            // `writeTimeout` is a transport failure that happens to live in the
            // credential-shaped pairing error enum.
            case .writeTimeout:
                return "transport"
            default:
                return "other"
            }
        }
        if error is SensorSessionError || error is SensorScannerError {
            return "transport"
        }
        return "other"
    }

    private static func compactErrorName(for error: Error) -> String {
        let supportSafeName = supportSafeDescription(for: error)
            .prefix { $0 != "(" }
        return supportSafeName
            .split(separator: ".")
            .last
            .map(String.init) ?? String(supportSafeName)
    }

    private static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw Libre3DirectError.entropyUnavailable(status)
        }
        return Data(bytes)
    }

    /// Produces support-safe diagnostics while retaining error type/case names,
    /// ATT/CoreBluetooth codes, and characteristic UUIDs. Every associated
    /// `Data` value is represented only by its byte count; unknown error types
    /// omit associated values. This is the same content policy intended for the
    /// upcoming `Libre3DiagnosticsLog`.
    private static func supportSafeDescription(for error: Error) -> String {
        switch error {
        case let error as PairingFlowError:
            switch error {
            case .sessionKeyDerivationNotImplemented:
                return "sessionKeyDerivationNotImplemented"
            case .commandTransportRequired:
                return "commandTransportRequired"
            case .phoneCertRequired:
                return "phoneCertRequired"
            case .unexpectedCommandResponse(let label, let expectedPrefix, let actual):
                return "unexpectedCommandResponse(label=\(label), expectedPrefixBytes=\(expectedPrefix.count), actualBytes=\(actual.count))"
            case .sensorR1WrongSize(let count):
                return "sensorR1WrongSize(\(count))"
            case .blePINWrongSize(let count):
                return "blePINWrongSize(\(count))"
            case .tail4WrongSize(let count):
                return "tail4WrongSize(\(count))"
            case .phase6VerificationFailed(let message):
                return "phase6VerificationFailed(\(message))"
            case .phase5MaterialUnavailable:
                return "phase5MaterialUnavailable"
            case .phase5EphemeralPublicKeyMismatch(let expected, let actual):
                return "phase5EphemeralPublicKeyMismatch(expectedBytes=\(expected.count), actualBytes=\(actual.count))"
            case .randomFailed(let status):
                return "randomFailed(\(status))"
            case .writeTimeout(let label, let seconds):
                return "writeTimeout(label=\(label), seconds=\(seconds))"
            case .sensorCertificateVerificationFailed:
                return "sensorCertificateVerificationFailed"
            @unknown default:
                return supportSafeUnknownDescription(for: error)
            }

        case let error as Libre3NFCError:
            switch error {
            case .readerUnavailable:
                return "readerUnavailable"
            case .sessionAlreadyActive:
                return "sessionAlreadyActive"
            case .noTag:
                return "noTag"
            case .multipleTags:
                return "multipleTags"
            case .nonISO15693Tag:
                return "nonISO15693Tag"
            case .invalidPatchInfo(let data):
                return "invalidPatchInfo(bytes=\(data.count))"
            case .invalidActivationResponse(let data):
                return "invalidActivationResponse(bytes=\(data.count))"
            case .invalidActivationResponseForPatch(let commandCode, let patchInfo, let raw):
                return "invalidActivationResponseForPatch(commandCode=\(commandCode), stateByte=\(patchInfo.stateByte), rawBytes=\(raw.count), patchRawBytes=\(patchInfo.raw.count), patchInputRawBytes=\(patchInfo.inputRaw.count))"
            case .unexpectedSensorState(let patchInfo):
                return "unexpectedSensorState(stateByte=\(patchInfo.stateByte), patchRawBytes=\(patchInfo.raw.count), patchInputRawBytes=\(patchInfo.inputRaw.count))"
            @unknown default:
                return supportSafeUnknownDescription(for: error)
            }

        case is CancellationError,
             is Libre3DirectError,
             is SensorScannerError,
             is SensorSessionError,
             is SensorSessionTransportError,
             is Libre3ReceiverIDError,
             is Libre3PatchContextError,
             is Libre3SensorStateError,
             is DataFrameError,
             is BleFramingError,
             is DataPlaneCryptoError,
             is HistoricalReadingPageError,
             is RealtimeGlucoseReadingError,
             is ClinicalReadingRecordError,
             is PatchStatusError,
             is PatchControlCommandError,
             is CipherFnError,
             is Phase5SessionDataError,
             is Phase5KeyScheduleError,
             is Phase6ResponseError,
             is EphemeralExchangeError,
             is ChallengeError,
             is PhoneCertError,
             is SensorCertError,
             is SessionKeyError,
             is KAuthError,
             is AESCCMError,
             is LibAESError,
             is FirstPairSourceSliceError,
             is Child23KAuthImportError:
            return String(describing: error)

        default:
            return supportSafeUnknownDescription(for: error)
        }
    }

    private static func supportSafeUnknownDescription(for error: Error) -> String {
        let typeName = String(describing: type(of: error))
        if let caseName = Mirror(reflecting: error).children.first?.label {
            return "\(typeName).\(caseName)"
        }
        return typeName
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
