//
//  LowGlucoseNotificationManager.swift
//  LibreWrist
//
//  Created by Codex on 28.03.26.
//

#if os(iOS)
import Foundation
import OSLog
import UserNotifications

private enum LowGlucoseNotificationConfig {
    static let notificationIdentifierPrefix = "low-glucose-alert"
    static let categoryIdentifier = "LOW_GLUCOSE_ALERT"
    static let snoozeActionIdentifier = "LOW_GLUCOSE_ALERT_SNOOZE"
    static let maxReadingAge: TimeInterval = 3 * 60
    static let repeatInterval: TimeInterval = 5 * 60
    static let snoozeInterval: TimeInterval = 15 * 60
    static let deliveryDelay: TimeInterval = 1
}

@MainActor
final class LowGlucoseNotificationManager: NSObject {
    static let shared = LowGlucoseNotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    func configureForegroundPresentation() {
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories([
            UNNotificationCategory(
                identifier: LowGlucoseNotificationConfig.categoryIdentifier,
                actions: [
                    UNNotificationAction(
                        identifier: LowGlucoseNotificationConfig.snoozeActionIdentifier,
                        title: "Snooze 15 min"
                    )
                ],
                intentIdentifiers: [],
                options: [.customDismissAction, .allowInCarPlay]
            )
        ])
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus != .denied else {
            return false
        }

        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .carPlay]

        do {
            return try await notificationCenter.requestAuthorization(options: options)
        } catch {
            Logger.connectivity.error("Low glucose notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func evaluateCurrentReading(now: Date = Date()) async {
        guard SharedData.lowGlucoseNotificationsEnabled else {
            await clearPendingNotifications(resetCooldown: true)
            return
        }

        let settings = await notificationCenter.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }
        guard settings.alertSetting == .enabled || settings.notificationCenterSetting == .enabled else {
            Logger.connectivity.info("Low glucose notification skipped: alerts disabled in system settings")
            return
        }
        let history = LibreLinkUpHistory.shared
        let threshold = SharedData.lowGlucoseNotificationThreshold
        let notificationIsDue = now.timeIntervalSince(SharedData.lowGlucoseNotificationLastSentDate) >= LowGlucoseNotificationConfig.repeatInterval
        let snoozeUntil = SharedData.lowGlucoseNotificationSnoozeUntilDate

        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast else {
            markPendingRepeatIfNeeded(notificationIsDue)
            await clearPendingNotifications(resetCooldown: false)
            return
        }
        guard now.timeIntervalSince(history.lastReadingDate) <= LowGlucoseNotificationConfig.maxReadingAge else {
            Logger.connectivity.info("Low glucose notification skipped: glucose value is stale")
            markPendingRepeatIfNeeded(notificationIsDue)
            await clearPendingNotifications(resetCooldown: false)
            return
        }

        if history.currentGlucose >= threshold {
            await clearPendingNotifications(resetCooldown: true)
            return
        }

        guard now >= snoozeUntil else {
            Logger.connectivity.info("Low glucose notification skipped: snoozed until \(snoozeUntil.formatted(), privacy: .public)")
            return
        }

        guard SharedData.lowGlucoseNotificationPendingRepeat || notificationIsDue else {
            return
        }

        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        let currentValue = formattedGlucoseValue(history.currentGlucose, glucoseUnit: glucoseUnit)
        let thresholdValue = formattedGlucoseValue(threshold, glucoseUnit: glucoseUnit)
        let trendArrow = history.currentTrendArrow == "---" ? "-" : history.currentTrendArrow

        let content = UNMutableNotificationContent()
        content.title = "Glucose is low"
        content.body = "Current reading is \(currentValue) \(trendArrow). Your alert level is \(thresholdValue)."
        if settings.soundSetting == .enabled {
            content.sound = .default
        } else {
            Logger.connectivity.info("Low glucose notification scheduled without sound because sounds are disabled in system settings")
        }
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        content.categoryIdentifier = LowGlucoseNotificationConfig.categoryIdentifier

        let requestIdentifier = "\(LowGlucoseNotificationConfig.notificationIdentifierPrefix)-\(Int(now.timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: LowGlucoseNotificationConfig.deliveryDelay, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            SharedData.lowGlucoseNotificationLastSentDate = now
            SharedData.lowGlucoseNotificationPendingRepeat = false
            SharedData.lowGlucoseNotificationSnoozeUntilDate = .distantPast
        } catch {
            Logger.connectivity.error("Low glucose notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func enableNotifications(now: Date = Date()) async {
        await clearPendingNotifications(resetCooldown: true)
        await evaluateCurrentReading(now: now)
    }

    func disableNotifications() async {
        await clearPendingNotifications(resetCooldown: true)
    }

    private func clearPendingNotifications(resetCooldown: Bool) async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let matchingPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(LowGlucoseNotificationConfig.notificationIdentifierPrefix) }
        if !matchingPendingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingPendingIdentifiers)
        }

        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        let matchingDeliveredIdentifiers = deliveredNotifications
            .map(\.request.identifier)
            .filter { $0.hasPrefix(LowGlucoseNotificationConfig.notificationIdentifierPrefix) }
        if !matchingDeliveredIdentifiers.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: matchingDeliveredIdentifiers)
        }

        if resetCooldown {
            SharedData.lowGlucoseNotificationLastSentDate = .distantPast
            SharedData.lowGlucoseNotificationPendingRepeat = false
            SharedData.lowGlucoseNotificationSnoozeUntilDate = .distantPast
        }
    }

    private func markPendingRepeatIfNeeded(_ notificationIsDue: Bool) {
        guard notificationIsDue, SharedData.lowGlucoseNotificationLastSentDate > .distantPast else { return }
        SharedData.lowGlucoseNotificationPendingRepeat = true
    }

    private func snoozeNotifications(until date: Date) async {
        SharedData.lowGlucoseNotificationSnoozeUntilDate = date
        SharedData.lowGlucoseNotificationPendingRepeat = false
        await clearPendingNotifications(resetCooldown: false)
    }

    private func formattedGlucoseValue(_ valueInMgDl: Int, glucoseUnit: GlucoseUnit) -> String {
        switch glucoseUnit {
        case .mgdl:
            return "\(valueInMgDl) \(glucoseUnit.description)"
        case .mmoll:
            let mmolValue = valueInMgDl.displayedGlucoseValue(glucoseUnit: glucoseUnit)
            let formatted = GlucoseFormatters.mmolLFormatter.string(from: mmolValue as NSNumber) ?? String(format: "%.1f", mmolValue)
            return "\(formatted) \(glucoseUnit.description)"
        }
    }
}

extension LowGlucoseNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier.hasPrefix("low-glucose-alert") else {
            return []
        }
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier.hasPrefix(LowGlucoseNotificationConfig.notificationIdentifierPrefix) else {
            return
        }

        guard response.actionIdentifier == LowGlucoseNotificationConfig.snoozeActionIdentifier else {
            return
        }

        let snoozeUntil = Date().addingTimeInterval(LowGlucoseNotificationConfig.snoozeInterval)
        await LowGlucoseNotificationManager.shared.snoozeNotifications(until: snoozeUntil)
    }
}
#endif
