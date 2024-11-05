//
//  GlucoseUnit.swift
//  LibreWrist
//
//  Created by Peter Müller on 19.08.24.
//

import Foundation

enum GlucoseUnit: String, CustomStringConvertible, CaseIterable, Identifiable {
    case mgdl, mmoll
    var id: String { rawValue}
    
    static let exchangeRate: Double = 0.0555

    var description: String {
        switch self {
        case .mgdl:  "mg/dL"
        case .mmoll: "mmol/L"
        }
    }
}


extension Int {
    var units: String {
        SensorSettingsSingleton.shared.sensorSettings.uom == 0 ?
//        UserDefaults.standard.bool(forKey: "displayingMillimoles") ?
        String(format: "%.1f", Double(self) / 18.0182) : String(self)
    }
}

extension Double {
    var units: String {
        SensorSettingsSingleton.shared.sensorSettings.uom == 0 ?
//        UserDefaults.standard.bool(forKey: "displayingMillimoles") ?
        String(format: "%.1f", self / 18.0182) : String(format: "%.0f", self)
    }
}
