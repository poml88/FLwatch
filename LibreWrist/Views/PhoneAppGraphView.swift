//
//  GraphView.swift
//  FLwatch
//
//  Created by Peter Müller on 25.07.25.
//

import SwiftUI
import Charts

struct PhoneAppGraphView: View {
    
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    @Environment(\.sensorSettingsSingleton) var sensorSettingsSingleton
    
    @AppStorage(DefaultsKey.showInsulinDeliveryMarksPhone.rawValue, store: UserDefaults.group) private var showInsulinDeliveryMarksPhone: Bool = false
    @AppStorage(DefaultsKey.showIOBCurvePhone.rawValue, store: UserDefaults.group) private var showIOBCurvePhone: Bool = false
    @AppStorage(DefaultsKey.showActivityCurvePhone.rawValue, store: UserDefaults.group) private var showActivityCurvePhone: Bool = false
    
    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    
    var body: some View {
//        let rectXStart: Date = libreLinkUpHistory.libreLinkUpGlucose.last?.glucose.date ?? Date(timeIntervalSinceNow: -6 * 60 * 60)
//        let rectXStop: Date = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date(timeIntervalSinceNow: -1 * 60)
        
        let date: Date = Date.now
        
        let dateSixHoursTenAgo: Date = date.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
        let timeIntervalSince1970: Double = date.timeIntervalSince1970
        let timeInternvalSixHoursAndTenAgo: Double = timeIntervalSince1970 - 3600 * 6 - 60 * 10
        
        let rectXStart: Date = dateSixHoursTenAgo
        let rectXStop: Date = date
        
        //Configuration
        // 0 = mmoll  1 = mgdl  0.0555
        var chartYScaleMin: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 2.75 : 50 }
        
        
        let maxBG = libreLinkUpHistory.maxBG
        
        let chartXScaleMin: Date = dateSixHoursTenAgo
        let chartXScaleMax: Date = date
        
        var chartYScaleMax: Double { if maxBG > 350 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 27 : 500}
            else if maxBG > 250 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 21 : 350}
            else { sensorSettingsSingleton.sensorSettings.uom == 0 ? 15 : 250}
        }
        
        let quarterYAxisIOBCurve: Double = (chartYScaleMax - chartYScaleMin) / 4 + 0.25
        var chartYScaleMinIOBCurve: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 3 : 50 }
        
        var yAxisSteps: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 3 : 50 }
        
        
        var chartRectangleYStart: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.targetLow.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.targetLow) }
        var chartRectangleYEnd: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.targetHigh.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.targetHigh) }
        var chartRuleAlarmLL: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.alarmLow.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.alarmLow) }

        let unitString = sensorSettingsSingleton.sensorSettings.uom == 0 ? "mmol/L" : "mg/dL"
        
        
        
        Chart {
            //                    RuleMark(y: .value("Minimum High", 300))
            //                        .foregroundStyle(.clear)

//MARK: Range Rectangle and Alarm Rules
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

//MARK: Glucose Graph
            ForEach(libreLinkUpHistory.libreLinkUpGlucose) { item in
                
                //                        PointMark(x: .value("Time", item.glucose.date),
                //                                  y: .value("Glucose", item.glucose.value)
                //                        )
                //                        .foregroundStyle(item.color.color)
                //                        .symbolSize(12)
                var itemValue: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                LineMark(x: .value("Time", item.glucose.date),
                         y: .value("Glucose", itemValue),
                         series: .value("Curve", "Glucose")
                )
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
            
//MARK: Minute Glucose Trend
            ForEach(libreLinkUpHistory.libreLinkUpMinuteGlucose) { item in
                var itemValue: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                PointMark(x: .value("Time", item.glucose.date),
                          y: .value("Glucose", itemValue)
                )
                .foregroundStyle(Color.yellow)
                .symbolSize(20)
                
            }
            
//MARK: IOB Curve
            if showIOBCurvePhone == true {
                let insulinOnBoardCurve = CurrentIOBSingleton.shared.insulinOnBoardCurve
                let maxIOB = CurrentIOBSingleton.shared.maxIOB
                
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
                if showInsulinDeliveryMarksPhone == true {
                    
                    let maxIOB = CurrentIOBSingleton.shared.maxIOB
                    
                    if InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory.count > 0 {
                        ForEach(InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory) { item in
                            //                    var itemValue: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? item.glucose.value.toMmolL() : Double(item.glucose.value) }
                            if item.timeStamp > timeInternvalSixHoursAndTenAgo {
                                let insulinOnBoardCurve = CurrentIOBSingleton.shared.insulinOnBoardCurve
                                var iobCurveDataPointAtTimeStamp: ActivityCurveDataPoint { insulinOnBoardCurve.first(where: { $0.date > Date(timeIntervalSince1970: item.timeStamp)}) ?? ActivityCurveDataPoint(id: Int(item.timeStamp),date: Date(timeIntervalSince1970: item.timeStamp), value: 0)}
                                
                                var alignment: Alignment {
                                    if item.timeStamp > timeIntervalSince1970 - 30 * 60 {
                                        return .trailing
                                    } else if item.timeStamp < timeIntervalSince1970 - 3600 * 6 + 30 * 60 {
                                        return .leading
                                    } else {
                                        return .center
                                    }
                                }
                                let shiftInYValue = 5
                                var shiftInY: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? shiftInYValue.toMmolL() : Double(shiftInYValue) }
                                PointMark(x: .value("Time", Date(timeIntervalSince1970: item.timeStamp)),
                                          y: .value("Insulin", chartYScaleMinIOBCurve + shiftInY + iobCurveDataPointAtTimeStamp.value * quarterYAxisIOBCurve / maxIOB) // we need to know the IOB at this time stamp.
                                )
                                .symbol {
                                    Image(systemName: "arrowtriangle.down.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))   // default
                                }
                                .annotation(alignment: alignment) {
                                    Text("\(item.insulinUnits, specifier: "%.1f")u")
                                }
                            }
                        }
                    }
                }
                
            
            
//MARK: Insulin activity graph
            if showActivityCurvePhone == true {
                
                let insulinActivityCurve = CurrentIOBSingleton.shared.insulinActivityCurve
                let maxActivity = CurrentIOBSingleton.shared.maxActivity
                
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
        .padding()    }
}

#Preview {
    PhoneAppGraphView()
}
