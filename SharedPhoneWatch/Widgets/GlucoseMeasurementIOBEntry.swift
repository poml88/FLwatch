//
//  GlucoseMeasurementEntry.swift
//  LibreWrist
//
//  Created by Peter Müller on 08.10.24.
//

import WidgetKit

struct GlucoseMeasurementIOBEntry: TimelineEntry {
    let date: Date
    let glucoseMeasurement: GlucoseMeasurement
    var currentIOB: Double
    
    static let sampleEntry = GlucoseMeasurementIOBEntry(date: Date(), glucoseMeasurement: GlucoseMeasurement(factoryTimestamp: "", timestamp: "", type: 0, alarmType: 3, valueInMgPerDl: 105, trendArrow: .stable, trendMessage: "", measurementColor: .green, glucoseUnits: 1, value: 105, isHigh: false, isLow: false), currentIOB: 0.1)
    
    static var invalidEntry: GlucoseMeasurementIOBEntry {
        GlucoseMeasurementIOBEntry(
            date: Date(),
            glucoseMeasurement: GlucoseMeasurement(factoryTimestamp: "", timestamp: "", type: 0, alarmType: 3, valueInMgPerDl: 0, trendArrow: .unknown, trendMessage: "", measurementColor: .gray, glucoseUnits: 1, value: 0, isHigh: false, isLow: false),
            currentIOB: -1
        )
    }
    
    
    static func getLastGlucoseMeasurement(timeout _: TimeInterval = 10,
                                          completion: @escaping (GlucoseMeasurementIOBEntry?, Error?) -> Void) {
        Task {
            do {
                let entry = try await getLastGlucoseMeasurement()
                await MainActor.run { completion(entry, nil) }
            } catch {
                await MainActor.run { completion(nil, error) }
            }
        }
    }

    static func getLastGlucoseMeasurement(maxAgeMinutes: Int? = nil,
                                          forceReload: Bool = false) async throws -> GlucoseMeasurementIOBEntry {
        // The reload gate is about whether a *network* fetch is feasible here.
        // It is not a precondition for *displaying* a value: persisted history
        // can be fresher than the gate, e.g. when the phone re-authenticated
        // and pushed new readings via WatchConnectivity after the widget's
        // own session expired and was cleared.
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
    private static func entryFromHistory() async -> GlucoseMeasurementIOBEntry? {
        let history = LibreLinkUpHistory.shared
        // The widget is a separate process from the app. Cloud providers reload
        // here, which updates the in-process store — leave them untouched. But
        // push-only direct BLE never reloads in the widget: the app writes the
        // store, so we must re-read it from disk or `shared` stays stale
        // (currentGlucose 0) and the caller throws "Missing CGM credentials" →
        // blank widget.
        if SharedData.cgmProviderKind == .libre3BLE {
            history.refreshFromPersistence(force: true)
        }
        let sensor = SensorSettingsStore.shared
        guard history.currentGlucose > 0 else { return nil }

        guard let latest = latestHistoryValue(from: history) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        let timestamp = formatter.string(from: latest.glucose.date)
        let uom = sensor.sensorSettings.uom
        let value = uom == 0 ? latest.glucose.value.toMmolL() : Double(latest.glucose.value)

        let measurement = GlucoseMeasurement(
            factoryTimestamp: timestamp,
            timestamp: timestamp,
            type: 0,
            alarmType: nil,
            valueInMgPerDl: latest.glucose.value,
            trendArrow: latest.trendArrow,
            trendMessage: nil,
            measurementColor: latest.color,
            glucoseUnits: uom,
            value: value,
            isHigh: false,
            isLow: false
        )

        InsulinDeliveryHistorySingleton.shared.read() // widget/intents must refresh singleton from UserDefaults.
        let currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()

        return GlucoseMeasurementIOBEntry(
            date: latest.glucose.date,
            glucoseMeasurement: measurement,
            currentIOB: currentIOB
        )
    }

    @MainActor
    private static func latestHistoryValue(from history: LibreLinkUpHistory) -> LibreLinkUpGlucose? {
        history.latestLibreLinkUpGlucose
    }

    func invalidated(currentIOB: Double) -> GlucoseMeasurementIOBEntry {
        GlucoseMeasurementIOBEntry(
            date: date,
            glucoseMeasurement: GlucoseMeasurement(
                factoryTimestamp: glucoseMeasurement.factoryTimestamp,
                timestamp: glucoseMeasurement.timestamp,
                type: glucoseMeasurement.type,
                alarmType: glucoseMeasurement.alarmType,
                valueInMgPerDl: 0,
                trendArrow: .unknown,
                trendMessage: glucoseMeasurement.trendMessage,
                measurementColor: .gray,
                glucoseUnits: glucoseMeasurement.glucoseUnits,
                value: 0,
                isHigh: false,
                isLow: false
            ),
            currentIOB: currentIOB
        )
    }
//    static func updateIOB(timeStamp time: Double) -> Double {
//        let model = ExponentialInsulinModel(actionDuration: 270 * 60, peakActivityTime: 120 * 60, delay: 15 * 60)
//        let result = model.percentEffectRemaining(at: Date().timeIntervalSince1970 - time)
//        return result
//    }
    
}
