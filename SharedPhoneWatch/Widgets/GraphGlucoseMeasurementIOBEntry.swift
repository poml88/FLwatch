//
//  GraphGlucoseMeasurementIOBEntry.swift
//  FLwatch
//
//  Created by Peter Müller on 19.01.26.
//

import WidgetKit

struct GraphGlucoseMeasurementIOBEntry: TimelineEntry {
    let date: Date
    let lastGlucoseMeasurement: LibreLinkUpGlucose
    var graph: [LibreLinkUpGlucose]
    var currentIOB: Double
    let uom: Int
    let maxBG: Int
    
    static let sampleEntry = GraphGlucoseMeasurementIOBEntry(
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
        currentIOB: 0.1,
        uom: 1,
        maxBG: 250
    )
    
    
    static var invalidEntry: GraphGlucoseMeasurementIOBEntry {
        GraphGlucoseMeasurementIOBEntry(
            date: Date(),
            lastGlucoseMeasurement: LibreLinkUpGlucose(
                glucose: Glucose(0, id: 0, date: Date(), source: ""),
                color: .gray,
                trendArrow: .unknown
            ),
            graph: [LibreLinkUpGlucose(glucose: Glucose(0, id: 0, date: Date(), source: "Sample"), color: .green, trendArrow: .stable)
                   ],
            currentIOB: -1,
            uom: 1,
            maxBG: 250
        )
    }
    
    
    static func getPatientGraph(timeout _: TimeInterval = 10,
                                completion: @escaping (GraphGlucoseMeasurementIOBEntry?, Error?) -> Void) {
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
                                forceReload: Bool = false) async throws -> GraphGlucoseMeasurementIOBEntry {
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
    private static func entryFromHistory() async -> GraphGlucoseMeasurementIOBEntry? {
        let history = LibreLinkUpHistory.shared
        // Push-only BLE never reloads in the widget, so re-read the app's writes
        // from disk; cloud providers refresh via their reload (see
        // GlucoseMeasurementIOBEntry).
        if SharedData.cgmProviderKind == .libre3BLE {
            history.refreshFromPersistence(force: true)
        }
        let sensor = SensorSettingsStore.shared
        guard history.currentGlucose > 0 else { return nil }
        guard let lastGlucose = latestHistoryValue(from: history) else { return nil }

        let dateTwoHoursTenAgo: Date = Date(timeIntervalSinceNow: -2 * 60 * 60 - 10 * 60)
        var graph = history.libreLinkUpGlucose.filter { $0.glucose.date > dateTwoHoursTenAgo }
        if !graph.contains(where: { $0.glucose.date == lastGlucose.glucose.date && $0.id == lastGlucose.id }) {
            graph.append(lastGlucose)
        }
        graph.sort(by: { $0.glucose.date < $1.glucose.date })

        let indexOfMaxGlucoseItem = graph.indices.max(by: { graph[$0].glucose.value < graph[$1].glucose.value }) ?? 0
        let maxBG = graph.isEmpty ? max(history.maxBG, 250) : graph[indexOfMaxGlucoseItem].glucose.value

        InsulinDeliveryHistorySingleton.shared.read() // widget/intents must refresh singleton from UserDefaults.
        let currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()

        return GraphGlucoseMeasurementIOBEntry(
            date: lastGlucose.glucose.date,
            lastGlucoseMeasurement: lastGlucose,
            graph: graph,
            currentIOB: currentIOB,
            uom: sensor.sensorSettings.uom,
            maxBG: maxBG
        )
    }

    @MainActor
    private static func latestHistoryValue(from history: LibreLinkUpHistory) -> LibreLinkUpGlucose? {
        history.latestLibreLinkUpGlucose
    }

    func invalidated(currentIOB: Double) -> GraphGlucoseMeasurementIOBEntry {
        GraphGlucoseMeasurementIOBEntry(
            date: date,
            lastGlucoseMeasurement: LibreLinkUpGlucose(
                glucose: Glucose(0, id: 0, date: date, source: lastGlucoseMeasurement.glucose.source),
                color: .gray,
                trendArrow: .unknown
            ),
            graph: graph,
            currentIOB: currentIOB,
            uom: uom,
            maxBG: maxBG
        )
    }
}
