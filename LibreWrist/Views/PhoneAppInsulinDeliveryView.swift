//
//  PhoneAppInsulinDeliveryView.swift
//  LibreWrist
//
//  Created by Peter Müller on 01.09.24.
//

import SwiftUI

struct PhoneAppInsulinDeliveryView: View {
    
    // Existing persisted manual picker
    @AppStorage(DefaultsKey.insulinSelected.rawValue, store: UserDefaults.group)
    private var insulinSelected: Double = 0.5
    
    // NEW: persisted calculator settings
    @AppStorage(DefaultsKey.icrGramsPerUnit.rawValue, store: UserDefaults.group)
    private var icrGramsPerUnit: Double = 10
    
    @AppStorage(DefaultsKey.roundingStep.rawValue, store: UserDefaults.group)
    private var roundingStep: Double = 0.5
    
    @AppStorage(DefaultsKey.carbsPer100g.rawValue, store: UserDefaults.group)
    private var carbsPer100g: Double = 0
    
    @AppStorage(DefaultsKey.portionGrams.rawValue, store: UserDefaults.group)
    private var portionGrams: Double = 0
    
    @AppStorage(DefaultsKey.carbsStore.rawValue, store: UserDefaults.group)
    private var carbsStore: Double = 0
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.insulinDeliveryHistorySingleton) var insulinDeliveryHistorySingleton
    
    @State private var pickerTimeStamp: Date = Date.now
    @State private var isShowingInsulinDeliverySubmitAlert = false
    @State private var isShowingInsulinDeliveryResetAlert = false
    @State private var isShowingDifferenceTimePickerSheet = false
    @State private var isShowingInsulinDeliveryResendToWatchAlert = false
    @State private var insulinTypeSelected: InsulinType = UserDefaults.group.insulinTypeSelected
    
    @State private var navigationPath = NavigationPath()
    
    private var watchConnector = WatchConnectivityManager.shared
    
    // Manual doses
    let insulinDoses: [Double] = Array(stride(from: 0.5, to: 60, by: 0.5))
    
    // NEW: carb calculator transient inputs
//    @State private var carbsPer100g: Double = 0
//    @State private var portionGrams: Double = 0
    let portionChoices: [Int] = [50, 75, 100, 150, 200, 250, 300, 400]
    
    
    // MARK: - Calculator computed values
    private var totalCarbs: Double {
        max(0, carbsPer100g) * max(0, portionGrams) / 100.0
    }
    private var insulinUnitsRaw: Double {
        guard icrGramsPerUnit > 0 else { return 0 }
        return carbsStore / icrGramsPerUnit
    }
    private var insulinUnitsRounded: Double {
        guard roundingStep > 0 else { return insulinUnitsRaw }
        return (insulinUnitsRaw / roundingStep).rounded() * roundingStep
    }
    private var hasValidCalculatedDose: Bool {
        insulinUnitsRaw > 0 // raw > 0 implies rounded ≥ 0 unless rounding is 0
    }
    private let roundingChoices: [(label: String, step: Double)] = [
        ("No rounding", 0),
        ("0.5 U", 0.5),
        ("1 U", 1.0)
    ]
    
    enum Field: Hashable { case carbsPer100g, portionGrams, icrGramsPerUnit }
    
    @FocusState private var focused: Field?

    
    var body: some View {
        NavigationStack(path: $navigationPath) { // necessary for the toolbar of the numeric keyboard
            VStack {
                Button { dismiss() } label: { Text("Dismiss") }
                    .buttonStyle(.borderedProminent)
                    .padding()
                
                Form {
                    // MARK: Manual entry (existing)
                    Section {
                        Picker(selection: $insulinTypeSelected) {
                            ForEach(InsulinType.allCases, id: \.self) {
                                Text($0.description)
                            }
                        } label: {
                            Text("Bolus insulin")
                        }
                        //                .labelsHidden()
                        //                                    .pickerStyle(.navigationLink)
                        .onChange(of: insulinTypeSelected) {oldValue, newValue in
                            UserDefaults.group.insulinTypeSelected = newValue
                            let messageToWatch: [String: Any] = ["content": "updateInsulinTypeSelected",
                                                                 "insulinTypeSelected": newValue.rawValue]
                            sendMessagetoOther(message: messageToWatch)
                        }
                        
                        Picker("Insulin units", selection: $insulinSelected) {
                            ForEach(insulinDoses, id: \.self) {
                                Text("\($0, specifier: "%.1f")")
                            }
                        }
                        .pickerStyle(.menu)
                        
                        DatePicker(selection: $pickerTimeStamp) { Text("Time: ") }
                        
                        Button {
                            isShowingDifferenceTimePickerSheet = true
                        } label: {
                            Text("or: Time since injection")
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .sheet(isPresented: $isShowingDifferenceTimePickerSheet) {
                            TimeDifferencePicker(pickerTimeStamp: $pickerTimeStamp)
                        }
                        
                        Button {
                            isShowingInsulinDeliverySubmitAlert = true
                        } label: {
                            Text("Add insulin")
                        }
                        .buttonStyle(.borderedProminent)
                        // Enable if EITHER manual OR calculated dose is > 0
                        .disabled(insulinSelected == 0.0 && !hasValidCalculatedDose)
                        
                    } header: {
                        Text("Record insulin units")
                    }
                    
                    
                    
                    // MARK: Carb calculator (NEW)
                    Section {
                        HStack {
                            Text("Carbs per 100 g")
                            Spacer()
                            TextField("0", value: $carbsPer100g,
                                      format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .focused($focused, equals: .carbsPer100g)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 90)
                            .onChange(of: carbsPer100g) { carbsPer100g = max(0, carbsPer100g) }
                            Text("g")
                                .foregroundStyle(.secondary)
                        }
                    
//                    GeometryReader { proxy in
//                        HStack(spacing: 8) {
//                            Text("Carbs per 100 g")
//                                .frame(width: proxy.size.width * 0.7, alignment: .leading)
//
//                            HStack(spacing: 4) {
//                                TextField("0", value: $carbsPer100g,
//                                          format: .number.precision(.fractionLength(0...2)))
//                                .keyboardType(.decimalPad)
//                                .focused($focused, equals: .carbsPer100g)
//                                .multilineTextAlignment(.trailing)
//                                .onChange(of: carbsPer100g) { carbsPer100g = max(0, carbsPer100g) }
//
//                                Text("g")
//                                    .foregroundStyle(.secondary)
//                            }
//                            .frame(width: proxy.size.width * 0.3, alignment: .trailing)
//                        }
//                    }
//                    .frame(height: 22)
                    
                    
                        
                        HStack {
                            Text("Portion size")
                            Spacer()
                            TextField("0", value: $portionGrams,
                                      format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .focused($focused, equals: .portionGrams)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 90)
                            .onChange(of: portionGrams) { portionGrams = max(0, portionGrams) }
                            Text("g")
                                .foregroundStyle(.secondary)
                        }
                        
                        // Quick portion chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(portionChoices, id: \.self) { g in
                                    Button("\(g) g") { portionGrams = Double(g) }
                                        .buttonStyle(.bordered)
                                }
                                Button {
                                    portionGrams = 0
                                } label: {
                                    Label("Clear", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .tint(.gray)
                            }
                            .padding(.top, 2)
                        }
                        
                        HStack {
                            Text("Resulting carbs")
                            Spacer()
                            Text(totalCarbs, format: .number.precision(.fractionLength(0...1))).foregroundStyle(.secondary)
                            Text("g").foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Button {
                                carbsStore += totalCarbs
                            } label: {
                                Label("Carbs → store", systemImage: "arrow.down.doc")
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                carbsStore = 0
                            } label: {
                                Label("Clear store", systemImage: "xmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)                    }
                        
                        HStack {
                            Text("Carbs store")
                            Spacer()
                            Text(carbsStore, format: .number.precision(.fractionLength(0...1))).foregroundStyle(.secondary)
                            Text("g").foregroundStyle(.secondary)
                        }
                        
                        // ICR & rounding
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ICR")
                                Spacer()
                                TextField("10", value: $icrGramsPerUnit,
                                          format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .focused($focused, equals: .icrGramsPerUnit)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 90)
                                .onChange(of: icrGramsPerUnit) { icrGramsPerUnit = max(0, icrGramsPerUnit) }
                                Text("g / 1U").foregroundStyle(.secondary)
                            }
                            Text("Enter grams per 1U (e.g., 10 ≙ 1U/10g).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        
                        Picker("Rounding", selection: $roundingStep) {
                            ForEach(roundingChoices, id: \.step) { c in
                                Text(c.label).tag(c.step)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Results
                        
                        HStack {
                            Text(roundingStep > 0 ? "Insulin (rounded)" : "Insulin")
                            Spacer()
                            Text(
                                (roundingStep > 0 ? insulinUnitsRounded : insulinUnitsRaw),
                                format: .number.precision(.fractionLength(0...2))
                            ).foregroundStyle(.secondary)
                            Text("U").foregroundStyle(.secondary)
                        }
                        if roundingStep > 0 && abs(insulinUnitsRounded - insulinUnitsRaw) >= 0.01 {
                            HStack {
                                Text("Raw")
                                Spacer()
                                Text(insulinUnitsRaw, format: .number.precision(.fractionLength(0...2)))
                                Text("U").foregroundStyle(.secondary)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        
                        // Convenience: copy calc → manual picker
                        if hasValidCalculatedDose {
                            
                            Button {
                                if roundingStep > 0 {
                                    insulinSelected = insulinUnitsRounded
                                } else {
                                    roundingStep = 0.5 ; insulinSelected = insulinUnitsRounded ; roundingStep = 0
                                }
                            } label: {
                                Label("Copy calculated → insulin picker", systemImage: "arrow.down.doc")
                            }
                            .buttonStyle(.bordered)
                            
                        }
                        
                        
                        
                    } header: {
                        Text("Carb Calculator")
                    } footer: {
                        Text("Convenience calculator only. Follow your care plan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    // MARK: Existing history list
                    if !insulinDeliveryHistorySingleton.insulinDeliveryHistory.isEmpty {
                        
                        Section(header: Text("Insulin Delivery History")) {
                            Button {
                                isShowingInsulinDeliveryResetAlert.toggle()
                            } label: {
                                Text("Reset IOB")
                            }
                            .buttonStyle(.borderedProminent)
                            ForEach(insulinDeliveryHistorySingleton.insulinDeliveryHistory, id: \.id) { item in
                                let timeInterval = Date(timeIntervalSince1970: item.timeStamp).timeIntervalSinceNow
                                let timeSinceInjection = Duration(
                                    secondsComponent: Int64(-timeInterval),
                                    attosecondsComponent: 0
                                ).formatted(.time(pattern: .hourMinute))
                                
                                Text("Time: \(Date(timeIntervalSince1970: item.timeStamp).toLocalTime())  (\(timeSinceInjection) h)      Units: \(item.insulinUnits, specifier: "%.1f")")
                            }
                            .onDelete(perform: deleteHistory)
                            Button {
                                isShowingInsulinDeliveryResendToWatchAlert.toggle()
                            } label: {
                                Text("Resend history to watch")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .toolbar {
                    if focused == .carbsPer100g || focused == .portionGrams || focused == .icrGramsPerUnit {
                        ToolbarItemGroup(placement: .keyboard) {
                            // Previous / Next (disabled appropriately)
                            Button(action: focusPrevious) {
                                Image(systemName: "chevron.left")
//                                Text("Prev")
                            }
                            .disabled(focused == nil || focused == .carbsPer100g)
                            
                            Button(action: focusNext) {
//                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .disabled(focused == nil || focused == .icrGramsPerUnit)
                            
                            Spacer()
                            
                            Button("Clear") { clearFocused() }
                            
                            Spacer()
                            
                            Button("Done") {
                                focused = nil
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            }
                        }
                    }
                }
//                .toolbar {
//                    ToolbarItemGroup(placement: .keyboard) {
//                        
//                        
//                        Button("Clear") { clearFocused() }
//                        Spacer()
//                        Button("Done") {
//                            // Preferred: dismiss via FocusState
//                            focused = nil
//                            
//                            // Fallback: resign first responder via UIKit
//                            UIApplication.shared.sendAction(
//                                #selector(UIResponder.resignFirstResponder),
//                                to: nil, from: nil, for: nil
//                            )
//                        }
//                        
//                    }
//                }
                .scrollDismissesKeyboard(.interactively)
                
                // MARK: - Alerts
                .alert ("Confirm", isPresented: $isShowingInsulinDeliverySubmitAlert) {
                    Button("Submit", action: {
                        let insulinDeliveryTimeStamp = pickerTimeStamp
                        let insulinDeliveryUnits = insulinSelected
                        let delivery = insulinDeliveryHistorySingleton.recordDelivery(
                            timestamp: insulinDeliveryTimeStamp,
                            insulinUnits: insulinDeliveryUnits,
                            insulinType: UserDefaults.group.insulinTypeSelected.rawValue
                        )
                        
                        let messageToWatch: [String: Any] = ["content": "insulinDelivery", // The insulinTypeSelected is taken from UserDefaults, so does not need to be sent.
                                                             "id": delivery.id.uuidString,
                                                             "timeStamp": insulinDeliveryTimeStamp.timeIntervalSince1970,
                                                             "units": insulinDeliveryUnits,
                                                             "insulinType": delivery.insulinType]
                        sendMessagetoOther(message: messageToWatch)
                        
                        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                        refreshLiveActivityIfNeeded()
                        dismiss()
                        //                        selectedTab = "Home"
                    })
                    Button("Cancel", role: .cancel, action: {})
                } message: {
                    
                    Text("Do you want to add \(insulinSelected, specifier: "%.1f") units?")
                }
                .alert("Confirm", isPresented: $isShowingInsulinDeliveryResetAlert) {
                    Button("Reset", action: {
                        pickerTimeStamp = Date.now
                        insulinDeliveryHistorySingleton.clearHistory()
                        let messageToWatch: [String: Any] = ["content": "clearInsulinHistory"]
                        sendMessagetoOther(message: messageToWatch)
                        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                        refreshLiveActivityIfNeeded()
                    })
                    Button("Cancel", role: .cancel, action: {})
                } message: {
                    Text("Do you want to reset insulin history?")
                }
                .alert("Confirm", isPresented: $isShowingInsulinDeliveryResendToWatchAlert) {
                    Button("Resend", action: {
                        pickerTimeStamp = Date.now
                        let messageToWatch: [String: Any] = ["content": "clearInsulinHistory"]
                        sendMessagetoOther(message: messageToWatch)
                        resendHistoryToWatch()
                        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
                        refreshLiveActivityIfNeeded()
                    })
                    Button("Cancel", role: .cancel, action: {})
                } message: {
                    Text("Do you want to resend the insulin history to the watch?")
                }
                
            }
            //        .toolbar {
            //            // Keyboard toolbar to dismiss number pads
            //            ToolbarItemGroup(placement: .keyboard) {
            //                Spacer()
            //                Button("Done") {
            //                    // Dismiss keyboard
            //                 }
            //            }
            //        }
            .onAppear {
                if icrGramsPerUnit <= 0 { icrGramsPerUnit = 10 }
                if roundingStep < 0 { roundingStep = 0.5 }
            }
        }
    }
    
    // MARK: - Submit helper (shared path, unchanged logic)
    private func submitInsulinXXX(units: Double, timestamp: Date, source: String) {
        let insulinDeliveryUnits = units

        _ = source

        let delivery = insulinDeliveryHistorySingleton.recordDelivery(
            timestamp: timestamp,
            insulinUnits: insulinDeliveryUnits,
            insulinType: UserDefaults.group.insulinTypeSelected.rawValue
        )
        
        var messageToWatch: [String: Any] = [
            "content": "insulinDelivery",
            "id": delivery.id.uuidString,
            "timeStamp": timestamp.timeIntervalSince1970,
            "units": insulinDeliveryUnits,
            "insulinType": delivery.insulinType
        ]
        // Optional: tag the origin (manual/calculated); safe if ignored by receiver
        messageToWatch["source"] = source
        sendMessagetoOther(message: messageToWatch)
        
        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        refreshLiveActivityIfNeeded()
        dismiss()
    }
    
    private func sendMessagetoOther(message: [String: Any]) {
        watchConnector.sendMessageToPairedDevice(message)
    }
    
    private func deleteHistory(at offsets: IndexSet) {
        insulinDeliveryHistorySingleton.read()
        var history = insulinDeliveryHistorySingleton.insulinDeliveryHistory
        let removedItems = offsets.map { history[$0] }
        history.remove(atOffsets: offsets)

        // Update model & persist
        insulinDeliveryHistorySingleton.replaceHistory(history)
        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        refreshLiveActivityIfNeeded()

        // Notify paired watch about deletions (optional)
        for item in removedItems {
            let messageToWatch: [String: Any] = [
                "content": "deleteInsulin",
                "id": item.id.uuidString,
                "timestamp": item.timeStamp
            ]
            sendMessagetoOther(message: messageToWatch)
        }
    }
    
    private func resendHistoryToWatch() {
        insulinDeliveryHistorySingleton.read()
        let history = insulinDeliveryHistorySingleton.insulinDeliveryHistory
//        let removedItems = offsets.map { history[$0] }
//        history.remove(atOffsets: offsets)
//
//        // Update model & persist
//        insulinDeliveryHistorySingleton.insulinDeliveryHistory = history
//        UserDefaults.group.insulinDeliveryHistory = history
//        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()

        // Notify paired watch about deletions (optional)
        for item in history {
            let messageToWatch: [String: Any] = ["content": "insulinDelivery", // The insulinTypeSelected is taken from UserDefaults, so does not need to be sent.
                                                 "id": item.id.uuidString,
                                                 "timeStamp": item.timeStamp,
                                                 "units": item.insulinUnits,
                                                 "insulinType": item.insulinType]
            sendMessagetoOther(message: messageToWatch)
            
            
        }
    }

    private func refreshLiveActivityIfNeeded() {
        guard SharedData.useLiveActivities else { return }
        Task {
            await LiveActivityManager.shared.refreshFromCurrentHistory(useLiveActivities: true)
        }
    }
    
    private func focusNext() {
        switch focused {
        case .carbsPer100g: focused = .portionGrams
        case .portionGrams: focused = .icrGramsPerUnit
        case .icrGramsPerUnit: focused = nil // dismiss after last, or change to .carbsPer100g to cycle
        default: focused = .carbsPer100g
        }
    }

    private func focusPrevious() {
        switch focused {
        case .carbsPer100g: focused = nil // already first
        case .portionGrams: focused = .carbsPer100g
        case .icrGramsPerUnit: focused = .portionGrams
        default: focused = .icrGramsPerUnit // fallback to first
        }
    }

    private func clearFocused() {
        switch focused {
        case .carbsPer100g:
            carbsPer100g = 0
        case .portionGrams:
            portionGrams = 0
        case .icrGramsPerUnit:
            icrGramsPerUnit = 0
        default:
            // no-op or clear all if you prefer
            break
        }
    }
}

#Preview {
    PhoneAppInsulinDeliveryView()
}
