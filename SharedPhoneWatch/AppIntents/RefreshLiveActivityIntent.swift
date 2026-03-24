//
//  RefreshLiveActivityIntent.swift
//  LibreWrist
//
//  Created by Peter Müller on 11.03.26.
//

import AppIntents
import WidgetKit


struct RefreshLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Refresh Live Activity"
    static var description = IntentDescription("Reload the Live Activity.")
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await LibreLinkUpService.shared.requestReloadIfNeeded()
        await LiveActivityManager.shared.refreshFromCurrentHistory(
            useLiveActivities: SharedData.useLiveActivities,
            reloadFailed: LibreLinkUpService.shared.didLastReloadFail
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
