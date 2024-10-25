//
//  PhoneAppSetupView.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.07.24.
//

import SwiftUI
import OSLog
import SecureDefaults
 

struct PhoneAppConnectView: View {
    
    @StateObject var watchConnector = PhoneToWatchConnector()
    
    @State private var username = UserDefaults.group.username
    @State private var password = SecureDefaults.sgroup.string(forKey: "llu.password") ?? ""
    @State private var connected = UserDefaults.group.connected
    @State private var libreLinkUpResponse: String = "[...]"
    @State private var isShowingConnectionFailed = false
    

    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()
    
    
    func statusMessage() -> String {
        switch connected {
        case .connected: return "Connected."
        case .newlyConnected: return "Connected."
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .failed: return "Connection failed."
        case .locked: return "Access temporarly locked."
        }
    }
    
    func statusColor() -> Color {
        switch connected {
        case .connected: return .green
        case .newlyConnected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .failed: return .red
        case .locked: return .black
        }
    }
    
    
    var body: some View {
        VStack {
            
            Text("FLwatch")
                .padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                .font(.system(.title))
                .foregroundColor(.green)
            
            
            Form {
                Section(header: Text("Credentials"), footer: Text("Enter the credentials for your [LLU follower account](https://www.librelinkup.com/) and press the Connect button. Credentials will be sent automatically to watch app if it is installed.".attributed)) {
                    TextField(text: $username, prompt: Text("Username (email adress)")) {
                        Text("Username")
                    }.textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onChange(of: username) { _ in
                            UserDefaults.group.connected = .disconnected
                            settings.libreLinkUpToken = ""
                        }
                    SecureField(text: $password, prompt: Text("Password")) {
                        Text("Password")
                    }.onChange(of: password) { _ in
                        UserDefaults.group.connected = .disconnected
                        settings.libreLinkUpToken = ""
                    }
                }
                Section {
                    Button("Connect") {
                        tryToConnect()
                    }
                }
                .disabled(username.isBlank || password.isBlank)
                
                if watchConnector.session.activationState == .activated && !watchConnector.session.isWatchAppInstalled {
                    Text("**Watch app not installed / detected**\nCredentials will not be transferred to watch. Install watch app and press \"Connect\" again to resend credentials to watch.")
                        .font(.system(size: 16))
                } else {
                    Text("Press \"Connect\" again to resend credentials to watch.")
                        .font(.system(size: 16))
                }
                if connected == .connected || connected == .newlyConnected {
                    Text("**Not for treatment decisions.**\\\n\\\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.".attributed)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
            .disabled(connected == .connecting || connected == .locked)
            
            Text(statusMessage())
                .padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                .frame(maxWidth: .infinity)
                .background(statusColor())
                
            Spacer()
        }
        .alert ("Warning", isPresented: $isShowingConnectionFailed) {
//            Button("Accept", role: .cancel, action: {settings.hasSeenDisclaimer = true})
        }
    message: {
            Text(libreLinkUpResponse)
        }
        .overlay
        {
            if connected == .connecting {
                ZStack {
                    Color(white: 0, opacity: 0.25)
                    ProgressView().tint(.white)
                }
            }
        }
//        .background(LinearGradient(
//            colors: [.white, .white, statusColor()],
//            startPoint: .top,
//            endPoint: .bottom)
//        )
        .onReceive(timer) { time in
            // TODO: synchronize by common method
            connected = UserDefaults.group.connected
            //    UserDefaults.group.connected.connected = .disconnected
        }
    }
    
    private func tryToConnect() {
        settings.libreLinkUpToken = ""
        UserDefaults.group.username = username
        let sdefaults = SecureDefaults.sgroup
        if !(sdefaults.isKeyCreated) {
            sdefaults.password = UUID().uuidString
        }
        sdefaults.set(password, forKey: "llu.password")
        sdefaults.synchronize()
        UserDefaults.group.connected = .connecting
        Task {
            do {
                print("do")
                try await LibreLinkUp().login()
                UserDefaults.group.connected = .newlyConnected
                let messageToWatch: [String: Any] = ["content": "credentials",
                                                     "username": username,
                                                     "password": password]
                sendMessagetoWatch(message: messageToWatch)
            } catch {
                print("catch")
                isShowingConnectionFailed = true
                libreLinkUpResponse = error.localizedDescription
                UserDefaults.group.connected = .disconnected
            }
        }
        
        func sendMessagetoWatch(message: [String: Any]){
            
            //            let messageToSend: [String: Any] = ["message": message]
            watchConnector.sendMessagetoWatch(message)
        }
        
//        libreViewAPI.fetchCurrentGlucoseEntry { glucose, error in
//            if glucose != nil {
//                appConfiguration.connected = .connected
//            } else {
//                if error is Int && error as? Int == FetchStatus.LOCKED {
//                    appConfiguration.connected = .locked
//                } else {
//                    appConfiguration.connected = .failed
//                }
//            }
//        }
        
    }
}

#Preview {
    PhoneAppConnectView()
}
