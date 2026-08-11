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
        case .high: "high-glucose-alert"
        }
    }

    var categoryIdentifier: String {
        switch self {
        case .low: "LOW_GLUCOSE_ALERT"
        case .criticalLow: "CRITICAL_LOW_GLUCOSE_ALERT"
        case .high: "HIGH_GLUCOSE_ALERT"
        }
    }

    var notificationTitle: String {
        switch self {
        case .low: String(localized: "Glucose is low")
        case .criticalLow: String(localized: "Glucose is critically low")
        case .high: String(localized: "Glucose is high")
        }
    }

    var logLabel: String {
        switch self {
        case .low: "Low glucose"
        case .criticalLow: "Critically low glucose"
        case .high: "High glucose"
        }
    }
}

@MainActor
final class LowGlucoseNotificationManager: NSObject {
    static let shared = LowGlucoseNotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var tiersKnownClearInNotificationCenter: Set<GlucoseAlertTier> = []
    private var tiersBeingScheduled: Set<GlucoseAlertTier> = []
    private var providerChangeObserver: NSObjectProtocol?

    private override init() {
        super.init()
        // Every provider switch has to reconcile the alerts, and the phone has
        // more than one entry point (the Settings picker and the first-launch
        // picker). Observing the notification `switchProvider` already posts
        // catches them all in one place, the same way `BluetoothHeartbeatManager`
        // reconciles BLE ownership. `SharedData.cgmProviderKind` is written
        // before the post, so `providerDidChange()` reads the new kind.
        providerChangeObserver = NotificationCenter.default.addObserver(
            forName: .activeCGMProviderDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.providerDidChange()
            }
        }
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
            clearLowSnoozeIfNeeded()
            clearHighSnoozeIfNeeded()
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

        let triggeredTiers = effectiveTiers.filter {
            isTriggered($0, glucose: history.currentGlucose)
        }
        let recoveredTiers = Set(effectiveTiers.filter { !triggeredTiers.contains($0) })
        await clearNotifications(for: recoveredTiers, resetCooldown: true)
        if !triggeredTiers.contains(.low) && !triggeredTiers.contains(.criticalLow) {
            clearLowSnoozeIfNeeded()
        }
        if !triggeredTiers.contains(.high) {
            clearHighSnoozeIfNeeded()
        }

        guard !triggeredTiers.isEmpty else {
            return
        }

        var winningTiers: [GlucoseAlertTier] = []
        if triggeredTiers.contains(.criticalLow) {
            winningTiers.append(.criticalLow)
        } else if triggeredTiers.contains(.low) {
            winningTiers.append(.low)
        }
        if triggeredTiers.contains(.high) {
            winningTiers.append(.high)
        }

        let suppressedTiers = Set(triggeredTiers.filter { !winningTiers.contains($0) })
        await clearNotifications(for: suppressedTiers, resetCooldown: false)

        let dueTiers = winningTiers.filter { tier in
            let snoozeUntil = snoozeUntilDate(for: tier)
            guard now >= snoozeUntil else {
                Logger.connectivity.info("\(tier.logLabel, privacy: .public) notification skipped: snoozed until \(snoozeUntil.formatted(), privacy: .public)")
                return false
            }
            return pendingRepeat(for: tier) || notificationIsDue(for: tier, now: now)
        }
        guard !dueTiers.isEmpty else { return }

        let settings = await notificationCenter.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }
        guard settings.alertSetting == .enabled || settings.notificationCenterSetting == .enabled else {
            Logger.connectivity.info("Glucose notification skipped: alerts disabled in system settings")
            return
        }

        // Another evaluation may have completed while notification settings were
        // being fetched. Re-check the persisted gate before scheduling.
        for tier in dueTiers where
            pendingRepeat(for: tier) || notificationIsDue(for: tier, now: now) {
            await scheduleNotification(
                for: tier,
                history: history,
                settings: settings,
                now: now
            )
        }
    }

    private func scheduleNotification(
        for tier: GlucoseAlertTier,
        history: LibreLinkUpHistory,
        settings: UNNotificationSettings,
        now: Date
    ) async {
        // `add` suspends, so keep a per-tier in-flight guard as well as the
        // persisted due check above. A concurrent evaluation can still schedule
        // a different tier independently.
        guard tiersBeingScheduled.insert(tier).inserted else { return }
        defer { tiersBeingScheduled.remove(tier) }

        let alertThreshold = threshold(for: tier)
        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        let compactCurrentValue = formattedGlucoseNumber(history.currentGlucose, glucoseUnit: glucoseUnit)
        let thresholdValue = formattedGlucoseValue(alertThreshold, glucoseUnit: glucoseUnit)
        let trendArrow = history.currentTrendArrow == "---" ? "-" : history.currentTrendArrow
        let compactTrendSummary = "\(compactCurrentValue) \(trendArrow)"

        let notificationTitle = tier.notificationTitle
        let content = UNMutableNotificationContent()
        content.title = "\(notificationTitle) 📱"
        content.subtitle = compactTrendSummary
        content.body = String(format: String(localized: "Your alert level is %@."), thresholdValue)
        // Critical delivery (overrides silent mode / Focus / Do Not Disturb) when
        // the user opted in AND the system granted the critical-alert permission;
        // otherwise fall back to the default time-sensitive level. A critical
        // alert plays its sound even when the ringer is muted, so it ignores the
        // system sound setting.
        let useCritical = criticalDeliveryEnabled(for: tier) && settings.criticalAlertSetting == .enabled
        if useCritical {
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        } else {
            if settings.soundSetting == .enabled {
                content.sound = .default
            } else {
                Logger.connectivity.info("\(tier.logLabel, privacy: .public) notification scheduled without sound because sounds are disabled in system settings")
            }
            content.interruptionLevel = .timeSensitive
        }
        content.relevanceScore = 1
        content.categoryIdentifier = tier.categoryIdentifier

        let requestIdentifier = "\(tier.notificationIdentifierPrefix)-\(Int(now.timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: LowGlucoseNotificationConfig.deliveryDelay, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            tiersKnownClearInNotificationCenter.remove(tier)
            setLastSentDate(now, for: tier)
            setPendingRepeat(false, for: tier)
            clearSnoozeIfNeeded(for: tier)
            WatchConnectivityManager.shared.sendLowGlucoseAlertToWatch(
                title: "\(notificationTitle) ⌚",
                subtitle: content.subtitle,
                body: content.body,
                sentAt: now,
                tier: tier
            )
        } catch {
            Logger.connectivity.error("\(tier.logLabel, privacy: .public) notification scheduling failed: \(error.localizedDescription, privacy: .public)")
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
            await disableHeartbeatBackedAlertsIfHeartbeatIsOff()
        }
        if !GlucoseAlertTier.allCases.contains(where: isEffectivelyEnabled) {
            clearLowSnoozeIfNeeded()
            clearHighSnoozeIfNeeded()
        }
    }

    /// On a cloud provider the low/high alerts are only ever evaluated from the
    /// Bluetooth heartbeat's refresh pipeline, so turning the heartbeat off
    /// switches them off too (see the heartbeat toggle in `PhoneAppSettingsView`).
    /// Switching *into* a cloud provider — typically from direct BLE, where the
    /// alerts need no heartbeat — has to apply the same rule, otherwise they'd
    /// arrive switched on but never delivered, and the Alerts tab would show two
    /// toggles that claim to be armed.
    private func disableHeartbeatBackedAlertsIfHeartbeatIsOff() async {
        guard !SharedData.bluetoothHeartbeatEnabled else { return }
        guard SharedData.lowGlucoseNotificationsEnabled || SharedData.highGlucoseNotificationsEnabled else { return }

        SharedData.lowGlucoseNotificationsEnabled = false
        SharedData.highGlucoseNotificationsEnabled = false
        await clearNotifications(for: [.low, .high], resetCooldown: true, forceCleanup: true)
        // The switching code sends its own settings snapshot before this runs,
        // so the watch needs a second one carrying the now-off preferences.
        WatchConnectivityManager.shared.sendSettingsSnapshotToWatch()
        Logger.connectivity.info("Low/high glucose alerts switched off: provider switched to a cloud provider while the Bluetooth heartbeat is disabled")
    }

    func isLowGlucoseAlertSnoozed(now: Date = Date()) -> Bool {
        now < SharedData.lowGlucoseNotificationSnoozeUntilDate
    }

    func shouldShowSnoozeAction(now: Date = Date()) -> Bool {
        let effectiveTiers: [GlucoseAlertTier] = [.low, .criticalLow].filter(isEffectivelyEnabled)
        guard !effectiveTiers.isEmpty else {
            return false
        }

        let history = LibreLinkUpHistory.shared
        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast,
              now.timeIntervalSince(history.lastReadingDate) <= LibreLinkUpService.shared.activeProvider.staleReadingAfter else {
            return false
        }

        return effectiveTiers.contains { isTriggered($0, glucose: history.currentGlucose) } &&
            !isLowGlucoseAlertSnoozed(now: now)
    }

    func shouldShowHighGlucoseSnoozeAction(now: Date = Date()) -> Bool {
        guard isEffectivelyEnabled(.high) else { return false }

        let history = LibreLinkUpHistory.shared
        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast,
              now.timeIntervalSince(history.lastReadingDate) <= LibreLinkUpService.shared.activeProvider.staleReadingAfter else {
            return false
        }

        return isTriggered(.high, glucose: history.currentGlucose) &&
            now >= SharedData.highGlucoseNotificationSnoozeUntilDate
    }

    func snoozeLowGlucoseAlerts(now: Date = Date()) async {
        let lowTiers: Set<GlucoseAlertTier> = [.low, .criticalLow]
        await removePendingAndDeliveredNotifications(for: lowTiers)
        SharedData.lowGlucoseNotificationSnoozeUntilDate = now.addingTimeInterval(LowGlucoseNotificationConfig.snoozeInterval)
        for tier in lowTiers where isEffectivelyEnabled(tier) {
            setPendingRepeat(true, for: tier)
        }
    }

    func snoozeHighGlucoseAlerts(now: Date = Date()) async {
        await removePendingAndDeliveredNotifications(for: [.high])
        SharedData.highGlucoseNotificationSnoozeUntilDate = now.addingTimeInterval(LowGlucoseNotificationConfig.snoozeInterval)
        if isEffectivelyEnabled(.high) {
            setPendingRepeat(true, for: .high)
        }
    }

    private var wantsCriticalDeliveryAuthorization: Bool {
        (SharedData.lowGlucoseNotificationsEnabled && SharedData.lowGlucoseCriticalAlertsEnabled) ||
            (SharedData.cgmProviderKind == .libre3BLE &&
             SharedData.criticalLowGlucoseNotificationsEnabled &&
             SharedData.criticalLowGlucoseCriticalAlertsEnabled) ||
            (SharedData.highGlucoseNotificationsEnabled && SharedData.highGlucoseCriticalAlertsEnabled)
    }

    private func isEffectivelyEnabled(_ tier: GlucoseAlertTier) -> Bool {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationsEnabled
        case .criticalLow:
            SharedData.cgmProviderKind == .libre3BLE &&
                SharedData.criticalLowGlucoseNotificationsEnabled
        case .high:
            SharedData.highGlucoseNotificationsEnabled
        }
    }

    private func threshold(for tier: GlucoseAlertTier) -> Int {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationThreshold
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationThreshold
        case .high:
            SharedData.highGlucoseNotificationThreshold
        }
    }

    private func isTriggered(_ tier: GlucoseAlertTier, glucose: Int) -> Bool {
        switch tier {
        case .low, .criticalLow:
            glucose < threshold(for: tier)
        case .high:
            glucose > threshold(for: tier)
        }
    }

    private func criticalDeliveryEnabled(for tier: GlucoseAlertTier) -> Bool {
        switch tier {
        case .low:
            SharedData.lowGlucoseCriticalAlertsEnabled
        case .criticalLow:
            SharedData.criticalLowGlucoseCriticalAlertsEnabled
        case .high:
            SharedData.highGlucoseCriticalAlertsEnabled
        }
    }

    private func lastSentDate(for tier: GlucoseAlertTier) -> Date {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationLastSentDate
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationLastSentDate
        case .high:
            SharedData.highGlucoseNotificationLastSentDate
        }
    }

    private func setLastSentDate(_ date: Date, for tier: GlucoseAlertTier) {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationLastSentDate = date
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationLastSentDate = date
        case .high:
            SharedData.highGlucoseNotificationLastSentDate = date
        }
    }

    private func pendingRepeat(for tier: GlucoseAlertTier) -> Bool {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationPendingRepeat
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationPendingRepeat
        case .high:
            SharedData.highGlucoseNotificationPendingRepeat
        }
    }

    private func setPendingRepeat(_ isPending: Bool, for tier: GlucoseAlertTier) {
        switch tier {
        case .low:
            SharedData.lowGlucoseNotificationPendingRepeat = isPending
        case .criticalLow:
            SharedData.criticalLowGlucoseNotificationPendingRepeat = isPending
        case .high:
            SharedData.highGlucoseNotificationPendingRepeat = isPending
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

    private func snoozeUntilDate(for tier: GlucoseAlertTier) -> Date {
        switch tier {
        case .low, .criticalLow:
            SharedData.lowGlucoseNotificationSnoozeUntilDate
        case .high:
            SharedData.highGlucoseNotificationSnoozeUntilDate
        }
    }

    private func clearSnoozeIfNeeded(for tier: GlucoseAlertTier) {
        switch tier {
        case .low, .criticalLow:
            clearLowSnoozeIfNeeded()
        case .high:
            clearHighSnoozeIfNeeded()
        }
    }

    private func clearLowSnoozeIfNeeded() {
        guard SharedData.lowGlucoseNotificationSnoozeUntilDate > .distantPast else { return }
        SharedData.lowGlucoseNotificationSnoozeUntilDate = .distantPast
    }

    private func clearHighSnoozeIfNeeded() {
        guard SharedData.highGlucoseNotificationSnoozeUntilDate > .distantPast else { return }
        SharedData.highGlucoseNotificationSnoozeUntilDate = .distantPast
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
        guard let tier = GlucoseAlertTier.allCases.first(where: {
            identifier.hasPrefix($0.notificationIdentifierPrefix)
        }) else {
            return
        }

        guard response.actionIdentifier == LowGlucoseNotificationConfig.snoozeActionIdentifier else {
            return
        }

        Task { @MainActor in
            switch tier {
            case .low, .criticalLow:
                await LowGlucoseNotificationManager.shared.snoozeLowGlucoseAlerts()
            case .high:
                await LowGlucoseNotificationManager.shared.snoozeHighGlucoseAlerts()
            }
        }
    }
}
#endif
