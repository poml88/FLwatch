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
    var libreLinkUpGlucose: [LibreLinkUpGlucose] = []
    var libreLinkUpMinuteGlucose: [LibreLinkUpGlucose] = []
    var lastReadingDate: Date = Date(timeIntervalSinceNow: -999 * 60)
    var currentGlucose: Int = 0
    var currentTrendArrow: String = "---"
    var maxBG: Int = 250
    
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
    
    private init() {}
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
        instance.libreLinkUpGlucose = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 1000,
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
        
        instance.libreLinkUpMinuteGlucose = [LibreLinkUpGlucose(glucose: Glucose(rawValue: 820,
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

