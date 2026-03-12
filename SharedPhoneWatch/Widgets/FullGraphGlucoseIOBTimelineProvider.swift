//
//  FullGraphGlucoseIOBTimelineProvider.swift
//  FLwatch
//
//  Created by Peter Mueller on 11.03.26.
//

import WidgetKit

struct FullGraphProvider: TimelineProvider {
    func placeholder(in context: Context) -> FullGraphGlucoseMeasurementIOBEntry {
        return FullGraphGlucoseMeasurementIOBEntry.sampleEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (FullGraphGlucoseMeasurementIOBEntry) -> ()) {
        let entry = FullGraphGlucoseMeasurementIOBEntry.sampleEntry
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [FullGraphGlucoseMeasurementIOBEntry] = []

        let interval = SharedData.widgetUpdateFrequency

        FullGraphGlucoseMeasurementIOBEntry.getPatientGraph { graphGlucoseMeasurementIOBEntry, _ in
            if let gme = graphGlucoseMeasurementIOBEntry {
                if Int(Date().timeIntervalSince(gme.date) / 60) <= 15 {
                    entries.append(gme)
                } else {
                    var entry = FullGraphGlucoseMeasurementIOBEntry.invalidEntry
                    entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                    entry.graph = gme.graph
                    entries.append(entry)
                }
            } else {
                var entry = FullGraphGlucoseMeasurementIOBEntry.invalidEntry
                entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                entries.append(entry)
            }

            let reloadDate = Calendar.current.date(byAdding: .minute, value: interval, to: Date())!
            let timeline = Timeline(entries: entries, policy: .after(reloadDate))
            completion(timeline)
        }
    }
}
