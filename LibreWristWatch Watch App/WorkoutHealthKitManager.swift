//
//  WorkoutHealthKitManager.swift
//  FLwatchWatchApp
//
//  Owns the watch-local HealthKit workout transaction and Libre 3 lifetime.
//

import CoreBluetooth
import Foundation
import HealthKit
import OSLog
import Observation
import WatchConnectivity
import WatchKit

private extension WorkoutTypeOption {
    var healthKitActivityType: HKWorkoutActivityType {
        switch self {
        case .hiking: return .hiking
        case .yoga: return .yoga
        case .walking: return .walking
        case .running: return .running
        case .cycling: return .cycling
        case .mixedCardio: return .mixedCardio
        case .functionalStrengthTraining: return .functionalStrengthTraining
        case .traditionalStrengthTraining: return .traditionalStrengthTraining
        case .elliptical: return .elliptical
        case .rowing: return .rowing
        case .stairClimbing: return .stairClimbing
        }
    }

    static func from(_ activityType: HKWorkoutActivityType) -> WorkoutTypeOption {
        switch activityType {
        case .hiking: return .hiking
        case .yoga: return .yoga
        case .walking: return .walking
        case .running: return .running
        case .cycling: return .cycling
        case .mixedCardio: return .mixedCardio
        case .functionalStrengthTraining: return .functionalStrengthTraining
        case .traditionalStrengthTraining: return .traditionalStrengthTraining
        case .elliptical: return .elliptical
        case .rowing: return .rowing
        case .stairClimbing: return .stairClimbing
        default: return .yoga
        }
    }
}

private extension WorkoutLocationOption {
    var healthKitLocationType: HKWorkoutSessionLocationType {
        switch self {
        case .indoor: return .indoor
        case .outdoor: return .outdoor
        }
    }

    static func from(_ locationType: HKWorkoutSessionLocationType) -> WorkoutLocationOption {
        locationType == .outdoor ? .outdoor : .indoor
    }
}

@MainActor
@Observable
final class WorkoutHealthKitManager: NSObject {
    enum OperationState: Equatable {
        case idle
        case starting
        case recovering
        case active
        case ending
    }

    static let shared = WorkoutHealthKitManager()

    private(set) var operationState: OperationState = .idle
    private(set) var bluetoothAuthorization: CBManagerAuthorization = CBManager.authorization
    private(set) var currentHeartRate: Double?
    private(set) var currentDistanceMeters: Double?

    var isBusy: Bool {
        operationState == .starting || operationState == .recovering || operationState == .ending
    }

    var workoutSessionStateDescription: String? {
        session.map { Self.stateDescription($0.state) }
    }

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var bluetoothPermissionCentral: CBCentralManager?
    private var recoveryAttempted = false
    private var explicitEndInProgress = false
    private var startupFailed = false
    private var pendingStartSession: HKWorkoutSession?
    private var pendingStartContinuation: CheckedContinuation<Void, Error>?

    /// A reachable phone force-sends its current provisioning package. The
    /// package install and acknowledgement are both local operations after the
    /// message arrives, so a short foreground settling window is sufficient;
    /// the later claim remains version-validated by the phone as the backstop.
    private let provisioningSettleDelay: Duration = .seconds(2)

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "WorkoutHealthKitManager"
    )

    private static func stateDescription(_ state: HKWorkoutSessionState) -> String {
        switch state {
        case .notStarted: "not-started"
        case .running: "running"
        case .ended: "ended"
        case .paused: "paused"
        case .prepared: "prepared"
        case .stopped: "stopped"
        @unknown default: "unknown-\(state.rawValue)"
        }
    }

    /// The workout lifecycle owns monitoring so navigating away from its view
    /// cannot interrupt battery sampling while HealthKit keeps the session live.
    private func beginBatteryMonitoring() {
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
    }

    private func endBatteryMonitoring() {
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = false
    }

    private override init() {
        super.init()
    }

    /// Allocating a central is CoreBluetooth's permission request. Doing it
    /// while the start card is visible keeps the system prompt in foreground
    /// and does not instantiate the Libre 3 engine before a workout owns it.
    func preflightBluetoothPermissionIfNeeded() {
        guard SharedData.cgmProviderKind == .libre3BLE,
              !WorkoutModeStore.shared.isActive else { return }

        bluetoothAuthorization = CBManager.authorization
        guard bluetoothAuthorization == .notDetermined,
              bluetoothPermissionCentral == nil else { return }
        bluetoothPermissionCentral = CBCentralManager(delegate: self, queue: nil)
    }

    func startWorkout(
        lowGlucoseThreshold: Int,
        workoutType: WorkoutTypeOption
    ) async -> WorkoutStartResult {
        // A start must not race the one-time recovery pass. Only after HealthKit
        // reports no live session is an unmatched watch ownership claim stale.
        if !recoveryAttempted {
            await recoverActiveWorkoutIfNeeded()
        }

        guard operationState == .idle,
              session == nil,
              !WorkoutModeStore.shared.isActive else {
            return .startFailed
        }

        operationState = .starting
        startupFailed = false
        currentHeartRate = nil
        currentDistanceMeters = nil
        let providerKind = SharedData.cgmProviderKind

        if providerKind == .libre3BLE,
           !(await clearStaleLibre3ClaimBeforeStart()) {
            operationState = .idle
            return .ownershipClaimRejected
        }

        if let validationFailure = await validateProviderForStart(providerKind) {
            operationState = .idle
            return validationFailure
        }

        let authorizationResult = await requestAuthorization()
        guard authorizationResult == .started else {
            operationState = .idle
            return authorizationResult
        }

        let configuration = makeConfiguration(for: workoutType)
        let workoutSession: HKWorkoutSession
        do {
            workoutSession = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
        } catch {
            logger.error("Could not create workout session: \(error.localizedDescription, privacy: .public)")
            operationState = .idle
            return .startFailed
        }

        let workoutBuilder = workoutSession.associatedWorkoutBuilder()
        configure(workoutSession, builder: workoutBuilder, configuration: configuration)

        session = workoutSession
        builder = workoutBuilder
        beginBatteryMonitoring()

        let workoutSessionID = UUID()
        let startedAt = Date()

        do {
            try await startActivityAndWaitUntilRunning(workoutSession, at: startedAt)
            try await workoutBuilder.beginCollection(at: startedAt)
        } catch {
            logger.error("Could not start workout transaction: \(error.localizedDescription, privacy: .public)")
            rollbackUncommittedWorkout(workoutSession, builder: workoutBuilder)
            return .startFailed
        }

        guard self.session === workoutSession,
              !startupFailed,
              WorkoutModeStore.shared.activate(
                workoutSessionID: workoutSessionID,
                startedAt: workoutSession.startDate ?? startedAt,
                lowGlucoseThreshold: lowGlucoseThreshold,
                workoutType: workoutType,
                workoutLocation: workoutType.defaultLocation,
                providerKind: providerKind
              ) else {
            logger.error("Workout session did not reach a committed running state")
            rollbackUncommittedWorkout(workoutSession, builder: workoutBuilder)
            return .startFailed
        }

        if providerKind == .libre3BLE {
            Libre3DirectManager.shared.beginWorkoutDiagnostics(
                startedAt: workoutSession.startDate ?? startedAt
            )
            guard WatchConnectivityManager.shared.claimLibre3SensorForWorkout(
                workoutSessionID: workoutSessionID
            ) else {
                Libre3DirectManager.shared.discardWorkoutDiagnostics()
                logger.error("Libre 3 workout ownership claim was rejected locally")
                rollbackUncommittedWorkout(workoutSession, builder: workoutBuilder)
                return .ownershipClaimRejected
            }
        }

        await WorkoutAlertNotificationManager.shared.startOrRecoverWorkout(
            isRecovery: false
        )
        WorkoutModeRefreshManager.shared.start()
        operationState = .active
        return .started
    }

    func endWorkout() async {
        guard let session, let builder, !explicitEndInProgress else { return }

        explicitEndInProgress = true
        operationState = .ending
        let endedAt = Date()
        let workoutSessionID = WorkoutModeStore.shared.workoutSessionID
        let providerKind = WorkoutModeStore.shared.providerKind

        _ = WorkoutModeStore.shared.markEnding(at: endedAt)
        WorkoutModeRefreshManager.shared.stop()
        await WorkoutAlertNotificationManager.shared.stopWorkout()
        if providerKind == .libre3BLE, let workoutSessionID {
            await WatchConnectivityManager.shared.releaseLibre3SensorAfterWorkout(
                workoutSessionID: workoutSessionID
            )
        }
        if providerKind == .libre3BLE {
            Libre3DirectManager.shared.finishWorkoutDiagnostics()
        }

        // Stop the activity before saving, but keep the session recoverable
        // until finishWorkout completes. A crash in this window can then retry
        // the persisted ending transaction on the next launch.
        session.stopActivity(with: endedAt)
        await finishWorkout(builder: builder, endedAt: endedAt)
        session.end()
        clearCurrentWorkout(at: endedAt)
    }

    /// Reattaches only to a workout created on this watch. When HealthKit has
    /// nothing to recover, any persisted ownership claim is stale and must be
    /// released so the phone cannot remain suppressed indefinitely.
    func recoverActiveWorkoutIfNeeded() async {
        guard !recoveryAttempted else { return }
        recoveryAttempted = true
        operationState = .recovering

        let recoveredSession: HKWorkoutSession?
        do {
            recoveredSession = try await recoverActiveWorkoutSession()
        } catch {
            logger.error("Active workout recovery failed: \(error.localizedDescription, privacy: .public)")
            await clearStaleWorkoutOwnership()
            operationState = .idle
            return
        }

        guard let recoveredSession else {
            await clearStaleWorkoutOwnership()
            operationState = .idle
            return
        }

        let recoveredBuilder = recoveredSession.associatedWorkoutBuilder()
        let configuration = recoveredSession.workoutConfiguration
        configure(recoveredSession, builder: recoveredBuilder, configuration: configuration)
        session = recoveredSession
        builder = recoveredBuilder
        beginBatteryMonitoring()

        let persistedWorkoutWasEnding = WorkoutModeStore.shared.isActive
            && WorkoutModeStore.shared.isEnding
        let ownershipState = SharedData.libre3SessionOwner
        let workoutSessionID = WorkoutModeStore.shared.workoutSessionID
            ?? ownershipState.workoutSessionID
            ?? UUID()
        let workoutType = WorkoutTypeOption.from(configuration.activityType)
        let workoutLocation = WorkoutLocationOption.from(configuration.locationType)
        let providerKind: CGMProviderKind
        if ownershipState.hasActiveWatchClaim,
           ownershipState.workoutSessionID == workoutSessionID {
            providerKind = .libre3BLE
        } else if WorkoutModeStore.shared.isActive {
            providerKind = WorkoutModeStore.shared.providerKind
        } else {
            providerKind = SharedData.cgmProviderKind
        }
        let startedAt = recoveredSession.startDate
            ?? WorkoutModeStore.shared.startedAt
            ?? Date()
        let threshold = WorkoutModeStore.shared.isActive
            ? WorkoutModeStore.shared.lowGlucoseThreshold
            : defaultWorkoutThreshold(for: providerKind)

        if persistedWorkoutWasEnding {
            // markEnding persists the user's original end time. Reuse it so a
            // relaunch cannot extend the workout by the duration of the crash.
            // Do not start a new tally for this teardown-only recovery: the
            // original process may already have written the workout's result.
            let interruptedEndDate = WorkoutModeStore.shared.updatedAt
            explicitEndInProgress = true
            operationState = .ending
            WorkoutModeRefreshManager.shared.stop()
            await WorkoutAlertNotificationManager.shared.stopWorkout()
            if providerKind == .libre3BLE {
                await WatchConnectivityManager.shared.releaseLibre3SensorAfterWorkout(
                    workoutSessionID: workoutSessionID
                )
                Libre3DirectManager.shared.finishWorkoutDiagnostics()
            }
            recoveredSession.stopActivity(with: interruptedEndDate)
            await finishWorkout(builder: recoveredBuilder, endedAt: interruptedEndDate)
            recoveredSession.end()
            clearCurrentWorkout(at: interruptedEndDate)
            logger.info("Completed an interrupted workout end transaction")
            return
        }

        guard WorkoutModeStore.shared.activate(
            workoutSessionID: workoutSessionID,
            startedAt: startedAt,
            lowGlucoseThreshold: threshold,
            workoutType: workoutType,
            workoutLocation: workoutLocation,
            providerKind: providerKind,
            preservingAlertState: true
        ) else {
            logger.error("Recovered workout could not be persisted; ending untracked session")
            recoveredSession.end()
            recoveredBuilder.discardWorkout()
            self.session = nil
            self.builder = nil
            await clearStaleWorkoutOwnership()
            operationState = .idle
            return
        }

        if providerKind == .libre3BLE {
            Libre3DirectManager.shared.beginWorkoutDiagnostics(startedAt: startedAt)
            // A terminal phone reclaim intentionally makes this return false;
            // the HealthKit workout remains active and the UI explains that the
            // sensor moved to the phone.
            _ = WatchConnectivityManager.shared.claimLibre3SensorForWorkout(
                workoutSessionID: workoutSessionID
            )
        }

        await WorkoutAlertNotificationManager.shared.startOrRecoverWorkout(
            isRecovery: true
        )
        WorkoutModeRefreshManager.shared.start()
        operationState = .active
        logger.info("Recovered active watch workout")
    }

    private func validateProviderForStart(
        _ providerKind: CGMProviderKind
    ) async -> WorkoutStartResult? {
        guard SharedData.hasActiveProviderAccount else {
            return .providerNotConfigured
        }
        guard providerKind == .libre3BLE else { return nil }

        preflightBluetoothPermissionIfNeeded()
        bluetoothAuthorization = CBManager.authorization
        guard bluetoothAuthorization == .allowedAlways else {
            return .bluetoothPermissionDenied
        }

        let connectivity = WatchConnectivityManager.shared
        if connectivity.session.activationState == .activated,
           connectivity.session.isReachable {
            connectivity.requestLibre3ProvisioningFromPhone()
            do {
                try await Task.sleep(for: provisioningSettleDelay)
            } catch {
                return .startFailed
            }
        }

        guard SharedData.libre3ProvisioningInstalledRevision > 0,
              !SharedData.libre3ProvisioningInstalledDigest.isEmpty,
              !SharedData.libre3ProvisioningInstalledSensorIdentity.isEmpty,
              Libre3StateStore.isPaired,
              Libre3StateStore.loadReconnectKey() != nil else {
            return .provisioningUnavailable
        }

        guard let sensorStartDate = SharedData.libre3SensorStartDate,
              SharedData.libre3WarmupMinutes > 0,
              SharedData.libre3WearDurationMinutes > 0 else {
            return .sensorTimingUnavailable
        }

        let now = Date()
        let warmupEnd = sensorStartDate.addingTimeInterval(
            TimeInterval(SharedData.libre3WarmupMinutes) * 60
        )
        guard now >= warmupEnd else { return .sensorWarmingUp }

        let sensorEnd = sensorStartDate.addingTimeInterval(
            TimeInterval(SharedData.libre3WearDurationMinutes) * 60
        )
        guard now < sensorEnd else { return .sensorExpired }
        return nil
    }

    private func requestAuthorization() async -> WorkoutStartResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .healthDataUnavailable
        }

        let readTypes: Set<HKObjectType> = Set([
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .distanceCycling)
        ].compactMap { $0 })
        let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]

        do {
            try await healthStore.requestAuthorization(
                toShare: shareTypes,
                read: readTypes
            )
            return .started
        } catch {
            logger.error("Workout authorization failed: \(error.localizedDescription, privacy: .public)")
            return .authorizationFailed
        }
    }

    private func makeConfiguration(for workoutType: WorkoutTypeOption) -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType.healthKitActivityType
        configuration.locationType = workoutType.defaultLocation.healthKitLocationType
        return configuration
    }

    private func configure(
        _ session: HKWorkoutSession,
        builder: HKLiveWorkoutBuilder,
        configuration: HKWorkoutConfiguration
    ) {
        session.delegate = self
        builder.delegate = self
        let dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            dataSource.enableCollection(for: heartRate, predicate: nil)
        }
        if configuration.locationType == .outdoor,
           let workoutDistanceType = distanceType(for: configuration.activityType) {
            dataSource.enableCollection(for: workoutDistanceType, predicate: nil)
        }
        builder.dataSource = dataSource
        seedCurrentStatistics(from: builder, configuration: configuration)
    }

    /// HealthKit reports walking/running distance for every supported outdoor
    /// activity except cycling, which has its own quantity type.
    private func distanceType(
        for activityType: HKWorkoutActivityType
    ) -> HKQuantityType? {
        let identifier: HKQuantityTypeIdentifier
        switch activityType {
        case .hiking, .walking, .running:
            identifier = .distanceWalkingRunning
        case .cycling:
            identifier = .distanceCycling
        default:
            return nil
        }
        return HKObjectType.quantityType(forIdentifier: identifier)
    }

    /// A recovered builder can already contain live statistics before its next
    /// delegate callback. Seed the UI immediately; a new builder simply yields nil.
    private func seedCurrentStatistics(
        from builder: HKLiveWorkoutBuilder,
        configuration: HKWorkoutConfiguration
    ) {
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
           let quantity = builder.statistics(for: heartRate)?.mostRecentQuantity() {
            currentHeartRate = quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
        } else {
            currentHeartRate = nil
        }

        if configuration.locationType == .outdoor,
           let workoutDistanceType = distanceType(for: configuration.activityType),
           let quantity = builder.statistics(for: workoutDistanceType)?.sumQuantity() {
            currentDistanceMeters = quantity.doubleValue(for: .meter())
        } else {
            currentDistanceMeters = nil
        }
    }

    private func defaultWorkoutThreshold(for providerKind: CGMProviderKind) -> Int {
        providerKind == .libre3BLE
            ? SharedData.libre3WorkoutLowDefaultMgDL
            : SensorSettingsStore.shared.sensorSettings.alarmLow
    }

    private func startActivityAndWaitUntilRunning(
        _ workoutSession: HKWorkoutSession,
        at startedAt: Date
    ) async throws {
        if workoutSession.state == .running || workoutSession.state == .paused {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            pendingStartSession = workoutSession
            pendingStartContinuation = continuation
            workoutSession.startActivity(with: startedAt)

            Task { @MainActor [weak self, weak workoutSession] in
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    return
                }
                guard let self, let workoutSession,
                      self.pendingStartSession === workoutSession else { return }
                self.startupFailed = true
                self.resolvePendingStart(
                    for: workoutSession,
                    result: .failure(NSError(
                        domain: "WorkoutHealthKitManager",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Workout session did not start in time."]
                    ))
                )
            }
        }
    }

    private func resolvePendingStart(
        for workoutSession: HKWorkoutSession,
        result: Result<Void, Error>
    ) {
        guard pendingStartSession === workoutSession,
              let continuation = pendingStartContinuation else { return }
        pendingStartSession = nil
        pendingStartContinuation = nil
        continuation.resume(with: result)
    }

    private func rollbackUncommittedWorkout(
        _ workoutSession: HKWorkoutSession,
        builder workoutBuilder: HKLiveWorkoutBuilder
    ) {
        endBatteryMonitoring()
        workoutSession.end()
        workoutBuilder.discardWorkout()
        if session === workoutSession {
            session = nil
            builder = nil
        }
        currentHeartRate = nil
        currentDistanceMeters = nil
        resolvePendingStart(
            for: workoutSession,
            result: .failure(NSError(
                domain: "WorkoutHealthKitManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Workout startup was cancelled."]
            ))
        )
        _ = WorkoutModeStore.shared.deactivate()
        explicitEndInProgress = false
        startupFailed = false
        operationState = .idle
    }

    private func finishWorkout(builder: HKLiveWorkoutBuilder, endedAt: Date) async {
        do {
            try await builder.endCollection(at: endedAt)
        } catch {
            // Recovery can arrive after endCollection committed but before the
            // workout was saved. Still attempt finishWorkout in that case.
            logger.error("Could not end workout collection: \(error.localizedDescription, privacy: .public)")
        }

        do {
            _ = try await builder.finishWorkout()
        } catch {
            logger.error("Could not save workout: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearCurrentWorkout(at date: Date) {
        endBatteryMonitoring()
        session = nil
        builder = nil
        currentHeartRate = nil
        currentDistanceMeters = nil
        _ = WorkoutModeStore.shared.deactivate(at: date)
        explicitEndInProgress = false
        startupFailed = false
        operationState = .idle
    }

    private func handleExternallyEndedWorkout(
        _ workoutSession: HKWorkoutSession,
        endedAt: Date
    ) async {
        guard session === workoutSession,
              !explicitEndInProgress,
              operationState != .ending,
              let builder else { return }

        operationState = .ending
        _ = WorkoutModeStore.shared.markEnding(at: endedAt)
        WorkoutModeRefreshManager.shared.stop()
        await WorkoutAlertNotificationManager.shared.stopWorkout()
        let ownershipState = SharedData.libre3SessionOwner
        let workoutSessionID = WorkoutModeStore.shared.workoutSessionID
            ?? ownershipState.workoutSessionID
        let claimMatchesWorkout = ownershipState.hasActiveWatchClaim
            && ownershipState.workoutSessionID == workoutSessionID
        let wasDirectWorkout = WorkoutModeStore.shared.providerKind == .libre3BLE
            || claimMatchesWorkout
        if let workoutSessionID,
           WorkoutModeStore.shared.providerKind == .libre3BLE
            || (ownershipState.hasActiveWatchClaim
                && ownershipState.workoutSessionID == workoutSessionID) {
            await WatchConnectivityManager.shared.releaseLibre3SensorAfterWorkout(
                workoutSessionID: workoutSessionID
            )
        }
        if wasDirectWorkout {
            Libre3DirectManager.shared.finishWorkoutDiagnostics()
        }
        workoutSession.end()
        await finishWorkout(builder: builder, endedAt: endedAt)
        clearCurrentWorkout(at: endedAt)
    }

    private func clearStaleWorkoutOwnership() async {
        WorkoutModeRefreshManager.shared.stop()
        await WorkoutAlertNotificationManager.shared.stopWorkout()
        let ownershipState = SharedData.libre3SessionOwner
        let wasDirectWorkout = WorkoutModeStore.shared.providerKind == .libre3BLE
            || ownershipState.hasActiveWatchClaim
        let staleWorkoutSessionID = WorkoutModeStore.shared.workoutSessionID
            ?? ownershipState.workoutSessionID
        if let staleWorkoutSessionID,
           ownershipState.hasActiveWatchClaim,
           ownershipState.workoutSessionID == staleWorkoutSessionID {
            await WatchConnectivityManager.shared.releaseLibre3SensorAfterWorkout(
                workoutSessionID: staleWorkoutSessionID
            )
        }
        if wasDirectWorkout {
            Libre3DirectManager.shared.finishWorkoutDiagnostics()
        }
        endBatteryMonitoring()
        let workoutStore = WorkoutModeStore.shared
        if workoutStore.isActive
            || workoutStore.isEnding
            || workoutStore.workoutSessionID != nil {
            _ = workoutStore.deactivate()
        }
    }

    /// Recovery has already established that this process owns no live
    /// HealthKit workout. Release an orphaned watch claim before allocating the
    /// next session so it cannot permanently reject every future start.
    private func clearStaleLibre3ClaimBeforeStart() async -> Bool {
        guard recoveryAttempted,
              session == nil,
              !WorkoutModeStore.shared.isActive else { return false }

        let ownershipState = SharedData.libre3SessionOwner
        guard ownershipState.hasActiveWatchClaim else { return true }
        guard let staleWorkoutSessionID = ownershipState.workoutSessionID else {
            return false
        }

        logger.warning(
            "Releasing stale Libre 3 workout ownership before starting a new workout"
        )
        await WatchConnectivityManager.shared.releaseLibre3SensorAfterWorkout(
            workoutSessionID: staleWorkoutSessionID
        )
        return !SharedData.libre3SessionOwner.hasActiveWatchClaim
    }

    private func recoverActiveWorkoutSession() async throws -> HKWorkoutSession? {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.recoverActiveWorkoutSession { session, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: session)
                }
            }
        }
    }
}

extension WorkoutHealthKitManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let authorization = CBManager.authorization
        Task { @MainActor in
            self.bluetoothAuthorization = authorization
            if authorization != .notDetermined {
                self.bluetoothPermissionCentral = nil
            }
        }
    }
}

extension WorkoutHealthKitManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        let description = error.localizedDescription
        Task { @MainActor in
            self.logger.error("Workout session failed: \(description, privacy: .public)")
            if self.operationState == .starting {
                self.startupFailed = true
                self.resolvePendingStart(
                    for: workoutSession,
                    result: .failure(NSError(
                        domain: "WorkoutHealthKitManager",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: description]
                    ))
                )
                return
            }
            await self.handleExternallyEndedWorkout(workoutSession, endedAt: Date())
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            let providerKind = WorkoutModeStore.shared.isActive
                ? WorkoutModeStore.shared.providerKind
                : SharedData.cgmProviderKind
            if providerKind == .libre3BLE {
                Libre3DiagnosticsLog.traceReconnect(
                    "hk-state from=\(Self.stateDescription(fromState)) " +
                        "to=\(Self.stateDescription(toState))"
                )
            }
            self.logger.info(
                "Workout state changed from \(fromState.rawValue, privacy: .public) to \(toState.rawValue, privacy: .public)"
            )
            if toState == .running || toState == .paused {
                self.resolvePendingStart(for: workoutSession, result: .success(()))
            }
            if toState == .ended {
                if self.operationState == .starting {
                    self.startupFailed = true
                    self.resolvePendingStart(
                        for: workoutSession,
                        result: .failure(NSError(
                            domain: "WorkoutHealthKitManager",
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "Workout ended during startup."]
                        ))
                    )
                    return
                }
                await self.handleExternallyEndedWorkout(workoutSession, endedAt: date)
            }
        }
    }
}

extension WorkoutHealthKitManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Reduce HealthKit objects to Sendable scalar values on the builder's
        // delegate queue; no HealthKit object crosses into the main actor.
        let beatsPerMinute: Double? = if
            let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
            collectedTypes.contains(heartRate),
            let quantity = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity()
        {
            quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        } else {
            nil
        }

        let distanceMeters = [
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .distanceCycling)
        ]
        .compactMap { $0 }
        .first { collectedTypes.contains($0) }
        .flatMap { workoutBuilder.statistics(for: $0)?.sumQuantity() }
        .map { $0.doubleValue(for: .meter()) }

        guard beatsPerMinute != nil || distanceMeters != nil else { return }
        Task { @MainActor in
            if let beatsPerMinute {
                self.currentHeartRate = beatsPerMinute
            }
            if let distanceMeters {
                self.currentDistanceMeters = distanceMeters
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
