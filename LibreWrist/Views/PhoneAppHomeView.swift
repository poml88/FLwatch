//
//  PhoneAppHomeView.swift
//  LibreWrist
//
//  Created by Peter Müller on 31.07.24.
//

import SwiftUI
import OSLog
import Charts


struct PhoneAppHomeView: View {
    
    
    
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
//    @Environment(History.self) var history: History
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    @Environment(\.sensorSettingsSingleton) var sensorSettingsSingleton
    @Environment(\.currentIOBSingleton) var currentIOBSingleton
    
    
    
    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    @State private var minutesSinceLastReading: Int = 999
    @State private var libreLinkUpResponse: String = "[...]"
//    @State private var libreLinkUpHistory = LibreLinkUpHistory.mock
//    @State private var libreLinkUpLogbookHistory: [LibreLinkUpGlucose] = []
    @State private var isReloading: Bool = false
    @State private var isShowingDisclaimer = false
    @State private var isShowingNotification = false
    @State private var isShowingInsulinDeliverySheet = false
//    @State private var currentIOB: Double = 0.0
    @State private var scrollPosition: Date = Date.now
//    @State private var sensorSettings = SensorSettings()
    @State private var connected = UserDefaults.group.connected
    
//    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
//    @State var currentGlucose: Int = 0
//    @State var trendArrow = "---"
    private var libreLinkUp = LibreLinkUp()
    
     
    private let timer = Timer.publish(every: 60, tolerance: 1, on: .main, in: .common).autoconnect()
    
    
    
    var body: some View {
        VStack {
            if colorScheme == .dark {
                HStack {
                    
                    Text("\(libreLinkUpHistory.currentGlucose.units)")
                        .font(.system(size: 128)) //, weight: .bold)
                        .foregroundStyle(libreLinkUpHistory.libreLinkUpGlucose[0].color.color)
                        .minimumScaleFactor(0.1)
                        .padding()
                   
                    VStack {
                        Text("\(libreLinkUpHistory.currentTrendArrow)")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(libreLinkUpHistory.libreLinkUpGlucose[0].color.color)
                      
//                        Text("IOB: \(currentIOB, specifier: "%.2f")U")
                        
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
                        
//                        Text("\(lastReadingDate.toLocalTime())")
//                            .font(.system(size: 30, weight: .bold))
//                        
//                        if minutesSinceLastReading == 999 {
//                            Text("-- min ago")
//                        } else {
//                            Text("\(minutesSinceLastReading) min ago")
//                                .font(.footnote)
//                                .monospacedDigit()
//                        }
                    }
                    .padding()
                }
            } else {
                HStack {
                    Text("\(libreLinkUpHistory.currentGlucose.units)")
                        .font(.system(size: 128)) //, weight: .bold)
                        .minimumScaleFactor(0.1)
                        .padding()
                    VStack {
                        Text("\(libreLinkUpHistory.currentTrendArrow)")
                            .font(.system(size: 50, weight: .bold))
                        
//                        Text("IOB: \(currentIOB, specifier: "%.2f")U")
//                            .font(.title2)
                        
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
                        
                        
                        
//                        Text("\(lastReadingDate.toLocalTime())")
//                            .font(.system(size: 30, weight: .bold))
//
//                        if minutesSinceLastReading == 999 {
//                            Text("-- min ago")
//                        } else {
//                            Text("\(minutesSinceLastReading) min ago")
//                                .font(.footnote)
//                                .monospacedDigit()
//                        }
                    }
                    .padding()
                }
                .background(Color(libreLinkUpHistory.libreLinkUpGlucose[0].color.color))
//                .frame(maxWidth: .infinity)
                .cornerRadius(30)
//                .safeAreaPadding(.top)
                
            }
            
            
            if libreLinkUpHistory.libreLinkUpGlucose.count > 0 {
                let rectXStart: Date = libreLinkUpHistory.libreLinkUpGlucose.last?.glucose.date ?? Date(timeIntervalSinceNow: -6 * 60 * 60)
                let rectXStop: Date = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date(timeIntervalSinceNow: -1 * 60)
                
                //Configuration
                // 0 = mmoll  1 = mgdl  0.0555
                var chartYScaleMin: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 2.75 : 50 }
                var chartYScaleMax: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 14 : 250 }
                var yAxisSteps: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 3 : 50 }
                
                
                let chartRectangleYStart = sensorSettingsSingleton.sensorSettings.targetLow
                let chartRectangleYEnd = sensorSettingsSingleton.sensorSettings.targetHigh
                let chartRuleAlarmLL = sensorSettingsSingleton.sensorSettings.alarmLow
                // Setting to 6 hours below by deleting half of the values.
                let unitString = sensorSettingsSingleton.sensorSettings.uom == 0 ? "mmol/L" : "mg/dL"
                
                Chart {
                    //                    RuleMark(y: .value("Minimum High", 300))
                    //                        .foregroundStyle(.clear)
                    
                    RectangleMark(
                        xStart: .value("Rect Start Width", rectXStart),
                        xEnd: .value("Rect End Width", rectXStop),
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
//                        .lineStyle(.init(lineWidth: 2))
                    
//                    RuleMark(y: .value("Upper limit", 300))
//                        .foregroundStyle(.red)
//                        .lineStyle(.init(lineWidth: 1, dash: [2]))

//                    switch libreLinkUpHistory[0].color {
//                    case .green:
//                            .foregroundStyle(.green)
//                    case .yellow:
//                            .foregroundStyle(.yellow)
//                    case .orange:
//                            .foregroundStyle(.orange)
//                    case red:
//                            .foregroundStyle(.red)
//                    default:
//                            .foregroundStyle(.white)
//                    }

                    ForEach(libreLinkUpHistory.libreLinkUpGlucose) { item in
                                                
//                        PointMark(x: .value("Time", item.glucose.date),
//                                  y: .value("Glucose", item.glucose.value)
//                        )
//                        .foregroundStyle(item.color.color)
//                        .symbolSize(12)
                        var itemValue: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                        LineMark(x: .value("Time", item.glucose.date),
                                 y: .value("Glucose", itemValue))
                        .interpolationMethod(.linear)
                        .lineStyle(.init(lineWidth: 5))
                        .symbol(){
                            Circle()
                                .fill(item.color.color)
                                .frame(width: 6, height: 6)
                        }
//                        .symbolSize(100)
                        
                        
                        if let selectedlibreLinkHistoryPoint,selectedlibreLinkHistoryPoint.id == item.id {
                            RuleMark(x: .value("Time", selectedlibreLinkHistoryPoint.glucose.date))
                                .annotation(position: .top) {
                                    VStack(alignment: .leading, spacing: 6){
                                        Text("\(selectedlibreLinkHistoryPoint.glucose.date.toLocalTime())")
                                        
                                        Text("\(selectedlibreLinkHistoryPoint.glucose.value.units) \(unitString)")
                                            .font(.title3.bold())
                                    }
                                    .padding(.horizontal,10)
                                    .padding(.vertical,4)
                                    .background{
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(.background.shadow(.drop(radius: 2)))
                                    }
                                }
                        }
                    }
                    
                    #warning ("breaks preview")
                    ForEach(libreLinkUpHistory.libreLinkUpMinuteGlucose) { item in
                        var itemValue: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                        PointMark(x: .value("Time", item.glucose.date),
                                  y: .value("Glucose", itemValue)
                        )
                        .foregroundStyle(Color.yellow)
                        .symbolSize(20)
                        
                    }
                }
                .chartYScale(domain: [chartYScaleMin, chartYScaleMax])
                
                .chartXVisibleDomain(length: 3600 * 6)
//                .chartScrollableAxes(.horizontal)
//                .chartScrollPosition(initialX: Date())
//                .chartScrollPosition(x: $scrollPosition)
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
                        
                    }
                }
                .chartOverlay { overlayProxy in
                    GeometryReader { geometryProxy in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(DragGesture()
                                .onChanged { value in
                                    let currentX = value.location
                                    if let currentDate: Date = overlayProxy.value(atX: currentX.x) {
                                        //                                        let selectedlibreLinkHistoryPoint = libreLinkUpHistory[currentDate.toRounded(on: 1, .minute)]
                                        if let currentItem = libreLinkUpHistory.libreLinkUpGlucose.first(where: { item in
                                            item.glucose.date.toRounded(on: 1, .minute) == currentDate.toRounded(on: 1, .minute)
                                        }){
                                            self.selectedlibreLinkHistoryPoint = currentItem
                                        }                                     }
                                }
                                     
                                .onEnded { value in
                                    self.selectedlibreLinkHistoryPoint = nil
                                }
                            )
                    }
                }
                .padding()
                
            }
        }
        .alert ("Warning", isPresented: $isShowingDisclaimer) {
            Button("Accept", role: .cancel, action: {settings.hasSeenDisclaimer = true})
        }
    message: {
            Text("!! Not for treatment decisions !!\n\nUse at your own risk!\n\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.")
        }
        
    .alert ("Update note", isPresented: $isShowingNotification) {
        Button("Understood", role: .cancel, action: {settings.hasSeenNotification = true})
    }
message: {
        Text("Please reboot phone and watch once if widgets do not work!")
    }
        
        .overlay
        {
            if isReloading == true {
                ZStack {
                    Color(white: 0, opacity: 0.25)
                    ProgressView().tint(.white)
                }
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
                scrollPosition = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date.now
            }
        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
            if settings.hasSeenDisclaimer == false {
                isShowingDisclaimer = true
            }
            
            if settings.hasSeenNotification == false {
                isShowingNotification = true
            }
            
            CurrentIOBSingleton.shared.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
            
            minutesSinceLastReading = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            connected = UserDefaults.group.connected
            if minutesSinceLastReading >= 1 && connected == .newlyConnected {
                Task {
                    isReloading = true
                    await libreLinkUp.reloadLibreLinkUp()
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
                .ignoresSafeArea()
                .allowsHitTesting(false) // passes taps/clicks through to the bottom layer
                // in this case the IOB button
            }
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

