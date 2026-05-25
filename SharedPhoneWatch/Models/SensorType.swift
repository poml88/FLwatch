//
//  SensorType.swift
//  LibreWrist
//
//  Created by Peter Müller on 19.08.24.
//

import Foundation

enum SensorType: String, CustomStringConvertible {
    case libre1        = "Libre 1"
    case libreUS14day  = "Libre US 14d"
    case libreProH     = "Libre Pro/H"
    case libre2        = "Libre 2"
    case libre2US      = "Libre 2 US"
    case libre2CA      = "Libre 2 CA"
    case libre2RU      = "Libre 2 RU"
    case libreSense    = "Libre Sense"
    case libre2Plus    = "Libre 2 Plus"
    case libre3        = "Libre 3"
    case libre3Plus    = "Libre 3 Plus"
    case lingo         = "Lingo"
    case dexcomG6      = "Dexcom G6"
    case dexcomG7      = "Dexcom G7"
    case dexcomONEPlus = "Dexcom ONE+"
    case unknown       = "unknown"

    var description: String { rawValue }
    var isALibre: Bool { self == .libre3 || self == .libre3Plus || self == .libre2 || self == .libre2Plus || self == .libre1 || self == .libreUS14day || self == .libreProH || self == .libre2US || self == .libre2CA || self == .libre2RU || self == .libreSense || self == .lingo }
    var isADexcom: Bool { self == .dexcomG6 || self == .dexcomG7 || self == .dexcomONEPlus }

    /// User-selectable Dexcom sensor types, in the order shown in the settings picker.
    /// Dexcom Share only exposes data for G6, G7, and ONE+ — plain "ONE" is excluded.
    static let dexcomSelectable: [SensorType] = [.dexcomG7, .dexcomONEPlus, .dexcomG6]
}

