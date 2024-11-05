//
//  GlucoseMeasurement.swift
//  LibreWrist
//
//  Created by Peter Müller on 10.09.24.
//

import Foundation

struct GlucoseMeasurement: Codable {
    let factoryTimestamp: String
    let timestamp: String
    let type: Int                // 0: graph, 1: logbook, 2: alarm, 3: hybrid
    let alarmType: Int?          // when type = 3  0: fixedLow, 1: low, 2: high
    let valueInMgPerDl: Int
    let trendArrow: TrendArrow?  // in logbook but not in graph data
    let trendMessage: String?
    let measurementColor: MeasurementColor
    let glucoseUnits: Int        // 0: mmoll, 1: mgdl
    let value: Double
    let isHigh: Bool
    let isLow: Bool
    enum CodingKeys: String, CodingKey { case factoryTimestamp = "FactoryTimestamp", timestamp = "Timestamp", type, alarmType, valueInMgPerDl = "ValueInMgPerDl", trendArrow = "TrendArrow", trendMessage = "TrendMessage", measurementColor = "MeasurementColor", glucoseUnits = "GlucoseUnits", value = "Value", isHigh, isLow }
}
