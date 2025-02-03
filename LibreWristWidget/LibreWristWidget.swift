//
//  LibreWristWidget.swift
//  LibreWristWidget
//
//  Created by Peter Müller on 02.10.24.
//

import WidgetKit
import SwiftUI


struct LibreWristWidgetEntryView : View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) var colorScheme
    
    var glucose: String {
        if entry.glucoseMeasurement.value <= 0 {
            return "--"
        } else if entry.glucoseMeasurement.glucoseUnits == 1 {
            return "\(Int(entry.glucoseMeasurement.value))"
        } else {
            return String(format: "%.1f", entry.glucoseMeasurement.value)
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
                colorScheme == .dark ? .black : entry.glucoseMeasurement.measurementColor.color
                VStack(alignment: .center, spacing: -10) {
                    HStack {
                        Text(verbatim: entry.glucoseMeasurement.trendArrow?.symbol ?? "-")
                            .font(.system(size: 48, weight: .heavy, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? entry.glucoseMeasurement.measurementColor.color : .black)
                            .padding(.leading, 60)
                            .padding(.trailing, 5)
                        Button(intent: ReloadWidgetIntent()) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundColor(colorScheme == .dark ? .gray : .black)
                        }
                    }
                    Text(verbatim: glucose)
                        .font(.system(size: 52, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? entry.glucoseMeasurement.measurementColor.color : .black)
                    HStack (spacing: 15){
                        Text(currentIOB)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? .gray : .black)
//                        Text("88:88")
                        Text(Date(), style: .timer)
                        //Text(verbatim: " ")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? .gray : .black)
                            .frame(width: 60)
                        //.colorInvert()
                        //                                .multilineTextAlignment(.center)
                            .monospacedDigit()
                        //.frame(width: 10)
                    }
                    .padding(.top, 4)
                }
            }
            .containerBackground(for: .widget) {
                background()
            }
        case .accessoryCircular:
            ZStack {
                //                if #available(iOSApplicationExtension 17.0, *) {
                //                    // TODO
                //                } else {
                //                    Color(.white)
                //                }
                AccessoryWidgetBackground()
                VStack(alignment: .center, spacing: -6) {
                    Button(intent: ReloadWidgetIntent()) {
                        Text(verbatim: entry.glucoseMeasurement.trendArrow?.symbol ?? "-")
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        //.colorInvert()
                        //.widgetAccentable()
                    }
                    .buttonStyle(PlainButtonStyle())
                    Text(verbatim: glucose)
                        .font(.system(size: 20, weight: .heavy))
                    //.colorInvert()
                    
                    Text(Date(), style: .timer)
                    //Text(verbatim: " ")
                        .font(.system(size: 10, weight: .heavy))
                    //.colorInvert()
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .padding(4)
                }
            }
            .containerBackground(for: .widget) {
                EmptyView()
            }
        case .accessoryRectangular:
            ZStack {
//                if #available(iOSApplicationExtension 17.0, *) {
//                    // TODO
//                } else {
//                    Color(.white)
//                }
                AccessoryWidgetBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                HStack {
                    VStack (alignment: .center, spacing: 6){
                        if entry.currentIOB > 0 {
                            Text(currentIOB)
                                .font(.system(size: 15, weight: .heavy))
                        }
                        Text(Date(), style: .timer)
                        //Text(verbatim: " ")
                            .font(.system(size: 12, weight: .heavy))
                        //.colorInvert()
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
//                            .padding(4)
                    }
                    VStack(alignment: .center, spacing: -6)
                    {
                        Text(verbatim: entry.glucoseMeasurement.trendArrow?.symbol ?? "-")
                            .font(.system(size: 25, weight: .heavy, design: .monospaced))
                        //.colorInvert()
                        //.widgetAccentable()
                        
                        Text(verbatim: glucose)
                            .font(.system(size: 25, weight: .heavy))
                        //.colorInvert()
                    }
                    .fixedSize()
                    Button(intent: ReloadWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .heavy))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing,5)
                }
            }
            .containerBackground(for: .widget) {
                EmptyView()
            }
        default:
            VStack(alignment: .center) {
                Text("default")
            }
            .containerBackground(for: .widget) {
//                Color.clear
                background()
            }
        }
    }
}

struct LibreWristWidget: Widget {
    let kind: String = "LibreWristWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            LibreWristWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.accessoryCircular, .systemSmall, .accessoryRectangular])
        .configurationDisplayName("Glucose Widget")
        .description("This widget displays the latest blood glucose value.")
        .contentMarginsDisabled()
    }
}
    

    
 

#Preview("systSma", as: .systemSmall) {
    LibreWristWidget()
} timeline: {
//    SimpleEntry(date: .now, emoji: "😀")
//    SimpleEntry(date: .now, emoji: "🤩")
    GlucoseMeasurementIOBEntry.sampleEntry
}

#Preview("accessCirc", as: .accessoryCircular) {
    LibreWristWidget()
} timeline: {
//    SimpleEntry(date: .now, emoji: "😀")
//    SimpleEntry(date: .now, emoji: "🤩")
    GlucoseMeasurementIOBEntry.sampleEntry
}

#Preview("accessRect", as: .accessoryRectangular) {
    LibreWristWidget()
} timeline: {
//    SimpleEntry(date: .now, emoji: "😀")
//    SimpleEntry(date: .now, emoji: "🤩")
    GlucoseMeasurementIOBEntry.sampleEntry
}
