//
//  WatchConnector.swift
//  TestWatchConnectivity
//
//  Created by Peter Müller on 01.09.24.
//

import Foundation
import WatchConnectivity
import OSLog

class PhoneToWatchConnector: NSObject, WCSessionDelegate, ObservableObject {
    @Published var receivedMessage: String = ""
    
    private var messageHandlers: [WatchMessageHandler] = []
    private var requestHandlers: [WatchRequestHandler] = []
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    private func received(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
        
        DispatchQueue.main.async { [self] in
            receivedMessage = message["message"] as? String ?? "Not found"
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
    
    func sendMessagetoWatch(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)? = nil) {
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
                Logger.connectivity.warning("Error, trying ApplicationContext")
//                try? WCSession.default.updateApplicationContext(message)
                WCSession.default.transferUserInfo(message)
            })
        } else {
            Logger.connectivity.warning("Session not reachable / counterpart app not available for live messaging")
//            try? WCSession.default.updateApplicationContext(message)
            WCSession.default.transferUserInfo(message)
            
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
//        print(message)
        
        received(message)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any] ) {
        received(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        received(userInfo)
    }
    
    var session: WCSession
    
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
