//
//  LibreLinkUpHistory.swift
//  LibreWrist
//
//  Created by Peter Müller on 10.09.24.
//

import SwiftUI

@Observable class LibreLinkUpHistory {
//    var glucose: [Glucose] = []
//    var color: [MeasurementColor] = []
//    var trendArrow: [TrendArrow?] = []
//    var id: [Glucose.ID] = []
    var libreLinkUpGlucose: [LibreLinkUpGlucose] = [] { didSet { persist() } }
    var libreLinkUpMinuteGlucose: [LibreLinkUpGlucose] = [] { didSet { persist() } }
    var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60) { didSet { persist() } }
    var currentGlucose: Int = 0 { didSet { persist() } } // always in mg/dl
    var currentTrendArrow: String = "---" { didSet { persist() } }
    var maxBG: Int = 100 { didSet { persist() } }
    var uom: Int = 1 { didSet { persist() } } // 0: mmol/L, 1: mg/dL
    var lastOnlineDate: Date = Date(timeIntervalSinceNow: -1 * 60 * 60 * 24) {
        didSet {
            persist()
        }
    }
    
    let libreLinkUpGlucoseDefaultEntries = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 1000,
                                                                                rawTemperature: 4,
                                                                                temperatureAdjustment: 4,
                                                                                trendRate: 4.0,
                                                                                trendArrow: .stable,
                                                                                id: 6020,
                                                                                date: Date(timeIntervalSinceNow: -3 * 60 * 60),
                                                                                hasError: false),
                                                               color: MeasurementColor.green,
                                                               trendArrow: TrendArrow(rawValue: 0)),
                                            LibreLinkUpGlucose(glucose: Glucose(rawValue: 1500,
                                                                                rawTemperature: 4,
                                                                                temperatureAdjustment: 4,
                                                                                trendRate: 4.0,
                                                                                trendArrow: .stable,
                                                                                id: 6025,
                                                                                date: Date(timeIntervalSinceNow: -2 * 60 * 60),
                                                                                hasError: false),
                                                               color: MeasurementColor.green,
                                                               trendArrow: TrendArrow(rawValue: 0)),
                                            LibreLinkUpGlucose(glucose: Glucose(rawValue: 800,
                                                                                rawTemperature: 4,
                                                                                temperatureAdjustment: 4,
                                                                                trendRate: 4.0,
                                                                                trendArrow: .stable,
                                                                                id: 6030,
                                                                                date: Date(timeIntervalSinceNow: -1 * 60 * 60),
                                                                                hasError: false),
                                                               color: MeasurementColor.green,
                                                               trendArrow: TrendArrow(rawValue: 0))]
    
    private var isRestoring = false

    private init() {}

    private struct Snapshot: Codable {
        let libreLinkUpGlucose: [LibreLinkUpGlucose]
        let libreLinkUpMinuteGlucose: [LibreLinkUpGlucose]
        let lastReadingDate: Date
        let currentGlucose: Int
        let currentTrendArrow: String
        let maxBG: Int
        let uom: Int?
        let lastOnlineDate: Date?
    }

    private func persist() {
        guard !isRestoring else { return }
        let snapshot = Snapshot(
            libreLinkUpGlucose: libreLinkUpGlucose,
            libreLinkUpMinuteGlucose: libreLinkUpMinuteGlucose,
            lastReadingDate: lastReadingDate,
            currentGlucose: currentGlucose,
            currentTrendArrow: currentTrendArrow,
            maxBG: maxBG,
            uom: uom,
            lastOnlineDate: lastOnlineDate
        )
        UserDefaults.group.setObject(snapshot, forKey: .libreLinkUpHistorySnapshot)
    }



  

    @discardableResult
    private func restore() -> Bool {
        guard let snapshot: Snapshot = UserDefaults.group.getObject(forKey: .libreLinkUpHistorySnapshot) else {
            return false
        }
        isRestoring = true
        libreLinkUpGlucose = snapshot.libreLinkUpGlucose
        libreLinkUpMinuteGlucose = snapshot.libreLinkUpMinuteGlucose
        lastReadingDate = snapshot.lastReadingDate
        currentGlucose = snapshot.currentGlucose
        currentTrendArrow = snapshot.currentTrendArrow
        maxBG = snapshot.maxBG
        uom = snapshot.uom ?? 1
        lastOnlineDate = snapshot.lastOnlineDate ?? Date(timeIntervalSinceNow: -1 * 60 * 60 * 24)
        isRestoring = false
        return true
    }

    /// Refreshes the in-memory singleton from app-group persistence.
    /// Useful in widgets/intents where another process may have written newer data.
    @discardableResult
    func refreshFromPersistedSnapshot() -> Bool {
        restore()
    }

    private func loadDefaultData() {
        libreLinkUpGlucose = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 1000,
                                                                   rawTemperature: 4,
                                                                   temperatureAdjustment: 4,
                                                                   trendRate: 4.0,
                                                                   trendArrow: .stable,
                                                                   id: 6020,
                                                                   date: Date(timeIntervalSinceNow: -3 * 60 * 60),
                                                                   hasError: false),
                                                  color: MeasurementColor.green,
                                                  trendArrow: TrendArrow(rawValue: 0)),
                              LibreLinkUpGlucose(glucose: Glucose(rawValue: 1500,
                                                                  rawTemperature: 4,
                                                                  temperatureAdjustment: 4,
                                                                  trendRate: 4.0,
                                                                  trendArrow: .stable,
                                                                  id: 6025,
                                                                  date: Date(timeIntervalSinceNow: -2 * 60 * 60),
                                                                  hasError: false),
                                                 color: MeasurementColor.green,
                                                 trendArrow: TrendArrow(rawValue: 0)),
                              LibreLinkUpGlucose(glucose: Glucose(rawValue: 800,
                                                                  rawTemperature: 4,
                                                                  temperatureAdjustment: 4,
                                                                  trendRate: 4.0,
                                                                  trendArrow: .stable,
                                                                  id: 6030,
                                                                  date: Date(timeIntervalSinceNow: -1 * 60 * 60),
                                                                  hasError: false),
                                                 color: MeasurementColor.green,
                                                 trendArrow: TrendArrow(rawValue: 0))]

        libreLinkUpMinuteGlucose = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 820,
                                                                         rawTemperature: 4,
                                                                         temperatureAdjustment: 4,
                                                                         trendRate: 4.0,
                                                                         trendArrow: .stable,
                                                                         id: 1,
                                                                         date: Date(timeIntervalSinceNow: -1 * 60 * 60 - 120),
                                                                         hasError: false),
                                                        color: MeasurementColor.green,
                                                        trendArrow: TrendArrow(rawValue: 0)),
                                    LibreLinkUpGlucose(glucose: Glucose(rawValue: 810,
                                                                        rawTemperature: 4,
                                                                        temperatureAdjustment: 4,
                                                                        trendRate: 4.0,
                                                                        trendArrow: .stable,
                                                                        id: 2,
                                                                        date: Date(timeIntervalSinceNow: -1 * 60 * 60 - 60),
                                                                        hasError: false),
                                                       color: MeasurementColor.green,
                                                       trendArrow: TrendArrow(rawValue: 0)),
                                    LibreLinkUpGlucose(glucose: Glucose(rawValue: 800,
                                                                        rawTemperature: 4,
                                                                        temperatureAdjustment: 4,
                                                                        trendRate: 4.0,
                                                                        trendArrow: .stable,
                                                                        id: 3,
                                                                        date: Date(timeIntervalSinceNow: -1 * 60 * 60),
                                                                        hasError: false),
                                                       color: MeasurementColor.green,
                                                       trendArrow: TrendArrow(rawValue: 0))]
        uom = 1
        lastOnlineDate = Date(timeIntervalSinceNow: -1 * 60 * 60 * 24)
    }
}

extension LibreLinkUpHistory {
    static let shared: LibreLinkUpHistory = {
//        let libreLinkUpHistory = LibreLinkUpHistory()
//        libreLinkUpHistory.glucose.append(Glucose(rawValue: 1000,
//                                                  rawTemperature: 4,
//                                                  temperatureAdjustment: 4,
//                                                  trendRate: 4.0,
//                                                  trendArrow: .stable,
//                                                  id: 6020,
//                                                  date: Date(timeIntervalSince1970: 746239583),
//                                                  hasError: false))
//        libreLinkUpHistory.color.append(MeasurementColor.green)
//        libreLinkUpHistory.trendArrow.append(TrendArrow(rawValue: 0))
        let instance = LibreLinkUpHistory()
        if !instance.restore() {
            instance.loadDefaultData()
        }
        return instance
    }()
    
}

extension EnvironmentValues {
    var libreLinkUpHistory: LibreLinkUpHistory {
        get { self[LibreLinkUpHistoryKey.self] }
        set { self[LibreLinkUpHistoryKey.self] = newValue }
    }
}


private struct LibreLinkUpHistoryKey: EnvironmentKey {
    static var defaultValue: LibreLinkUpHistory = LibreLinkUpHistory.shared
}
