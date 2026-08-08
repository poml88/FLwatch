
//
//  WatchAppGraphView.swift
//  FLwatch
//
//  Created by Peter Müller on 25.07.25.
//

import SwiftUI
import Charts

struct WatchAppGraphView: View {
    // On watchOS 11+ Charts renders these compact models as vectorized plots
    // instead of building a LineMark and a custom SwiftUI symbol subtree for
    // every reading. Both paths resolve the per-point color once here instead of
    // looking it up per mark, so `id` is only needed by the watchOS 10 ForEach.
    private struct GlucosePlotPoint: Identifiable {
        let id: Int
        let timestamp: Date
        let value: Double
        let color: Color
    }

    private struct PlotPoint: Identifiable {
        let id: Int
        let timestamp: Date
        let value: Double
    }

    private struct InsulinMarkerPoint: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
        let insulinUnits: Double
        let alignment: Alignment
    }
    
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
        let glucosePointDiameter: CGFloat = 4

        let date: Date = Date.now
        
        let dateSixHoursTenAgo: Date = date.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
        let timeIntervalSince1970: Double = date.timeIntervalSince1970
        let chartStartTimestamp: Double = timeIntervalSince1970 - 3600 * 6 - 60 * 10


        let rectXStart: Date = dateSixHoursTenAgo
        let rectXStop: Date = date

        //Configuration
        // Resolved once: the per-point loops below would otherwise re-read the
        // observable settings store and rebuild the unit for every reading.
        let sensorSettings = sensorSettingsStore.sensorSettings
        let glucoseUnit = GlucoseUnit(uom: sensorSettings.uom)
        let displaysMmol = glucoseUnit == .mmoll
        let chartYScaleMin: Double = displaysMmol ? 2.75 : 50

        let maxBG = libreLinkUpHistory.maxBG

        let chartXScaleMin: Date = dateSixHoursTenAgo
        let chartXScaleMax: Date = date

        // Tighter tiers than the phone: the watch chart is much shorter, so the
        // usable range is capped lower.
        let chartYScaleMax: Double = if maxBG > 300 {
            displaysMmol ? 21 : 400
        } else if maxBG > 225 {
            displaysMmol ? 18 : 300
        } else {
            displaysMmol ? 12.5 : 225
        }

        let quarterYAxisIOBCurve: Double = (chartYScaleMax - chartYScaleMin) / 4 + 0.25
        let chartYScaleMinIOBCurve: Double = displaysMmol ? 3 : 50

        let yAxisSteps: Double = displaysMmol ? 3 : 50


        let chartRectangleYStart = displaysMmol ? sensorSettings.targetLow.toMmolL() : Double(sensorSettings.targetLow)
        let chartRectangleYEnd = displaysMmol ? sensorSettings.targetHigh.toMmolL() : Double(sensorSettings.targetHigh)
        let chartRuleAlarmLL = displaysMmol ? sensorSettings.alarmLow.toMmolL() : Double(sensorSettings.alarmLow)
        let graphData = libreLinkUpHistory.libreLinkUpGlucose.filter { $0.glucose.date > dateSixHoursTenAgo }
        let minuteGlucose = Array(libreLinkUpHistory.libreLinkUpMinuteGlucose.dropFirst())
        let insulinHistory = InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory
        let insulinOnBoardCurve = currentIOBSingleton.insulinOnBoardCurve
        let insulinActivityCurve = currentIOBSingleton.insulinActivityCurve
        let safeMaxIOB = max(currentIOBSingleton.maxIOB, 0.01)
        let safeMaxActivity = max(currentIOBSingleton.maxActivity, 0.01)
        let iobScale = quarterYAxisIOBCurve / safeMaxIOB
        let activityScale = quarterYAxisIOBCurve / safeMaxActivity
        // Wider than the phone's 5 mg/dL so the markers clear the IOB curve on
        // the shorter watch chart; the alignment thresholds are wider too.
        let insulinMarkerShift = displaysMmol ? Double(10).toMmolL() : 10
        let trailingMarkerThreshold = timeIntervalSince1970 - 40 * 60
        let leadingMarkerThreshold = timeIntervalSince1970 - 3600 * 6 + 40 * 60
        let glucoseChartPoints: [GlucosePlotPoint] = graphData.compactMap { item in
            let yValue = item.glucose.value.displayedGlucoseValue(glucoseUnit: glucoseUnit)
            guard yValue.isFinite else { return nil }
            return GlucosePlotPoint(id: item.id, timestamp: item.glucose.date, value: yValue, color: item.color.color)
        }

        let minuteGlucoseChartPoints: [PlotPoint] = minuteGlucose.compactMap { item in
            let yValue = item.glucose.value.displayedGlucoseValue(glucoseUnit: glucoseUnit)
            guard yValue.isFinite else { return nil }
            return PlotPoint(id: item.id, timestamp: item.glucose.date, value: yValue)
        }

        let iobChartPoints: [PlotPoint] = showIOBCurveWatch
            ? insulinOnBoardCurve.compactMap { item in
                let yValue = chartYScaleMinIOBCurve + item.value * iobScale
                guard yValue.isFinite else { return nil }
                return PlotPoint(id: item.id, timestamp: item.date, value: yValue)
            }
            : []

        let activityChartPoints: [PlotPoint] = showActivityCurveWatch
            ? insulinActivityCurve.compactMap { item in
                let yValue = chartYScaleMinIOBCurve + item.value * activityScale
                guard yValue.isFinite else { return nil }
                return PlotPoint(id: item.id, timestamp: item.date, value: yValue)
            }
            : []

        let insulinMarkerPoints: [InsulinMarkerPoint] = showInsulinDeliveryMarksWatch
            ? insulinHistory.compactMap { item in
                guard item.timeStamp > chartStartTimestamp else { return nil }

                let markerDate = Date(timeIntervalSince1970: item.timeStamp)
                let iobValueAtTimestamp = insulinOnBoardCurve.first(where: {
                    $0.date > markerDate
                })?.value ?? 1

                let yValue = chartYScaleMinIOBCurve + insulinMarkerShift + iobValueAtTimestamp * iobScale
                guard yValue.isFinite else { return nil }

                let alignment: Alignment
                if item.timeStamp > trailingMarkerThreshold {
                    alignment = .trailing
                } else if item.timeStamp < leadingMarkerThreshold {
                    alignment = .leading
                } else {
                    alignment = .center
                }

                return InsulinMarkerPoint(
                    id: item.id,
                    date: markerDate,
                    value: yValue,
                    insulinUnits: item.insulinUnits,
                    alignment: alignment
                )
            }
            : []
        
        
        // The vectorized plots need watchOS 11, so the two chart bodies are kept
        // apart at the view level. Mixing them inside one Chart is not possible:
        // ChartContentBuilder swaps buildPartialBlock for a variadic buildBlock
        // exactly at watchOS 11, so a multi-mark `if #available` block inside a
        // Chart has no builder that covers both sides. The chart modifiers below
        // are View modifiers and apply to whichever branch is used.
        Group {
            if #available(watchOS 11.0, *) {
                Chart {
//MARK: Range Rectangle and Alarm Rules
                    rangeRectangle(xStart: rectXStart, xEnd: rectXStop, yStart: chartRectangleYStart, yEnd: chartRectangleYEnd)

                    if sensorSettings.hasDrawableLowAlarm {
                        alarmRule(chartRuleAlarmLL)
                    }

//MARK: Glucose Graph
                    // Keep the continuous line separate from the independently
                    // colored points while rendering each as a single plot.
                    LinePlot(
                        glucoseChartPoints,
                        x: .value("Time", \.timestamp),
                        y: .value("Glucose", \.value),
                        series: .value("Curve", "Glucose")
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(.init(lineWidth: 3))

                    PointPlot(
                        glucoseChartPoints,
                        x: .value("Time", \.timestamp),
                        y: .value("Glucose", \.value)
                    )
                    // Keep vectorized key-path modifiers before modifiers that
                    // return only `some ChartContent`, such as the symbol size.
                    .foregroundStyle(\.color)
                    // symbolSize takes an area in pt², while glucosePointDiameter
                    // is the diameter the Circle symbol uses below. Convert that
                    // diameter to circle area so both paths draw the same size.
                    .symbolSize(.pi * glucosePointDiameter * glucosePointDiameter / 4)

//MARK: Minute Glucose Trend
                    PointPlot(
                        minuteGlucoseChartPoints,
                        x: .value("Time", \.timestamp),
                        y: .value("Glucose", \.value)
                    )
                    .foregroundStyle(minuteGlucoseColor)
                    .symbolSize(8)

//MARK: IOB Curve
                    if showIOBCurveWatch, !insulinHistory.isEmpty, !iobChartPoints.isEmpty {
                        LinePlot(
                            iobChartPoints,
                            x: .value("Time", \.timestamp),
                            y: .value("Insulin", \.value),
                            series: .value("Curve", "Insulin")
                        )
                        .foregroundStyle(.orange)
                    }

//MARK: Insulin delivery marks
                    if showInsulinDeliveryMarksWatch, !insulinMarkerPoints.isEmpty {
                        insulinMarkers(insulinMarkerPoints)
                    }

//MARK: Insulin activity graph
                    if showActivityCurveWatch, !insulinHistory.isEmpty, !activityChartPoints.isEmpty {
                        LinePlot(
                            activityChartPoints,
                            x: .value("Time", \.timestamp),
                            y: .value("Activity", \.value),
                            series: .value("Curve", "Activity")
                        )
                        .foregroundStyle(.brown)
                    }
                }
            } else {
                // watchOS 10 fallback. It builds a SwiftUI symbol subtree per
                // reading, which is the cost the vectorized branch above avoids,
                // and it only ever runs on Series 4/5/SE1 — the last models that
                // cannot go past watchOS 10. Deliberately left unoptimized: that
                // hardware ages out on its own. Keep it working, don't tune it.
                Chart {
//MARK: Range Rectangle and Alarm Rules
                    rangeRectangle(xStart: rectXStart, xEnd: rectXStop, yStart: chartRectangleYStart, yEnd: chartRectangleYEnd)

                    if sensorSettings.hasDrawableLowAlarm {
                        alarmRule(chartRuleAlarmLL)
                    }

//MARK: Glucose Graph
                    ForEach(glucoseChartPoints) { item in
                        LineMark(x: .value("Time", item.timestamp),
                                 y: .value("Glucose", item.value),
                                 series: .value("Curve", "Glucose")
                        )
                        .interpolationMethod(.linear)
                        .lineStyle(.init(lineWidth: 3))
                        .symbol(){
                            Circle()
                                .fill(item.color)
                                .frame(width: glucosePointDiameter, height: glucosePointDiameter)
                        }
                    }

//MARK: Minute Glucose Trend
                    ForEach(minuteGlucoseChartPoints) { item in
                        PointMark(x: .value("Time", item.timestamp),
                                  y: .value("Glucose", item.value)
                        )
                        .foregroundStyle(minuteGlucoseColor)
                        .symbolSize(8)
                    }

//MARK: IOB Curve
                    if showIOBCurveWatch, !insulinHistory.isEmpty, !iobChartPoints.isEmpty {
                        ForEach(iobChartPoints) { item in
                            LineMark(x: .value("Time", item.timestamp),
                                     y: .value("Insulin", item.value),
                                     series: .value("Curve", "Insulin")
                            )
                            .foregroundStyle(.orange)
                        }
                    }

//MARK: Insulin delivery marks
                    if showInsulinDeliveryMarksWatch, !insulinMarkerPoints.isEmpty {
                        insulinMarkers(insulinMarkerPoints)
                    }

//MARK: Insulin activity graph
                    if showActivityCurveWatch, !insulinHistory.isEmpty, !activityChartPoints.isEmpty {
                        ForEach(activityChartPoints) { item in
                            LineMark(x: .value("Time", item.timestamp),
                                     y: .value("Activity", item.value),
                                     series: .value("Curve", "Activity")
                            )
                            .foregroundStyle(Color.brown)
                        }
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

    // Content that is identical on both paths. Each returns a single mark, so no
    // result builder is involved and both watchOS generations accept them.
    private func rangeRectangle(xStart: Date, xEnd: Date, yStart: Double, yEnd: Double) -> some ChartContent {
        RectangleMark(
            xStart: .value("Rect Start Width", xStart),
            xEnd: .value("Rect End Width", xEnd),
            yStart: .value("Rect Start Height", yStart),
            yEnd: .value("Rect End Height", yEnd)
        )
        .opacity(0.2)
        .foregroundStyle(.green)
    }

    private func alarmRule(_ value: Double) -> some ChartContent {
        RuleMark(y: .value("Lower limit", value))
            .foregroundStyle(.red)
            .lineStyle(.init(lineWidth: 1, dash: [2]))
    }

    private func insulinMarkers(_ points: [InsulinMarkerPoint]) -> some ChartContent {
        ForEach(points) { item in
            PointMark(x: .value("Time", item.date),
                      y: .value("Insulin", item.value)
            )
            .symbol {
                Image(systemName: "arrowtriangle.down.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 15))   // default
            }
            .annotation(alignment: item.alignment) {
                Text("\(item.insulinUnits, specifier: "%.1f")u")
                    .font(.footnote)
            }
        }
    }
}

#Preview {
    WatchAppGraphView()
}
