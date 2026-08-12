//
//  LibreLinkUpGlucose.swift
//  LibreWrist
//
//  Created by Peter Müller on 10.09.24.
//

import Foundation

// `id` is computed, so synthesized equality compares the three stored properties.
struct LibreLinkUpGlucose: Identifiable, Codable, Equatable {
    let glucose: Glucose
    let color: MeasurementColor
    let trendArrow: TrendArrow?
    var id: Int { glucose.id }
}
