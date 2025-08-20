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

struct ActivityCurveDataPoint: Codable, Identifiable {
    let id: Int //timeinterval
    let date: Date
    let value: Double
}

struct InsulinDelivery: Codable, Identifiable {
    let id: UUID
    let timeStamp: Double
    let insulinUnits: Double
    let insulinType: Int
    
    init(id: UUID, timestamp: Double, insulinUnits: Double, insulinType: Int) {
        self.id = UUID()
        self.timeStamp = timestamp
        self.insulinUnits = insulinUnits
        self.insulinType = insulinType
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

@Observable class InsulinDeliveryHistorySingleton {
    
    var insulinDeliveryHistory: [InsulinDelivery] = []
    
    static let shared: InsulinDeliveryHistorySingleton = {
        // nothing at the moment so can be used as well: static let shared: InsulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton()
        // static implies lazy
        let instance = InsulinDeliveryHistorySingleton()
        return instance
    }()
    
    private init() {
        insulinDeliveryHistory = UserDefaults.group.insulinDeliveryHistory ?? []
    }
}

@Observable class CurrentIOBSingleton {
    
    var currentIOB: Double = 0.0
    var insulinOnBoardCurve: [ActivityCurveDataPoint] = []
    var insulinActivityCurve: [ActivityCurveDataPoint] = []
    var maxIOB: Double = 1
    var maxActivity: Double = 1
    
    static let shared: CurrentIOBSingleton = {
        let instance = CurrentIOBSingleton()
        return instance
    }()
    
    private init() {}
    
    func getCurrentIOB() -> Double {
        let insulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton.shared
        insulinDeliveryHistorySingleton.insulinDeliveryHistory = UserDefaults.group.insulinDeliveryHistory ?? [] // It is necessary to read in the UserDefaults value because widgets and app are individual programs with individual Singletons...
//        var insulinDeliveryHistory: [InsulinDelivery] = insulinDeliveryHistorySingleton.insulinDeliveryHistory
        var sumIOB: Double = 0
        for item in insulinDeliveryHistorySingleton.insulinDeliveryHistory {
            let timeIntervalBetweenDeliveryAndNow = Date().timeIntervalSince1970 - item.timeStamp
            if timeIntervalBetweenDeliveryAndNow > 12 * 60 * 60 {
                insulinDeliveryHistorySingleton.insulinDeliveryHistory.removeAll(where: {$0.id == item.id})
            } else {
                let timeIntervalBetweenDeliveryAndNow = Date().timeIntervalSince1970 - item.timeStamp
                let IOB =   updateIOB(timeStamp: timeIntervalBetweenDeliveryAndNow, insulinType: item.insulinType) * item.insulinUnits
                sumIOB = sumIOB + IOB
            }
        }
        
        UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistorySingleton.insulinDeliveryHistory
        let currentIOB: Double = sumIOB
        return currentIOB
    }
    
    private func updateIOB(timeStamp timeInterval: Double, insulinType type: InsulinType.RawValue) -> Double {
        let insulin: InsulinType = InsulinType(rawValue: type) ?? .rapidActing
        let preset: InsulinTypePresets = insulin.presets
        let model = ExponentialInsulinModel(actionDuration: preset.actionDuration, peakActivityTime: preset.peakActivityTime, delay: preset.delay)
        let result = model.percentEffectRemaining(at: timeInterval)
        return result
    }
    
    func calculateInsulinOnBoardCurve() -> [ActivityCurveDataPoint] {
        let insulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton.shared
        insulinDeliveryHistorySingleton.insulinDeliveryHistory = UserDefaults.group.insulinDeliveryHistory ?? [] // It is necessary to read in the UserDefaults value because widgets and app are individual programs with individual Singletons...
        
        if insulinDeliveryHistorySingleton.insulinDeliveryHistory.count < 1 { return [] }
        
        var activityCurve: [ActivityCurveDataPoint] = []
        let minutes = 5 * 60
        for timeInterval in stride(from: 6 * 60 * 60, through: -2 * 60 * 60, by: -minutes) {
            var sumIOB: Double = 0
            for item in insulinDeliveryHistorySingleton.insulinDeliveryHistory {
                let timeIntervalBetweenDeliveryAndNow = Date().timeIntervalSince1970 - item.timeStamp
                if timeIntervalBetweenDeliveryAndNow < 6 * 60 * 60 {
                    let timeIntervalBetweenDeliveryAndTimeStampToBeCalculated = Date().timeIntervalSince1970 - Double(timeInterval) - item.timeStamp
                    if timeIntervalBetweenDeliveryAndTimeStampToBeCalculated >= 0 { // timeIntervalBetweenDeliveryAndTimeStampToBeCalculated < timeIntervalBetweenDeliveryAndNow &&
                        let IOB =   updateIOB(timeStamp: timeIntervalBetweenDeliveryAndTimeStampToBeCalculated, insulinType: item.insulinType) * item.insulinUnits
                        sumIOB = sumIOB + IOB
                    }
                }
            }
            if sumIOB > 0 {
                let dataPoint: ActivityCurveDataPoint = ActivityCurveDataPoint(id: timeInterval, date: Date(timeIntervalSinceNow: -Double(timeInterval)), value: sumIOB)
//                print("\(dataPoint)")
                activityCurve.append(dataPoint)
            }
        }
        return activityCurve
    }
    
    func calculateinsulinActivityCurve() -> [ActivityCurveDataPoint] {
        let currentIOBSingleton = CurrentIOBSingleton.shared
        let IOBcurve: [ActivityCurveDataPoint] = currentIOBSingleton.insulinOnBoardCurve
        
        if IOBcurve.count < 2 { return []}
        
        var activityCurve: [ActivityCurveDataPoint] = []
        for i in 0..<IOBcurve.count - 1 {
            let difference = IOBcurve[i].value - IOBcurve[i + 1].value
            if difference > 0 {
                let dataPoint = ActivityCurveDataPoint(id: IOBcurve[i + 1].id, date: IOBcurve[i + 1].date, value: difference)
//                print("\(dataPoint)")
                activityCurve.append(dataPoint)
            }
        }
        return activityCurve
    }
    
    func updateCurrentIOBAndGraphs() {
//                print("Updating graphs: \(Date.now)")
        //MARK: Update IOB
        currentIOB = getCurrentIOB()
        
        //MARK: Update IOB graph
#if os(iOS)
        if SharedData.showIOBCurvePhone == false && SharedData.showActivityCurvePhone == false { insulinOnBoardCurve = []; insulinActivityCurve = []; maxIOB = 1000; return }
#endif
#if os(watchOS)
        if SharedData.showIOBCurveWatch == false && SharedData.showActivityCurveWatch == false { insulinOnBoardCurve = []; insulinActivityCurve = []; maxIOB = 1000; return }
#endif
        
        insulinOnBoardCurve = calculateInsulinOnBoardCurve()
        let indexOfMaxInsulinItem = insulinOnBoardCurve.indices.max(by:
                                                                        { insulinOnBoardCurve[$0].value < insulinOnBoardCurve[$1].value }
        ) ?? 0
        maxIOB = { insulinOnBoardCurve.count > 0 ? insulinOnBoardCurve[indexOfMaxInsulinItem].value : 1 }()
        
        //MARK: Update insulin activity graph
#if os(iOS)
        if SharedData.showActivityCurvePhone == false {
            insulinActivityCurve = []
            insulinOnBoardCurve = insulinOnBoardCurve.filter { $0.date < Date.now }
            return
        }
#endif
#if os(watchOS)
        if SharedData.showActivityCurveWatch == false {
            insulinActivityCurve = []
            insulinOnBoardCurve = insulinOnBoardCurve.filter { $0.date < Date.now }
            return
        }
#endif
        
        insulinActivityCurve = calculateinsulinActivityCurve()
        let indexOfMaxActivityItem = insulinActivityCurve.indices.max(by:
                                                                        { insulinActivityCurve[$0].value < insulinActivityCurve[$1].value }
        ) ?? 0
        maxActivity = { insulinActivityCurve.count > 0 ? insulinActivityCurve[indexOfMaxActivityItem].value : 1 }()
        
        insulinOnBoardCurve = insulinOnBoardCurve.filter { $0.date < Date.now }
        insulinActivityCurve = insulinActivityCurve.filter { $0.date < Date.now }
    }
}





extension EnvironmentValues {
    var insulinDeliveryHistorySingleton: InsulinDeliveryHistorySingleton {
        get { self[InsulinDeliveryHistorySingletonKey.self] }
        set { self[InsulinDeliveryHistorySingletonKey.self] = newValue }
    }
    
    var currentIOBSingleton: CurrentIOBSingleton {
        get { self[CurrentIOBSingletonKey.self] }
        set { self[CurrentIOBSingletonKey.self] = newValue }
    }
}


private struct InsulinDeliveryHistorySingletonKey: EnvironmentKey {
    static var defaultValue: InsulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton.shared
}

private struct CurrentIOBSingletonKey: EnvironmentKey {
    static var defaultValue: CurrentIOBSingleton = CurrentIOBSingleton.shared
}


