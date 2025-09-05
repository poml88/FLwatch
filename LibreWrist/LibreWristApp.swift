//
//  LibreWristApp.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.07.24.
//

import SwiftUI


@main
struct LibreWristApp: App {
        
    init(){
        UserDefaults.group.register(defaults: Settings.defaults)
        print("init")
        if UserDefaults.group.connected == .connecting {
            UserDefaults.group.connected = .disconnected
        }
        FLwatchShortcuts.updateAppShortcutParameters()
        WatchConnectivityManager.shared.startSession()
        // alternatively the session could be started in AppDelegate see https://developer.apple.com/documentation/swiftui/migrating-to-the-swiftui-life-cycle

    }
    
//    @State private var history = History()
    @State private var libreLinkUpHistory = LibreLinkUpHistory.shared
    @State private var sensorSettingsSingleton = SensorSettingsSingleton.shared
    @State private var currentIOBSingleton = CurrentIOBSingleton.shared
    @State private var insulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
//                .environment(history)
                .environment(\.libreLinkUpHistory, libreLinkUpHistory)
                .environment(\.sensorSettingsSingleton, sensorSettingsSingleton)
                .environment(\.currentIOBSingleton, currentIOBSingleton)
                .environment(\.insulinDeliveryHistorySingleton, insulinDeliveryHistorySingleton)
//                .environment(\.openURL, OpenURLAction { url in
//                    print("openURL asked to open:", url)
//                    // print a stack trace so you can see who triggered this call
//                    print("stack trace:\n" + Thread.callStackSymbols.joined(separator: "\n"))
//                    return .systemAction
//                })
        }
    }
}





