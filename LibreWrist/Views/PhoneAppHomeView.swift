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
    
    
    
//    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    @State private var minutesSinceLastReading: Int = 999
    @State private var libreLinkUpResponse: String = "[...]"
//    @State private var libreLinkUpHistory = LibreLinkUpHistory.mock
//    @State private var libreLinkUpLogbookHistory: [LibreLinkUpGlucose] = []
    @State private var isReloading: Bool = false
    @State private var isShowingDisclaimer = false
    @State private var isShowingWelcomeMessage = false
    @State private var isShowingNotification = false
    @State private var isShowingInsulinDeliverySheet = false
//    @State private var currentIOB: Double = 0.0
    @State private var scrollPosition: Date = Date.now
//    @State private var sensorSettings = SensorSettings()
    @State private var connected = UserDefaults.group.connected
    @State private var isShowingReloadFailed = false
    @State private var onAppearNotToDoFirstStart: Bool = true
    @State private var scenePhaseNotToDoFirstStart: Bool = true
    @State private var showPrompt = false
    
//    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
//    @State var currentGlucose: Int = 0
//    @State var trendArrow = "---"
    
    private let promptInterval: TimeInterval = 90 * 24 * 60 * 60
    private let safeRange: ClosedRange<Int> = 80...140
    private let allowedHours = 18...22
    private let minimumDaysOfUse = 10
    
    private let libreLinkUp = LibreLinkUp()
     
    private let timer = Timer.publish(every: 60, tolerance: 1, on: .main, in: .common).autoconnect()
    
    private let useLiveActivities  = true
    
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
            Text(libreLinkUp.libreLinkUpResponse)
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
        
        .overlay
        {
            if isReloading == true {
                ZStack {
                    Color(white: 0, opacity: 0.25)
                        .cornerRadius(10)
                    ProgressView().tint(.white)
                }
            }
        }
        .onReceive(timer) { time in
            print("Timer") // Timer fires as well when on a different tab, for example settings tab
            
            connected = UserDefaults.group.connected
            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            if isReloading == false && minutesSinceLastReading >= 1 && (connected == .connected || connected == .newlyConnected) {
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                Task {
                    
                    isReloading = true
                    await libreLinkUp.reloadLibreLinkUp()
                    if libreLinkUp.libreLinkUpErrorBool == true {
                        print(libreLinkUp.libreLinkUpResponse)
                        isShowingReloadFailed = true
                    }
                    minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                    isReloading = false
                    
                }
                scrollPosition = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date.now
            }
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
            
            if onAppearNotToDoFirstStart == false { // not to do on first start
                
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                
                if shouldShowPrompt {
                    showPrompt = true
                }
                
            }
            if onAppearNotToDoFirstStart == true { // to do only on first start
                FLwatchShortcuts.updateAppShortcutParameters() // this was in the app init first, but it seems this was too early... So I moved it here.
//      DEVELOPMENT: 1 lines commented out          LiveActivityManager.shared.startIfAllowed(useLiveActivities: useLiveActivities)

                onAppearNotToDoFirstStart = false
            }
            
            if !hasPromptedOnce {
                recordDayOfUse()
            }
            
            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            connected = UserDefaults.group.connected
            if isReloading == false && minutesSinceLastReading >= 1 && connected == .newlyConnected {
                Task {
                    isReloading = true
                    await libreLinkUp.reloadLibreLinkUp()
                    if libreLinkUp.libreLinkUpErrorBool == true {
                        print(libreLinkUp.libreLinkUpResponse)
                        isShowingReloadFailed = true
                    }
                    isReloading = false
                    connected = .connected
                    UserDefaults.group.connected = .connected
                    minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("Scene Phase Active")

                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                
                if scenePhaseNotToDoFirstStart == false { // not to do on first start
                    WidgetCenter.shared.reloadAllTimelines()
                }
                if scenePhaseNotToDoFirstStart == true { scenePhaseNotToDoFirstStart = false } // to do only on first start
                
                connected = UserDefaults.group.connected
                minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                if isReloading == false && minutesSinceLastReading >= 1 && (connected == .connected || connected == .newlyConnected) {
                    Task {
                        isReloading = true
                        await libreLinkUp.reloadLibreLinkUp()
                        if libreLinkUp.libreLinkUpErrorBool == true {
                            print(libreLinkUp.libreLinkUpResponse)
                            isShowingReloadFailed = true
                        }
                        minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                        isReloading = false
                        }
                    }
            } else if newPhase == .inactive {
                print("Scene Phase Inactive")
            } else if newPhase == .background {
                print("Scene Phase Background")
            }
        }
        .overlay {
            if minutesSinceLastReading >= 3 && isReloading == false {
                ZStack {
                    Color(white: 0, opacity: 0.5)
                        .cornerRadius(10)
                    VStack {
                        Image(systemName: "hourglass.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100)
                            .padding()
                        
                        Text("No data received since \(minutesSinceLastReading) min.\n\nCheck network and bluetooth connections.")
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .background()
                    .cornerRadius(10)
                    .opacity(0.5)
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
        
        let glucose = libreLinkUpHistory.currentGlucose
        guard safeRange.contains(glucose) else { return false }
        
        if !hasPromptedOnce {
            let usedDays: [String] = SharedData.usedDays
            guard usedDays.count >= minimumDaysOfUse else { return false }
        } else {
            SharedData.usedDays.removeAll()
        }
        
        return true
    }
    
    private func recordDayOfUse() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        var usedDays: [String] = SharedData.usedDays
        if !usedDays.contains(todayString) {
            usedDays.append(todayString)
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
        let model = UIDevice.current.model
        let name = UIDevice.current.name
        
        let sensorType = SensorSettingsSingleton.shared.sensorType.description
        
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

