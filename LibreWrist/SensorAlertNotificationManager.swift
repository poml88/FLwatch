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
        case warning24h = "libre3-sensor-alert.expiry-24h"
        case warning2h = "libre3-sensor-alert.expiry-2h"
        case ended = "libre3-sensor-alert.expiry-ended"
    }

    private static let requestIdentifier = "libre3-sensor-alert.terminal"
    nonisolated static let signalLossIdentifier = "libre3-sensor-alert.signal-loss"
    private static let reconnectFailingIdentifier = "libre3-sensor-alert.reconnect-failing"
    private let notificationCenter = UNUserNotificationCenter.current()
    private var desiredSignalLossDeadline: Date?
    private var signalLossRevision = 0
    private var signalLossReconciliationTask: Task<Void, Never>?

    private init() { }

    /// App-wide auth; idempotent, and only prompts while authorization is undetermined.
    func requestAuthorizationIfNeeded() async {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            Logger.connectivity.error("Sensor alert notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func postReconnectFailing() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Sensor connection failing")
        content.body = String(localized: "FLwatch can't reconnect to your sensor. If the sensor was replaced or re-scanned with another app, re-pair it in the Connect tab.")
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.reconnectFailingIdentifier,
            content: content,
            trigger: nil
        )
        do {
            try await notificationCenter.add(request)
        } catch {
            Logger.connectivity.error("Reconnect-failing notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func retractReconnectFailing() {
        let ids = [Self.reconnectFailingIdentifier]
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

    /// Returns the OS-scheduled signal-loss deadline, if one is still pending.
    /// Used once at manager startup so an earlier, nearer dead-man deadline is
    /// adopted without being replaced by a fresh grace window.
    func pendingSignalLossDeadline() async -> Date? {
        let requests = await notificationCenter.pendingNotificationRequests()
        let trigger = requests
            .first { $0.identifier == Self.signalLossIdentifier }?
            .trigger as? UNTimeIntervalNotificationTrigger
        return trigger?.nextTriggerDate()
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
        content.body = String(localized: "Your phone hasn't received readings for 20 minutes. Move closer to your sensor or check it.")
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
        let request = UNNotificationRequest(
            identifier: Self.signalLossIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, deadline.timeIntervalSinceNow),
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
            // Sensor-reported terminal state is authoritative; the scheduled
            // expiry-ended reminder is only a silent-sensor fallback.
            removeEndedExpiryReminder()
            await post(
                title: String(localized: "Replace sensor"),
                body: String(localized: "Your sensor has stopped working and needs to be replaced to resume readings."),
                interruptionLevel: interruptionLevel
            )
        case .sensorEnded:
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

    func scheduleExpiryReminders(sensorStartDate: Date, wearDurationMinutes: Int, now: Date = Date()) async {
        // Clean slate avoids stale fire times when a new sensor has a different
        // start anchor or wear duration.
        await cancelExpiryReminders()
        let expiresAt = sensorStartDate.addingTimeInterval(TimeInterval(wearDurationMinutes) * 60)
        let expiryDateTime = expiresAt.formatted(date: .abbreviated, time: .shortened)
        let expiryTime = expiresAt.formatted(date: .omitted, time: .shortened)

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
