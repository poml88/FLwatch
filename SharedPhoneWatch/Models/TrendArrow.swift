//
//  TrendArrow.swift
//  LibreWrist
//
//  Created by Peter Müller on 26.08.24.
//

import Foundation

enum TrendArrow: Int, CustomStringConvertible, CaseIterable, Codable {
    case unknown            = -1
    case notDetermined      = 0
    case fallingQuickly     = 1
    case falling            = 2
    case stable             = 3
    case rising             = 4
    case risingQuickly      = 5
    // 6/7 are FLwatch-only extremes for Dexcom's double-arrow trends. The
    // LibreLinkUp server only ever sends rawValues 1–5, so these are never
    // produced on the Libre path — keep 1–5 frozen so Libre decoding by
    // rawValue stays correct.
    case fallingVeryQuickly = 6
    case risingVeryQuickly  = 7

    var description: String {
        switch self {
        case .notDetermined:      "NOT_DETERMINED"
        case .fallingVeryQuickly: "FALLING_VERY_QUICKLY"
        case .fallingQuickly:     "FALLING_QUICKLY"
        case .falling:            "FALLING"
        case .stable:             "STABLE"
        case .rising:             "RISING"
        case .risingQuickly:      "RISING_QUICKLY"
        case .risingVeryQuickly:  "RISING_VERY_QUICKLY"
        default:                  ""
        }
    }

    var descriptionSiri: LocalizedStringResource {
        switch self {
        case .notDetermined:      "not determined"
        case .fallingVeryQuickly: "falling very quickly"
        case .fallingQuickly:     "falling quickly"
        case .falling:            "falling"
        case .stable:             "stable"
        case .rising:             "rising"
        case .risingQuickly:      "rising quickly"
        case .risingVeryQuickly:  "rising very quickly"
        default:                  ""
        }
    }
    
    init(string: String) {
        self = Self.allCases.first { $0.description == string } ?? .unknown
    }
    
    var symbol: String {
        switch self {
        case .fallingVeryQuickly: "⇊"
        case .fallingQuickly:     "↓"
        case .falling:            "↘︎"
        case .stable:             "→"
        case .rising:             "↗︎"
        case .risingQuickly:      "↑"
        case .risingVeryQuickly:  "⇈"
        default:                  "-"
        }
    }
}


