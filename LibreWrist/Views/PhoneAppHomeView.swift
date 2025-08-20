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


struct PhoneAppHomeView: View {
    
    
    
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
//    @Environment(History.self) var history: History
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
//    @Environment(\.sensorSettingsSingleton) var sensorSettingsSingleton
    @Environment(\.currentIOBSingleton) var currentIOBSingleton
//    @Environment(\.insulinDeliveryHistorySingleton) var insulinDeliveryHistorySingleton
    
    
    
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
    
//    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
//    @State var currentGlucose: Int = 0
//    @State var trendArrow = "---"
    private var libreLinkUp = LibreLinkUp()
    
     
    private let timer = Timer.publish(every: 60, tolerance: 1, on: .main, in: .common).autoconnect()
    
    
    
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
            Button("Accept", role: .cancel, action: {settings.hasSeenDisclaimer = true})
        }
        message: {
            Text("!! Not for treatment decisions !!\n\nUse at your own risk!\n\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.")
        }
        
        .alert ("Welcome", isPresented: $isShowingWelcomeMessage) {
            Button("Start", role: .cancel, action: {settings.hasSeenWelcomeMessage = true})
        }
        message: {
            Text("Thank you for downloading FLwatch. I hope it will prove useful.\n\nTo get startet, please read the SETUP AND USAGE guide. In case of questions, please contact support. More info on the Settings tab.")
        }
        
        .alert ("Update note", isPresented: $isShowingNotification) {
            Button("Understood", role: .cancel, action: {settings.hasSeenNotification = true})
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
            print("Timer")
            
            
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            
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
                scrollPosition = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date.now
            }
        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
//            settings.hasSeenDisclaimer = false
//            settings.hasSeenWelcomeMessage = false
            
            if settings.hasSeenWelcomeMessage == false {
                isShowingWelcomeMessage = true
            }
            
            if settings.hasSeenDisclaimer == false {
                isShowingDisclaimer = true
            }
            
            
            
//            Uncomment to show a notification at app start
//            Increase counter in Settings (hasSeenNotification000)
//            if settings.hasSeenNotification == false {
//                isShowingNotification = true
//            }
            
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            
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
                print("Active")
                
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                WidgetCenter.shared.reloadAllTimelines()
                
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
                print("Inactive")
            } else if newPhase == .background {
                print("Background")
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
            
            VStack {
                Text("\(libreLinkUpHistory.currentTrendArrow)")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(foregroundStyleColor)
                Button {
                    isShowingInsulinDeliverySheet.toggle()
                } label: {
                    Text("IOB: \(currentIOBSingleton.currentIOB, specifier: "%.2f")u")
                        .font(.title2)
                        .foregroundStyle(Color.primary)
                }
                .sheet(isPresented: $isShowingInsulinDeliverySheet, content: {
                    PhoneAppInsulinDeliveryView()
                })
            }
            .padding()
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

