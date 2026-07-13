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
            await post(
                title: String(localized: "Replace sensor"),
                body: String(localized: "Your sensor has stopped working and needs to be replaced to resume readings."),
                interruptionLevel: interruptionLevel
            )
        case .sensorEnded:
            await post(
                title: String(localized: "Sensor ended"),
                body: String(localized: "Your sensor session has ended. Replace it to resume readings."),
                interruptionLevel: interruptionLevel
            )
        case .checkSensor, .none, .unknown:
            await retract()
        }
    }

    func retract() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [Self.requestIdentifier])
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
