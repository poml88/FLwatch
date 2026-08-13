//
//  PhoneAppNotificationsView.swift
//  LibreWrist
//
//  Created by Peter Müller on 08.08.26.
//

import SwiftUI
import UserNotifications

private enum AlertOptionsKind: String, Identifiable {
    case low
    case criticalLow
    case high
    case signalLoss

    var id: String { rawValue }

    var navigationTitle: LocalizedStringResource {
        switch self {
        case .low:
            LocalizedStringResource(
                "Low glucose options",
                comment: "Navigation title for settings that control low-glucose notification delivery."
            )
        case .criticalLow:
            LocalizedStringResource(
                "Critically low glucose options",
                comment: "Navigation title for settings that control critically-low-glucose notification delivery."
            )
        case .high:
            LocalizedStringResource(
                "High glucose options",
                comment: "Navigation title for settings that control high-glucose notification delivery."
            )
        case .signalLoss:
            LocalizedStringResource(
                "Signal loss options",
                comment: "Navigation title for settings that control signal-loss notification delivery."
            )
        }
    }
}

/// The glucose alert settings, lifted out of `PhoneAppSettingsView` into their
/// own tab so they're one tap away instead of buried in a long Form.
///
/// Which alerts exist depends on the provider, exactly as before the move: the
/// direct-BLE sensor pushes readings and `Libre3DirectManager` drives the alarms
/// off that push tick, so it gets the full set (low / critically low / high /
/// signal loss). The cloud providers rely on the vendor app for primary alarms
/// and only ride on the Bluetooth heartbeat, so they offer low and high, gated
/// on that heartbeat — which stays configured in Settings.
struct PhoneAppNotificationsView: View {

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(DefaultsKey.cgmProviderKind.rawValue, store: UserDefaults.group) private var cgmProviderKindRaw: String = CGMProviderKind.libreLinkUp.rawValue
    @AppStorage(DefaultsKey.lowGlucoseNotificationsEnabled.rawValue, store: UserDefaults.group) private var lowGlucoseNotificationsEnabled: Bool = false
    @AppStorage(DefaultsKey.lowGlucoseCriticalAlertsEnabled.rawValue, store: UserDefaults.group) private var lowGlucoseCriticalAlertsEnabled: Bool = false
    @AppStorage(DefaultsKey.lowGlucoseQuietHoursEnabled.rawValue, store: UserDefaults.group) private var lowGlucoseQuietHoursEnabled: Bool = false
    @AppStorage(DefaultsKey.lowGlucoseQuietHoursStartMinutes.rawValue, store: UserDefaults.group) private var lowGlucoseQuietHoursStartMinutes: Int = QuietHours.defaultStartMinutes
    @AppStorage(DefaultsKey.lowGlucoseQuietHoursEndMinutes.rawValue, store: UserDefaults.group) private var lowGlucoseQuietHoursEndMinutes: Int = QuietHours.defaultEndMinutes
    @AppStorage(DefaultsKey.lowGlucoseNotificationThreshold.rawValue, store: UserDefaults.group) private var lowGlucoseNotificationThreshold: Int = 70
    @AppStorage(DefaultsKey.criticalLowGlucoseNotificationsEnabled.rawValue, store: UserDefaults.group) private var criticalLowGlucoseNotificationsEnabled: Bool = false
    @AppStorage(DefaultsKey.criticalLowGlucoseCriticalAlertsEnabled.rawValue, store: UserDefaults.group) private var criticalLowGlucoseCriticalAlertsEnabled: Bool = false
    @AppStorage(DefaultsKey.criticalLowGlucoseQuietHoursEnabled.rawValue, store: UserDefaults.group) private var criticalLowGlucoseQuietHoursEnabled: Bool = false
    @AppStorage(DefaultsKey.criticalLowGlucoseQuietHoursStartMinutes.rawValue, store: UserDefaults.group) private var criticalLowGlucoseQuietHoursStartMinutes: Int = QuietHours.defaultStartMinutes
    @AppStorage(DefaultsKey.criticalLowGlucoseQuietHoursEndMinutes.rawValue, store: UserDefaults.group) private var criticalLowGlucoseQuietHoursEndMinutes: Int = QuietHours.defaultEndMinutes
    @AppStorage(DefaultsKey.criticalLowGlucoseNotificationThreshold.rawValue, store: UserDefaults.group) private var criticalLowGlucoseNotificationThreshold: Int = 55
    @AppStorage(DefaultsKey.highGlucoseNotificationsEnabled.rawValue, store: UserDefaults.group) private var highGlucoseNotificationsEnabled: Bool = false
    @AppStorage(DefaultsKey.highGlucoseCriticalAlertsEnabled.rawValue, store: UserDefaults.group) private var highGlucoseCriticalAlertsEnabled: Bool = false
    @AppStorage(DefaultsKey.highGlucoseQuietHoursEnabled.rawValue, store: UserDefaults.group) private var highGlucoseQuietHoursEnabled: Bool = false
    @AppStorage(DefaultsKey.highGlucoseQuietHoursStartMinutes.rawValue, store: UserDefaults.group) private var highGlucoseQuietHoursStartMinutes: Int = QuietHours.defaultStartMinutes
    @AppStorage(DefaultsKey.highGlucoseQuietHoursEndMinutes.rawValue, store: UserDefaults.group) private var highGlucoseQuietHoursEndMinutes: Int = QuietHours.defaultEndMinutes
    @AppStorage(DefaultsKey.highGlucoseNotificationThreshold.rawValue, store: UserDefaults.group) private var highGlucoseNotificationThreshold: Int = 250
    @AppStorage(DefaultsKey.libre3SignalLossAlertEnabled.rawValue, store: UserDefaults.group) private var libre3SignalLossAlertEnabled: Bool = true
    @AppStorage(DefaultsKey.libre3SignalLossCritical.rawValue, store: UserDefaults.group) private var libre3SignalLossCritical: Bool = false
    @AppStorage(DefaultsKey.libre3SignalLossQuietHoursEnabled.rawValue, store: UserDefaults.group) private var libre3SignalLossQuietHoursEnabled: Bool = false
    @AppStorage(DefaultsKey.libre3SignalLossQuietHoursStartMinutes.rawValue, store: UserDefaults.group) private var libre3SignalLossQuietHoursStartMinutes: Int = QuietHours.defaultStartMinutes
    @AppStorage(DefaultsKey.libre3SignalLossQuietHoursEndMinutes.rawValue, store: UserDefaults.group) private var libre3SignalLossQuietHoursEndMinutes: Int = QuietHours.defaultEndMinutes

    @State private var notificationAuthorizationDenied = false
    @State private var presentedAlertOptions: AlertOptionsKind?
    @StateObject private var bluetoothHeartbeatManager = BluetoothHeartbeatManager.shared
    private var watchConnector = WatchConnectivityManager.shared

    let lowGlucoseThresholdOptions: [Int] = Array(stride(from: 60, through: 120, by: 5))
    let highGlucoseThresholdOptions: [Int] = Array(stride(from: 120, through: 400, by: 10))
    private var criticalLowGlucoseThresholdOptions: [Int] {
        let maximumThreshold = max(50, min(80, lowGlucoseNotificationThreshold - 5))
        return Array(stride(from: 50, through: maximumThreshold, by: 5))
    }

    private var cgmProviderKind: CGMProviderKind {
        CGMProviderKind(rawValue: cgmProviderKindRaw) ?? .libreLinkUp
    }

    var body: some View {
        Form {
            if cgmProviderKind == .libre3BLE {
                directBLEAlertsSection
            } else {
                heartbeatAlertsSection
            }
        }
        .onAppear {
            refreshNotificationAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshNotificationAuthorizationStatus()
        }
        .sheet(item: $presentedAlertOptions) { alert in
            AlertOptionsView(
                alert: alert,
                alertEnabled: isAlertEnabled(alert),
                criticalAlertsEnabled: criticalAlertsBinding(for: alert),
                quietHours: quietHours(for: alert),
                onCriticalAlertsChanged: { isEnabled in
                    handleCriticalAlertsChanged(for: alert, isEnabled: isEnabled)
                },
                onQuietHoursChanged: { quietHours in
                    applyQuietHours(quietHours, for: alert)
                }
            )
        }
    }

    // MARK: - Cloud providers (LibreLinkUp / Dexcom Share)

    /// Low and high alerts for the polled providers. They can only fire while
    /// the Bluetooth heartbeat is running — that's what schedules the cloud
    /// polls — so an alert cannot be switched on until the heartbeat is enabled
    /// in Settings. Its delivery options remain available for configuration.
    @ViewBuilder
    private var heartbeatAlertsSection: some View {
        Section {
            if !bluetoothHeartbeatManager.isEnabled {
                if lowGlucoseNotificationsEnabled || highGlucoseNotificationsEnabled {
                    Text("An alert below is switched on but won't be delivered: glucose alerts need the Bluetooth heartbeat, which is off. Turn it on in Settings, under “Bluetooth Heartbeat”, or switch the alert off here.", comment: "Warning at the top of the Alerts tab, shown only for cloud CGM providers when a glucose alert is switched on while the Bluetooth heartbeat — the mechanism that evaluates those alerts — is off. Offers the user both ways out: enable the heartbeat in the Settings tab, or switch the alert off.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.red)
                } else {
                    Text("Glucose alerts need the Bluetooth heartbeat. Turn it on in Settings, under “Bluetooth Heartbeat”.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $lowGlucoseNotificationsEnabled) {
                alertToggleLabel(for: .low)
            }
                .onChange(of: lowGlucoseNotificationsEnabled) { _, isEnabled in
                    guard bluetoothHeartbeatManager.isEnabled || !isEnabled else {
                        lowGlucoseNotificationsEnabled = false
                        return
                    }
                    if cgmProviderKind == .dexcomShare {
                        persistManualSensorSettings()
                    }
                    handleGlucoseAlertsChanged(.low, isEnabled: isEnabled)
                }
                // Disabled only while off, never while on: an alert that somehow
                // ended up switched on without a heartbeat must stay switchable
                // off, or the user has no way to clear it.
                .disabled(!bluetoothHeartbeatManager.isEnabled && !lowGlucoseNotificationsEnabled)

            if lowGlucoseNotificationsEnabled {
                Picker("Alert me below", selection: $lowGlucoseNotificationThreshold) {
                    ForEach(lowGlucoseThresholdOptions, id: \.self) { threshold in
                        Text(lowGlucoseThresholdText(for: threshold))
                            .tag(threshold)
                    }
                }
                .onChange(of: lowGlucoseNotificationThreshold) { _, _ in
                    handleLowGlucoseThresholdChanged(
                        persistSensorSettings: cgmProviderKind == .dexcomShare
                    )
                }
            } else {
                LabeledContent("Alert me below", value: lowGlucoseThresholdText(for: lowGlucoseNotificationThreshold))
                    .foregroundStyle(.secondary)
            }

            alertOptionsButton(for: .low)

            if notificationAuthorizationDenied {
                Text("Notifications are off — glucose alerts can't be delivered")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Link("Open app settings", destination: URL(string: UIApplication.openSettingsURLString)!)
            }

            Text("You’ll get a notification when a new reading is below \(lowGlucoseThresholdText(for: lowGlucoseNotificationThreshold)). Alerts repeat at most every 5 minutes while glucose stays low. Alerts depend on a stable Bluetooth connection to your sensor and an internet connection. Always rely on the manufacturer's alerts first.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $highGlucoseNotificationsEnabled) {
                alertToggleLabel(for: .high)
            }
                .onChange(of: highGlucoseNotificationsEnabled) { _, isEnabled in
                    guard bluetoothHeartbeatManager.isEnabled || !isEnabled else {
                        highGlucoseNotificationsEnabled = false
                        return
                    }
                    handleGlucoseAlertsChanged(.high, isEnabled: isEnabled)
                }
                .disabled(!bluetoothHeartbeatManager.isEnabled && !highGlucoseNotificationsEnabled)

            if highGlucoseNotificationsEnabled {
                Picker("Alert me above", selection: highGlucoseThresholdBinding) {
                    ForEach(highGlucoseThresholdOptions, id: \.self) { threshold in
                        Text(lowGlucoseThresholdText(for: threshold))
                            .tag(threshold)
                    }
                }
            } else {
                LabeledContent("Alert me above", value: lowGlucoseThresholdText(for: highGlucoseNotificationThreshold))
                    .foregroundStyle(.secondary)
            }

            alertOptionsButton(for: .high)

            Text("You’ll get a notification when a new reading is above \(lowGlucoseThresholdText(for: highGlucoseNotificationThreshold)). Alerts repeat at most every 5 minutes while glucose stays high. Alerts depend on a stable Bluetooth connection to your sensor and an internet connection. Always rely on the manufacturer's alerts first.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        } header: {
            Text("Notifications")
        } footer: {
            Text("Critical alerts can play a sound even when your iPhone is muted or a Focus is active. iOS will ask for permission the first time you enable one.\nFLwatch alerts are delivered on a best-effort basis and may be delayed or missed. Always confirm your glucose reading before taking action.")
        }
    }

    // MARK: - Direct Bluetooth (Libre 3)

    /// Direct-BLE has no vendor app to poll and no heartbeat to ride on: the
    /// sensor pushes readings and `Libre3DirectManager` drives the alerts from
    /// that push tick. So there's no heartbeat toggle to gate on, and the same
    /// provider-agnostic `LowGlucoseNotificationManager` backs everything here.
    @ViewBuilder
    private var directBLEAlertsSection: some View {
        Section {
            Toggle(isOn: $lowGlucoseNotificationsEnabled) {
                alertToggleLabel(for: .low)
            }
                .onChange(of: lowGlucoseNotificationsEnabled) { _, isEnabled in
                    // Re-wire the graph's red low-alarm line: it tracks the
                    // threshold while alerts are on, hidden otherwise.
                    persistManualSensorSettings()
                    handleGlucoseAlertsChanged(.low, isEnabled: isEnabled)
                }

            if lowGlucoseNotificationsEnabled {
                Picker("Alert me below", selection: $lowGlucoseNotificationThreshold) {
                    ForEach(lowGlucoseThresholdOptions, id: \.self) { threshold in
                        Text(lowGlucoseThresholdText(for: threshold))
                            .tag(threshold)
                    }
                }
                .onChange(of: lowGlucoseNotificationThreshold) { _, _ in
                    handleLowGlucoseThresholdChanged(persistSensorSettings: true)
                }
            } else {
                LabeledContent("Alert me below", value: lowGlucoseThresholdText(for: lowGlucoseNotificationThreshold))
                    .foregroundStyle(.secondary)
            }

            alertOptionsButton(for: .low)

            Text("Notifies you when a new sensor reading is below \(lowGlucoseThresholdText(for: lowGlucoseNotificationThreshold)). Alerts may repeat every 5 minutes while glucose remains low and require a stable Bluetooth connection. Alerts can be snoozed for 15 minutes.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $criticalLowGlucoseNotificationsEnabled) {
                alertToggleLabel(for: .criticalLow)
            }
                .onChange(of: criticalLowGlucoseNotificationsEnabled) { _, isEnabled in
                    handleGlucoseAlertsChanged(.criticalLow, isEnabled: isEnabled)
                }

            if criticalLowGlucoseNotificationsEnabled {
                Picker("Alert me below", selection: criticalLowGlucoseThresholdBinding) {
                    ForEach(criticalLowGlucoseThresholdOptions, id: \.self) { threshold in
                        Text(lowGlucoseThresholdText(for: threshold))
                            .tag(threshold)
                    }
                }
            } else {
                LabeledContent(
                    "Alert me below",
                    value: lowGlucoseThresholdText(for: criticalLowGlucoseNotificationThreshold)
                )
                .foregroundStyle(.secondary)
            }

            alertOptionsButton(for: .criticalLow)

            Text("Notifies you when a new sensor reading is critically low, below \(lowGlucoseThresholdText(for: criticalLowGlucoseNotificationThreshold)). This alert takes precedence over the low glucose alert. Alerts may repeat every 5 minutes and share the 15-minute snooze.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $highGlucoseNotificationsEnabled) {
                alertToggleLabel(for: .high)
            }
                .onChange(of: highGlucoseNotificationsEnabled) { _, isEnabled in
                    handleGlucoseAlertsChanged(.high, isEnabled: isEnabled)
                }

            if highGlucoseNotificationsEnabled {
                Picker("Alert me above", selection: highGlucoseThresholdBinding) {
                    ForEach(highGlucoseThresholdOptions, id: \.self) { threshold in
                        Text(lowGlucoseThresholdText(for: threshold))
                            .tag(threshold)
                    }
                }
            } else {
                LabeledContent(
                    "Alert me above",
                    value: lowGlucoseThresholdText(for: highGlucoseNotificationThreshold)
                )
                .foregroundStyle(.secondary)
            }

            alertOptionsButton(for: .high)

            Text("Notifies you when a new sensor reading is above \(lowGlucoseThresholdText(for: highGlucoseNotificationThreshold)). Alerts may repeat every 5 minutes while glucose remains high and require a stable Bluetooth connection. Alerts can be snoozed for 15 minutes.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $libre3SignalLossAlertEnabled) {
                alertToggleLabel(for: .signalLoss)
            }
                .onChange(of: libre3SignalLossAlertEnabled) { _, isEnabled in
                    handleSignalLossAlertChanged(isEnabled)
                }

            alertOptionsButton(for: .signalLoss)

            Text("Notifies you when no sensor readings have arrived for 20 minutes. Keep your iPhone near the sensor to maintain the Bluetooth connection.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            if notificationAuthorizationDenied {
                Text("Notifications are off — alerts can't be delivered")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Link("Open app settings", destination: URL(string: UIApplication.openSettingsURLString)!)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Critical alerts can play a sound even when your iPhone is muted or a Focus is active. iOS will ask for permission the first time you enable one.\nFLwatch alerts are delivered on a best-effort basis and may be delayed or missed. Always confirm your glucose reading before taking action.")
        }
    }

    @ViewBuilder
    private func alertToggleLabel(for alert: AlertOptionsKind) -> some View {
        HStack(spacing: 6) {
            switch alert {
            case .low:
                Text(
                    "Low glucose alerts",
                    comment: "Toggle label for notifications when glucose is below the configured low threshold."
                )
            case .criticalLow:
                Text(
                    "Critically low glucose alerts",
                    comment: "Toggle label for notifications when glucose is below the configured critically-low threshold."
                )
            case .high:
                Text(
                    "High glucose alerts",
                    comment: "Toggle label for notifications when glucose is above the configured high threshold."
                )
            case .signalLoss:
                Text(
                    "Signal loss alert",
                    comment: "Toggle label for a notification when the phone has stopped receiving sensor readings."
                )
            }

            TimelineView(.everyMinute) { context in
                if isAlertEnabled(alert), quietHours(for: alert).isMuted(at: context.date) {
                    Image(systemName: "bell.slash")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(
                            Text(
                                "Currently muted by Do Not Disturb",
                                comment: "Accessibility label for an icon showing that this alert is currently inside its configured Do Not Disturb window."
                            )
                        )
                }
            }
        }
    }

    private func alertOptionsButton(for alert: AlertOptionsKind) -> some View {
        Button {
            presentedAlertOptions = alert
        } label: {
            HStack {
                Text(
                    "Options",
                    comment: "Button that opens critical-delivery and Do Not Disturb settings for one notification type."
                )
                Spacer()
                if isAlertEnabled(alert) {
                    if criticalAlertsEnabled(for: alert) {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(
                                Text(
                                    "Critical alerts enabled",
                                    comment: "Accessibility label for the Options-row icon showing that critical delivery is enabled for this alert."
                                )
                            )
                    }
                    if quietHours(for: alert).enabled {
                        Text(verbatim: formattedQuietHours(quietHours(for: alert)))
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
    }

    private func isAlertEnabled(_ alert: AlertOptionsKind) -> Bool {
        switch alert {
        case .low: lowGlucoseNotificationsEnabled
        case .criticalLow: criticalLowGlucoseNotificationsEnabled
        case .high: highGlucoseNotificationsEnabled
        case .signalLoss: libre3SignalLossAlertEnabled
        }
    }

    private func criticalAlertsEnabled(for alert: AlertOptionsKind) -> Bool {
        switch alert {
        case .low: lowGlucoseCriticalAlertsEnabled
        case .criticalLow: criticalLowGlucoseCriticalAlertsEnabled
        case .high: highGlucoseCriticalAlertsEnabled
        case .signalLoss: libre3SignalLossCritical
        }
    }

    private func quietHours(for alert: AlertOptionsKind) -> QuietHours {
        switch alert {
        case .low:
            QuietHours(
                enabled: lowGlucoseQuietHoursEnabled,
                startMinutes: lowGlucoseQuietHoursStartMinutes,
                endMinutes: lowGlucoseQuietHoursEndMinutes
            )
        case .criticalLow:
            QuietHours(
                enabled: criticalLowGlucoseQuietHoursEnabled,
                startMinutes: criticalLowGlucoseQuietHoursStartMinutes,
                endMinutes: criticalLowGlucoseQuietHoursEndMinutes
            )
        case .high:
            QuietHours(
                enabled: highGlucoseQuietHoursEnabled,
                startMinutes: highGlucoseQuietHoursStartMinutes,
                endMinutes: highGlucoseQuietHoursEndMinutes
            )
        case .signalLoss:
            QuietHours(
                enabled: libre3SignalLossQuietHoursEnabled,
                startMinutes: libre3SignalLossQuietHoursStartMinutes,
                endMinutes: libre3SignalLossQuietHoursEndMinutes
            )
        }
    }

    private func criticalAlertsBinding(for alert: AlertOptionsKind) -> Binding<Bool> {
        switch alert {
        case .low: $lowGlucoseCriticalAlertsEnabled
        case .criticalLow: $criticalLowGlucoseCriticalAlertsEnabled
        case .high: $highGlucoseCriticalAlertsEnabled
        case .signalLoss: $libre3SignalLossCritical
        }
    }

    private func formattedQuietHours(_ quietHours: QuietHours) -> String {
        let start = alertOptionsTimePickerDate(for: quietHours.startMinutes)
        let end = alertOptionsTimePickerDate(for: quietHours.endMinutes)
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Alert plumbing

    private func handleGlucoseAlertsChanged(_ tier: GlucoseAlertTier, isEnabled: Bool) {
        Task {
            if isEnabled {
                let granted = await LowGlucoseNotificationManager.shared.requestAuthorizationIfNeeded()
                if granted {
                    await LowGlucoseNotificationManager.shared.enableNotifications(for: tier)
                } else {
                    await MainActor.run {
                        switch tier {
                        case .low:
                            lowGlucoseNotificationsEnabled = false
                        case .criticalLow:
                            criticalLowGlucoseNotificationsEnabled = false
                        case .high:
                            highGlucoseNotificationsEnabled = false
                        }
                    }
                }
            } else {
                await LowGlucoseNotificationManager.shared.disableNotifications(for: tier)
            }
        }
    }

    /// Enabling critical delivery needs the critical-alert permission on top of
    /// the standard grant; if the user declines the system prompt, revert the
    /// toggle so it reflects reality. Re-evaluates so a currently-triggered
    /// reading is re-delivered at the new level.
    private func handleCriticalAlertsChanged(for alert: AlertOptionsKind, isEnabled: Bool) {
        switch alert {
        case .low:
            handleCriticalAlertsChanged(for: GlucoseAlertTier.low, isEnabled: isEnabled)
        case .criticalLow:
            handleCriticalAlertsChanged(for: GlucoseAlertTier.criticalLow, isEnabled: isEnabled)
        case .high:
            handleCriticalAlertsChanged(for: GlucoseAlertTier.high, isEnabled: isEnabled)
        case .signalLoss:
            handleSignalLossCriticalChanged(isEnabled)
        }
    }

    private func handleCriticalAlertsChanged(for tier: GlucoseAlertTier, isEnabled: Bool) {
        Task {
            if isEnabled {
                let granted = await LowGlucoseNotificationManager.shared.requestCriticalAuthorizationIfNeeded()
                if !granted {
                    await MainActor.run {
                        switch tier {
                        case .low:
                            lowGlucoseCriticalAlertsEnabled = false
                        case .criticalLow:
                            criticalLowGlucoseCriticalAlertsEnabled = false
                        case .high:
                            highGlucoseCriticalAlertsEnabled = false
                        }
                    }
                }
            }
            // Mirror the (possibly reverted) preference to the watch so its
            // backup glucose alert matches the phone's level, then re-evaluate
            // so a currently-triggered reading is re-delivered at the new level.
            watchConnector.sendSettingsSnapshotToWatch()
            await LowGlucoseNotificationManager.shared.rearmNotifications(for: [tier])
        }
    }

    private func applyQuietHours(_ quietHours: QuietHours, for alert: AlertOptionsKind) {
        guard quietHours != self.quietHours(for: alert) else { return }

        switch alert {
        case .low:
            lowGlucoseQuietHoursEnabled = quietHours.enabled
            lowGlucoseQuietHoursStartMinutes = quietHours.startMinutes
            lowGlucoseQuietHoursEndMinutes = quietHours.endMinutes
        case .criticalLow:
            criticalLowGlucoseQuietHoursEnabled = quietHours.enabled
            criticalLowGlucoseQuietHoursStartMinutes = quietHours.startMinutes
            criticalLowGlucoseQuietHoursEndMinutes = quietHours.endMinutes
        case .high:
            highGlucoseQuietHoursEnabled = quietHours.enabled
            highGlucoseQuietHoursStartMinutes = quietHours.startMinutes
            highGlucoseQuietHoursEndMinutes = quietHours.endMinutes
        case .signalLoss:
            libre3SignalLossQuietHoursEnabled = quietHours.enabled
            libre3SignalLossQuietHoursStartMinutes = quietHours.startMinutes
            libre3SignalLossQuietHoursEndMinutes = quietHours.endMinutes
        }

        switch alert {
        case .low:
            Task {
                await LowGlucoseNotificationManager.shared.rearmNotifications(for: [.low])
            }
        case .criticalLow:
            Task {
                await LowGlucoseNotificationManager.shared.rearmNotifications(for: [.criticalLow])
            }
        case .high:
            Task {
                await LowGlucoseNotificationManager.shared.rearmNotifications(for: [.high])
            }
        case .signalLoss:
            Libre3DirectManager.shared.signalLossSettingsChanged()
        }
    }

    private func handleLowGlucoseThresholdChanged(persistSensorSettings: Bool) {
        if persistSensorSettings {
            persistManualSensorSettings()
        }

        let clampedCriticalThreshold = max(
            50,
            min(
                criticalLowGlucoseNotificationThreshold,
                min(80, lowGlucoseNotificationThreshold - 5)
            )
        )
        let didClampCriticalThreshold = clampedCriticalThreshold != criticalLowGlucoseNotificationThreshold
        if didClampCriticalThreshold {
            criticalLowGlucoseNotificationThreshold = clampedCriticalThreshold
        }

        Task {
            let tiers: Set<GlucoseAlertTier> = didClampCriticalThreshold
                ? [.low, .criticalLow]
                : [.low]
            await LowGlucoseNotificationManager.shared.rearmNotifications(for: tiers)
        }
    }

    private var criticalLowGlucoseThresholdBinding: Binding<Int> {
        Binding(
            get: { criticalLowGlucoseNotificationThreshold },
            set: { newValue in
                criticalLowGlucoseNotificationThreshold = newValue
                Task {
                    await LowGlucoseNotificationManager.shared.rearmNotifications(for: [.criticalLow])
                }
            }
        )
    }

    private var highGlucoseThresholdBinding: Binding<Int> {
        Binding(
            get: { highGlucoseNotificationThreshold },
            set: { newValue in
                highGlucoseNotificationThreshold = newValue
                Task {
                    await LowGlucoseNotificationManager.shared.rearmNotifications(for: [.high])
                }
            }
        )
    }

    private func handleSignalLossAlertChanged(_ isEnabled: Bool) {
        // Apply off immediately; when enabling, this also grace-arms immediately
        // if lifecycle is already known. Re-apply after the authorization request
        // so the executor sees the system's updated notification settings.
        Libre3DirectManager.shared.signalLossSettingsChanged()
        guard isEnabled else {
            refreshNotificationAuthorizationStatus()
            return
        }
        Task {
            _ = await LowGlucoseNotificationManager.shared.requestAuthorizationIfNeeded()
            await MainActor.run {
                Libre3DirectManager.shared.signalLossSettingsChanged()
            }
            refreshNotificationAuthorizationStatus()
        }
    }

    private func handleSignalLossCriticalChanged(_ isEnabled: Bool) {
        // Preserve the deadline while immediately applying an off transition.
        // After an on prompt completes, roll back a declined preference and
        // re-apply at that same deadline so the pending request stays accurate.
        Libre3DirectManager.shared.signalLossSettingsChanged()
        guard isEnabled else { return }
        Task {
            let granted = await LowGlucoseNotificationManager.shared.requestCriticalAuthorizationIfNeeded()
            await MainActor.run {
                if !granted {
                    libre3SignalLossCritical = false
                }
                Libre3DirectManager.shared.signalLossSettingsChanged()
            }
            refreshNotificationAuthorizationStatus()
        }
    }

    /// Re-writes only the alarm pair of the persisted sensor settings, so the
    /// graph's red low-alarm line follows the low-glucose alert level. The unit
    /// and target range are owned by the Settings tab, so they're carried over
    /// unchanged from the store rather than mirrored into local state here.
    private func persistManualSensorSettings() {
        let current = SensorSettingsStore.shared.sensorSettings
        let alarms = SensorSettings.manualAlarms(
            notificationsEnabled: lowGlucoseNotificationsEnabled,
            threshold: lowGlucoseNotificationThreshold
        )
        let updated = SensorSettings(
            uom: current.uom,
            targetLow: current.targetLow,
            targetHigh: current.targetHigh,
            alarmLow: alarms.low,
            alarmHigh: alarms.high
        )
        SensorSettingsStore.shared.updateSensorSettings(updated)
        watchConnector.sendSettingsSnapshotToWatch()
    }

    private func refreshNotificationAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                notificationAuthorizationDenied = settings.authorizationStatus == .denied
            }
        }
    }

    private func lowGlucoseThresholdText(for value: Int) -> String {
        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        return value.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
    }
}

private struct AlertOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    let alert: AlertOptionsKind
    let alertEnabled: Bool
    @Binding var criticalAlertsEnabled: Bool
    let onCriticalAlertsChanged: (Bool) -> Void
    let onQuietHoursChanged: (QuietHours) -> Void

    @State private var quietHoursEnabled: Bool
    @State private var quietHoursStartMinutes: Int
    @State private var quietHoursEndMinutes: Int
    private let initialQuietHours: QuietHours

    init(
        alert: AlertOptionsKind,
        alertEnabled: Bool,
        criticalAlertsEnabled: Binding<Bool>,
        quietHours: QuietHours,
        onCriticalAlertsChanged: @escaping (Bool) -> Void,
        onQuietHoursChanged: @escaping (QuietHours) -> Void
    ) {
        self.alert = alert
        self.alertEnabled = alertEnabled
        _criticalAlertsEnabled = criticalAlertsEnabled
        initialQuietHours = quietHours
        _quietHoursEnabled = State(initialValue: quietHours.enabled)
        _quietHoursStartMinutes = State(initialValue: quietHours.startMinutes)
        _quietHoursEndMinutes = State(initialValue: quietHours.endMinutes)
        self.onCriticalAlertsChanged = onCriticalAlertsChanged
        self.onQuietHoursChanged = onQuietHoursChanged
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $criticalAlertsEnabled) {
                        Text(
                            "Use critical alerts",
                            comment: "Toggle that makes this notification type use iOS critical-alert delivery."
                        )
                    }
                    .disabled(!alertEnabled)
                    .onChange(of: criticalAlertsEnabled) { _, isEnabled in
                        onCriticalAlertsChanged(isEnabled)
                    }
                } footer: {
                    Text(
                        "Critical alerts can play a sound even when your iPhone is muted or a Focus is active.",
                        comment: "Footer explaining the effect of critical notification delivery."
                    )
                }

                Section {
                    Toggle(isOn: $quietHoursEnabled) {
                        Text(
                            "Enable Do Not Disturb",
                            comment: "Toggle that enables a daily period during which this notification type is suppressed."
                        )
                    }

                    if quietHoursEnabled {
                        DatePicker(selection: startTimeBinding, displayedComponents: .hourAndMinute) {
                            Text(
                                "From",
                                comment: "Label for the start time of an alert's daily Do Not Disturb window."
                            )
                        }
                        DatePicker(selection: endTimeBinding, displayedComponents: .hourAndMinute) {
                            Text(
                                "To",
                                comment: "Label for the end time of an alert's daily Do Not Disturb window."
                            )
                        }

                        if quietHoursStartMinutes == quietHoursEndMinutes {
                            Text(
                                "Do Not Disturb is inactive when From and To are the same.",
                                comment: "Caption explaining that equal Do Not Disturb start and end times create a zero-length interval and do not suppress alerts."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(
                        "Do Not Disturb",
                        comment: "Section title for an alert's daily suppression window."
                    )
                } footer: {
                    Text(
                        "This alert will not be delivered during the selected window, even when critical alerts are enabled.",
                        comment: "Footer explaining that an alert's app-specific Do Not Disturb window also suppresses critical delivery."
                    )
                }
            }
            .navigationTitle(Text(alert.navigationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(
                            "Done",
                            comment: "Button that closes an alert Options sheet and applies its Do Not Disturb settings."
                        )
                    }
                }
            }
        }
        .onDisappear {
            let updatedQuietHours = QuietHours(
                enabled: quietHoursEnabled,
                startMinutes: quietHoursStartMinutes,
                endMinutes: quietHoursEndMinutes
            )
            guard updatedQuietHours != initialQuietHours else { return }
            onQuietHoursChanged(updatedQuietHours)
        }
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { alertOptionsTimePickerDate(for: quietHoursStartMinutes) },
            set: { quietHoursStartMinutes = minutesOfDay(from: $0) }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { alertOptionsTimePickerDate(for: quietHoursEndMinutes) },
            set: { quietHoursEndMinutes = minutesOfDay(from: $0) }
        )
    }

    private func minutesOfDay(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private func alertOptionsTimePickerDate(for minutes: Int) -> Date {
    var components = DateComponents()
    components.calendar = .current
    components.timeZone = Calendar.current.timeZone
    components.year = 2001
    components.month = 1
    components.day = 15
    components.hour = minutes / 60
    components.minute = minutes % 60
    return Calendar.current.date(from: components) ?? .distantPast
}

#Preview {
    PhoneAppNotificationsView()
}
