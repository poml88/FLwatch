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
import CryptoKit

enum Libre3ProvisioningReadiness: Equatable, Sendable {
    case waitingForSensorSetup
    case ready
    case outdated
}

class WatchConnectivityManager: NSObject, WCSessionDelegate, UNUserNotificationCenterDelegate {  // ObservableObject is the old method, Swiftui now uses @Observable
    // https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
    // https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
    
//    @Published var receivedMessage: String = ""
    
    private static let libreLinkUpSnapshotContent = "libreLinkUpSnapshot"
    private static let libreLinkUpSnapshotDataKey = "snapshotData"
    private static let settingsSnapshotContent = "settingsSnapshot"
    private static let settingsSnapshotDataKey = "settingsSnapshotData"
    private static let requestSettingsSnapshotContent = "requestSettingsSnapshot"
    private static let libre3ProvisioningContent = "libre3Provisioning"
    private static let libre3ProvisioningDataKey = "libre3ProvisioningData"
    private static let libre3ProvisioningAcknowledgementContent = "libre3ProvisioningAcknowledgement"
    private static let libre3ProvisioningAcknowledgementDataKey = "libre3ProvisioningAcknowledgementData"
    private static let requestLibre3ProvisioningContent = "requestLibre3Provisioning"
    private static let libre3WorkoutOwnershipContent = "libre3WorkoutOwnership"
    private static let libre3WorkoutOwnershipDataKey = "libre3WorkoutOwnershipData"
    private static let libre3WorkoutOwnershipAcknowledgementContent = "libre3WorkoutOwnershipAcknowledgement"
    private static let libre3WorkoutOwnershipAcknowledgementDataKey = "libre3WorkoutOwnershipAcknowledgementData"
    private static let lowGlucoseAlertContent = "lowGlucoseAlert"
    private static let highGlucoseAlertContent = "highGlucoseAlert"
    private static let lowGlucoseAlertDataKey = "lowGlucoseAlertData"
    /// Phone → watch nudge: a fresh Dexcom Share sessionId after the phone
    /// re-authenticated. The watch persists it so its own next reload skips
    /// the dead-session round-trip. LLU has no equivalent because its bearer
    /// token has a multi-month lifetime and gets refreshed rarely enough that
    /// the existing settings-snapshot path already covers it.
    private static let dexcomShareSessionContent = "dexcomShareSession"
    private static let dexcomShareSessionIdKey = "dexcomShareSessionId"
#if os(watchOS)
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
        // Also pushed separately on BG re-auth via `sendDexcomShareSessionToWatch`
        // (see comment there). The two paths overlap by design — both writes
        // are idempotent; the settings snapshot covers user-facing events,
        // the dedicated push covers background re-auths.
        let dexcomShareSessionId: String?
        // Sensor settings (unit, target/alarm range) and sensor type. Share
        // doesn't return these, so the phone is the source of truth and mirrors
        // them here. Optional for older builds that didn't send them.
        let sensorSettings: SensorSettings?
        let sensorTypeRawValue: String?
        // Libre 3 direct-BLE: the paired sensor serial. Direct BLE has no cloud
        // credentials, but the watch's provider-account gate
        // (`hasActiveProviderAccount` → `libre3SensorIsPaired`) needs to know a
        // sensor is paired — app groups are per-device, so the phone forwards it.
        // nil when not the active provider / not paired / from older builds.
        let libre3Serial: String?
        // Whether low-glucose alerts should be delivered as *critical*
        // notifications. A global user setting (set in the phone's Libre 3
        // section), mirrored so the watch's backup local alert can match the
        // phone's level and pre-request critical-alert authorization. Optional
        // for older builds that didn't send it (treated as false).
        let lowGlucoseCriticalAlertsEnabled: Bool?
        // Same delivery preference for the Libre 3-only critically-low tier.
        // Optional so watches can still decode snapshots from older phones.
        let criticalLowGlucoseCriticalAlertsEnabled: Bool?
        let highGlucoseCriticalAlertsEnabled: Bool?
        let updatedAt: Date
    }

    private struct Libre3ProvisioningPayload: Codable, Sendable {
        static let currentPackageVersion = 3

        let packageVersion: Int
        let sensorIdentity: String
        let revision: Int64
        let digest: String
        let state: Libre3ProvisionedState?
        let createdAt: Date
    }

    private struct Libre3ProvisioningDigestMaterial: Codable, Sendable {
        let packageVersion: Int
        let sensorIdentity: String
        let state: Libre3ProvisionedState?
    }

    private struct DesiredLibre3ProvisioningPackage: Sendable {
        let sensorIdentity: String
        let state: Libre3ProvisionedState?
        let digest: String
    }

    private struct Libre3ProvisioningAcknowledgement: Codable, Sendable {
        let packageVersion: Int
        let sensorIdentity: String
        let revision: Int64
        let digest: String
        let installedAt: Date
    }

    private struct Libre3WorkoutOwnershipAcknowledgement: Codable, Sendable {
        let protocolVersion: Int
        let workoutSessionID: UUID
        let revision: Int64
        let accepted: Bool
        let reason: String
        let createdAt: Date
    }

    private struct LowGlucoseAlertPayload: Codable {
        let title: String
        let subtitle: String
        let body: String
        let sentAt: Date
        // Missing payloads came from older phones and are ordinary low alerts.
        let tier: GlucoseAlertTier?
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
    private var lastWatchGlucoseAlertAt: [GlucoseAlertTier: Date] = [:]
    private var lastScheduledWatchGlucoseSentAt: [GlucoseAlertTier: TimeInterval] = [:]
#endif
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Logger.connectivity.info("Session activation complete: \(activationState.rawValue)")
#if os(watchOS)
        if activationState == .activated {
            requestSettingsSnapshotFromPhone()
            requestLibre3ProvisioningFromPhone()
            Task { @MainActor in
                self.resendPendingLibre3WorkoutOwnershipEvent()
            }
        }
#elseif os(iOS)
        if activationState == .activated {
            sendSettingsSnapshotToWatch()
            Task { @MainActor in
                self.resendPendingLibre3WorkoutOwnershipEvent()
            }
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
        // Send the ordinary snapshot now. A replacement watch separately asks
        // for provisioning during its activation, and that request takes the
        // forced path even if this phone still remembers the old watch's ack.
        sendSettingsSnapshotToWatch()
        Task { @MainActor in
            self.resendPendingLibre3WorkoutOwnershipEvent()
        }
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

        if message["content"] as? String == Self.requestLibre3ProvisioningContent {
#if os(iOS)
            // A watch-originated request is authoritative evidence that its
            // local package is absent or suspect; do not trust an old ack from
            // a replaced/reinstalled watch to suppress this transfer.
            sendLibre3ProvisioningPackageToWatch(force: true)
#endif
        }

        if message["content"] as? String == Self.libre3WorkoutOwnershipContent {
            guard let ownershipData = message[Self.libre3WorkoutOwnershipDataKey] as? Data else {
                Logger.connectivity.error("Missing Libre 3 workout ownership data in message")
                return
            }
            do {
                let event = try JSONDecoder().decode(
                    Libre3WorkoutOwnershipEvent.self,
                    from: ownershipData
                )
                Task { @MainActor in
                    await self.applyLibre3WorkoutOwnershipEvent(event)
                }
            } catch {
                Logger.connectivity.error("Failed to decode Libre 3 workout ownership event: \(error.localizedDescription)")
            }
        }

        if message["content"] as? String == Self.libre3WorkoutOwnershipAcknowledgementContent {
            guard let acknowledgementData = message[Self.libre3WorkoutOwnershipAcknowledgementDataKey] as? Data else {
                Logger.connectivity.error("Missing Libre 3 workout ownership acknowledgement data in message")
                return
            }
            do {
                let acknowledgement = try JSONDecoder().decode(
                    Libre3WorkoutOwnershipAcknowledgement.self,
                    from: acknowledgementData
                )
                Task { @MainActor in
                    self.applyLibre3WorkoutOwnershipAcknowledgement(acknowledgement)
                }
            } catch {
                Logger.connectivity.error("Failed to decode Libre 3 workout ownership acknowledgement: \(error.localizedDescription)")
            }
        }

        if message["content"] as? String == Self.libre3ProvisioningContent {
#if os(watchOS)
            guard let provisioningData = message[Self.libre3ProvisioningDataKey] as? Data else {
                Logger.connectivity.error("Missing Libre 3 provisioning data in message")
                return
            }
            do {
                let payload = try JSONDecoder().decode(Libre3ProvisioningPayload.self, from: provisioningData)
                applyLibre3ProvisioningPayload(payload)
            } catch {
                Logger.connectivity.error("Failed to decode Libre 3 provisioning package: \(error.localizedDescription)")
            }
#endif
        }

        if message["content"] as? String == Self.libre3ProvisioningAcknowledgementContent {
#if os(iOS)
            guard let acknowledgementData = message[Self.libre3ProvisioningAcknowledgementDataKey] as? Data else {
                Logger.connectivity.error("Missing Libre 3 provisioning acknowledgement data in message")
                return
            }
            do {
                let acknowledgement = try JSONDecoder().decode(
                    Libre3ProvisioningAcknowledgement.self,
                    from: acknowledgementData
                )
                Task { @MainActor in
                    applyLibre3ProvisioningAcknowledgement(acknowledgement)
                }
            } catch {
                Logger.connectivity.error("Failed to decode Libre 3 provisioning acknowledgement: \(error.localizedDescription)")
            }
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
#if os(watchOS)
                    await WorkoutAlertNotificationManager.shared.evaluateCurrentReading()
#endif
                }
            } catch {
                Logger.connectivity.error("Failed to decode LibreLinkUp snapshot: \(error.localizedDescription)")
            }
        }

#if os(watchOS)
        if message["content"] as? String == Self.dexcomShareSessionContent {
            guard let sessionId = message[Self.dexcomShareSessionIdKey] as? String,
                  !sessionId.isEmpty else {
                Logger.connectivity.error("Missing Dexcom sessionId in refresh message")
                return
            }
            do {
                try DexcomShareTokenStore.save(sessionId, kind: .sessionId)
                SharedData.dexcomShareSessionId = sessionId
                Logger.connectivity.info("Applied fresh Dexcom sessionId from WatchConnectivity")
            } catch {
                Logger.connectivity.error("Failed to persist Dexcom sessionId: \(error.localizedDescription)")
            }
        }
#endif

        let glucoseAlertContent = message["content"] as? String
        if glucoseAlertContent == Self.lowGlucoseAlertContent ||
            glucoseAlertContent == Self.highGlucoseAlertContent {
            guard let alertData = message[Self.lowGlucoseAlertDataKey] as? Data else {
                Logger.connectivity.error("Missing glucose alert data in message")
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
                Logger.connectivity.error("Failed to decode glucose alert payload: \(error.localizedDescription)")
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

    /// Ownership transitions need both low-latency delivery and a durable FIFO
    /// copy. `sendMessageToPairedDevice` intentionally chooses only one path,
    /// so this protocol uses its own transport helper.
    @MainActor
    private func sendLibre3WorkoutOwnershipMessage(_ message: [String: Any]) {
        guard WCSession.isSupported() else {
            Logger.connectivity.error("Device does not support WatchConnectivity")
            return
        }
        guard session.activationState == .activated else {
            Logger.connectivity.info("Deferred Libre 3 workout ownership message until WCSession activation")
            return
        }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                Logger.connectivity.error("Immediate Libre 3 workout ownership send failed: \(error.localizedDescription)")
            }
        }
        session.transferUserInfo(message)
    }

    @MainActor
    private func sendLibre3WorkoutOwnershipEvent(_ event: Libre3WorkoutOwnershipEvent) {
        do {
            let data = try JSONEncoder().encode(event)
            sendLibre3WorkoutOwnershipMessage([
                "content": Self.libre3WorkoutOwnershipContent,
                Self.libre3WorkoutOwnershipDataKey: data,
                "useApplicationContext": false
            ])
            Logger.connectivity.info(
                "Published Libre 3 workout ownership kind=\(event.kind.rawValue, privacy: .public) revision=\(event.revision, privacy: .public) session=\(event.workoutSessionID.uuidString, privacy: .private(mask: .hash))"
            )
        } catch {
            Logger.connectivity.error("Failed to encode Libre 3 workout ownership event: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func sendLibre3WorkoutOwnershipAcknowledgement(
        for event: Libre3WorkoutOwnershipEvent,
        accepted: Bool,
        reason: String
    ) {
        let acknowledgement = Libre3WorkoutOwnershipAcknowledgement(
            protocolVersion: Libre3WorkoutOwnershipEvent.currentProtocolVersion,
            workoutSessionID: event.workoutSessionID,
            revision: event.revision,
            accepted: accepted,
            reason: reason,
            createdAt: Date()
        )
        do {
            let data = try JSONEncoder().encode(acknowledgement)
            sendLibre3WorkoutOwnershipMessage([
                "content": Self.libre3WorkoutOwnershipAcknowledgementContent,
                Self.libre3WorkoutOwnershipAcknowledgementDataKey: data,
                "useApplicationContext": false
            ])
        } catch {
            Logger.connectivity.error("Failed to encode Libre 3 workout ownership acknowledgement: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func makeLibre3WorkoutOwnershipEvent(
        kind: Libre3WorkoutOwnershipEventKind,
        origin: Libre3WorkoutOwnershipDevice,
        owner: Libre3WorkoutOwnershipDevice,
        workoutSessionID: UUID,
        provisioningRevision: Int64,
        disconnectOutcome: Libre3WorkoutDisconnectOutcome? = nil
    ) -> Libre3WorkoutOwnershipEvent {
        let state = SharedData.libre3SessionOwner
        return Libre3WorkoutOwnershipEvent(
            protocolVersion: Libre3WorkoutOwnershipEvent.currentProtocolVersion,
            kind: kind,
            origin: origin,
            owner: owner,
            workoutSessionID: workoutSessionID,
            revision: state.nextRevision(),
            provisioningRevision: provisioningRevision,
            disconnectOutcome: disconnectOutcome,
            createdAt: Date()
        )
    }

    @MainActor
    private func publishLocalLibre3WorkoutOwnershipEvent(_ event: Libre3WorkoutOwnershipEvent) {
        var state = SharedData.libre3SessionOwner
        guard state.apply(event, isLocal: true) == .applied else {
            Logger.connectivity.error("Could not apply locally-created Libre 3 workout ownership event")
            return
        }
        SharedData.libre3SessionOwner = state
        NotificationCenter.default.post(name: .libreWristDataDidChange, object: nil)
        sendLibre3WorkoutOwnershipEvent(event)
    }

    @MainActor
    private func resendPendingLibre3WorkoutOwnershipEvent() {
        guard let event = SharedData.libre3SessionOwner.pendingOutboundEvent else { return }
        sendLibre3WorkoutOwnershipEvent(event)
    }

    @MainActor
    private func applyLibre3WorkoutOwnershipAcknowledgement(
        _ acknowledgement: Libre3WorkoutOwnershipAcknowledgement
    ) {
        guard acknowledgement.protocolVersion == Libre3WorkoutOwnershipEvent.currentProtocolVersion,
              acknowledgement.revision > 0 else {
            Logger.connectivity.info("Ignored malformed Libre 3 workout ownership acknowledgement")
            return
        }
        guard acknowledgement.accepted else {
            Logger.connectivity.warning(
                "Libre 3 workout ownership revision=\(acknowledgement.revision, privacy: .public) rejected reason=\(acknowledgement.reason, privacy: .public)"
            )
            if acknowledgement.reason == "revision-conflict",
               let pending = SharedData.libre3SessionOwner.pendingOutboundEvent,
               pending.workoutSessionID == acknowledgement.workoutSessionID,
               pending.revision == acknowledgement.revision {
                let retried = makeLibre3WorkoutOwnershipEvent(
                    kind: pending.kind,
                    origin: pending.origin,
                    owner: pending.owner,
                    workoutSessionID: pending.workoutSessionID,
                    provisioningRevision: pending.provisioningRevision,
                    disconnectOutcome: pending.disconnectOutcome
                )
                publishLocalLibre3WorkoutOwnershipEvent(retried)
                return
            }
#if os(watchOS)
            if acknowledgement.reason == "provisioning-not-current" {
                var state = SharedData.libre3SessionOwner
                guard state.pendingOutboundEvent?.kind == .claim,
                      state.pendingOutboundEvent?.workoutSessionID == acknowledgement.workoutSessionID,
                      state.pendingOutboundEvent?.revision == acknowledgement.revision else {
                    return
                }
                state.recordClaimRejection(
                    reason: acknowledgement.reason,
                    workoutSessionID: acknowledgement.workoutSessionID,
                    revision: acknowledgement.revision
                )
                SharedData.libre3SessionOwner = state
                Task { @MainActor in
                    _ = await Libre3DirectManager.shared.standDownForHandoff()
                }
                return
            }
            if acknowledgement.reason == "terminal-reclaim" {
                var state = SharedData.libre3SessionOwner
                guard state.pendingOutboundEvent?.kind == .claim,
                      state.pendingOutboundEvent?.workoutSessionID == acknowledgement.workoutSessionID,
                      state.pendingOutboundEvent?.revision == acknowledgement.revision else {
                    return
                }
                state.recordTerminalRejection(
                    for: acknowledgement.workoutSessionID,
                    revision: acknowledgement.revision
                )
                SharedData.libre3SessionOwner = state
                NotificationCenter.default.post(name: .libreWristDataDidChange, object: nil)
                Task { @MainActor in
                    _ = await Libre3DirectManager.shared.standDownForHandoff()
                }
            }
#endif
            return
        }
        var state = SharedData.libre3SessionOwner
        guard state.pendingOutboundEvent?.workoutSessionID == acknowledgement.workoutSessionID else {
            return
        }
        state.acknowledge(revision: acknowledgement.revision)
        SharedData.libre3SessionOwner = state
    }

    @MainActor
    private func applyLibre3WorkoutOwnershipEvent(
        _ event: Libre3WorkoutOwnershipEvent
    ) async {
        var state = SharedData.libre3SessionOwner

#if os(iOS)
        guard event.origin == .watch,
              (event.kind == .claim || event.kind == .released) else {
            sendLibre3WorkoutOwnershipAcknowledgement(
                for: event,
                accepted: false,
                reason: "wrong-origin"
            )
            return
        }
        if event.kind == .claim {
            if state.hasTerminalReclaim(for: event.workoutSessionID) {
                sendLibre3WorkoutOwnershipAcknowledgement(
                    for: event,
                    accepted: false,
                    reason: "terminal-reclaim"
                )
                return
            }
            if state.hasActiveWatchClaim,
               state.workoutSessionID != event.workoutSessionID {
                sendLibre3WorkoutOwnershipAcknowledgement(
                    for: event,
                    accepted: false,
                    reason: "different-active-session"
                )
                return
            }
            let provisioningIsCurrent =
                event.provisioningRevision > 0
                && event.provisioningRevision == SharedData.libre3ProvisioningCurrentRevision
                && SharedData.libre3SensorIsPaired
                && SharedData.cgmProviderKind == .libre3BLE
            guard provisioningIsCurrent else {
                sendLibre3WorkoutOwnershipAcknowledgement(
                    for: event,
                    accepted: false,
                    reason: "provisioning-not-current"
                )
                sendLibre3ProvisioningPackageToWatch(force: true)
                return
            }
        } else if state.hasActiveWatchClaim,
                  state.workoutSessionID != event.workoutSessionID {
            sendLibre3WorkoutOwnershipAcknowledgement(
                for: event,
                accepted: false,
                reason: "different-active-session"
            )
            return
        }
#elseif os(watchOS)
        guard event.origin == .phone,
              (event.kind == .released || event.kind == .reclaim) else {
            sendLibre3WorkoutOwnershipAcknowledgement(
                for: event,
                accepted: false,
                reason: "wrong-origin"
            )
            return
        }
        if event.kind == .released,
           event.owner == .watch,
           (!state.hasActiveWatchClaim || state.workoutSessionID != event.workoutSessionID) {
            // A phone release acknowledges a claim that this watch must already
            // hold locally. This prevents a replacement/reinstalled watch from
            // starting BLE when an old phone-side event is replayed.
            sendLibre3WorkoutOwnershipAcknowledgement(
                for: event,
                accepted: false,
                reason: "no-local-workout"
            )
            return
        }
#endif

        let decision = state.apply(event, isLocal: false)
        switch decision {
        case .applied:
            SharedData.libre3SessionOwner = state
            NotificationCenter.default.post(name: .libreWristDataDidChange, object: nil)
            sendLibre3WorkoutOwnershipAcknowledgement(for: event, accepted: true, reason: "applied")
        case .duplicate:
            sendLibre3WorkoutOwnershipAcknowledgement(for: event, accepted: true, reason: "duplicate")
            return
        case .stale:
            sendLibre3WorkoutOwnershipAcknowledgement(for: event, accepted: true, reason: "superseded")
            return
        case .terminallyReclaimed:
            sendLibre3WorkoutOwnershipAcknowledgement(for: event, accepted: false, reason: "terminal-reclaim")
            return
        case .conflict:
            sendLibre3WorkoutOwnershipAcknowledgement(for: event, accepted: false, reason: "revision-conflict")
            return
        case .malformed:
            sendLibre3WorkoutOwnershipAcknowledgement(for: event, accepted: false, reason: "malformed")
            return
        }

#if os(iOS)
        switch event.kind {
        case .claim:
            let result = await Libre3DirectManager.shared.standDownForHandoff()
            let latest = SharedData.libre3SessionOwner
            guard latest.hasActiveWatchClaim,
                  latest.workoutSessionID == event.workoutSessionID,
                  !latest.hasTerminalReclaim(for: event.workoutSessionID) else { return }
            let released = makeLibre3WorkoutOwnershipEvent(
                kind: .released,
                origin: .phone,
                owner: .watch,
                workoutSessionID: event.workoutSessionID,
                provisioningRevision: event.provisioningRevision,
                disconnectOutcome: result == .confirmedDisconnect
                    ? .confirmedDisconnect
                    : .timedOut
            )
            publishLocalLibre3WorkoutOwnershipEvent(released)
            await LowGlucoseNotificationManager.shared.evaluateCurrentReading()
            await LiveActivityManager.shared.refreshFromCurrentHistory(
                useLiveActivities: SharedData.useLiveActivities,
                refreshIOB: false
            )
        case .released:
            if event.owner == .phone {
                Libre3DirectManager.shared.resumeAfterHandoff()
            }
        case .reclaim:
            break
        }
#elseif os(watchOS)
        switch event.kind {
        case .released:
            if event.owner == .watch {
                Libre3DirectManager.shared.resumeAfterHandoff()
            }
        case .reclaim:
            let result = await Libre3DirectManager.shared.standDownForHandoff()
            let latest = SharedData.libre3SessionOwner
            guard latest.owner == .phone,
                  latest.workoutSessionID == event.workoutSessionID else { return }
            let released = makeLibre3WorkoutOwnershipEvent(
                kind: .released,
                origin: .watch,
                owner: .phone,
                workoutSessionID: event.workoutSessionID,
                provisioningRevision: event.provisioningRevision,
                disconnectOutcome: result == .confirmedDisconnect
                    ? .confirmedDisconnect
                    : .timedOut
            )
            publishLocalLibre3WorkoutOwnershipEvent(released)
        case .claim:
            break
        }
#endif
    }

#if os(watchOS)
    /// Called only after the HealthKit workout transaction has committed. BLE
    /// acquisition remains best-effort and never rolls the workout back.
    @MainActor
    @discardableResult
    func claimLibre3SensorForWorkout(workoutSessionID: UUID) -> Bool {
        let provisioningRevision = SharedData.libre3ProvisioningInstalledRevision
        let state = SharedData.libre3SessionOwner
        guard SharedData.cgmProviderKind == .libre3BLE,
              Libre3StateStore.isPaired,
              provisioningRevision > 0,
              !state.hasActiveWatchClaim || state.workoutSessionID == workoutSessionID,
              !state.hasTerminalReclaim(for: workoutSessionID) else {
            return false
        }
        if state.hasActiveWatchClaim,
           state.workoutSessionID == workoutSessionID {
            guard state.claimRejectionReason == nil else { return false }
            resendPendingLibre3WorkoutOwnershipEvent()
            if let currentEvent = state.currentEvent,
               currentEvent.kind == .claim {
                beginWatchBLEAcquisitionAfterClaim(currentEvent)
            } else if state.currentEvent?.kind == .released {
                Libre3DirectManager.shared.resumeAfterHandoff()
            }
            return true
        }

        let claim = makeLibre3WorkoutOwnershipEvent(
            kind: .claim,
            origin: .watch,
            owner: .watch,
            workoutSessionID: workoutSessionID,
            provisioningRevision: provisioningRevision
        )
        publishLocalLibre3WorkoutOwnershipEvent(claim)
        beginWatchBLEAcquisitionAfterClaim(claim)
        return true
    }

    @MainActor
    private func beginWatchBLEAcquisitionAfterClaim(_ claim: Libre3WorkoutOwnershipEvent) {
        if session.activationState == .activated && session.isReachable {
            Task { @MainActor in
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        Libre3WorkoutOwnershipState.phoneReclaimFallbackDelay * 1_000_000_000
                    )
                )
                let latest = SharedData.libre3SessionOwner
                guard latest.hasActiveWatchClaim,
                      latest.workoutSessionID == claim.workoutSessionID,
                      latest.currentEvent?.revision == claim.revision,
                      latest.claimRejectionReason == nil else { return }
                // The phone's stand-down is itself bounded at five seconds. If
                // its one-way release never arrives, proceed and let normal BLE
                // contention/backoff handle the unreachable-phone edge case.
                Libre3DirectManager.shared.resumeAfterHandoff()
            }
        } else {
            Libre3DirectManager.shared.resumeAfterHandoff()
        }
    }

    /// Idempotent after a phone reclaim: ending the workout must not create a
    /// new phone-owned event that could disturb the terminal decision.
    @MainActor
    func releaseLibre3SensorAfterWorkout(workoutSessionID: UUID) async {
        let state = SharedData.libre3SessionOwner
        guard state.hasActiveWatchClaim,
              state.workoutSessionID == workoutSessionID else { return }

        let result = await Libre3DirectManager.shared.standDownForHandoff()
        let released = makeLibre3WorkoutOwnershipEvent(
            kind: .released,
            origin: .watch,
            owner: .phone,
            workoutSessionID: workoutSessionID,
            provisioningRevision: SharedData.libre3ProvisioningInstalledRevision,
            disconnectOutcome: result == .confirmedDisconnect
                ? .confirmedDisconnect
                : .timedOut
        )
        publishLocalLibre3WorkoutOwnershipEvent(released)
    }
#endif

#if os(iOS)
    @MainActor
    func takeLibre3SensorBack() {
        reclaimLibre3SensorForPhone(resumeImmediately: false)
    }

    /// An NFC pair invalidates the watch's cached key, so it must terminally
    /// reclaim any active workout session before the phone starts with the new
    /// material. Unlike the UI action, the new pair is already disconnected and
    /// may resume immediately.
    @MainActor
    func reclaimLibre3SensorForNewPairIfNeeded() {
        reclaimLibre3SensorForPhone(resumeImmediately: true)
    }

    @MainActor
    func reclaimLibre3SensorBeforeDisconnectIfNeeded() {
        reclaimLibre3SensorForPhone(resumeImmediately: false)
    }

    @MainActor
    private func reclaimLibre3SensorForPhone(resumeImmediately: Bool) {
        let state = SharedData.libre3SessionOwner
        guard state.hasActiveWatchClaim,
              let workoutSessionID = state.workoutSessionID else {
            if resumeImmediately {
                Libre3DirectManager.shared.resumeAfterHandoff(immediately: true)
            }
            return
        }

        let reclaim = makeLibre3WorkoutOwnershipEvent(
            kind: .reclaim,
            origin: .phone,
            owner: .phone,
            workoutSessionID: workoutSessionID,
            provisioningRevision: SharedData.libre3ProvisioningCurrentRevision
        )
        publishLocalLibre3WorkoutOwnershipEvent(reclaim)

        if resumeImmediately {
            Libre3DirectManager.shared.resumeAfterHandoff(immediately: true)
            return
        }

        Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(
                    Libre3WorkoutOwnershipState.phoneReclaimFallbackDelay * 1_000_000_000
                )
            )
            let latest = SharedData.libre3SessionOwner
            guard latest.owner == .phone,
                  latest.workoutSessionID == workoutSessionID,
                  latest.currentEvent?.revision == reclaim.revision else { return }
            Libre3DirectManager.shared.resumeAfterHandoff()
        }
    }
#endif

#if os(iOS)
    func sendSettingsSnapshotToWatch() {
      Task { @MainActor in
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
        case .libre3BLE:
            // Direct-BLE provisioning is deliberately separate from this general
            // settings snapshot. Never place its PIN or reconnect key here; the
            // workout handoff must send them in its dedicated provisioning package.
            // There are no cloud credentials for this payload.
            break
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
            // Only Dexcom needs the phone to be the source of truth for sensor
            // settings; for Libre the watch fetches its own from LibreLinkUp, so
            // leave these nil to avoid clobbering them.
            sensorSettings: providerKind == .dexcomShare ? SensorSettingsStore.shared.sensorSettings : nil,
            sensorTypeRawValue: providerKind == .dexcomShare ? SensorSettingsStore.shared.sensorType.rawValue : nil,
            libre3Serial: providerKind == .libre3BLE && SharedData.libre3SensorIsPaired ? SharedData.libre3Serial : nil,
            lowGlucoseCriticalAlertsEnabled: SharedData.lowGlucoseCriticalAlertsEnabled,
            criticalLowGlucoseCriticalAlertsEnabled: providerKind == .libre3BLE
                ? SharedData.criticalLowGlucoseCriticalAlertsEnabled
                : false,
            highGlucoseCriticalAlertsEnabled: SharedData.highGlucoseCriticalAlertsEnabled,
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

        // Direct BLE has an acknowledged, revisioned package of its own. The
        // general snapshot remains responsible for provider selection and
        // backward compatibility, while this call makes all existing settings
        // sync triggers also notice provisioning-relevant changes.
        sendLibre3ProvisioningPackageToWatch()
      }
    }

    /// Send the current phone-owned Libre 3 package when its digest changed or
    /// the watch has not acknowledged the current revision. `force` is reserved
    /// for an explicit watch resync/install request, where an acknowledgement
    /// may belong to a previous watch.
    func sendLibre3ProvisioningPackageToWatch(force: Bool = false) {
        Task { @MainActor in
            guard let desired = makeDesiredLibre3ProvisioningPackage() else { return }
            let payload = commitLibre3ProvisioningPackage(desired)
            let isAcknowledged =
                SharedData.libre3ProvisioningAcknowledgedRevision == payload.revision
                && SharedData.libre3ProvisioningAcknowledgedDigest == payload.digest
                && SharedData.libre3ProvisioningAcknowledgedSensorIdentity == payload.sensorIdentity
            guard force || !isAcknowledged else { return }

            do {
                let data = try JSONEncoder().encode(payload)
                let message: [String: Any] = [
                    "content": Self.libre3ProvisioningContent,
                    Self.libre3ProvisioningDataKey: data,
                    // Provisioning must be delivered once and in FIFO order.
                    // Application context is replayed and coalesced, which can
                    // resurrect an obsolete package after a later clear.
                    "useApplicationContext": false
                ]
                sendMessageToPairedDevice(message)
                Logger.connectivity.info(
                    "Queued Libre 3 provisioning revision=\(payload.revision, privacy: .public) sensor=\(payload.sensorIdentity, privacy: .private(mask: .hash)) hasState=\(payload.state != nil, privacy: .public)"
                )
            } catch {
                Logger.connectivity.error("Failed to encode Libre 3 provisioning package: \(error.localizedDescription)")
            }
        }
    }

    /// Part 1's phone readiness surface will consume this. Keep the getter pure:
    /// observing SwiftUI state must not itself advance a provisioning revision.
    @MainActor
    var libre3ProvisioningReadiness: Libre3ProvisioningReadiness {
        guard SharedData.libre3SensorIsPaired,
              Libre3StateStore.loadReconnectKey() != nil,
              let desired = makeDesiredLibre3ProvisioningPackage() else {
            return .waitingForSensorSetup
        }
        let desiredStateIsCurrent =
            SharedData.libre3ProvisioningCurrentRevision > 0
            && SharedData.libre3ProvisioningCurrentDigest == desired.digest
            && SharedData.libre3ProvisioningCurrentSensorIdentity == desired.sensorIdentity
        guard desiredStateIsCurrent else { return .outdated }

        let isAcknowledged =
            SharedData.libre3ProvisioningAcknowledgedRevision == SharedData.libre3ProvisioningCurrentRevision
            && SharedData.libre3ProvisioningAcknowledgedDigest == desired.digest
            && SharedData.libre3ProvisioningAcknowledgedSensorIdentity == desired.sensorIdentity
        return isAcknowledged ? .ready : .outdated
    }

    @MainActor
    private func makeDesiredLibre3ProvisioningPackage() -> DesiredLibre3ProvisioningPackage? {
        let state: Libre3ProvisionedState?
        if SharedData.libre3SensorIsPaired {
            guard let pin = (try? Libre3PINStore.read()) ?? nil else {
                Logger.connectivity.error("Cannot provision Libre 3: paired metadata has no keychain PIN")
                return nil
            }
            state = Libre3ProvisionedState(
                serial: SharedData.libre3Serial,
                bleAddress: SharedData.libre3BleAddress,
                receiverIDHex: SharedData.libre3ReceiverIDHex,
                mode: SharedData.libre3Mode,
                firmwareVersion: SharedData.libre3FirmwareVersion,
                warmupMinutes: SharedData.libre3WarmupMinutes,
                wearDurationMinutes: SharedData.libre3WearDurationMinutes,
                generation: SharedData.libre3Generation,
                productType: SharedData.libre3ProductType,
                sensorStartDateMillisecondsSince1970: SharedData.libre3SensorStartDate.map {
                    Int64(($0.timeIntervalSince1970 * 1_000).rounded())
                },
                blePIN: pin,
                reconnectKey: Libre3StateStore.loadReconnectKey(),
                calibrationSensorSerial: SharedData.libre3CalibrationSensorSerial,
                calibrationOffsetMgDL: SharedData.libre3CalibrationOffsetMgDL,
                sensorSettings: SensorSettingsStore.shared.sensorSettings,
                workoutLowDefaultMgDL: SharedData.lowGlucoseNotificationThreshold
            )
        } else {
            state = nil
        }

        // Retain the last non-empty identity in a clear package. It makes logs
        // and acknowledgements attributable while the global revision remains
        // the actual ordering authority.
        let sensorIdentity = state?.serial
            ?? SharedData.libre3ProvisioningCurrentSensorIdentity
        let material = Libre3ProvisioningDigestMaterial(
            packageVersion: Libre3ProvisioningPayload.currentPackageVersion,
            sensorIdentity: sensorIdentity,
            state: state
        )

        let digest: String
        do {
            digest = try Self.libre3ProvisioningDigest(for: material)
        } catch {
            Logger.connectivity.error("Failed to digest Libre 3 provisioning package: \(error.localizedDescription)")
            return nil
        }

        return DesiredLibre3ProvisioningPackage(
            sensorIdentity: sensorIdentity,
            state: state,
            digest: digest
        )
    }

    @MainActor
    private func commitLibre3ProvisioningPackage(
        _ desired: DesiredLibre3ProvisioningPackage
    ) -> Libre3ProvisioningPayload {
        var revision = SharedData.libre3ProvisioningCurrentRevision
        if revision <= 0
            || desired.digest != SharedData.libre3ProvisioningCurrentDigest
            || desired.sensorIdentity != SharedData.libre3ProvisioningCurrentSensorIdentity {
            revision = Self.nextLibre3ProvisioningRevision(after: revision)
            SharedData.libre3ProvisioningCurrentRevision = revision
            SharedData.libre3ProvisioningCurrentDigest = desired.digest
            SharedData.libre3ProvisioningCurrentSensorIdentity = desired.sensorIdentity
        }
        return Libre3ProvisioningPayload(
            packageVersion: Libre3ProvisioningPayload.currentPackageVersion,
            sensorIdentity: desired.sensorIdentity,
            revision: revision,
            digest: desired.digest,
            state: desired.state,
            createdAt: Date()
        )
    }

    @MainActor
    private func applyLibre3ProvisioningAcknowledgement(
        _ acknowledgement: Libre3ProvisioningAcknowledgement
    ) {
        guard acknowledgement.packageVersion == Libre3ProvisioningPayload.currentPackageVersion else {
            Logger.connectivity.info("Ignored Libre 3 provisioning acknowledgement for an unsupported package version")
            return
        }
        guard acknowledgement.revision > 0, acknowledgement.revision < .max else {
            Logger.connectivity.info("Ignored Libre 3 provisioning acknowledgement with an invalid revision")
            return
        }
        if acknowledgement.revision > SharedData.libre3ProvisioningCurrentRevision {
            // This can happen after the phone app was reinstalled while the
            // watch retained a later revision. Move the local floor forward and
            // force the desired state into a strictly newer package.
            SharedData.libre3ProvisioningCurrentRevision = acknowledgement.revision
            SharedData.libre3ProvisioningCurrentDigest = ""
            sendLibre3ProvisioningPackageToWatch()
            return
        }
        if acknowledgement.revision == SharedData.libre3ProvisioningCurrentRevision,
           (acknowledgement.digest != SharedData.libre3ProvisioningCurrentDigest
            || acknowledgement.sensorIdentity != SharedData.libre3ProvisioningCurrentSensorIdentity) {
            // Equal revisions with different content are never accepted. Treat
            // the watch's installed revision as the floor, then issue the phone's
            // desired state under a new revision.
            SharedData.libre3ProvisioningCurrentDigest = ""
            sendLibre3ProvisioningPackageToWatch()
            return
        }
        guard acknowledgement.revision == SharedData.libre3ProvisioningCurrentRevision,
              acknowledgement.digest == SharedData.libre3ProvisioningCurrentDigest,
              acknowledgement.sensorIdentity == SharedData.libre3ProvisioningCurrentSensorIdentity else {
            Logger.connectivity.info(
                "Ignored stale Libre 3 provisioning acknowledgement revision=\(acknowledgement.revision, privacy: .public)"
            )
            return
        }
        SharedData.libre3ProvisioningAcknowledgedRevision = acknowledgement.revision
        SharedData.libre3ProvisioningAcknowledgedDigest = acknowledgement.digest
        SharedData.libre3ProvisioningAcknowledgedSensorIdentity = acknowledgement.sensorIdentity
        Logger.connectivity.info(
            "Acknowledged Libre 3 provisioning revision=\(acknowledgement.revision, privacy: .public)"
        )
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

    /// Phone → watch: notify the watch that the phone just minted a fresh
    /// Dexcom Share sessionId. Watch persists it to keychain + app group so
    /// the watch widget's reload gate opens again and its next tick can fetch
    /// without going through a sessionInvalid round-trip first. Dexcom is
    /// observed to accept the same sessionId being used from multiple
    /// processes concurrently, so we don't worry about contention here.
    ///
    /// Intentional overlap with `SettingsSnapshotPayload.dexcomShareSessionId`:
    /// the settings snapshot also carries the session, but is only sent on
    /// user-facing events (Settings/Connect/Home view, initial connect). It
    /// does NOT fire from background re-auths — which is exactly when the
    /// watch's session silently goes stale and the user wakes up to a frozen
    /// widget. This dedicated push closes that gap. The overlap case (user
    /// opens app right around a reauth) is benign: both writes are idempotent.
    /// Don't "dedupe" by dropping the field from the settings snapshot
    /// without also adding an explicit push from the initial-connect path.
    func sendDexcomShareSessionToWatch(_ sessionId: String) {
        guard !sessionId.isEmpty else { return }
        let messageToWatch: [String: Any] = [
            "content": Self.dexcomShareSessionContent,
            Self.dexcomShareSessionIdKey: sessionId
        ]
        sendMessageToPairedDevice(messageToWatch)
    }
#endif

    private static func libre3ProvisioningDigest(
        for material: Libre3ProvisioningDigestMaterial
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(material)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func nextLibre3ProvisioningRevision(after current: Int64) -> Int64 {
        // A wall-clock floor keeps a reinstalled phone from normally restarting
        // below a revision retained by the watch. `current + 1` preserves strict
        // monotonicity if several settings change in one millisecond.
        let wallClockMilliseconds = Int64(Date().timeIntervalSince1970 * 1_000)
        let incremented = current == .max ? current : current + 1
        return max(incremented, wallClockMilliseconds)
    }

#if os(watchOS)
    private func applyLibre3ProvisioningPayload(_ payload: Libre3ProvisioningPayload) {
        Task { @MainActor in
            guard payload.packageVersion == Libre3ProvisioningPayload.currentPackageVersion else {
                Logger.connectivity.error(
                    "Unsupported Libre 3 provisioning package version=\(payload.packageVersion, privacy: .public)"
                )
                return
            }
            guard payload.revision > 0 else {
                Logger.connectivity.error("Rejected Libre 3 provisioning package with an invalid revision")
                return
            }
            guard payload.state?.serial == payload.sensorIdentity || payload.state == nil else {
                Logger.connectivity.error("Rejected Libre 3 provisioning package with mismatched sensor identity")
                return
            }

            let material = Libre3ProvisioningDigestMaterial(
                packageVersion: payload.packageVersion,
                sensorIdentity: payload.sensorIdentity,
                state: payload.state
            )
            let expectedDigest: String
            do {
                expectedDigest = try Self.libre3ProvisioningDigest(for: material)
            } catch {
                Logger.connectivity.error("Failed to verify Libre 3 provisioning digest: \(error.localizedDescription)")
                return
            }
            guard expectedDigest == payload.digest else {
                Logger.connectivity.error("Rejected Libre 3 provisioning package with invalid digest")
                return
            }

            let installedRevision = SharedData.libre3ProvisioningInstalledRevision
            if payload.revision < installedRevision {
                Logger.connectivity.info(
                    "Ignored stale Libre 3 provisioning revision=\(payload.revision, privacy: .public) installed=\(installedRevision, privacy: .public)"
                )
                sendInstalledLibre3ProvisioningAcknowledgement()
                return
            }
            if payload.revision == installedRevision {
                guard payload.digest == SharedData.libre3ProvisioningInstalledDigest,
                      payload.sensorIdentity == SharedData.libre3ProvisioningInstalledSensorIdentity else {
                    Logger.connectivity.error("Rejected conflicting Libre 3 provisioning package at installed revision")
                    sendInstalledLibre3ProvisioningAcknowledgement()
                    return
                }
                sendInstalledLibre3ProvisioningAcknowledgement()
                return
            }

            do {
                if let state = payload.state {
                    try Libre3StateStore.installProvisionedState(state)
                } else {
                    Libre3StateStore.clear()
                }
            } catch {
                Logger.connectivity.error("Failed to install Libre 3 provisioning package: \(String(describing: error), privacy: .public)")
                return
            }

            SharedData.libre3ProvisioningInstalledRevision = payload.revision
            SharedData.libre3ProvisioningInstalledDigest = payload.digest
            SharedData.libre3ProvisioningInstalledSensorIdentity = payload.sensorIdentity
            if SharedData.cgmProviderKind == .libre3BLE {
                UserDefaults.group.connected = payload.state == nil ? .disconnected : .connected
            }
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            sendInstalledLibre3ProvisioningAcknowledgement()
            refreshLibre3WorkoutClaimAfterProvisioningIfNeeded()
            Logger.connectivity.info(
                "Installed Libre 3 provisioning revision=\(payload.revision, privacy: .public) hasState=\(payload.state != nil, privacy: .public)"
            )
        }
    }

    private func sendInstalledLibre3ProvisioningAcknowledgement() {
        let revision = SharedData.libre3ProvisioningInstalledRevision
        guard revision > 0 else { return }
        let acknowledgement = Libre3ProvisioningAcknowledgement(
            packageVersion: Libre3ProvisioningPayload.currentPackageVersion,
            sensorIdentity: SharedData.libre3ProvisioningInstalledSensorIdentity,
            revision: revision,
            digest: SharedData.libre3ProvisioningInstalledDigest,
            installedAt: Date()
        )
        do {
            let data = try JSONEncoder().encode(acknowledgement)
            let message: [String: Any] = [
                "content": Self.libre3ProvisioningAcknowledgementContent,
                Self.libre3ProvisioningAcknowledgementDataKey: data,
                "useApplicationContext": false
            ]
            sendMessageToPairedDevice(message)
        } catch {
            Logger.connectivity.error("Failed to encode Libre 3 provisioning acknowledgement: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func refreshLibre3WorkoutClaimAfterProvisioningIfNeeded() {
        let state = SharedData.libre3SessionOwner
        guard state.hasActiveWatchClaim,
              let workoutSessionID = state.workoutSessionID,
              state.currentEvent?.kind == .claim,
              !state.hasTerminalReclaim(for: workoutSessionID) else { return }

        let refreshedClaim = makeLibre3WorkoutOwnershipEvent(
            kind: .claim,
            origin: .watch,
            owner: .watch,
            workoutSessionID: workoutSessionID,
            provisioningRevision: SharedData.libre3ProvisioningInstalledRevision
        )
        publishLocalLibre3WorkoutOwnershipEvent(refreshedClaim)
        beginWatchBLEAcquisitionAfterClaim(refreshedClaim)
    }

    func requestLibre3ProvisioningFromPhone() {
        let message: [String: Any] = [
            "content": Self.requestLibre3ProvisioningContent,
            "useApplicationContext": false
        ]
        sendMessageToPairedDevice(message)
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
        if session.isReachable {
            Task { @MainActor in
                self.resendPendingLibre3WorkoutOwnershipEvent()
            }
        }
#if os(iOS)
        if session.isReachable {
            sendLibre3ProvisioningPackageToWatch()
        }
#endif
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
#if os(iOS)
        // Bridge `DexcomShareProvider` re-auths to the watch without giving
        // the provider a compile-time dependency on this class (the provider
        // is built into widget targets that don't link WC).
        NotificationCenter.default.addObserver(
            forName: .dexcomShareSessionDidRefresh,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let sessionId = note.object as? String else { return }
            self?.sendDexcomShareSessionToWatch(sessionId)
        }
#endif
    }

    private func applySettingsSnapshot(_ snapshot: SettingsSnapshotPayload) {
        UserDefaults.group.insulinTypeSelected = InsulinType(rawValue: snapshot.insulinTypeSelected) ?? .rapidActing
        SharedData.showInsulinDeliveryMarksWatch = snapshot.showInsulinDeliveryMarksWatch
        SharedData.showIOBCurveWatch = snapshot.showIOBCurveWatch
        SharedData.showActivityCurveWatch = snapshot.showActivityCurveWatch
        SharedData.widgetUpdateFrequency = snapshot.widgetUpdateFrequency
        SharedData.tapComplicationReloads = snapshot.tapComplicationReloads

        // Mirror the critical-alert preference so the watch's backup low-glucose
        // notification matches the phone's level. When it flips on, (re)request
        // authorization including `.criticalAlert` now, so the grant is in place
        // before the next alert rather than prompting mid-low.
        let wantsLowCritical = snapshot.lowGlucoseCriticalAlertsEnabled ?? false
        let wantsCriticalLowCritical = snapshot.criticalLowGlucoseCriticalAlertsEnabled ?? false
        let wantsHighCritical = snapshot.highGlucoseCriticalAlertsEnabled ?? false
#if os(watchOS)
        let lowCriticalWasEnabled = SharedData.lowGlucoseCriticalAlertsEnabled
        let criticalLowCriticalWasEnabled = SharedData.criticalLowGlucoseCriticalAlertsEnabled
        let highCriticalWasEnabled = SharedData.highGlucoseCriticalAlertsEnabled
#endif
        SharedData.lowGlucoseCriticalAlertsEnabled = wantsLowCritical
        SharedData.criticalLowGlucoseCriticalAlertsEnabled = wantsCriticalLowCritical
        SharedData.highGlucoseCriticalAlertsEnabled = wantsHighCritical
#if os(watchOS)
        if (wantsLowCritical && !lowCriticalWasEnabled) ||
            (wantsCriticalLowCritical && !criticalLowCriticalWasEnabled) ||
            (wantsHighCritical && !highCriticalWasEnabled) {
            requestWatchLowGlucoseNotificationAuthorization()
        }
#endif

        // Mirror the phone's sensor settings (unit, target range, sensor type).
        // The phone is authoritative; Share never returns these on the watch.
        if let sensorSettings = snapshot.sensorSettings {
            let updatedAt = snapshot.updatedAt
            let rawType = snapshot.sensorTypeRawValue
            Task { @MainActor in
                let sensorType = rawType.flatMap { SensorType(rawValue: $0) } ?? SensorSettingsStore.shared.sensorType
                _ = SensorSettingsStore.shared.replaceCacheAndPersist(
                    sensorSettings: sensorSettings,
                    sensorType: sensorType,
                    updatedAt: updatedAt
                )
            }
        }

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
            case .libre3BLE:
                // No cloud credentials for direct BLE — glucose arrives via the
                // dedicated snapshot path. Before the revisioned provisioning
                // protocol has ever installed, retain the legacy serial mirror
                // so an older phone still opens the provider-account gate. Once
                // a package has landed it is authoritative: an out-of-order,
                // unacknowledged settings snapshot must not resurrect a sensor
                // that a later provisioning package cleared.
                if SharedData.libre3ProvisioningInstalledRevision > 0 {
                    UserDefaults.group.connected = Libre3StateStore.isPaired
                        ? .connected
                        : .disconnected
                } else if let serial = snapshot.libre3Serial, !serial.isEmpty {
                    SharedData.libre3Serial = serial
                    UserDefaults.group.connected = .connected
                } else {
                    SharedData.libre3Serial = ""
                    UserDefaults.group.connected = .disconnected
                }
                CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
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
            // Also publish into the watch's app group so the watch widget's
            // reload gate (`canActiveProviderReload`) passes immediately —
            // the widget can't read the watch keychain.
            SharedData.dexcomShareSessionId = sessionId
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
            configureWatchNotifications()
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
    // NOTE: sent with `useApplicationContext: true`, so low-family and high
    // alerts use separate sibling keys in the WC application context. This lets
    // intentionally overlapping thresholds deliver both families without one
    // overwriting the other. Application context is latest-state storage, not a
    // queue: each value lingers until a newer alert in that family overwrites it,
    // and the system *replays the whole context* to the watch on
    // every session activation / reachability change (see deliverApplicationCtx
    // → received). So the watch will see this same alert re-delivered repeatedly
    // — alongside the snapshot — especially under Xcode where each relaunch
    // re-activates the session. That's expected and harmless: the watch's
    // `sentAt` staleness guard drops any replay older than its window. If a
    // future change needs alerts to fire exactly once, switch them to
    // transferUserInfo (FIFO, delivered once) or clear this key after consume.
    func sendLowGlucoseAlertToWatch(
        title: String,
        subtitle: String,
        body: String,
        sentAt: Date,
        tier: GlucoseAlertTier
    ) {
        let payload = LowGlucoseAlertPayload(
            title: title,
            subtitle: subtitle,
            body: body,
            sentAt: sentAt,
            tier: tier
        )

        do {
            let alertData = try JSONEncoder().encode(payload)
            let content = tier == .high
                ? Self.highGlucoseAlertContent
                : Self.lowGlucoseAlertContent
            let messageToWatch: [String: Any] = [
                "content": content,
                Self.lowGlucoseAlertDataKey: alertData,
                "useApplicationContext": true
            ]
            sendMessageToPairedDevice(messageToWatch)
        } catch {
            Logger.connectivity.error("Failed to encode glucose alert payload: \(error.localizedDescription)")
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

    private func configureWatchNotifications() {
        watchNotificationCenter.delegate = self
    }

    func requestWatchLowGlucoseNotificationAuthorization() {
        Task {
            _ = await requestWatchNotificationAuthorizationIfNeeded()
        }
    }

    /// Workout notification criticality is watch-owned. Passing an explicit
    /// preference keeps unrelated phone-mirrored alert settings from prompting
    /// for critical authorization when every workout critical flag is off.
    @MainActor
    func requestWatchWorkoutNotificationAuthorization() async -> Bool {
        let wantsCritical = SharedData.workoutLowCriticalAlertsEnabled
            || SharedData.workoutCriticalLowCriticalAlertsEnabled
            || SharedData.workoutRapidDropCriticalAlertsEnabled
            || SharedData.workoutNoReadingCriticalAlertsEnabled
        return await requestWatchNotificationAuthorizationIfNeeded(
            criticalDeliveryOverride: wantsCritical
        )
    }

    private func watchNotificationIdentifierPrefix(for tier: GlucoseAlertTier) -> String {
        switch tier {
        case .low:
            "watch-low-glucose-alert"
        case .criticalLow:
            "watch-critical-low-glucose-alert"
        case .high:
            "watch-high-glucose-alert"
        }
    }

    private func criticalDeliveryEnabled(for tier: GlucoseAlertTier) -> Bool {
        switch tier {
        case .low:
            SharedData.lowGlucoseCriticalAlertsEnabled
        case .criticalLow:
            SharedData.criticalLowGlucoseCriticalAlertsEnabled
        case .high:
            SharedData.highGlucoseCriticalAlertsEnabled
        }
    }

    @MainActor
    private func requestWatchNotificationAuthorizationIfNeeded(
        criticalDeliveryOverride: Bool? = nil
    ) async -> Bool {
        let settings = await watchNotificationCenter.notificationSettings()
        guard settings.authorizationStatus != .denied else {
            Logger.connectivity.warning("Watch notification authorization denied")
            return false
        }

        // When the user wants critical alerts we must still request even if the
        // base alert grant exists, so iOS prompts for the incremental
        // critical-alert permission. Skip the request only when already
        // authorized AND the critical grant is satisfied (or not wanted).
        let wantsCritical = criticalDeliveryOverride ?? (
            SharedData.lowGlucoseCriticalAlertsEnabled
                || SharedData.criticalLowGlucoseCriticalAlertsEnabled
                || SharedData.highGlucoseCriticalAlertsEnabled
        )
        let criticalSatisfied = !wantsCritical || settings.criticalAlertSetting == .enabled
        if [.authorized, .provisional].contains(settings.authorizationStatus), criticalSatisfied {
            return true
        }

        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        if wantsCritical {
            options.insert(.criticalAlert)
        }

        do {
            return try await watchNotificationCenter.requestAuthorization(options: options)
        } catch {
            Logger.connectivity.error("Watch notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    private func scheduleWatchLowGlucoseNotificationIfNeeded(for payload: LowGlucoseAlertPayload) async {
        let tier = payload.tier ?? .low
        Logger.connectivity.info(
            "Watch \(tier.rawValue, privacy: .public) glucose fallback received: state=\(String(describing: self.watchAppVisibilityState), privacy: .public), sentAt=\(payload.sentAt.formatted(date: .omitted, time: .standard), privacy: .public)"
        )
        // During any locally owned workout, the watch evaluates the same shared
        // glucose history itself. Dropping every relayed tier also makes cloud
        // workouts match Libre 3, whose phone alerts are ownership-suppressed.
        guard !WorkoutModeStore.shared.isActive else {
            Logger.connectivity.info("Skipping relayed glucose alert during an active watch workout")
            return
        }
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
        guard sentAtInterval > lastScheduledWatchGlucoseSentAt[tier, default: 0] else {
            Logger.connectivity.info("Skipping watch low glucose fallback: already scheduled this alert")
            return
        }

        let lastAlertAt = lastWatchGlucoseAlertAt[tier] ?? .distantPast
        guard now.timeIntervalSince(lastAlertAt) >= Self.watchLowGlucoseAlertCooldown else {
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
        // Match the phone: critical delivery (overrides silent mode / Focus / Do
        // Not Disturb, plays a sound even when muted) when the user opted in AND
        // the watch granted the critical-alert permission; otherwise the default
        // time-sensitive level.
        let useCritical = criticalDeliveryEnabled(for: tier) && settings.criticalAlertSetting == .enabled
        if useCritical {
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        } else {
            if settings.soundSetting == .enabled {
                content.sound = .default
            }
            content.interruptionLevel = .timeSensitive
        }
        content.relevanceScore = 1

        let identifierPrefix = watchNotificationIdentifierPrefix(for: tier)
        let requestIdentifier = "\(identifierPrefix)-\(Int(now.timeIntervalSince1970))"
        let pendingRequests = await watchNotificationCenter.pendingNotificationRequests()
        let prefixesToRemove = tier == .criticalLow
            ? [identifierPrefix, watchNotificationIdentifierPrefix(for: .low)]
            : [identifierPrefix]
        let matchingPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { identifier in
                prefixesToRemove.contains { prefix in identifier.hasPrefix(prefix) }
            }
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
            lastWatchGlucoseAlertAt[tier] = now
            lastScheduledWatchGlucoseSentAt[tier] = sentAtInterval
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
        let identifier = notification.request.identifier
        let isWatchGlucoseAlert = GlucoseAlertTier.allCases.contains {
            identifier.hasPrefix(watchNotificationIdentifierPrefix(for: $0))
        }
        let isWorkoutAlert = WorkoutAlertNotificationManager
            .handlesNotificationIdentifier(identifier)
        guard isWatchGlucoseAlert || isWorkoutAlert else {
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
