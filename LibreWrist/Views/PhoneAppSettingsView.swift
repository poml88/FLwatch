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
    
    @Environment(\.openURL) private var openURL
    
    @AppStorage(DefaultsKey.showInsulinDeliveryMarksPhone.rawValue, store: UserDefaults.group) private var showInsulinDeliveryMarksPhone: Bool = false
    @AppStorage(DefaultsKey.showInsulinDeliveryMarksWatch.rawValue, store: UserDefaults.group) private var showInsulinDeliveryMarksWatch: Bool = false
    @AppStorage(DefaultsKey.showIOBCurvePhone.rawValue, store: UserDefaults.group) private var showIOBCurvePhone: Bool = false
    @AppStorage(DefaultsKey.showIOBCurveWatch.rawValue, store: UserDefaults.group) private var showIOBCurveWatch: Bool = false
    @AppStorage(DefaultsKey.showActivityCurvePhone.rawValue, store: UserDefaults.group) private var showActivityCurvePhone: Bool = false
    @AppStorage(DefaultsKey.showActivityCurveWatch.rawValue, store: UserDefaults.group) private var showActivityCurveWatch: Bool = false
    @AppStorage(DefaultsKey.widgetUpdateFrequency.rawValue, store: UserDefaults.group) private var widgetUpdateFrequency: Int = 5
    @AppStorage(DefaultsKey.tapComplicationReloads.rawValue, store: UserDefaults.group) private var tapComplicationReloads: Bool = false
    @AppStorage(DefaultsKey.useLiveActivities.rawValue, store: UserDefaults.group) private var useLiveActivities: Bool = true
    
    
    @State private var isScreenAlwaysOn = false
    @State private var showingMailView = false
    @State private var isShowingSiriSheet = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var insulinTypeSelected: InsulinType = UserDefaults.group.insulinTypeSelected
    @State private var appleHealthExportEnabled = AppleHealthExportManager.shared.isExportEnabled
    @State private var appleHealthAuthorizationState = AppleHealthExportManager.shared.syncPreferenceWithAuthorization()
    private var watchConnector = WatchConnectivityManager.shared
    let updateFrequencyOptions: [Int] = [1, 5, 10, 15, 20]
    private var bgAppRefreshExecutionTimestamps: [Date] {
        (UserDefaults.group.array(forKey: "bgAppRefreshExecutionTimestamps") as? [TimeInterval] ?? [])
            .map(Date.init(timeIntervalSince1970:))
    }
    
    var body: some View {
        Form {
            Section {
                LazyVGrid(
                    columns: [GridItem(spacing: 8), GridItem(spacing: 8)],
                    spacing: 12
                ) {
                    Button {
                        if let url = URL(string: "https://poml88.github.io/FLwatch/") {
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
                }
            } header: {
                Text("Support")
            }
            
            Section {
                Toggle("Keep phone screen always on", isOn: $isScreenAlwaysOn)
                    .onChange(of: isScreenAlwaysOn) {
                        print("yes")
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
            
            
            
            Section {
                Toggle(isOn: $tapComplicationReloads) {
                    Text("Tap on circular watch complication: updates glucose value")
                    Text("Default behaviour: opens FLwatch app. Only watchOS 11 and later.")
                }
                .onChange(of: tapComplicationReloads) { oldValue, newValue in
                    print("yes")
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
                        print("yes")
                    }
                
                Toggle("Phone: show IOB graph", isOn: $showIOBCurvePhone)
                    .onChange(of: showIOBCurvePhone) {
                        print("yes")
                    }
                
                Toggle("Phone: show insulin activity graph", isOn: $showActivityCurvePhone)
                    .onChange(of: showActivityCurvePhone) {
                        print("yes")
                    }
                
                Toggle("Watch: show insulin delivery marks", isOn: $showInsulinDeliveryMarksWatch)
                    .onChange(of: showInsulinDeliveryMarksWatch) { oldValue, newValue in
                        print("yes")
                        let messageToWatch: [String: Any] = ["content": "showInsulinDeliveryMarksWatchMessage",
                                                             "showInsulinDeliveryMarksWatch": newValue]
                        sendMessagetoOther(message: messageToWatch)
                    }
                
                Toggle("Watch: show IOB graph", isOn: $showIOBCurveWatch)
                    .onChange(of: showIOBCurveWatch) { oldValue, newValue in
                        print("yes")
                        let messageToWatch: [String: Any] = ["content": "showIOBCurveWatchMessage",
                                                             "showIOBCurveWatch": newValue]
                        sendMessagetoOther(message: messageToWatch)
                    }
                
                Toggle("Watch: show insulin activity graph", isOn: $showActivityCurveWatch)
                    .onChange(of: showActivityCurveWatch) { oldValue, newValue in
                        print("yes")
                        let messageToWatch: [String: Any] = ["content": "showActivityCurveWatchMessage",
                                                             "showActivityCurveWatch": newValue]
                        sendMessagetoOther(message: messageToWatch)
                    }
            } header: {
                Text("Insulin marks and graphs")
            }
            
            
            Section {
                
                
                let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
                Text("V\(versionNumber).\(buildNumber)")
                
                let systemVersion = UIDevice.current.systemVersion
                let systemName = UIDevice.current.systemName
                //                let model = UIDevice.current.model
                let name = UIDevice.current.name
                Text("\(systemName) \(systemVersion) on \(name)")
                
                Text(verbatim: "Sensor: \(SensorSettingsStore.shared.sensorType)")
                
                Text("Error message: \(DebugMessageSingleton.shared.libreLinkUpResponseError)")
                
                if UserDefaults.group.username == "librewidget@cmdline.net" {
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
        }
        
    }
    func sendMessagetoOther(message: [String: Any]) {
        watchConnector.sendMessageToPairedDevice(message)
    }

    private func refreshAppleHealthStatus() {
        appleHealthAuthorizationState = AppleHealthExportManager.shared.syncPreferenceWithAuthorization()
        appleHealthExportEnabled = AppleHealthExportManager.shared.isExportEnabled
    }
    
}

#Preview {
    PhoneAppSettingsView()
}
