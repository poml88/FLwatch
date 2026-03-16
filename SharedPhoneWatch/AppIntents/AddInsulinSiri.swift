//
//  AddInsulinSiri.swift
//  LibreWrist
//
//  Created by Peter Müller on 11.09.25.
//


import AppIntents
import SwiftUI
import WidgetKit


struct AddInsulinSiri: AppIntent {
    static var title: LocalizedStringResource = "Record Insulin Injection (written)"
    static var description: IntentDescription = "Ask the system to record insulin units for IOB calculation."
    
    
    @Parameter(title: "Insulin Units (written)",
               description: "How many insulin units?"
    )
    
    var unitsDoubleWritten: Double?
    
    
    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$unitsDoubleWritten) units of insulin (written)") {
        }
    }
    
    
    @MainActor
    //    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        
        var insulinDeliveryUnits: Double = 0.0
        
        if let val = unitsDoubleWritten, val >= 0.5, val <= 30.0 {
            insulinDeliveryUnits = val
        }
        
        if insulinDeliveryUnits == 0.0 {
            let request = try await $unitsDoubleWritten.requestValue("How many insulin units?")
            insulinDeliveryUnits = request
        }
        
        
        
        //            let formattedString = formatter.number(from: string)
        //            insulinDeliveryUnits = Double(formattedString ?? 0.0)
        
        //        var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
        let insulinDeliveryTimeStamp = Date.now.timeIntervalSince1970
        let delivery = await InsulinDeliveryHistorySingleton.shared.recordDeliveryAndAwaitExport(
            timestamp: Date(timeIntervalSince1970: insulinDeliveryTimeStamp),
            insulinUnits: insulinDeliveryUnits,
            insulinType: UserDefaults.group.insulinTypeSelected.rawValue
        )
        
        let messageToWatch: [String: Any] = ["content": "insulinDelivery",
                                             "id": delivery.id.uuidString,
                                             "timeStamp": insulinDeliveryTimeStamp,
                                             "units": insulinDeliveryUnits,
                                             "insulinType": delivery.insulinType]
        sendMessagetoOther(message: messageToWatch)
        
        let units = String(format: "%.1f", insulinDeliveryUnits)
        let dialogString: IntentDialog = "Recorded \(units) units of insulin."
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetCenter.shared.reloadAllTimelines()")
        
        return .result(
            dialog: dialogString,
            view: AddInsulinSiriSnippetView(units: units)
        )
    }
    
    func sendMessagetoOther(message: [String: Any]) {
        WatchConnectivityManager.shared.sendMessageToPairedDevice(message)
    }
    
    
    
    
}

struct AddInsulinSiriSnippetView: View {
    var units: String
    var body: some View {
        Text("Units recorded: \(units).")
            .accessibilityLabel("Insulin units recorded: \(units)")
    }
}
