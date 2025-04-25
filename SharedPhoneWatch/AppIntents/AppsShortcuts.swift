//
//  AppShortcuts.swift
//  LibreWrist
//
//  Created by Peter Müller on 25.04.25.
//

import AppIntents

struct AppsShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
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
    }
}

