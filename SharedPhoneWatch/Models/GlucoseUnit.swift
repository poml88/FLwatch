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

    init(uom: Int) {
        self = uom == 0 ? .mmoll : .mgdl
    }

    var description: String {
        switch self {
        case .mgdl:  "mg/dL"
        case .mmoll: "mmol/L"
        }
    }
}


extension Int {
    func displayedGlucoseValue(glucoseUnit: GlucoseUnit) -> Double {
        glucoseUnit == .mmoll ? toMmolL() : toDouble()
    }

    func displayedGlucoseValue(glucoseUnitValue: Int) -> Double {
        displayedGlucoseValue(glucoseUnit: GlucoseUnit(uom: glucoseUnitValue))
    }

    func asGlucose(glucoseUnitValue: Int, withUnit: Bool = false) -> String {
        asGlucose(glucoseUnit: GlucoseUnit(uom: glucoseUnitValue), withUnit: withUnit)
    }

    @MainActor
    var units: String {
        asGlucose(glucoseUnitValue: SensorSettingsStore.shared.sensorSettings.uom)
    }
}

extension Double {
    @MainActor
    var units: String {
        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        if glucoseUnit == .mmoll {
            return GlucoseFormatters.mmolLFormatter.string(from: self.toMmolL() as NSNumber) ?? String(format: "%.1f", self.toMmolL())
        }
        return GlucoseFormatters.mgdLFormatter.string(from: self as NSNumber) ?? String(format: "%.0f", self)
    }
}
