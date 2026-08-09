//
//  PhoneAppNotificationsView.swift
//  LibreWrist
//
//  Created by Peter Müller on 08.08.26.
//

import SwiftUI
import UserNotifications

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
    @AppStorage(DefaultsKey.lowGlucoseNotificationThreshold.rawValue, store: UserDefaults.group) private var lowGlucoseNotificationThreshold: Int = 70
    @AppStorage(DefaultsKey.criticalLowGlucoseNotificationsEnabled.rawValue, store: UserDefaults.group) private var criticalLowGlucoseNotificationsEnabled: Bool = false
    @AppStorage(DefaultsKey.criticalLowGlucoseCriticalAlertsEnabled.rawValue, store: UserDefaults.group) private var criticalLowGlucoseCriticalAlertsEnabled: Bool = false
    @AppStorage(DefaultsKey.criticalLowGlucoseNotificationThreshold.rawValue, store: UserDefaults.group) private var criticalLowGlucoseNotificationThreshold: Int = 55
    @AppStorage(DefaultsKey.highGlucoseNotificationsEnabled.rawValue, store: UserDefaults.group) private var highGlucoseNotificationsEnabled: Bool = false
    @AppStorage(DefaultsKey.highGlucoseCriticalAlertsEnabled.rawValue, store: UserDefaults.group) private var highGlucoseCriticalAlertsEnabled: Bool = false
    @AppStorage(DefaultsKey.highGlucoseNotificationThreshold.rawValue, store: UserDefaults.group) private var highGlucoseNotificationThreshold: Int = 250
    @AppStorage(DefaultsKey.libre3SignalLossAlertEnabled.rawValue, store: UserDefaults.group) private var libre3SignalLossAlertEnabled: Bool = true
    @AppStorage(DefaultsKey.libre3SignalLossCritical.rawValue, store: UserDefaults.group) private var libre3SignalLossCritical: Bool = false

    @State private var notificationAuthorizationDenied = false
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
    }

    // MARK: - Cloud providers (LibreLinkUp / Dexcom Share)

    /// Low and high alerts for the polled providers. They can only fire while
    /// the Bluetooth heartbeat is running — that's what schedules the cloud
    /// polls — so every control is disabled until it's enabled in Settings.
    @ViewBuilder
    private var heartbeatAlertsSection: some View {
        Section {
            if !bluetoothHeartbeatManager.isEnabled {
                Text("Glucose alerts need the Bluetooth heartbeat. Turn it on in Settings, under “Bluetooth Heartbeat”.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }

            Toggle("Low glucose alerts", isOn: $lowGlucoseNotificationsEnabled)
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
                .disabled(!bluetoothHeartbeatManager.isEnabled)

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

            Toggle("High glucose alerts", isOn: $highGlucoseNotificationsEnabled)
                .onChange(of: highGlucoseNotificationsEnabled) { _, isEnabled in
                    guard bluetoothHeartbeatManager.isEnabled || !isEnabled else {
                        highGlucoseNotificationsEnabled = false
                        return
                    }
                    handleGlucoseAlertsChanged(.high, isEnabled: isEnabled)
                }
                .disabled(!bluetoothHeartbeatManager.isEnabled)

            if highGlucoseNotificationsEnabled {
                Picker("Alert me above", selection: highGlucoseThresholdBinding) {
                    ForEach(highGlucoseThresholdOptions, id: \.self) { threshold in
                        Text(lowGlucoseThresholdText(for: threshold))
                            .tag(threshold)
                    }
                }

                Toggle("Use critical alerts", isOn: $highGlucoseCriticalAlertsEnabled)
                    .onChange(of: highGlucoseCriticalAlertsEnabled) { _, isEnabled in
                        handleCriticalAlertsChanged(for: .high, isEnabled: isEnabled)
                    }
            } else {
                LabeledContent("Alert me above", value: lowGlucoseThresholdText(for: highGlucoseNotificationThreshold))
                    .foregroundStyle(.secondary)
            }

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
            Toggle("Low glucose alerts", isOn: $lowGlucoseNotificationsEnabled)
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

                Toggle("Use critical alerts", isOn: $lowGlucoseCriticalAlertsEnabled)
                    .onChange(of: lowGlucoseCriticalAlertsEnabled) { _, isEnabled in
                        handleCriticalAlertsChanged(for: .low, isEnabled: isEnabled)
                    }
            } else {
                LabeledContent("Alert me below", value: lowGlucoseThresholdText(for: lowGlucoseNotificationThreshold))
                    .foregroundStyle(.secondary)
            }

            Text("Notifies you when a new sensor reading is below \(lowGlucoseThresholdText(for: lowGlucoseNotificationThreshold)). Alerts may repeat every 5 minutes while glucose remains low and require a stable Bluetooth connection. Alerts can be snoozed for 15 minutes.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Critically low glucose alerts", isOn: $criticalLowGlucoseNotificationsEnabled)
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

                Toggle("Use critical alerts", isOn: $criticalLowGlucoseCriticalAlertsEnabled)
                    .onChange(of: criticalLowGlucoseCriticalAlertsEnabled) { _, isEnabled in
                        handleCriticalAlertsChanged(for: .criticalLow, isEnabled: isEnabled)
                    }
            } else {
                LabeledContent(
                    "Alert me below",
                    value: lowGlucoseThresholdText(for: criticalLowGlucoseNotificationThreshold)
                )
                .foregroundStyle(.secondary)
            }

            Text("Notifies you when a new sensor reading is critically low, below \(lowGlucoseThresholdText(for: criticalLowGlucoseNotificationThreshold)). This alert takes precedence over the low glucose alert. Alerts may repeat every 5 minutes and share the 15-minute snooze.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("High glucose alerts", isOn: $highGlucoseNotificationsEnabled)
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

                Toggle("Use critical alerts", isOn: $highGlucoseCriticalAlertsEnabled)
                    .onChange(of: highGlucoseCriticalAlertsEnabled) { _, isEnabled in
                        handleCriticalAlertsChanged(for: .high, isEnabled: isEnabled)
                    }
            } else {
                LabeledContent(
                    "Alert me above",
                    value: lowGlucoseThresholdText(for: highGlucoseNotificationThreshold)
                )
                .foregroundStyle(.secondary)
            }

            Text("Notifies you when a new sensor reading is above \(lowGlucoseThresholdText(for: highGlucoseNotificationThreshold)). Alerts may repeat every 5 minutes while glucose remains high and require a stable Bluetooth connection. Alerts can be snoozed for 15 minutes.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Signal loss alert", isOn: $libre3SignalLossAlertEnabled)
                .onChange(of: libre3SignalLossAlertEnabled) { _, isEnabled in
                    handleSignalLossAlertChanged(isEnabled)
                }

            Toggle("Use critical alerts", isOn: $libre3SignalLossCritical)
                .disabled(!libre3SignalLossAlertEnabled)
                .onChange(of: libre3SignalLossCritical) { _, isEnabled in
                    handleSignalLossCriticalChanged(isEnabled)
                }

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
        // After an on prompt completes, re-apply at that same deadline so a newly
        // granted critical setting takes effect on the pending request.
        Libre3DirectManager.shared.signalLossSettingsChanged()
        guard isEnabled else { return }
        Task {
            _ = await LowGlucoseNotificationManager.shared.requestCriticalAuthorizationIfNeeded()
            await MainActor.run {
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

#Preview {
    PhoneAppNotificationsView()
}
