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
    @Environment(History.self) var history: History 
    
    @State private var libreLinkUpHistory: [LibreLinkUpGlucose] = MockDataWatch
    //    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    @State private var libreLinkUpResponse: String = "[...]"
    @State private var libreLinkUpLogbookHistory: [LibreLinkUpGlucose] = []
    @State private var minutesSinceLastReading: Int = 999
    @State private var isReloading: Bool = false
    @State private var isShowingDisclaimer = false
    @State private var currentIOB: Double = 0.0
    @State private var sensorSettings = SensorSettings(uom: 1, targetLow: 70, targetHigh: 180, alarmLow: 80, alarmHigh: 300)
    @State private var connected = UserDefaults.group.connected
    
    @State var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
    @State var currentGlucose: Int = 0
    @State var trendArrow = "---"
    
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
                    Text("\(currentGlucose)")
                    .font(.system(size: 60)) //, weight: .bold
                    .foregroundStyle(libreLinkUpHistory[0].color.color)
                        .minimumScaleFactor(0.1)
                        .padding()
//                }
                    
                VStack (spacing: -10){
                    //                    if minutesSinceLastReading >= 3 {
                    //                        Text("---")
                    //                            .font(.title)
                    //                    } else {
                    Text("\(trendArrow)")
                        .font(.title)
                        .foregroundStyle(libreLinkUpHistory[0].color.color)
                    
                    if currentIOB > 0 {
                        Text("\(currentIOB, specifier: "%.2f")U")
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
            if libreLinkUpHistory.count > 0 {
                let rectXStart: Date = libreLinkUpHistory.last?.glucose.date ?? Date.distantPast
                let rectXStop: Date = libreLinkUpHistory.first?.glucose.date ?? Date.distantFuture
                
                //Configuration
                // 0 = mmoll  1 = mgdl  0.0555
                var chartYScaleMin: Double { sensorSettings.uom == 0 ? 2.75 : 50 }
                var chartYScaleMax: Double { sensorSettings.uom == 0 ? 12.5 : 225 }
                var yAxisSteps: Double { sensorSettings.uom == 0 ? 3 : 50 }
                
                
                let chartRectangleYStart = sensorSettings.targetLow
                let chartRectangleYEnd = sensorSettings.targetHigh
                let chartRuleAlarmLL = sensorSettings.alarmLow
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
                    
                    ForEach(libreLinkUpHistory) { item in
                        
//                        PointMark(x: .value("Time", item.glucose.date),
//                                  y: .value("Glucose", item.glucose.value)
//                        )
//                        .foregroundStyle(.red)
//                        .symbolSize(3)
                        
                        LineMark(x: .value("Time", item.glucose.date),
                                 y: .value("Glucose", item.glucose.value))
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
                    
                    ForEach(history.factoryTrend) { item in
                        PointMark(x: .value("Time", item.date),
                                  y: .value("Glucose", item.value)
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
            
            var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
            var sumIOB: Double = 0
            for item in insulinDeliveryHistory {
                if Date().timeIntervalSince1970 - item.timeStamp > 12 * 60 * 60 {
                    insulinDeliveryHistory.removeAll(where: {$0.id == item.id})
                } else {
                    let IOB =   updateIOB(timeStamp: item.timeStamp) * item.insulinUnits
                    sumIOB = sumIOB + IOB
                }
            }
            currentIOB = sumIOB
            UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
            
            connected = UserDefaults.group.connected
            minutesSinceLastReading = Int(Date().timeIntervalSince(lastReadingDate) / 60)
            if minutesSinceLastReading >= 1 && connected == .connected {
                Task {
                    isReloading = true
                    await reloadLibreLinkUp()
                    isReloading = false
                }
            }
        }
        .onAppear() { // fires when switching the Views, e.g. form settings to home view.
            print("onAppear")
            if settings.hasSeenDisclaimer == false {
                isShowingDisclaimer = true
            }
            
            
            var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
            var sumIOB: Double = 0
            for item in insulinDeliveryHistory {
                if Date().timeIntervalSince1970 - item.timeStamp > 12 * 60 * 60 {
                    insulinDeliveryHistory.removeAll(where: {$0.id == item.id})
                } else {
                    let IOB =   updateIOB(timeStamp: item.timeStamp) * item.insulinUnits
                    sumIOB = sumIOB + IOB
                }
            }
            currentIOB = sumIOB
            UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
            
            
            
            minutesSinceLastReading = Int(Date().timeIntervalSince(lastReadingDate) / 60)
            connected = UserDefaults.group.connected
            if minutesSinceLastReading >= 1 && connected == .newlyConnected {
                Task {
                    isReloading = true
                    await reloadLibreLinkUp()
                    isReloading = false
                    connected = .connected
                    UserDefaults.group.connected = .connected
                }
            }        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                print("Active")
                
                
                var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
                var sumIOB: Double = 0
                for item in insulinDeliveryHistory {
                    if Date().timeIntervalSince1970 - item.timeStamp > 12 * 60 * 60 {
                        insulinDeliveryHistory.removeAll(where: {$0.id == item.id})
                    } else {
                        let IOB =   updateIOB(timeStamp: item.timeStamp) * item.insulinUnits
                        sumIOB = sumIOB + IOB
                    }
                }
                currentIOB = sumIOB
                UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
                
                
                connected = UserDefaults.group.connected
                minutesSinceLastReading = Int(Date().timeIntervalSince(lastReadingDate) / 60)
                if minutesSinceLastReading >= 1 && connected == .connected {
                    Task {
                        isReloading = true
                        await reloadLibreLinkUp()
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
                        
                        Text("No data since \(minutesSinceLastReading) min.")
                            .multilineTextAlignment(.center)
                    }
                    
                    
                }
                .ignoresSafeArea()
            }
        }
    }
    
    func updateIOB(timeStamp time: Double) -> Double {
        let model = ExponentialInsulinModel(actionDuration: 270 * 60, peakActivityTime: 120 * 60, delay: 15 * 60)
        let result = model.percentEffectRemaining(at: Date().timeIntervalSince1970 - time)
        return result
    }
        
    
    func reloadLibreLinkUp() async {
        
        var dataString = ""
        var retries = 0
        let dropLastValues = 70
        
        
    loop: repeat {
        do {
            let token = settings.libreLinkUpToken
            if settings.libreLinkUpUserId.isEmpty ||
                settings.libreLinkUpToken.isEmpty ||
                settings.libreLinkUpTokenExpirationDate < Date() ||
                retries == 1 {
                do {
                    try await LibreLinkUp().login()
                    UserDefaults.group.connected = .connected
                } catch {
                    libreLinkUpResponse = error.localizedDescription.capitalized
                    UserDefaults.group.connected = .disconnected
                }
            }
            if !(settings.libreLinkUpUserId.isEmpty ||
                 settings.libreLinkUpToken.isEmpty) {
                let (data, _, graphHistory, logbookData, logbookHistory, _, sensorSettingsRead) = try await LibreLinkUp().getPatientGraph()
                dataString = (data as! Data).string
                libreLinkUpResponse = dataString + (logbookData as! Data).string
                
//                                if libreLinkUpHistory.count == 0 {
//                    libreLinkUpHistory = MockDataWatch
//                }
                libreLinkUpLogbookHistory = logbookHistory
                
                
                
                if graphHistory.count > 0 {
                    DispatchQueue.main.async {
                        settings.lastOnlineDate = Date()
                        sensorSettings = sensorSettingsRead
                        // TODO: just merge with newer values
                        libreLinkUpHistory = graphHistory.reversed().dropLast(dropLastValues) //For watch show only 6 hours
                        let lastMeasurement = libreLinkUpHistory[0]
                        lastReadingDate = lastMeasurement.glucose.date
                        minutesSinceLastReading = Int(Date().timeIntervalSince(lastReadingDate) / 60)
//                        sensor?.lastReadingDate = lastReadingDate
                        currentGlucose = lastMeasurement.glucose.value
                        trendArrow = lastMeasurement.trendArrow?.symbol ?? "---"
                        // TODO: keep the raw values filling the gaps with -1 values
                        history.rawValues = []
                        history.factoryValues = libreLinkUpHistory.dropFirst().map(\.glucose) // TEST
                        var trend = history.factoryTrend
                        if trend.isEmpty || lastMeasurement.id > trend[0].id {
                            trend.insert(lastMeasurement.glucose, at: 0)
                        }
                        // keep only the latest 16 minutes considering the 17-minute latency of the historic values update
                        if libreLinkUpHistory.indices.contains(1) {
                            let lastGraphItem = libreLinkUpHistory[1].id
                            trend = trend.filter { $0.id > lastGraphItem }
                        }
                        history.factoryTrend = trend
                        Logger.general.info("LibreLinkUp: history.factoryTrend: \(history.factoryTrend)")
                        // TODO: merge and update sensor history / trend
                        //                            app.main.didParseSensor(app.sensor)
                    }
                }
                if dataString != "{\"message\":\"MissingCachedUser\"}\n" {
                    break loop
                }
                retries += 1
            }
        } catch {
            libreLinkUpResponse = error.localizedDescription.capitalized
        }
    } while retries == 1
    }
}


#Preview {
    WatchAppHomeView()
        .environment(History.test)
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
