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
        
        
        GlucoseMeasurementIOBEntry.getLastGlucoseMeasurement { glucoseMeasurementEntry, error in
            let interval = SharedData.widgetUpdateFrequency
            if let gme = glucoseMeasurementEntry {
                    guard Int(Date().timeIntervalSince(gme.date) / 60) <= 3 else {
                    var entry = GlucoseMeasurementIOBEntry.invalidEntry
                    entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                    
                    entries.append(entry)
                    
                    let reloadDate = Calendar.current.date(byAdding: .minute, value: interval, to: Date())!
                    let timeline = Timeline(entries: entries, policy: .after(reloadDate))
                    return completion(timeline)
                    
                }
                let entry = gme
                entries.append(entry)
                
                let reloadDate = Calendar.current.date(byAdding: .minute, value: interval, to: Date())!
                let timeline = Timeline(entries: entries, policy: .after(reloadDate))
                completion(timeline)
            } else {
                var entry = GlucoseMeasurementIOBEntry.invalidEntry
                entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                entries.append(entry)
                
                let reloadDate = Calendar.current.date(byAdding: .minute, value: interval, to: Date())!
                let timeline = Timeline(entries: entries, policy: .after(reloadDate))
                completion(timeline)
            }
        }
    }
}
