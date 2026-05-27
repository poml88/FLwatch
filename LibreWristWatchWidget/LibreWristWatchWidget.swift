//
//  LibreWristWatchWidget.swift
//  LibreWristWatchWidget
//
//  Created by Peter Müller on 08.10.24.
//

import WidgetKit
import SwiftUI

struct LibreWristWidgetEntryView : View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family
    
    @AppStorage(DefaultsKey.tapComplicationReloads.rawValue, store: UserDefaults.group) private var tapComplicationReloads: Bool = false
    
    private let staleThreshold: TimeInterval = 5 * 60
    
    var isStaleGlucose: Bool {
        Date().timeIntervalSince(entry.date) > staleThreshold && !(entry.glucoseMeasurement.value <= 0)
    }
    
    var glucoseFontWeight: Font.Weight {
        isStaleGlucose ? .regular : .heavy
    }

    
    var glucose: String {
        if entry.glucoseMeasurement.valueInMgPerDl <= 0 {
            return "--"
        }
        return entry.glucoseMeasurement.valueInMgPerDl.asGlucose(glucoseUnitValue: entry.glucoseMeasurement.glucoseUnits)
    }
    
    var currentIOB: String {
        if entry.currentIOB == -1 {
            return "-.-u"
//        } else if entry.currentIOB == 0 {
//            return ""
        } else {
            return "\(String(format: "%.1f", entry.currentIOB))u"
        }
    }

    /// True when the active provider has no credential the widget process can
    /// use to fetch *and* the cached reading is already stale. The widget
    /// can't re-auth itself (no keychain access, see `PasswordKeychain`), so
    /// the only useful action then is "open the app" — which is what a
    /// default complication tap does. We surface that by drawing just a
    /// reload arrow and skipping any Button wrapper that would otherwise
    /// trigger a doomed reload intent.
    ///
    /// Freshness guard: while the phone is still pushing fresh snapshots over
    /// WC, `LibreLinkUpHistory.lastReadingDate` keeps advancing even if the
    /// watch's own token/session is empty. Showing the arrow in that window
    /// would hide perfectly good data — so we only flip once history has
    /// drifted past the provider's stale threshold (LLU 3 min, Dexcom 8 min).
    private var needsManualReauth: Bool {
        guard !SharedData.canActiveProviderReload else { return false }
        let staleAfter = SharedData.cgmProviderKind.staleReadingAfter
        return Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) > staleAfter
    }

    @ViewBuilder
    private var reauthBody: some View {
        switch family {
        case .accessoryInline:
            // Inline can only render a single line of text — no images.
            Text(verbatim: "↻ Open FLwatch")
                .containerBackground(.background, for: .widget)
        case .accessoryCorner:
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 18, weight: .heavy))
                .widgetCurvesContent()
                .containerBackground(.background, for: .widget)
        case .accessoryRectangular:
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 34, weight: .heavy))
                    .containerBackground(for: .widget) { EmptyView() }
                Text("Open\nFLwatch")
            }
        case .accessoryCircular:
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 26, weight: .heavy))
                .containerBackground(.background, for: .widget)
        default:
            Image("AppIcon")
                .containerBackground(.background, for: .widget)
        }
    }

    @ViewBuilder
    var body: some View {
        if needsManualReauth {
            reauthBody
        } else {
            normalBody
        }
    }

    @ViewBuilder
    private var normalBody: some View {
        switch family {

        case .accessoryCircular:
            
            VStack(alignment: .center, spacing: -6) {
                
                let trend = entry.glucoseMeasurement.trendArrow?.symbol ?? "-"
                Text(verbatim: trend)
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundColor(entry.glucoseMeasurement.measurementColor.color)
                //.colorInvert()
                    .widgetAccentable()
                
                
                if tapComplicationReloads, #available(watchOS 11.0, *) {
                    Button(intent: ReloadWidgetIntent()) {
                        Text(verbatim: glucose)
                            .font(.system(size: 20, weight: glucoseFontWeight))
                            .strikethrough(isStaleGlucose)
                            .foregroundColor(entry.glucoseMeasurement.measurementColor.color)
                        //.colorInvert()
                            .widgetAccentable()
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Text(verbatim: glucose)
                        .font(.system(size: 20, weight: glucoseFontWeight))
                        .strikethrough(isStaleGlucose)
                        .foregroundColor(entry.glucoseMeasurement.measurementColor.color)
                    //.colorInvert()
                        .widgetAccentable()
                }
                
                Text(entry.date, style: .timer)
                //Text(verbatim: " ")
                    .font(.system(size: 10, weight: .heavy))
                //.colorInvert()
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .padding(4)

            }
            .containerBackground(.background, for: .widget)
            
        case .accessoryRectangular:
//            ZStack {
////                if #available(iOSApplicationExtension 17.0, *) {
////                    // TODO
////                } else {
////                    Color(.white)
////                }
//                AccessoryWidgetBackground()
            HStack {//}(spacing: 0){
                VStack (alignment: .center, spacing: 6){
                    if entry.currentIOB > 0 {
                        Text(currentIOB)
                            .font(.system(size: 18, weight: .heavy))
                    }
                    Text(entry.date, style: .timer)
                    //Text(verbatim: " ")
                        .font(.system(size: 14, weight: .heavy))
                    //.colorInvert()
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .frame(width: 60)
                    //                            .padding(4)
                }
                
                VStack(alignment: .center, spacing: -6)
                {
                    Text(verbatim: entry.glucoseMeasurement.trendArrow?.symbol ?? "-")
                        .font(.system(size: 25, weight: .heavy, design: .monospaced))
                        .foregroundColor(entry.glucoseMeasurement.measurementColor.color)
                    //.colorInvert()
                        .widgetAccentable()
                    
                    Text(verbatim: glucose)
                        .font(.system(size: 27, weight: glucoseFontWeight))
                        .strikethrough(isStaleGlucose)
                        .foregroundColor(entry.glucoseMeasurement.measurementColor.color)
                    //.colorInvert()
                        .widgetAccentable()
                    
                }
                //                    .frame(width: 50)
                //                    .padding(.leading,-10)
                if #available(watchOS 11.0, *) {
                    Button(intent: ReloadWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 22, weight: .heavy))
//                            .padding(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    //                    .padding(.trailing,5)
                    .padding(.leading,10)
                }
            }
//            }
            .containerBackground(for: .widget) {
                EmptyView()
            }
            
        case .accessoryCorner:
//            ZStack{
//                AccessoryWidgetBackground()
                
                Text("\(glucose) \(entry.glucoseMeasurement.trendArrow?.symbol ?? "-")")
                
                    .foregroundColor(entry.glucoseMeasurement.measurementColor.color)
                    .strikethrough(isStaleGlucose)
                    .fontWeight(glucoseFontWeight)
                //.colorInvert()
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text(entry.date, style: .timer)
                        //Text(verbatim: " ")
                        //.colorInvert()
                        //                                        .multilineTextAlignment(.center)
                            .monospacedDigit()
                        
                    }
//            }
             .containerBackground(.background, for: .widget)
            
        case .accessoryInline:
            Text("\(glucose)  \(entry.glucoseMeasurement.trendArrow?.symbol ?? "-")  \(entry.date, style: .timer)")
                .strikethrough(isStaleGlucose)
                    .widgetAccentable()
            .containerBackground(.background, for: .widget)
            
            
        default:
//            VStack(alignment: .center) {
                Image("AppIcon")
//            }
            .containerBackground(.background, for: .widget)
        }
    }
}

@main
struct LibreWristWatchWidget: Widget {
    let kind: String = "LibreWristWatchWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            LibreWristWidgetEntryView(entry: entry)
        }
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline])
        .configurationDisplayName("Glucose Widget")
        .description("This widget displays the latest blood glucose value.")
        //        .contentMarginsDisabled()
    }
}



#Preview("accessCirc", as: .accessoryCircular) {
    LibreWristWatchWidget()
} timeline: {
    GlucoseMeasurementIOBEntry.sampleEntry
}

#Preview("accessRect", as: .accessoryRectangular) {
    LibreWristWatchWidget()
} timeline: {
    GlucoseMeasurementIOBEntry.sampleEntry
}

#Preview("accessCorn", as: .accessoryCorner) {
    LibreWristWatchWidget()
} timeline: {
    GlucoseMeasurementIOBEntry.sampleEntry
}

#Preview("accessInline", as: .accessoryInline) {
    LibreWristWatchWidget()
} timeline: {
    GlucoseMeasurementIOBEntry.sampleEntry
}
