//
//  WatchAppHomeView.swift
//  LibreWristWatch Watch App
//
//  Created by Peter Müller on 26.08.24.
//

import SwiftUI
import Charts
import OSLog
import WidgetKit



struct WatchAppHomeView: View {
    
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    //    @Environment(\.sensorSettingsSingleton) var sensorSettingsSingleton
    @Environment(\.currentIOBSingleton) var currentIOBSingleton
    
    //    @State private var libreLinkUpHistory: [LibreLinkUpGlucose] = MockDataWatch
    //    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    @State private var libreLinkUpResponse: String = "[...]"
    //    @State private var libreLinkUpLogbookHistory: [LibreLinkUpGlucose] = []
    @State private var minutesSinceLastReading: Int = 999
    //    @State private var isReloading: Bool = false
    @State private var isShowingDisclaimer = false
    //    @State private var currentIOB: Double = 0.0
    //    @State private var sensorSettings = SensorSettings()
    @State private var connected = UserDefaults.group.connected
    @State private var onAppearNotToDoFirstStart: Bool = true
    @State private var lastWidgetReloadAt: Date = .distantPast
    
    @StateObject private var lluService = LibreLinkUpService.shared
    
    //    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
    //    @State var currentGlucose: Int = 0
    //    @State var trendArrow = "---"
    
    private let timer = Timer.publish(every: 60, tolerance: 1, on: .main, in: .common).autoconnect()
    private let minimumWidgetReloadInterval: TimeInterval = 2

    private func reloadWidgetsIfNeeded(trigger: String) {
        let now = Date()
        guard now.timeIntervalSince(lastWidgetReloadAt) >= minimumWidgetReloadInterval else {
            print("Skipping WidgetCenter.shared.reloadAllTimelines() [\(trigger)]")
            return
        }
        lastWidgetReloadAt = now
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetCenter.shared.reloadAllTimelines() [\(trigger)]")
    }
    
    
    var body: some View {
        VStack{
            HStack {
                //                if minutesSinceLastReading >= 3 {
                //                    Text("---")
                //                    .font(.system(size: 60)) //, weight: .bold
                //                    .minimumScaleFactor(0.1)
                //                    .padding()
                //                } else {
                let fg = libreLinkUpHistory.libreLinkUpGlucose.first?.color.color ?? .white
                Text("\(libreLinkUpHistory.currentGlucose.units)")
                    .font(.system(size: 60)) //, weight: .bold
                    .foregroundStyle(fg)
                    .minimumScaleFactor(0.1)
                    .padding()
                //                }
                
                VStack (spacing: -10){
                    //                    if minutesSinceLastReading >= 3 {
                    //                        Text("---")
                    //                            .font(.title)
                    //                    } else {
                    Text("\(libreLinkUpHistory.currentTrendArrow)")
                        .font(.title)
                        .foregroundStyle(fg)
                    
                    if currentIOBSingleton.currentIOB > 0 {
                        Text("\(currentIOBSingleton.currentIOB, specifier: "%.2f")u")
                            .font(.body)
                    }
                    //                    }
                    //                    Text("\(lastReadingDate.toLocalTime())")
                    //                        .font(.system(size: 30, weight: .bold))
                    
                    //                    if minutesSinceLastReading == 999 {
                    //                        Text("-- min ago")
                    //                    } else {
                    //                        Text("\(minutesSinceLastReading) min ago")
                    //                    }
                }
                .padding()
            }
            if libreLinkUpHistory.libreLinkUpGlucose.count > 0 {
                WatchAppGraphView()
            }
            
        }
        .padding(.top, -40)
        .padding(.bottom, -15)
        .alert ("Warning", isPresented: $isShowingDisclaimer) {
            Button("Accept", role: .cancel, action: {SharedData.hasSeenDisclaimer = true})
        }
        message: {
            Text("!! Not for treatment decisions !!\n\nUse at your own risk!\n\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.")
        }
        
        .onReceive(timer) { time in
            print("Timer")
            
            //            connected = UserDefaults.group.connected
            //            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            //            if isReloading == false && minutesSinceLastReading >= 1 && (connected == .connected || connected == .newlyConnected) {
            //                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            //                Task {
            //                    isReloading = true
            //                    await libreLinkUp.reloadLibreLinkUp()
            //                    minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            //                    isReloading = false
            //                }
            //            }
            reloadAndUpdateMinutes()

        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
            if SharedData.hasSeenDisclaimer == false {
                isShowingDisclaimer = true
            }
            
            //MARK: Skip the following on app start
            if onAppearNotToDoFirstStart == false { // not to do on first start
                
//                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            }
            // ------------------------------------
            
            //MARK: Do the following only on app start
            if onAppearNotToDoFirstStart == true { // to do only on first start
                FLwatchShortcuts.updateAppShortcutParameters() // this was in the app init first, but it seems this was too early... So I moved it here.
                
                // --------------------- copied here from .onChange(of: scenePhase) { oldPhase, newPhase in as it currently does not fire at app start
//                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                
                reloadWidgetsIfNeeded(trigger: "onAppear:firstStart")
                
                //                connected = UserDefaults.group.connected
                //                minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                //                if isReloading == false && minutesSinceLastReading >= 1 && (connected == .connected || connected == .newlyConnected) {
                //                    Task {
                //                        isReloading = true
                //                        await libreLinkUp.reloadLibreLinkUp()
                //                        minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                //                        isReloading = false
                //                    }
                //                }
                reloadAndUpdateMinutes()

                // -----------------------
                
                onAppearNotToDoFirstStart = false
            }
            // ------------------------------------------------
            
            //MARK: Do the following .onAppear
            //            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            //            connected = UserDefaults.group.connected
            //            if isReloading == false && minutesSinceLastReading >= 1 && connected == .newlyConnected {
            //                Task {
            //                    isReloading = true
            //                    await libreLinkUp.reloadLibreLinkUp()
            //                    minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            //                    isReloading = false
            //                    connected = .connected
            //                    UserDefaults.group.connected = .connected
            //                }
            //            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active { // This does not fire anyore at app start since iOS 26...
                print("Scene Phase Active")
                
//                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                
                reloadWidgetsIfNeeded(trigger: "scenePhase.active")
                
                //                connected = UserDefaults.group.connected
                //                minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                //                if isReloading == false && minutesSinceLastReading >= 1 && (connected == .connected || connected == .newlyConnected) {
                //                    Task {
                //                        isReloading = true
                //                        await libreLinkUp.reloadLibreLinkUp()
                //                        minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                //                        isReloading = false
                //                    }
                //                }
                reloadAndUpdateMinutes()

                
                
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
                    ProgressView().tint(.white)
                }
                .ignoresSafeArea()
            }
            
            let minutesSinceLastReadingOverlay = Int(Date().timeIntervalSince(libreLinkUpHistory.lastReadingDate) / 60)
            if minutesSinceLastReadingOverlay >= 3 && lluService.isReloading == false {
                ZStack {
                    Color(white: 0, opacity: 0.5)
                    
                    VStack {
                        Image(systemName: "hourglass.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40)
                        if UserDefaults.group.username == "" {
                            Text("No credentials (yet) received from phone. Try tapping 'Connect' on phone to resend to watch and wait a minute.")
                                .multilineTextAlignment(.center)
                        } else {
                            Text("No data since \(minutesSinceLastReading) min.")
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    
                }
                .ignoresSafeArea()
            }
        }
    }
    
    private func reloadAndUpdateMinutes() {
        Task {
            await lluService.requestReloadIfNeeded()
            minutesSinceLastReading = Int(Date().timeIntervalSince(libreLinkUpHistory.lastReadingDate) / 60)
        }
    }
    
}


#Preview {
    WatchAppHomeView()
    //        .environment(History.test)
}

let MockDataWatch = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 1000,
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
