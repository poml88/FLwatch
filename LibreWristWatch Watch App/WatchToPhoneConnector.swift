//
//  WatchToIOSConnection.swift
//  TestWatchConnectivityWatchApp Watch App
//
//  Created by Peter Müller on 01.09.24.
//

/*
 
 
#if false
import Foundation
import WatchConnectivity
import OSLog
import SecureDefaults

class WatchToPhoneConnector: NSObject, WCSessionDelegate, ObservableObject {
    
    @Published var receivedMessage: String = ""
    
    private var messageHandlers: [WatchMessageHandler] = []
    private var requestHandlers: [WatchRequestHandler] = []
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        
    }
    
    private func received(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
        
        DispatchQueue.main.async { [self] in
            receivedMessage = message["message"] as? String ?? "Not found"
        }
        Logger.connectivity.info("Message received: \(message)")
        
        if message["content"] as? String == "credentials" {
            UserDefaults.group.username = message["username"] as? String ?? ""
            let sdefaults = SecureDefaults.sgroup
            if !sdefaults.isKeyCreated {
                sdefaults.password = UUID().uuidString
            }
            let password = message["password"] as? String ?? ""
            sdefaults.set(password, forKey: "llu.password")
            sdefaults.synchronize()
            settings.libreLinkUpToken = ""
            UserDefaults.group.connected = .newlyConnected
        }
        
        if message["content"] as? String == "insulinDelivery" {
            let insulinDeliveryHistoryItem = InsulinDelivery(id: UUID(), timestamp: message["timeStamp"] as? Double ?? Date().timeIntervalSince1970 - 12 * 3600, insulinUnits: message["units"] as? Double ?? 0.0)
            var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
            insulinDeliveryHistory.append(insulinDeliveryHistoryItem)
            UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
        }
        
        if message["content"] as? String == "clearInsulinHistory" {
            UserDefaults.group.insulinDeliveryHistory = []
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
        
        // iterate through the message handlers until one of them handles it
        let _ = messageHandlers.firstIndex(where: { $0.handle(dictionary: message) })
    }
    
    func sendMessagetoPhone(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
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
            session.sendMessage(message, replyHandler: replyHandler, errorHandler: { error in
                Logger.connectivity.error("\(error)")
                Logger.connectivity.warning("Error, trying ApplicationContext")//                try? WCSession.default.updateApplicationContext(message)
                WCSession.default.transferUserInfo(message)
            })
        } else {
            Logger.connectivity.warning("Session not reachable / counterpart app not available for live messaging")
//            try? WCSession.default.updateApplicationContext(message)
            WCSession.default.transferUserInfo(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        received(message)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any] ) {
        received(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        received(userInfo)
    }
    
    var session: WCSession
    
    static let shared = WatchToPhoneConnector()
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        session.delegate = self
        session.activate()
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
#endif

*/
