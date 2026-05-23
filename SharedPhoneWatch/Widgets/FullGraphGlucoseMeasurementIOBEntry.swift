//
//  FullGraphGlucoseMeasurementIOBEntry.swift
//  FLwatch
//
//  Created by Peter Mueller on 11.03.26.
//

import WidgetKit

struct FullGraphGlucoseMeasurementIOBEntry: TimelineEntry {
    struct GraphPoint: Hashable, Identifiable {
        let timestamp: Date
        let valueInMgPerDl: Int
        let colorRawValue: Int
        
        var id: Date { timestamp }
    }
    
    struct ActivityPoint: Hashable, Identifiable {
        let timestamp: Date
        let value: Double
        
        var id: Date { timestamp }
    }
    
    struct InsulinMarker: Hashable, Identifiable {
        let timestamp: Date
        let insulinUnitsInHundredths: Int
        
        var id: Date { timestamp }
    }
    
    let date: Date
    let lastGlucoseMeasurement: LibreLinkUpGlucose
    let graph: [LibreLinkUpGlucose]
    let minutePoints: [GraphPoint]
    let currentIOB: Double
    let iobPoints: [ActivityPoint]
    let maxIOB: Double
    let activityPoints: [ActivityPoint]
    let maxActivity: Double
    let insulinMarkers: [InsulinMarker]
    let targetLow: Int
    let targetHigh: Int
    let alarmLow: Int
    let showIOBCurve: Bool
    let showActivityCurve: Bool
    let showInsulinDeliveryMarks: Bool
    let uom: Int
    let maxBG: Int
    
    static let sampleEntry = FullGraphGlucoseMeasurementIOBEntry(
        date: Date(),
        lastGlucoseMeasurement: LibreLinkUpGlucose(
            glucose: Glucose(105, id: 1, date: Date(), source: "Sample"),
            color: .green,
            trendArrow: .stable
        ),
        graph: [
            LibreLinkUpGlucose(glucose: Glucose(95, id: 0, date: Date().addingTimeInterval(-7200), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(97, id: 1, date: Date().addingTimeInterval(-6300), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(100, id: 2, date: Date().addingTimeInterval(-5400), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(102, id: 3, date: Date().addingTimeInterval(-4500), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(104, id: 4, date: Date().addingTimeInterval(-3600), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(106, id: 5, date: Date().addingTimeInterval(-2700), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(107, id: 6, date: Date().addingTimeInterval(-1800), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(108, id: 7, date: Date().addingTimeInterval(-900), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(115, id: 8, date: Date().addingTimeInterval(-500), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(105, id: 9, date: Date(), source: "Sample"), color: .green, trendArrow: .stable)
        ],
        minutePoints: [
            GraphPoint(timestamp: Date().addingTimeInterval(-15 * 60), valueInMgPerDl: 104, colorRawValue: MeasurementColor.yellow.rawValue),
            GraphPoint(timestamp: Date().addingTimeInterval(-10 * 60), valueInMgPerDl: 106, colorRawValue: MeasurementColor.yellow.rawValue),
            GraphPoint(timestamp: Date().addingTimeInterval(-5 * 60), valueInMgPerDl: 105, colorRawValue: MeasurementColor.yellow.rawValue)
        ],
        currentIOB: 0.1,
        iobPoints: [
            ActivityPoint(timestamp: Date().addingTimeInterval(-3 * 60 * 60), value: 1.5),
            ActivityPoint(timestamp: Date().addingTimeInterval(-2 * 60 * 60), value: 1),
            ActivityPoint(timestamp: Date().addingTimeInterval(0), value: 0.3)
        ],
        maxIOB: 1.8,
        activityPoints: [
            ActivityPoint(timestamp: Date().addingTimeInterval(-3 * 60 * 60), value: 0.05),
            ActivityPoint(timestamp: Date().addingTimeInterval(-2 * 60 * 60), value: 0.35),
            ActivityPoint(timestamp: Date().addingTimeInterval(0), value: 0.15)
        ],
        maxActivity: 0.35,
        insulinMarkers: [
            InsulinMarker(timestamp: Date().addingTimeInterval(-3 * 60 * 60), insulinUnitsInHundredths: 250),
            InsulinMarker(timestamp: Date().addingTimeInterval(-75 * 60), insulinUnitsInHundredths: 150)
        ],
        targetLow: 70,
        targetHigh: 180,
        alarmLow: 85,
        showIOBCurve: true,
        showActivityCurve: true,
        showInsulinDeliveryMarks: true,
        uom: 1,
        maxBG: 250
    )
    
    static var invalidEntry: FullGraphGlucoseMeasurementIOBEntry {
        FullGraphGlucoseMeasurementIOBEntry(
            date: Date(),
            lastGlucoseMeasurement: LibreLinkUpGlucose(
                glucose: Glucose(0, id: 0, date: Date(), source: ""),
                color: .gray,
                trendArrow: .unknown
            ),
            graph: [LibreLinkUpGlucose(glucose: Glucose(0, id: 0, date: Date(), source: "Sample"), color: .green, trendArrow: .stable)],
            minutePoints: [],
            currentIOB: -1,
            iobPoints: [],
            maxIOB: 0.01,
            activityPoints: [],
            maxActivity: 0.01,
            insulinMarkers: [],
            targetLow: SensorSettings.defaultValue.targetLow,
            targetHigh: SensorSettings.defaultValue.targetHigh,
            alarmLow: SensorSettings.defaultValue.alarmLow,
            showIOBCurve: false,
            showActivityCurve: false,
            showInsulinDeliveryMarks: false,
            uom: 1,
            maxBG: 250
        )
    }
    
    static func getPatientGraph(timeout _: TimeInterval = 10,
                                completion: @escaping (FullGraphGlucoseMeasurementIOBEntry?, Error?) -> Void) {
        Task {
            do {
                let entry = try await getPatientGraph()
                await MainActor.run { completion(entry, nil) }
            } catch {
                await MainActor.run { completion(nil, error) }
            }
        }
    }
    
    static func getPatientGraph(maxAgeMinutes: Int? = nil,
                                forceReload: Bool = false) async throws -> FullGraphGlucoseMeasurementIOBEntry {
        // See GlucoseMeasurementIOBEntry: the reload gate is not a precondition
        // for displaying persisted history that may have arrived via a peer
        // process (e.g. WatchConnectivity) since this widget's session was cleared.
        if SharedData.canActiveProviderReload {
            _ = await LibreLinkUpService.shared.requestReloadIfNeeded(maxAgeMinutes: maxAgeMinutes, force: forceReload)
        }

        if let entry = await entryFromHistory() {
            return entry
        }

        if !SharedData.canActiveProviderReload {
            throw NSError(domain: "MissingSettings", code: -5,
                          userInfo: [NSLocalizedDescriptionKey: "Missing CGM credentials"])
        }
        throw NSError(domain: "ResponseError", code: -3,
                      userInfo: [NSLocalizedDescriptionKey: "No glucose item found in history."])
    }
    
    @MainActor
    private static func entryFromHistory() async -> FullGraphGlucoseMeasurementIOBEntry? {
        let history = LibreLinkUpHistory.shared
        let sensor = SensorSettingsStore.shared
        guard history.currentGlucose > 0 else { return nil }
        guard let lastGlucose = latestHistoryValue(from: history) else { return nil }
        
        let cutoffDate = Date(timeIntervalSinceNow: -6 * 60 * 60 - 10 * 60)
        var graph = history.libreLinkUpGlucose.filter { $0.glucose.date > cutoffDate }
        if !graph.contains(where: { $0.glucose.date == lastGlucose.glucose.date && $0.id == lastGlucose.id }) {
            graph.append(lastGlucose)
        }
        graph.sort(by: { $0.glucose.date < $1.glucose.date })
        
        let minutePoints = history.libreLinkUpMinuteGlucose
            .filter { $0.glucose.date >= cutoffDate }
            .sorted { $0.glucose.date < $1.glucose.date }
            .sampled(maxCount: 48)
            .map {
                GraphPoint(
                    timestamp: $0.glucose.date,
                    valueInMgPerDl: $0.glucose.value,
                    colorRawValue: MeasurementColor.yellow.rawValue
                )
            }
        
        let indexOfMaxGlucoseItem = graph.indices.max(by: { graph[$0].glucose.value < graph[$1].glucose.value }) ?? 0
        let maxBG = graph.isEmpty ? max(history.maxBG, 250) : graph[indexOfMaxGlucoseItem].glucose.value
        
        let insulinHistory = InsulinDeliveryHistorySingleton.shared
        insulinHistory.read()
        let currentIOBSingleton = CurrentIOBSingleton.shared
        currentIOBSingleton.updateCurrentIOBAndGraphs()
        
        let iobPoints = currentIOBSingleton.insulinOnBoardCurve
            .filter { $0.date >= cutoffDate }
            .map {
                ActivityPoint(
                    timestamp: $0.date,
                    value: $0.value
                )
            }
        
        let activityPoints = currentIOBSingleton.insulinActivityCurve
            .filter { $0.date >= cutoffDate }
            .map {
                ActivityPoint(
                    timestamp: $0.date,
                    value: $0.value
                )
            }
        
        let insulinMarkers = insulinHistory.insulinDeliveryHistory
            .filter { Date(timeIntervalSince1970: $0.timeStamp) >= cutoffDate }
            .sorted { $0.timeStamp < $1.timeStamp }
            .map {
                InsulinMarker(
                    timestamp: Date(timeIntervalSince1970: $0.timeStamp),
                    insulinUnitsInHundredths: Int(($0.insulinUnits * 100).rounded())
                )
            }
        
        return FullGraphGlucoseMeasurementIOBEntry(
            date: lastGlucose.glucose.date,
            lastGlucoseMeasurement: lastGlucose,
            graph: graph,
            minutePoints: minutePoints,
            currentIOB: currentIOBSingleton.currentIOB,
            iobPoints: iobPoints,
            maxIOB: max(currentIOBSingleton.maxIOB, 0.01),
            activityPoints: activityPoints,
            maxActivity: max(currentIOBSingleton.maxActivity, 0.01),
            insulinMarkers: insulinMarkers,
            targetLow: sensor.sensorSettings.targetLow,
            targetHigh: sensor.sensorSettings.targetHigh,
            alarmLow: sensor.sensorSettings.alarmLow,
            showIOBCurve: SharedData.showIOBCurveWatch,
            showActivityCurve: SharedData.showActivityCurveWatch,
            showInsulinDeliveryMarks: SharedData.showInsulinDeliveryMarksWatch,
            uom: sensor.sensorSettings.uom,
            maxBG: maxBG
        )
    }
    
    @MainActor
    private static func latestHistoryValue(from history: LibreLinkUpHistory) -> LibreLinkUpGlucose? {
        history.latestLibreLinkUpGlucose
    }
    
    func invalidated(currentIOB: Double) -> FullGraphGlucoseMeasurementIOBEntry {
        FullGraphGlucoseMeasurementIOBEntry(
            date: date,
            lastGlucoseMeasurement: LibreLinkUpGlucose(
                glucose: Glucose(0, id: 0, date: date, source: lastGlucoseMeasurement.glucose.source),
                color: .gray,
                trendArrow: .unknown
            ),
            graph: graph,
            minutePoints: minutePoints,
            currentIOB: currentIOB,
            iobPoints: iobPoints,
            maxIOB: maxIOB,
            activityPoints: activityPoints,
            maxActivity: maxActivity,
            insulinMarkers: insulinMarkers,
            targetLow: targetLow,
            targetHigh: targetHigh,
            alarmLow: alarmLow,
            showIOBCurve: showIOBCurve,
            showActivityCurve: showActivityCurve,
            showInsulinDeliveryMarks: showInsulinDeliveryMarks,
            uom: uom,
            maxBG: maxBG
        )
    }
}

private extension Array {
    func sampled(maxCount: Int) -> [Element] {
        guard count > maxCount, maxCount > 1 else {
            return self
        }
        
        let step = Double(count - 1) / Double(maxCount - 1)
        return (0 ..< maxCount).map { index in
            self[Int((Double(index) * step).rounded(.toNearestOrAwayFromZero))]
        }
    }
}
