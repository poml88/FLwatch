//
//  PhoneAppSettingsView.swift
//  LibreWrist
//
//  Created by Peter Müller on 03.09.24.
//

import SwiftUI
import MessageUI

struct PhoneAppSettingsView: View {
    
    @AppStorage(SharedData.Keys.showIOBCurvePhone.key, store: SharedData.defaultsGroup) private var showIOBCurvePhone: Bool = false
    @AppStorage(SharedData.Keys.showIOBCurveWatch.key, store: SharedData.defaultsGroup) private var showIOBCurveWatch: Bool = false
    
    @State private var isScreenAlwaysOn = false
    @State private var showingMailView = false
    @State private var isShowingSiriSheet = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    @State private var insulinTypeSelected: InsulinType = UserDefaults.group.insulinTypeSelected
    private var watchConnector = WatchConnectivityManager.shared
    
    var body: some View {
        Form {
            Section {
                
                Toggle("Keep phone screen always on", isOn: $isScreenAlwaysOn)
                    .onChange(of: isScreenAlwaysOn) { value in
                        print("yes")
                        UIApplication.shared.isIdleTimerDisabled.toggle()
                    }
                Toggle("Show IOB curve on phone", isOn: $showIOBCurvePhone)
                    .onChange(of: showIOBCurvePhone) { value in
                        print("yes")
                    }
                Toggle("Show IOB curve on watch", isOn: $showIOBCurveWatch)
                    .onChange(of: showIOBCurveWatch) { value in
                        print("yes")
                        let messageToWatch: [String: Any] = ["content": "showIOBCurveWatchMessage",
                                                             "showIOBCurveWatch": value]
                        sendMessagetoOther(message: messageToWatch)
                    }
            } header: {
                Text("Settings")
            }
            
            Section {
                Picker(selection: $insulinTypeSelected) {
                    ForEach(InsulinType.allCases, id: \.self) {
                        Text($0.description)
                        
                    }
                } label: {
                }
                .labelsHidden()
                //                                    .pickerStyle(.navigationLink)
                .onChange(of: insulinTypeSelected) {value in
                    UserDefaults.group.insulinTypeSelected = value
                    let messageToWatch: [String: Any] = ["content": "updateInsulinTypeSelected",
                                                         "insulinTypeSelected": value.rawValue]
                    sendMessagetoOther(message: messageToWatch)
                }
            } header: {
                Text("Insulin selection")
            } footer: {
                Text("Select the bolus insulin for the IOB calculations. Currently supported are:\n- Rapid acting (Novolog, Novorapid, ... (peak activity 75 mins))\n- Fast rapid acting (Fiasp, Lyumjev, ... (peak activity 55 mins))")
            }
            .fixedSize(horizontal: false, vertical: true)
            
            
            Section {
                Link(destination: URL(string: "https://github.com/poml88/FLwatch/#usage")!) {
                    Text("Setup and usage guide")
                        .frame(width: 200, height: 50)
                        .foregroundColor(.accentColor)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                }
                
                Button {
                    isShowingSiriSheet.toggle()
                } label: {
                    Text("Siri integration")
                        .padding(-5)
                        .frame(width: 177, height: 35)
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $isShowingSiriSheet, content: {
                    PhoneAppSiriSheetView()
                })
                
                
                
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
                Text("Support")
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
                
                Text("Error message: \(DebugMessageSingleton.shared.libreLinkUpResponseError)")
                
            } header: {
                Text("Debug Info")
            }
            
        }
        
    }
    func sendMessagetoOther(message: [String: Any]) {
        watchConnector.sendMessageToPairedDevice(message)
    }
    
}

#Preview {
    PhoneAppSettingsView()
}






