//
//  LowGlucoseNotificationManager.swift
//  LibreWrist
//
//  Created on 28.03.26.
//

#if os(iOS)
import Foundation
import OSLog
import UserNotifications

private enum LowGlucoseNotificationConfig {
    static let notificationIdentifierPrefix = "low-glucose-alert"
    static let categoryIdentifier = "LOW_GLUCOSE_ALERT"
    static let snoozeActionIdentifier = "LOW_GLUCOSE_ALERT_SNOOZE"
    static let repeatInterval: TimeInterval = 5 * 60
    // Readings arrive on the same ~5min cadence as repeatInterval, so jitter
    // (propagation delay, network, processing) can make the measured gap fall a
    // few seconds short of 300s and skip a whole cycle. Treat a reading landing
    // within this grace window as due.
    static let repeatIntervalTolerance: TimeInterval = 10
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
                        title: String(localized: "Snooze 15 min")
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
        let notificationIsDue = now.timeIntervalSince(SharedData.lowGlucoseNotificationLastSentDate) >= LowGlucoseNotificationConfig.repeatInterval - LowGlucoseNotificationConfig.repeatIntervalTolerance
        let snoozeUntil = SharedData.lowGlucoseNotificationSnoozeUntilDate

        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast else {
            markPendingRepeatIfNeeded(notificationIsDue)
            await clearPendingNotifications(resetCooldown: false)
            return
        }
        let maxReadingAge = LibreLinkUpService.shared.activeProvider.staleReadingAfter
        guard now.timeIntervalSince(history.lastReadingDate) <= maxReadingAge else {
            Logger.connectivity.info("Low glucose notification skipped: glucose value is stale (>\(Int(maxReadingAge / 60))min)")
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
        let compactCurrentValue = formattedGlucoseNumber(history.currentGlucose, glucoseUnit: glucoseUnit)
        let thresholdValue = formattedGlucoseValue(threshold, glucoseUnit: glucoseUnit)
        let trendArrow = history.currentTrendArrow == "---" ? "-" : history.currentTrendArrow
        let compactTrendSummary = "\(compactCurrentValue) \(trendArrow)"

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Glucose is low")
        content.subtitle = compactTrendSummary
        content.body = String(format: String(localized: "Your alert level is %@."), thresholdValue)
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
            WatchConnectivityManager.shared.sendLowGlucoseAlertToWatch(
                title: content.title,
                subtitle: content.subtitle,
                body: content.body,
                sentAt: now
            )
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

    func isLowGlucoseAlertSnoozed(now: Date = Date()) -> Bool {
        now < SharedData.lowGlucoseNotificationSnoozeUntilDate
    }

    func shouldShowSnoozeAction(now: Date = Date()) -> Bool {
        guard SharedData.lowGlucoseNotificationsEnabled else {
            return false
        }

        let history = LibreLinkUpHistory.shared
        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast,
              now.timeIntervalSince(history.lastReadingDate) <= LibreLinkUpService.shared.activeProvider.staleReadingAfter else {
            return false
        }

        return history.currentGlucose < SharedData.lowGlucoseNotificationThreshold &&
            !isLowGlucoseAlertSnoozed(now: now)
    }

    func snoozeLowGlucoseAlerts(now: Date = Date()) async {
        await removePendingAndDeliveredNotifications()
        SharedData.lowGlucoseNotificationSnoozeUntilDate = now.addingTimeInterval(LowGlucoseNotificationConfig.snoozeInterval)
        SharedData.lowGlucoseNotificationPendingRepeat = true
    }

    private func clearPendingNotifications(resetCooldown: Bool) async {
        await removePendingAndDeliveredNotifications()

        if resetCooldown {
            SharedData.lowGlucoseNotificationLastSentDate = .distantPast
            SharedData.lowGlucoseNotificationPendingRepeat = false
            SharedData.lowGlucoseNotificationSnoozeUntilDate = .distantPast
        }
    }

    private func removePendingAndDeliveredNotifications() async {
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

    private func formattedGlucoseNumber(_ valueInMgDl: Int, glucoseUnit: GlucoseUnit) -> String {
        switch glucoseUnit {
        case .mgdl:
            return "\(valueInMgDl)"
        case .mmoll:
            let mmolValue = valueInMgDl.displayedGlucoseValue(glucoseUnit: glucoseUnit)
            return GlucoseFormatters.mmolLFormatter.string(from: mmolValue as NSNumber) ?? String(format: "%.1f", mmolValue)
        }
    }
}

extension LowGlucoseNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier.hasPrefix("low-glucose-alert") else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard response.notification.request.identifier.hasPrefix(LowGlucoseNotificationConfig.notificationIdentifierPrefix) else {
            return
        }

        guard response.actionIdentifier == LowGlucoseNotificationConfig.snoozeActionIdentifier else {
            return
        }

        Task { @MainActor in
            await LowGlucoseNotificationManager.shared.snoozeLowGlucoseAlerts()
        }
    }
}
#endif
