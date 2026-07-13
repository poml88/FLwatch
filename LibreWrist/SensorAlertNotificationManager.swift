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

    enum ExpiryReminder: String, CaseIterable {
        case warning24h = "libre3-sensor-alert.expiry-24h"
        case warning2h = "libre3-sensor-alert.expiry-2h"
        case ended = "libre3-sensor-alert.expiry-ended"
    }

    private static let requestIdentifier = "libre3-sensor-alert.terminal"
    private let notificationCenter = UNUserNotificationCenter.current()

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

    func update(
        for attention: Libre3SensorAttention,
        interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive
    ) async {
        switch attention {
        case .replaceSensor:
            removeEndedExpiryReminder()
            await post(
                title: String(localized: "Replace sensor"),
                body: String(localized: "Your sensor has stopped working and needs to be replaced to resume readings."),
                interruptionLevel: interruptionLevel
            )
        case .sensorEnded:
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
