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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit))
                            .font(.title2)
                            .bold()
                        Text(context.state.trend)
                            .font(.footnote)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    GlucoseLiveActivityChart(contentState: context.state, showsAxes: false)
                        .frame(width: 96, height: 52)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(DateFormatter.localizedString(from: context.state.timestamp, dateStyle: .none, timeStyle: .short))
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GlucoseLiveActivityChart(contentState: context.state, showsAxes: false)
                        .frame(height: 72)
                }
            } compactLeading: {
                Text(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit))
                    .bold()
            } compactTrailing: {
                Text(context.state.trend)
            } minimal: {
                Text(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit))
            }
        }
    }
}

private struct LockScreenView: View {
    var contentState: FLWatchAttributes.ContentState

    var body: some View {
        let staleAfterMinutes = Int(FLWatchAttributes.staleAfterInterval / 60)
        let isStale = contentState.timestamp.addingTimeInterval(FLWatchAttributes.staleAfterInterval) <= Date()

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
                    Text(contentState.trend)
                        .font(.headline)
                    Text(DateFormatter.localizedString(from: contentState.timestamp, dateStyle: .none, timeStyle: .short))
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

private struct GlucoseLiveActivityChart: View {
    let contentState: FLWatchAttributes.ContentState
    let showsAxes: Bool

    private var chartXScaleMin: Date {
        contentState.timestamp.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
    }

    private var chartXScaleMax: Date {
        max(contentState.timestamp, contentState.graphPoints.last?.timestamp ?? contentState.timestamp)
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
                    y: .value("Glucose", scaledValue(point.valueInMgPerDl)),
                    series: .value("Curve", "Glucose")
                )
                .interpolationMethod(.linear)
                .lineStyle(.init(lineWidth: showsAxes ? 4 : 3))
                .foregroundStyle(by: .value("Series", "Glucose"))
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
        .chartForegroundStyleScale([
            "Glucose": Color.white
        ])
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
