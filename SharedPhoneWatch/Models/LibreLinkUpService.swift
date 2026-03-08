//
//  LibreLinkUpService.swift
//  LibreWrist
//
//  Created by Peter Müller on 24.02.26.
//

import SwiftUI
import Darwin
import OSLog

@MainActor
final class LibreLinkUpService: ObservableObject {
    static let shared = LibreLinkUpService()

    private let gate = ReloadGate()
    private let libreLinkUp = LibreLinkUp()

    @Published var isReloading = false
    @Published private(set) var libreLinkUpResponse = "[...]"
    @Published private(set) var didLastReloadFail = false

    /// Refreshes history from the persisted snapshot on MainActor.
    @discardableResult
    func refreshHistoryFromPersistence() -> Bool {
        LibreLinkUpHistory.shared.refreshFromPersistedSnapshot()
    }

    @discardableResult
    func refreshSensorSettingsFromPersistence(force: Bool = false) -> Bool {
        SensorSettingsStore.shared.refreshFromPersistence(force: force)
    }

    /// Convenience for non-MainActor contexts (widgets/intents) to refresh via the centralized service API.
    @discardableResult
    nonisolated static func refreshHistoryFromPersistenceAsync() async -> Bool {
        await MainActor.run {
            LibreLinkUpService.shared.refreshHistoryFromPersistence()
        }
    }

    func hasRecentOnlineCall(maxAgeMinutes: Int = 1, now: Date = Date()) -> Bool {
        now.timeIntervalSince(LibreLinkUpHistory.shared.lastOnlineDate) < Double(maxAgeMinutes * 60)
    }

    private func canReload() -> Bool {
        let connected = UserDefaults.group.connected
        return connected == .connected || connected == .newlyConnected
    }

    /// Awaitable: returns when either (a) no reload was needed, or (b) the reload finished.
    @discardableResult
    func requestReloadIfNeeded(maxAgeMinutes: Int = 1, force: Bool = false) async -> Bool {
        Logger.libreLinkUpService.info("requestReloadIfNeeded called (maxAgeMinutes: \(maxAgeMinutes), force: \(force))")

        return await gate.runOrJoin { [weak self] in
            guard let self else { return false }
            _ = self.refreshHistoryFromPersistence()
            _ = self.refreshSensorSettingsFromPersistence()
            let secondsSinceLastOnline = Date().timeIntervalSince(LibreLinkUpHistory.shared.lastOnlineDate)
            Logger.libreLinkUpService.info("requestReloadIfNeeded refreshed persisted snapshot before checks (secondsSinceLastOnline: \(String(format: "%.1f", secondsSinceLastOnline)))")
            guard self.canReload() else {
                Logger.libreLinkUpService.info("requestReloadIfNeeded skipped: not connected (state: \(UserDefaults.group.connected.rawValue))")
                return false
            }
            guard force || !self.hasRecentOnlineCall(maxAgeMinutes: maxAgeMinutes) else {
                let age = Date().timeIntervalSince(LibreLinkUpHistory.shared.lastOnlineDate)
                Logger.libreLinkUpService.info("requestReloadIfNeeded skipped: recent online call \(String(format: "%.1f", age))s ago (throttle: \(maxAgeMinutes * 60)s)")
                return false
            }

            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
            self.isReloading = true
            defer { self.isReloading = false }

            LibreLinkUpHistory.shared.lastOnlineDate = Date()
            Logger.libreLinkUpService.info("requestReloadIfNeeded starting network reload")
            await self.libreLinkUp.reloadLibreLinkUp()
            self.libreLinkUpResponse = self.libreLinkUp.libreLinkUpResponse
            self.didLastReloadFail = self.libreLinkUp.libreLinkUpErrorBool
            if self.didLastReloadFail {
                Logger.libreLinkUpService.error("requestReloadIfNeeded completed with failure")
            } else {
                Logger.libreLinkUpService.info("requestReloadIfNeeded completed successfully")
            }
#if os(iOS)
//            WatchConnectivityManager.shared.sendLibreLinkUpSnapshotToWatch()
#endif
            return true
        }
    }
}

actor ReloadGate {
    private var inFlightTask: Task<Bool, Never>?
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist", category: "ReloadGate")

    func runOrJoin(_ op: @escaping @MainActor @Sendable () async -> Bool) async -> Bool {
        if let inFlightTask {
            Logger.libreLinkUpService.info("ReloadGate: joining existing in-flight reload task")
            return await inFlightTask.value
        }

        let task = Task {
            await runWithInterprocessLock(op)
        }
        inFlightTask = task
        let result = await task.value
        inFlightTask = nil
        return result
    }

    private func runWithInterprocessLock(_ op: @escaping @MainActor @Sendable () async -> Bool) async -> Bool {
        do {
            let fd = try await Self.acquireLockFileDescriptor()
            defer { Self.releaseLockFileDescriptor(fd) }
            return await op()
        } catch {
            // Fallback to in-process gating if the shared lock cannot be created.
            return await op()
        }
    }

    private static func lockFileURL() -> URL {
        if let appGroupID = SharedDefaults.appGroupID,
           let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return containerURL.appendingPathComponent("librelinkup-reload.lock")
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("librelinkup-reload.lock")
    }

    private static func acquireLockFileDescriptor() async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let lockFilePath = lockFileURL().path
            DispatchQueue.global(qos: .utility).async {
                let fd = open(lockFilePath, O_CREAT | O_RDWR, 0o666)
                guard fd >= 0 else {
                    continuation.resume(throwing: NSError(domain: "ReloadGateLock", code: Int(errno)))
                    return
                }

                guard flock(fd, LOCK_EX) == 0 else {
                    let lockErrno = errno
                    close(fd)
                    continuation.resume(throwing: NSError(domain: "ReloadGateLock", code: Int(lockErrno)))
                    return
                }

                continuation.resume(returning: fd)
            }
        }
    }

    private static func releaseLockFileDescriptor(_ fd: Int32) {
        _ = flock(fd, LOCK_UN)
        close(fd)
    }
}
