//
//  GlucoseActivityLiveActivity.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.09.25.
//

import ActivityKit
import Charts
import SwiftUI
import WidgetKit

//TODO: > 10–15 min: keep value visible, but add an explicit stale label like Old or No recent reading

struct FLWatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FLWatchAttributes.self) { context in
            LockScreenView(contentState: context.state)
//                .activityBackgroundTint(Color("LABackground", bundle: nil))
//                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
//                    let isStaleActivity: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleActivityAfterInterval) <= Date()
                                        
//                    var isStaleGlucose: Bool {
//                        Date().timeIntervalSince(context.state.latestTimestamp ) > FLWatchAttributes.staleGlucoseAfterInterval
//                    }
                    let isStaleGlucose: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()
                    
                    HStack {
                        Text("\(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit)) \(context.state.latestTrend)")
//                            .font(.headline)
                            .strikethrough(isStaleGlucose)
                            .bold(!isStaleGlucose)
                            .foregroundStyle(context.state.latestMeasurementColor.color)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.7)
                        
                        if context.state.currentIOB > 0 {
                            Text(context.state.currentIOBText)
//                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .allowsTightening(true)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(
                            .currentDate,
                            format: .stopwatch(
                                startingAt: context.state.latestTimestamp,
                                showsHours: false,
                                maxFieldCount: 2,
                                maxPrecision: .seconds(1)
                            )
                        )
//                            .bold()
                            .monospacedDigit()
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.7)
                            .frame(width: 50, alignment: .trailing)

//                        if context.state.currentIOB > 0 {
//                            Text("IOB \(context.state.currentIOBText)")
//                                .font(.caption2)
//                                .foregroundStyle(.secondary)
//                        }
                    }
                }
//                DynamicIslandExpandedRegion(.center) {
//                    if context.state.currentIOB > 0 {
//                        Text(context.state.currentIOBText)
//                            .font(.footnote)
//                            .foregroundStyle(.secondary)
//                            .lineLimit(1)
//                    }
//                }
                DynamicIslandExpandedRegion(.bottom) {
                    
                    GlucoseLiveActivityChart(
                        contentState: context.state,
                        showsAxes: true,
                        xAxisFont: Font.system(size: 8, weight: .regular),
                        yAxisFont: Font.system(size: 8, weight: .regular),
                        graphLineWidth: 3,
                        graphPointSize: 3,
                        minutePointSize: 8,
                        insulinMarkerFontSize: 12,
                        insulinAnnotationFont: Font.system(size: 12, weight: .regular)
                    )
//                    .padding(.top, 0)
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
//                    GlucoseLiveActivityChart(contentState: context.state, showsAxes: true)
//                        .padding(.top, 0)
//                        .frame(height: 84)
                }
            } compactLeading: {
                
                let isStaleGlucose: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()

                
                Text("\(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit)) \(context.state.latestTrend)")
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .foregroundStyle(context.state.latestMeasurementColor.color)
            } compactTrailing: {
                Text(
                    .currentDate,
                    format: .stopwatch(
                        startingAt: context.state.latestTimestamp,
                        showsHours: false,
                        maxFieldCount: 2,
                        maxPrecision: .seconds(1)
                    )
                )
                    .bold()
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            } minimal: {
  
                let isStaleGlucose: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()

                
                Text(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit))
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .foregroundStyle(context.state.latestMeasurementColor.color)
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

private struct LockScreenView: View {
    var contentState: FLWatchAttributes.ContentState
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        Group {
            switch activityFamily {
            case .small:
                SmallSupplementalActivityView(contentState: contentState)
            case .medium:
                MediumSupplementalActivityView(contentState: contentState)
            @unknown default:
                DefaultLockScreenActivityView(contentState: contentState) //currently never reached
            }
        }
    }
}

private struct DefaultLockScreenActivityView: View { // currently never displayed
    let contentState: FLWatchAttributes.ContentState

    var body: some View {
       Text("This view is replaced by the MediumSupplementalActivityView view.")
        .padding()
    }
}

private struct SmallSupplementalActivityView: View {
    let contentState: FLWatchAttributes.ContentState

    var body: some View {
        
        let isStaleGlucose: Bool = contentState.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()

        VStack (spacing: 5){
            HStack {
                Text(contentState.latestGlucoseValue.units(for: contentState.glucoseUnit))
                    .font(.footnote)
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(contentState.latestMeasurementColor.color)

                Text(contentState.latestTrend)
                    .font(.footnote)
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(contentState.latestMeasurementColor.color)

                if contentState.currentIOB > 0 {
                    Text(contentState.currentIOBText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()

                Text(
                    .currentDate,
                    format: .stopwatch(
                        startingAt: contentState.latestTimestamp,
                        showsHours: false,
                        maxFieldCount: 2,
                        maxPrecision: .seconds(1)
                    )
                )
                .font(.caption)
//                    .bold()
                    .monospacedDigit()
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.7)
                    .frame(width: 50, alignment: .trailing)

            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlucoseLiveActivityChart(
                contentState: contentState,
                showsAxes: true,
                xAxisFont: Font.system(size: 8, weight: .regular),
                yAxisFont: Font.system(size: 8, weight: .regular),
                graphLineWidth: 2,
                graphPointSize: 2,
                minutePointSize: 5,
                insulinMarkerFontSize: 8,
                insulinAnnotationFont: Font.system(size: 8, weight: .regular)
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
//        .overlay {
//            if isStale {
//                Text("Activity has not been updated for \(staleAfterMinutes) mins. Tap to refresh")
//                    .font(.caption2)
//                    .foregroundStyle(.secondary)
//            }
//        }
        .padding(5)
    }
}

private struct MediumSupplementalActivityView: View {
    let contentState: FLWatchAttributes.ContentState
    
    var body: some View {
        // Show the manual-refresh affordance once a new reading is overdue by
        // one source cadence (Libre 1 min, Dexcom 5 min).
        let updateUIAfter = TimeInterval(SharedData.cgmProviderKind.cadenceMinutes * 60)
        let isUpdateUI: Bool = contentState.latestTimestamp.addingTimeInterval(updateUIAfter) <= Date()
        let isStaleGlucose: Bool = contentState.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()

        VStack (spacing: 8){
            HStack {
                Text(contentState.latestGlucoseValue.units(for: contentState.glucoseUnit))
//                    .font(.title)
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(contentState.latestMeasurementColor.color)

                Text(contentState.latestTrend)
//                    .font(.title)
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .foregroundStyle(contentState.latestMeasurementColor.color)

                if contentState.currentIOB > 0 {
                    Text("IOB \(contentState.currentIOBText)")
//                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isUpdateUI {
                    HStack(spacing: 6) {
                        Text("Update")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(intent: RefreshLiveActivityIntent()) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
//                    .frame(maxWidth: .infinity, alignment: .trailing)
                }



                Text(
                    .currentDate,
                    format: .stopwatch(
                        startingAt: contentState.latestTimestamp,
                        showsHours: false,
                        maxFieldCount: 2,
                        maxPrecision: .seconds(1)
                    )
                )
//                    .bold()
                    .monospacedDigit()
                    .lineLimit(1)
//                    .truncationMode(.head)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.7)
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

                      GlucoseLiveActivityChart(
                contentState: contentState,
                showsAxes: true,
                xAxisFont: .footnote,
                yAxisFont: .footnote,
                graphLineWidth: 3,
                graphPointSize: 3,
                minutePointSize: 10,
                insulinMarkerFontSize: 12,
                insulinAnnotationFont: .footnote
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
//        .overlay {
//            if isStaleGlucose {
//                Text("Activity has not been updated for \(staleAfterMinutes) mins. Tap to refresh")
//                    .font(.caption2)
//                    .foregroundStyle(.secondary)
//            }
//        }
        .padding()
    }
}

private struct GlucoseLiveActivityChart: View {
    let contentState: FLWatchAttributes.ContentState
    let showsAxes: Bool
    let xAxisFont: Font
    let yAxisFont: Font
    let graphLineWidth: CGFloat
    let graphPointSize: CGFloat
    let minutePointSize: CGFloat
    let insulinMarkerFontSize: CGFloat
    let insulinAnnotationFont: Font

    init(
        contentState: FLWatchAttributes.ContentState,
        showsAxes: Bool,
        xAxisFont: Font = .caption,
        yAxisFont: Font = .caption,
        graphLineWidth: CGFloat? = nil,
        graphPointSize: CGFloat? = nil,
        minutePointSize: CGFloat? = nil,
        insulinMarkerFontSize: CGFloat? = nil,
        insulinAnnotationFont: Font? = nil
    ) {
        self.contentState = contentState
        self.showsAxes = showsAxes
        self.xAxisFont = xAxisFont
        self.yAxisFont = yAxisFont
        self.graphLineWidth = graphLineWidth ?? (showsAxes ? 4 : 3)
        self.graphPointSize = graphPointSize ?? (showsAxes ? 6 : 4)
        self.minutePointSize = minutePointSize ?? (showsAxes ? 18 : 12)
        self.insulinMarkerFontSize = insulinMarkerFontSize ?? (showsAxes ? 15 : 12)
        self.insulinAnnotationFont = insulinAnnotationFont ?? (showsAxes ? .footnote : .caption2)
    }

    private var chartXScaleMin: Date {
        Date().addingTimeInterval(-6 * 60 * 60 - 10 * 60)
    }

    private var chartXScaleMax: Date {
        Date()
    }

    private var chartYScaleMin: Double {
        contentState.glucoseUnit == 0 ? 2.75 : 50
    }

    private var chartYScaleMax: Double {
        let maxBG = max(contentState.maxGlucoseValue, contentState.graphPoints.map(\.valueInMgPerDl).max() ?? contentState.latestGlucoseValue)
        if maxBG > 350 {
            return contentState.glucoseUnit == 0 ? 27 : 500
        } else if maxBG > 250 {
            return contentState.glucoseUnit == 0 ? 21 : 350
        } else {
            return contentState.glucoseUnit == 0 ? 15 : 250
        }
    }

    private var yAxisStride: Double {
        contentState.glucoseUnit == 0 ? 3 : 50
    }

    private var quarterYAxisIOBCurve: Double {
        (chartYScaleMax - chartYScaleMin) / 4 + 0.25
    }

    private var chartYScaleMinIOBCurve: Double {
        contentState.glucoseUnit == 0 ? 3 : 50
    }

    private var targetLow: Double {
        scaledValue(contentState.targetLow)
    }

    private var targetHigh: Double {
        scaledValue(contentState.targetHigh)
    }

    private var alarmLow: Double {
        scaledValue(contentState.alarmLow)
    }

    var body: some View {
        Chart {
            RectangleMark(
                xStart: .value("Rect Start Width", chartXScaleMin),
                xEnd: .value("Rect End Width", chartXScaleMax),
                yStart: .value("Rect Start Height", targetLow),
                yEnd: .value("Rect End Height", targetHigh)
            )
            .opacity(0.2)
            .foregroundStyle(.green)

            if contentState.alarmLow >= SensorSettings.minDrawableAlarmMgDl {
                RuleMark(y: .value("Lower limit", alarmLow))
                    .foregroundStyle(.red)
                    .lineStyle(.init(lineWidth: 1, dash: [2]))
            }

            ForEach(contentState.graphPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Glucose", scaledValue(point.valueInMgPerDl)),
                    series: .value("Curve", "Glucose")
                )
                .interpolationMethod(.linear)
                .lineStyle(.init(lineWidth: graphLineWidth))
//                .foregroundStyle(.white)
                .symbol {
                    Circle()
                        .fill(measurementColor(for: point.colorRawValue).color)
                        .frame(width: graphPointSize, height: graphPointSize)
                }
            }

            ForEach(contentState.minutePoints) { point in
                let minuteGlucoseColor = Color(red: 0.96, green: 0.78, blue: 0.18) // #F5C72E
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Glucose", scaledValue(point.valueInMgPerDl))
                )
                .foregroundStyle(minuteGlucoseColor)
                .symbolSize(minutePointSize)
            }

            if contentState.showIOBCurve, !contentState.iobPoints.isEmpty {
                ForEach(contentState.iobPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Insulin", scaledIOBValue(point.iobValue)),
                        series: .value("Curve", "Insulin")
                    )
                    .foregroundStyle(.orange)
                }
            }

            if contentState.showInsulinDeliveryMarks, !contentState.insulinMarkers.isEmpty {
                ForEach(contentState.insulinMarkers) { marker in
                    PointMark(
                        x: .value("Time", marker.timestamp),
                        y: .value("Insulin", markerYPosition(for: marker))
                    )
                    .symbol {
                        Image(systemName: "arrowtriangle.down.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: insulinMarkerFontSize))
                    }
                    .annotation(alignment: markerAlignment(for: marker.timestamp)) {
                        Text(marker.unitsText)
                            .font(insulinAnnotationFont)
                    }
                }
            }

            if contentState.showActivityCurve, !contentState.activityPoints.isEmpty {
                ForEach(contentState.activityPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Activity", scaledActivityValue(point.activityValue)),
                        series: .value("Curve", "Activity")
                    )
                    .foregroundStyle(.brown)
                }
            }
        }
//        .chartForegroundStyleScale([
//            "Glucose": Color.white
//        ])
        .chartXScale(domain: [chartXScaleMin, chartXScaleMax])
        .chartYScale(domain: [chartYScaleMin, chartYScaleMax])
        .if(showsAxes) { chart in
            chart
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
                        AxisTick(length: -5, stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                        AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)), anchor: .top)
                            .font(xAxisFont)
                    }
                    AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                        //                        AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
                        AxisTick(length: -5, stroke: .init(lineWidth: 1))
                            .foregroundStyle(.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: yAxisStride)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                            .foregroundStyle(.gray.opacity(0.4))
                        AxisValueLabel()
                            .font(yAxisFont)
                    }
                }
        }
        .if(!showsAxes) { chart in
            chart
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
        }
    }

    private func scaledValue(_ valueInMgPerDl: Int) -> Double {
        valueInMgPerDl.displayedGlucoseValue(glucoseUnitValue: contentState.glucoseUnit)
    }

    private func scaledIOBValue(_ value: Double) -> Double {
        chartYScaleMinIOBCurve + value * quarterYAxisIOBCurve / contentState.maxIOB
    }

    private func scaledActivityValue(_ value: Double) -> Double {
        chartYScaleMinIOBCurve + value * quarterYAxisIOBCurve / contentState.maxActivity
    }

    private func markerYPosition(for marker: FLWatchAttributes.InsulinMarker) -> Double {
        let shiftInYValue = showsAxes ? 10 : 5
        let shiftInY = contentState.glucoseUnit == 0 ? Double(shiftInYValue).toMmolL() : Double(shiftInYValue)
        let curvePoint = contentState.iobPoints.first(where: { $0.timestamp > marker.timestamp })
        return chartYScaleMinIOBCurve + shiftInY + scaledIOBComponent(curvePoint?.iobValue ?? 0, maxValue: contentState.maxIOB)
    }

    private func scaledIOBComponent(_ value: Double, maxValue: Double) -> Double {
        value * quarterYAxisIOBCurve / maxValue
    }

    private func markerAlignment(for timestamp: Date) -> Alignment {
        let timestampValue = timestamp.timeIntervalSince1970
        let chartMin = chartXScaleMin.timeIntervalSince1970
        let chartMax = chartXScaleMax.timeIntervalSince1970
        let edgePadding: TimeInterval = 30 * 60

        if timestampValue > chartMax - edgePadding {
            return .trailing
        } else if timestampValue < chartMin + edgePadding {
            return .leading
        }
        return .center
    }

    private func measurementColor(for rawValue: Int) -> MeasurementColor {
        MeasurementColor(rawValue: rawValue) ?? .gray
    }
}

private extension FLWatchAttributes.ContentState {
    var unitString: String {
        glucoseUnit == 0 ? "mmol/L" : "mg/dL"
    }

    var currentIOB: Double {
        Double(currentIOBInHundredths) / Double(FLWatchAttributes.iobValueScale)
    }

    var maxIOB: Double {
        max(Double(maxIOBInHundredths) / Double(FLWatchAttributes.iobValueScale), 0.01)
    }

    var maxActivity: Double {
        max(Double(maxActivityInHundredths) / Double(FLWatchAttributes.activityValueScale), 0.01)
    }

    var currentIOBText: String {
        String(format: "%.2fu", currentIOB)
    }
}

private extension FLWatchAttributes.ActivityPoint {
    var iobValue: Double {
        Double(valueInHundredths) / Double(FLWatchAttributes.iobValueScale)
    }

    var activityValue: Double {
        Double(valueInHundredths) / Double(FLWatchAttributes.activityValueScale)
    }
}

private extension FLWatchAttributes.InsulinMarker {
    var unitsText: String {
        String(format: "%.1fu", Double(insulinUnitsInHundredths) / 100)
    }
}

private extension Int {
    func units(for glucoseUnit: Int) -> String {
        asGlucose(glucoseUnitValue: glucoseUnit)
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview("Live Activity Content", as: .content, using: FLWatchAttributes()) {
    FLWatchLiveActivityWidget()
} contentStates: {
    FLWatchAttributes.ContentState.preview
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: FLWatchAttributes()) {
    FLWatchLiveActivityWidget()
} contentStates: {
    FLWatchAttributes.ContentState.preview
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: FLWatchAttributes()) {
    FLWatchLiveActivityWidget()
} contentStates: {
    FLWatchAttributes.ContentState.preview
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: FLWatchAttributes()) {
    FLWatchLiveActivityWidget()
} contentStates: {
    FLWatchAttributes.ContentState.preview
}

private extension FLWatchAttributes.ContentState {
    static var preview: Self {
        let now = Date.now

        return .init(
            latestGlucoseValue: 142,
            latestTrend: "↗",
            latestTimestamp: now - 30,
            latestColor: MeasurementColor.green.rawValue,
            graphPoints: [
                .init(timestamp: now.addingTimeInterval(-6 * 60 * 60), valueInMgPerDl: 118, colorRawValue: MeasurementColor.green.rawValue),
                .init(timestamp: now.addingTimeInterval(-5 * 60 * 60), valueInMgPerDl: 126, colorRawValue: MeasurementColor.green.rawValue),
                .init(timestamp: now.addingTimeInterval(-4 * 60 * 60), valueInMgPerDl: 132, colorRawValue: MeasurementColor.green.rawValue),
                .init(timestamp: now.addingTimeInterval(-3 * 60 * 60), valueInMgPerDl: 190, colorRawValue: MeasurementColor.yellow.rawValue),
                .init(timestamp: now.addingTimeInterval(-2 * 60 * 60), valueInMgPerDl: 195, colorRawValue: MeasurementColor.yellow.rawValue),
                .init(timestamp: now.addingTimeInterval(-60 * 60), valueInMgPerDl: 160, colorRawValue: MeasurementColor.green.rawValue),
                .init(timestamp: now, valueInMgPerDl: 142, colorRawValue: MeasurementColor.green.rawValue)
            ],
            minutePoints: [
                .init(timestamp: now.addingTimeInterval(-15 * 60), valueInMgPerDl: 140, colorRawValue: MeasurementColor.yellow.rawValue),
                .init(timestamp: now.addingTimeInterval(-10 * 60), valueInMgPerDl: 141, colorRawValue: MeasurementColor.yellow.rawValue),
                .init(timestamp: now.addingTimeInterval(-5 * 60), valueInMgPerDl: 142, colorRawValue: MeasurementColor.yellow.rawValue)
            ],
            glucoseUnit: 1,
            targetLow: 70,
            targetHigh: 180,
            alarmLow: 85,
            maxGlucoseValue: 180,
            currentIOBInHundredths: 138,
            iobPoints: [
                .init(timestamp: now.addingTimeInterval(-3 * 60 * 60), valueInHundredths: 180),
                .init(timestamp: now.addingTimeInterval(-2 * 60 * 60), valueInHundredths: 160),
                .init(timestamp: now.addingTimeInterval(-60 * 60), valueInHundredths: 138),
                .init(timestamp: now.addingTimeInterval(-0), valueInHundredths: 70)
            ],
            maxIOBInHundredths: 180,
            activityPoints: [
                .init(timestamp: now.addingTimeInterval(-3 * 60 * 60), valueInHundredths: 50),
                .init(timestamp: now.addingTimeInterval(-2 * 60 * 60), valueInHundredths: 400),
                .init(timestamp: now.addingTimeInterval(-60 * 60), valueInHundredths: 300),
                .init(timestamp: now.addingTimeInterval(-0), valueInHundredths: 100)
            ],
            maxActivityInHundredths: 250,
            insulinMarkers: [
                .init(timestamp: now.addingTimeInterval(-3 * 60 * 60), insulinUnitsInHundredths: 250),
                .init(timestamp: now.addingTimeInterval(-75 * 60), insulinUnitsInHundredths: 150)
            ],
            showIOBCurve: true,
            showActivityCurve: true,
            showInsulinDeliveryMarks: true
        )
    }
}
private extension FLWatchAttributes.ContentState {
    var latestMeasurementColor: MeasurementColor {
        MeasurementColor(rawValue: latestColor) ?? .gray
    }
}
