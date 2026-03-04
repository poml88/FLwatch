//
//  ReadGlucose.swift
//  LibreWrist
//
//  Created by Peter Müller on 24.04.25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct ReadGlucose: AppIntent {
    static var title: LocalizedStringResource = "Get Current Blood Glucose"
    static var description: LocalizedStringResource = "Return the current blood glucose."
    
//    static var authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get the current blood glucose.") {
        }
    }
    
    @MainActor
    //    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        var dialogString: IntentDialog = "[...]"
        let libreLinkUp = LibreLinkUp()
        let gme = try await libreLinkUp.getLastGlucoseData()
        var glucose: String {
            if gme.glucoseMeasurement.value <= 0 {
                return "not available"
            } else if gme.glucoseMeasurement.glucoseUnits == 1 {
                return "\(Int(gme.glucoseMeasurement.value))"
            } else {
                return String(format: "%.1f", gme.glucoseMeasurement.value)
            }
        }
        let trend = gme.glucoseMeasurement.trendArrow?.descriptionSiri ?? "not determined"
        if glucose == "not available" {
            dialogString = "Your blood glucose value is currently not available."
        } else {
            if Int(Date().timeIntervalSince(gme.date) / 60) <= 3 {
                dialogString = "Your blood glucose is currently \(glucose) and \(trend)."
            } else {
                dialogString = "Sorry, there are no recent blood glucose values."
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetCenter.shared.reloadAllTimelines()")
        return .result(
            dialog: dialogString,
            view: ReadGlucoseView(glucose: glucose, trend: trend)
        )
    }
}
        

struct ReadGlucoseView: View {
    var glucose: String
    var trend: LocalizedStringResource
    var body: some View {
        Text("Current glucose: \(glucose). Trend: \(trend)")
    }
}



//struct OpenFavorites: AppIntent {
//    
//    static var title: LocalizedStringResource = "Open Favorite Trails"
//
//
//    static var description = IntentDescription("Opens the app and goes to your favorite trails.")
//    
//    static var openAppWhenRun: Bool = true
//    
//    @MainActor
//    func perform() async throws -> some IntentResult {
//        navigationModel.selectedCollection = trailManager.favoritesCollection
//        
//        return .result()
//    }
//    
//    @Dependency
//    private var navigationModel: NavigationModel
//    
//    @Dependency
//    private var trailManager: TrailDataManager
//}
//
//
//func perform() async throws -> some IntentResult & ReturnsValue<TrailEntity> & ProvidesDialog & ShowsSnippetView {
//    guard let trailData = trailManager.trail(with: trail.id) else {
//        throw TrailIntentError.trailNotFound
//    }
//            
//    /**
//     You provide a custom view by conforming the return type of the `perform()` function to the `ShowsSnippetView` protocol.
//     */
//    let snippet = TrailInfoView(trail: trailData, includeConditions: true)
//    
//    /**
//     This intent displays a custom view that includes the trail conditions as part of the view. The dialog includes the trail conditions when
//     the system can only read the response, but not display it. When the system can display the response, the dialog omits the trail
//     conditions.
//     */
//    let dialog = IntentDialog(full: "The latest conditions reported for \(trail.name) indicate: \(trail.currentConditions).",
//                              supporting: "Here's the latest information on trail conditions.")
//    
//    return .result(value: trail, dialog: dialog, view: snippet)
//}
