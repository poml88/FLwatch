//
//  WorkoutModeRefreshManager.swift
//  FLwatchWatchApp
//

import Foundation
import OSLog
import UserNotifications

/// Keeps cloud-backed glucose current while HealthKit grants workout runtime.
/// Direct BLE remains push-driven; its only work here is sampling an active
/// discovery or connect wait for diagnostics without adding another wakeup.
@MainActor
final class WorkoutModeRefreshManager {
    static let shared = WorkoutModeRefreshManager()

    private let refreshInterval: Duration = .seconds(60)
    private var refreshTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "WorkoutModeRefreshManager"
    )

    private init() {}

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshNow(trigger: "workout-start")

            while !Task.isCancelled, WorkoutModeStore.shared.isActive {
                do {
                    try await Task.sleep(for: self.refreshInterval)
                } catch {
                    break
                }
                await self.refreshNow(trigger: "workout-minute")
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshNow(trigger: String) async {
        guard WorkoutModeStore.shared.isActive else { return }

        if WorkoutModeStore.shared.providerKind.isDirectBLE {
            Libre3DirectManager.shared.traceConnectWaitIfNeeded()
        } else {
            logger.debug("Running cloud workout refresh [\(trigger, privacy: .public)]")
            _ = await LibreLinkUpService.shared.requestReloadIfNeeded(maxAgeMinutes: 1)
            await WorkoutAlertNotificationManager.shared.evaluateCurrentReading()
        }
        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
    }
}

/// Owns watch-local workout alerts without taking over Notification Center's
/// delegate. `WatchConnectivityManager` remains the single foreground router.
@MainActor
final class WorkoutAlertNotificationManager {
    private enum NotificationFamily {
        case glucose(GlucoseAlertTier)
        case rapidDrop
    }

    static let shared = WorkoutAlertNotificationManager()

    nonisolated private static let notificationIdentifierPrefix = "watch-workout-"
    nonisolated static let notificationCategoryIdentifier = "WATCH_WORKOUT_ALERT"
    nonisolated static let snoozeActionIdentifier = "WATCH_WORKOUT_ALERT_SNOOZE"
    private static let noReadingIdentifier = "watch-workout-no-reading"
    private static let reconnectGateIdentifier = "watch-workout-reconnect-gate"
    private static let snoozeInterval: TimeInterval = 15 * 60
    /// Deliberately half the phone's 20-minute signal-loss dead-man. That one
    /// covers a phone left behind on a table, where the user is not relying on it
    /// minute to minute. A workout is the opposite: the watch is the only device
    /// present, glucose is moving fastest, and the user can act on a warning
    /// immediately by moving the sensor arm or ending the session. Ten minutes
    /// still absorbs two missed Dexcom five-minute readings, and ten missed
    /// Libre 3 ones.
    private static let noReadingInterval: TimeInterval = 10 * 60
    private static let maximumGlucoseAgeForAlerts: TimeInterval = 3 * 60
    private static let minimumRepeatInterval: TimeInterval = 5 * 60
    // Sensor/network jitter can put a nominal five-minute reading a few seconds
    // early; use the same tolerance as the phone alert policy.
    private static let repeatIntervalTolerance: TimeInterval = 10
    private static let deliveryDelay: TimeInterval = 1

    private let notificationCenter = UNUserNotificationCenter.current()
    private var isWorkoutAlertingActive = false
    private var isEvaluating = false
    private var evaluationRequested = false
    /// Invalidates a suspended gate notification when its advice is retracted.
    private var reconnectGateNotificationGeneration = 0
    // Process-local dedupe avoids a workout-state file write every minute. The
    // pending OS request carries its own deadline across a crash or suspension.
    private var lastArmedReadingDate: Date?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "WorkoutAlertNotificationManager"
    )

    private init() {}

    nonisolated static var notificationCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: notificationCategoryIdentifier,
            actions: [
                UNNotificationAction(
                    identifier: snoozeActionIdentifier,
                    title: String(
                        localized: "Snooze 15 min",
                        comment: "Notification action that snoozes a glucose alert for 15 minutes."
                    )
                )
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    nonisolated static func handlesNotificationIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(notificationIdentifierPrefix)
    }

    private static func notificationIdentifierPrefix(
        for family: NotificationFamily
    ) -> String {
        switch family {
        case .glucose(let tier):
            "\(notificationIdentifierPrefix)\(tier.rawValue)-"
        case .rapidDrop:
            "\(notificationIdentifierPrefix)rapid-drop-"
        }
    }

    func snooze(notificationIdentifier: String, now: Date = Date()) async {
        let lowPrefixes = [GlucoseAlertTier.low, .criticalLow].map {
            Self.notificationIdentifierPrefix(for: .glucose($0))
        }
        let rapidDropPrefix = Self.notificationIdentifierPrefix(for: .rapidDrop)
        let prefixesToRemove: [String]

        var alertState = WorkoutModeStore.shared.alertState
        if lowPrefixes.contains(where: { notificationIdentifier.hasPrefix($0) }) {
            alertState.lowSnoozedUntil = now.addingTimeInterval(Self.snoozeInterval)
            prefixesToRemove = lowPrefixes
        } else if notificationIdentifier.hasPrefix(rapidDropPrefix) {
            alertState.rapidDropSnoozedUntil = now.addingTimeInterval(Self.snoozeInterval)
            prefixesToRemove = [rapidDropPrefix]
        } else {
            return
        }

        guard WorkoutModeStore.shared.isActive,
              !WorkoutModeStore.shared.isEnding else { return }
        guard WorkoutModeStore.shared.updateAlertState(alertState, at: now) else {
            logger.error("Failed to persist workout alert snooze")
            return
        }

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let pendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { identifier in
                prefixesToRemove.contains { identifier.hasPrefix($0) }
            }
        if !pendingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
        }

        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        let deliveredIdentifiers = deliveredNotifications
            .map(\.request.identifier)
            .filter { identifier in
                prefixesToRemove.contains { identifier.hasPrefix($0) }
            }
        if !deliveredIdentifiers.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
        }
    }

    func startOrRecoverWorkout(isRecovery: Bool) async {
        let workoutStore = WorkoutModeStore.shared
        guard workoutStore.isActive, !workoutStore.isEnding else { return }
        isWorkoutAlertingActive = true
        _ = await WatchConnectivityManager.shared.requestWatchWorkoutNotificationAuthorization()

        let now = Date()
        let alreadyDelivered: Bool
        let pendingDeadline: Date?
        if isRecovery {
            alreadyDelivered = await hasDeliveredNoReadingAlert()
            pendingDeadline = await pendingNoReadingDeadline()
        } else {
            alreadyDelivered = false
            pendingDeadline = nil
        }
        var didArmNoReadingAlert = alreadyDelivered
        if !alreadyDelivered,
           await scheduleNoReadingNotification(
                deadline: pendingDeadline
                    ?? now.addingTimeInterval(Self.noReadingInterval),
                clearsDeliveredAlert: !isRecovery
            ) {
            didArmNoReadingAlert = true
        }
        let history = LibreLinkUpHistory.shared
        if didArmNoReadingAlert,
           history.currentGlucose > 0,
           history.lastReadingDate > .distantPast {
            lastArmedReadingDate = history.lastReadingDate
        }
        await evaluateCurrentReading()
    }

    func stopWorkout() async {
        isWorkoutAlertingActive = false
        lastArmedReadingDate = nil
        retractReconnectGate()
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let workoutRequestIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { Self.handlesNotificationIdentifier($0) }
        if !workoutRequestIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(
                withIdentifiers: workoutRequestIdentifiers
            )
        }
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [Self.noReadingIdentifier]
        )
    }

    func evaluateCurrentReading() async {
        guard isWorkoutAlertingActive,
              WorkoutModeStore.shared.isActive,
              !WorkoutModeStore.shared.isEnding else { return }
        if isEvaluating {
            evaluationRequested = true
            return
        }

        isEvaluating = true
        repeat {
            evaluationRequested = false
            await evaluateLatestReading(now: Date())
        } while evaluationRequested
            && isWorkoutAlertingActive
            && WorkoutModeStore.shared.isActive
            && !WorkoutModeStore.shared.isEnding
        isEvaluating = false
    }

    private func evaluateLatestReading(now: Date) async {
        let workoutStore = WorkoutModeStore.shared
        guard isWorkoutAlertingActive,
              workoutStore.isActive,
              !workoutStore.isEnding else { return }

        let history = LibreLinkUpHistory.shared
        var alertState = workoutStore.alertState
        let originalState = alertState

        if history.currentGlucose > 0,
           history.lastReadingDate > .distantPast,
           history.lastReadingDate > (lastArmedReadingDate ?? .distantPast) {
            let deadline = now.addingTimeInterval(Self.noReadingInterval)
            if await scheduleNoReadingNotification(
                deadline: deadline,
                clearsDeliveredAlert: true
            ) {
                // The reading date, rather than evaluation time, makes duplicate WC
                // snapshots and duplicate BLE frames unable to postpone the deadline.
                lastArmedReadingDate = history.lastReadingDate
            }
        }

        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast,
              now.timeIntervalSince(history.lastReadingDate) <= Self.maximumGlucoseAgeForAlerts else {
            alertState.activeGlucoseTier = nil
            alertState.wasDroppingQuickly = false
            persist(alertState, ifChangedFrom: originalState, at: now)
            logger.debug("Skipped workout alert evaluation because glucose is stale or unavailable")
            return
        }

        let glucose = history.currentGlucose
        let criticalThreshold = SharedData.workoutCriticalLowThresholdMgDL
        if glucose >= workoutStore.lowGlucoseThreshold {
            // Match the phone: recovery above the workout low threshold ends the
            // shared low/critical-low snooze. Stale readings return before here.
            alertState.lowSnoozedUntil = nil
        }
        let lowIsSnoozed = alertState.lowSnoozedUntil.map { now < $0 } ?? false
        let triggeredTier: GlucoseAlertTier?
        if glucose < criticalThreshold {
            triggeredTier = .criticalLow
        } else if glucose < workoutStore.lowGlucoseThreshold {
            triggeredTier = .low
        } else {
            triggeredTier = nil
        }

        switch triggeredTier {
        case .criticalLow:
            let isNewCriticalDrop = alertState.activeGlucoseTier != .criticalLow
            var criticalAlertWasScheduled = false
            if !lowIsSnoozed,
               isNewCriticalDrop || isDue(alertState.lastGlucoseNotificationDate, now: now) {
                if await scheduleGlucoseNotification(
                    tier: .criticalLow,
                    glucose: glucose,
                    threshold: criticalThreshold,
                    trendArrow: history.currentTrendArrow,
                    now: now
                ) {
                    alertState.lastGlucoseNotificationDate = now
                    criticalAlertWasScheduled = true
                }
            }
            // Staying latched in the wider low range prevents a less-severe low
            // alert immediately after glucose rises out of the critical range.
            // If escalation scheduling failed, retain the previous tier so the
            // next reading retries the safety-critical edge immediately.
            if !isNewCriticalDrop || criticalAlertWasScheduled {
                alertState.activeGlucoseTier = .criticalLow
            }

        case .low:
            let isNewWorkoutLow = alertState.activeGlucoseTier == nil
            var workoutLowAlertWasScheduled = false
            if !lowIsSnoozed,
               isNewWorkoutLow || isDue(alertState.lastGlucoseNotificationDate, now: now) {
                if await scheduleGlucoseNotification(
                    tier: .low,
                    glucose: glucose,
                    threshold: workoutStore.lowGlucoseThreshold,
                    trendArrow: history.currentTrendArrow,
                    now: now
                ) {
                    alertState.lastGlucoseNotificationDate = now
                    workoutLowAlertWasScheduled = true
                }
            }
            if !isNewWorkoutLow || workoutLowAlertWasScheduled {
                alertState.activeGlucoseTier = .low
            }

        case .high, nil:
            alertState.activeGlucoseTier = nil
        }

        if SharedData.workoutRapidDropAlertsEnabled {
            let latestTrend = history.latestLibreLinkUpGlucose.map {
                $0.trendArrow ?? $0.glucose.trendArrow
            }
            let isDroppingQuickly = latestTrend == .fallingQuickly
                || latestTrend == .fallingVeryQuickly
            if isDroppingQuickly {
                let isNewRapidDrop = !alertState.wasDroppingQuickly
                let rapidDropIsSnoozed = alertState.rapidDropSnoozedUntil.map { now < $0 } ?? false
                var rapidDropAlertWasScheduled = false
                if !rapidDropIsSnoozed,
                   isNewRapidDrop
                    || isDue(alertState.lastRapidDropNotificationDate, now: now) {
                    if await scheduleRapidDropNotification(
                        glucose: glucose,
                        trendArrow: history.currentTrendArrow,
                        now: now
                    ) {
                        alertState.lastRapidDropNotificationDate = now
                        rapidDropAlertWasScheduled = true
                    }
                }
                if !isNewRapidDrop || rapidDropAlertWasScheduled {
                    alertState.wasDroppingQuickly = true
                }
            } else {
                // Arrow recovery resets the edge latch, but the independent
                // rapid-drop snooze deliberately runs for its full 15 minutes.
                alertState.wasDroppingQuickly = false
            }
        } else {
            // Re-enabling while the fastest-fall arrow remains active should
            // create a fresh edge and alert immediately.
            alertState.wasDroppingQuickly = false
        }

        persist(alertState, ifChangedFrom: originalState, at: now)
    }

    private func isDue(_ lastNotificationDate: Date?, now: Date) -> Bool {
        guard let lastNotificationDate else { return true }
        return now.timeIntervalSince(lastNotificationDate)
            >= Self.minimumRepeatInterval - Self.repeatIntervalTolerance
    }

    private func isSnoozed(notificationIdentifier: String, now: Date) -> Bool {
        let alertState = WorkoutModeStore.shared.alertState
        let isLowAlert = [GlucoseAlertTier.low, .criticalLow].contains { tier in
            notificationIdentifier.hasPrefix(
                Self.notificationIdentifierPrefix(for: .glucose(tier))
            )
        }
        if isLowAlert {
            return alertState.lowSnoozedUntil.map { now < $0 } ?? false
        }
        if notificationIdentifier.hasPrefix(
            Self.notificationIdentifierPrefix(for: .rapidDrop)
        ) {
            return alertState.rapidDropSnoozedUntil.map { now < $0 } ?? false
        }
        return false
    }

    private func persist(
        _ evaluatedState: WorkoutAlertState,
        ifChangedFrom originalState: WorkoutAlertState,
        at date: Date
    ) {
        let workoutStore = WorkoutModeStore.shared
        let currentState = workoutStore.alertState
        var alertState = evaluatedState
        // Scheduling awaits Notification Center. Preserve a snooze action that
        // reached the main actor while this evaluation was suspended.
        if currentState.lowSnoozedUntil != originalState.lowSnoozedUntil {
            alertState.lowSnoozedUntil = currentState.lowSnoozedUntil
        }
        if currentState.rapidDropSnoozedUntil != originalState.rapidDropSnoozedUntil {
            alertState.rapidDropSnoozedUntil = currentState.rapidDropSnoozedUntil
        }

        guard alertState != currentState else { return }
        if !workoutStore.updateAlertState(alertState, at: date) {
            logger.error("Failed to persist workout alert state")
        }
    }

    private func scheduleGlucoseNotification(
        tier: GlucoseAlertTier,
        glucose: Int,
        threshold: Int,
        trendArrow: String,
        now: Date
    ) async -> Bool {
        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        let currentValue = glucose.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
        let thresholdValue = threshold.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
        let title: String
        let requestsCriticalDelivery: Bool
        switch tier {
        case .criticalLow:
            title = String(
                localized: "Glucose is critically low",
                comment: "Title of a critically-low glucose notification during an Apple Watch workout."
            )
            requestsCriticalDelivery = SharedData.workoutCriticalLowCriticalAlertsEnabled
        case .low:
            title = String(
                localized: "Glucose is low during workout",
                comment: "Title of a workout-specific low-glucose notification on Apple Watch."
            )
            requestsCriticalDelivery = SharedData.workoutLowCriticalAlertsEnabled
        case .high:
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = "\(currentValue) \(trendArrow == "---" ? "-" : trendArrow)"
        content.body = String(
            localized: "Your workout alert level is \(thresholdValue).",
            comment: "Body of a low-glucose workout notification. The value is the user's workout alert threshold with its glucose unit."
        )
        let identifierPrefix = Self.notificationIdentifierPrefix(for: .glucose(tier))
        return await scheduleImmediateNotification(
            content,
            identifier: "\(identifierPrefix)\(Int(now.timeIntervalSince1970))",
            identifierFamiliesToRemove: tier == .criticalLow
                ? [
                    Self.notificationIdentifierPrefix(for: .glucose(.criticalLow)),
                    Self.notificationIdentifierPrefix(for: .glucose(.low))
                ]
                : [identifierPrefix],
            requestsCriticalDelivery: requestsCriticalDelivery
        )
    }

    private func scheduleRapidDropNotification(
        glucose: Int,
        trendArrow: String,
        now: Date
    ) async -> Bool {
        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        let currentValue = glucose.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "Glucose dropping quickly",
            comment: "Title of a rapid glucose-drop notification during an Apple Watch workout."
        )
        content.subtitle = "\(currentValue) \(trendArrow == "---" ? "-" : trendArrow)"
        content.body = String(
            localized: "Glucose is falling quickly during your workout.",
            comment: "Body of a rapid glucose-drop notification during an Apple Watch workout."
        )
        let identifierPrefix = Self.notificationIdentifierPrefix(for: .rapidDrop)
        return await scheduleImmediateNotification(
            content,
            identifier: "\(identifierPrefix)\(Int(now.timeIntervalSince1970))",
            identifierFamiliesToRemove: [identifierPrefix],
            requestsCriticalDelivery: SharedData.workoutRapidDropCriticalAlertsEnabled
        )
    }

    private func scheduleImmediateNotification(
        _ content: UNMutableNotificationContent,
        identifier: String,
        identifierFamiliesToRemove: [String],
        requestsCriticalDelivery: Bool
    ) async -> Bool {
        guard isWorkoutAlertingActive,
              WorkoutModeStore.shared.isActive,
              !WorkoutModeStore.shared.isEnding,
              let settings = await enabledNotificationSettings() else { return false }
        content.categoryIdentifier = Self.notificationCategoryIdentifier
        applyDelivery(
            to: content,
            requestsCriticalDelivery: requestsCriticalDelivery,
            settings: settings
        )

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let matchingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { identifier in
                identifierFamiliesToRemove.contains { identifier.hasPrefix($0) }
            }
        if !matchingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
        }
        // The main actor can process a snooze while either Notification Center
        // query is suspended. Do not arm an alert after that snooze was saved.
        guard !isSnoozed(notificationIdentifier: identifier, now: Date()) else {
            return false
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: Self.deliveryDelay,
                repeats: false
            )
        )
        do {
            try await notificationCenter.add(request)
            guard !isSnoozed(notificationIdentifier: identifier, now: Date()) else {
                notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: [identifier]
                )
                return false
            }
            guard isWorkoutAlertingActive,
                  WorkoutModeStore.shared.isActive,
                  !WorkoutModeStore.shared.isEnding else {
                notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: [identifier]
                )
                return false
            }
            return true
        } catch {
            logger.error("Failed to schedule workout notification: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func scheduleNoReadingNotification(
        deadline: Date,
        clearsDeliveredAlert: Bool
    ) async -> Bool {
        guard isWorkoutAlertingActive,
              WorkoutModeStore.shared.isActive,
              !WorkoutModeStore.shared.isEnding,
              let settings = await enabledNotificationSettings() else { return false }

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "No recent glucose reading",
            comment: "Title of an Apple Watch notification when no new glucose reading arrives during a workout."
        )
        content.body = String(
            localized: "Apple Watch has not received a new glucose reading during your workout.",
            comment: "Body of a notification warning that glucose readings stopped during an Apple Watch workout."
        )
        applyDelivery(
            to: content,
            requestsCriticalDelivery: SharedData.workoutNoReadingCriticalAlertsEnabled,
            settings: settings
        )
        if clearsDeliveredAlert {
            notificationCenter.removeDeliveredNotifications(
                withIdentifiers: [Self.noReadingIdentifier]
            )
        }

        let request = UNNotificationRequest(
            identifier: Self.noReadingIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(deadline.timeIntervalSinceNow, Self.deliveryDelay),
                repeats: false
            )
        )
        do {
            try await notificationCenter.add(request)
            guard isWorkoutAlertingActive,
                  WorkoutModeStore.shared.isActive,
                  !WorkoutModeStore.shared.isEnding else {
                notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: [Self.noReadingIdentifier]
                )
                return false
            }
            return true
        } catch {
            logger.error("Failed to schedule the workout no-reading notification: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// The persisted estimator calls this only on a new gate-likely transition.
    func postReconnectGateLikely() async {
        let generation = reconnectGateNotificationGeneration
        guard isWorkoutAlertingActive,
              WorkoutModeStore.shared.isActive,
              !WorkoutModeStore.shared.isEnding,
              let settings = await enabledNotificationSettings() else { return }
        // Authorization lookup suspends; Bluetooth or the workout may stop.
        guard generation == reconnectGateNotificationGeneration,
              isWorkoutAlertingActive,
              WorkoutModeStore.shared.isActive,
              !WorkoutModeStore.shared.isEnding else { return }

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "Sensor reconnect limited",
            comment: "Title of an Apple Watch workout notification when repeated sensor connection timeouts likely limit Bluetooth reconnects."
        )
        content.body = String(
            localized: "After repeated signal losses, Apple Watch now reconnects only when the sensor is close. Turn Bluetooth off and on to reset.",
            comment: "Body of an Apple Watch workout notification advising the user to toggle Bluetooth to clear an estimated sensor reconnect penalty."
        )
        // No category: this Bluetooth advice has no glucose-alert snooze action.
        applyDelivery(to: content, requestsCriticalDelivery: false, settings: settings)
        let request = UNNotificationRequest(
            identifier: Self.reconnectGateIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: Self.deliveryDelay,
                repeats: false
            )
        )
        do {
            try await notificationCenter.add(request)
            guard generation == reconnectGateNotificationGeneration,
                  isWorkoutAlertingActive,
                  WorkoutModeStore.shared.isActive,
                  !WorkoutModeStore.shared.isEnding else {
                notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: [Self.reconnectGateIdentifier]
                )
                notificationCenter.removeDeliveredNotifications(
                    withIdentifiers: [Self.reconnectGateIdentifier]
                )
                return
            }
        } catch {
            logger.error("Failed to schedule the workout reconnect-gate notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    func retractReconnectGate() {
        reconnectGateNotificationGeneration &+= 1
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.reconnectGateIdentifier]
        )
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [Self.reconnectGateIdentifier]
        )
    }

    private func hasDeliveredNoReadingAlert() async -> Bool {
        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        return deliveredNotifications.contains {
            $0.request.identifier == Self.noReadingIdentifier
        }
    }

    private func pendingNoReadingDeadline() async -> Date? {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let trigger = pendingRequests.first {
            $0.identifier == Self.noReadingIdentifier
        }?.trigger as? UNTimeIntervalNotificationTrigger
        return trigger?.nextTriggerDate()
    }

    private func enabledNotificationSettings() async -> UNNotificationSettings? {
        let settings = await notificationCenter.notificationSettings()
        guard [.authorized, .provisional].contains(settings.authorizationStatus),
              settings.alertSetting == .enabled
                || settings.notificationCenterSetting == .enabled else {
            logger.warning("Workout notification skipped because notification authorization is unavailable")
            return nil
        }
        return settings
    }

    private func applyDelivery(
        to content: UNMutableNotificationContent,
        requestsCriticalDelivery: Bool,
        settings: UNNotificationSettings
    ) {
        if requestsCriticalDelivery, settings.criticalAlertSetting == .enabled {
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        } else {
            if settings.soundSetting == .enabled {
                content.sound = .default
            }
            content.interruptionLevel = .timeSensitive
        }
        content.relevanceScore = 1
    }
}
