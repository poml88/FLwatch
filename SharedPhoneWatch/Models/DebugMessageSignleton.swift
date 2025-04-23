//
//  DebugMessageSignleton.swift
//  LibreWrist
//
//  Created by Peter Müller on 18.04.25.
//

import SwiftUI


//struct SensorSettings {
//    let uom: Int
//    let targetLow: Int
//    let targetHigh: Int
//    let alarmLow: Int
//    let alarmHigh: Int
//    
//    init(uom: Int = 1, targetLow: Int = 70, targetHigh: Int = 180, alarmLow: Int = 80, alarmHigh: Int = 300) {
//        self.uom = uom
//        self.targetLow = targetLow
//        self.targetHigh = targetHigh
//        self.alarmLow = alarmLow
//        self.alarmHigh = alarmHigh
//    }
//}


@Observable class DebugMessageSingleton {
    
//    var sensorSettings: SensorSettings = SensorSettings()
//    var sensorType: SensorType = .unknown
    var libreLinkUpResponseError: String = "[...]"
    
    static let shared: DebugMessageSingleton = {
        let instance = DebugMessageSingleton()
        //nothing at the moment
        return instance
    }()
    
    private init(){}
}
    
extension EnvironmentValues {
    var debugMessageSingleton: DebugMessageSingleton {
        get { self[DebugMessageSingletonKey.self] }
        set { self[DebugMessageSingletonKey.self] = newValue }
    }
}


private struct DebugMessageSingletonKey: EnvironmentKey {
    static var defaultValue: DebugMessageSingleton = DebugMessageSingleton.shared
}
