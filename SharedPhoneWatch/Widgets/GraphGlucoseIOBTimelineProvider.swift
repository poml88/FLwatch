//
//  GraphGlucoseIOBTimelineProvider.swift
//  FLwatch
//
//  Created by Peter Müller on 19.01.26.
//

import WidgetKit

struct GraphProvider: TimelineProvider {
    func placeholder(in context: Context) -> GraphGlucoseMeasurementIOBEntry {
        return GraphGlucoseMeasurementIOBEntry.sampleEntry
    }
    
    func getSnapshot(in context: Context, completion: @escaping (GraphGlucoseMeasurementIOBEntry) -> ()) {
        let entry = GraphGlucoseMeasurementIOBEntry.sampleEntry
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [GraphGlucoseMeasurementIOBEntry] = []
        
        let interval = SharedData.widgetUpdateFrequency
        
        GraphGlucoseMeasurementIOBEntry.getPatientGraph { graphGlucoseMeasurementIOBEntry, error in
            
            if let gme = graphGlucoseMeasurementIOBEntry {
                // Ensure recent enough
                if Int(Date().timeIntervalSince(gme.date) / 60) <= 3 {
                    entries.append(gme)
                } else {
                    var entry = GraphGlucoseMeasurementIOBEntry.invalidEntry
                    entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                    entry.graph = gme.graph
                    entries.append(entry)
                }
            } else {
                // On timeout / error return an invalid (fallback) entry quickly
                var entry = GraphGlucoseMeasurementIOBEntry.invalidEntry
                entry.currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                entries.append(entry)
            }
            
            let reloadDate = Calendar.current.date(byAdding: .minute, value: interval, to: Date())!
            let timeline = Timeline(entries: entries, policy: .after(reloadDate))
            completion(timeline)
            
        }
    }
}
