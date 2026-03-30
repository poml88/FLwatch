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
//    @State private var minutesSinceLastReading: Int = 999
    //    @State private var isReloading: Bool = false
    @State private var isShowingDisclaimer = false
    //    @State private var currentIOB: Double = 0.0
    //    @State private var sensorSettings = SensorSettings()
    @State private var connected = UserDefaults.group.connected
    @State private var onAppearNotToDoFirstStart: Bool = true
    @State private var lastWidgetReloadAt: Date = .distantPast
    @State private var lastHistoryReloadAt: Date = .distantPast
    @State private var currentTime: Date = Date()
    
    @StateObject private var lluService = LibreLinkUpService.shared
    
    //    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
    //    @State var currentGlucose: Int = 0
    //    @State var trendArrow = "---"
    
    private let timer = Timer.publish(every: 60, tolerance: 1, on: .main, in: .common).autoconnect()
    private let minimumWidgetReloadInterval: TimeInterval = 2
    private let minimumHistoryReloadInterval: TimeInterval = 2

    private var minutesSinceLastReading: Int {
        max(Int(currentTime.timeIntervalSince(libreLinkUpHistory.lastReadingDate) / 60), 0)
    }

    private var isReadingStale: Bool {
        minutesSinceLastReading >= 3
    }

    private var isMissingCredentials: Bool {
        UserDefaults.group.username.isEmpty
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
            currentTime = time
            reloadAndRefreshHistory(trigger: "timer")
        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
            currentTime = Date()
            if SharedData.hasSeenDisclaimer == false {
                isShowingDisclaimer = true
            }
            
            reloadAndRefreshHistory(trigger: ".onAppear") // Do this early
            
            //MARK: Skip the following on app start
            if onAppearNotToDoFirstStart == false { // not to do on first start
                
            }
            // ------------------------------------
            
            //MARK: Do the following only on app start
            if onAppearNotToDoFirstStart == true { // to do only on first start
                FLwatchShortcuts.updateAppShortcutParameters() // this was in the app init first, but it seems this was too early... So I moved it here.
                
//                reloadWidgetsIfNeeded(trigger: "onAppear:firstStart")
                
                onAppearNotToDoFirstStart = false
            }
            // ------------------------------------------------
            
            //MARK: Do the following .onAppear
            
            
            
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active { // This does not fire anyore at app start since iOS 26...
                print("Scene Phase Active")
                
//                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                
                reloadWidgetsIfNeeded(trigger: "scenePhase.active")
                currentTime = Date()

                reloadAndRefreshHistory(trigger: "scenePhase.active")

                
                
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

            if isMissingCredentials && lluService.isReloading == false {
                ZStack {
                    Color(white: 0, opacity: 0.5)

                    VStack {
                        Image(systemName: "iphone.slash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40)
                        Text("No credentials (yet) received from phone. Try tapping 'Connect' on phone to resend to watch and wait a minute.")
                            .multilineTextAlignment(.center)
                    }
                }
                .ignoresSafeArea()
            } else if isReadingStale && lluService.isReloading == false {
                ZStack {
                    Color(white: 0, opacity: 0.5)

                    VStack {
                        Image(systemName: "hourglass.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40)
                        Text("No data since \(minutesSinceLastReading) min.")
                            .multilineTextAlignment(.center)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
    
    private func reloadAndRefreshHistory(trigger: String) {
        let now = Date()
        guard now.timeIntervalSince(lastHistoryReloadAt) >= minimumHistoryReloadInterval else {
            print("Skipping reloadAndRefreshHistory() [\(trigger)]")
            return
        }
        lastHistoryReloadAt = now
        Task {
            currentTime = Date()
            await lluService.requestReloadIfNeeded()
            currentTime = Date()
        }
        print("reloadAndRefreshHistory() [\(trigger)]")
    }
    
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
    
}


#Preview {
    WatchAppHomeView()
    //        .environment(History.test)
}

