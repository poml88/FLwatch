//
//  SensorAlertNotificationManager.swift
//  LibreWrist
//

#if os(iOS)
import Foundation
import LibreCRKit
import OSLog
import UserNotifications

@MainActor
final class SensorAlertNotificationManager {
    static let shared = SensorAlertNotificationManager()
    nonisolated static let identifierPrefix = "libre3-sensor-alert"

    /// Fixed IDs keep rescheduling idempotent and share the sensor-alert prefix
    /// so the existing foreground notification router presents these reminders.
    enum ExpiryReminder: String, CaseIterable {
        case warning3d = "libre3-sensor-alert.expiry-3d"
        case warning24h = "libre3-sensor-alert.expiry-24h"
        case warning2h = "libre3-sensor-alert.expiry-2h"
        case ended = "libre3-sensor-alert.expiry-ended"
    }

    private static let requestIdentifier = "libre3-sensor-alert.terminal"
    nonisolated static let signalLossIdentifier = "libre3-sensor-alert.signal-loss"
    private static let signalLossOriginalDeadlineKey = "signalLossOriginalDeadline"
    private static let applicationTerminatedIdentifier = "libre3-sensor-alert.application-terminated"
    private static let reconnectFailingIdentifier = "libre3-sensor-alert.reconnect-failing"
    private static let sensorNotRespondingIdentifier = "libre3-sensor-alert.sensor-not-responding"
    private static let warmupCompletionIdentifier = "libre3-sensor-alert.warmup-complete"
    private let notificationCenter = UNUserNotificationCenter.current()
    /// In-flight authorization request shared by concurrent callers, nil when
    /// none is running.
    private var authorizationRequest: Task<Void, Never>?
    private var desiredSignalLossDeadline: Date?
    private var signalLossRevision = 0
    private var signalLossReconciliationTask: Task<Void, Never>?

    private init() { }

    /// Best-effort warning submitted from `applicationWillTerminate`. iOS does
    /// not guarantee that lifecycle callback for a user force-quit, especially
    /// when the app is already suspended.
    func postApplicationTerminated() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "FLwatch was closed")
        content.body = String(localized: "Open FLwatch to resume receiving glucose readings and alarms.")
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.applicationTerminatedIdentifier,
            content: content,
            trigger: nil
        )
        notificationCenter.add(request) { error in
            if let error {
                Logger.connectivity.error("App-termination notification scheduling failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Remove a warning left in Notification Center when the user opens FLwatch
    /// directly instead of tapping the notification.
    func clearApplicationTerminatedNotification() {
        let ids = [Self.applicationTerminatedIdentifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// App-wide auth; idempotent, and only prompts while authorization is undetermined.
    ///
    /// Single-flight: `start()` runs again from the scanner's `.poweredOn`
    /// callback, so two callers can otherwise both observe `.notDetermined`
    /// across the settings await and each raise a request. Concurrent callers
    /// share the in-flight one instead.
    func requestAuthorizationIfNeeded() async {
        if let authorizationRequest {
            await authorizationRequest.value
            return
        }
        let request = Task { await performAuthorizationRequest() }
        authorizationRequest = request
        await request.value
        authorizationRequest = nil
    }

    private func performAuthorizationRequest() async {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            Logger.connectivity.error("Sensor alert notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Adds a fixed-ID request, then removes it again if the state that justified
    /// it was cleared while `add` was suspended.
    ///
    /// `add` is async while every retract here is synchronous, so a recovery
    /// landing mid-flight removes a request that does not exist yet — and the
    /// alert then arrives anyway, describing a problem that is already over.
    /// Re-reading the desired state after the add closes that window. The state
    /// must be the persisted one the retract path clears, not a local copy.
    /// - Returns: true when the request was accepted and still wanted, i.e. the
    ///   alert now stands. False means it was never submitted or was withdrawn,
    ///   so a caller tracking delivery must be prepared to try again.
    @discardableResult
    private func add(
        _ request: UNNotificationRequest,
        whileDesired stillDesired: () -> Bool,
        logLabel: String
    ) async -> Bool {
        do {
            try await notificationCenter.add(request)
        } catch {
            Logger.connectivity.error("\(logLabel, privacy: .public) notification scheduling failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard !stillDesired() else { return true }
        let ids = [request.identifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
        return false
    }

    func postReconnectFailing() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Re-scan sensor")
        content.body = String(localized: "FLwatch is still trying to reconnect. If readings don't resume, re-pair the sensor in the Connect tab.")
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.reconnectFailingIdentifier,
            content: content,
            trigger: nil
        )
        await add(
            request,
            whileDesired: { SharedData.libre3ConnectionRequiresUserAction },
            logLabel: "Reconnect-failing"
        )
    }

    func retractReconnectFailing() {
        let ids = [Self.reconnectFailingIdentifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// The sensor takes the BLE connection but never answers the authorization
    /// handshake — see `Libre3SensorNotRespondingPolicy`. Distinct from the
    /// re-scan alert: re-pairing does not resolve this, so the body names the
    /// likeliest cause (another app holding the sensor) and its remedy.
    func postSensorNotResponding() async {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "Sensor not responding",
            comment: "Notification title shown when the Libre 3 sensor accepts the Bluetooth connection but never answers FLwatch"
        )
        // Naming the app the sensor was started in beats naming one of Abbott's
        // two apps and misleading users of the other.
        if let vendorApp = SharedData.libre3ActivatingApp.contendingAppName {
            content.body = String(
                localized: "FLwatch reaches your sensor but it doesn't answer. \(vendorApp) may be using it: a sensor serves one app at a time. Force-close that app and turn off its Bluetooth access in iOS Settings.",
                comment: "Notification body explaining that the sensor serves only one app at a time, and how to release it. The placeholder is the name of the Abbott app the sensor was started in ('FreeStyle Libre 3' or 'Libre by Abbott'); both stay untranslated."
            )
        } else {
            content.body = String(
                localized: "FLwatch reaches your sensor but it doesn't answer. Another app or device may be using it — a sensor serves one at a time.",
                comment: "Notification body for a sensor FLwatch activated itself, which no Abbott app can use, so no app can be named. Shown when the sensor accepts the connection but never answers."
            )
        }
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.sensorNotRespondingIdentifier,
            content: content,
            trigger: nil
        )
        // Only a request that actually stands counts as delivered; anything else
        // leaves the evidence path free to retry on the next failure.
        SharedData.libre3SensorNotRespondingNotified = await add(
            request,
            whileDesired: { SharedData.libre3SensorNotResponding },
            logLabel: "Sensor-not-responding"
        )
    }

    func retractSensorNotResponding() {
        let ids = [Self.sensorNotRespondingIdentifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Sets the desired signal-loss deadline, or disarms the alert with `nil`.
    ///
    /// This synchronous entry point only records intent. A single serialized
    /// worker reconciles that intent with Notification Center so callers never
    /// race one another while replacing or cancelling the fixed-ID request.
    func setSignalLossState(deadline: Date?) {
        desiredSignalLossDeadline = deadline
        signalLossRevision &+= 1
        ensureSignalLossReconciliationWorker()
    }

    /// Returns the original dead-man deadline for a pending signal-loss alert,
    /// even when quiet hours moved its OS trigger later. Used once at manager
    /// startup so an earlier deadline is not replaced by a fresh grace window.
    func pendingSignalLossDeadline() async -> Date? {
        let requests = await notificationCenter.pendingNotificationRequests()
        guard let request = requests.first(where: {
            $0.identifier == Self.signalLossIdentifier
        }) else { return nil }

        // New requests retain the dead-man deadline even when their actual fire
        // date was clamped to quiet-hours end. Older requests have no payload,
        // so keep recovering their trigger date for upgrade compatibility.
        if let storedDeadline = request.content.userInfo[Self.signalLossOriginalDeadlineKey] as? NSNumber,
           storedDeadline.doubleValue.isFinite {
            return Date(timeIntervalSince1970: storedDeadline.doubleValue)
        }
        return (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
    }

    private func ensureSignalLossReconciliationWorker() {
        guard signalLossReconciliationTask == nil else { return }
        signalLossReconciliationTask = Task { [weak self] in
            await self?.runSignalLossReconciliationWorker()
        }
    }

    private func runSignalLossReconciliationWorker() async {
        // A revision check before `add` is insufficient: `add` itself is async,
        // so a cancel can arrive during that await and the stale add can commit
        // afterward. The one worker must finish each apply, then loop whenever
        // its snapshot is stale, and exit only after the latest revision lands.
        while !Task.isCancelled {
            let revision = signalLossRevision
            let deadline = desiredSignalLossDeadline
            await applySignalLossState(deadline: deadline)
            guard revision == signalLossRevision else { continue }
            signalLossReconciliationTask = nil
            return
        }
        signalLossReconciliationTask = nil
    }

    private func applySignalLossState(deadline: Date?) async {
        let ids = [Self.signalLossIdentifier]
        guard let deadline, SharedData.libre3SignalLossAlertEnabled else {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
            notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
            return
        }

        let settings = await notificationCenter.notificationSettings()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "No glucose data")
        content.body = String(
            localized: "Your phone hasn't received readings for 20 minutes. Bring your phone closer to the sensor or check the sensor.",
            comment: "Notification explaining that the phone has lost contact with the glucose sensor and should be moved closer to it."
        )
        content.userInfo = [
            Self.signalLossOriginalDeadlineKey: deadline.timeIntervalSince1970
        ]
        // The preference alone cannot authorize critical delivery. Gate it on
        // the system's current critical-alert setting and otherwise fall back to
        // a time-sensitive notification.
        let useCritical = SharedData.libre3SignalLossCritical &&
            settings.criticalAlertSetting == .enabled
        if useCritical {
            content.interruptionLevel = .critical
            content.sound = .defaultCritical
        } else {
            content.interruptionLevel = .timeSensitive
            if settings.soundSetting == .enabled {
                content.sound = .default
            }
        }

        // Reusing an identifier replaces only a pending request. Retract an
        // already-delivered outage banner when a new reading resumes the stream.
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
        let quietHours = QuietHours.signalLoss
        let fireAt = quietHours.isMuted(at: deadline)
            ? quietHours.end(after: deadline) ?? deadline
            : deadline
        let request = UNNotificationRequest(
            identifier: Self.signalLossIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, fireAt.timeIntervalSinceNow),
                repeats: false
            )
        )
        do {
            try await notificationCenter.add(request)
        } catch {
            Logger.connectivity.error("Signal-loss notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(
        for attention: Libre3SensorAttention,
        interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive
    ) async {
        switch attention {
        case .replaceSensor:
            // A failed sensor cannot finish warm-up, so remove its pending reminder.
            cancelWarmupCompletionReminder()
            // Sensor-reported terminal state is authoritative; the scheduled
            // expiry-ended reminder is only a silent-sensor fallback.
            removeEndedExpiryReminder()
            await post(
                title: String(localized: "Replace sensor"),
                body: String(localized: "Your sensor has stopped working and needs to be replaced to resume readings."),
                interruptionLevel: interruptionLevel
            )
        case .sensorEnded:
            // A terminal sensor cannot finish warm-up, so remove its pending reminder.
            cancelWarmupCompletionReminder()
            // Sensor-reported terminal state is authoritative; the scheduled
            // expiry-ended reminder is only a silent-sensor fallback.
            removeEndedExpiryReminder()
            await post(
                title: String(localized: "Sensor ended"),
                body: String(localized: "Your sensor session has ended. Replace it to resume readings."),
                interruptionLevel: interruptionLevel
            )
        case .checkSensor, .none, .unknown:
            await retract()
        }
    }

    func scheduleWarmupCompletionReminder(
        sensorStartDate: Date,
        warmupDurationMinutes: Int,
        now: Date = Date()
    ) async {
        // The stable sensor anchor keeps reconnects from moving the completion time.
        let fireAt = sensorStartDate.addingTimeInterval(TimeInterval(warmupDurationMinutes) * 60)
        cancelWarmupCompletionReminder()
        guard fireAt > now,
              SharedData.libre3SensorIsPaired,
              SharedData.libre3SensorStartDate == sensorStartDate,
              !SharedData.libre3SensorNeedsReplacement else { return }

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireAt
        )
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Sensor warm-up complete")
        content.body = String(localized: "Your sensor is ready. Open FLwatch to check your glucose.")
        content.interruptionLevel = .active
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.warmupCompletionIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            // The sensor may have been forgotten or failed while Notification Center was adding it.
            if !SharedData.libre3SensorIsPaired ||
                SharedData.libre3SensorStartDate != sensorStartDate ||
                SharedData.libre3SensorNeedsReplacement {
                cancelWarmupCompletionReminder()
            }
        } catch {
            Logger.connectivity.error("Warm-up completion notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func cancelWarmupCompletionReminder() {
        let ids = [Self.warmupCompletionIdentifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func scheduleExpiryReminders(sensorStartDate: Date, wearDurationMinutes: Int, now: Date = Date()) async {
        // Clean slate avoids stale fire times when a new sensor has a different
        // start anchor or wear duration.
        await cancelExpiryReminders()
        let expiresAt = sensorStartDate.addingTimeInterval(TimeInterval(wearDurationMinutes) * 60)
        let expiryDateTime = expiresAt.formatted(date: .abbreviated, time: .shortened)
        let expiryTime = expiresAt.formatted(date: .omitted, time: .shortened)

        await schedule(
            .warning3d,
            fireAt: expiresAt.addingTimeInterval(-3 * 24 * 60 * 60),
            now: now,
            level: .active,
            title: String(localized: "Sensor ends in 3 days"),
            body: String.localizedStringWithFormat(
                String(localized: "Your sensor is scheduled to end on %@."),
                expiryDateTime
            )
        )
        await schedule(
            .warning24h,
            fireAt: expiresAt.addingTimeInterval(-24 * 60 * 60),
            now: now,
            level: .active,
            title: String(localized: "Sensor ends tomorrow"),
            body: String.localizedStringWithFormat(
                String(localized: "Your sensor is scheduled to end on %@."),
                expiryDateTime
            )
        )
        await schedule(
            .warning2h,
            fireAt: expiresAt.addingTimeInterval(-2 * 60 * 60),
            now: now,
            level: .timeSensitive,
            title: String(localized: "Sensor ends in 2 hours"),
            body: String.localizedStringWithFormat(
                String(localized: "Your sensor is scheduled to end at %@."),
                expiryTime
            )
        )
        await schedule(
            .ended,
            fireAt: expiresAt,
            now: now,
            level: .timeSensitive,
            title: String(localized: "Sensor session ended"),
            body: String(localized: "Replace it to resume readings.")
        )
    }

    func cancelExpiryReminders() async {
        let ids = ExpiryReminder.allCases.map(\.rawValue)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func retract() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [Self.requestIdentifier])
    }

    private func removeEndedExpiryReminder() {
        let ids = [ExpiryReminder.ended.rawValue]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func schedule(
        _ id: ExpiryReminder,
        fireAt: Date,
        now: Date,
        level: UNNotificationInterruptionLevel,
        title: String,
        body: String
    ) async {
        // Do not enqueue catch-up notifications for reminders that are already
        // in the past, such as when pairing an older active sensor.
        guard fireAt > now else { return }

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = level
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id.rawValue,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            Logger.connectivity.error("Sensor expiry reminder scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func post(
        title: String,
        body: String,
        interruptionLevel: UNNotificationInterruptionLevel
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = interruptionLevel
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            Logger.connectivity.error("Sensor alert notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
