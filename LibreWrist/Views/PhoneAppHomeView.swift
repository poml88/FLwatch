//
//  PhoneAppHomeView.swift
//  LibreWrist
//
//  Created by Peter Müller on 31.07.24.
//

import SwiftUI
import OSLog
import Charts
import WidgetKit
import StoreKit


struct PhoneAppHomeView: View {
    
    
    
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
//    @Environment(History.self) var history: History
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
//    @Environment(\.sensorSettingsSingleton) var sensorSettingsSingleton
    @Environment(\.currentIOBSingleton) var currentIOBSingleton
//    @Environment(\.insulinDeliveryHistorySingleton) var insulinDeliveryHistorySingleton
    @Environment(\.requestReview) private var requestReview
    

    @AppStorage(DefaultsKey.hasDeclinedReview.rawValue, store: UserDefaults.group) private var hasDeclinedReview = false
    @AppStorage(DefaultsKey.lastReviewPromptDate.rawValue, store: UserDefaults.group) private var lastReviewPromptDate: Double = 0
//    @AppStorage(DefaultsKey.usedDays.rawValue, store: UserDefaults.group) private var usedDays: [String] = []
    @AppStorage(DefaultsKey.hasPromptedOnce.rawValue, store: UserDefaults.group) private var hasPromptedOnce = false
    @AppStorage(DefaultsKey.hasAgreedToReview.rawValue, store: UserDefaults.group) private var hasAgreedToReview = false
    @AppStorage(DefaultsKey.useLiveActivities.rawValue, store: UserDefaults.group) private var useLiveActivities = true
    
    
    
//    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    @State private var minutesSinceLastReading: Int = 999
//    @State private var libreLinkUpResponse: String = "[...]"
//    @State private var libreLinkUpHistory = LibreLinkUpHistory.mock
//    @State private var libreLinkUpLogbookHistory: [LibreLinkUpGlucose] = []
//    @State private var isReloading: Bool = false
    @State private var isShowingDisclaimer = false
    @State private var isShowingWelcomeMessage = false
    @State private var isShowingNotification = false
    @State private var isShowingInsulinDeliverySheet = false
//    @State private var currentIOB: Double = 0.0
//    @State private var scrollPosition: Date = Date.now
//    @State private var sensorSettings = SensorSettings()
    @State private var connected = UserDefaults.group.connected
    @State private var isShowingReloadFailed = false
    @State private var onAppearNotToDoFirstStart: Bool = true
    @State private var scenePhaseNotToDoFirstStart: Bool = true
    @State private var showPrompt = false
    
//    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
//    @State var currentGlucose: Int = 0
//    @State var trendArrow = "---"
    
    private let promptInterval: TimeInterval = 30 * 24 * 60 * 60
    private let safeRange: ClosedRange<Int> = 70...180
    private let allowedHours = 0...24
    private let minimumDaysOfUse = 10
    private let defaultOverlayConnectionMessage = String(localized: "Check that Libre app is running.")
    
//    private let libreLinkUp = LibreLinkUp()
    @StateObject private var lluService = LibreLinkUpService.shared
     
    private static let foregroundReloadInterval: TimeInterval = 63
    private let timer = Timer.publish(every: Self.foregroundReloadInterval, tolerance: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            if colorScheme == .dark {
                GlucoseValueView(libreLinkUpHistory: libreLinkUpHistory, foregroundStyleColor: libreLinkUpHistory.libreLinkUpGlucose[0].color.color, isShowingInsulinDeliverySheet: $isShowingInsulinDeliverySheet, currentIOBSingleton: currentIOBSingleton)
            } else {
                GlucoseValueView(libreLinkUpHistory: libreLinkUpHistory, foregroundStyleColor: Color.primary, isShowingInsulinDeliverySheet: $isShowingInsulinDeliverySheet, currentIOBSingleton: currentIOBSingleton)
                .background(Color(libreLinkUpHistory.libreLinkUpGlucose[0].color.color))
//                .frame(maxWidth: .infinity)
                .cornerRadius(30)
//                .safeAreaPadding(.top)
                
            }
            
            
            if libreLinkUpHistory.libreLinkUpGlucose.count > 0 {
                PhoneAppGraphView()
            }
            
        }
        .alert ("Warning", isPresented: $isShowingDisclaimer) {
            Button("Accept", role: .cancel, action: {SharedData.hasSeenDisclaimer = true})
        }
        message: {
            Text("!! Not for treatment decisions !!\n\nUse at your own risk!\n\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.")
        }
        
        .alert ("Welcome", isPresented: $isShowingWelcomeMessage) {
            Button("Start", role: .cancel, action: {SharedData.hasSeenWelcomeMessage = true})
        }
        message: {
            Text("Thank you for downloading FLwatch. I hope it will prove useful.\n\nTo get startet, please read the SETUP AND USAGE guide. In case of questions, please contact support. More info on the Settings tab.")
        }
        
        .alert ("Update note", isPresented: $isShowingNotification) {
            Button("Understood", role: .cancel, action: {SharedData.hasSeenNotification = true})
        }
        message: {
            Text("Please reboot phone and watch once if widgets do not work!")
        }
        
        .alert ("Warning", isPresented: $isShowingReloadFailed) {
            //            Button("Accept", role: .cancel, action: {settings.hasSeenDisclaimer = true})
        }
        message: {
            Text(lluService.libreLinkUpResponse)
        }
        
        .alert("Enjoying FLwatch?", isPresented: $showPrompt) {
            Button("Yes, rate now") {
                requestReview()
                lastReviewPromptDate = Date().timeIntervalSince1970
                hasPromptedOnce = true
                hasAgreedToReview = true
            }
            Button("Maybe later", role: .cancel) {
                lastReviewPromptDate = Date().timeIntervalSince1970
                hasPromptedOnce = true
            }
            Button("Not happy? Suggestions?") {
                openSupportEmail()
                hasPromptedOnce = true
                lastReviewPromptDate = Date().timeIntervalSince1970
//                hasDeclinedReview = true // optional: don’t ask again
            }
            Button("No thanks", role: .destructive) {
                hasDeclinedReview = true
            }
        } message: {
            Text("Your feedback helps us improve and makes it easier for others with diabetes to discover the app. And it motivates to continue the work. 😊\nWould you like to leave a quick review?")
        }
        
        .onReceive(timer) { time in
            print("Timer") // Timer fires as well when on a different tab, for example settings tab
            

            
//                scrollPosition = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date.now

            
            reloadAndUpdateMinutes(refreshLiveActivity: true, trigger: "timer")
        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
//            settings.hasSeenDisclaimer = false
//            settings.hasSeenWelcomeMessage = false
            
            if SharedData.hasSeenWelcomeMessage == false {
                isShowingWelcomeMessage = true
            }
            
            if SharedData.hasSeenDisclaimer == false {
                isShowingDisclaimer = true
            }
            
            
            
//            Uncomment to show a notification at app start
//            Increase counter in Settings (hasSeenNotification000)
//            if settings.hasSeenNotification == false {
//                isShowingNotification = true
//            }
            
            //MARK: Skip the following on app start
            if onAppearNotToDoFirstStart == false { // not to do on first start
                
                reloadAndUpdateMinutes(trigger: ".onAppear")
                
                if shouldShowPrompt {
                    showPrompt = true
                }
            }
            // -------------------------------------
            
            //MARK: Do the following only on app start
            if onAppearNotToDoFirstStart == true { // to do only on first start
                
                calculateUserdefaultsSize()
                
                FLwatchShortcuts.updateAppShortcutParameters() // this was in the app init first, but it seems this was too early... So I moved it here.

                LiveActivityManager.shared.startIfAllowed(useLiveActivities: useLiveActivities)
                onAppearNotToDoFirstStart = false
            }
            
            if !hasPromptedOnce {
                recordDayOfUse()
            }
            // ----------------------------------------
            
            //MARK: Do the following .onAppear

            
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("Scene Phase Active")

//                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                
                //MARK: Skip the following on app start
                if scenePhaseNotToDoFirstStart == false { // not to do on first start
                    WidgetCenter.shared.reloadAllTimelines()
                    print("WidgetCenter.shared.reloadAllTimelines()")
                }
                
                //MARK: Do the following only on app start
                if scenePhaseNotToDoFirstStart == true { scenePhaseNotToDoFirstStart = false } // to do only on first start
                
                //MARK: Do the following .onChange(of: scenePhase) == .active
                reloadAndUpdateMinutes(
                    refreshLiveActivity: true,
                    trigger: "scenePhase.active",
                    liveActivityRestartThreshold: LiveActivityManager.shared.foregroundRestartAgeThreshold
                )

                
            } else if newPhase == .inactive {
                print("Scene Phase Inactive")
            } else if newPhase == .background {
                print("Scene Phase Background")
            }
        }
        .overlay {
            if lluService.isReloading == true {
                ZStack {
                    Color(white: 0, opacity: 0.25)
                        .cornerRadius(10)
                    ProgressView().tint(.white)
                }
            }
            
            let minutesSinceLastReadingOverlay = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            if minutesSinceLastReadingOverlay >= 3 && lluService.isReloading == false {
                ZStack {
                    Color(white: 0, opacity: 0.5)
                        .cornerRadius(10)
                    VStack {
                        Image(systemName: "hourglass.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100)
                            .padding()
                        
                        Text("No data received since \(minutesSinceLastReading) min.\n\n\(overlayConnectionMessage)")
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .background()
                    .cornerRadius(10)
                    .opacity(0.5)
                    .padding()
                }
//                .ignoresSafeArea()
                .allowsHitTesting(false) // passes taps/clicks through to the bottom layer
                // in this case the IOB button
            }
        }
    }
    
    private var shouldShowPrompt: Bool {
        guard !hasDeclinedReview else { return false }
        
        guard !hasAgreedToReview else { return false }
        
        let now = Date()
        let secondsSinceLast = now.timeIntervalSince1970 - lastReviewPromptDate
        
        guard secondsSinceLast > promptInterval else { return false }
        
        let hour = Calendar.current.component(.hour, from: now)
        guard allowedHours.contains(hour) else { return false }
        
        let glucose = libreLinkUpHistory.currentGlucose //always in mg/dl
        guard safeRange.contains(glucose) else { return false }
        
        if !hasPromptedOnce {
            let usedDays: [String] = SharedData.usedDays
            guard usedDays.count >= minimumDaysOfUse else { return false }
        } else {
            SharedData.usedDays.removeAll()
        }
        
        return true
    }

    private var overlayConnectionMessage: String {
        let localizedNetworkError = DebugMessageSingleton.shared.libreLinkUpOverlayError.trimmingCharacters(in: .whitespacesAndNewlines)
        return localizedNetworkError.isEmpty ? defaultOverlayConnectionMessage : localizedNetworkError
    }

    private var shouldShowReloadFailedAlert: Bool {
        guard lluService.didLastReloadFail else { return false }
        guard DebugMessageSingleton.shared.libreLinkUpOverlayError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return lluService.libreLinkUpResponse != LibreLinkUpError.noConnectionGraph.localizedDescription
    }
    
    private func recordDayOfUse() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        var usedDays: [String] = SharedData.usedDays
        if !usedDays.contains(todayString) {
            usedDays.append(todayString)
   //         usedDays.append("2025-10-10") // for testing purposes
            SharedData.usedDays = usedDays
        }
    }
    
    private func openSupportEmail() {
        let to = "flwatch@cmdline.net"
        let subject = "FLwatch Feedback"
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let systemVersion = UIDevice.current.systemVersion
        let systemName = UIDevice.current.systemName
//        let model = UIDevice.current.model
        let name = UIDevice.current.name
        
        let sensorType = SensorSettingsStore.shared.sensorType.description
        
        let libreLinkUpDebug = DebugMessageSingleton.shared.libreLinkUpResponseError
        
        let messageBody: LocalizedStringResource = "Hello,\n\n*** write your message here ***\n\n\n\nKind regards\n\n\n\n--\nDebug info:\nApp Version: \(versionNumber) Build: \(buildNumber)\nDevice Info: \(systemName) \(systemVersion) on \(name)\nSensor: \(sensorType)\nError Message: \(libreLinkUpDebug)\n\n"
        let messageBodyString: String = String(localized: messageBody)
        
        // Build the URL components safely
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = to
        comps.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: messageBodyString)
        ]
        
        guard let url = comps.url else { return }
        UIApplication.shared.open(url)
    }
    
    private func calculateUserdefaultsSize() {
        let defaults = UserDefaults.standard
        let dict = defaults.dictionaryRepresentation()
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict,
                                                          format: .binary,
                                                          options: 0)
            print("UserDefaults size: \(data.count) bytes")
        } catch {
            print("Error serializing UserDefaults: \(error)")
        }

    }
   
    private func reloadAndUpdateMinutes(
        refreshLiveActivity: Bool = false,
        trigger: String,
        liveActivityRestartThreshold: TimeInterval? = nil
    ) {
        print("reloadAndUpdateMinutes() [\(trigger)]")
        Task {
            await lluService.requestReloadIfNeeded()
            if refreshLiveActivity {
                await LiveActivityManager.shared.refreshFromCurrentHistory(
                    useLiveActivities: useLiveActivities,
                    reloadFailed: lluService.didLastReloadFail,
                    restartIfOlderThan: liveActivityRestartThreshold,
                    refreshIOB: false
                )
            }
            isShowingReloadFailed = shouldShowReloadFailedAlert
            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
        }
    }
    
    
}

struct GlucoseValueView: View {
    var libreLinkUpHistory: LibreLinkUpHistory
    var foregroundStyleColor: Color
    @Binding var isShowingInsulinDeliverySheet: Bool
    var currentIOBSingleton: CurrentIOBSingleton
    var body: some View {
        HStack {
            Text("\(libreLinkUpHistory.currentGlucose.units)")
                .font(.system(size: 128)) //, weight: .bold)
                .foregroundStyle(foregroundStyleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .padding()
            
            VStack(spacing: 4) {
                Text("\(libreLinkUpHistory.currentTrendArrow)")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(foregroundStyleColor)
//                    .border(.red)
                Button {
                    isShowingInsulinDeliverySheet.toggle()
                } label: {
                    let iobValue = currentIOBSingleton.currentIOB
                    Text(iobValue > 0
                         ? "IOB: \(iobValue, specifier: "%.2f")u"
                         : "IOB")
                    .font(.title2)
                    .foregroundStyle(Color.primary)
                    .padding(4) // Add padding so the border doesn't hug the text too tightly
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary, lineWidth: 0.5)
                    )
                    
                }
                .sheet(isPresented: $isShowingInsulinDeliverySheet, content: {
                    PhoneAppInsulinDeliveryView()
                })
            }
            .padding()
//            .border(.red)
        }
    }
}


#Preview {
    PhoneAppHomeView()
    
//        .environment(History.test)
//        .environment(LibreLinkUpHistory.mock)
}






// This is not needed at the moment
struct MockData {
    
    static let libreLinkUpHistory = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 1200, rawTemperature: 4, temperatureAdjustment: 4, trendRate: 4.0, trendArrow: .stable, id: 4, date: Date(timeIntervalSince1970: 746277263), hasError: false),
                                                        color: MeasurementColor.green,
                                                        trendArrow: TrendArrow(rawValue: 0))]
    
    let test = Glucose(rawValue: 4, rawTemperature: 4, temperatureAdjustment: 4, trendRate: 4.0, trendArrow: .stable, id: 4, date: Date(timeIntervalSince1970: 345345345), hasError: false)
    let test2 = Glucose(120, temperature: 20.0, trendRate: 0.0, trendArrow: .stable, id: 6000, date: Date(), source: "Mock")
}

let MockDataPhone = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 1000,
                                                         rawTemperature: 4,
                                                         temperatureAdjustment: 4,
                                                         trendRate: 4.0,
                                                         trendArrow: .stable,
                                                         id: 6020,
                                                         date: Date(timeIntervalSinceNow: -3 * 60 * 60),
                                                         hasError: false),
                                        color: MeasurementColor.green,
                                        trendArrow: TrendArrow(rawValue: 0)),
                     LibreLinkUpGlucose(glucose: Glucose(rawValue: 1500,
                                                         rawTemperature: 4,
                                                         temperatureAdjustment: 4,
                                                         trendRate: 4.0,
                                                         trendArrow: .stable,
                                                         id: 6025,
                                                         date: Date(timeIntervalSinceNow: -2 * 60 * 60),
                                                         hasError: false),
                                         color: MeasurementColor.green,
                                        trendArrow: TrendArrow(rawValue: 0)),
                     LibreLinkUpGlucose(glucose: Glucose(rawValue: 800,
                                                         rawTemperature: 4,
                                                         temperatureAdjustment: 4,
                                                         trendRate: 4.0,
                                                         trendArrow: .stable,
                                                         id: 6030,
                                                         date: Date(timeIntervalSinceNow: -1 * 60 * 60),
                                                         hasError: false),
                                        color: MeasurementColor.green,
                                        trendArrow: TrendArrow(rawValue: 0))]
