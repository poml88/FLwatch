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

/// WidgetKit re-archives every Live Activity presentation on each `Activity.update`, and
/// archiving accessibility metadata is ~43% of that work. The presentation roots are hidden from
/// accessibility because the Live Activity intentionally has no accessible UI, but this does not
/// reduce the archive cost: measured on three builds, the accessibility share of the widget
/// extension's CPU was 43% unmodified, 53% with
/// `.accessibilityElement(children: .ignore)` plus a fixed label, and 48% with
/// `.accessibilityHidden(true)` on every presentation root. With all presentations hidden, `Text`s
/// were still resolved into the archive and `AXNameFromColor` still ran. The Live Activity is
/// composited by a separate process from the serialized display list, so VoiceOver data is written
/// regardless of what the view declares.
///
/// The reachable levers are therefore fewer and simpler `Text`s, and a lower update cadence.
///
/// The "since last reading" counters below cost ~10% of the render: dropping the system
/// `.stopwatch` text entirely removed that much (`TimeDataFormattingStorage` 10.3% → 0.2%, text
/// layout 20.4% → 11.2%). But the counter has to stay live — it is the only element the system
/// keeps ticking between updates, and therefore the only indication that the feed has stalled.
/// Two replacements were tried and rejected: an absolute clock time makes the reader do the
/// subtraction, and a self-computed "7m" string is evaluated at archive time, so it freezes
/// exactly when it matters (no new reading means no update means the age stops moving).
///
/// A minute-precision variant was tried and reverted. `maxPrecision: .seconds(60)` renders
/// "0 Minutes", which truncates in these narrow slots, and neither `SystemFormatStyle.Stopwatch`
/// nor `.DateOffset` exposes an abbreviation parameter, so it needed `.textVariant(.sizeDependent)`
/// to pick the shorter "0 Min." form. Profiling the result (tethered Instruments attached to this
/// extension, screen off, 1 ms sampling) showed it costs MORE, not less: the variant machinery
/// alone — `Text.Resolved.append(_:in:with:isUniqueSizeVariant:)` and friends — added ~72 ms per
/// render that did not exist before, taking the counters from ~11% of the render to 16.3%.
/// `.sizeDependent` is documented to cost extra processing per `Text`, and it does.
///
/// So these are back to the original per-second counters. Most of their extension-side cost is
/// SwiftUI hashing the format configuration (`MixedFormatStyle.hash(into:)`), which we cannot
/// influence. The counters use fixed monospaced widths so the renderer does not need tightening
/// or scale-factor searches as the digits change. Widths remain presentation-specific because
/// the Dynamic Island and small supplemental layout have much tighter horizontal constraints.
///
/// Every presentation root pins `.dynamicTypeSize(.large)`. This is an editorial choice, not a
/// performance one: these layouts have fixed frames and fixed monospaced counter widths, they are
/// not built to grow with the system text size, and they look wrong when they try.
///
/// It was originally added as a performance experiment, and that experiment failed — recording it
/// so nobody repeats it. A single `Activity.update` costs the widget extension roughly a second
/// of main-thread CPU, spent on ~55 *complete* render + display-list-encode cycles, alternating
/// render/encode. (For scale: the home-screen widget extension ran 5 such cycles in ten minutes
/// total.) The guess was that those cycles were Dynamic Type variants. Pinning the type size
/// changed the cycle count not at all: 52–72 cycles before, 52–72 after.
///
/// What the cycle count *does* track is elapsed time since the previous update. Measured on the
/// simulator, where the update spacing varies: 4.9 s → 12 cycles, 8 s → 15, 13 s → 18, 42 s → 72,
/// 60 s → 52; roughly 220 ms fixed plus ~7 ms per second of gap. The device traces, always on a
/// 60 s cadence, sit exactly where that model puts them, which is why they never varied.
///
/// The only thing here that is a function of elapsed seconds is the `.stopwatch` counter below at
/// `maxPrecision: .seconds(1)`; the system has to pre-archive a display list per tick so the
/// counter keeps running without waking this extension. See the note on the counters for what has
/// and has not been tried.
struct FLWatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FLWatchAttributes.self) { context in
            LockScreenView(contentState: context.state)
            //                .activityBackgroundTint(Color("LABackground", bundle: nil))
            //                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
//                    Text("X")
                    
//#if false
                    //                    let isStaleActivity: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleActivityAfterInterval) <= Date()
                    
                    //                    var isStaleGlucose: Bool {
                    //                        Date().timeIntervalSince(context.state.latestTimestamp ) > FLWatchAttributes.staleGlucoseAfterInterval
                    //                    }
                    let isStaleGlucose: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()
                    
                    HStack {
                        Text(verbatim: "\(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit)) \(context.state.latestTrend)")
                        //                            .font(.headline)
                            .strikethrough(isStaleGlucose)
                            .bold(!isStaleGlucose)
                            .foregroundStyle(context.state.latestMeasurementColor.color)
                            .lineLimit(1)
                            .padding(.leading, 4)
                        
                        if context.state.currentIOB > 0 {
                            Text(context.state.currentIOBText)
                            //                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .dynamicTypeSize(.large)
                    .accessibilityHidden(true)
//#endif
                }
                DynamicIslandExpandedRegion(.trailing) {
//                    Text("X")
                    
//#if false
                    VStack(alignment: .trailing, spacing: 2) {
//                        Text("12:34")
//#if false
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
                        .frame(width: 50, alignment: .trailing)
//#endif
                        //                        if context.state.currentIOB > 0 {
                        //                            Text("IOB \(context.state.currentIOBText)")
                        //                                .font(.caption2)
                        //                                .foregroundStyle(.secondary)
                        //                        }
                    }
                    .dynamicTypeSize(.large)
                    .accessibilityHidden(true)
//#endif
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
//                    Text("X")
           
                    
#if false
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
#endif

#if true
                    GlucoseLiveActivityCanvas(
                        contentState: context.state,
                        xAxisFont: Font.system(size: 8, weight: .regular),
                        yAxisFont: Font.system(size: 8, weight: .regular),
                        yAxisWidth: 29,
                        xAxisHeight: 14,
                        graphLineWidth: 3,
                        graphPointSize: 3,
                        minutePointArea: 8,
                        insulinMarkerFontSize: 12,
                        insulinAnnotationFont: Font.system(size: 12, weight: .regular)
                    )
                    .frame(height: 84)
                    .frame(maxWidth: .infinity)
                    .dynamicTypeSize(.large)
#endif
                }
            } compactLeading: {
//                Text("X")
                
//#if false
                let isStaleGlucose: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()
                
                
                Text(verbatim: "\(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit)) \(context.state.latestTrend)")
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .foregroundStyle(context.state.latestMeasurementColor.color)
                    .dynamicTypeSize(.large)
                    .accessibilityHidden(true)
//#endif
            } compactTrailing: {
//                Text("X")
                
//#if false
                
//#if false
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
                .dynamicTypeSize(.large)
                .accessibilityHidden(true)
//#endif
//                Text("12:34")
//                .dynamicTypeSize(.large)
//                .accessibilityHidden(true)
//#endif
            } minimal: {
//                Text("X")
                
//#if false
                let isStaleGlucose: Bool = context.state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()
                
                
                Text(context.state.latestGlucoseValue.units(for: context.state.glucoseUnit))
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .foregroundStyle(context.state.latestMeasurementColor.color)
                    .dynamicTypeSize(.large)
                    .accessibilityHidden(true)
//#endif
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
        .dynamicTypeSize(.large)
        .accessibilityHidden(true)
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
//        Text("X")
        
//#if false
        let isStaleGlucose: Bool = contentState.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()
        
        VStack (spacing: 0){
            HStack {
                Text(verbatim: "\(contentState.latestGlucoseValue.units(for: contentState.glucoseUnit)) \(contentState.latestTrend)")
                    .font(.footnote)
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .lineLimit(1)
                    .foregroundStyle(contentState.latestMeasurementColor.color)
                
                if contentState.currentIOB > 0 {
                    Text(contentState.currentIOBText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
//                Text("12:34")
//#if false
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
                //                    .bold()
                .monospacedDigit()
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .frame(width: 50, alignment: .trailing)
//#endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 7)
            
#if false
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
#endif

#if true
            GlucoseLiveActivityCanvas(
                contentState: contentState,
                xAxisFont: Font.system(size: 8, weight: .regular),
                yAxisFont: Font.system(size: 8, weight: .regular),
                // Use tighter axis reserves in the height-constrained Watch presentation.
                yAxisWidth: 22,
                xAxisHeight: 10,
                graphLineWidth: 2,
                graphPointSize: 2,
                minutePointArea: 5,
                insulinMarkerFontSize: 8,
                insulinAnnotationFont: Font.system(size: 8, weight: .regular)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
#endif
        }
        //        .overlay {
        //            if isStale {
        //                Text("Activity has not been updated for \(staleAfterMinutes) mins. Tap to refresh")
        //                    .font(.caption2)
        //                    .foregroundStyle(.secondary)
        //            }
        //        }
        .padding(.leading, 5)
        .padding(.top, 3)
//#endif
    }
}

private struct MediumSupplementalActivityView: View {
    let contentState: FLWatchAttributes.ContentState
    
    var body: some View {
//        Text("X")
        
//#if false
        // Show the manual-refresh affordance once a new reading is overdue by
        // one source cadence (Libre 1 min, Dexcom 5 min).
        let updateUIAfter = TimeInterval(SharedData.cgmProviderKind.cadenceMinutes * 60)
        let isUpdateUI: Bool = contentState.latestTimestamp.addingTimeInterval(updateUIAfter) <= Date()
        let isStaleGlucose: Bool = contentState.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleGlucoseAfterInterval) <= Date()
        
        VStack (spacing: 5){
            HStack {
                Text(verbatim: "\(contentState.latestGlucoseValue.units(for: contentState.glucoseUnit)) \(contentState.latestTrend)")
                //                    .font(.title)
                    .strikethrough(isStaleGlucose)
                    .bold(!isStaleGlucose)
                    .lineLimit(1)
                    .foregroundStyle(contentState.latestMeasurementColor.color)
                
                if contentState.currentIOB > 0 {
                    Text(verbatim: "IOB \(contentState.currentIOBText)")
                    //                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isUpdateUI, SharedData.cgmProviderKind != .libre3BLE {
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
                
                
//                Text("12:34")
//#if false
                Text(
                    .currentDate,
                    format: .stopwatch(
                        startingAt: contentState.latestTimestamp,
                        showsHours: false,
                        maxFieldCount: 2,
                        maxPrecision: .seconds(1)
                    )
                )
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 60, alignment: .trailing)
//#endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            
#if false
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
#endif

#if true
            GlucoseLiveActivityCanvas(
                contentState: contentState,
                xAxisFont: .footnote,
                yAxisFont: .footnote,
                yAxisWidth: 29,
                xAxisHeight: 14,
                graphLineWidth: 3,
                graphPointSize: 3,
                minutePointArea: 10,
                insulinMarkerFontSize: 12,
                insulinAnnotationFont: .footnote
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
#endif
        }
        //        .overlay {
        //            if isStaleGlucose {
        //                Text("Activity has not been updated for \(staleAfterMinutes) mins. Tap to refresh")
        //                    .font(.caption2)
        //                    .foregroundStyle(.secondary)
        //            }
        //        }
        .padding()
        .frame(height: 160)
//#endif
    }
}

/// Canvas keeps each Live Activity graph to one drawing view instead of archiving the large Swift
/// Charts display list on every update.
private struct GlucoseLiveActivityCanvas: View {
    private struct InsulinMarkerPlotPoint {
        let marker: FLWatchAttributes.InsulinMarker
        let yPosition: Double
    }

    private struct PlotGeometry {
        let rect: CGRect
        let xMinimum: Date
        let xMaximum: Date
        let yMinimum: Double
        let yMaximum: Double
        
        func xPosition(for date: Date) -> CGFloat {
            let domainLength = xMaximum.timeIntervalSince(xMinimum)
            guard domainLength > 0 else { return rect.minX }
            let fraction = CGFloat(date.timeIntervalSince(xMinimum) / domainLength)
            return rect.minX + rect.width * fraction
        }
        
        func yPosition(for value: Double) -> CGFloat {
            let domainLength = yMaximum - yMinimum
            guard domainLength > 0 else { return rect.maxY }
            let fraction = CGFloat((value - yMinimum) / domainLength)
            return rect.maxY - rect.height * fraction
        }
    }
    
    let contentState: FLWatchAttributes.ContentState
    let xAxisFont: Font
    let yAxisFont: Font
    let yAxisWidth: CGFloat
    let xAxisHeight: CGFloat
    let graphLineWidth: CGFloat
    let graphPointSize: CGFloat
    let minutePointArea: CGFloat
    let insulinMarkerFontSize: CGFloat
    let insulinAnnotationFont: Font
    
    private let yAxisLabelInset: CGFloat = 4
    private let curveLineWidth: CGFloat = 2
    
    private var chartYScaleMin: Double {
        contentState.glucoseUnit == 0 ? 2.75 : 50
    }
    
    private var chartYScaleMax: Double {
        let maxBG = max(
            contentState.maxGlucoseValue,
            contentState.graphPoints.map(\.valueInMgPerDl).max() ?? contentState.latestGlucoseValue
        )
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
    
    private var chartYScaleMinIOBCurve: Double {
        contentState.glucoseUnit == 0 ? 3 : 50
    }
    
    var body: some View {
        let chartXScaleMax = Date.now
        let chartXScaleMin = chartXScaleMax.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
        let yScaleMin = chartYScaleMin
        let yScaleMax = chartYScaleMax
        let yScaleMinIOBCurve = chartYScaleMinIOBCurve
        let quarterYAxisIOBCurve = (yScaleMax - yScaleMin) / 4 + 0.25
        let insulinMarkerPlotPoints = contentState.showInsulinDeliveryMarks
            ? contentState.insulinMarkers.map {
                InsulinMarkerPlotPoint(
                    marker: $0,
                    yPosition: markerYPosition(
                        for: $0,
                        yScaleMinIOBCurve: yScaleMinIOBCurve,
                        quarterYAxisIOBCurve: quarterYAxisIOBCurve
                    )
                )
            }
            : []
        
        Canvas { context, size in
            let plotRect = CGRect(
                x: 0,
                y: yAxisLabelInset,
                width: max(0, size.width - yAxisWidth),
                height: max(0, size.height - xAxisHeight - 2 * yAxisLabelInset)
            )
            guard plotRect.width > 0, plotRect.height > 0 else { return }
            
            let geometry = PlotGeometry(
                rect: plotRect,
                xMinimum: chartXScaleMin,
                xMaximum: chartXScaleMax,
                yMinimum: yScaleMin,
                yMaximum: yScaleMax
            )
            var plotContext = context
            var clipPath = Path()
            clipPath.addRect(plotRect)
            plotContext.clip(to: clipPath)
            
            drawTargetRange(in: &plotContext, geometry: geometry)
            drawAxes(in: &plotContext, labelsIn: &context, geometry: geometry)
            drawAlarmLimit(in: &plotContext, geometry: geometry)
            drawGlucoseLine(in: &plotContext, geometry: geometry)
            drawGlucosePoints(in: &plotContext, geometry: geometry)
            drawInsulinCurves(
                in: &plotContext,
                geometry: geometry,
                insulinMarkerPlotPoints: insulinMarkerPlotPoints,
                yScaleMinIOBCurve: yScaleMinIOBCurve,
                quarterYAxisIOBCurve: quarterYAxisIOBCurve
            )
        }
        .accessibilityHidden(true)
    }
    
    private func drawTargetRange(in context: inout GraphicsContext, geometry: PlotGeometry) {
        let targetLowY = geometry.yPosition(for: scaledValue(contentState.targetLow))
        let targetHighY = geometry.yPosition(for: scaledValue(contentState.targetHigh))
        let targetRect = CGRect(
            x: geometry.rect.minX,
            y: min(targetLowY, targetHighY),
            width: geometry.rect.width,
            height: abs(targetLowY - targetHighY)
        )
        var targetPath = Path()
        targetPath.addRect(targetRect)
        context.fill(targetPath, with: .color(.green.opacity(0.2)))
    }
    
    private func drawAxes(
        in plotContext: inout GraphicsContext,
        labelsIn context: inout GraphicsContext,
        geometry: PlotGeometry
    ) {
        for tick in hourlyTicks(from: geometry.xMinimum, through: geometry.xMaximum) {
            let x = geometry.xPosition(for: tick.date)
            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: geometry.rect.maxY))
            tickPath.addLine(to: CGPoint(x: x, y: geometry.rect.maxY - 5))
            plotContext.stroke(tickPath, with: .color(.gray), lineWidth: 1)
            
            guard tick.showsLabel else { continue }
            var gridPath = Path()
            gridPath.move(to: CGPoint(x: x, y: geometry.rect.minY))
            gridPath.addLine(to: CGPoint(x: x, y: geometry.rect.maxY))
            plotContext.stroke(
                gridPath,
                with: .color(.gray.opacity(0.5)),
                style: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
            )
            context.draw(
                Text(tick.date, format: .dateTime.hour(.defaultDigits(amPM: .narrow)))
                    .font(xAxisFont)
                    .foregroundStyle(.secondary),
                at: CGPoint(x: x, y: geometry.rect.maxY + 1),
                anchor: .top
            )
        }
        
        let firstYTick = ceil(geometry.yMinimum / yAxisStride) * yAxisStride
        for value in stride(from: firstYTick, through: geometry.yMaximum, by: yAxisStride) {
            let y = geometry.yPosition(for: value)
            var gridPath = Path()
            gridPath.move(to: CGPoint(x: geometry.rect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: geometry.rect.maxX, y: y))
            plotContext.stroke(gridPath, with: .color(.gray.opacity(0.4)), lineWidth: 0.5)
            context.draw(
                Text(verbatim: String(Int(value.rounded())))
                    .font(yAxisFont)
                    .foregroundStyle(.secondary),
                at: CGPoint(x: geometry.rect.maxX + 3, y: y),
                anchor: .leading
            )
        }
    }
    
    private func drawAlarmLimit(in context: inout GraphicsContext, geometry: PlotGeometry) {
        guard contentState.alarmLow >= SensorSettings.minDrawableAlarmMgDl else { return }
        let y = geometry.yPosition(for: scaledValue(contentState.alarmLow))
        var path = Path()
        path.move(to: CGPoint(x: geometry.rect.minX, y: y))
        path.addLine(to: CGPoint(x: geometry.rect.maxX, y: y))
        context.stroke(
            path,
            with: .color(.red),
            style: StrokeStyle(lineWidth: 1, dash: [2])
        )
    }

    private func drawGlucoseLine(in context: inout GraphicsContext, geometry: PlotGeometry) {
        var path = Path()
        for (index, point) in contentState.graphPoints.enumerated() {
            let position = CGPoint(
                x: geometry.xPosition(for: point.timestamp),
                y: geometry.yPosition(for: scaledValue(point.valueInMgPerDl))
            )
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }
        context.stroke(
            path,
            with: .color(.blue),
            style: StrokeStyle(lineWidth: graphLineWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func drawGlucosePoints(in context: inout GraphicsContext, geometry: PlotGeometry) {
        let graphPointRadius = graphPointSize / 2
        for point in contentState.graphPoints {
            drawPoint(
                at: CGPoint(
                    x: geometry.xPosition(for: point.timestamp),
                    y: geometry.yPosition(for: scaledValue(point.valueInMgPerDl))
                ),
                radius: graphPointRadius,
                color: measurementColor(for: point.colorRawValue).color,
                in: &context
            )
        }
        
        let minutePointRadius = (minutePointArea / CGFloat.pi).squareRoot()
        let minuteGlucoseColor = Color(red: 0.96, green: 0.78, blue: 0.18) // #F5C72E
        for point in contentState.minutePoints {
            drawPoint(
                at: CGPoint(
                    x: geometry.xPosition(for: point.timestamp),
                    y: geometry.yPosition(for: scaledValue(point.valueInMgPerDl))
                ),
                radius: minutePointRadius,
                color: minuteGlucoseColor,
                in: &context
            )
        }
    }
    
    private func drawInsulinCurves(
        in context: inout GraphicsContext,
        geometry: PlotGeometry,
        insulinMarkerPlotPoints: [InsulinMarkerPlotPoint],
        yScaleMinIOBCurve: Double,
        quarterYAxisIOBCurve: Double
    ) {
        if contentState.showIOBCurve, !contentState.iobPoints.isEmpty {
            let path = curvePath(
                points: contentState.iobPoints,
                geometry: geometry,
                pointValue: { $0.iobValue },
                scaledValue: {
                    yScaleMinIOBCurve + $0 * quarterYAxisIOBCurve / contentState.maxIOB
                }
            )
            context.stroke(
                path,
                with: .color(.orange),
                style: StrokeStyle(lineWidth: curveLineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        
        if contentState.showInsulinDeliveryMarks, !insulinMarkerPlotPoints.isEmpty {
            for plotPoint in insulinMarkerPlotPoints {
                drawInsulinMarker(plotPoint, in: &context, geometry: geometry)
            }
        }
        
        if contentState.showActivityCurve, !contentState.activityPoints.isEmpty {
            let path = curvePath(
                points: contentState.activityPoints,
                geometry: geometry,
                pointValue: { $0.activityValue },
                scaledValue: {
                    yScaleMinIOBCurve + $0 * quarterYAxisIOBCurve / contentState.maxActivity
                }
            )
            context.stroke(
                path,
                with: .color(.brown),
                style: StrokeStyle(lineWidth: curveLineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    private func drawInsulinMarker(
        _ plotPoint: InsulinMarkerPlotPoint,
        in context: inout GraphicsContext,
        geometry: PlotGeometry
    ) {
        let marker = plotPoint.marker
        let x = geometry.xPosition(for: marker.timestamp)
        let y = geometry.yPosition(for: plotPoint.yPosition)
        let halfWidth = insulinMarkerFontSize * 0.4
        let halfHeight = insulinMarkerFontSize * 0.35
        var markerPath = Path()
        markerPath.move(to: CGPoint(x: x - halfWidth, y: y - halfHeight))
        markerPath.addLine(to: CGPoint(x: x + halfWidth, y: y - halfHeight))
        markerPath.addLine(to: CGPoint(x: x, y: y + halfHeight))
        markerPath.closeSubpath()
        context.fill(markerPath, with: .color(.orange))
        
        let labelAnchor: UnitPoint
        if marker.timestamp.timeIntervalSince(geometry.xMaximum) > -30 * 60 {
            labelAnchor = .bottomTrailing
        } else if marker.timestamp.timeIntervalSince(geometry.xMinimum) < 30 * 60 {
            labelAnchor = .bottomLeading
        } else {
            labelAnchor = .bottom
        }
        context.draw(
            Text(verbatim: marker.unitsText)
                .font(insulinAnnotationFont),
            at: CGPoint(x: x, y: y - halfHeight - 1),
            anchor: labelAnchor
        )
    }
    
    private func curvePath(
        points: [FLWatchAttributes.ActivityPoint],
        geometry: PlotGeometry,
        pointValue: (FLWatchAttributes.ActivityPoint) -> Double,
        scaledValue: (Double) -> Double
    ) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let position = CGPoint(
                x: geometry.xPosition(for: point.timestamp),
                y: geometry.yPosition(for: scaledValue(pointValue(point)))
            )
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }
        return path
    }
    
    private func drawPoint(
        at position: CGPoint,
        radius: CGFloat,
        color: Color,
        in context: inout GraphicsContext
    ) {
        let rect = CGRect(
            x: position.x - radius,
            y: position.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
    
    private func hourlyTicks(from minimum: Date, through maximum: Date) -> [(date: Date, showsLabel: Bool)] {
        let calendar = Calendar.autoupdatingCurrent
        guard var tick = calendar.dateInterval(of: .hour, for: minimum)?.start else { return [] }
        if tick < minimum {
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: tick) else { return [] }
            tick = nextHour
        }
        
        var ticks: [(date: Date, showsLabel: Bool)] = []
        while tick <= maximum {
            ticks.append((tick, calendar.component(.hour, from: tick).isMultiple(of: 2)))
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: tick), nextHour > tick else {
                break
            }
            tick = nextHour
        }
        return ticks
    }
    
    private func scaledValue(_ valueInMgPerDl: Int) -> Double {
        valueInMgPerDl.displayedGlucoseValue(glucoseUnitValue: contentState.glucoseUnit)
    }
    
    private func markerYPosition(
        for marker: FLWatchAttributes.InsulinMarker,
        yScaleMinIOBCurve: Double,
        quarterYAxisIOBCurve: Double
    ) -> Double {
        let shiftInY = contentState.glucoseUnit == 0 ? Double(10).toMmolL() : 10
        let curvePoint = contentState.iobPoints.first(where: { $0.timestamp > marker.timestamp })
        let iobValue = curvePoint?.iobValue ?? 0
        return yScaleMinIOBCurve + shiftInY + iobValue * quarterYAxisIOBCurve / contentState.maxIOB
    }
    
    private func measurementColor(for rawValue: Int) -> MeasurementColor {
        MeasurementColor(rawValue: rawValue) ?? .gray
    }
}

private struct GlucoseLiveActivityChart: View {
    // The Live Activity updates frequently, and its chart was a major widget-extension
    // CPU hotspot. This compact model lets Charts render the glucose series as
    // vectorized plots instead of building a LineMark and custom SwiftUI symbol
    // subtree for every glucose reading.
    private struct GlucosePlotPoint {
        let timestamp: Date
        let value: Double
        let color: Color
    }
    
    private struct PlotPoint {
        let timestamp: Date
        let value: Double
    }

    private struct InsulinMarkerPlotPoint: Identifiable {
        let marker: FLWatchAttributes.InsulinMarker
        let yPosition: Double

        var id: FLWatchAttributes.InsulinMarker.ID { marker.id }
    }
    
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
        let yScaleMin = chartYScaleMin
        let yScaleMax = chartYScaleMax
        let yScaleMinIOBCurve = chartYScaleMinIOBCurve
        let quarterYAxisIOBCurve = (yScaleMax - yScaleMin) / 4 + 0.25
        // Vectorized plots read values through key paths, so resolve the
        // unit-dependent glucose value and fallback measurement color here.
        let glucosePlotPoints = contentState.graphPoints.map {
            GlucosePlotPoint(
                timestamp: $0.timestamp,
                value: scaledValue($0.valueInMgPerDl),
                color: measurementColor(for: $0.colorRawValue).color
            )
        }
        let minutePlotPoints = contentState.minutePoints.map {
            PlotPoint(
                timestamp: $0.timestamp,
                value: scaledValue($0.valueInMgPerDl)
            )
        }
        let iobPlotPoints = contentState.iobPoints.map {
            PlotPoint(
                timestamp: $0.timestamp,
                value: yScaleMinIOBCurve + $0.iobValue * quarterYAxisIOBCurve / contentState.maxIOB
            )
        }
        let activityPlotPoints = contentState.activityPoints.map {
            PlotPoint(
                timestamp: $0.timestamp,
                value: yScaleMinIOBCurve + $0.activityValue * quarterYAxisIOBCurve / contentState.maxActivity
            )
        }
        let insulinMarkerPlotPoints = contentState.showInsulinDeliveryMarks
            ? contentState.insulinMarkers.map {
                InsulinMarkerPlotPoint(
                    marker: $0,
                    yPosition: markerYPosition(
                        for: $0,
                        yScaleMinIOBCurve: yScaleMinIOBCurve,
                        quarterYAxisIOBCurve: quarterYAxisIOBCurve
                    )
                )
            }
            : []
        let minuteGlucoseColor = Color(red: 0.96, green: 0.78, blue: 0.18) // #F5C72E
        
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
            
            // Keep the continuous line separate from the independently colored
            // points while rendering each collection as a single plot.
            // Temporarily NOT killed the blue line to save cpu / battery
            LinePlot(
                glucosePlotPoints,
                x: .value("Time", \.timestamp),
                y: .value("Glucose", \.value),
                series: .value("Curve", "Glucose")
            )
            .interpolationMethod(.linear)
            .lineStyle(.init(lineWidth: graphLineWidth))
            
            PointPlot(
                glucosePlotPoints,
                x: .value("Time", \.timestamp),
                y: .value("Glucose", \.value)
            )
            // Keep vectorized key-path modifiers before modifiers that return
            // only `some ChartContent`, such as the constant symbol size.
            .foregroundStyle(\.color)
            // symbolSize takes an area in pt², while graphPointSize is the diameter
            // used by the previous Circle frame. Convert that diameter to circle
            // area to preserve the presentation-specific sizing, calibrated on device.
            .symbolSize(.pi * graphPointSize * graphPointSize / 4)
            
            PointPlot(
                minutePlotPoints,
                x: .value("Time", \.timestamp),
                y: .value("Glucose", \.value)
            )
            .foregroundStyle(minuteGlucoseColor)
            .symbolSize(minutePointSize)
            
            if contentState.showIOBCurve, !contentState.iobPoints.isEmpty {
                LinePlot(
                    iobPlotPoints,
                    x: .value("Time", \.timestamp),
                    y: .value("Insulin", \.value),
                    series: .value("Curve", "Insulin")
                )
                .foregroundStyle(.orange)
            }
            
            if contentState.showInsulinDeliveryMarks, !insulinMarkerPlotPoints.isEmpty {
                ForEach(insulinMarkerPlotPoints) { plotPoint in
                    PointMark(
                        x: .value("Time", plotPoint.marker.timestamp),
                        y: .value("Insulin", plotPoint.yPosition)
                    )
                    .symbol {
                        Image(systemName: "arrowtriangle.down.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: insulinMarkerFontSize))
                    }
                    .annotation(alignment: markerAlignment(for: plotPoint.marker.timestamp)) {
                        Text(plotPoint.marker.unitsText)
                            .font(insulinAnnotationFont)
                    }
                }
            }
            
            if contentState.showActivityCurve, !contentState.activityPoints.isEmpty {
                LinePlot(
                    activityPlotPoints,
                    x: .value("Time", \.timestamp),
                    y: .value("Activity", \.value),
                    series: .value("Curve", "Activity")
                )
                .foregroundStyle(.brown)
            }
        }
        //        .chartForegroundStyleScale([
        //            "Glucose": Color.white
        //        ])
        .chartXScale(domain: [chartXScaleMin, chartXScaleMax])
        .chartYScale(domain: [yScaleMin, yScaleMax])
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
        // WidgetKit archives accessibility metadata for every Live Activity update.
        // The surrounding value and trend already summarize this glanceable chart.
        .accessibilityHidden(true)
    }
    
    private func scaledValue(_ valueInMgPerDl: Int) -> Double {
        valueInMgPerDl.displayedGlucoseValue(glucoseUnitValue: contentState.glucoseUnit)
    }
    
    private func markerYPosition(
        for marker: FLWatchAttributes.InsulinMarker,
        yScaleMinIOBCurve: Double,
        quarterYAxisIOBCurve: Double
    ) -> Double {
        let shiftInYValue = showsAxes ? 10 : 5
        let shiftInY = contentState.glucoseUnit == 0 ? Double(shiftInYValue).toMmolL() : Double(shiftInYValue)
        let curvePoint = contentState.iobPoints.first(where: { $0.timestamp > marker.timestamp })
        return yScaleMinIOBCurve
            + shiftInY
            + (curvePoint?.iobValue ?? 0) * quarterYAxisIOBCurve / contentState.maxIOB
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
