//
//  WatchConnectivityManager.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.04.25.
//

//import Foundation
import SwiftUI
import UserNotifications
import WatchConnectivity
import OSLog

class WatchConnectivityManager: NSObject, WCSessionDelegate, UNUserNotificationCenterDelegate {  // ObservableObject is the old method, Swiftui now uses @Observable
    // https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
    // https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
    
//    @Published var receivedMessage: String = ""
    
    private static let libreLinkUpSnapshotContent = "libreLinkUpSnapshot"
    private static let libreLinkUpSnapshotDataKey = "snapshotData"
    private static let settingsSnapshotContent = "settingsSnapshot"
    private static let settingsSnapshotDataKey = "settingsSnapshotData"
    private static let requestSettingsSnapshotContent = "requestSettingsSnapshot"
    private static let lowGlucoseAlertContent = "lowGlucoseAlert"
    private static let lowGlucoseAlertDataKey = "lowGlucoseAlertData"
#if os(watchOS)
    private static let watchLowGlucoseNotificationIdentifierPrefix = "watch-low-glucose-alert"
    private static let watchLowGlucoseAlertFreshness: TimeInterval = 3 * 60
    private static let watchLowGlucoseAlertTriggerDelay: TimeInterval = 1
    private static let watchLowGlucoseAlertCooldown: TimeInterval = 45
#endif

    private static let loggedDataPreviewByteCount = 20

    private struct LibreLinkUpSnapshotPayload: Codable {
        let libreLinkUpGlucose: [LibreLinkUpGlucose]
        let libreLinkUpMinuteGlucose: [LibreLinkUpGlucose]
        let latestLibreLinkUpGlucose: LibreLinkUpGlucose?
        let lastReadingDate: Date
        let currentGlucose: Int
        let currentTrendArrow: String
        let maxBG: Int
    }

    private struct SettingsSnapshotPayload: Codable {
        let insulinTypeSelected: Int
        let showInsulinDeliveryMarksWatch: Bool
        let showIOBCurveWatch: Bool
        let showActivityCurveWatch: Bool
        let widgetUpdateFrequency: Int
        let tapComplicationReloads: Bool
        let hasValidCredentials: Bool
        let username: String?
        let password: String?
        let patientId: String?
        let cgmProviderKind: String?
        // Dexcom Share credentials. Sent only when Dexcom is the active
        // provider and connected; nil otherwise (and from older phone builds).
        // They let the watch run its own Share reloads when the phone is
        // unreachable, mirroring the LibreLinkUp username/password path.
        let dexcomShareUsername: String?
        let dexcomShareRegion: String?
        let dexcomSharePassword: String?
        let dexcomShareAccountId: String?
        let dexcomShareSessionId: String?
        let updatedAt: Date
    }

    private struct LowGlucoseAlertPayload: Codable {
        let title: String
        let subtitle: String
        let body: String
        let sentAt: Date
    }

#if os(watchOS)
    private enum WatchAppVisibilityState {
        case active
        case inactive
        case background

        var isFrontmost: Bool {
            self == .active || self == .inactive
        }
    }
#endif

    @MainActor
    private static func shouldApplySnapshot(_ snapshot: LibreLinkUpSnapshotPayload, to history: LibreLinkUpHistoryStore) -> Bool {
        snapshot.lastReadingDate > history.lastReadingDate
    }

    private static func mergeMinuteGlucose(
        existing: [LibreLinkUpGlucose],
        received: [LibreLinkUpGlucose],
        libreLinkUpGlucose: [LibreLinkUpGlucose]
    ) -> [LibreLinkUpGlucose] {
        var mergedByID: [Int: LibreLinkUpGlucose] = [:]

        for entry in existing {
            mergedByID[entry.id] = entry
        }

        for entry in received {
            guard let current = mergedByID[entry.id] else {
                mergedByID[entry.id] = entry
                continue
            }

            if entry.glucose.date >= current.glucose.date {
                mergedByID[entry.id] = entry
            }
        }

        let merged = mergedByID.values.sorted {
            if $0.id == $1.id {
                return $0.glucose.date > $1.glucose.date
            }
            return $0.id > $1.id
        }

        guard libreLinkUpGlucose.indices.contains(1) else {
            return merged
        }

        let previousGraphPointDate = libreLinkUpGlucose[1].glucose.date
        return merged.filter { $0.glucose.date > previousGraphPointDate }
    }

    private static func summarizedLogValue(_ value: Any) -> String {
        if let data = value as? Data {
            let preview = data.prefix(loggedDataPreviewByteCount)
                .map { String(format: "%02x", $0) }
                .joined(separator: " ")
            let suffix = data.count > loggedDataPreviewByteCount ? " ..." : ""
            return "<Data \(data.count) bytes: \(preview)\(suffix)>"
        }

        if let dictionary = value as? [String: Any] {
            let entries = dictionary.keys.sorted().map { key in
                "\(key): \(summarizedLogValue(dictionary[key] as Any))"
            }
            return "[\(entries.joined(separator: ", "))]"
        }

        if let array = value as? [Any] {
            let items = array.map(summarizedLogValue)
            return "[\(items.joined(separator: ", "))]"
        }

        return String(describing: value)
    }

    private static func summarizedMessageForLogging(_ message: [String: Any]) -> String {
        summarizedLogValue(message)
    }

    private var messageHandlers: [WatchMessageHandler] = []
    private var requestHandlers: [WatchRequestHandler] = []
#if os(watchOS)
    private let watchNotificationCenter = UNUserNotificationCenter.current()
    private var watchAppVisibilityState: WatchAppVisibilityState = .background
    private var lastWatchLowGlucoseAlertAt: Date = .distantPast
    private var lastScheduledWatchLowGlucoseSentAt: TimeInterval = 0
#endif
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Logger.connectivity.info("Session activation complete: \(activationState.rawValue)")
#if os(watchOS)
        if activationState == .activated {
            requestSettingsSnapshotFromPhone()
        }
#endif
    }
    
#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        Logger.connectivity.info("Session did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        Logger.connectivity.info("Session did deactivate")
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
//        print("\(#function): activationState = \(session.activationState.rawValue)")
        Logger.connectivity.info("Session Watch State did change")
    }

#endif
    
   
    
    private func received(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
        
//        DispatchQueue.main.async { [self] in
//            receivedMessage = message["message"] as? String ?? "Not found"
//        }

        Logger.connectivity.info("Message received: \(Self.summarizedMessageForLogging(message))")
        
        if message["content"] as? String == "credentials" {
            UserDefaults.group.username = message["username"] as? String ?? ""
            let password = message["password"] as? String ?? ""
            try? PasswordKeychain.save(password)
            if let patientId = message["patientId"] as? String, !patientId.isEmpty {
                SharedData.libreLinkUpPatientId = patientId
            }
            SharedData.libreLinkUpToken = ""
            UserDefaults.group.connected = .connected
            Task { @MainActor in
                await LibreLinkUpService.shared.requestReloadIfNeeded(force: true)
            }
        }

        if message["content"] as? String == "updateLibreLinkUpPatient" {
            let patientId = message["patientId"] as? String ?? ""
            if !patientId.isEmpty {
                SharedData.libreLinkUpPatientId = patientId
            }
        }
        
        if message["content"] as? String == "insulinDelivery" {
            let deliveryID = UUID(uuidString: message["id"] as? String ?? "") ?? UUID()
            let timeStamp = message["timeStamp"] as? Double ?? Date().timeIntervalSince1970 - 12 * 3600
            let insulinUnits = message["units"] as? Double ?? 0.0
            let insulinType = message["insulinType"] as? Int ?? UserDefaults.group.insulinTypeSelected.rawValue
            Task { @MainActor in
                await InsulinDeliveryHistorySingleton.shared.recordDeliveryAndAwaitExport(
                    id: deliveryID,
                    timestamp: Date(timeIntervalSince1970: timeStamp),
                    insulinUnits: insulinUnits,
                    insulinType: insulinType
                )
            }
        }
        
        if message["content"] as? String == "clearInsulinHistory" {
            Task { @MainActor in
                InsulinDeliveryHistorySingleton.shared.clearHistory()
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            }
        }
        
        if message["content"] as? String == "deleteInsulin" {
            Task { @MainActor in
                let didRemove: Bool
                if let idString = message["id"] as? String, let deliveryID = UUID(uuidString: idString) {
                    didRemove = InsulinDeliveryHistorySingleton.shared.removeDelivery(id: deliveryID)
                } else {
                    let timeStamp = message["timestamp"] as? Double ?? Date().timeIntervalSince1970 - 12 * 3600
                    didRemove = InsulinDeliveryHistorySingleton.shared.removeDeliveries(timestamp: timeStamp)
                }
                if didRemove {
                    CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                }
            }
        }
        
        if message["content"] as? String == "updateInsulinTypeSelected" {
            let valueRaw = message["insulinTypeSelected"] as? Int ?? 0
            let valueType: InsulinType = InsulinType(rawValue: valueRaw) ?? .rapidActing
            UserDefaults.group.insulinTypeSelected = valueType
        }
        
        if message["content"] as? String == "showInsulinDeliveryMarksWatchMessage" {
            let valueBool = message["showInsulinDeliveryMarksWatch"] as? Bool ?? false
            SharedData.showInsulinDeliveryMarksWatch = valueBool
            Task { @MainActor in
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            }
        }
        if message["content"] as? String == "showIOBCurveWatchMessage" {
            let valueBool = message["showIOBCurveWatch"] as? Bool ?? false
            SharedData.showIOBCurveWatch = valueBool
            Task { @MainActor in
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            }
        }
        
        if message["content"] as? String == "showActivityCurveWatchMessage" {
            let valueBool = message["showActivityCurveWatch"] as? Bool ?? false
            SharedData.showActivityCurveWatch = valueBool
            Task { @MainActor in
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            }
        }
        
        if message["content"] as? String == "updateWidgetUpdateFrequency" {
            let valueInt: Int = message["widgetUpdateFrequency"] as? Int ?? 5
            SharedData.widgetUpdateFrequency = valueInt
        }
        
        if message["content"] as? String == "tapComplicationReloadsMessage" {
            let valueBool = message["tapComplicationReloads"] as? Bool ?? false
            SharedData.tapComplicationReloads = valueBool
        }

        if message["content"] as? String == Self.requestSettingsSnapshotContent {
#if os(iOS)
            sendSettingsSnapshotToWatch()
#endif
        }

        if message["content"] as? String == Self.settingsSnapshotContent {
            guard let settingsData = message[Self.settingsSnapshotDataKey] as? Data else {
                Logger.connectivity.error("Missing settings snapshot data in message")
                return
            }

            do {
                let snapshot = try JSONDecoder().decode(SettingsSnapshotPayload.self, from: settingsData)
                applySettingsSnapshot(snapshot)
                Logger.connectivity.info("Applied settings snapshot from WatchConnectivity dated \(snapshot.updatedAt.formatted())")
            } catch {
                Logger.connectivity.error("Failed to decode settings snapshot: \(error.localizedDescription)")
            }
        }

        if message["content"] as? String == Self.libreLinkUpSnapshotContent {
            guard let snapshotData = message[Self.libreLinkUpSnapshotDataKey] as? Data else {
                Logger.connectivity.error("Missing LibreLinkUp snapshot data in message")
                return
            }
            do {
                let snapshot = try JSONDecoder().decode(LibreLinkUpSnapshotPayload.self, from: snapshotData)
#if os(watchOS)
                SharedData.watchPeerSnapshotLastReceivedDate = Date()
#endif
                Task { @MainActor in
                    let history = LibreLinkUpHistory.shared
                    _ = history.refreshFromPersistence()
                    guard Self.shouldApplySnapshot(snapshot, to: history) else {
                        Logger.connectivity.info("Ignored stale LibreLinkUp snapshot from WatchConnectivity")
                        return
                    }

                    let didApply = history.replaceCacheAndPersist(
                        libreLinkUpGlucose: snapshot.libreLinkUpGlucose,
                        libreLinkUpMinuteGlucose: Self.mergeMinuteGlucose(
                            existing: history.libreLinkUpMinuteGlucose,
                            received: snapshot.libreLinkUpMinuteGlucose,
                            libreLinkUpGlucose: snapshot.libreLinkUpGlucose
                        ),
                        latestLibreLinkUpGlucose: snapshot.latestLibreLinkUpGlucose,
                        lastReadingDate: snapshot.lastReadingDate,
                        currentGlucose: snapshot.currentGlucose,
                        currentTrendArrow: snapshot.currentTrendArrow,
                        maxBG: snapshot.maxBG,
                        lastSuccessfulLibreLinkUpAPICall: history.lastSuccessfulLibreLinkUpAPICall
                    )
                    guard didApply else {
                        Logger.connectivity.error("Failed to persist LibreLinkUp snapshot from WatchConnectivity")
                        return
                    }

//                    CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs() // Seems to be totally unnecessary here.
                    Logger.connectivity.info("Applied fresh LibreLinkUp snapshot from WatchConnectivity")
                }
            } catch {
                Logger.connectivity.error("Failed to decode LibreLinkUp snapshot: \(error.localizedDescription)")
            }
        }

        if message["content"] as? String == Self.lowGlucoseAlertContent {
            guard let alertData = message[Self.lowGlucoseAlertDataKey] as? Data else {
                Logger.connectivity.error("Missing low glucose alert data in message")
                return
            }

            do {
                let alertPayload = try JSONDecoder().decode(LowGlucoseAlertPayload.self, from: alertData)
#if os(watchOS)
                Task {
                    await scheduleWatchLowGlucoseNotificationIfNeeded(for: alertPayload)
                }
#endif
            } catch {
                Logger.connectivity.error("Failed to decode low glucose alert payload: \(error.localizedDescription)")
            }
        }


        
        if let replyHandler = replyHandler {
            
            let responseHandler: (WatchMessage) -> Void = { responseMessage in
                var dictionary = responseMessage.dictionary
                dictionary["_type"] = String(describing: type(of: responseMessage))
                replyHandler(dictionary)
            }
            
            if let _ = requestHandlers.firstIndex(where: { $0.handle(dictionary: message, responseHandler: responseHandler) }) {
                return
            }
        }
    }
    
    func sendMessageToPairedDevice(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
        guard WCSession.isSupported() else {
            Logger.connectivity.error("Device does not support WatchConnectivity")
            return
        }
        guard session.activationState == .activated else {
            Logger.connectivity.error("WCSession not activated")
            return
        }
        if session.isReachable {
            //            let message: [String: Any] = ["message": message]
            Logger.connectivity.info("Session reachable, sending message: \(message)")
            session.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in // Watch App: sendMessage only works if app is active in foreground
                Logger.connectivity.error("\(error)")
                if message["useApplicationContext"] as? Bool ?? true {
                    Logger.connectivity.warning("Error, trying updateApplicationContext")
                    do {
                        try self.updateApplicationContextMessage(message)
                    } catch {
                        Logger.connectivity.error("updateApplicationContext failed: \(error.localizedDescription)")
                    }
                } else {
                    Logger.connectivity.warning("Error, trying transferUserInfo")
                    //                try? WCSession.default.updateApplicationContext(message)
                    self.session.transferUserInfo(message) // transferUserInfo does not work in Simulator!!
                }
            })
        } else {
            Logger.connectivity.warning("Session not reachable / counterpart app not available for live messaging")
            if message["useApplicationContext"] as? Bool ?? false {
                Logger.connectivity.warning("Trying updateApplicationContext. Sending message: \(message).")
                do {
                    try self.updateApplicationContextMessage(message)
                } catch {
                    Logger.connectivity.error("updateApplicationContext failed: \(error.localizedDescription)")
                }
            } else {
                Logger.connectivity.warning("Trying transferUserInfo. Sending message: \(message).")
                //                try? WCSession.default.updateApplicationContext(message)
                self.session.transferUserInfo(message) // transferUserInfo does not work in Simulator!!
            }
        }
    }

#if os(iOS)
    func sendSettingsSnapshotToWatch() {
        let providerKind = SharedData.cgmProviderKind
        let isConnected = UserDefaults.group.connected == .connected

        // Per-provider credential bundle. Only the active provider's secrets are
        // sent, and only when connected.
        var hasValidCredentials = false
        var username: String?
        var password: String?
        var patientId: String?
        var dexcomShareUsername: String?
        var dexcomShareRegion: String?
        var dexcomSharePassword: String?
        var dexcomShareAccountId: String?
        var dexcomShareSessionId: String?

        switch providerKind {
        case .libreLinkUp:
            let llUsername = UserDefaults.group.username
            let llPassword = try? PasswordKeychain.read()
            hasValidCredentials = isConnected
                && !llUsername.isEmpty
                && !(llPassword ?? "").isEmpty
            if hasValidCredentials {
                username = llUsername
                password = llPassword
                patientId = SharedData.libreLinkUpPatientId.isEmpty ? nil : SharedData.libreLinkUpPatientId
            }
        case .dexcomShare:
            let dxUsername = SharedData.dexcomShareUsername
            let dxPassword = (try? DexcomShareTokenStore.read(.password)) ?? nil
            let dxAccountId = (try? DexcomShareTokenStore.read(.accountId)) ?? nil
            let dxSessionId = (try? DexcomShareTokenStore.read(.sessionId)) ?? nil
            hasValidCredentials = isConnected
                && !dxUsername.isEmpty
                && SharedData.dexcomShareRegionIsKnown
                && !(dxPassword ?? "").isEmpty
                && !(dxAccountId ?? "").isEmpty
            if hasValidCredentials {
                dexcomShareUsername = dxUsername
                dexcomShareRegion = SharedData.dexcomShareRegion.rawValue
                dexcomSharePassword = dxPassword
                dexcomShareAccountId = dxAccountId
                dexcomShareSessionId = dxSessionId
            }
        }

        let snapshot = SettingsSnapshotPayload(
            insulinTypeSelected: UserDefaults.group.insulinTypeSelected.rawValue,
            showInsulinDeliveryMarksWatch: SharedData.showInsulinDeliveryMarksWatch,
            showIOBCurveWatch: SharedData.showIOBCurveWatch,
            showActivityCurveWatch: SharedData.showActivityCurveWatch,
            widgetUpdateFrequency: SharedData.widgetUpdateFrequency,
            tapComplicationReloads: SharedData.tapComplicationReloads,
            hasValidCredentials: hasValidCredentials,
            username: username,
            password: password,
            patientId: patientId,
            cgmProviderKind: providerKind.rawValue,
            dexcomShareUsername: dexcomShareUsername,
            dexcomShareRegion: dexcomShareRegion,
            dexcomSharePassword: dexcomSharePassword,
            dexcomShareAccountId: dexcomShareAccountId,
            dexcomShareSessionId: dexcomShareSessionId,
            updatedAt: Date()
        )

        do {
            let settingsData = try JSONEncoder().encode(snapshot)
            let messageToWatch: [String: Any] = [
                "content": Self.settingsSnapshotContent,
                Self.settingsSnapshotDataKey: settingsData,
                "useApplicationContext": false
            ]
            sendMessageToPairedDevice(messageToWatch)
        } catch {
            Logger.connectivity.error("Failed to encode settings snapshot: \(error.localizedDescription)")
        }
    }

    func sendLibreLinkUpSnapshotToWatch() {
        Task { @MainActor in
            let history = LibreLinkUpHistory.shared
            let snapshot = LibreLinkUpSnapshotPayload(
                libreLinkUpGlucose: history.libreLinkUpGlucose,
                libreLinkUpMinuteGlucose: history.libreLinkUpMinuteGlucose,
                latestLibreLinkUpGlucose: history.latestLibreLinkUpGlucose,
                lastReadingDate: history.lastReadingDate,
                currentGlucose: history.currentGlucose,
                currentTrendArrow: history.currentTrendArrow,
                maxBG: history.maxBG
            )

            do {
                let snapshotData = try JSONEncoder().encode(snapshot)
                let messageToWatch: [String: Any] = [
                    "content": Self.libreLinkUpSnapshotContent,
                    Self.libreLinkUpSnapshotDataKey: snapshotData,
                    "useApplicationContext": true
                ]
                sendMessageToPairedDevice(messageToWatch)
            } catch {
                Logger.connectivity.error("Failed to encode LibreLinkUp snapshot: \(error.localizedDescription)")
            }
        }
    }
#endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        received(message)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any] ) {
        deliverApplicationContext(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        received(userInfo)
    }
    
    func session(_ session: WCSession,
                 didFinish userInfoTransfer: WCSessionUserInfoTransfer,
                 error: Error?) {
        if let error = error {
            Logger.connectivity.error("transferUserInfo finished with error: \(error.localizedDescription)")
        } else {
            Logger.connectivity.info("transferUserInfo finished successfully. Keys: \(userInfoTransfer.userInfo.keys)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        Logger.connectivity.info("Reachability changed: reachable=\(session.isReachable)")
        // Optional: when becoming reachable, try sending any locally queued events
    }
    
    var session: WCSession = .default // not sure what happens if WatchConnectivity is not supported, I guess it does not matter, as all modern iPhones and iOS versions support it. All apple watches support it as well, obviously
    
  
    static let shared: WatchConnectivityManager = {
        let instance = WatchConnectivityManager()
        // nothing at the moment so can be used as well: static let shared: WatchConnectivityManager = WatchConnectivityManager()
        // static implies lazy
        return instance
    }()

    
//    init(session: WCSession = .default) {
//        self.session = session
//        super.init()
//        session.delegate = self
//        session.activate()
//    }
    
    private override init(){
        super.init()
    }

    private func applySettingsSnapshot(_ snapshot: SettingsSnapshotPayload) {
        UserDefaults.group.insulinTypeSelected = InsulinType(rawValue: snapshot.insulinTypeSelected) ?? .rapidActing
        SharedData.showInsulinDeliveryMarksWatch = snapshot.showInsulinDeliveryMarksWatch
        SharedData.showIOBCurveWatch = snapshot.showIOBCurveWatch
        SharedData.showActivityCurveWatch = snapshot.showActivityCurveWatch
        SharedData.widgetUpdateFrequency = snapshot.widgetUpdateFrequency
        SharedData.tapComplicationReloads = snapshot.tapComplicationReloads

        // Mirror the phone's active CGM provider and its credentials in one
        // ordered MainActor task. switchProvider() flips `connected` to
        // .disconnected, so the credential application that re-sets it to
        // .connected must run *after* the switch — hence the single task.
        // Older phone builds send a nil cgmProviderKind: fall back to whatever
        // the watch already had.
        let targetKind = snapshot.cgmProviderKind.flatMap { CGMProviderKind(rawValue: $0) }
        Task { @MainActor in
            if let targetKind, targetKind != SharedData.cgmProviderKind {
                LibreLinkUpService.shared.switchProvider(to: targetKind)
            }
            switch targetKind ?? SharedData.cgmProviderKind {
            case .dexcomShare:
                await self.applyDexcomShareCredentials(from: snapshot)
            case .libreLinkUp:
                await self.applyLibreLinkUpCredentials(from: snapshot)
            }
        }
    }

    @MainActor
    private func applyLibreLinkUpCredentials(from snapshot: SettingsSnapshotPayload) async {
        let shouldForceReload =
            snapshot.hasValidCredentials
            && !(snapshot.username ?? "").isEmpty
            && !(snapshot.password ?? "").isEmpty

        guard shouldForceReload,
              let username = snapshot.username,
              let password = snapshot.password else {
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            return
        }

        let existingUsername = UserDefaults.group.username
        let existingPassword = (try? PasswordKeychain.read()) ?? ""
        let existingPatientId = SharedData.libreLinkUpPatientId
        let hasToken = !SharedData.libreLinkUpToken.isEmpty
        UserDefaults.group.username = username
        try? PasswordKeychain.save(password)
        if let patientId = snapshot.patientId, !patientId.isEmpty {
            SharedData.libreLinkUpPatientId = patientId
        }
        let credentialsChanged =
            username != existingUsername ||
            password != existingPassword ||
            ((snapshot.patientId ?? "").isEmpty == false && snapshot.patientId != existingPatientId)
        if credentialsChanged {
            SharedData.libreLinkUpToken = ""
        }
        UserDefaults.group.connected = .connected
        if credentialsChanged || !hasToken {
            await LibreLinkUpService.shared.requestReloadIfNeeded(force: true)
        } else {
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        }
    }

    @MainActor
    private func applyDexcomShareCredentials(from snapshot: SettingsSnapshotPayload) async {
        guard snapshot.hasValidCredentials,
              let username = snapshot.dexcomShareUsername, !username.isEmpty,
              let regionRaw = snapshot.dexcomShareRegion, let region = ShareRegion(rawValue: regionRaw),
              let password = snapshot.dexcomSharePassword, !password.isEmpty,
              let accountId = snapshot.dexcomShareAccountId, !accountId.isEmpty else {
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            return
        }

        let existingUsername = SharedData.dexcomShareUsername
        let existingPassword = ((try? DexcomShareTokenStore.read(.password)) ?? nil) ?? ""
        let existingAccountId = ((try? DexcomShareTokenStore.read(.accountId)) ?? nil) ?? ""
        let hadSession = !(((try? DexcomShareTokenStore.read(.sessionId)) ?? nil) ?? "").isEmpty

        SharedData.dexcomShareUsername = username
        SharedData.dexcomShareRegion = region
        try? DexcomShareTokenStore.save(password, kind: .password)
        try? DexcomShareTokenStore.save(accountId, kind: .accountId)
        if let sessionId = snapshot.dexcomShareSessionId, !sessionId.isEmpty {
            try? DexcomShareTokenStore.save(sessionId, kind: .sessionId)
        }
        UserDefaults.group.connected = .connected

        let credentialsChanged =
            username != existingUsername ||
            password != existingPassword ||
            accountId != existingAccountId
        if credentialsChanged || !hadSession {
            await LibreLinkUpService.shared.requestReloadIfNeeded(force: true)
        } else {
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        }
    }

    func requestSettingsSnapshotFromPhone() {
#if os(watchOS)
        let message: [String: Any] = [
            "content": Self.requestSettingsSnapshotContent,
            "useApplicationContext": false
        ]
        sendMessageToPairedDevice(message)
#endif
    }
    
    func startSession() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
#if os(watchOS)
            configureWatchLowGlucoseNotifications()
#endif
            for transfer in session.outstandingUserInfoTransfers {
                Logger.connectivity.info("Outstanding transfer: \(transfer.userInfo.keys) isTransferring=\(transfer.isTransferring)")
                // Optional: if you detect very old or duplicated items, decide whether to cancel or leave them
                // transfer.cancel() // if appropriate
            }
        }
    }

    private func updateApplicationContextMessage(_ message: [String: Any]) throws {
        guard let content = message["content"] as? String else {
            try session.updateApplicationContext(message)
            return
        }

        var mergedContext = session.applicationContext
        mergedContext[content] = message
        try session.updateApplicationContext(mergedContext)
    }

    private func deliverApplicationContext(_ applicationContext: [String: Any]) {
        var deliveredAnyMessage = false
        for value in applicationContext.values {
            guard let nestedMessage = value as? [String: Any],
                  nestedMessage["content"] != nil else {
                continue
            }
            deliveredAnyMessage = true
            received(nestedMessage)
        }

        if deliveredAnyMessage {
            return
        }

        if applicationContext["content"] != nil {
            received(applicationContext)
            return
        }

        if !deliveredAnyMessage {
            Logger.connectivity.info("Ignoring application context without recognized messages: \(applicationContext.keys)")
        }
    }

#if os(iOS)
    func sendLowGlucoseAlertToWatch(title: String, subtitle: String, body: String, sentAt: Date) {
        let payload = LowGlucoseAlertPayload(
            title: title,
            subtitle: subtitle,
            body: body,
            sentAt: sentAt
        )

        do {
            let alertData = try JSONEncoder().encode(payload)
            let messageToWatch: [String: Any] = [
                "content": Self.lowGlucoseAlertContent,
                Self.lowGlucoseAlertDataKey: alertData,
                "useApplicationContext": true
            ]
            sendMessageToPairedDevice(messageToWatch)
        } catch {
            Logger.connectivity.error("Failed to encode low glucose alert payload: \(error.localizedDescription)")
        }
    }
#endif

#if os(watchOS)
    func updateWatchScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            watchAppVisibilityState = .active
        case .inactive:
            watchAppVisibilityState = .inactive
        case .background:
            watchAppVisibilityState = .background
        @unknown default:
            watchAppVisibilityState = .background
        }
        Logger.connectivity.info("Updated watch scene phase to \(String(describing: scenePhase), privacy: .public)")
    }

    private func configureWatchLowGlucoseNotifications() {
        watchNotificationCenter.delegate = self
    }

    func requestWatchLowGlucoseNotificationAuthorization() {
        Task {
            _ = await requestWatchNotificationAuthorizationIfNeeded()
        }
    }

    private func requestWatchNotificationAuthorizationIfNeeded() async -> Bool {
        let settings = await watchNotificationCenter.notificationSettings()
        guard settings.authorizationStatus != .denied else {
            Logger.connectivity.warning("Watch low glucose notification authorization denied")
            return false
        }

        if [.authorized, .provisional].contains(settings.authorizationStatus) {
            return true
        }

        do {
            return try await watchNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.connectivity.error("Watch low glucose notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    private func scheduleWatchLowGlucoseNotificationIfNeeded(for payload: LowGlucoseAlertPayload) async {
        Logger.connectivity.info(
            "Watch low glucose fallback received: state=\(String(describing: self.watchAppVisibilityState), privacy: .public), sentAt=\(payload.sentAt.formatted(date: .omitted, time: .standard), privacy: .public)"
        )
        guard watchAppVisibilityState.isFrontmost else {
            Logger.connectivity.info("Skipping watch low glucose fallback: app not frontmost")
            return
        }

        let now = Date()
        let alertAge = now.timeIntervalSince(payload.sentAt)
        Logger.connectivity.info("Watch low glucose fallback age: \(alertAge, privacy: .public)s")
        guard now.timeIntervalSince(payload.sentAt) <= Self.watchLowGlucoseAlertFreshness else {
            Logger.connectivity.info("Skipping watch low glucose fallback: alert is stale")
            return
        }

        let sentAtInterval = payload.sentAt.timeIntervalSince1970
        guard sentAtInterval > lastScheduledWatchLowGlucoseSentAt else {
            Logger.connectivity.info("Skipping watch low glucose fallback: already scheduled this alert")
            return
        }

        guard now.timeIntervalSince(lastWatchLowGlucoseAlertAt) >= Self.watchLowGlucoseAlertCooldown else {
            Logger.connectivity.info("Skipping watch low glucose fallback: cooldown active")
            return
        }

        let settings = await watchNotificationCenter.notificationSettings()
        Logger.connectivity.info(
            "Watch notification settings: authorization=\(settings.authorizationStatus.rawValue, privacy: .public), alerts=\(settings.alertSetting.rawValue, privacy: .public), sound=\(settings.soundSetting.rawValue, privacy: .public)"
        )
        guard [.authorized, .provisional].contains(settings.authorizationStatus) else {
            Logger.connectivity.warning("Skipping watch low glucose fallback: notification authorization unavailable")
            return
        }
        guard settings.alertSetting == .enabled || settings.notificationCenterSetting == .enabled else {
            Logger.connectivity.warning("Skipping watch low glucose fallback: alerts disabled in system settings")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.subtitle = payload.subtitle
        content.body = payload.body
        if settings.soundSetting == .enabled {
            content.sound = .default
        }
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1

        let requestIdentifier = "\(Self.watchLowGlucoseNotificationIdentifierPrefix)-\(Int(now.timeIntervalSince1970))"
        let pendingRequests = await watchNotificationCenter.pendingNotificationRequests()
        let matchingPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.watchLowGlucoseNotificationIdentifierPrefix) }
        if !matchingPendingIdentifiers.isEmpty {
            watchNotificationCenter.removePendingNotificationRequests(withIdentifiers: matchingPendingIdentifiers)
        }

        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: Self.watchLowGlucoseAlertTriggerDelay, repeats: false)
        )

        do {
            try await watchNotificationCenter.add(request)
            lastWatchLowGlucoseAlertAt = now
            lastScheduledWatchLowGlucoseSentAt = sentAtInterval
            Logger.connectivity.info("Scheduled watch low glucose fallback notification with identifier \(requestIdentifier, privacy: .public)")
        } catch {
            Logger.connectivity.error("Failed to schedule watch low glucose fallback notification: \(error.localizedDescription)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier.hasPrefix(Self.watchLowGlucoseNotificationIdentifierPrefix) else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound])
    }
#endif
}

protocol WatchMessage {
    
    init?(dictionary: [String : Any])
    var dictionary: [String : Any] { get }
}

private protocol WatchMessageHandler {
    func handle(dictionary: [String : Any]) -> Bool
}
private protocol WatchRequestHandler {
    func handle(dictionary: [String : Any], responseHandler: @escaping (WatchMessage) -> Void) -> Bool
}


//extension WatchMessage {
//
//    func send(replyHandler: (([String : Any]) -> Void)? = nil) {
//        WatchMessageService.singleton.send(message: self, replyHandler: replyHandler)
//    }
//
//    func send<T: WatchMessage>(responseHandler: @escaping (T) -> Void) {
//        WatchMessageService.singleton.send(request: self, responseHandler: responseHandler)
//    }
//}
