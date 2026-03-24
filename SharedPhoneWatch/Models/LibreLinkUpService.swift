//
//  LibreLinkUpService.swift
//  LibreWrist
//
//  Created by Peter Müller on 24.02.26.
//

import Foundation
import SwiftUI
import OSLog

@MainActor
final class LibreLinkUpService: ObservableObject {
    static let shared = LibreLinkUpService()
    private static let peerReloadWaitTimeout: TimeInterval = 15

    private let gate = ReloadGate()
    private let libreLinkUp = LibreLinkUp()

    @Published var isReloading = false
    @Published private(set) var libreLinkUpResponse = "[...]"
    @Published private(set) var didLastReloadFail = false

    /// Refreshes history from the persisted snapshot on MainActor.
    @discardableResult
    func refreshHistoryFromPersistence(force: Bool = false) -> Bool {
        LibreLinkUpHistory.shared.refreshFromPersistence(force: force)
    }

    @discardableResult
    func refreshSensorSettingsFromPersistence(force: Bool = false) -> Bool {
        SensorSettingsStore.shared.refreshFromPersistence(force: force)
    }

    /// Convenience for non-MainActor contexts (widgets/intents) to refresh via the centralized service API.
    @discardableResult
    nonisolated static func refreshHistoryFromPersistenceAsync(force: Bool = false) async -> Bool {
        await MainActor.run {
            LibreLinkUpService.shared.refreshHistoryFromPersistence(force: force)
        }
    }

    func hasRecentReloadAttempt(maxAgeMinutes: Int = 1, now: Date = Date()) -> Bool {
        now.timeIntervalSince(LibreLinkUpHistory.shared.lastReloadAttemptDate) < Double(maxAgeMinutes * 60)
    }

    func hasFreshReading(maxAgeMinutes: Int = 1, now: Date = Date()) -> Bool {
        now.timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) < Double(maxAgeMinutes * 60)
    }

    private func canReload() -> Bool {
        let connected = UserDefaults.group.connected
        return connected == .connected
    }

    /// Awaitable: returns when either (a) no reload was needed, or (b) the reload finished.
    @discardableResult
    func requestReloadIfNeeded(maxAgeMinutes: Int = 1, force: Bool = false) async -> Bool {
        Logger.libreLinkUpService.info("requestReloadIfNeeded called (maxAgeMinutes: \(maxAgeMinutes), force: \(force))")

        let baselineUpdatedAt = LibreLinkUpHistory.shared.updatedAt
        let baselineLastReadingDate = LibreLinkUpHistory.shared.lastReadingDate
        
        _ = self.refreshHistoryFromPersistence()
        _ = self.refreshSensorSettingsFromPersistence()
        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()

        return await gate.runOrJoin(
            op: { [weak self] in
            guard let self else { return false }
            
            let secondsSinceLastAttempt = Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReloadAttemptDate)
            let secondsSinceLastSuccessfulAPICall = Date().timeIntervalSince(LibreLinkUpHistory.shared.lastSuccessfulLibreLinkUpAPICall)
            Logger.libreLinkUpService.info("requestReloadIfNeeded refreshed persisted snapshot before checks (secondsSinceLastAttempt: \(String(format: "%.1f", secondsSinceLastAttempt)), secondsSinceLastSuccessfulAPICall: \(String(format: "%.1f", secondsSinceLastSuccessfulAPICall)))")

            guard self.canReload() else {
                Logger.libreLinkUpService.info("requestReloadIfNeeded skipped: not connected (state: \(UserDefaults.group.connected.rawValue))")
                return false
            }
            guard force || !self.hasRecentReloadAttempt(maxAgeMinutes: maxAgeMinutes) else {
                let age = Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReloadAttemptDate)
                Logger.libreLinkUpService.info("requestReloadIfNeeded skipped: last API attempt was \(String(format: "%.1f", age))s ago (throttle: \(maxAgeMinutes * 60)s)")
                return false
            }
            self.isReloading = true
            defer { self.isReloading = false }

            LibreLinkUpHistory.shared.updateLastReloadAttemptDate()
            Logger.libreLinkUpService.info("requestReloadIfNeeded starting network reload")
            await self.libreLinkUp.reloadLibreLinkUp()
            self.libreLinkUpResponse = self.libreLinkUp.libreLinkUpResponse
            self.didLastReloadFail = self.libreLinkUp.libreLinkUpErrorBool
            if self.didLastReloadFail {
                Logger.libreLinkUpService.error("requestReloadIfNeeded completed with failure")
            } else {
                LibreLinkUpHistory.shared.updateLastSuccessfulLibreLinkUpAPICall()
                Logger.libreLinkUpService.info("requestReloadIfNeeded completed successfully")
            }
#if os(iOS)
//            WatchConnectivityManager.shared.sendLibreLinkUpSnapshotToWatch()
#endif
            return true
            },
            waitForPeerResult: { [weak self] in
                guard let self else { return false }
                return await self.waitForPeerReloadResult(
                    baselineUpdatedAt: baselineUpdatedAt,
                    baselineLastReadingDate: baselineLastReadingDate,
                    timeout: Self.peerReloadWaitTimeout
                )
            }
        )
    }

    private func waitForPeerReloadResult(
        baselineUpdatedAt: Date,
        baselineLastReadingDate: Date,
        timeout: TimeInterval,
        pollIntervalNanoseconds: UInt64 = 300_000_000
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if Task.isCancelled {
                return false
            }

            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)

            _ = refreshHistoryFromPersistence(force: true)
            _ = refreshSensorSettingsFromPersistence(force: true)

            let history = LibreLinkUpHistory.shared
            if history.updatedAt > baselineUpdatedAt || history.lastReadingDate > baselineLastReadingDate {
                Logger.libreLinkUpService.info("requestReloadIfNeeded observed fresh persisted data from peer process")
                return true
            }
        }

        Logger.libreLinkUpService.info("requestReloadIfNeeded timed out waiting for peer process reload result")
        return false
    }
}

actor ReloadGate {
    private var inFlightTask: Task<Bool, Never>?
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let leaseDuration: TimeInterval = 15

    private struct LeaseSnapshot: Codable {
        let ownerID: String
        let acquiredAt: Date
        let expiresAt: Date
    }

    private enum LeaseClaimResult {
        case acquired(LeaseSnapshot)
        case heldByPeer
    }

    private let ownerID = UUID().uuidString

    func runOrJoin(
        op: @escaping @MainActor @Sendable () async -> Bool,
        waitForPeerResult: @escaping @MainActor @Sendable () async -> Bool
    ) async -> Bool {
        if let inFlightTask {
            Logger.libreLinkUpService.info("ReloadGate: joining existing in-flight reload task")
            return await inFlightTask.value
        }

        let task = Task {
            await runWithInterprocessLease(op: op, waitForPeerResult: waitForPeerResult)
        }
        inFlightTask = task
        let result = await task.value
        inFlightTask = nil
        return result
    }

    private func runWithInterprocessLease(
        op: @escaping @MainActor @Sendable () async -> Bool,
        waitForPeerResult: @escaping @MainActor @Sendable () async -> Bool
    ) async -> Bool {
        do {
            switch try claimLease() {
            case let .acquired(lease):
                defer { releaseLeaseIfOwned(lease) }
                return await op()
            case .heldByPeer:
                if await waitForPeerResult() {
                    return true
                }

                switch try claimLease() {
                case let .acquired(lease):
                    defer { releaseLeaseIfOwned(lease) }
                    return await op()
                case .heldByPeer:
                    return false
                }
            }
        } catch {
            Logger.libreLinkUpService.error("ReloadGate coordination failed; falling back to in-process gating only")
            return await op()
        }
    }

    private func claimLease(now: Date = Date()) throws -> LeaseClaimResult {
        if let currentLease = try readLease(),
           currentLease.ownerID != ownerID,
           currentLease.expiresAt > now {
            Logger.libreLinkUpService.info("ReloadGate: peer process already owns reload lease until \(currentLease.expiresAt.formatted(date: .omitted, time: .standard), privacy: .public)")
            return .heldByPeer
        }

        let nextLease = LeaseSnapshot(
            ownerID: ownerID,
            acquiredAt: now,
            expiresAt: now.addingTimeInterval(Self.leaseDuration)
        )
        _ = try FileStoreIO.writeSnapshot(
            nextLease,
            to: leaseFileURL(),
            using: encoder,
            fileManager: fileManager
        )

        guard let confirmedLease = try readLease(),
              confirmedLease.ownerID == ownerID,
              confirmedLease.acquiredAt == nextLease.acquiredAt else {
            Logger.libreLinkUpService.info("ReloadGate: lease claim lost to peer process")
            return .heldByPeer
        }

        return .acquired(confirmedLease)
    }

    private func releaseLeaseIfOwned(_ lease: LeaseSnapshot) {
        do {
            guard let currentLease = try readLease(),
                  currentLease.ownerID == lease.ownerID,
                  currentLease.acquiredAt == lease.acquiredAt else {
                return
            }
            try fileManager.removeItem(at: leaseFileURL())
        } catch {
            Logger.libreLinkUpService.error("ReloadGate failed to release reload lease")
        }
    }

    private func readLease() throws -> LeaseSnapshot? {
        try FileStoreIO.readSnapshot(
            LeaseSnapshot.self,
            from: leaseFileURL(),
            using: decoder,
            fileManager: fileManager
        )
    }

    private func leaseFileURL() -> URL {
        FileStoreIO.makeStoreURL(
            fileName: "librelinkup-reload-lease.json",
            using: fileManager,
            appGroupID: SharedDefaults.appGroupID
        )
    }
}
