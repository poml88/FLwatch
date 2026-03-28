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

@MainActor
final class LowGlucoseNotificationManager: NSObject {
    static let shared = LowGlucoseNotificationManager()

    private static let notificationIdentifierPrefix = "low-glucose-alert"
    private static let categoryIdentifier = "LOW_GLUCOSE_ALERT"
    private static let maxReadingAge: TimeInterval = 3 * 60
    private static let repeatInterval: TimeInterval = 5 * 60
    private static let deliveryDelay: TimeInterval = 1
    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    func configureForegroundPresentation() {
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryIdentifier,
                actions: [],
                intentIdentifiers: [],
                options: [.allowInCarPlay]
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
        let notificationIsDue = now.timeIntervalSince(SharedData.lowGlucoseNotificationLastSentDate) >= Self.repeatInterval

        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast else {
            markPendingRepeatIfNeeded(notificationIsDue)
            await clearPendingNotifications(resetCooldown: false)
            return
        }
        guard now.timeIntervalSince(history.lastReadingDate) <= Self.maxReadingAge else {
            Logger.connectivity.info("Low glucose notification skipped: glucose value is stale")
            markPendingRepeatIfNeeded(notificationIsDue)
            await clearPendingNotifications(resetCooldown: false)
            return
        }

        if history.currentGlucose >= threshold {
            await clearPendingNotifications(resetCooldown: true)
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
        content.title = "Low glucose"
        content.body = "Current glucose is \(currentValue) \(trendArrow), below your alert limit of \(thresholdValue)."
        if settings.soundSetting == .enabled {
            content.sound = .default
        } else {
            Logger.connectivity.info("Low glucose notification scheduled without sound because sounds are disabled in system settings")
        }
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        content.categoryIdentifier = Self.categoryIdentifier

        let requestIdentifier = "\(Self.notificationIdentifierPrefix)-\(Int(now.timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: Self.deliveryDelay, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            SharedData.lowGlucoseNotificationLastSentDate = now
            SharedData.lowGlucoseNotificationPendingRepeat = false
        } catch {
            Logger.connectivity.error("Low glucose notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disableNotifications() async {
        await clearPendingNotifications(resetCooldown: true)
    }

    private func clearPendingNotifications(resetCooldown: Bool) async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let matchingPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.notificationIdentifierPrefix) }
        if !matchingPendingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingPendingIdentifiers)
        }

        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        let matchingDeliveredIdentifiers = deliveredNotifications
            .map(\.request.identifier)
            .filter { $0.hasPrefix(Self.notificationIdentifierPrefix) }
        if !matchingDeliveredIdentifiers.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: matchingDeliveredIdentifiers)
        }

        if resetCooldown {
            SharedData.lowGlucoseNotificationLastSentDate = .distantPast
            SharedData.lowGlucoseNotificationPendingRepeat = false
        }
    }

    private func markPendingRepeatIfNeeded(_ notificationIsDue: Bool) {
        guard notificationIsDue, SharedData.lowGlucoseNotificationLastSentDate > .distantPast else { return }
        SharedData.lowGlucoseNotificationPendingRepeat = true
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
}
#endif
