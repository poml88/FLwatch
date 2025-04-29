//
//  AppShortcuts.swift
//  LibreWrist
//
//  Created by Peter Müller on 25.04.25.
//

import Foundation
import AppIntents

class FLwatchShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .yellow
//    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadGlucose(),
            phrases: [
                "What is my glucose in \(.applicationName)",
                "What's my glucose in \(.applicationName)",
                "What is my glucose level in \(.applicationName)",
                "What's my glucose level in \(.applicationName)",
                "What is my \(.applicationName) glucose",
                "What's my \(.applicationName) glucose",
                "What is my \(.applicationName) glucose level",
                "What's my \(.applicationName) glucose level",
          ],
            shortTitle: "Blood Glucose",
            systemImageName: "drop"
        )
    
        AppShortcut(
            intent: AddInsulin(),
            phrases: [
                "\(.applicationName) record insulin",
                "\(.applicationName) note insulin",
                "\(.applicationName) add insulin",
                "\(\.$insulinUnitsEnum) insulin units in \(.applicationName)",
                "\(.applicationName) \(\.$insulinUnitsEnum) unit",
                "\(.applicationName) \(\.$insulinUnitsEnum) units",
                "\(\.$insulinUnitsEnum) unit \(.applicationName)",
                "\(\.$insulinUnitsEnum) units \(.applicationName)",
            ],
            shortTitle: "Add insulin",
            systemImageName: "syringe"
        )
    }
}

