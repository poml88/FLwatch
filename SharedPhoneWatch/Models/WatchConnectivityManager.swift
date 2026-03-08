//
//  WatchConnectivityManager.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.04.25.
//

//import Foundation
import WatchConnectivity
import OSLog

class WatchConnectivityManager: NSObject, WCSessionDelegate {  // ObservableObject is the old method, Swiftui now uses @Observable
    // https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
    // https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
    
//    @Published var receivedMessage: String = ""
    
    private static let libreLinkUpSnapshotContent = "libreLinkUpSnapshot"
    private static let libreLinkUpSnapshotDataKey = "snapshotData"

    private struct LibreLinkUpSnapshotPayload: Codable {
        let libreLinkUpGlucose: [LibreLinkUpGlucose]
        let libreLinkUpMinuteGlucose: [LibreLinkUpGlucose]
        let latestLibreLinkUpGlucose: LibreLinkUpGlucose?
        let lastReadingDate: Date
        let currentGlucose: Int
        let currentTrendArrow: String
        let maxBG: Int
    }

    private var messageHandlers: [WatchMessageHandler] = []
    private var requestHandlers: [WatchRequestHandler] = []
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Logger.connectivity.info("Session activation complete: \(activationState.rawValue)")
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

        let idhs = InsulinDeliveryHistorySingleton.shared
        
        Logger.connectivity.info("Message received: \(message)")
        
        if message["content"] as? String == "credentials" {
            UserDefaults.group.username = message["username"] as? String ?? ""
            let password = message["password"] as? String ?? ""
            try? PasswordKeychain.save(password)
            SharedData.libreLinkUpToken = ""
            UserDefaults.group.connected = .newlyConnected
            UserDefaults.group.connected = .connected
        }
        
        if message["content"] as? String == "insulinDelivery" {
            let insulinDeliveryHistoryItem = InsulinDelivery(id: UUID(), timestamp: message["timeStamp"] as? Double ?? Date().timeIntervalSince1970 - 12 * 3600, insulinUnits: message["units"] as? Double ?? 0.0, insulinType: UserDefaults.group.insulinTypeSelected.rawValue)
            idhs.insulinDeliveryHistory.append(insulinDeliveryHistoryItem)
            idhs.saveAndUpdateIOB()
        }
        
        if message["content"] as? String == "clearInsulinHistory" {
            idhs.insulinDeliveryHistory = []
            idhs.saveAndUpdateIOB()
        }
        
        if message["content"] as? String == "deleteInsulin" {
            let timeStamp = message["timestamp"] as? Double ?? Date().timeIntervalSince1970 - 12 * 3600
            if let idx = idhs.insulinDeliveryHistory.firstIndex(where: { $0.timeStamp == timeStamp }) {
                idhs.insulinDeliveryHistory.remove(at: idx)
            }
            idhs.saveAndUpdateIOB()
        }
        
        if message["content"] as? String == "updateInsulinTypeSelected" {
            let valueRaw = message["insulinTypeSelected"] as? Int ?? 0
            let valueType: InsulinType = InsulinType(rawValue: valueRaw) ?? .rapidActing
            UserDefaults.group.insulinTypeSelected = valueType
        }
        
        if message["content"] as? String == "showInsulinDeliveryMarksWatchMessage" {
            let valueBool = message["showInsulinDeliveryMarksWatch"] as? Bool ?? false
            SharedData.showInsulinDeliveryMarksWatch = valueBool
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        }
        if message["content"] as? String == "showIOBCurveWatchMessage" {
            let valueBool = message["showIOBCurveWatch"] as? Bool ?? false
            SharedData.showIOBCurveWatch = valueBool
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        }
        
        if message["content"] as? String == "showActivityCurveWatchMessage" {
            let valueBool = message["showActivityCurveWatch"] as? Bool ?? false
            SharedData.showActivityCurveWatch = valueBool
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        }
        
        if message["content"] as? String == "updateWidgetUpdateFrequency" {
            let valueInt: Int = message["widgetUpdateFrequency"] as? Int ?? 5
            SharedData.widgetUpdateFrequency = valueInt
        }
        
        if message["content"] as? String == "tapComplicationReloadsMessage" {
            let valueBool = message["tapComplicationReloads"] as? Bool ?? false
            SharedData.tapComplicationReloads = valueBool
        }

        if message["content"] as? String == Self.libreLinkUpSnapshotContent {
            guard let snapshotData = message[Self.libreLinkUpSnapshotDataKey] as? Data else {
                Logger.connectivity.error("Missing LibreLinkUp snapshot data in message")
                return
            }
            do {
                let snapshot = try JSONDecoder().decode(LibreLinkUpSnapshotPayload.self, from: snapshotData)
                Task { @MainActor in
                    let history = LibreLinkUpHistory.shared
                    history.libreLinkUpGlucose = snapshot.libreLinkUpGlucose
                    history.libreLinkUpMinuteGlucose = snapshot.libreLinkUpMinuteGlucose
                    history.latestLibreLinkUpGlucose = snapshot.latestLibreLinkUpGlucose ?? snapshot.libreLinkUpGlucose.first ?? snapshot.libreLinkUpMinuteGlucose.first
                    history.lastReadingDate = snapshot.lastReadingDate
                    history.currentGlucose = snapshot.currentGlucose
                    history.currentTrendArrow = snapshot.currentTrendArrow
                    history.maxBG = snapshot.maxBG
                    CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                    Logger.connectivity.info("Applied LibreLinkUp snapshot from WatchConnectivity")
                }
            } catch {
                Logger.connectivity.error("Failed to decode LibreLinkUp snapshot: \(error.localizedDescription)")
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
            Logger.connectivity.info("Sending message: \(message)")
            session.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in // Watch App: sendMessage only works if app is active in foreground
                Logger.connectivity.error("\(error)")
                if message["useApplicationContext"] as? Bool ?? true {
                    Logger.connectivity.warning("Error, trying updateApplicationContext")
                    do {
                        try self.session.updateApplicationContext(message)
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
                Logger.connectivity.warning("Error, trying updateApplicationContext")
                do {
                    try self.session.updateApplicationContext(message)
                } catch {
                    Logger.connectivity.error("updateApplicationContext failed: \(error.localizedDescription)")
                }
            } else {
                Logger.connectivity.warning("Error, trying transferUserInfo")
                //                try? WCSession.default.updateApplicationContext(message)
                self.session.transferUserInfo(message) // transferUserInfo does not work in Simulator!!
            }
        }
    }

#if os(iOS)
    func sendLibreLinkUpSnapshotToWatch() {
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
#endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        received(message)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any] ) {
        received(applicationContext)
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
    
    func startSession() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            for transfer in session.outstandingUserInfoTransfers {
                Logger.connectivity.info("Outstanding transfer: \(transfer.userInfo.keys) isTransferring=\(transfer.isTransferring)")
                // Optional: if you detect very old or duplicated items, decide whether to cancel or leave them
                // transfer.cancel() // if appropriate
            }
        }
    }
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

