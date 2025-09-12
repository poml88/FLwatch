//
//  AddInsulin.swift
//  LibreWrist
//
//  Created by Peter Müller on 26.04.25.
//

import AppIntents
import SwiftUI
import WidgetKit

//struct InsulinEntity: AppEntity {
//    /**
//     A localized name representing this entity as a concept people are familiar with in the app, including
//     localized variations based on the plural rules that the app's `.stringsdict` file defines (and references
//     through the `table` parameter). The app may show this value to people when they configure an intent.
//     */
//    static var typeDisplayRepresentation: TypeDisplayRepresentation {
//        TypeDisplayRepresentation(
//            name: LocalizedStringResource("Insulin Units", table: "AppIntents"),
//            numericFormat: LocalizedStringResource("\(placeholder: .double) insulin units", table: "AppIntents")
//        )
//    }
//    
//    var displayRepresentation: DisplayRepresentation {
//        DisplayRepresentation(title: "\(name)",
//                              subtitle: "\(regionDescription)",
//                              image: DisplayRepresentation.Image(named: imageName))
//    }
//
//    
//    var id: UUID = UUID()
//    var insulinUnits: Double
//}

struct RecommendedInsulinDoses: DynamicOptionsProvider {
  func results() async throws -> [Double] {
    // Could come from settings, last-used values, or clinical presets
//      let d: [Double] = InsulinUnitsEnum.allCases.compactMap { Double($0.rawValue) }
//      return d
      return stride(from: 0.5, through: 30.0, by: 0.5).map { $0 }
//    [0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10]
  }
}


struct AddInsulin: AppIntent {
    
    
    
    
    static var title: LocalizedStringResource = "Record Insulin Injection"
    static var description: IntentDescription = "Ask the system to record insulin units for IOB calculation."
    
    
    // We provide two parameters, one used only for AppShortcuts with a limited value of options,
    // and an open value that can be used programatically with Shortcuts and also on the times that
    // Siri fails to understand a value, to ask the user for something more precise.
    @Parameter(title: "Insulin Units",
               description: "How many insulin units?",
               requestValueDialog: "How much insulin?")
    
    var insulinUnitsEnum: InsulinUnitsEnum?
    
    //    @Parameter(title: "Insulin Units",
    //               description: "How many insulin units?",
    ////               inclusiveRange: (lowerBound: 0.5, upperBound: 30.0),
    ////               optionsProvider: RecommendedInsulinDoses()
    //               )
    //    var unitsDouble: Double?
    
    @Parameter(title: "Insulin Units",
               description: "How many insulin units?")
    
    var insulinUnitsRaw: String?
    
    
    //    @Parameter(title: "Units", description: "How many insulin units?")
    //    var unitsInt: Int?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$insulinUnitsRaw) units of insulin") {
        }
    }
    
    
    @MainActor
    //    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        
        var insulinDeliveryUnits: Double = 0.0
        
        if let value = insulinUnitsEnum?.rawValue, let d = Double(value) {
            insulinDeliveryUnits = d
        }
        
        //        if insulinDeliveryUnits == 0.0, let val = unitsDouble {
        //            insulinDeliveryUnits = val
        //        }
        
        if let raw = insulinUnitsRaw {
            // First try localized parsing (handles 8.5 vs 8,5)
            if let number = formatter.number(from: raw) {
                insulinDeliveryUnits = number.doubleValue
            } else {
                // Try spelling out numbers ("eight", "drei", "八")
                formatter.numberStyle = .spellOut
                if let number = formatter.number(from: raw.lowercased()) {
                    insulinDeliveryUnits = number.doubleValue
                }
            }
        }
        
        if insulinDeliveryUnits == 0.0 {
            let request = try await $insulinUnitsRaw.requestValue("How many insulin units?")
            let raw = request
            // First try localized parsing (handles 8.5 vs 8,5)
            if let number = formatter.number(from: raw) {
                insulinDeliveryUnits = number.doubleValue
            } else {
                // Try spelling out numbers ("eight", "drei", "八")
                formatter.numberStyle = .spellOut
                if let number = formatter.number(from: raw.lowercased()) {
                    insulinDeliveryUnits = number.doubleValue
                }
            }
        }
        
        if (insulinDeliveryUnits == 0.0 || insulinDeliveryUnits < 0.5 || insulinDeliveryUnits > 30.0  ) {
            throw $insulinUnitsRaw.needsValueError("Could not determine insulin units value.")
        }
        
        //            let formattedString = formatter.number(from: string)
        //            insulinDeliveryUnits = Double(formattedString ?? 0.0)
        
        //        var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
        let idhs = InsulinDeliveryHistorySingleton.shared
        let insulinDeliveryTimeStamp = Date.now.timeIntervalSince1970
        let insulinDeliveryHistoryItem = InsulinDelivery(id: UUID(), timestamp: insulinDeliveryTimeStamp, insulinUnits: insulinDeliveryUnits, insulinType: UserDefaults.group.insulinTypeSelected.rawValue)
        idhs.insulinDeliveryHistory.append(insulinDeliveryHistoryItem)
        idhs.saveAndUpdateIOB()
        
        let messageToWatch: [String: Any] = ["content": "insulinDelivery",
                                             "timeStamp": insulinDeliveryTimeStamp,
                                             "units": insulinDeliveryUnits]
        sendMessagetoOther(message: messageToWatch)
        
        let units = String(format: "%.1f", insulinDeliveryUnits)
        let dialogString: IntentDialog = "Recorded \(units) units of insulin."
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result(
            dialog: dialogString,
            view: AddInsulinSnippetView(units: units)
        )
    }
    
    func sendMessagetoOther(message: [String: Any]) {
        WatchConnectivityManager.shared.sendMessageToPairedDevice(message)
    }
    
    
    
    
}

struct AddInsulinSnippetView: View {
    var units: String
    var body: some View {
        Text("Units recorded: \(units).")
            .accessibilityLabel("Insulin units recorded: \(units)")
    }
}

enum InsulinUnitsEnum: String, Codable, Sendable {
    case value0_5 = "0.5"
    case value1   = "1"
    case value1_5 = "1.5"
    case value2   = "2"
    case value2_5 = "2.5"
    case value3   = "3"
    case value3_5 = "3.5"
    case value4   = "4"
    case value4_5 = "4.5"
    case value5   = "5"
    case value5_5 = "5.5"
    case value6   = "6"
    case value6_5 = "6.5"
    case value7   = "7"
    case value7_5 = "7.5"
    case value8   = "8"
    case value8_5 = "8.5"
    case value9   = "9"
    case value9_5 = "9.5"
    case value10  = "10"
    case value10_5 = "10.5"
    case value11  = "11"
    case value11_5 = "11.5"
    case value12  = "12"
    case value12_5 = "12.5"
    case value13  = "13"
    case value13_5 = "13.5"
    case value14  = "14"
    case value14_5 = "14.5"
    case value15  = "15"
    case value15_5 = "15.5"
    case value16  = "16"
    case value16_5 = "16.5"
    case value17  = "17"
    case value17_5 = "17.5"
    case value18  = "18"
    case value18_5 = "18.5"
    case value19  = "19"
    case value19_5 = "19.5"
    case value20  = "20"
    case value20_5 = "20.5"
    case value21  = "21"
    case value21_5 = "21.5"
    case value22  = "22"
    case value22_5 = "22.5"
    case value23  = "23"
    case value23_5 = "23.5"
    case value24  = "24"
    case value24_5 = "24.5"
    case value25  = "25"
    case value25_5 = "25.5"
    case value26  = "26"
    case value26_5 = "26.5"
    case value27  = "27"
    case value27_5 = "27.5"
    case value28  = "28"
    case value28_5 = "28.5"
    case value29  = "29"
    case value29_5 = "29.5"
    case value30  = "30"
}

extension InsulinUnitsEnum: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(stringLiteral: "Insulin Units")
    
    static var caseDisplayRepresentations: [InsulinUnitsEnum : DisplayRepresentation] = [
        .value0_5  : DisplayRepresentation(stringLiteral: "0.5"),
        .value1    : DisplayRepresentation(stringLiteral: "1"),
        .value1_5  : DisplayRepresentation(stringLiteral: "1.5"),
        .value2    : DisplayRepresentation(stringLiteral: "2"),
        .value2_5  : DisplayRepresentation(stringLiteral: "2.5"),
        .value3    : DisplayRepresentation(stringLiteral: "3"),
        .value3_5  : DisplayRepresentation(stringLiteral: "3.5"),
        .value4    : DisplayRepresentation(stringLiteral: "4"),
        .value4_5  : DisplayRepresentation(stringLiteral: "4.5"),
        .value5    : DisplayRepresentation(stringLiteral: "5"),
        .value5_5  : DisplayRepresentation(stringLiteral: "5.5"),
        .value6    : DisplayRepresentation(stringLiteral: "6"),
        .value6_5  : DisplayRepresentation(stringLiteral: "6.5"),
        .value7    : DisplayRepresentation(stringLiteral: "7"),
        .value7_5  : DisplayRepresentation(stringLiteral: "7.5"),
        .value8    : DisplayRepresentation(stringLiteral: "8"),
        .value8_5  : DisplayRepresentation(stringLiteral: "8.5"),
        .value9    : DisplayRepresentation(stringLiteral: "9"),
        .value9_5  : DisplayRepresentation(stringLiteral: "9.5"),
        .value10   : DisplayRepresentation(stringLiteral: "10"),
        .value10_5 : DisplayRepresentation(stringLiteral: "10.5"),
        .value11   : DisplayRepresentation(stringLiteral: "11"),
        .value11_5 : DisplayRepresentation(stringLiteral: "11.5"),
        .value12   : DisplayRepresentation(stringLiteral: "12"),
        .value12_5 : DisplayRepresentation(stringLiteral: "12.5"),
        .value13   : DisplayRepresentation(stringLiteral: "13"),
        .value13_5 : DisplayRepresentation(stringLiteral: "13.5"),
        .value14   : DisplayRepresentation(stringLiteral: "14"),
        .value14_5 : DisplayRepresentation(stringLiteral: "14.5"),
        .value15   : DisplayRepresentation(stringLiteral: "15"),
        .value15_5 : DisplayRepresentation(stringLiteral: "15.5"),
        .value16   : DisplayRepresentation(stringLiteral: "16"),
        .value16_5 : DisplayRepresentation(stringLiteral: "16.5"),
        .value17   : DisplayRepresentation(stringLiteral: "17"),
        .value17_5 : DisplayRepresentation(stringLiteral: "17.5"),
        .value18   : DisplayRepresentation(stringLiteral: "18"),
        .value18_5 : DisplayRepresentation(stringLiteral: "18.5"),
        .value19   : DisplayRepresentation(stringLiteral: "19"),
        .value19_5 : DisplayRepresentation(stringLiteral: "19.5"),
        .value20   : DisplayRepresentation(stringLiteral: "20"),
        .value20_5 : DisplayRepresentation(stringLiteral: "20.5"),
        .value21   : DisplayRepresentation(stringLiteral: "21"),
        .value21_5 : DisplayRepresentation(stringLiteral: "21.5"),
        .value22   : DisplayRepresentation(stringLiteral: "22"),
        .value22_5 : DisplayRepresentation(stringLiteral: "22.5"),
        .value23   : DisplayRepresentation(stringLiteral: "23"),
        .value23_5 : DisplayRepresentation(stringLiteral: "23.5"),
        .value24   : DisplayRepresentation(stringLiteral: "24"),
        .value24_5 : DisplayRepresentation(stringLiteral: "24.5"),
        .value25   : DisplayRepresentation(stringLiteral: "25"),
        .value25_5 : DisplayRepresentation(stringLiteral: "25.5"),
        .value26   : DisplayRepresentation(stringLiteral: "26"),
        .value26_5 : DisplayRepresentation(stringLiteral: "26.5"),
        .value27   : DisplayRepresentation(stringLiteral: "27"),
        .value27_5 : DisplayRepresentation(stringLiteral: "27.5"),
        .value28   : DisplayRepresentation(stringLiteral: "28"),
        .value28_5 : DisplayRepresentation(stringLiteral: "28.5"),
        .value29   : DisplayRepresentation(stringLiteral: "29"),
        .value29_5 : DisplayRepresentation(stringLiteral: "29.5"),
        .value30   : DisplayRepresentation(stringLiteral: "30"),
    ]
    
    static var allCases: [InsulinUnitsEnum] = [
        .value0_5,
        .value1,
        .value1_5,
        .value2,
        .value2_5,
        .value3,
        .value3_5,
        .value4,
        .value4_5,
        .value5,
        .value5_5,
        .value6,
        .value6_5,
        .value7,
        .value7_5,
        .value8,
        .value8_5,
        .value9,
        .value9_5,
        .value10,
        .value10_5,
        .value11,
        .value11_5,
        .value12,
        .value12_5,
        .value13,
        .value13_5,
        .value14,
        .value14_5,
        .value15,
        .value15_5,
        .value16,
        .value16_5,
        .value17,
        .value17_5,
        .value18,
        .value18_5,
        .value19,
        .value19_5,
        .value20,
        .value20_5,
        .value21,
        .value21_5,
        .value22,
        .value22_5,
        .value23,
        .value23_5,
        .value24,
        .value24_5,
        .value25,
        .value25_5,
        .value26,
        .value26_5,
        .value27,
        .value27_5,
        .value28,
        .value28_5,
        .value29,
        .value29_5,
        .value30
    ]
}


