//
//  InsulinObjects.swift
//  LibreWrist
//
//  Created by Peter Müller on 01.09.24.
//

import SwiftUI

enum InsulinType: Int, CaseIterable {
    case rapidActing = 0
    case fastRapidActing = 1
    
    var description: String {
        switch self {
        case .rapidActing:
            return "Rapid acting"
        case .fastRapidActing:
            return "Fast rapid acting"
        }
    }
    var fullDescription: String {
        switch self {
        case .rapidActing:
            return "Rapid acting (Novolog, ...)"
        case .fastRapidActing:
            return "Fast rapid acting (Fiasp, Lyumjev, ...)"
        }
    }
    var presets: InsulinTypePresets {
        switch self {
        case .rapidActing:
            return .rapidActing
        case .fastRapidActing:
            return .fastRapidActing
        }
    }
}

struct InsulinDelivery: Codable, Identifiable {
    let id: UUID
    let timeStamp: Double
    let insulinUnits: Double
    
    init(id: UUID, timestamp: Double, insulinUnits: Double) {
        self.id = UUID()
        self.timeStamp = timestamp
        self.insulinUnits = insulinUnits
    }
}

struct InsulinTypePresets: Codable, Identifiable {
    let id: UUID
    let actionDuration: Double
    let peakActivityTime: Double
    let delay: Double
    
    init(id: UUID, actionDuration: Double, peakActivityTime: Double, delay: Double) {
        self.id = UUID()
        self.actionDuration = actionDuration
        self.peakActivityTime = peakActivityTime
        self.delay = delay
    }
    static let rapidActing = InsulinTypePresets(id: UUID(), actionDuration: 360 * 60, peakActivityTime: 75 * 60, delay: 10 * 60)
    static let fastRapidActing = InsulinTypePresets(id: UUID(), actionDuration: 360 * 60, peakActivityTime: 55 * 60, delay: 10 * 60)
}


@Observable class CurrentIOBSingleton {
    
    var currentIOB: Double = 0.0
    
    static let shared: CurrentIOBSingleton = {
        let instance = CurrentIOBSingleton()
        return instance
    }()
    
    private init() {}
    
    func getCurrentIOB() -> Double {
        var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
        var sumIOB: Double = 0
        for item in insulinDeliveryHistory {
            if Date().timeIntervalSince1970 - item.timeStamp > 12 * 60 * 60 {
                insulinDeliveryHistory.removeAll(where: {$0.id == item.id})
            } else {
                let IOB =   updateIOB(timeStamp: item.timeStamp) * item.insulinUnits
                sumIOB = sumIOB + IOB
            }
        }
        
        UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
        let currentIOB: Double = sumIOB
        return currentIOB
    }
    
    private func updateIOB(timeStamp time: Double) -> Double {
        let insulin:InsulinType = UserDefaults.group.insulinTypeSelected
        let preset: InsulinTypePresets = insulin.presets
        let model = ExponentialInsulinModel(actionDuration: preset.actionDuration, peakActivityTime: preset.peakActivityTime, delay: preset.delay)
        let result = model.percentEffectRemaining(at: Date().timeIntervalSince1970 - time)
        return result
    }

}





extension EnvironmentValues {
    var currentIOBSingleton: CurrentIOBSingleton {
        get { self[CurrentIOBSingletonKey.self] }
        set { self[CurrentIOBSingletonKey.self] = newValue }
    }
}


private struct CurrentIOBSingletonKey: EnvironmentKey {
    static var defaultValue: CurrentIOBSingleton = CurrentIOBSingleton.shared
}


