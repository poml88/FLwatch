//
//  WorkoutModeRefreshManager.swift
//  FLwatchWatchApp
//

import Foundation
import OSLog

/// Keeps cloud-backed glucose current while HealthKit grants workout runtime.
/// Direct BLE is push-driven and is deliberately never kicked from here.
@MainActor
final class WorkoutModeRefreshManager {
    static let shared = WorkoutModeRefreshManager()

    private let refreshInterval: Duration = .seconds(60)
    private var refreshTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "WorkoutModeRefreshManager"
    )

    private init() {}

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshNow(trigger: "workout-start")

            while !Task.isCancelled, WorkoutModeStore.shared.isActive {
                do {
                    try await Task.sleep(for: self.refreshInterval)
                } catch {
                    break
                }
                await self.refreshNow(trigger: "workout-minute")
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshNow(trigger: String) async {
        guard WorkoutModeStore.shared.isActive else { return }

        if !WorkoutModeStore.shared.providerKind.isDirectBLE {
            logger.debug("Running cloud workout refresh [\(trigger, privacy: .public)]")
            _ = await LibreLinkUpService.shared.requestReloadIfNeeded(maxAgeMinutes: 1)
        }
        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
    }
}
