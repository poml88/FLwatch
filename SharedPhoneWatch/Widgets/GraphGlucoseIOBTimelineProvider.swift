//
//  GlucoseIOBTimelineProvider.swift
//  LibreWrist
//
//  Created by Peter Müller on 13.10.24.
//

import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GlucoseMeasurementIOBEntry {
        return GlucoseMeasurementIOBEntry.sampleEntry
    }
    
    func getSnapshot(in context: Context, completion: @escaping (GlucoseMeasurementIOBEntry) -> ()) {
        let entry = GlucoseMeasurementIOBEntry.sampleEntry
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [GlucoseMeasurementIOBEntry] = []
        
        let interval = SharedData.widgetUpdateFrequency
        
        GlucoseMeasurementIOBEntry.getLastGlucoseMeasurement { glucoseMeasurementEntry, error in
            
            if let gme = glucoseMeasurementEntry {
                // Ensure recent enough
                if Int(Date().timeIntervalSince(gme.date) / 60) <= 3 {
                    entries.append(gme)
                } else {
                    var entry = GlucoseMeasurementIOBEntry.invalidEntry
                    entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                    entries.append(entry)
                }
            } else {
                // On timeout / error return an invalid (fallback) entry quickly
                var entry = GlucoseMeasurementIOBEntry.invalidEntry
                entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                entries.append(entry)
            }
            
            let reloadDate = Calendar.current.date(byAdding: .minute, value: interval, to: Date())!
            let timeline = Timeline(entries: entries, policy: .after(reloadDate))
            completion(timeline)
            
        }
    }
}
