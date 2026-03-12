//
//  FLwatchFullGraphWidget.swift
//  LibreWrist
//
//  Created by Peter Mueller on 11.03.26.
//

import WidgetKit
import SwiftUI
import Charts

struct FLwatchFullGraphWidgetEntryView: View {
    var entry: FullGraphProvider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) var colorScheme

    private let staleThreshold: TimeInterval = 5 * 60

    var isStaleGlucose: Bool {
        Date().timeIntervalSince(entry.date) > staleThreshold
    }

    var glucoseFontWeight: Font.Weight {
        isStaleGlucose ? .regular : .heavy
    }

    var glucose: String {
        if entry.lastGlucoseMeasurement.glucose.value <= 0 {
            return "--"
        } else if entry.uom == 1 {
            return "\(Int(entry.lastGlucoseMeasurement.glucose.value))"
        } else {
            return String(format: "%.1f", Double(entry.lastGlucoseMeasurement.glucose.value) * 0.0555)
        }
    }

    var currentIOB: String {
        if entry.currentIOB == -1 {
            return "-.-u"
        } else {
            return "\(String(format: "%.1f", entry.currentIOB))u"
        }
    }

    @ViewBuilder
    var body: some View {
        switch family {
        case .systemSmall:
            ZStack {
                colorScheme == .dark ? Color.black : entry.lastGlucoseMeasurement.color.color
                VStack {
                    HStack {
                        Spacer()
                        Text(verbatim: glucose)
                            .font(.title2.weight(glucoseFontWeight))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundColor(colorScheme == .dark ? entry.lastGlucoseMeasurement.color.color : Color.black)
                            .strikethrough(isStaleGlucose)
                        Text(verbatim: entry.lastGlucoseMeasurement.trendArrow?.symbol ?? "-")
                            .font(.title2.weight(.heavy).monospaced())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundColor(colorScheme == .dark ? entry.lastGlucoseMeasurement.color.color : Color.black)
                        Spacer()
                        Button(intent: ReloadWidgetIntent()) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundColor(colorScheme == .dark ? Color.gray : Color.black)
                        }
                    }
                    .padding(.top, 5)
                    .padding(.bottom, -2)

                    graphView()

                    HStack {
                        Spacer()
                        Text(currentIOB)
                            .font(.footnote.weight(.heavy).monospaced())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundColor(colorScheme == .dark ? Color.gray : Color.black)
                        Spacer()
                        Text(entry.date, style: .timer)
                            .font(.footnote.weight(.heavy).monospaced())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundColor(colorScheme == .dark ? Color.gray : Color.black)
                            .frame(width: 60, alignment: .trailing)
                            .monospacedDigit()
                        Spacer()
                    }
                    .padding(.bottom, 4)
                }
            }
            .containerBackground(for: .widget) {
                background()
            }

        case .systemMedium:
            ZStack {
                colorScheme == .dark ? Color.black : entry.lastGlucoseMeasurement.color.color
                HStack {
                    graphView()
                        .padding()
                        .padding(.trailing, -15)

                    VStack(alignment: .center, spacing: 0) {
                        HStack {
                            Spacer()
                            Text(verbatim: entry.lastGlucoseMeasurement.trendArrow?.symbol ?? "-")
                                .font(.system(size: 48, weight: .heavy, design: .monospaced))
                                .foregroundColor(colorScheme == .dark ? entry.lastGlucoseMeasurement.color.color : Color.black)
                                .padding(.leading, 40)
                            Spacer()
                            Button(intent: ReloadWidgetIntent()) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundColor(colorScheme == .dark ? Color.gray : Color.black)
                            }
                        }
                        Text(verbatim: glucose)
                            .font(.system(size: 52, weight: glucoseFontWeight))
                            .strikethrough(isStaleGlucose)
                            .foregroundColor(colorScheme == .dark ? entry.lastGlucoseMeasurement.color.color : Color.black)
                            .padding(.top, -5)
                        HStack(spacing: 15) {
                            Text(currentIOB)
                                .font(.body.weight(.heavy))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .foregroundColor(colorScheme == .dark ? Color.gray : Color.black)
                            Text(entry.date, style: .timer)
                                .font(.body.weight(.heavy))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .foregroundColor(colorScheme == .dark ? Color.gray : Color.black)
                                .frame(width: 60)
                                .monospacedDigit()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.trailing, 10)
                }
            }
            .containerBackground(for: .widget) {
                background()
            }

        default:
            VStack(alignment: .center) {
                Text("default")
            }
            .containerBackground(for: .widget) {
                background()
            }
        }
    }

    fileprivate func graphView() -> some View {
        let date: Date = Date.now

        let dateSixHoursTenAgo: Date = date.addingTimeInterval(-2 * 60 * 60 - 10 * 60)
        let maxBG = entry.maxBG

        var chartYScaleMin: Double { entry.uom == 0 ? 2.75 : 50 }
        var chartYScaleMax: Double {
            if maxBG > 350 {
                entry.uom == 0 ? 27 : 500
            } else if maxBG > 250 {
                entry.uom == 0 ? 21 : 350
            } else {
                entry.uom == 0 ? 15 : 250
            }
        }
        var yAxisSteps: Double { entry.uom == 0 ? 3 : 50 }

        let chartXScaleMin: Date = dateSixHoursTenAgo
        let chartXScaleMax: Date = date

        return Chart {
            if entry.graph.count > 1 {
                ForEach(entry.graph) { item in
                    var itemValue: Double {
                        entry.uom == 0 ? Double(item.glucose.value) * 0.0555 : Double(item.glucose.value)
                    }

                    LineMark(
                        x: .value("Time", item.glucose.date),
                        y: .value("Glucose", itemValue),
                        series: .value("Curve", "Glucose")
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(.init(lineWidth: 2))
                    .symbol {
                        Circle()
                            .fill(item.color.color)
                            .strokeBorder(.black, lineWidth: 0.5)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .chartXScale(domain: [chartXScaleMin, chartXScaleMax])
        .chartYScale(domain: [chartYScaleMin, chartYScaleMax])
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
                AxisTick(length: -5, stroke: .init(lineWidth: 1))
                    .foregroundStyle(entry.lastGlucoseMeasurement.glucose.value == 0 ? Color(white: 0.4) : Color.gray)
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)), anchor: .top)
            }
            AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                AxisTick(length: -5, stroke: .init(lineWidth: 1))
                    .foregroundStyle(entry.lastGlucoseMeasurement.glucose.value == 0 ? Color(white: 0.4) : Color.gray)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .stride(by: yAxisSteps)) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.5))
                    .foregroundStyle(entry.lastGlucoseMeasurement.glucose.value == 0 ? Color(white: 0.4) : Color.gray)
                AxisValueLabel()
            }
        }
    }
}

struct FLwatchFullGraphWidget: Widget {
    let kind: String = "FLwatchFullGraphWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: FullGraphProvider()
        ) { entry in
            FLwatchFullGraphWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Glucose Full Graph Widget")
        .description("This widget displays the full glucose graph and latest blood glucose value.")
        .contentMarginsDisabled()
    }
}

#Preview("fullGraphSystSma", as: .systemSmall) {
    FLwatchFullGraphWidget()
} timeline: {
    FullGraphGlucoseMeasurementIOBEntry.sampleEntry
}

#Preview("fullGraphSystMed", as: .systemMedium) {
    FLwatchFullGraphWidget()
} timeline: {
    FullGraphGlucoseMeasurementIOBEntry.sampleEntry
}
