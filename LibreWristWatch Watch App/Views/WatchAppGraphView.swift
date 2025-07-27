
//
//  WatchAppGraphView.swift
//  FLwatch
//
//  Created by Peter Müller on 25.07.25.
//

import SwiftUI
import Charts

struct WatchAppGraphView: View {
    
    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    @Environment(\.sensorSettingsSingleton) var sensorSettingsSingleton
    
    var body: some View {
        let rectXStart: Date = libreLinkUpHistory.libreLinkUpGlucose.last?.glucose.date ?? Date(timeIntervalSinceNow: -6 * 60 * 60)
        let rectXStop: Date = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date(timeIntervalSinceNow: -1 * 60)
        
        //Configuration
        // 0 = mmoll  1 = mgdl  0.0555
        var chartYScaleMin: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 2.75 : 50 }
        
        let indexOfMaxGlucoseItem = libreLinkUpHistory.libreLinkUpGlucose.indices.max(by:
                                                                                        { libreLinkUpHistory.libreLinkUpGlucose[$0].glucose.value < libreLinkUpHistory.libreLinkUpGlucose[$1].glucose.value }
        ) ?? 225
        let maxBG: Int = libreLinkUpHistory.libreLinkUpGlucose[indexOfMaxGlucoseItem].glucose.value
        
        
        var chartYScaleMax: Double { if maxBG > 300 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 21 : 400}
            else if maxBG > 225 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 18 : 300}
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

