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
    
    private static let foregroundReloadInterval: TimeInterval = 65
    private let timer = Timer.publish(every: Self.foregroundReloadInterval, tolerance: 1, on: .main, in: .common).autoconnect()
    private let minimumWidgetReloadInterval: TimeInterval = 2
    private let minimumHistoryReloadInterval: TimeInterval = 2

    /// Minute-rounded right edge of the graph's time window, derived from the same
    /// clock sample that drives the staleness overlay so the tick costs one state
    /// write rather than two. Rounding means the graph only re-renders when the
    /// minute actually turns, while the overlay keeps using the exact sample.
    private var chartWindowEnd: Date {
        .chartWindowEnd(from: currentTime)
    }

    private var minutesSinceLastReading: Int {
        max(Int(currentTime.timeIntervalSince(libreLinkUpHistory.lastReadingDate) / 60), 0)
    }

    private var isReadingStale: Bool {
        currentTime.timeIntervalSince(libreLinkUpHistory.lastReadingDate) >= LibreLinkUpService.shared.activeProvider.staleReadingAfter
    }

    private var isMissingCredentials: Bool {
        !SharedData.hasActiveProviderAccount
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
                // Colour of the reading the value below actually shows: `currentGlucose`
                // comes from `latestLibreLinkUpGlucose`, so take the colour from the same
                // reading rather than from the head of the graph series.
                let fg = libreLinkUpHistory.latestLibreLinkUpGlucose?.color.color ?? .white
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
                WatchAppGraphView(windowEnd: chartWindowEnd)
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
        
        .onReceive(timer) { _ in
            Logger.viewDebug.debug("Timer")
            reloadAndRefreshHistory(trigger: "timer")
        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
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
            Logger.viewDebug.debug("Skipping reloadAndRefreshHistory() [\(trigger, privacy: .public)]")
            return
        }
        lastHistoryReloadAt = now
        Task {
            await lluService.requestReloadIfNeeded()
            // One clock sample per reload, taken *after* it finishes rather than
            // before. The progress overlay hides the staleness overlay for the
            // duration of the request, so completion is the moment the staleness
            // check becomes visible again and it has to reflect the time now — a
            // reading that crossed the threshold mid-request would otherwise stay
            // unflagged until the next timer delivery.
            currentTime = Date()
        }
        Logger.viewDebug.debug("reloadAndRefreshHistory() [\(trigger, privacy: .public)]")
    }
    
    private func reloadWidgetsIfNeeded(trigger: String) {
        let now = Date()
        guard now.timeIntervalSince(lastWidgetReloadAt) >= minimumWidgetReloadInterval else {
            Logger.viewDebug.debug("Skipping WidgetCenter.shared.reloadAllTimelines() [\(trigger, privacy: .public)]")
            return
        }
        lastWidgetReloadAt = now
        WidgetCenter.shared.reloadAllTimelines()
        Logger.viewDebug.debug("WidgetCenter.shared.reloadAllTimelines() [\(trigger, privacy: .public)]")
    }
    
}


#Preview {
    WatchAppHomeView()
    //        .environment(History.test)
}
