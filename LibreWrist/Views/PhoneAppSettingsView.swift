//
//  PhoneAppSettingsView.swift
//  LibreWrist
//
//  Created by Peter Müller on 03.09.24.
//

import SwiftUI
import MessageUI
import ActivityKit

struct PhoneAppSettingsView: View {

    private typealias NightscoutDraftConfiguration = (
        baseURL: NightscoutBaseURL,
        accessToken: String
    )

    private enum NightscoutSettingsStatus {
        case success(String)
        case failure(String)

        var message: String {
            switch self {
            case .success(let message), .failure(let message):
                return message
            }
        }

        var systemImage: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .failure: return .red
            }
        }
    }
    
    @Environment(\.openURL) private var openURL
    
    @AppStorage(DefaultsKey.cgmProviderKind.rawValue, store: UserDefaults.group) private var cgmProviderKindRaw: String = CGMProviderKind.libreLinkUp.rawValue
    @AppStorage(DefaultsKey.showInsulinDeliveryMarksPhone.rawValue, store: UserDefaults.group) private var showInsulinDeliveryMarksPhone: Bool = false
    @AppStorage(DefaultsKey.showInsulinDeliveryMarksWatch.rawValue, store: UserDefaults.group) private var showInsulinDeliveryMarksWatch: Bool = false
    @AppStorage(DefaultsKey.showIOBCurvePhone.rawValue, store: UserDefaults.group) private var showIOBCurvePhone: Bool = false
    @AppStorage(DefaultsKey.showIOBCurveWatch.rawValue, store: UserDefaults.group) private var showIOBCurveWatch: Bool = false
    @AppStorage(DefaultsKey.showActivityCurvePhone.rawValue, store: UserDefaults.group) private var showActivityCurvePhone: Bool = false
    @AppStorage(DefaultsKey.showActivityCurveWatch.rawValue, store: UserDefaults.group) private var showActivityCurveWatch: Bool = false
    @AppStorage(DefaultsKey.widgetUpdateFrequency.rawValue, store: UserDefaults.group) private var widgetUpdateFrequency: Int = 5
    @AppStorage(DefaultsKey.tapComplicationReloads.rawValue, store: UserDefaults.group) private var tapComplicationReloads: Bool = false
    @AppStorage(DefaultsKey.useLiveActivities.rawValue, store: UserDefaults.group) private var useLiveActivities: Bool = true
    @AppStorage(DefaultsKey.lowGlucoseNotificationsEnabled.rawValue, store: UserDefaults.group) private var lowGlucoseNotificationsEnabled: Bool = false
    @AppStorage(DefaultsKey.lowGlucoseNotificationThreshold.rawValue, store: UserDefaults.group) private var lowGlucoseNotificationThreshold: Int = 70
    @AppStorage(DefaultsKey.highGlucoseNotificationsEnabled.rawValue, store: UserDefaults.group) private var highGlucoseNotificationsEnabled: Bool = false
    @AppStorage(DefaultsKey.libre3CalibrationOffsetMgDL.rawValue, store: UserDefaults.group) private var libre3CalibrationOffsetMgDL: Int = 0
    @AppStorage(DefaultsKey.nightscoutUploadEnabled.rawValue, store: UserDefaults.group) private var nightscoutUploadEnabled: Bool = false
    @AppStorage("developerModeEnabled") private var developerModeEnabled: Bool = false
    
    
    @State private var isScreenAlwaysOn = false
    @State private var showingMailView = false
    @State private var isShowingSiriSheet = false
    @State private var isShowingDeveloperAlert = false
    @State private var isShowingCalibrationSheet = false
    @State private var developerAlertRequiresCode = true
    @State private var enteredDeveloperCode = ""
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var pendingProviderSwitch: CGMProviderKind? = nil
    @State private var insulinTypeSelected: InsulinType = UserDefaults.group.insulinTypeSelected
    @State private var manualUom: Int = SensorSettingsStore.shared.sensorSettings.uom
    @State private var manualTargetLow: Int = SensorSettingsStore.shared.sensorSettings.targetLow
    @State private var manualTargetHigh: Int = SensorSettingsStore.shared.sensorSettings.targetHigh
    @State private var dexcomSensorType: SensorType = {
        let current = SensorSettingsStore.shared.sensorType
        return current.isADexcom ? current : .dexcomG7
    }()
    @State private var appleHealthExportEnabled = AppleHealthExportManager.shared.isExportEnabled
    @State private var appleHealthAuthorizationState = AppleHealthExportManager.shared.syncPreferenceWithAuthorization()
    @State private var nightscoutURL = SharedData.nightscoutURL
    @State private var nightscoutAccessToken = ""
    @State private var nightscoutSettingsStatus: NightscoutSettingsStatus?
    @State private var isTestingNightscoutConnection = false
    @State private var isShowingForgetNightscoutConfirmation = false
    @State private var unresolvedNightscoutItemCount = 0
    @State private var pendingForgetNightscoutBaseURL: String?
    @State private var hasLoadedNightscoutToken = false
    @State private var nightscoutUploadStatus = NightscoutUploadManager.shared.status
    @StateObject private var bluetoothHeartbeatManager = BluetoothHeartbeatManager.shared
    private var watchConnector = WatchConnectivityManager.shared
    let updateFrequencyOptions: [Int] = [1, 5, 10, 15, 20]
    // Stored in mg/dL; displayed in the selected unit. Ranges kept disjoint so
    // targetLow stays below targetHigh and never trips SensorSettings normalization.
    let targetLowOptions: [Int] = Array(stride(from: 50, through: 120, by: 5))
    let targetHighOptions: [Int] = Array(stride(from: 125, through: 250, by: 5))
    private var bgAppRefreshExecutionTimestamps: [Date] {
        (UserDefaults.group.array(forKey: "bgAppRefreshExecutionTimestamps") as? [TimeInterval] ?? [])
            .map(Date.init(timeIntervalSince1970:))
    }

    private var hasSelectedHeartbeatDevice: Bool {
        !bluetoothHeartbeatManager.selectedDeviceName.isEmpty
    }

    private var bluetoothHeartbeatActionTitle: String {
        if bluetoothHeartbeatManager.isScanning {
            return hasSelectedHeartbeatDevice
                ? String(localized: "Pause heartbeat check")
                : String(localized: "Stop search")
        }

        if hasSelectedHeartbeatDevice {
            return String(localized: "Check heartbeat now")
        }

        return String(localized: "Scan devices")
    }

    private var bluetoothHeartbeatStatusText: String {
        switch bluetoothHeartbeatManager.settingsDisplayStatus {
        case .disabled:
            return String(localized: "Bluetooth heartbeat off")
        case .bluetoothOff:
            return String(localized: "Bluetooth is off")
        case .idle:
            return hasSelectedHeartbeatDevice
                ? String(localized: "Waiting for next heartbeat")
                : String(localized: "Ready to search")
        case .scanning:
            return hasSelectedHeartbeatDevice
                ? String(localized: "Waiting for next heartbeat")
                : String(localized: "Looking for devices")
        case .connecting:
            return String(localized: "Connecting to selected heartbeat device")
        case .connected:
            return String(localized: "Heartbeat received")
        case .unauthorized:
            return String(localized: "Bluetooth permission needed")
        case .unsupported:
            return String(localized: "Bluetooth not supported")
        case .unavailable:
            return String(localized: "Bluetooth unavailable")
        }
    }

    /// Turning the heartbeat off takes the cloud-provider alerts that ride on it
    /// down with it. The alert UI itself lives in `PhoneAppNotificationsView`;
    /// only this force-off path is still needed here.
    private func disableGlucoseAlerts(_ tier: GlucoseAlertTier) {
        Task {
            await LowGlucoseNotificationManager.shared.disableNotifications(for: tier)
        }
    }

    private var cgmProviderKind: CGMProviderKind {
        CGMProviderKind(rawValue: cgmProviderKindRaw) ?? .libreLinkUp
    }

    private var normalizedNightscoutURL: String? {
        try? NightscoutBaseURL(normalizing: nightscoutURL).absoluteString
    }

    private var nightscoutURLBinding: Binding<String> {
        Binding(
            get: { nightscoutURL },
            set: { newValue in
                nightscoutURL = newValue
                if let embeddedToken = embeddedNightscoutToken(in: newValue) {
                    nightscoutAccessToken = embeddedToken
                }
                nightscoutSettingsStatus = nil
            }
        )
    }

    private var nightscoutAccessTokenBinding: Binding<String> {
        Binding(
            get: { nightscoutAccessToken },
            set: { newValue in
                nightscoutAccessToken = newValue
                nightscoutSettingsStatus = nil
            }
        )
    }

    private var nightscoutUploadStatusPresentation: (message: String, systemImage: String, color: Color) {
        guard nightscoutUploadEnabled else {
            return (
                String(localized: "Automatic uploads are disabled."),
                "pause.circle",
                .secondary
            )
        }
        guard cgmProviderKind.isDirectBLE else {
            return (
                String(localized: "Upload is inactive while a cloud CGM provider is selected."),
                "pause.circle",
                .secondary
            )
        }

        switch nightscoutUploadStatus.activity {
        case .ready:
            if nightscoutUploadStatus.lastSuccessfulUploadAt == nil {
                return (
                    String(localized: "Waiting for the first glucose upload."),
                    "clock",
                    .secondary
                )
            }
            return (String(localized: "Uploads ready."), "checkmark.circle.fill", .green)
        case .retrying:
            return (String(localized: "Retrying Nightscout now."), "arrow.clockwise.circle", .orange)
        case .retryDeferred:
            return (
                String(localized: "Upload waiting to retry after a temporary network or server error."),
                "clock.arrow.circlepath",
                .orange
            )
        case .documentRejected:
            return (
                String(localized: "Nightscout rejected one glucose document; other readings remain eligible."),
                "exclamationmark.triangle.fill",
                .red
            )
        case .paused(let reason, let until):
            let reasonText: String
            switch reason {
            case .credentialsRejected:
                reasonText = String(localized: "Nightscout rejected the access token")
            case .endpointUnavailable:
                reasonText = String(localized: "no compatible Nightscout API v3 endpoint was found")
            case .authorizationUnavailable:
                reasonText = String(localized: "Nightscout authorization could not be established")
            case .invalidServerURL:
                reasonText = String(localized: "the saved Nightscout server URL is invalid")
            }
            let retryTime = until.formatted(date: .omitted, time: .shortened)
            return (
                String(localized: "Uploads paused: \(reasonText). Next automatic probe at \(retryTime)."),
                "exclamationmark.octagon.fill",
                .red
            )
        }
    }

    @ViewBuilder
    private var nightscoutSettingsSection: some View {
        if developerModeEnabled {
            Section {
                Toggle(
                    "Enable Nightscout upload",
                    isOn: Binding(
                        get: { nightscoutUploadEnabled },
                        set: { newValue in
                            if newValue {
                                testNightscoutConnection(enableAfterSuccess: true)
                                return
                            }
                            nightscoutUploadEnabled = false
                        }
                    )
                )
                .disabled(isTestingNightscoutConnection)

                TextField(
                    "Server URL or token link",
                    text: nightscoutURLBinding,
                    prompt: Text("https://nightscout.example.com")
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

                SecureField(
                    "Admin access token",
                    text: nightscoutAccessTokenBinding
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Text("Paste the complete Nightscout token link, or enter the server URL and admin access token separately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let normalizedNightscoutURL {
                    LabeledContent("Server to test") {
                        Text(normalizedNightscoutURL)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }

                Button {
                    testNightscoutConnection()
                } label: {
                    HStack {
                        Text("Test connection")
                        Spacer()
                        if isTestingNightscoutConnection {
                            ProgressView()
                        }
                    }
                }
                .disabled(isTestingNightscoutConnection)

                if let nightscoutSettingsStatus {
                    Label(
                        nightscoutSettingsStatus.message,
                        systemImage: nightscoutSettingsStatus.systemImage
                    )
                    .font(.callout)
                    .foregroundStyle(nightscoutSettingsStatus.color)
                }

                if let lastSuccessfulUploadAt = nightscoutUploadStatus.lastSuccessfulUploadAt {
                    LabeledContent("Last successful upload") {
                        Text(lastSuccessfulUploadAt.formatted(date: .abbreviated, time: .standard))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Label(
                    nightscoutUploadStatusPresentation.message,
                    systemImage: nightscoutUploadStatusPresentation.systemImage
                )
                .font(.callout)
                .foregroundStyle(nightscoutUploadStatusPresentation.color)

                Button("Forget server", role: .destructive) {
                    prepareToForgetNightscoutServer()
                }
                .disabled(isTestingNightscoutConnection)
                .confirmationDialog(
                    "Forget Nightscout server?",
                    isPresented: $isShowingForgetNightscoutConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Forget server", role: .destructive) {
                        forgetNightscoutServer()
                    }
                    Button("Cancel", role: .cancel) {
                        pendingForgetNightscoutBaseURL = nil
                    }
                } message: {
                    Text(
                        "This discards \(unresolvedNightscoutItemCount) unresolved upload(s) or deletion(s) for this server. The URL, token, and enable setting remain saved."
                    )
                }
            } header: {
                Text("Nightscout")
            } footer: {
                Text("Developer preview. A configuration is saved only after a successful connection test. Glucose from direct-Bluetooth CGM providers is eligible; insulin upload is not wired yet.")
            }
            .task {
                loadNightscoutTokenIfNeeded()
            }
        }
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(
                    columns: [GridItem(spacing: 8), GridItem(spacing: 8)],
                    spacing: 12
                ) {
                    Button {
                        if let url = URL(string: "https://flwatch.app/") {
                            openURL(url)
                        }
                    } label: {
                        Text("Setup and usage guide")
                            .padding(2)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        isShowingSiriSheet.toggle()
                    } label: {
                        Text("Siri integration")
                            .padding(2)
                        //                            .frame(width: 140, height: 50)
                    }
                    .buttonStyle(.bordered)
                    .sheet(isPresented: $isShowingSiriSheet, content: {
                        PhoneAppSiriSheetView()
                    })
                    
                    Button {
                        if let url = URL(string: "https://github.com/poml88/FLwatch/issues") {
                            openURL(url)
                        }
                    } label: {
                        Text("Open issue on GitHub")
                            .padding(2)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        if let url = URL(string: "https://github.com/poml88/FLwatch/discussions") {
                            openURL(url)
                        }
                    } label: {
                        Text("Discussion forum")
                            .padding(2)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingMailView.toggle()
                    } label: {
                        Text("Send Email to Support")
                            .padding(2)
                        //                            .frame(width: 140, height: 50)
                    }
                    .buttonStyle(.bordered)

                    .disabled(!MailView.canSendMail())
                    .sheet(isPresented: $showingMailView) {
                        MailView(result: $mailResult)
                    }

                    // Setup walkthrough is Libre-specific; hide on Dexcom so we
                    // don't link users to a video that doesn't cover their flow.
                    if cgmProviderKind == .libreLinkUp {
                        Button {
                            if let url = URL(string: "https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB") {
                                openURL(url)
                            }
                        } label: {
                            Text("Setup video")
                                .padding(2)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("Support")
            }
            
            Section {
                Picker(
                    selection: Binding(
                        get: { cgmProviderKind },
                        set: { newValue in
                            guard newValue != cgmProviderKind else { return }
                            pendingProviderSwitch = newValue
                        }
                    )
                ) {
                    Text("FreeStyle Libre (LibreLinkUp)").tag(CGMProviderKind.libreLinkUp)
                    Text("Dexcom (Share)").tag(CGMProviderKind.dexcomShare)
                    Text("FreeStyle Libre 3 (Bluetooth)").tag(CGMProviderKind.libre3BLE)
                } label: {
                    Text("CGM provider")
                }
                .confirmationDialog(
                    "Switch CGM provider?",
                    isPresented: Binding(
                        get: { pendingProviderSwitch != nil },
                        set: { if !$0 { pendingProviderSwitch = nil } }
                    ),
                    titleVisibility: .visible,
                    presenting: pendingProviderSwitch
                ) { newKind in
                    Button("Switch", role: .destructive) {
                        applyProviderSwitch(to: newKind)
                    }
                    Button("Cancel", role: .cancel) {
                        pendingProviderSwitch = nil
                    }
                } message: { _ in
                    Text("Switching disconnects the current provider and clears its cached glucose readings in FLwatch on this device. Credentials for both providers stay saved, so switching back doesn't require re-entering them.")
                }
            } header: {
                Text("CGM Provider")
            } footer: {
                Text("Choose which CGM service FLwatch reads from.")
            }

            if cgmProviderKind == .dexcomShare {
                Section {
                    Picker("Sensor model", selection: $dexcomSensorType) {
                        ForEach(SensorType.dexcomSelectable, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }
                    .onChange(of: dexcomSensorType) { _, newValue in
                        _ = SensorSettingsStore.shared.updateSensorType(newValue)
                        watchConnector.sendSettingsSnapshotToWatch()
                    }

                    Picker("Glucose unit", selection: $manualUom) {
                        Text("mg/dL").tag(1)
                        Text("mmol/L").tag(0)
                    }
                    .onChange(of: manualUom) { _, _ in persistManualSensorSettings() }

                    Picker("Target low", selection: $manualTargetLow) {
                        ForEach(targetLowOptions, id: \.self) { value in
                            Text(value.asGlucose(glucoseUnit: GlucoseUnit(uom: manualUom), withUnit: true))
                                .tag(value)
                        }
                    }
                    .onChange(of: manualTargetLow) { _, _ in persistManualSensorSettings() }

                    Picker("Target high", selection: $manualTargetHigh) {
                        ForEach(targetHighOptions, id: \.self) { value in
                            Text(value.asGlucose(glucoseUnit: GlucoseUnit(uom: manualUom), withUnit: true))
                                .tag(value)
                        }
                    }
                    .onChange(of: manualTargetHigh) { _, _ in persistManualSensorSettings() }
                } header: {
                    Text("Dexcom Sensor Settings")
                } footer: {
                    Text("Dexcom Share doesn't send these settings, so set them here. Values are shown in the selected unit and used for the graph target range and reading colors.")
                }
            }

            // Like Dexcom Share, the Libre 3 direct stream carries no unit /
            // target / alarm preferences, so the user sets them here. Same
            // manual plumbing (`persistManualSensorSettings`). The red low-alarm
            // line is wired from the low-glucose alert level in the Notifications
            // section below; there's no sensor-model picker because the model is
            // detected on connect.
            if cgmProviderKind == .libre3BLE {
                Section {
                    Picker("Glucose unit", selection: $manualUom) {
                        Text("mg/dL").tag(1)
                        Text("mmol/L").tag(0)
                    }
                    .onChange(of: manualUom) { _, _ in persistManualSensorSettings() }

                    Picker("Target low", selection: $manualTargetLow) {
                        ForEach(targetLowOptions, id: \.self) { value in
                            Text(value.asGlucose(glucoseUnit: GlucoseUnit(uom: manualUom), withUnit: true))
                                .tag(value)
                        }
                    }
                    .onChange(of: manualTargetLow) { _, _ in persistManualSensorSettings() }

                    Picker("Target high", selection: $manualTargetHigh) {
                        ForEach(targetHighOptions, id: \.self) { value in
                            Text(value.asGlucose(glucoseUnit: GlucoseUnit(uom: manualUom), withUnit: true))
                                .tag(value)
                        }
                    }
                    .onChange(of: manualTargetHigh) { _, _ in persistManualSensorSettings() }
                } header: {
                    Text("Libre 3 Sensor Settings")
                } footer: {
                    Text("The direct Bluetooth connection doesn't carry these, so set them here. Values are shown in the selected unit and used for the graph target range and reading colors. The red low-alarm line follows your low-glucose alert level.")
                }
            }

            if cgmProviderKind == .libre3BLE && developerModeEnabled {
                Section {
                    Button {
                        isShowingCalibrationSheet = true
                    } label: {
                        HStack {
                            Label("Sensor calibration", systemImage: "plus.forwardslash.minus")
                            Spacer()
                            Text(formattedCalibrationOffset)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .sheet(isPresented: $isShowingCalibrationSheet) {
                        PhoneAppCalibrationView()
                    }
                } header: {
                    Text("Calibration")
                } footer: {
                    Text("Libre 3 and Libre 3 Plus sensors are factory calibrated and normally do not require calibration. Any FLwatch correction applies only to newly received readings.")
                }
            }

            Section {
                Toggle("Keep phone screen always on", isOn: $isScreenAlwaysOn)
                    .onChange(of: isScreenAlwaysOn) {
                        UIApplication.shared.isIdleTimerDisabled.toggle()
                    }

                Toggle(isOn: $useLiveActivities) {
                    Text("Enable Live Activities")
                    let systemLiveActivityEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
                    ? "System Live Activities: enabled"
                    : "System Live Activities: disabled in iOS settings"
                    Text("Updates of this live activity are not guaranteed. On my phone about every 8 minutes.\nTo enable or disable mirroring of the live activity to the Smart Stack of the Watch use the \"Watch\" app on the phone.\nLive Activity needs to be enabled in the app settings as well. Current status: \(systemLiveActivityEnabled)")
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 8)
                    Link("Tap to open app settings.", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                    .onChange(of: useLiveActivities) { _, newValue in
                        Task {
                            if newValue {
                                await LiveActivityManager.shared.refreshFromCurrentHistory(useLiveActivities: true)
                            } else {
                                await LiveActivityManager.shared.endAllActivities()
                            }
                        }
                    }
            } header: {
                Text("Settings")
            }

            Section {
                Toggle(
                    "Export glucose and insulin data to Apple Health",
                    isOn: Binding(
                        get: { appleHealthExportEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    let state = await AppleHealthExportManager.shared.requestWriteAuthorizationAndEnableExport()
                                    await MainActor.run {
                                        appleHealthAuthorizationState = state
                                        appleHealthExportEnabled = AppleHealthExportManager.shared.isExportEnabled
                                    }
                                }
                            } else {
                                AppleHealthExportManager.shared.disableExport()
                                appleHealthAuthorizationState = AppleHealthExportManager.shared.syncPreferenceWithAuthorization()
                                appleHealthExportEnabled = false
                            }
                        }
                    )
                )
                .disabled(appleHealthAuthorizationState == .unavailable)

                Text(appleHealthAuthorizationState.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if appleHealthAuthorizationState == .denied {
                    Link("Open app settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Permission is requested only when you turn this on. FLwatch exports insulin injections and glucose values, and tags samples with HealthKit sync identifiers to avoid duplicates.")
            }

            nightscoutSettingsSection

            // The Bluetooth heartbeat — and the glucose alerts that ride on it
            // (now in the Alerts tab) — applies only to the cloud providers:
            // there FLwatch relies on the vendor app for primary alarms, and the
            // heartbeat merely schedules cloud polls. In direct-BLE mode there's
            // no vendor app to alarm and nothing to poll, so the whole section is
            // hidden. BLE gets its own purpose-built alarms for the push model.
            if cgmProviderKind != .libre3BLE {
            Section {
                Toggle(
                    "Enable Bluetooth heartbeat",
                    isOn: Binding(
                        get: { bluetoothHeartbeatManager.isEnabled },
                        set: {
                            bluetoothHeartbeatManager.setEnabled($0)
                            guard !$0 else { return }
                            if lowGlucoseNotificationsEnabled {
                                lowGlucoseNotificationsEnabled = false
                                disableGlucoseAlerts(.low)
                            }
                            if highGlucoseNotificationsEnabled {
                                highGlucoseNotificationsEnabled = false
                                disableGlucoseAlerts(.high)
                            }
                        }
                    )
                )

                Text("To discover your sensor transmitter, first fully close the LibreLink or Libre 3 app. After the transmitter connects in FLwatch, you can open the app again.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)

                HStack {
                    Button(bluetoothHeartbeatActionTitle) {
                        if bluetoothHeartbeatManager.isScanning {
                            bluetoothHeartbeatManager.stopScanning()
                        } else {
                            bluetoothHeartbeatManager.startScanning()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!bluetoothHeartbeatManager.isEnabled)

                    if !bluetoothHeartbeatManager.selectedDeviceName.isEmpty {
                        Button("Clear device") {
                            bluetoothHeartbeatManager.clearSelection()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!bluetoothHeartbeatManager.isEnabled)
                    }
                }

                Text("Status: \(bluetoothHeartbeatStatusText)")

                if !bluetoothHeartbeatManager.selectedDeviceName.isEmpty {
                    Text("Selected device: \(bluetoothHeartbeatManager.selectedDeviceName)")
                }

                if !bluetoothHeartbeatManager.selectedPeripheralUUID.isEmpty {
                    Text("Peripheral UUID: \(bluetoothHeartbeatManager.selectedPeripheralUUID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastHeartbeatDate = bluetoothHeartbeatManager.lastHeartbeatDate {
                    Text("Last heartbeat: \(lastHeartbeatDate.formatted(date: .abbreviated, time: .standard))")
                }

                if bluetoothHeartbeatManager.discoveredDevices.isEmpty {
                    Text("No matching nearby devices found yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bluetoothHeartbeatManager.discoveredDevices) { device in
                        Button {
                            bluetoothHeartbeatManager.selectDevice(device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                    Text("RSSI \(device.rssi) • \(device.lastSeen.formatted(date: .omitted, time: .standard))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if device.id.uuidString == bluetoothHeartbeatManager.selectedPeripheralUUID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(!bluetoothHeartbeatManager.isEnabled)
                    }
                }
            } header: {
                Text("Bluetooth heartbeat")
            } footer: {
                Text("FLwatch scans for devices nearby, reconnects to the selected device, and uses that Bluetooth activity to refresh glucose data, widgets, Live Activities, and background updates. Only nearby discoverable Bluetooth devices can appear here. This mode has very little impact on the battery.")
            }
            } // end `if cgmProviderKind != .libre3BLE` — heartbeat section hidden in BLE mode

            Section {
                Toggle(isOn: $tapComplicationReloads) {
                    Text("Tap on circular watch complication: updates glucose value")
                    Text("Default behaviour: opens FLwatch app. Only watchOS 11 and later.")
                }
                .onChange(of: tapComplicationReloads) { oldValue, newValue in
                    let messageToWatch: [String: Any] = ["content": "tapComplicationReloadsMessage",
                                                         "tapComplicationReloads": newValue]
                    sendMessagetoOther(message: messageToWatch)
                }
                
                Picker(selection: $widgetUpdateFrequency) {
                    ForEach(updateFrequencyOptions, id: \.self) {
                        Text("\($0) min")
                    }
                } label: {
                    Text("Widget update frequency")
                    Text("The default is 5 mins. Note that the OS allows about 40 to 70 widget (complication) updates max per 24 hours. When this budget is finished, no more updates.")
                }
                .onChange(of: widgetUpdateFrequency) {  // simplified version when only the new value is needed
                    //                .onChange(of: widgetUpdateFrequency, initial: false) { oldValue, newValue in // initial defaults to false and can be also left out; initial means weather the action should be run wehen this view initially appears
                    let messageToWatch: [String: Any] = ["content": "updateWidgetUpdateFrequency",
                                                         "widgetUpdateFrequency": widgetUpdateFrequency]
                    sendMessagetoOther(message: messageToWatch)
                }
            } header: {
                Text("Widgets / Complications")
            }
            
            Section {
                Picker(selection: $insulinTypeSelected) {
                    ForEach(InsulinType.allCases, id: \.self) {
                        Text($0.description)
                    }
                } label: {
                    Text("Bolus insulin")
                }
                //                .labelsHidden()
                //                                    .pickerStyle(.navigationLink)
                .onChange(of: insulinTypeSelected) {oldValue, newValue in
                    UserDefaults.group.insulinTypeSelected = newValue
                    let messageToWatch: [String: Any] = ["content": "updateInsulinTypeSelected",
                                                         "insulinTypeSelected": newValue.rawValue]
                    sendMessagetoOther(message: messageToWatch)
                }
            } header: {
                                Text("Insulin type")
            } footer: {
                Text("Select the bolus insulin for the IOB calculations. Currently supported are:\n- Rapid acting (Novolog, Novorapid, ... (peak activity 75 mins))\n- Fast rapid acting (Fiasp, Lyumjev, ... (peak activity 55 mins))")
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Section {
                Toggle("Phone: show insulin delivery marks", isOn: $showInsulinDeliveryMarksPhone)
                    .onChange(of: showInsulinDeliveryMarksPhone) {
                    }
                
                Toggle("Phone: show IOB graph", isOn: $showIOBCurvePhone)
                    .onChange(of: showIOBCurvePhone) {
                    }
                
                Toggle("Phone: show insulin activity graph", isOn: $showActivityCurvePhone)
                    .onChange(of: showActivityCurvePhone) {
                    }
                
                Toggle("Watch: show insulin delivery marks", isOn: $showInsulinDeliveryMarksWatch)
                    .onChange(of: showInsulinDeliveryMarksWatch) { oldValue, newValue in
                        let messageToWatch: [String: Any] = ["content": "showInsulinDeliveryMarksWatchMessage",
                                                             "showInsulinDeliveryMarksWatch": newValue]
                        sendMessagetoOther(message: messageToWatch)
                    }
                
                Toggle("Watch: show IOB graph", isOn: $showIOBCurveWatch)
                    .onChange(of: showIOBCurveWatch) { oldValue, newValue in
                        let messageToWatch: [String: Any] = ["content": "showIOBCurveWatchMessage",
                                                             "showIOBCurveWatch": newValue]
                        sendMessagetoOther(message: messageToWatch)
                    }
                
                Toggle("Watch: show insulin activity graph", isOn: $showActivityCurveWatch)
                    .onChange(of: showActivityCurveWatch) { oldValue, newValue in
                        let messageToWatch: [String: Any] = ["content": "showActivityCurveWatchMessage",
                                                             "showActivityCurveWatch": newValue]
                        sendMessagetoOther(message: messageToWatch)
                    }
            } header: {
                Text("Insulin marks and graphs")
            }
            
            
            Section {
                Button("Re-send all settings to watch") {
                    watchConnector.sendSettingsSnapshotToWatch()
                }
            } header: {
                Text("Watch Settings")
            } footer: {
                Text("Use this if the watch app was reinstalled or its settings appear out of sync.")
            }

            Section {
                
                
                let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
                Text("V\(versionNumber).\(buildNumber)")
                    // Seven taps reveal the code prompt for this device-local
                    // gate, or disable it when already active. Future
                    // developer-only UI can use the same flag.
                    .onTapGesture(count: 7) {
                        enteredDeveloperCode = ""
                        if developerModeEnabled {
                            developerModeEnabled = false
                            developerAlertRequiresCode = false
                        } else {
                            developerAlertRequiresCode = true
                        }
                        isShowingDeveloperAlert = true
                    }
                    .alert(
                        developerAlertRequiresCode ? "Developer Access" : "Developer Mode",
                        isPresented: $isShowingDeveloperAlert
                    ) {
                        if developerAlertRequiresCode {
                            SecureField("Code", text: $enteredDeveloperCode)
                            Button("Cancel", role: .cancel) {
                                enteredDeveloperCode = ""
                            }
                            Button("Unlock") {
                                developerModeEnabled = enteredDeveloperCode == "1234"
                                enteredDeveloperCode = ""
                            }
                        } else {
                            Button("OK") { }
                        }
                    } message: {
                        Text(
                            developerAlertRequiresCode
                                ? "Enter the developer code."
                                : "Developer mode is now off."
                        )
                    }
                
                let systemVersion = UIDevice.current.systemVersion
                let systemName = UIDevice.current.systemName
                //                let model = UIDevice.current.model
                let name = UIDevice.current.name
                Text("\(systemName) \(systemVersion) on \(name)")
                
                Text(verbatim: "CGM Provider: \(cgmProviderKind.displayName)")

                Text(verbatim: "Sensor: \(SensorSettingsStore.shared.sensorType)")
                
                Text("Error message: \(DebugMessageSingleton.shared.libreLinkUpResponseError)")
                
                if developerModeEnabled {
                    Text("BG task executions last 12 hours (total): \(bgAppRefreshExecutionTimestamps.count)")
                    ForEach(Array(bgAppRefreshExecutionTimestamps.enumerated()), id: \.offset) { _, timestamp in
                        Text(timestamp.formatted(date: .abbreviated, time: .standard))
                    }
                }
            }
            header: {
                Text("Debug Info")

            }
        }
        .onAppear {
            refreshAppleHealthStatus()
            bluetoothHeartbeatManager.startIfNeeded()
        }

    }
    func sendMessagetoOther(message: [String: Any]) {
        watchConnector.sendMessageToPairedDevice(message)
    }

    private func loadNightscoutTokenIfNeeded() {
        guard !hasLoadedNightscoutToken else { return }
        do {
            if let embeddedToken = embeddedNightscoutToken(in: nightscoutURL) {
                nightscoutAccessToken = embeddedToken
            } else {
                nightscoutAccessToken = try NightscoutSecretKeychain.read() ?? ""
            }
            hasLoadedNightscoutToken = true
        } catch {
            nightscoutSettingsStatus = .failure(
                String(localized: "The Nightscout token could not be read from secure storage.")
            )
        }
    }

    private func embeddedNightscoutToken(in rawValue: String) -> String? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmedValue),
              let token = components.queryItems?
                .first(where: { $0.name.caseInsensitiveCompare("token") == .orderedSame })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private func testNightscoutConnection(enableAfterSuccess: Bool = false) {
        guard let configuration = validatedNightscoutDraft() else {
            if enableAfterSuccess {
                nightscoutUploadEnabled = false
            }
            return
        }
        nightscoutSettingsStatus = nil
        isTestingNightscoutConnection = true

        Task { @MainActor in
            let result = await NightscoutUploadManager.shared.testConnection(
                baseURLString: configuration.baseURL.absoluteString,
                accessToken: configuration.accessToken
            )
            isTestingNightscoutConnection = false
            guard normalizedNightscoutURL == configuration.baseURL.absoluteString,
                  nightscoutAccessToken.trimmingCharacters(in: .whitespacesAndNewlines) == configuration.accessToken else {
                return
            }
            switch result {
            case .ok:
                guard persistNightscoutConfiguration(configuration) else {
                    if enableAfterSuccess {
                        nightscoutUploadEnabled = false
                    }
                    return
                }
                if enableAfterSuccess {
                    nightscoutUploadEnabled = true
                    // Enabling while the scene is already active does not
                    // produce a lifecycle transition, so explicitly seed the
                    // server with the complete retained glucose and insulin windows.
                    Task { @MainActor in
                        await NightscoutUploadManager.shared.reconcileRetainedDataAndWait()
                    }
                }
                nightscoutSettingsStatus = .success(
                    String(localized: "Connection successful. The token grants all required write permissions.")
                )
            case .unreachable:
                if enableAfterSuccess {
                    nightscoutUploadEnabled = false
                }
                nightscoutSettingsStatus = .failure(
                    String(localized: "Nightscout is unavailable. The saved upload configuration was not changed.")
                )
            case .notV3Server:
                if enableAfterSuccess {
                    nightscoutUploadEnabled = false
                }
                nightscoutSettingsStatus = .failure(
                    String(localized: "No compatible Nightscout API v3 endpoint was found. The saved upload configuration was not changed.")
                )
            case .tokenLacksWrites:
                if enableAfterSuccess {
                    nightscoutUploadEnabled = false
                }
                nightscoutSettingsStatus = .failure(
                    String(localized: "The token lacks the required write permissions. The saved upload configuration was not changed.")
                )
            }
        }
    }

    private func validatedNightscoutDraft() -> NightscoutDraftConfiguration? {
        let trimmedToken = nightscoutAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = try? NightscoutBaseURL(normalizing: nightscoutURL) else {
            nightscoutSettingsStatus = .failure(
                String(localized: "Enter a valid HTTPS Nightscout server URL.")
            )
            return nil
        }
        guard !trimmedToken.isEmpty else {
            nightscoutSettingsStatus = .failure(
                String(localized: "Enter a Nightscout admin access token.")
            )
            return nil
        }

        return (baseURL, trimmedToken)
    }

    private func persistNightscoutConfiguration(
        _ configuration: NightscoutDraftConfiguration
    ) -> Bool {
        do {
            try NightscoutSecretKeychain.save(configuration.accessToken)
        } catch {
            nightscoutSettingsStatus = .failure(
                String(localized: "The Nightscout token could not be saved securely.")
            )
            return false
        }

        SharedData.nightscoutURL = configuration.baseURL.absoluteString
        nightscoutURL = configuration.baseURL.absoluteString
        nightscoutAccessToken = configuration.accessToken
        return true
    }

    private func prepareToForgetNightscoutServer() {
        guard let baseURL = try? NightscoutBaseURL(normalizing: nightscoutURL) else {
            nightscoutSettingsStatus = .failure(
                String(localized: "Enter a valid HTTPS Nightscout server URL first.")
            )
            return
        }
        do {
            unresolvedNightscoutItemCount = try NightscoutUploadManager.shared.unresolvedCount(
                baseURLString: baseURL.absoluteString
            )
        } catch {
            pendingForgetNightscoutBaseURL = nil
            nightscoutSettingsStatus = .failure(
                String(localized: "Nightscout upload state could not be read, so nothing was discarded.")
            )
            return
        }
        pendingForgetNightscoutBaseURL = baseURL.absoluteString
        isShowingForgetNightscoutConfirmation = true
    }

    private func forgetNightscoutServer() {
        guard let baseURLString = pendingForgetNightscoutBaseURL else { return }
        pendingForgetNightscoutBaseURL = nil
        do {
            let discardedCount = try NightscoutUploadManager.shared.forgetServer(
                baseURLString: baseURLString
            )
            nightscoutSettingsStatus = .success(
                String(localized: "Forgot Nightscout upload state for \(discardedCount) unresolved item(s).")
            )
        } catch {
            nightscoutSettingsStatus = .failure(
                String(localized: "Nightscout upload state could not be removed.")
            )
        }
    }

    /// Persists the manually-entered sensor settings (stored in mg/dL) and
    /// mirrors them to the watch. Shared by the providers that carry no settings
    /// of their own — Dexcom Share and Libre 3 direct BLE. Coloring runs off the
    /// target range; the red alarm line tracks the low-glucose notification
    /// threshold when alerts are enabled, otherwise it stays hidden at the
    /// sentinel.
    private func persistManualSensorSettings() {
        let alarms = SensorSettings.manualAlarms(
            notificationsEnabled: lowGlucoseNotificationsEnabled,
            threshold: lowGlucoseNotificationThreshold
        )
        let updated = SensorSettings(
            uom: manualUom,
            targetLow: manualTargetLow,
            targetHigh: manualTargetHigh,
            alarmLow: alarms.low,
            alarmHigh: alarms.high
        )
        SensorSettingsStore.shared.updateSensorSettings(updated)
        watchConnector.sendSettingsSnapshotToWatch()
    }

    /// Decision 7.1: switching providers triggers a disconnect. Both providers'
    /// credentials stay in place per decision 7.2.
    private func applyProviderSwitch(to newKind: CGMProviderKind) {
        pendingProviderSwitch = nil
        LibreLinkUpService.shared.switchProvider(to: newKind)
        cgmProviderKindRaw = newKind.rawValue
        // `switchProvider` may have replaced a stale sensor type — sync the
        // picker @State so it reflects what's now persisted.
        let resolved = SensorSettingsStore.shared.sensorType
        dexcomSensorType = resolved.isADexcom ? resolved : .dexcomG7
        // Mirror the change to the watch so its stale window and cadence
        // follow without waiting for the next settings sync.
        watchConnector.sendSettingsSnapshotToWatch()
        Task {
            await LowGlucoseNotificationManager.shared.providerDidChange()
        }
    }

    private func refreshAppleHealthStatus() {
        appleHealthAuthorizationState = AppleHealthExportManager.shared.syncPreferenceWithAuthorization()
        appleHealthExportEnabled = AppleHealthExportManager.shared.isExportEnabled
    }

    private var formattedCalibrationOffset: String {
        let glucoseUnit = GlucoseUnit(uom: manualUom)
        let magnitude = abs(libre3CalibrationOffsetMgDL).asGlucose(glucoseUnit: glucoseUnit)
        let sign = libre3CalibrationOffsetMgDL > 0 ? "+" : libre3CalibrationOffsetMgDL < 0 ? "−" : ""
        return "\(sign)\(magnitude) \(glucoseUnit.description)"
    }

    
}

#Preview {
    PhoneAppSettingsView()
}
