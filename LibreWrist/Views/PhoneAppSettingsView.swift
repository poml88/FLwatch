//
//  PhoneAppSettingsView.swift
//  LibreWrist
//
//  Created by Peter Müller on 03.09.24.
//

import SwiftUI
import MessageUI

struct PhoneAppSettingsView: View {
    
    @State private var isScreenAlwaysOn = false
    @State private var showingMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    
    var body: some View {
        Form {
            Section {
                
                Toggle("Keep phone screen always on", isOn: $isScreenAlwaysOn)
                    .onChange(of: isScreenAlwaysOn) { value in
                        print("yes")
                        UIApplication.shared.isIdleTimerDisabled.toggle()
                    }
            } header: {
            Text("Settings")
        }
            
            Section {
                let versionNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
                Text("V\(versionNumber).\(buildNumber)")
                
                let systemVersion = UIDevice.current.systemVersion
                let systemName = UIDevice.current.systemName
                let model = UIDevice.current.model
                let name = UIDevice.current.name
                Text("\(systemName) \(systemVersion) on \(name)")
                
                Text("Sensor: \(SensorSettingsSingleton.shared.sensorType)")

                
                Link(destination: URL(string: "https://github.com/poml88/FLwatch/issues")!) {
                    Text("Open issue on GitHub")
                        .frame(width: 200, height: 50)
                        .foregroundColor(.accentColor)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                }
                
                Button {
                    showingMailView.toggle()
                } label: {
                 Text("Send Email to Support")
                        .padding(-5)
                        .frame(width: 177, height: 35)
                }
                .buttonStyle(.bordered)
                
                .disabled(!MailView.canSendMail())
                .sheet(isPresented: $showingMailView) {
                    MailView(result: $mailResult)
                }
               
            } header: {
            Text("Debug Info")
        }
            
        }
    }
}

#Preview {
    PhoneAppSettingsView()
}




    
  
