//
//  TrendArrow.swift
//  LibreWrist
//
//  Created by Peter Müller on 26.08.24.
//

import Foundation

enum TrendArrow: Int, CustomStringConvertible, CaseIterable, Codable {
    case unknown        = -1
    case notDetermined  = 0
    case fallingQuickly = 1
    case falling        = 2
    case stable         = 3
    case rising         = 4
    case risingQuickly  = 5
    
    var description: String {
        switch self {
        case .notDetermined:  "NOT_DETERMINED"
        case .fallingQuickly: "FALLING_QUICKLY"
        case .falling:        "FALLING"
        case .stable:         "STABLE"
        case .rising:         "RISING"
        case .risingQuickly:  "RISING_QUICKLY"
        default:              ""
        }
    }
    
    var descriptionSiri: LocalizedStringResource {
        switch self {
        case .notDetermined:  "not determined"
        case .fallingQuickly: "falling quickly"
        case .falling:        "falling"
        case .stable:         "stable"
        case .rising:         "rising"
        case .risingQuickly:  "rising quickly"
        default:              ""
        }
    }
    
    init(string: String) {
        self = Self.allCases.first { $0.description == string } ?? .unknown
    }
    
    var symbol: String {
        switch self {
        case .fallingQuickly: "↓"
        case .falling:        "↘︎"
        case .stable:         "→"
        case .rising:         "↗︎"
        case .risingQuickly:  "↑"
        default:              "-"
        }
    }
}


