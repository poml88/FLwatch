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
    
    private var smallChartStyle: FullGraphWidgetChartStyle {
        .init(
            xAxisFont: .system(size: 7, weight: .regular),
            yAxisFont: .system(size: 7, weight: .regular),
            graphLineWidth: 2,
            graphPointSize: 4,
            minutePointSize: 4,
            overlayLineWidth: 1.5,
            insulinMarkerFontSize: 8,
            insulinAnnotationFont: .system(size: 7, weight: .regular)
        )
    }
    
    private var mediumChartStyle: FullGraphWidgetChartStyle {
        .init(
            xAxisFont: .system(size: 9, weight: .regular),
            yAxisFont: .system(size: 9, weight: .regular),
            graphLineWidth: 2,
            graphPointSize: 4,
            minutePointSize: 4,
            overlayLineWidth: 2,
            insulinMarkerFontSize: 10,
            insulinAnnotationFont: .system(size: 9, weight: .regular)
        )
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
                    
                    graphView(style: smallChartStyle)
                    
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
                    graphView(style: mediumChartStyle)
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
    
    fileprivate func graphView(style: FullGraphWidgetChartStyle) -> some View {
        FullGraphWidgetChart(entry: entry, showsAxes: true, style: style)
    }
}

private struct FullGraphWidgetChartStyle {
    let xAxisFont: Font
    let yAxisFont: Font
    let graphLineWidth: CGFloat
    let graphPointSize: CGFloat
    let minutePointSize: CGFloat
    let overlayLineWidth: CGFloat
    let insulinMarkerFontSize: CGFloat
    let insulinAnnotationFont: Font
}

private struct FullGraphWidgetChart: View {
    let entry: FullGraphGlucoseMeasurementIOBEntry
    let showsAxes: Bool
    let style: FullGraphWidgetChartStyle
    
    @Environment(\.colorScheme) private var colorScheme
    
    //    private let glucoseLineColor = Color(red: 0.54, green: 0.56, blue: 0.60)
    private let minuteGlucoseColor = Color(red: 0.96, green: 0.78, blue: 0.18) // #F5C72E
    
    private var IOBMarksLineColor: Color { entry.lastGlucoseMeasurement.color.color == .orange ? Color(red: 0.90, green: 0.52, blue: 0.12) : .orange }
    
    private let date: Date = Date.now
    
    private var chartXScaleMin: Date {
        date.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
    }
    
    private var chartXScaleMax: Date {
        date
    }
    
    private var chartYScaleMin: Double {
        entry.uom == 0 ? 2.75 : 50
    }
    
    private var chartYScaleMax: Double {
        let maxGlucoseValue = max(
            entry.maxBG,
            entry.graph.map(\.glucose.value).max() ?? 0,
            entry.minutePoints.map(\.valueInMgPerDl).max() ?? 0
        )
        if maxGlucoseValue > 350 {
            return entry.uom == 0 ? 27 : 500
        } else if maxGlucoseValue > 250 {
            return entry.uom == 0 ? 21 : 350
        } else {
            return entry.uom == 0 ? 15 : 250
        }
    }
    
    private var yAxisStride: Double {
        entry.uom == 0 ? 3 : 50
    }
    
    private var quarterYAxisIOBCurve: Double {
        (chartYScaleMax - chartYScaleMin) / 4 + 0.25
    }
    
    private var chartYScaleMinIOBCurve: Double {
        entry.uom == 0 ? 3 : 50
    }
    
    private var maxIOB: Double {
        max(entry.maxIOB, 0.01)
    }
    
    private var maxActivity: Double {
        max(entry.maxActivity, 0.01)
    }
    
    private var targetLow: Double {
        scaledValue(entry.targetLow)
    }
    
    private var targetHigh: Double {
        scaledValue(entry.targetHigh)
    }
    
    private var alarmLow: Double {
        scaledValue(entry.alarmLow)
    }
    
    var body: some View {
        if showsAxes {
            baseChart
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5, dash: [2, 3]))
                        AxisTick(length: -5, stroke: .init(lineWidth: 1))
                        //                            .foregroundStyle(.gray)
                        AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)), anchor: .top)
                            .font(style.xAxisFont)
                    }
                    AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                        AxisTick(length: -5, stroke: .init(lineWidth: 1))
                        //                            .foregroundStyle(.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: yAxisStride)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                        //                            .foregroundStyle(.gray.opacity(0.4))
                        AxisValueLabel()
                            .font(style.yAxisFont)
                    }
                }
        } else {
            baseChart
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
        }
    }
    
    private var baseChart: some View {
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
            
            ForEach(entry.graph) { item in
                var strokeColor: Color { colorScheme == .dark ? item.color.color : .black }
                LineMark(
                    x: .value("Time", item.glucose.date),
                    y: .value("Glucose", scaledValue(item.glucose.value)),
                    series: .value("Curve", "Glucose")
                )
                .interpolationMethod(.linear)
                //                .foregroundStyle(glucoseLineColor)
                .lineStyle(.init(lineWidth: style.graphLineWidth))
                .symbol {
                    Circle()
                        .fill(item.color.color)
                        .strokeBorder(strokeColor, lineWidth: 0.5)
                        .frame(width: style.graphPointSize, height: style.graphPointSize)
                }
            }
            
            ForEach(entry.minutePoints) { point in
                var strokeColor: Color { colorScheme == .dark ? minuteGlucoseColor : .black }
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Glucose", scaledValue(point.valueInMgPerDl))
                )
                .foregroundStyle(minuteGlucoseColor)
                .symbol {
                    Circle()
                        .fill(minuteGlucoseColor)
                        .strokeBorder(strokeColor, lineWidth: 0.5)
                        .frame(width: style.minutePointSize, height: style.minutePointSize)
                }
            }
            
            if entry.showIOBCurve, !entry.iobPoints.isEmpty {
                ForEach(entry.iobPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Insulin", scaledIOBValue(point.value)),
                        series: .value("Curve", "Insulin")
                    )
                    .foregroundStyle(IOBMarksLineColor)
                    .lineStyle(.init(lineWidth: style.overlayLineWidth))
                }
            }
            
            if entry.showInsulinDeliveryMarks, !entry.insulinMarkers.isEmpty {
                
                

                ForEach(entry.insulinMarkers) { marker in
                    PointMark(
                        x: .value("Time", marker.timestamp),
                        y: .value("Insulin", markerYPosition(for: marker))
                    )
                    .symbol {
                        Image(systemName: "arrowtriangle.down.fill")
                            .foregroundColor(IOBMarksLineColor)
                            .font(.system(size: style.insulinMarkerFontSize))
                    }
                    .annotation(alignment: markerAlignment(for: marker.timestamp)) {
                        Text(marker.unitsText)
                            .font(style.insulinAnnotationFont)
                    }
                }
            }
            
            if entry.showActivityCurve, !entry.activityPoints.isEmpty {
                ForEach(entry.activityPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Activity", scaledActivityValue(point.value)),
                        series: .value("Curve", "Activity")
                    )
                    .foregroundStyle(.brown)
                    .lineStyle(.init(lineWidth: style.overlayLineWidth))
                }
            }
        }
        .chartXScale(domain: [chartXScaleMin, chartXScaleMax])
        .chartYScale(domain: [chartYScaleMin, chartYScaleMax])
    }
    
    private func scaledValue(_ valueInMgPerDl: Int) -> Double {
        if entry.uom == 0 {
            return Double(valueInMgPerDl).toMmolL()
        }
        return Double(valueInMgPerDl)
    }
    
    private func scaledIOBValue(_ value: Double) -> Double {
        chartYScaleMinIOBCurve + value * quarterYAxisIOBCurve / maxIOB
    }
    
    private func scaledActivityValue(_ value: Double) -> Double {
        chartYScaleMinIOBCurve + value * quarterYAxisIOBCurve / maxActivity
    }
    
    private func markerYPosition(for marker: FullGraphGlucoseMeasurementIOBEntry.InsulinMarker) -> Double {
        let shiftInYValue = showsAxes ? 10 : 5
        let shiftInY = entry.uom == 0 ? Double(shiftInYValue).toMmolL() : Double(shiftInYValue)
        let curvePoint = entry.iobPoints.first(where: { $0.timestamp > marker.timestamp })
        return chartYScaleMinIOBCurve + shiftInY + scaledIOBComponent(curvePoint?.value ?? 0, maxValue: maxIOB)
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
}

private extension FullGraphGlucoseMeasurementIOBEntry.InsulinMarker {
    var unitsText: String {
        String(format: "%.1fu", Double(insulinUnitsInHundredths) / 100)
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
