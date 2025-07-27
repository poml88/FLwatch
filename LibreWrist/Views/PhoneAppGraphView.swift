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
    
    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    
    var body: some View {
        let rectXStart: Date = libreLinkUpHistory.libreLinkUpGlucose.last?.glucose.date ?? Date(timeIntervalSinceNow: -6 * 60 * 60)
        let rectXStop: Date = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date(timeIntervalSinceNow: -1 * 60)
        
        //Configuration
        // 0 = mmoll  1 = mgdl  0.0555
        var chartYScaleMin: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 2.75 : 50 }
        
        
        
        let indexOfMaxGlucoseItem = libreLinkUpHistory.libreLinkUpGlucose.indices.max(by:
                                                                                        { libreLinkUpHistory.libreLinkUpGlucose[$0].glucose.value < libreLinkUpHistory.libreLinkUpGlucose[$1].glucose.value }
        ) ?? 250
        let maxBG: Int = libreLinkUpHistory.libreLinkUpGlucose[indexOfMaxGlucoseItem].glucose.value
        
        
        var chartYScaleMax: Double { if maxBG > 350 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 27 : 500}
            else if maxBG > 250 { sensorSettingsSingleton.sensorSettings.uom == 0 ? 21 : 350}
            else { sensorSettingsSingleton.sensorSettings.uom == 0 ? 15 : 250}
        }
        
        var yAxisSteps: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? 3 : 50 }
        
        
        var chartRectangleYStart: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.targetLow.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.targetLow) }
        var chartRectangleYEnd: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.targetHigh.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.targetHigh) }
        var chartRuleAlarmLL: Double { sensorSettingsSingleton.sensorSettings.uom == 0 ? sensorSettingsSingleton.sensorSettings.alarmLow.toMmolL() : Double(sensorSettingsSingleton.sensorSettings.alarmLow) }

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
        .padding()    }
}

#Preview {
    PhoneAppGraphView()
}
