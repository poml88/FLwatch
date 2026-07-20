//
//  MailView.swift
//  LibreWrist
//
//  Created by Peter Müller on 12.10.24.
//

import SwiftUI
import MessageUI

struct MailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var result: Result<MFMailComposeResult, Error>?
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        
        init(_ parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                parent.dismiss()
            }
            if let error = error {
                parent.result = .failure(error)
            } else {
                parent.result = .success(result)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let systemVersion = UIDevice.current.systemVersion
        let systemName = UIDevice.current.systemName
//        let model = UIDevice.current.model
        let name = UIDevice.current.name
        
        let cgmProvider = SharedData.cgmProviderKind.displayName
        let sensorType = SensorSettingsStore.shared.sensorType.description
        
        let libreLinkUpDebug = DebugMessageSingleton.shared.libreLinkUpResponseError
        
        let messageBody: LocalizedStringResource = "Hello,\n\n*** write your message here ***\n\n\n\nKind regards\n\n\n\n--\nDebug info:\nApp Version: \(versionNumber) Build: \(buildNumber)\nDevice Info: \(systemName) \(systemVersion) on \(name)\nCGM Provider: \(cgmProvider)\nSensor: \(sensorType)\nError Message: \(libreLinkUpDebug)\n\n"
        var messageBodyString: String = String(localized: messageBody)
        if SharedData.cgmProviderKind == .libre3BLE {
            let diagnostics = Libre3DiagnosticsLog.supportEmailBlock()
            if !diagnostics.isEmpty {
                messageBodyString += "\(diagnostics)\n"
            }
            let reconnectTrace = Libre3DiagnosticsLog.reconnectTraceEmailBlock()
            if !reconnectTrace.isEmpty {
                messageBodyString += "\(reconnectTrace)\n"
            }
        }

        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(["flwatch@cmdline.net"])
        vc.setSubject("Support FLwatch")
        vc.setMessageBody(messageBodyString, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        
    }
    
    static func canSendMail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
}
