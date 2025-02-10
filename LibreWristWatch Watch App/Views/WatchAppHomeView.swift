//
//  WatchAppHomeView.swift
//  LibreWristWatch Watch App
//
//  Created by Peter Müller on 26.08.24.
//

import SwiftUI
import Charts
import OSLog



struct WatchAppHomeView: View {
    
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    @Environment(\.sensorSettingsSingleton) var sensorSettingsSingleton
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
                let rectXStart: Date = libreLinkUpHistory.libreLinkUpGlucose.last?.glucose.date ?? Date(timeIntervalSinceNow: -6 * 60 * 60)
                let rectXStop: Date = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date(timeIntervalSinceNow: -1 * 60)
                
                //Configuration
                // 0 = mmoll  1 = mgdl  0.0555
                var chartYScaleMin: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 2.75 : 50 }
                
                let indexOfMaxGlucoseItem = libreLinkUpHistory.libreLinkUpGlucose.indices.max(by:
                                                                                                { libreLinkUpHistory.libreLinkUpGlucose[$0].glucose.value < libreLinkUpHistory.libreLinkUpGlucose[$1].glucose.value }
                ) ?? 250
                let maxBG: Int = libreLinkUpHistory.libreLinkUpGlucose[indexOfMaxGlucoseItem].glucose.value
                
                
                var chartYScaleMax: Double { if maxBG > 350 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 21 : 400}
                    else if maxBG > 250 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 18 : 300}
                    else { sensorSettingsSingleton.sensorSettings.uom == 0 ? 12.5 : 225}
                }
//                var chartYScaleMax: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 12.5 : 225 }
                var yAxisSteps: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 3 : 50 }
                
                
                var chartRectangleYStart: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.targetLow.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.targetLow) }
                var chartRectangleYEnd: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.targetHigh.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.targetHigh) }
                var chartRuleAlarmLL: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.alarmLow.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.alarmLow) }
                // Setting to 6 hours below by deleting half of the values.
                
                
                Chart {
                    
                    RectangleMark(
                        xStart: .value("Rect Start Width", rectXStart),
                        xEnd: .value("Rect End Width", rectXStop),
                        //                xStart: .value("Rect Start Width", 1),
                        //                xEnd: .value("Rect End Width", 2),
                        yStart: .value("Rect Start Height", chartRectangleYStart),
                        yEnd: .value("Rect End Height", chartRectangleYEnd)
                    )
                    .opacity(0.2)
                    .foregroundStyle(.green)
                    
                    RuleMark(y: .value("Lower limit", chartRuleAlarmLL))
                        .foregroundStyle(.red)
                        .lineStyle(.init(lineWidth: 1, dash: [2]))
                    
//                    RuleMark(x: .value("Scroll right", rectXStop))
//                        .foregroundStyle(.yellow)
//                        .lineStyle(.init(lineWidth: 1))
                    
//                    RuleMark(y: .value("Upper limit", 225))
//                        .foregroundStyle(.red)
//                        .lineStyle(.init(lineWidth: 1, dash: [2]))
                    
                    ForEach(libreLinkUpHistory.libreLinkUpGlucose) { item in
                        
//                        PointMark(x: .value("Time", item.glucose.date),
//                                  y: .value("Glucose", item.glucose.value)
//                        )
//                        .foregroundStyle(.red)
//                        .symbolSize(3)
                        
                        var itemValue: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                        LineMark(x: .value("Time", item.glucose.date),
                                 y: .value("Glucose", itemValue))
                        .interpolationMethod(.linear)
                        .lineStyle(.init(lineWidth: 3))
                        .symbol(){
                            Circle()
                                .fill(item.color.color)
                                .frame(width: 4, height: 4)
                        }
                        
                        //                if let selectedlibreLinkHistoryPoint,selectedlibreLinkHistoryPoint.id == item.id {
                        //                    RuleMark(x: .value("Time", selectedlibreLinkHistoryPoint.glucose.date))
                        //                        .annotation(position: .top) {
                        //                            VStack(alignment: .leading, spacing: 6){
                        //                                Text("\(selectedlibreLinkHistoryPoint.glucose.date.toLocalTime())")
                        //
                        //                                Text("\(selectedlibreLinkHistoryPoint.glucose.value) mg/dL")
                        //                                    .font(.title3.bold())
                        //                            }
                        //                            .padding(.horizontal,10)
                        //                            .padding(.vertical,4)
                        //                            .background{
                        //                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                        //                                    .fill(.background.shadow(.drop(radius: 2)))
                        //                            }
                        //                        }
                        //                }
                    }
                    
                    ForEach(libreLinkUpHistory.libreLinkUpMinuteGlucose) { item in
                        var itemValue: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                        PointMark(x: .value("Time", item.glucose.date),
                                  y: .value("Glucose", itemValue)
                        )
                        .foregroundStyle(.yellow)
                        .symbolSize(8)
                    }
                }
                
                .chartYScale(domain: [chartYScaleMin, chartYScaleMax])
                
                .chartXVisibleDomain(length: 3600 * 6)
//                .chartScrollableAxes(.horizontal)
//                .chartScrollPosition(initialX: Date())
//                .chartScrollTargetBehavior(
//                            .valueAligned(
//                                unit: 3600 * 2,
//                                majorAlignment: .page))

                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
                        AxisTick(length: -5, stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                        //                        AxisValueLabel( anchor: .top)
                        AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)), anchor: .top)
                            .font(.system(size: 10))
                    }
                    AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                        //                        AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
                        AxisTick(length: -5, stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: yAxisSteps)) { value in
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                        //                        AxisTick(length: 5, stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                        AxisValueLabel()
                            .font(.system(size: 10))
                        
                    }
                }
                .padding(.top, -20)
            }
            //        .chartOverlay { overlayProxy in
            //            GeometryReader { geometryProxy in
            //                Rectangle().fill(.clear).contentShape(Rectangle())
            //                    .gesture(DragGesture()
            //                        .onChanged { value in
            //                            let currentX = value.location
            //                            if let currentDate: Date = overlayProxy.value(atX: currentX.x) {
            //                                //                                        let selectedlibreLinkHistoryPoint = libreLinkUpHistory[currentDate.toRounded(on: 1, .minute)]
            //                                if let currentItem = libreLinkUpHistory.first(where: { item in
            //                                    item.glucose.date.toRounded(on: 1, .minute) == currentDate.toRounded(on: 1, .minute)
            //                                }){
            //                                    self.selectedlibreLinkHistoryPoint = currentItem
            //                                }                                     }
            //                        }
            //
            //                        .onEnded { value in
            //                            self.selectedlibreLinkHistoryPoint = nil
            //                        }
            //                    )
            //            }
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
            
            CurrentIOBSingleton.shared.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
            
            connected = UserDefaults.group.connected
            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            if minutesSinceLastReading >= 1 && (connected == .connected || connected == .newlyConnected) {
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
            
            
            CurrentIOBSingleton.shared.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
            
            
            
            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            connected = UserDefaults.group.connected
            if minutesSinceLastReading >= 1 && connected == .newlyConnected {
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
                
                
                CurrentIOBSingleton.shared.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                
                
                connected = UserDefaults.group.connected
                minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
                if minutesSinceLastReading >= 1 && (connected == .connected || connected == .newlyConnected) {
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
