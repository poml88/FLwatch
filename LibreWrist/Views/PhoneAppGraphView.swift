//
//  GraphView.swift
//  FLwatch
//
//  Created by Peter Müller on 25.07.25.
//

import SwiftUI
import Charts

struct PhoneAppGraphView: View {
    // Charts renders these compact models as vectorized plots instead of building
    // a LineMark and a custom SwiftUI symbol subtree for every reading, and lets
    // the per-point color be resolved once here instead of looked up per mark.
    private struct GlucosePlotPoint {
        let timestamp: Date
        let value: Double
        let color: Color
    }

    private struct PlotPoint {
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
    
    /// Right-hand edge of the chart window, minute-rounded by the parent (see
    /// `Date.chartWindowEnd`). Every time value below derives from it, so the whole
    /// body is a pure function of its inputs: identical inputs redraw identically,
    /// and the window advances once a minute whether or not new readings arrive.
    /// Intentionally has no default — a `Date()` default would be re-evaluated on
    /// each parent body pass and reintroduce the instability this removes.
    let windowEnd: Date

    @Environment(\.libreLinkUpHistory) var libreLinkUpHistory
    @Environment(\.sensorSettingsStore) var sensorSettingsStore
    @Environment(\.currentIOBSingleton) var currentIOBSingleton

    @AppStorage(DefaultsKey.showInsulinDeliveryMarksPhone.rawValue, store: UserDefaults.group) private var showInsulinDeliveryMarksPhone: Bool = false
    @AppStorage(DefaultsKey.showIOBCurvePhone.rawValue, store: UserDefaults.group) private var showIOBCurvePhone: Bool = false
    @AppStorage(DefaultsKey.showActivityCurvePhone.rawValue, store: UserDefaults.group) private var showActivityCurvePhone: Bool = false
    
    @State private var selectedlibreLinkHistoryPoint: LibreLinkUpGlucose?
    
    var body: some View {
//        let rectXStart: Date = libreLinkUpHistory.libreLinkUpGlucose.last?.glucose.date ?? Date(timeIntervalSinceNow: -6 * 60 * 60)
//        let rectXStop: Date = libreLinkUpHistory.libreLinkUpGlucose.first?.glucose.date ?? Date(timeIntervalSinceNow: -1 * 60)
        
//        let glucoseLineColor = Color(red: 0.54, green: 0.56, blue: 0.60)
//        let minuteGlucoseColor = Color(red: 0.58, green: 0.38, blue: 0.95)
        let minuteGlucoseColor = Color(red: 0.96, green: 0.78, blue: 0.18) // #F5C72E
        let glucosePointDiameter: CGFloat = 6

//        A good option is a slightly deeper golden yellow:
//
//        Color(red: 0.96, green: 0.78, blue: 0.18) // #F5C72E
//        Why this works:
//
//        still clearly “yellow”
//        warmer and deeper than SwiftUI .yellow
//        reads more golden/amber, so it won’t feel identical
//        stays visible in both light and dark mode
//        A couple of nearby options:
//
//        Softer gold:
//        Color(red: 0.93, green: 0.76, blue: 0.24) // #EDC13D
//        Richer amber-yellow:
//        Color(red: 0.98, green: 0.74, blue: 0.12) // #FABD1F

        
        let date: Date = windowEnd

        let dateSixHoursTenAgo: Date = date.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
        let timeIntervalSince1970: Double = date.timeIntervalSince1970
        let chartStartTimestamp: Double = timeIntervalSince1970 - 3600 * 6 - 60 * 10
        
        let rectXStart: Date = dateSixHoursTenAgo
        let rectXStop: Date = date
        
        //Configuration
        let sensorSettings = sensorSettingsStore.sensorSettings
        let glucoseUnit = GlucoseUnit(uom: sensorSettings.uom)
        let displaysMmol = glucoseUnit == .mmoll
        let chartYScaleMin: Double = displaysMmol ? 2.75 : 50
        
        
        let maxBG = libreLinkUpHistory.maxBG
        
        let chartXScaleMin: Date = dateSixHoursTenAgo
        let chartXScaleMax: Date = date
        
        let chartYScaleMax: Double = if maxBG > 350 {
            displaysMmol ? 27 : 500
        } else if maxBG > 250 {
            displaysMmol ? 21 : 350
        } else {
            displaysMmol ? 15 : 250
        }
        
        let quarterYAxisIOBCurve: Double = (chartYScaleMax - chartYScaleMin) / 4 + 0.25
        let chartYScaleMinIOBCurve: Double = displaysMmol ? 3 : 50
        
        let yAxisSteps: Double = displaysMmol ? 3 : 50
        
        
        let chartRectangleYStart = displaysMmol ? sensorSettings.targetLow.toMmolL() : Double(sensorSettings.targetLow)
        let chartRectangleYEnd = displaysMmol ? sensorSettings.targetHigh.toMmolL() : Double(sensorSettings.targetHigh)
        let chartRuleAlarmLL = displaysMmol ? sensorSettings.alarmLow.toMmolL() : Double(sensorSettings.alarmLow)

        let unitString = glucoseUnit.description
        let graphData = libreLinkUpHistory.libreLinkUpGlucose.filter { $0.glucose.date > dateSixHoursTenAgo }
        let minuteGlucose = Array(libreLinkUpHistory.libreLinkUpMinuteGlucose.dropFirst())
        let insulinHistory = InsulinDeliveryHistorySingleton.shared.insulinDeliveryHistory
        let insulinOnBoardCurve = currentIOBSingleton.insulinOnBoardCurve
        let insulinActivityCurve = currentIOBSingleton.insulinActivityCurve
        let safeMaxIOB = max(currentIOBSingleton.maxIOB, 0.01)
        let safeMaxActivity = max(currentIOBSingleton.maxActivity, 0.01)
        let iobScale = quarterYAxisIOBCurve / safeMaxIOB
        let activityScale = quarterYAxisIOBCurve / safeMaxActivity
        let insulinMarkerShift = displaysMmol ? Double(5).toMmolL() : 5
        let trailingMarkerThreshold = timeIntervalSince1970 - 30 * 60
        let leadingMarkerThreshold = timeIntervalSince1970 - 3600 * 6 + 30 * 60
        let glucoseChartPoints: [GlucosePlotPoint] = graphData.compactMap { item in
            let yValue = item.glucose.value.displayedGlucoseValue(glucoseUnit: glucoseUnit)
            guard yValue.isFinite else { return nil }
            return GlucosePlotPoint(timestamp: item.glucose.date, value: yValue, color: item.color.color)
        }

        let minuteGlucoseChartPoints: [PlotPoint] = minuteGlucose.compactMap { item in
            let yValue = item.glucose.value.displayedGlucoseValue(glucoseUnit: glucoseUnit)
            guard yValue.isFinite else { return nil }
            return PlotPoint(timestamp: item.glucose.date, value: yValue)
        }

        let iobChartPoints: [PlotPoint] = showIOBCurvePhone
            ? insulinOnBoardCurve.compactMap { item in
                let yValue = chartYScaleMinIOBCurve + item.value * iobScale
                guard yValue.isFinite else { return nil }
                return PlotPoint(timestamp: item.date, value: yValue)
            }
            : []

        let activityChartPoints: [PlotPoint] = showActivityCurvePhone
            ? insulinActivityCurve.compactMap { item in
                let yValue = chartYScaleMinIOBCurve + item.value * activityScale
                guard yValue.isFinite else { return nil }
                return PlotPoint(timestamp: item.date, value: yValue)
            }
            : []

        let insulinMarkerPoints: [InsulinMarkerPoint] = showInsulinDeliveryMarksPhone
            ? insulinHistory.compactMap { item in
                guard item.timeStamp > chartStartTimestamp else { return nil }

                let markerDate = Date(timeIntervalSince1970: item.timeStamp)
                let iobValueAtTimestamp = insulinOnBoardCurve.first(where: {
                    $0.date > markerDate
                })?.value ?? 0

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
            
            if sensorSettings.hasDrawableLowAlarm {
                RuleMark(y: .value("Lower limit", chartRuleAlarmLL))
                    .foregroundStyle(.red)
                    .lineStyle(.init(lineWidth: 1, dash: [2]))
            }

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
            // Keep the continuous line separate from the independently colored
            // points while rendering each collection as a single plot.
            LinePlot(
                glucoseChartPoints,
                x: .value("Time", \.timestamp),
                y: .value("Glucose", \.value),
                series: .value("Curve", "Glucose")
            )
            .interpolationMethod(.linear)
//                .foregroundStyle(glucoseLineColor)
            .lineStyle(.init(lineWidth: 5))

            PointPlot(
                glucoseChartPoints,
                x: .value("Time", \.timestamp),
                y: .value("Glucose", \.value)
            )
            // Keep vectorized key-path modifiers before modifiers that return
            // only `some ChartContent`, such as the constant symbol size.
            .foregroundStyle(\.color)
            // symbolSize takes an area in pt², while glucosePointDiameter is the
            // diameter used by the previous Circle frame. Convert that diameter to
            // circle area to preserve the sizing.
            .symbolSize(.pi * glucosePointDiameter * glucosePointDiameter / 4)

//MARK: Selected point
            // Only one rule is ever drawn, so it lives outside the glucose plot.
            if let selectedlibreLinkHistoryPoint, selectedlibreLinkHistoryPoint.glucose.date > dateSixHoursTenAgo {
                RuleMark(x: .value("Time", selectedlibreLinkHistoryPoint.glucose.date))
                    // Without the overflow resolution the detail box is clipped by
                    // the chart edge for readings near the start or end of the window.
                    .annotation(position: .top,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 6){
                            Text("\(selectedlibreLinkHistoryPoint.glucose.date.toLocalTime())")

                            Text("\(selectedlibreLinkHistoryPoint.glucose.value.asGlucose(glucoseUnit: glucoseUnit)) \(unitString)")
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

//MARK: Minute Glucose Trend
            PointPlot(
                minuteGlucoseChartPoints,
                x: .value("Time", \.timestamp),
                y: .value("Glucose", \.value)
            )
            .foregroundStyle(minuteGlucoseColor)
            .symbolSize(20)
            
//MARK: IOB Curve
            if showIOBCurvePhone, !insulinHistory.isEmpty, !iobChartPoints.isEmpty {
                LinePlot(
                    iobChartPoints,
                    x: .value("Time", \.timestamp),
                    y: .value("Insulin", \.value),
                    series: .value("Curve", "Insulin")
                )
                .foregroundStyle(.orange)
            }
                
//MARK: Insulin delivery marks
                if showInsulinDeliveryMarksPhone == true {
                    if !insulinMarkerPoints.isEmpty {
                        ForEach(insulinMarkerPoints) { item in
                                PointMark(x: .value("Time", item.date),
                                          y: .value("Insulin", item.value)
                                )
                                .symbol {
                                    Image(systemName: "arrowtriangle.down.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))   // default
                                }
                                .annotation(alignment: item.alignment) {
                                    Text("\(item.insulinUnits, specifier: "%.1f")u")
                                }
                        }
                    }
                }
                
            
            
//MARK: Insulin activity graph
            if showActivityCurvePhone, !insulinHistory.isEmpty, !activityChartPoints.isEmpty {
                LinePlot(
                    activityChartPoints,
                    x: .value("Time", \.timestamp),
                    y: .value("Activity", \.value),
                    series: .value("Curve", "Activity")
                )
                .foregroundStyle(Color.brown)
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
                    // minimumDistance 0 so a plain tap already shows the value;
                    // the plain TabView above has no competing horizontal swipe.
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let currentDate: Date = overlayProxy.value(atX: value.location.x) else { return }

                            // Snap to the reading nearest the finger. Matching on the
                            // rounded minute instead left the marker on its last hit
                            // whenever the touched minute held no reading. Comparing
                            // raw time intervals also keeps Calendar out of a gesture
                            // that fires on every frame.
                            let currentTimestamp = currentDate.timeIntervalSince1970
                            let nearestItem = graphData.min { lhs, rhs in
                                abs(lhs.glucose.date.timeIntervalSince1970 - currentTimestamp)
                                    < abs(rhs.glucose.date.timeIntervalSince1970 - currentTimestamp)
                            }

                            // SwiftUI does not coalesce equal @State writes, so
                            // assigning the same reading again would rebuild the whole
                            // chart on every drag update.
                            guard let nearestItem,
                                  nearestItem.glucose.date != selectedlibreLinkHistoryPoint?.glucose.date else { return }
                            self.selectedlibreLinkHistoryPoint = nearestItem
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
    PhoneAppGraphView(windowEnd: .chartWindowEnd())
}
