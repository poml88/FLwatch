//
//  LibreWristWatchApp.swift
//  LibreWristWatch Watch App
//
//  Created by Peter Müller on 26.08.24.
//

import SwiftUI

@main
struct LibreWristWatch_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init(){
//        UserDefaults.group.register(defaults: Settings.defaults)
        print("init")
//        FLwatchShortcuts.updateAppShortcutParameters()
        LibreLinkUpHistory.shared.refreshFromPersistence(force: true)
        SensorSettingsStore.shared.refreshFromPersistence(force: true)
        WatchConnectivityManager.shared.startSession()
    }
    
    @State private var libreLinkUpHistory = LibreLinkUpHistory.shared
    @State private var sensorSettingsStore = SensorSettingsStore.shared
    @State private var currentIOBSingleton = CurrentIOBSingleton.shared
    @State private var insulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.libreLinkUpHistory, libreLinkUpHistory)
                .environment(\.sensorSettingsStore, sensorSettingsStore)
                .environment(\.currentIOBSingleton, currentIOBSingleton)
                .environment(\.insulinDeliveryHistorySingleton, insulinDeliveryHistorySingleton)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    LibreLinkUpHistory.shared.refreshFromPersistence()
                    SensorSettingsStore.shared.refreshFromPersistence()
                }
        }
    }
}
