//
//  WatchAppWorkoutView.swift
//  FLwatchWatchApp
//

import SwiftUI
import WatchKit

struct WatchAppWorkoutView: View {
    // MARK: - Environment and state

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
    @AppStorage(DefaultsKey.libre3EngineIsLinking.rawValue, store: UserDefaults.group)
    private var libre3EngineIsLinking = false
    @AppStorage(DefaultsKey.libre3EngineIsStreaming.rawValue, store: UserDefaults.group)
    private var libre3EngineIsStreaming = false

    /// Retains the five-minute calculation and layout for easy re-enabling
    /// without spending space on it in the current workout design.
    private static let displaysFiveMinuteDelta = false
    private let workoutGraphWindow: TimeInterval = 90 * 60

    // MARK: - Display values

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

    private var currentIOBText: String? {
        guard currentIOBSingleton.currentIOB > 0 else { return nil }
        return String(
            localized: "\(currentIOBSingleton.currentIOB.asInsulin()) U",
            comment: "Insulin on board amount on Apple Watch. The interpolated value is a localized decimal number; U means insulin units."
        )
    }

    private var currentDistanceText: String? {
        guard workoutModeStore.workoutLocation == .outdoor else { return nil }
        guard let meters = workoutManager.currentDistanceMeters else { return "--" }
        return Measurement(value: meters, unit: UnitLength.meters).formatted(
            .measurement(width: .abbreviated, usage: .road)
        )
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

    private func isReadingStale(at now: Date) -> Bool {
        guard libreLinkUpHistory.currentGlucose > 0,
              let latest = libreLinkUpHistory.latestLibreLinkUpGlucose else { return false }
        return now.timeIntervalSince(latest.glucose.date)
            >= workoutModeStore.providerKind.staleReadingAfter
    }

    private var sensorConnectionIndicatorColor: Color? {
        guard workoutModeStore.providerKind == .libre3BLE else { return nil }
        if libre3EngineIsStreaming { return .green }
        if libre3EngineIsLinking { return .orange }
        return .red
    }

    // MARK: - Libre 3 connection status

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
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
                    .id(WorkoutScrollAnchor.top)
                    .padding(.horizontal, 7)
                }
                .contentMargins(
                    .top,
                    workoutModeStore.isActive ? 0 : nil,
                    for: .scrollContent
                )
                .onChange(of: workoutModeStore.isActive) { _, _ in
                    scrollProxy.scrollTo(WorkoutScrollAnchor.top, anchor: .top)
                }
            }
        }
        .onAppear {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
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
        .onDisappear {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = false
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

    // MARK: - Start screen

    private var startCard: some View {
        VStack(spacing: 10) {
            Text("Workout", comment: "Heading of the Apple Watch workout start screen.")
                .font(.headline)

            if currentProviderKind == .libre3BLE {
                bluetoothPermissionStatus
            }

            Picker(
                String(
                    localized: "Select workout",
                    comment: "Label for the Apple Watch control used to choose a workout activity."
                ),
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

            VStack(spacing: 6) {
                Text(verbatim: currentProviderKind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if currentProviderKind == .libre3BLE {
                    Text(
                        "Wear the watch on the arm closest to the sensor. Otherwise the signal has to cross your body, and reconnecting can take much longer.",
                        comment: "Placement advice on the Apple Watch workout start screen for direct Libre 3 sensor readings. Body tissue absorbs the 2.4 GHz signal, so a sensor on the opposite arm makes reconnecting slow."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 4)
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

    // MARK: - Active screen

    private func activeWorkout(at now: Date) -> some View {
        let batteryLevel = WKInterfaceDevice.current().batteryLevel
        let connectionStatus = activeLibre3Status.map {
            WorkoutConnectionDisplay(
                text: $0.text,
                isFailure: libre3EngineDidFail,
                showsPlacementHint: showsSensorPlacementHint
            )
        }
        let values = ActiveWorkoutDisplayValues(
            glucoseText: currentGlucoseText,
            trendText: currentTrendText,
            readingColor: currentReadingColor,
            isReadingStale: isReadingStale(at: now),
            iobText: currentIOBText,
            workoutName: workoutModeStore.workoutType.shortDisplayName,
            outdoorLocationText: workoutModeStore.workoutLocation == .outdoor
                ? workoutModeStore.workoutLocation.displayName
                : nil,
            elapsedText: elapsedText(at: now),
            batteryLevel: batteryLevel >= 0 ? Double(batteryLevel) : nil,
            sensorConnectionIndicatorColor: sensorConnectionIndicatorColor,
            fiveMinuteDeltaText: Self.displaysFiveMinuteDelta
                ? fiveMinuteDeltaText
                : nil,
            heartRateText: currentHeartRateText,
            distanceText: currentDistanceText,
            connectionStatus: connectionStatus,
            showsGraph: !libreLinkUpHistory.libreLinkUpGlucose.isEmpty,
            isEnding: workoutManager.operationState == .ending,
            isBusy: workoutManager.isBusy
        )

        return ActiveWorkoutContent(values: values) {
            WatchAppGraphView(
                windowEnd: .chartWindowEnd(from: now),
                windowDuration: workoutGraphWindow,
                topPadding: 0
            )
        } onEndWorkout: {
            Task { await workoutManager.endWorkout() }
        }
    }

    // MARK: - Actions

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

// MARK: - Active workout presentation

private enum WorkoutScrollAnchor {
    static let top = "workout-top"
}

private let showsActiveWorkoutLayoutBorders = false

private struct WorkoutConnectionDisplay {
    let text: String
    let isFailure: Bool
    let showsPlacementHint: Bool
}

private struct ActiveWorkoutDisplayValues {
    let glucoseText: String
    let trendText: String
    let readingColor: Color
    let isReadingStale: Bool
    let iobText: String?
    let workoutName: String
    let outdoorLocationText: String?
    let elapsedText: String
    let batteryLevel: Double?
    let sensorConnectionIndicatorColor: Color?
    let fiveMinuteDeltaText: String?
    let heartRateText: String
    let distanceText: String?
    let connectionStatus: WorkoutConnectionDisplay?
    let showsGraph: Bool
    let isEnding: Bool
    let isBusy: Bool
}

private struct ActiveWorkoutContent<GraphContent: View>: View {
    let values: ActiveWorkoutDisplayValues
    let graph: GraphContent
    let onEndWorkout: () -> Void

    init(
        values: ActiveWorkoutDisplayValues,
        @ViewBuilder graph: () -> GraphContent,
        onEndWorkout: @escaping () -> Void
    ) {
        self.values = values
        self.graph = graph()
        self.onEndWorkout = onEndWorkout
    }

    var body: some View {
        VStack(spacing: 4) {
            workoutMetricsRow
                .border(
                    showsActiveWorkoutLayoutBorders ? Color.red : Color.clear,
                    width: 0.5
                )
            glucoseBlock
                .border(
                    showsActiveWorkoutLayoutBorders ? Color.red : Color.clear,
                    width: 0.5
                )

            if values.showsGraph {
                graph
                    .frame(height: 105)
                    .border(
                        showsActiveWorkoutLayoutBorders ? Color.red : Color.clear,
                        width: 0.5
                    )
            }

            if let connectionStatus = values.connectionStatus {
                connectionView(connectionStatus)
                    .border(
                        showsActiveWorkoutLayoutBorders ? Color.red : Color.clear,
                        width: 0.5
                    )
            }

            Button(role: .destructive, action: onEndWorkout) {
                if values.isEnding {
                    ProgressView()
                } else {
                    Text("End Workout", comment: "Ends and saves the active Apple Watch workout.")
                }
            }
            .buttonStyle(.bordered)
            .disabled(values.isBusy)
            .border(
                showsActiveWorkoutLayoutBorders ? Color.red : Color.clear,
                width: 0.5
            )
        }
        .padding(.top, -6)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                workoutTitleRow
            }
        }
    }

    private var workoutTitleRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: values.workoutName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .border(
                    showsActiveWorkoutLayoutBorders ? Color.red : Color.clear,
                    width: 0.5
                )

            HStack(spacing: 4) {
                if let sensorConnectionIndicatorColor = values.sensorConnectionIndicatorColor {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(sensorConnectionIndicatorColor)
                        // The detailed, accessible connection status remains below.
                        .accessibilityHidden(true)
                }
                batteryIndicator
            }
            .border(
                showsActiveWorkoutLayoutBorders ? Color.red : Color.clear,
                width: 0.5
            )
        }
    }

    private var workoutMetricsRow: some View {
        HStack {
            timeStat
            Spacer()
            compactStat(
                title: String(
                    localized: "HR",
                    comment: "Abbreviation for heart rate on Apple Watch."
                ),
                value: values.heartRateText
            )
            if let distanceText = values.distanceText {
                Spacer()
                compactStat(
                    title: String(
                        localized: "Distance",
                        comment: "Label for distance covered during an outdoor Apple Watch workout."
                    ),
                    value: distanceText
                )
            }
        }
    }

    private var timeStat: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(
                LocalizedStringResource(
                    "workout.duration-label",
                    defaultValue: "Time",
                    comment: "Short label for the elapsed duration shown during an active Apple Watch workout."
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            Text(verbatim: values.elapsedText)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// Keep all four values together when their ideal widths fit. On narrower
    /// watches only the secondary five-minute change moves below the main row.
    @ViewBuilder
    private var glucoseBlock: some View {
        if let fiveMinuteDeltaText = values.fiveMinuteDeltaText {
            ViewThatFits(in: .horizontal) {
                glucoseRow(fiveMinuteDeltaText: fiveMinuteDeltaText)
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 3) {
                    glucoseRow(fiveMinuteDeltaText: nil)
                    fiveMinuteStat(value: fiveMinuteDeltaText)
                }
            }
        } else {
            glucoseRow(fiveMinuteDeltaText: nil)
                .padding(.top, -6)
                .padding(.bottom, -6)
        }
    }

    private func glucoseRow(fiveMinuteDeltaText: String?) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 7) {
            Text(verbatim: values.glucoseText)
                .font(
                    .system(
                        size: 43,
                        weight: values.isReadingStale ? .regular : .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(values.readingColor)
                .strikethrough(values.isReadingStale)
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text(verbatim: values.trendText)
                .font(
                    .system(
                        .title2,
                        design: .rounded,
                        weight: values.isReadingStale ? .regular : .bold
                    )
                )
                .foregroundStyle(values.readingColor)
                .strikethrough(values.isReadingStale)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let iobText = values.iobText {
                compactStat(
                    title: String(
                        localized: "IOB",
                        comment: "Abbreviation for insulin on board on Apple Watch."
                    ),
                    value: iobText
                )
                .layoutPriority(1)
            }

            if let fiveMinuteDeltaText {
                fiveMinuteStat(value: fiveMinuteDeltaText)
            }
        }
    }

    private func fiveMinuteStat(value: String) -> some View {
        compactStat(
            title: String(
                localized: "5 min",
                comment: "Label for glucose change over the previous five minutes on Apple Watch."
            ),
            value: value
        )
    }

    private var batteryIndicator: some View {
        let levelText = values.batteryLevel?.formatted(
            .percent.precision(.fractionLength(0))
        ) ?? "--%"

        return HStack(spacing: 2) {
            Image(systemName: "battery.100percent")
            Text(verbatim: levelText)
                .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "Watch battery",
                comment: "Accessibility label for the Apple Watch battery indicator during a workout."
            )
        )
        .accessibilityValue(
            values.batteryLevel == nil
                ? Text(
                    "Unavailable",
                    comment: "Accessibility value when the Apple Watch battery percentage is temporarily unavailable."
                )
                : Text(verbatim: levelText)
        )
    }

    private func connectionView(
        _ connectionStatus: WorkoutConnectionDisplay
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(verbatim: connectionStatus.text)
                    .lineLimit(2)
            } icon: {
                Image(
                    systemName: connectionStatus.isFailure
                        ? "exclamationmark.triangle.fill"
                        : "antenna.radiowaves.left.and.right"
                )
            }
            .foregroundStyle(connectionStatus.isFailure ? .orange : .secondary)

            if connectionStatus.showsPlacementHint {
                Text(
                    "Bring the sensor close to the watch.",
                    comment: "Advice shown on Apple Watch while Libre 3 is acquiring the sensor during a workout. Moving the sensor nearer is the only thing the user can do to help."
                )
                .lineLimit(2)
                .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(verbatim: value)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
    }
}

// MARK: - Workout alert settings

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

// MARK: - Previews

private struct WorkoutGraphPreview: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.62))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.2, y: geometry.size.height * 0.48))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.4, y: geometry.size.height * 0.55))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.62, y: geometry.size.height * 0.3))
                path.addLine(to: CGPoint(x: geometry.size.width * 0.8, y: geometry.size.height * 0.38))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.24))
            }
            .stroke(.green, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        .background(.green.opacity(0.08))
    }
}

#Preview("Workout Setup") {
    WatchAppWorkoutView()
        .environment(\.libreLinkUpHistory, LibreLinkUpHistory.shared)
        .environment(\.sensorSettingsStore, SensorSettingsStore.shared)
        .environment(\.currentIOBSingleton, CurrentIOBSingleton.shared)
        .environment(\.workoutModeStore, WorkoutModeStore.shared)
}

#Preview("Active Outdoor") {
    NavigationStack {
        ScrollView {
            ActiveWorkoutContent(
                values: ActiveWorkoutDisplayValues(
                    glucoseText: "142",
                    trendText: "→",
                    readingColor: .green,
                    isReadingStale: true,
                    iobText: "1.2 U",
                    workoutName: "Running",
                    outdoorLocationText: "Outdoor",
                    elapsedText: "24:18",
                    batteryLevel: 0.72,
                    sensorConnectionIndicatorColor: .green,
                    fiveMinuteDeltaText: nil,
                    heartRateText: "138",
                    distanceText: "3.2 km",
                    connectionStatus: WorkoutConnectionDisplay(
                        text: "Streaming",
                        isFailure: false,
                        showsPlacementHint: false
                    ),
                    showsGraph: true,
                    isEnding: false,
                    isBusy: false
                )
            ) {
                WorkoutGraphPreview()
            } onEndWorkout: {}
            .padding(.horizontal, 7)
        }
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
