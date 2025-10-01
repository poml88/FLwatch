//
//  GlucoseActivityLiveActivity.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.09.25.
//

// FLWatchLiveActivityWidget.swift
import WidgetKit
import SwiftUI
import ActivityKit
import Charts

struct FLWatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FLWatchAttributes.self) { context in
            // Lock screen / Dynamic Island compact presentation
            LockScreenView(contentState: context.state)
                .activityBackgroundTint(Color("LABackground", bundle: nil))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("\(context.state.latestGlucoseValue)")
                            .font(.title2)
                            .bold()
                        Text(context.state.trend)
                            .font(.footnote)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // small chart in trailing region
                    MiniChartView(points: context.state.graphPoints)
                        .frame(width: 110, height: 54)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(DateFormatter.localizedString(from: context.state.timestamp, dateStyle: .none, timeStyle: .short))
                        .font(.caption)
                }
            } compactLeading: {
                Text("\(context.state.latestGlucoseValue)")
                    .bold()
            } compactTrailing: {
                Text(context.state.trend)
            } minimal: {
                Text("\(context.state.latestGlucoseValue)")
            }
        }
    }
}

struct LockScreenView: View {
    var contentState: FLWatchAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(contentState.latestGlucoseValue)")
                    .font(.system(size: 48, weight: .semibold))
                Spacer()
                VStack(alignment: .trailing) {
                    Text(contentState.trend)
                    Text(DateFormatter.localizedString(from: contentState.timestamp, dateStyle: .none, timeStyle: .short))
                        .font(.caption2)
                }
            }
            MiniChartView(points: contentState.graphPoints)
                .frame(height: 90)
        }
        .padding()
    }
}

struct MiniChartView: View {
    let points: [[Int]]

    var body: some View {
        // convert to series of (Date, Int)
        let data: [(Date, Int)] = points.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            let ts = TimeInterval(pair[0])
            let value = pair[1]
            return (Date(timeIntervalSince1970: ts), value)
        }

        Chart(data, id: \.0) { item in
            LineMark(
                x: .value("Time", item.0),
                y: .value("Glucose", item.1)
            )
            .interpolationMethod(.cardinal)
            PointMark(
                x: .value("Time", item.0),
                y: .value("Glucose", item.1)
            )
            .symbolSize(10)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
