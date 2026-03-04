//
//  LibreLinkUpService.swift
//  LibreWrist
//
//  Created by Peter Müller on 24.02.26.
//

import SwiftUI

@MainActor
final class LibreLinkUpService: ObservableObject {
    static let shared = LibreLinkUpService()

    private let gate = ReloadGate()
    private let libreLinkUp = LibreLinkUp()

    @Published var isReloading = false
    @Published private(set) var libreLinkUpResponse = "[...]"
    @Published private(set) var didLastReloadFail = false

    /// Awaitable: returns when either (a) no reload was needed, or (b) the reload finished.
    func requestReloadIfNeeded() async {
        // We do NOT create a Task here — the caller decides whether to spawn one.
        await gate.run { [weak self] in
            guard let self else { return }

            // Conditions checked INSIDE the gate
            let connected = UserDefaults.group.connected
            let minutes = Int(Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) / 60)
            guard minutes >= 1,
                  connected == .connected || connected == .newlyConnected else { return }
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            await MainActor.run { self.isReloading = true }
                        defer { Task { @MainActor in self.isReloading = false } }

            await self.libreLinkUp.reloadLibreLinkUp()
            await MainActor.run {
                self.libreLinkUpResponse = self.libreLinkUp.libreLinkUpResponse
                self.didLastReloadFail = self.libreLinkUp.libreLinkUpErrorBool
            }
#if os(iOS)
//            WatchConnectivityManager.shared.sendLibreLinkUpSnapshotToWatch()
#endif
        }
    }
}

actor ReloadGate {
    private var isRunning = false

    func run(_ op: @Sendable () async -> Void) async {
        guard !isRunning else { return }   // drop if already running
        isRunning = true
        defer { isRunning = false }
        await op()
    }
}
