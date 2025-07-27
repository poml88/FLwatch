//
//  PhoneAppSettingsView.swift
//  LibreWrist
//
//  Created by Peter Müller on 01.09.24.
//

import SwiftUI

struct PhoneAppInsulinDeliveryView: View {
    
    @AppStorage(SharedData.Keys.insulinSelected.key, store: SharedData.defaultsGroup) private var insulinSelected: Double = 0.5
    
    @Environment(\.dismiss) var dismiss
    
//    @StateObject var watchConnector = WatchConnectivityManager.shared
//    @EnvironmentObject var watchConnector: WatchConnectivityManager
    
    @State private var pickerTimeStamp: Date = Date.now
    @State private var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
    @State private var isShowingInsulinDeliverySubmitAlert = false
    @State private var isShowingInsulinDeliveryResetAlert = false
    @State private var isShowingDifferenceTimePickerSheet = false
    @State private var insulinTypeSelected: InsulinType = UserDefaults.group.insulinTypeSelected
    private var watchConnector = WatchConnectivityManager.shared
    
    //    @Binding var selectedTab: String
    
    let insulinDoses: [Double] = Array(stride(from: 0.5, to: 60, by: 0.5))
    
    var body: some View {
        VStack{
            
            
            Button {
                dismiss()
            } label: {
                Text("Dismiss")
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Form {
                Section {
                    Picker("Insulin units", selection: $insulinSelected) {
                        ForEach(insulinDoses, id: \.self) {
                            Text("\($0, specifier: "%.1f")")
                        }
                    }
                    .pickerStyle(.menu)
                    
                    DatePicker(selection: $pickerTimeStamp) {
                        Text("Time: ")
                    }
//                        .labelsHidden()
                    
                    Button {
                        isShowingDifferenceTimePickerSheet = true
                    } label: {
                        Text("or: Time since injection")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .sheet(isPresented: $isShowingDifferenceTimePickerSheet, content: {
                        TimeDifferencePicker(pickerTimeStamp: $pickerTimeStamp)
                    })
                    
                    Button {
                        isShowingInsulinDeliverySubmitAlert = true
                    } label: {
                        Text("Add insulin")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(insulinSelected == 0.0)
                    
                    Button {
                        isShowingInsulinDeliveryResetAlert.toggle()
                    } label:                    {
                        Text("Reset IOB")
                    }
                    .buttonStyle(.borderedProminent)
                } header: {
                    Text("Bolus Insulin (\(insulinTypeSelected.description))")
                }
            }
            //        .navigationBarTitle("Settings")
            .alert ("Confirm", isPresented: $isShowingInsulinDeliverySubmitAlert) {
                Button("Submit", action: {
                    let insulinDeliveryTimeStamp = pickerTimeStamp.timeIntervalSince1970
                    let insulinDeliveryUnits = insulinSelected
                    let insulinDeliveryHistoryItem = InsulinDelivery(id: UUID(), timestamp: insulinDeliveryTimeStamp, insulinUnits: insulinDeliveryUnits)
                    insulinDeliveryHistory.append(insulinDeliveryHistoryItem)
                    UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
                    
                    let messageToWatch: [String: Any] = ["content": "insulinDelivery",
                                                         "timeStamp": insulinDeliveryTimeStamp,
                                                         "units": insulinDeliveryUnits]
                    sendMessagetoOther(message: messageToWatch)
                    dismiss()
                    //                        selectedTab = "Home"
                })
                Button("Cancel", role: .cancel, action: {})
            } message: {
                
                Text("Do you want to add \(insulinSelected, specifier: "%.1f") units?")
            }
            
            .alert ("Confirm", isPresented: $isShowingInsulinDeliveryResetAlert) {
                Button("Reset", action: {
                    pickerTimeStamp = Date.now
                    insulinDeliveryHistory = []
                    UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
                    let messageToWatch: [String: Any] = ["content": "clearInsulinHistory"]
                    sendMessagetoOther(message: messageToWatch)
                })
                Button("Cancel", role: .cancel, action: {})
            } message: {
                Text("Do you want to reset insulin history?")
            }
            List{
                ForEach(insulinDeliveryHistory, id: \.id) {item in
                    let timeInterval = Date(timeIntervalSince1970: item.timeStamp).timeIntervalSinceNow
                    let timeSinceInjection = Duration(
                        secondsComponent: Int64(-timeInterval),
                        attosecondsComponent: 0
                    ).formatted(.time(pattern: .hourMinute))  // "2:05"

                    Text("Time: \(Date(timeIntervalSince1970: item.timeStamp).toLocalTime())  (\(timeSinceInjection) h)      Units: \(item.insulinUnits, specifier: "%.1f")")
                }
                
            }
            
                    }
    }
    
    func sendMessagetoOther(message: [String: Any]) {
        watchConnector.sendMessageToPairedDevice(message)
    }
}

#Preview {
    PhoneAppInsulinDeliveryView()
}
