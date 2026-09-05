//
//  WatchAppWorkoutView.swift
//  FLwatchWatchApp
//

import SwiftUI
import WatchKit

struct WatchAppWorkoutView: View {
    @Environment(\.libreLinkUpHistory) private var libreLinkUpHistory
    @Environment(\.sensorSettingsStore) private var sensorSettingsStore
    @Environment(\.currentIOBSingleton) private var currentIOBSingleton
    @Environment(\.workoutModeStore) private var workoutModeStore

    @State private var workoutManager = WorkoutHealthKitManager.shared
    @State private var selectedThreshold = SharedData.libre3WorkoutLowDefaultMgDL
    @State private var selectedWorkoutType: WorkoutTypeOption = .yoga
    @State private var startFailureMessage: String?

    @AppStorage(DefaultsKey.cgmProviderKind.rawValue, store: UserDefaults.group)
    private var providerKindRawValue = CGMProviderKind.libreLinkUp.rawValue
    @AppStorage(DefaultsKey.libre3SessionOwnerMirror.rawValue, store: UserDefaults.group)
    private var ownershipMirror = Libre3WorkoutOwnershipDevice.phone.rawValue
    @AppStorage(DefaultsKey.libre3EngineStatusMessage.rawValue, store: UserDefaults.group)
    private var libre3EngineStatusMessage = "[...]"
    @AppStorage(DefaultsKey.libre3EngineDidFail.rawValue, store: UserDefaults.group)
    private var libre3EngineDidFail = false
    @AppStorage(DefaultsKey.libre3EngineIsAcquiring.rawValue, store: UserDefaults.group)
    private var libre3EngineIsAcquiring = false

    private let workoutGraphWindow: TimeInterval = 90 * 60

    private var currentProviderKind: CGMProviderKind {
        CGMProviderKind(rawValue: providerKindRawValue) ?? .libreLinkUp
    }

    private var glucoseUnit: GlucoseUnit {
        GlucoseUnit(uom: sensorSettingsStore.sensorSettings.uom)
    }

    private var currentGlucoseText: String {
        guard libreLinkUpHistory.currentGlucose > 0 else { return "--" }
        return libreLinkUpHistory.currentGlucose.asGlucose(glucoseUnit: glucoseUnit)
    }

    private var currentTrendText: String {
        libreLinkUpHistory.currentGlucose > 0
            ? libreLinkUpHistory.currentTrendArrow
            : "--"
    }

    /// Colour of the reading the workout value actually shows. `currentGlucose`
    /// comes from `latestLibreLinkUpGlucose`, so take the colour from the same
    /// reading rather than from the head of the graph series.
    private var currentReadingColor: Color {
        libreLinkUpHistory.latestLibreLinkUpGlucose?.color.color ?? .white
    }

    private var currentHeartRateText: String {
        guard let currentHeartRate = workoutManager.currentHeartRate else { return "--" }
        return currentHeartRate.formatted(.number.precision(.fractionLength(0)))
    }

    private func elapsedText(at now: Date) -> String {
        guard let startedAt = workoutModeStore.startedAt else { return "--:--" }
        let elapsed = max(Int(now.timeIntervalSince(startedAt)), 0)
        let hours = elapsed / 3_600
        let minutes = (elapsed % 3_600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var fiveMinuteDeltaText: String {
        guard let latest = libreLinkUpHistory.latestLibreLinkUpGlucose else { return "--" }
        let targetDate = latest.glucose.date.addingTimeInterval(-5 * 60)
        let oldestAcceptableDate = targetDate.addingTimeInterval(-5 * 60)
        let previous = (libreLinkUpHistory.libreLinkUpMinuteGlucose + libreLinkUpHistory.libreLinkUpGlucose)
            .filter {
                $0.glucose.date <= targetDate
                    && $0.glucose.date >= oldestAcceptableDate
                    && $0.glucose.date < latest.glucose.date
            }
            .max { $0.glucose.date < $1.glucose.date }
        guard let previous else { return "--" }
        return Double(latest.glucose.value - previous.glucose.value)
            .asShortMinuteChange(glucoseUnit: glucoseUnit)
    }

    /// What the workout screen says about the Libre 3 link, plus whether that
    /// status is about reaching the sensor over the air. The two ownership states
    /// are not: moving the sensor closer cannot help when the phone holds it, or
    /// when provisioning is stale.
    private struct Libre3WorkoutStatus {
        let text: String
        let concernsRadioLink: Bool
    }

    private var activeLibre3Status: Libre3WorkoutStatus? {
        guard workoutModeStore.providerKind == .libre3BLE,
              let workoutSessionID = workoutModeStore.workoutSessionID else { return nil }

        _ = ownershipMirror
        let ownership = SharedData.libre3SessionOwner
        if ownership.hasTerminalReclaim(for: workoutSessionID)
            || (ownership.workoutSessionID == workoutSessionID && ownership.owner == .phone) {
            return Libre3WorkoutStatus(
                text: String(
                    localized: "Sensor moved to iPhone",
                    comment: "Apple Watch workout status after the user took Libre 3 sensor readings back on the iPhone. The workout itself is still running."
                ),
                concernsRadioLink: false
            )
        }
        if ownership.claimRejectionReason != nil {
            return Libre3WorkoutStatus(
                text: String(
                    localized: "Waiting for current sensor setup",
                    comment: "Apple Watch workout status while a rejected Libre 3 ownership claim waits for refreshed provisioning from iPhone."
                ),
                concernsRadioLink: false
            )
        }
        if libre3EngineStatusMessage == "[...]" || libre3EngineStatusMessage.isEmpty {
            return Libre3WorkoutStatus(
                text: String(
                    localized: "Acquiring sensor…",
                    comment: "Apple Watch workout status while discovering and authenticating directly with the Libre 3 sensor."
                ),
                concernsRadioLink: true
            )
        }
        return Libre3WorkoutStatus(text: libre3EngineStatusMessage, concernsRadioLink: true)
    }

    /// Whether to advise moving the sensor nearer the watch. Shown for the whole
    /// acquisition rather than after a delay: distance is the only lever the user
    /// has, and acting on it early is what shortens the wait.
    ///
    /// A Libre 3 advertises once a minute in a short burst with no retries, so a
    /// connect has to be decoded, answered and acknowledged inside that one
    /// burst. An established link has none of those constraints: it retries every
    /// connection interval for seconds. That asymmetry is why a stream survives
    /// across the body while the reconnect after it does not.
    private var showsSensorPlacementHint: Bool {
        libre3EngineIsAcquiring && activeLibre3Status?.concernsRadioLink == true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 9) {
                    if workoutModeStore.isActive {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            activeWorkout(at: context.date)
                        }
                    } else {
                        startCard
                    }
                }
                .padding(.horizontal, 7)
            }
        }
        .onAppear {
            selectedThreshold = workoutModeStore.lowGlucoseThreshold
            selectedWorkoutType = workoutModeStore.workoutType
            if !workoutModeStore.isActive,
               (workoutModeStore.updatedAt == .distantPast
                || workoutModeStore.providerKind != currentProviderKind) {
                selectedThreshold = currentProviderKind == .libre3BLE
                    ? SharedData.libre3WorkoutLowDefaultMgDL
                    : sensorSettingsStore.sensorSettings.alarmLow
                persistPreferences()
            }
            workoutManager.preflightBluetoothPermissionIfNeeded()
        }
        .onChange(of: providerKindRawValue) { _, newValue in
            guard !workoutModeStore.isActive else { return }
            if CGMProviderKind(rawValue: newValue) == .libre3BLE {
                selectedThreshold = SharedData.libre3WorkoutLowDefaultMgDL
            } else {
                selectedThreshold = sensorSettingsStore.sensorSettings.alarmLow
            }
            persistPreferences()
            workoutManager.preflightBluetoothPermissionIfNeeded()
        }
        .alert(
            String(
                localized: "Couldn’t Start Workout",
                comment: "Title of an Apple Watch alert explaining why a workout could not start."
            ),
            isPresented: Binding(
                get: { startFailureMessage != nil },
                set: { if !$0 { startFailureMessage = nil } }
            )
        ) {
            Button(
                String(localized: "OK", comment: "Dismisses a workout start failure alert."),
                role: .cancel
            ) {
                startFailureMessage = nil
            }
        } message: {
            if let startFailureMessage {
                Text(verbatim: startFailureMessage)
            }
        }
    }

    private var startCard: some View {
        VStack(spacing: 10) {
            Text("Workout Mode", comment: "Heading of the Apple Watch workout start screen.")
                .font(.headline)

            Text(verbatim: currentProviderKind.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if currentProviderKind == .libre3BLE {
                bluetoothPermissionStatus

                Text(
                    "Wear the watch on the arm closest to the sensor. Otherwise the signal has to cross your body, and reconnecting can take much longer.",
                    comment: "Placement advice on the Apple Watch workout start screen for direct Libre 3 sensor readings. Body tissue absorbs the 2.4 GHz signal, so a sensor on the opposite arm makes reconnecting slow."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Picker(
                String(localized: "Workout", comment: "Label for the Apple Watch workout activity picker."),
                selection: $selectedWorkoutType
            ) {
                ForEach(WorkoutTypeOption.sortedOptions) { workoutType in
                    Text(verbatim: "\(workoutType.displayName) · \(workoutType.defaultLocation.displayName)")
                        .tag(workoutType)
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: selectedWorkoutType) { _, _ in persistPreferences() }

            HStack {
                Text("Workout low", comment: "Label for the glucose threshold used by workout alerts on Apple Watch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: selectedThreshold.asGlucose(glucoseUnit: glucoseUnit, withUnit: true))
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 28) {
                Button {
                    selectedThreshold = max(selectedThreshold - 5, 60)
                    persistPreferences()
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text("Lower workout threshold", comment: "Accessibility label for lowering the Apple Watch workout glucose threshold.")
                )

                Button {
                    selectedThreshold = min(selectedThreshold + 5, 200)
                    persistPreferences()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text("Raise workout threshold", comment: "Accessibility label for raising the Apple Watch workout glucose threshold.")
                )
            }
            .font(.title3)

            NavigationLink {
                WorkoutAlertSettingsView(workoutLowThreshold: selectedThreshold)
            } label: {
                Text(
                    "Workout alerts",
                    comment: "Navigation link from the Apple Watch workout start screen to workout alert settings."
                )
            }

            Button {
                Task {
                    let result = await workoutManager.startWorkout(
                        lowGlucoseThreshold: selectedThreshold,
                        workoutType: selectedWorkoutType
                    )
                    if result != .started {
                        startFailureMessage = result.userMessage
                    }
                }
            } label: {
                if workoutManager.operationState == .starting {
                    ProgressView()
                } else {
                    Text("Start", comment: "Starts the selected workout on Apple Watch.")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                workoutManager.isBusy
                    || (currentProviderKind == .libre3BLE
                        && workoutManager.bluetoothAuthorization != .allowedAlways)
            )
        }
    }

    @ViewBuilder
    private var bluetoothPermissionStatus: some View {
        switch workoutManager.bluetoothAuthorization {
        case .allowedAlways:
            Label {
                Text("Bluetooth ready", comment: "Apple Watch workout preflight status when Bluetooth permission is granted.")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundStyle(.green)
        case .notDetermined:
            Label {
                Text("Allow Bluetooth access to continue", comment: "Apple Watch workout preflight status while its Bluetooth permission prompt awaits a choice.")
            } icon: {
                ProgressView()
            }
            .foregroundStyle(.secondary)
        case .denied, .restricted:
            Label {
                Text("Bluetooth access is off", comment: "Apple Watch workout preflight status when Bluetooth permission is denied or restricted.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .foregroundStyle(.orange)
        @unknown default:
            EmptyView()
        }
    }

    private func activeWorkout(at now: Date) -> some View {
        let batteryLevel = WKInterfaceDevice.current().batteryLevel

        return VStack(spacing: 8) {
            HStack {
                Text(verbatim: workoutModeStore.workoutType.shortDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if batteryLevel >= 0 {
                    batteryIndicator(level: batteryLevel)
                    Spacer()
                }
                Text(verbatim: elapsedText(at: now))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: currentGlucoseText)
                    .font(.system(size: 43, weight: .bold, design: .rounded))
                    .foregroundStyle(currentReadingColor)
                    .minimumScaleFactor(0.65)
                Text(verbatim: currentTrendText)
                    .font(.title2)
                    .foregroundStyle(currentReadingColor)
                Spacer(minLength: 0)
            }

            HStack {
                compactStat(
                    title: String(localized: "5 min", comment: "Label for glucose change over the previous five minutes on Apple Watch."),
                    value: fiveMinuteDeltaText
                )
                Spacer()
                compactStat(
                    title: String(localized: "HR", comment: "Abbreviation for heart rate on Apple Watch."),
                    value: currentHeartRateText
                )
                Spacer()
                compactStat(
                    title: String(localized: "IOB", comment: "Abbreviation for insulin on board on Apple Watch."),
                    value: String(
                        localized: "\(currentIOBSingleton.currentIOB.asInsulin()) U",
                        comment: "Insulin on board amount on Apple Watch. The interpolated value is a localized decimal number; U means insulin units."
                    )
                )
            }

            if let activeLibre3Status {
                VStack(alignment: .leading, spacing: 2) {
                    Label {
                        Text(verbatim: activeLibre3Status.text)
                            .lineLimit(2)
                    } icon: {
                        Image(
                            systemName: libre3EngineDidFail
                                ? "exclamationmark.triangle.fill"
                                : "antenna.radiowaves.left.and.right"
                        )
                    }
                    .foregroundStyle(libre3EngineDidFail ? .orange : .secondary)

                    if showsSensorPlacementHint {
                        Text(
                            "Bring the sensor close to the watch.",
                            comment: "Advice shown on Apple Watch when a Libre 3 sensor has taken a long time to connect during a workout. Moving the sensor nearer is the only thing the user can do to help."
                        )
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !libreLinkUpHistory.libreLinkUpGlucose.isEmpty {
                WatchAppGraphView(
                    windowEnd: .chartWindowEnd(from: now),
                    windowDuration: workoutGraphWindow
                )
                .frame(height: 105)
            }

            Button(role: .destructive) {
                Task { await workoutManager.endWorkout() }
            } label: {
                if workoutManager.operationState == .ending {
                    ProgressView()
                } else {
                    Text("End Workout", comment: "Ends and saves the active Apple Watch workout.")
                }
            }
            .buttonStyle(.bordered)
            .disabled(workoutManager.isBusy)
        }
        .onAppear {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        }
        .onDisappear {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = false
        }
    }

    private func batteryIndicator(level: Float) -> some View {
        let levelText = Double(level).formatted(
            .percent.precision(.fractionLength(0))
        )

        return Text(verbatim: levelText)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityLabel(
            Text(
                "Watch battery",
                comment: "Accessibility label for the Apple Watch battery indicator during a workout."
            )
        )
        .accessibilityValue(Text(verbatim: levelText))
    }

    private func compactStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    private func persistPreferences() {
        let maximumCriticalLowThreshold = max(50, min(80, selectedThreshold - 5))
        SharedData.workoutCriticalLowThresholdMgDL = min(
            max(SharedData.workoutCriticalLowThresholdMgDL, 50),
            maximumCriticalLowThreshold
        )
        _ = workoutModeStore.savePreferences(
            lowGlucoseThreshold: selectedThreshold,
            workoutType: selectedWorkoutType,
            providerKind: currentProviderKind
        )
    }
}

private struct WorkoutAlertSettingsView: View {
    let workoutLowThreshold: Int

    @Environment(\.sensorSettingsStore) private var sensorSettingsStore

    @AppStorage(DefaultsKey.workoutLowCriticalAlertsEnabled.rawValue, store: UserDefaults.group)
    private var workoutLowCriticalAlertsEnabled = false
    @AppStorage(DefaultsKey.workoutCriticalLowThresholdMgDL.rawValue, store: UserDefaults.group)
    private var workoutCriticalLowThresholdMgDL = 55
    @AppStorage(DefaultsKey.workoutCriticalLowCriticalAlertsEnabled.rawValue, store: UserDefaults.group)
    private var workoutCriticalLowCriticalAlertsEnabled = true
    @AppStorage(DefaultsKey.workoutRapidDropAlertsEnabled.rawValue, store: UserDefaults.group)
    private var workoutRapidDropAlertsEnabled = true
    @AppStorage(DefaultsKey.workoutRapidDropCriticalAlertsEnabled.rawValue, store: UserDefaults.group)
    private var workoutRapidDropCriticalAlertsEnabled = false
    @AppStorage(DefaultsKey.workoutNoReadingCriticalAlertsEnabled.rawValue, store: UserDefaults.group)
    private var workoutNoReadingCriticalAlertsEnabled = true

    private var glucoseUnit: GlucoseUnit {
        GlucoseUnit(uom: sensorSettingsStore.sensorSettings.uom)
    }

    private var maximumCriticalLowThreshold: Int {
        max(50, min(80, workoutLowThreshold - 5))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text(
                        "Critically low",
                        comment: "Label for the critically-low glucose threshold used during Apple Watch workouts."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text(
                        verbatim: workoutCriticalLowThresholdMgDL.asGlucose(
                            glucoseUnit: glucoseUnit,
                            withUnit: true
                        )
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                }

                HStack(spacing: 28) {
                    Button {
                        workoutCriticalLowThresholdMgDL = max(
                            workoutCriticalLowThresholdMgDL - 5,
                            50
                        )
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(
                            "Lower critically-low threshold",
                            comment: "Accessibility label for lowering the Apple Watch workout critically-low glucose threshold."
                        )
                    )

                    Button {
                        workoutCriticalLowThresholdMgDL = min(
                            workoutCriticalLowThresholdMgDL + 5,
                            maximumCriticalLowThreshold
                        )
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(
                            "Raise critically-low threshold",
                            comment: "Accessibility label for raising the Apple Watch workout critically-low glucose threshold."
                        )
                    )
                }
                .font(.title3)

                Toggle(isOn: $workoutLowCriticalAlertsEnabled) {
                    Text(
                        "Critical workout-low alerts",
                        comment: "Toggle that makes workout-low glucose notifications use critical delivery on Apple Watch."
                    )
                }

                Toggle(isOn: $workoutCriticalLowCriticalAlertsEnabled) {
                    Text(
                        "Critical critically-low alerts",
                        comment: "Toggle that makes critically-low glucose notifications during workouts use critical delivery on Apple Watch."
                    )
                }

                Toggle(isOn: $workoutRapidDropAlertsEnabled) {
                    Text(
                        "Rapid-drop alerts",
                        comment: "Toggle that enables rapid glucose-drop notifications during Apple Watch workouts."
                    )
                }

                Text(
                    "Alerts when the sensor trend arrow is pointing straight down.",
                    comment: "Explanation of when rapid-drop workout alerts fire on Apple Watch."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $workoutRapidDropCriticalAlertsEnabled) {
                    Text(
                        "Critical rapid-drop alerts",
                        comment: "Toggle that makes rapid glucose-drop notifications during workouts use critical delivery on Apple Watch."
                    )
                }

                Toggle(isOn: $workoutNoReadingCriticalAlertsEnabled) {
                    Text(
                        "Critical no-reading alerts",
                        comment: "Toggle that makes missing-glucose-reading notifications during workouts use critical delivery on Apple Watch."
                    )
                }
            }
            .padding(.horizontal, 7)
        }
        .navigationTitle(
            Text(
                "Workout alerts",
                comment: "Navigation title for Apple Watch workout alert settings."
            )
        )
        .onAppear {
            workoutCriticalLowThresholdMgDL = min(
                max(workoutCriticalLowThresholdMgDL, 50),
                maximumCriticalLowThreshold
            )
        }
    }
}

#Preview {
    WatchAppWorkoutView()
        .environment(\.libreLinkUpHistory, LibreLinkUpHistory.shared)
        .environment(\.sensorSettingsStore, SensorSettingsStore.shared)
        .environment(\.currentIOBSingleton, CurrentIOBSingleton.shared)
        .environment(\.workoutModeStore, WorkoutModeStore.shared)
}
