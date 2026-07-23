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

private extension GlucoseAlertTier {
    var notificationIdentifierPrefix: String {
        switch self {
        case .low: "low-glucose-alert"
        case .criticalLow: "critical-low-glucose-alert"
        }
    }

    var categoryIdentifier: String {
        switch self {
        case .low: "LOW_GLUCOSE_ALERT"
        case .criticalLow: "CRITICAL_LOW_GLUCOSE_ALERT"
        }
    }

    var notificationTitle: String {
        switch self {
        case .low: String(localized: "Glucose is low")
        case .criticalLow: String(localized: "Glucose is critically low")
        }
    }

    var logLabel: String {
        switch self {
        case .low: "Low glucose"
        case .criticalLow: "Critically low glucose"
        }
    }
}

@MainActor
final class LowGlucoseNotificationManager: NSObject {
    static let shared = LowGlucoseNotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var tiersKnownClearInNotificationCenter: Set<GlucoseAlertTier> = []

    private override init() {
        super.init()
    }

    func configureForegroundPresentation() {
        // This is the app's single UNUserNotificationCenter delegate. New notification types add a prefix branch here and merge categories into this one setNotificationCategories call — never reassign the delegate or call setNotificationCategories elsewhere.
        notificationCenter.delegate = self
        let categories = Set(GlucoseAlertTier.allCases.map { tier in
            UNNotificationCategory(
                identifier: tier.categoryIdentifier,
                actions: [
                    UNNotificationAction(
                        identifier: LowGlucoseNotificationConfig.snoozeActionIdentifier,
                        title: String(localized: "Snooze 15 min")
                    )
                ],
                intentIdentifiers: [],
                options: [.customDismissAction, .allowInCarPlay]
            )
        })
        notificationCenter.setNotificationCategories(categories)
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus != .denied else {
            return false
        }

        var options: UNAuthorizationOptions = [.alert, .badge, .sound, .carPlay]
        // Fold in the critical-alert grant when the user has opted into critical
        // delivery, so enabling low alerts while critical is already on prompts
        // for both in one go.
        if wantsCriticalDeliveryAuthorization {
            options.insert(.criticalAlert)
        }

        do {
            return try await notificationCenter.requestAuthorization(options: options)
        } catch {
            Logger.connectivity.error("Low glucose notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Request the critical-alert grant on top of the standard authorization
    /// (iOS authorizes incrementally). Returns whether the system now reports
    /// critical alerts as enabled, so the Settings toggle can revert itself if
    /// the user declines the prompt.
    func requestCriticalAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus != .denied else {
            return false
        }

        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .carPlay, .criticalAlert]
        do {
            _ = try await notificationCenter.requestAuthorization(options: options)
        } catch {
            Logger.connectivity.error("Critical alert authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
        let updated = await notificationCenter.notificationSettings()
        return updated.criticalAlertSetting == .enabled
    }

    func evaluateCurrentReading(now: Date = Date()) async {
        let effectiveTiers = GlucoseAlertTier.allCases.filter(isEffectivelyEnabled)
        let ineffectiveTiers = Set(GlucoseAlertTier.allCases.filter { !effectiveTiers.contains($0) })

        await clearNotifications(for: ineffectiveTiers, resetCooldown: true)

        guard !effectiveTiers.isEmpty else {
            clearSnoozeIfNeeded()
            return
        }

        let history = LibreLinkUpHistory.shared

        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast else {
            for tier in effectiveTiers {
                markPendingRepeatIfNeeded(for: tier, now: now)
            }
            await clearNotifications(for: Set(effectiveTiers), resetCooldown: false)
            return
        }
        let maxReadingAge = LibreLinkUpService.shared.activeProvider.staleReadingAfter
        guard now.timeIntervalSince(history.lastReadingDate) <= maxReadingAge else {
            Logger.connectivity.info("Glucose notification skipped: glucose value is stale (>\(Int(maxReadingAge / 60))min)")
            for tier in effectiveTiers {
                markPendingRepeatIfNeeded(for: tier, now: now)
            }
            await clearNotifications(for: Set(effectiveTiers), resetCooldown: false)
            return
        }

        let tiersBelowThreshold = effectiveTiers.filter {
            history.currentGlucose < threshold(for: $0)
        }
        let recoveredTiers = Set(effectiveTiers.filter { !tiersBelowThreshold.contains($0) })
        await clearNotifications(for: recoveredTiers, resetCooldown: true)

        guard !tiersBelowThreshold.isEmpty else {
            clearSnoozeIfNeeded()
            return
        }

        let winningTier: GlucoseAlertTier = tiersBelowThreshold.contains(.criticalLow) ? .criticalLow : .low
        let suppressedTiers = Set(tiersBelowThreshold.filter { $0 != winningTier })
        await clearNotifications(for: suppressedTiers, resetCooldown: false)

        let snoozeUntil = SharedData.lowGlucoseNotificationSnoozeUntilDate
        guard now >= snoozeUntil else {
            Logger.connectivity.info("\(winningTier.logLabel, privacy: .public) notification skipped: snoozed until \(snoozeUntil.formatted(), privacy: .public)")
            return
        }

        guard pendingRepeat(for: winningTier) || notificationIsDue(for: winningTier, now: now) else {
            return
        }

        let settings = await notificationCenter.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }
        guard settings.alertSetting == .enabled || settings.notificationCenterSetting == .enabled else {
            Logger.connectivity.info("Glucose notification skipped: alerts disabled in system settings")
            return
        }

        let winningThreshold = threshold(for: winningTier)
        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        let compactCurrentValue = formattedGlucoseNumber(history.currentGlucose, glucoseUnit: glucoseUnit)
        let thresholdValue = formattedGlucoseValue(winningThreshold, glucoseUnit: glucoseUnit)
        let trendArrow = history.currentTrendArrow == "---" ? "-" : history.currentTrendArrow
        let compactTrendSummary = "\(compactCurrentValue) \(trendArrow)"

        let notificationTitle = winningTier.notificationTitle
        let content = UNMutableNotificationContent()
        content.title = "\(notificationTitle) 📱"
        content.subtitle = compactTrendSummary
        content.body = String(format: String(localized: "Your alert level is %@."), thresholdValue)
        // Critical delivery (overrides silent mode / Focus / Do Not Disturb) when
        // the user opted in AND the system granted the critical-alert permission;
        // otherwise fall back to the default time-sensitive level. A critical
        // alert plays its sound even when the ringer is muted, so it ignores the
        // system sound setting.
        let useCritical = criticalDeliveryEnabled(for: winningTier) && settings.criticalAlertSetting == .enabled
        if useCritical {
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        } else {
            if settings.soundSetting == .enabled {
                content.sound = .default
            } else {
                Logger.connectivity.info("\(winningTier.logLabel, privacy: .public) notification scheduled without sound because sounds are disabled in system settings")
            }
            content.interruptionLevel = .timeSensitive
        }
        content.relevanceScore = 1
        content.categoryIdentifier = winningTier.categoryIdentifier

        let requestIdentifier = "\(winningTier.notificationIdentifierPrefix)-\(Int(now.timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: LowGlucoseNotificationConfig.deliveryDelay, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            tiersKnownClearInNotificationCenter.remove(winningTier)
            setLastSentDate(now, for: winningTier)
            setPendingRepeat(false, for: winningTier)
            clearSnoozeIfNeeded()
            WatchConnectivityManager.shared.sendLowGlucoseAlertToWatch(
                title: "\(notificationTitle) ⌚",
                subtitle: content.subtitle,
                body: content.body,
                sentAt: now,
                tier: winningTier
            )
        } catch {
            Logger.connectivity.error("\(winningTier.logLabel, privacy: .public) notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func enableNotifications(for tier: GlucoseAlertTier, now: Date = Date()) async {
        await clearNotifications(for: [tier], resetCooldown: true, forceCleanup: true)
        await evaluateCurrentReading(now: now)
    }

    func disableNotifications(for tier: GlucoseAlertTier, now: Date = Date()) async {
        await clearNotifications(for: [tier], resetCooldown: true, forceCleanup: true)
        await evaluateCurrentReading(now: now)
    }

    func rearmNotifications(for tiers: Set<GlucoseAlertTier>, now: Date = Date()) async {
        await clearNotifications(for: tiers, resetCooldown: true, forceCleanup: true)
        await evaluateCurrentReading(now: now)
    }

    func providerDidChange() async {
        if SharedData.cgmProviderKind != .libre3BLE {
            await clearNotifications(for: [.criticalLow], resetCooldown: true, forceCleanup: true)
        }
        if !GlucoseAlertTier.allCases.contains(where: isEffectivelyEnabled) {
            clearSnoozeIfNeeded()
        }
    }

    func isLowGlucoseAlertSnoozed(now: Date = Date()) -> Bool {
        now < SharedData.lowGlucoseNotificationSnoozeUntilDate
    }

    func shouldShowSnoozeAction(now: Date = Date()) -> Bool {
        let effectiveTiers = GlucoseAlertTier.allCases.filter(isEffectivelyEnabled)
        guard !effectiveTiers.isEmpty else {
            return false
        }

        let history = LibreLinkUpHistory.shared
        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast,
              now.timeIntervalSince(history.lastReadingDate) <= LibreLinkUpService.shared.activeProvider.staleReadingAfter else {
            return false
        }

        return effectiveTiers.contains { history.currentGlucose < threshold(for: $0) } &&
            !isLowGlucoseAlertSnoozed(now: now)
    }

    func snoozeLowGlucoseAlerts(now: Date = Date()) async {
        await removePendingAndDeliveredNotifications(for: Set(GlucoseAlertTier.allCases))
        SharedData.lowGlucoseNotificationSnoozeUntilDate = now.addingTimeInterval(LowGlucoseNotificationConfig.snoozeInterval)
        for tier in GlucoseAlertTier.allCases where isEffectivelyEnabled(tier) {
            setPendingRepeat(true, for: tier)
        }
    }

    private var wantsCriticalDeliveryAuthorization: Bool {
        (SharedData.lowGlucoseNotificationsEnabled && SharedData.lowGlucoseCriticalAlertsEnabled) ||
            (SharedData.cgmProviderKind == .libre3BLE &&
             SharedData.criticalLowGlucoseNotificationsEnabled &&
             SharedData.criticalLowGlucoseCriticalAlertsEnabled)
    }

    private func isEffectivelyEnabled(_ tier: GlucoseAlertTier) -> Bool {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationsEnabled
        case .criticalLow:
            SharedData.cgmProviderKind == .libre3BLE &&
                SharedData.criticalLowGlucoseNotificationsEnabled
        }
    }

    private func threshold(for tier: GlucoseAlertTier) -> Int {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationThreshold
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationThreshold
        }
    }

    private func criticalDeliveryEnabled(for tier: GlucoseAlertTier) -> Bool {
        switch tier {
        case .low:
            SharedData.lowGlucoseCriticalAlertsEnabled
        case .criticalLow:
            SharedData.criticalLowGlucoseCriticalAlertsEnabled
        }
    }

    private func lastSentDate(for tier: GlucoseAlertTier) -> Date {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationLastSentDate
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationLastSentDate
        }
    }

    private func setLastSentDate(_ date: Date, for tier: GlucoseAlertTier) {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationLastSentDate = date
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationLastSentDate = date
        }
    }

    private func pendingRepeat(for tier: GlucoseAlertTier) -> Bool {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationPendingRepeat
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationPendingRepeat
        }
    }

    private func setPendingRepeat(_ isPending: Bool, for tier: GlucoseAlertTier) {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationPendingRepeat = isPending
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationPendingRepeat = isPending
        }
    }

    private func notificationIsDue(for tier: GlucoseAlertTier, now: Date) -> Bool {
        now.timeIntervalSince(lastSentDate(for: tier)) >=
            LowGlucoseNotificationConfig.repeatInterval - LowGlucoseNotificationConfig.repeatIntervalTolerance
    }

    private func clearNotifications(
        for tiers: Set<GlucoseAlertTier>,
        resetCooldown: Bool,
        forceCleanup: Bool = false
    ) async {
        guard !tiers.isEmpty else { return }

        let tiersNeedingCleanup = Set(tiers.filter { tier in
            forceCleanup ||
                (!tiersKnownClearInNotificationCenter.contains(tier) &&
                 (lastSentDate(for: tier) > .distantPast || pendingRepeat(for: tier)))
        })
        if !tiersNeedingCleanup.isEmpty {
            await removePendingAndDeliveredNotifications(for: tiersNeedingCleanup)
        }

        guard resetCooldown else { return }
        for tier in tiers {
            if lastSentDate(for: tier) > .distantPast {
                setLastSentDate(.distantPast, for: tier)
            }
            if pendingRepeat(for: tier) {
                setPendingRepeat(false, for: tier)
            }
        }
    }

    private func removePendingAndDeliveredNotifications(for tiers: Set<GlucoseAlertTier>) async {
        guard !tiers.isEmpty else { return }

        let prefixes = tiers.map(\.notificationIdentifierPrefix)
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let matchingPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { identifier in
                prefixes.contains { prefix in identifier.hasPrefix(prefix) }
            }
        if !matchingPendingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingPendingIdentifiers)
        }

        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        let matchingDeliveredIdentifiers = deliveredNotifications
            .map(\.request.identifier)
            .filter { identifier in
                prefixes.contains { prefix in identifier.hasPrefix(prefix) }
            }
        if !matchingDeliveredIdentifiers.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: matchingDeliveredIdentifiers)
        }
        tiersKnownClearInNotificationCenter.formUnion(tiers)
    }

    private func markPendingRepeatIfNeeded(for tier: GlucoseAlertTier, now: Date) {
        guard notificationIsDue(for: tier, now: now),
              lastSentDate(for: tier) > .distantPast,
              !pendingRepeat(for: tier) else {
            return
        }
        setPendingRepeat(true, for: tier)
    }

    private func clearSnoozeIfNeeded() {
        guard SharedData.lowGlucoseNotificationSnoozeUntilDate > .distantPast else { return }
        SharedData.lowGlucoseNotificationSnoozeUntilDate = .distantPast
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
        let identifier = notification.request.identifier
        // Shared foreground router: add new notification families here instead of
        // assigning another UNUserNotificationCenter delegate.
        if GlucoseAlertTier.allCases.contains(where: { identifier.hasPrefix($0.notificationIdentifierPrefix) }) {
            completionHandler([.banner, .list, .sound])
        } else if identifier.hasPrefix(SensorAlertNotificationManager.identifierPrefix) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let identifier = response.notification.request.identifier
        guard GlucoseAlertTier.allCases.contains(where: { identifier.hasPrefix($0.notificationIdentifierPrefix) }) else {
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
