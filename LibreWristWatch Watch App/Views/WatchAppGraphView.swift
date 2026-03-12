
//
//  WatchAppGraphView.swift
//  FLwatch
//
//  Created by Peter Müller on 25.07.25.
//

import SwiftUI
import Charts

struct WatchAppGraphView: View {
    
    @AppStorage(DefaultsKey.showInsulinDeliveryMarksWatch.rawValue, store: UserDefaults.group) private var showInsulinDeliveryMarksWatch: Bool = false
    @AppStorage(DefaultsKey.showIOBCurveWatch.rawValue, store: UserDefaults.group) private var showIOBCurveWatch: Bool = false
    @AppStorage(DefaultsKey.showActivityCurveWatch.rawValue, store: UserDefaults.group) private var showActivityCurveWatch: Bool = false
    
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    @Environment(\.sensorSettingsStore) var sensorSettingsStore
    @Environment(\.currentIOBSingleton) var currentIOBSingleton
    
    var body: some View {
//        let rectXStart: Date = libreLinkUpHistory.libreLinkUpGlucose.last?.glucose.date ?? Date(timeIntervalSinceNow: -6 * 60 * 60)
//        let rectXStop: Date = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date(timeIntervalSinceNow: -1 * 60)
        
        let minuteGlucoseColor = Color(red: 0.96, green: 0.78, blue: 0.18)
        
        let date: Date = Date.now
        
        let dateSixHoursTenAgo: Date = date.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
        let timeIntervalSince1970: Double = date.timeIntervalSince1970
        let timeInternvalSixHoursAndTenAgo: Double = timeIntervalSince1970 - 3600 * 6 - 60 * 10
        
        
        let rectXStart: Date = dateSixHoursTenAgo
        let rectXStop: Date = Date(timeIntervalSinceNow: 0)
        
        //Configuration
        // 0 = mmoll  1 = mgdl  0.0555
        var chartYScaleMin: Double { sensorSettingsStore.sensorSettings.uom == 0 ? 2.75 : 50 }
        
        let maxBG = libreLinkUpHistory.maxBG
        
        let chartXScaleMin: Date = dateSixHoursTenAgo
        let chartXScaleMax: Date = date
        
        var chartYScaleMax: Double { if maxBG > 300 { sensorSettingsStore.sensorSettings.uom == 0 ? 21 : 400}
            else if maxBG > 225 { sensorSettingsStore.sensorSettings.uom == 0 ? 18 : 300}
            else { sensorSettingsStore.sensorSettings.uom == 0 ? 12.5 : 225}
        }
        
        let quarterYAxisIOBCurve: Double = (chartYScaleMax - chartYScaleMin) / 4 + 0.25
        var chartYScaleMinIOBCurve: Double { sensorSettingsStore.sensorSettings.uom == 0 ? 3 : 50 }
        
//                var chartYScaleMax: Double { sensorSettingsStore.sensorSettings.uom == 0 ? 12.5 : 225 }
        var yAxisSteps: Double { sensorSettingsStore.sensorSettings.uom == 0 ? 3 : 50 }
        
        
        var chartRectangleYStart: Double { sensorSettingsStore.sensorSettings.uom == 0 ? sensorSettingsStore.sensorSettings.targetLow.toMmolL() : Double(sensorSettingsStore.sensorSettings.targetLow) }
        var chartRectangleYEnd: Double { sensorSettingsStore.sensorSettings.uom == 0 ? sensorSettingsStore.sensorSettings.targetHigh.toMmolL() : Double(sensorSettingsStore.sensorSettings.targetHigh) }
        var chartRuleAlarmLL: Double { sensorSettingsStore.sensorSettings.uom == 0 ? sensorSettingsStore.sensorSettings.alarmLow.toMmolL() : Double(sensorSettingsStore.sensorSettings.alarmLow) }
        
        
        Chart {

//MARK: Range Rectangle and Alarm Rules
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
       
//MARK: Glucose Graph
            let graphData = libreLinkUpHistory.libreLinkUpGlucose.filter { $0.glucose.date > dateSixHoursTenAgo } // delete everything older than 6:10 h.
            ForEach(graphData) { item in
                
//                        PointMark(x: .value("Time", item.glucose.date),
//                                  y: .value("Glucose", item.glucose.value)
//                        )
//                        .foregroundStyle(.red)
//                        .symbolSize(3)
                
                var itemValue: Double { sensorSettingsStore.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                LineMark(x: .value("Time", item.glucose.date),
                         y: .value("Glucose", itemValue),
                         series: .value("Curve", "Glucose")
                )
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

//MARK: Minute Glucose Trend
            let minuteGlucose = libreLinkUpHistory.libreLinkUpMinuteGlucose.dropFirst()
            ForEach(minuteGlucose) { item in
                var itemValue: Double { sensorSettingsStore.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                PointMark(x: .value("Time", item.glucose.date),
                          y: .value("Glucose", itemValue)
                )
                .foregroundStyle(minuteGlucoseColor)
                .symbolSize(8)
            }

//MARK: IOB Curve
            if showIOBCurveWatch == true {
                let insulinOnBoardCurve = currentIOBSingleton.insulinOnBoardCurve
                let maxIOB = currentIOBSingleton.maxIOB
                
                if InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory.count > 0 {
                    
                    ForEach(insulinOnBoardCurve) { item in
                        LineMark(x: .value("Time", item.date),
                                 y: .value("Insulin", chartYScaleMinIOBCurve + item.value * quarterYAxisIOBCurve / maxIOB),
                                 series: .value("Curve", "Insulin")
                        )
                        .foregroundStyle(.orange)
                        //                    .interpolationMethod(.linear)
                        //                    .lineStyle(.init(lineWidth: 5))
                        //                    .symbol(){
                        //                        Circle()
                        //                            .fill(item.color.color)
                        //                            .frame(width: 6, height: 6)
                        //                    }
                    }
                }
            }
                
//MARK: Insulin delivery marks
            if showInsulinDeliveryMarksWatch == true {
                
                let maxIOB = currentIOBSingleton.maxIOB
                
                if InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory.count > 0 {
                    ForEach(InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory) { item in
                        //                    var itemValue: Double { sensorSettingsStore.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                        if item.timeStamp > timeInternvalSixHoursAndTenAgo {
                            let insulinOnBoardCurve = currentIOBSingleton.insulinOnBoardCurve
                            var iobCurveDataPointAtTimeStamp: ActivityCurveDataPoint { insulinOnBoardCurve.first(where: { $0.date > Date(timeIntervalSince1970: item.timeStamp)}) ?? ActivityCurveDataPoint(id: Int(item.timeStamp),date: Date(timeIntervalSince1970: item.timeStamp), value: 1)}
                            
                            var alignment: Alignment {
                                if item.timeStamp > timeIntervalSince1970 - 40 * 60 {
                                    return .trailing
                                } else if item.timeStamp < timeIntervalSince1970 - 3600 * 6 + 40 * 60 {
                                    return .leading
                                } else {
                                    return .center
                                }
                            }
                            let shiftInYValue = 10
                            var shiftInY: Double { sensorSettingsStore.sensorSettings.uom == 0 ? shiftInYValue.toMmolL() : Double(shiftInYValue) }
                            PointMark(x: .value("Time", Date(timeIntervalSince1970: item.timeStamp)),
                                      y: .value("Insulin", chartYScaleMinIOBCurve + shiftInY + iobCurveDataPointAtTimeStamp.value * quarterYAxisIOBCurve / maxIOB) // we need to know the IOB at this time stamp.
                            )
                            .symbol {
                                Image(systemName: "arrowtriangle.down.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 15))   // default
                            }
                            .annotation(alignment: alignment) {
                                Text("\(item.insulinUnits, specifier: "%.1f")u")
                                    .font(.footnote)
                            }
                        }
                    }
                }
            }
            
        
//MARK: Insulin activity graph
        if showActivityCurveWatch == true {
            
            let insulinActivityCurve = currentIOBSingleton.insulinActivityCurve
            let maxActivity = currentIOBSingleton.maxActivity
                        
            if InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory.count > 0 {
                ForEach(insulinActivityCurve) { item in
                    LineMark(x: .value("Time", item.date),
                             y: .value("Activity", chartYScaleMinIOBCurve + item.value * quarterYAxisIOBCurve / maxActivity),
                             series: .value("Curve", "Activity")
                    )
                    .foregroundStyle(Color.brown)
                    //                    .interpolationMethod(.linear)
                    //                    .lineStyle(.init(lineWidth: 5))
                    //                    .symbol(){
                    //                        Circle()
                    //                            .fill(item.color.color)
                    //                            .frame(width: 6, height: 6)
                    //                    }
                }
            }
        }
    }
        .chartXScale(domain: [chartXScaleMin, chartXScaleMax])
        .chartYScale(domain: [chartYScaleMin, chartYScaleMax])
        
//        .chartXVisibleDomain(length: 3600 * 6)
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
        .padding(.top, -20)    }
}

#Preview {
    WatchAppGraphView()
}
