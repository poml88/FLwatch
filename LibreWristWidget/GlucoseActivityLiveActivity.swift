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

struct FLWatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FLWatchAttributes.self) { context in
            LockScreenView(contentState: context.state)
                .activityBackgroundTint(Color("LABackground", bundle: nil))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit)) \(context.state.latestTrend)")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(context.state.latestMeasurementColor.color)
                    
                }
                DynamicIslandExpandedRegion(.trailing) {
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
                }
//                DynamicIslandExpandedRegion(.center) {
//                    Text(DateFormatter.localizedString(from: context.state.latestTimestamp, dateStyle: .none, timeStyle: .short))
//                        .font(.caption)
//                }
                DynamicIslandExpandedRegion(.bottom) {
                    GlucoseLiveActivityChart(contentState: context.state, showsAxes: true)
//                        .frame(height: 84)
                }
            } compactLeading: {
                Text("\(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit)) \(context.state.latestTrend)")
                    .bold()
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
                Text(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit))
                    .bold()
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
                DefaultLockScreenActivityView(contentState: contentState)
            }
        }
    }
}

private struct DefaultLockScreenActivityView: View {
    let contentState: FLWatchAttributes.ContentState

    var body: some View {
        let staleAfterMinutes = Int(FLWatchAttributes.staleAfterInterval / 60)
        let isStale = contentState.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleAfterInterval) <= Date()

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contentState.latestGlucoseValue.units(for: contentState.glucoseUnit))
                        .font(.system(size: 42, weight: .semibold))
                    Text(contentState.unitString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(contentState.latestTrend)
                        .font(.headline)
                        .foregroundStyle(contentState.latestMeasurementColor.color)
                    Text(DateFormatter.localizedString(from: contentState.latestTimestamp, dateStyle: .none, timeStyle: .short))
                        .font(.caption2)
                }
            }

            GlucoseLiveActivityChart(contentState: contentState, showsAxes: true)
                .frame(height: 112)
                
            if isStale {
                Text("Activity has not been updated for \(staleAfterMinutes) mins. Tap to refresh")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private struct SmallSupplementalActivityView: View {
    let contentState: FLWatchAttributes.ContentState

    var body: some View {
        let staleAfterMinutes = Int(FLWatchAttributes.staleAfterInterval / 60)
        let isStale = contentState.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleAfterInterval) <= Date()

        VStack (spacing: 5){
            HStack {
                Text(contentState.latestGlucoseValue.units(for: contentState.glucoseUnit))
                    .font(.footnote)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(contentState.latestMeasurementColor.color)

                Text(contentState.latestTrend)
                    .font(.footnote)
                    .bold()
                    .foregroundStyle(contentState.latestMeasurementColor.color)
                
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
                .font(.footnote)
                    .bold()
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlucoseLiveActivityChart(contentState: contentState, showsAxes: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if isStale {
                Text("Activity has not been updated for \(staleAfterMinutes) mins. Tap to refresh")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(5)
    }
}

private struct MediumSupplementalActivityView: View {
    let contentState: FLWatchAttributes.ContentState
    
    var body: some View {
        let staleAfterMinutes = Int(FLWatchAttributes.staleAfterInterval / 60)
        let isStale = contentState.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleAfterInterval) <= Date()

        VStack (spacing: 8){
            HStack {
                Text(contentState.latestGlucoseValue.units(for: contentState.glucoseUnit))
                    .font(.title)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(contentState.latestMeasurementColor.color)

                Text(contentState.latestTrend)
                    .font(.title)
                    .bold()
                    .foregroundStyle(contentState.latestMeasurementColor.color)
                
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
                    .bold()
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GlucoseLiveActivityChart(contentState: contentState, showsAxes: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if isStale {
                Text("Activity has not been updated for \(staleAfterMinutes) mins. Tap to refresh")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private struct GlucoseLiveActivityChart: View {
    let contentState: FLWatchAttributes.ContentState
    let showsAxes: Bool

    private var chartXScaleMin: Date {
        contentState.latestTimestamp.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
    }

    private var chartXScaleMax: Date {
        max(contentState.latestTimestamp, contentState.graphPoints.last?.timestamp ?? contentState.latestTimestamp)
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

            RuleMark(y: .value("Lower limit", alarmLow))
                .foregroundStyle(.red)
                .lineStyle(.init(lineWidth: 1, dash: [2]))

            ForEach(contentState.graphPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Glucose", scaledValue(point.valueInMgPerDl))
                )
                .interpolationMethod(.linear)
                .lineStyle(.init(lineWidth: showsAxes ? 4 : 3))
//                .foregroundStyle(.white)
                .symbol {
                    Circle()
                        .fill(measurementColor(for: point.colorRawValue).color)
                        .frame(width: showsAxes ? 6 : 4, height: showsAxes ? 6 : 4)
                }
            }

            ForEach(contentState.minutePoints) { point in
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Glucose", scaledValue(point.valueInMgPerDl))
                )
                .foregroundStyle(Color.yellow)
                .symbolSize(showsAxes ? 18 : 12)
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
        if contentState.glucoseUnit == 0 {
            return Double(valueInMgPerDl).toMmolL()
        }
        return Double(valueInMgPerDl)
    }

    private func measurementColor(for rawValue: Int) -> MeasurementColor {
        MeasurementColor(rawValue: rawValue) ?? .gray
    }
}

private extension FLWatchAttributes.ContentState {
    var unitString: String {
        glucoseUnit == 0 ? "mmol/L" : "mg/dL"
    }
}

private extension Int {
    func units(for glucoseUnit: Int) -> String {
        if glucoseUnit == 0 {
            return String(format: "%.1f", Double(self) / 18.0182)
        }
        return String(self)
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
            alarmLow: 55,
            maxGlucoseValue: 180
        )
    }
}
private extension FLWatchAttributes.ContentState {
    var latestMeasurementColor: MeasurementColor {
        MeasurementColor(rawValue: latestColor) ?? .gray
    }
}

