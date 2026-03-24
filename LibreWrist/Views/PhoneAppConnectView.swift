//
//  PhoneAppSetupView.swift
//  LibreWrist
//
//  Created by Peter Müller on 29.07.24.
//

import SwiftUI
import OSLog
import WidgetKit
 

struct PhoneAppConnectView: View {
    
//    @StateObject var watchConnector = WatchConnectivityManager.shared
//    @EnvironmentObject var watchConnector: WatchConnectivityManager
    
    @State private var username = UserDefaults.group.username
    @State private var password: String 
    @State private var connected = UserDefaults.group.connected
    @State private var libreLinkUpResponse: String = "[...]"
    @State private var isShowingConnectionFailed = false
    @State private var libreLinkUpPatients: [LibreLinkUpPatient] = SharedData.libreLinkUpPatients
    private var watchConnector = WatchConnectivityManager.shared
    
    let libreLinkUp = LibreLinkUp()
 
    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()
    
    init() {
        _password = State(initialValue: (try? PasswordKeychain.read()) ?? "")
    }

    
    
    func statusMessage() -> LocalizedStringResource {
        switch connected {
        case .connected: return "Connected."
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .failed: return "Connection failed."
        case .locked: return "Access temporarly locked."
        }
    }
    
    func statusColor() -> Color {
        switch connected {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .failed: return .red
        case .locked: return .black
        }
    }

    private var selectedPatientName: String {
        if let selectedPatient = libreLinkUpPatients.first(where: { $0.patientId == SharedData.libreLinkUpPatientId }) {
            return selectedPatient.displayName
        }
        return libreLinkUpPatients.first?.displayName ?? "No patient selected"
    }
    
    
    var body: some View {
        VStack {
            
            Text("FLwatch")
                .padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                .font(.system(.title))
                .foregroundColor(.green)
            
            
            Form {
                Section(header: Text("Credentials"), footer: Text("Enter the credentials for your [LibreLinkUp follower account](https://www.librelinkup.com/) and press the Connect button. Credentials will be sent automatically to watch app if it is installed.\n[TROUBLE? TAP TO OPEN HELP](https://flwatch.app/)")) {
                    TextField(text: $username, prompt: Text("Username (email adress)")) {
                        Text("Username")
                    }
                    .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .submitLabel(.done)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onChange(of: username) {
                            UserDefaults.group.connected = .disconnected
                            SharedData.libreLinkUpToken = ""
                            SharedData.libreLinkUpPatientId = ""
                            SharedData.libreLinkUpPatients = []
                            libreLinkUpPatients = []
                        }
                    SecureField(text: $password, prompt: Text("Password")) {
                        Text("Password")
                    }.submitLabel(.done)
                    .onChange(of: password) { 
                        UserDefaults.group.connected = .disconnected
                        SharedData.libreLinkUpToken = ""
                        SharedData.libreLinkUpPatientId = ""
                        SharedData.libreLinkUpPatients = []
                        libreLinkUpPatients = []
                    }
                }
                Section {
                    Button("Connect") {
                        tryToConnect()
                    }
                    
                }
                .disabled(username.isBlank || password.isBlank)

                if !libreLinkUpPatients.isEmpty {
                    Section("Patient") {
                        Menu {
                            ForEach(libreLinkUpPatients) { patient in
                                Button(patient.displayName) {
                                    selectPatient(patient)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Selected patient")
                                Spacer()
                                Text(selectedPatientName)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
//                Section {
//                    Link(destination: URL(string: "https://github.com/poml88/FLwatch?tab=readme-ov-file#usage")!) {
//                        Text("Tap to open user's guide")
//                    }
//                }
                
                if watchConnector.session.activationState == .activated && !watchConnector.session.isWatchAppInstalled {
                    Text("**Watch app not installed / detected**\nCredentials will not be transferred to watch. Install watch app and press \"Connect\" again to resend credentials to watch.")
                        .font(.system(size: 16))
                } else {
                    Text("Press \"Connect\" again to resend credentials to watch.")
                        .font(.system(size: 16))
                }
                if connected == .connected {
                    Text("**Not for treatment decisions.**\n\nThe information presented in this app and its extensions must not be used for treatment or dosing decisions. Consult the glucose-monitoring system and/or a healthcare professional.")
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
                        .cornerRadius(10)
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
            libreLinkUpPatients = SharedData.libreLinkUpPatients
            //    UserDefaults.group.connected.connected = .disconnected
        }
        .task {
            if let existing = try? PasswordKeychain.read(){
                password = existing
            }
            libreLinkUpPatients = SharedData.libreLinkUpPatients
        }
    }
        
    private func selectPatient(_ patient: LibreLinkUpPatient) {
        SharedData.libreLinkUpPatientId = patient.patientId
        SharedData.libreLinkUpLastUsedPatientId = patient.patientId
        libreLinkUpPatients = SharedData.libreLinkUpPatients
        WidgetCenter.shared.reloadAllTimelines()
        let messageToWatch: [String: Any] = [
            "content": "updateLibreLinkUpPatient",
            "patientId": patient.patientId
        ]
        watchConnector.sendMessageToPairedDevice(messageToWatch)
    }
    
    
    private func tryToConnect() {
        SharedData.libreLinkUpToken = ""
        SharedData.libreLinkUpPatientId = ""
        SharedData.libreLinkUpPatients = []
        libreLinkUpPatients = []
        UserDefaults.group.username = username
        try? PasswordKeychain.save(password)
        UserDefaults.group.connected = .connecting
        Task {
            do {
                print("do tryToConnect")
                try await libreLinkUp.login()
                UserDefaults.group.connected = .connected
                let messageToWatch: [String: Any] = ["content": "credentials",
                                                     "username": username,
                                                     "password": password,
                                                     "patientId": SharedData.libreLinkUpPatientId]
                sendMessagetoOther(message: messageToWatch)
                WidgetCenter.shared.reloadAllTimelines()
                print("WidgetCenter.shared.reloadAllTimelines()")
            } catch {
                print("catch tryToConnect")
                isShowingConnectionFailed = true
                libreLinkUpResponse = error.localizedDescription
                SharedData.libreLinkUpPatientId = ""
                UserDefaults.group.connected = .disconnected
            }
        }
        
        func sendMessagetoOther(message: [String: Any]){
            
            //            let messageToSend: [String: Any] = ["message": message]
            watchConnector.sendMessageToPairedDevice(message)
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
