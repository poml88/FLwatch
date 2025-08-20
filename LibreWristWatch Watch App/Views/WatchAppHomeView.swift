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
    @State private var isReloading: Bool = false
    @State private var isShowingDisclaimer = false
//    @State private var currentIOB: Double = 0.0
//    @State private var sensorSettings = SensorSettings()
    @State private var connected = UserDefaults.group.connected
    
//    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
//    @State var currentGlucose: Int = 0
//    @State var trendArrow = "---"
    private var libreLinkUp = LibreLinkUp()
    
    private let timer = Timer.publish(every: 60, tolerance: 1, on: .main, in: .common).autoconnect()
    
    
    var body: some View {
        VStack{
            HStack {
//                if minutesSinceLastReading >= 3 {
//                    Text("---")
//                    .font(.system(size: 60)) //, weight: .bold
//                    .minimumScaleFactor(0.1)
//                    .padding()
//                } else {
                Text("\(libreLinkUpHistory.currentGlucose.units)")
                    .font(.system(size: 60)) //, weight: .bold
                    .foregroundStyle(libreLinkUpHistory.libreLinkUpGlucose[0].color.color)
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
                        .foregroundStyle(libreLinkUpHistory.libreLinkUpGlucose[0].color.color)
                    
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
            Button("Accept", role: .cancel, action: {settings.hasSeenDisclaimer = true})
        }
    message: {
            Text("!! Not for treatment decisions !!\n\nUse at your own risk!\n\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.")
        }
        .overlay
        {
            if isReloading == true {
                ZStack {
                    Color(white: 0, opacity: 0.25)
                    ProgressView().tint(.white)
                }
                .ignoresSafeArea()
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
                    minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                    isReloading = false
                }
            }
        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
            if settings.hasSeenDisclaimer == false {
                isShowingDisclaimer = true
            }
            
            
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            
            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            connected = UserDefaults.group.connected
            if isReloading == false && minutesSinceLastReading >= 1 && connected == .newlyConnected {
                Task {
                    isReloading = true
                    await libreLinkUp.reloadLibreLinkUp()
                    minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                    isReloading = false
                    connected = .connected
                    UserDefaults.group.connected = .connected
                }
            }        }
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
