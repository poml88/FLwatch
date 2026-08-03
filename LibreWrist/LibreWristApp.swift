//
//  LibreWristApp.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.07.24.
//

import SwiftUI
import BackgroundTasks
import OSLog
import UIKit

@MainActor
final class FLwatchApplicationDelegate: NSObject, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        guard SharedData.cgmProviderKind == .libre3BLE,
              SharedData.libre3SensorIsPaired else { return }

        SensorAlertNotificationManager.shared.postApplicationTerminated()
    }
}

@main
struct LibreWristApp: App {
    @UIApplicationDelegateAdaptor(FLwatchApplicationDelegate.self) private var appDelegate

    private static let appRefreshTaskIdentifier = "de.poeml.philipp.LibreWrist.apprefresh"
    private let appRefreshScheduler = BGAppRefreshScheduler(
        taskIdentifier: appRefreshTaskIdentifier,
        refreshInterval: 5 * 60 // seems to result in 8-10 minute intervals
    )

    @Environment(\.scenePhase) private var scenePhase
        
    init(){
//        UserDefaults.group.register(defaults: Settings.defaults)
        print("init")
        if UserDefaults.group.connected == .connecting {
            UserDefaults.group.connected = .disconnected
        }

        LibreLinkUpHistory.shared.refreshFromPersistence(force: true)
        SensorSettingsStore.shared.refreshFromPersistence(force: true)
        LowGlucoseNotificationManager.shared.configureForegroundPresentation()
        SensorAlertNotificationManager.shared.clearApplicationTerminatedNotification()
        
        WatchConnectivityManager.shared.startSession()
        BluetoothHeartbeatManager.shared.startIfNeeded()
        if SharedData.bluetoothHeartbeatEnabled {
            BluetoothHeartbeatManager.shared.startScanning()
        }
        // Direct-BLE engine for the `.libre3BLE` provider. Creates its central
        // early (only when that provider is active) so CoreBluetooth state
        // restoration can deliver the sensor after a background relaunch; a
        // no-op for the cloud providers. The heartbeat above gates itself off
        // for `.libre3BLE`, so only one central ever owns the sensor.
        Libre3DirectManager.shared.startIfNeeded()
        // alternatively the session could be started in AppDelegate see https://developer.apple.com/documentation/swiftui/migrating-to-the-swiftui-life-cycle
        appRefreshScheduler.register()
        appRefreshScheduler.scheduleNextRefresh()
        scheduleLifecycleCatchUps()
        let lowGlucoseAlertsEnabled = SharedData.lowGlucoseNotificationsEnabled
        let highGlucoseAlertsEnabled = SharedData.highGlucoseNotificationsEnabled
        let criticalLowGlucoseAlertsEnabled = SharedData.cgmProviderKind == .libre3BLE &&
            SharedData.criticalLowGlucoseNotificationsEnabled
        if lowGlucoseAlertsEnabled || criticalLowGlucoseAlertsEnabled || highGlucoseAlertsEnabled {
            Task {
                let granted = await LowGlucoseNotificationManager.shared.requestAuthorizationIfNeeded()
                if !granted {
                    if lowGlucoseAlertsEnabled {
                        SharedData.lowGlucoseNotificationsEnabled = false
                    }
                    if criticalLowGlucoseAlertsEnabled {
                        SharedData.criticalLowGlucoseNotificationsEnabled = false
                    }
                    if highGlucoseAlertsEnabled {
                        SharedData.highGlucoseNotificationsEnabled = false
                    }
                }
            }
        }
    }
    
//    @State private var history = History()
    @State private var libreLinkUpHistory = LibreLinkUpHistory.shared
    @State private var sensorSettingsStore = SensorSettingsStore.shared
    @State private var currentIOBSingleton = CurrentIOBSingleton.shared
    @State private var insulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
//                .environment(history)
                .environment(\.libreLinkUpHistory, libreLinkUpHistory)
                .environment(\.sensorSettingsStore, sensorSettingsStore)
                .environment(\.currentIOBSingleton, currentIOBSingleton)
                .environment(\.insulinDeliveryHistorySingleton, insulinDeliveryHistorySingleton)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    LibreLinkUpHistory.shared.refreshFromPersistence()
                    SensorSettingsStore.shared.refreshFromPersistence()
                    scheduleLifecycleCatchUps()
                    Logger.bgTaskScheduler.info("Scene active: scheduling next BG refresh")
                    appRefreshScheduler.scheduleNextRefresh()
                    if SharedData.bluetoothHeartbeatEnabled {
                        BluetoothHeartbeatManager.shared.startScanning()
                    }
                }
//                .environment(\.openURL, OpenURLAction { url in
//                    print("openURL asked to open:", url)
//                    // print a stack trace so you can see who triggered this call
//                    print("stack trace:\n" + Thread.callStackSymbols.joined(separator: "\n"))
//                    return .systemAction
//                })
        }
    }

    private func scheduleLifecycleCatchUps() {
        Task {
            await NightscoutUploadManager.shared.reconcileRetainedGlucoseAndWait()
        }
        Task {
            // HealthKit reads may fail while locked, so reconcile both data
            // types when the app becomes active again.
            await AppleHealthExportManager.shared.exportAllAvailableDataIfNeeded()
        }
    }
}

final class BGAppRefreshScheduler {
    private let taskIdentifier: String
    private let refreshInterval: TimeInterval

    init(taskIdentifier: String, refreshInterval: TimeInterval) {
        self.taskIdentifier = taskIdentifier
        self.refreshInterval = refreshInterval
    }

    func register() {
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                Logger.bgTaskScheduler.error("Received wrong task type for \(self.taskIdentifier, privacy: .public)")
                task.setTaskCompleted(success: false)
                return
            }
            Logger.bgTaskScheduler.info("BG task launched: \(self.taskIdentifier, privacy: .public)")
            self.handleAppRefresh(task: appRefreshTask)
        }
        Logger.bgTaskScheduler.info("Register \(registered ? "success" : "failed", privacy: .public) for \(self.taskIdentifier, privacy: .public)")
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            let earliest = request.earliestBeginDate?.formatted(date: .abbreviated, time: .standard) ?? "nil"
            Logger.bgTaskScheduler.info("Submitted BG refresh request. earliestBeginDate=\(earliest, privacy: .public)")
        } catch {
            Logger.bgTaskScheduler.error("BG refresh submit failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        Logger.bgTaskScheduler.info("Handling BG refresh task")
        
        let executionTimestampsKey = "bgAppRefreshExecutionTimestamps"
        let now = Date()
        let cutoffDate = now.addingTimeInterval(-12 * 60 * 60)
        var executionTimestamps = (UserDefaults.group.array(forKey: executionTimestampsKey) as? [TimeInterval] ?? [])
            .map(Date.init(timeIntervalSince1970:))

        executionTimestamps.append(now)
        executionTimestamps = executionTimestamps.filter { $0 >= cutoffDate }
        UserDefaults.group.set(executionTimestamps.map(\.timeIntervalSince1970), forKey: executionTimestampsKey)

        let executionsInLast12Hours = executionTimestamps.count
        Logger.bgTaskScheduler.info("BG refresh executions in last 12 hours: \(executionsInLast12Hours, privacy: .public)")
        scheduleNextRefresh()

        let refreshTask = Task {
            Logger.bgTaskScheduler.info("Calling requestReloadIfNeeded()")
            await LibreLinkUpService.shared.requestReloadIfNeeded()
            Logger.bgTaskScheduler.info("Running Nightscout glucose catch-up from BG refresh")
            async let nightscoutCatchUp: Void = NightscoutUploadManager.shared
                .reconcileRetainedGlucoseAndWait(maximumDuration: 5)
            Logger.bgTaskScheduler.info("Running Apple Health catch-up export from BG refresh")
            await AppleHealthExportManager.shared.exportAllAvailableDataIfNeeded()
            await LiveActivityManager.shared.refreshFromCurrentHistory(
                useLiveActivities: SharedData.useLiveActivities,
                reloadFailed: LibreLinkUpService.shared.didLastReloadFail,
                refreshIOB: false
            )
            Logger.bgTaskScheduler.info("requestReloadIfNeeded() completed; live activity updated from BG refresh")
            WatchConnectivityManager.shared.sendLibreLinkUpSnapshotToWatch()
            Logger.bgTaskScheduler.info("new data sent to watch")
            await nightscoutCatchUp
            Logger.bgTaskScheduler.info("Nightscout BG catch-up finished or reached its five-second budget")
            guard !Task.isCancelled else { return }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            Logger.bgTaskScheduler.error("BG refresh task expired; cancelling")
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
