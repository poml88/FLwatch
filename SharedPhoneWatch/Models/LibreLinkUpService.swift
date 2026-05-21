//
//  LibreLinkUpService.swift
//  LibreWrist
//
//  Created by Peter Müller on 24.02.26.
//

import Foundation
import SwiftUI
import OSLog

extension Notification.Name {
    static let libreWristDataDidChange = Notification.Name("LibreWristDataDidChange")
}

enum LibreWristUpdateNotifier {
    static func postDataDidChange() {
        NotificationCenter.default.post(name: .libreWristDataDidChange, object: nil)
    }
}

@MainActor
final class LibreLinkUpService: ObservableObject {
    static let shared = LibreLinkUpService()
    private static let peerReloadWaitTimeout: TimeInterval = 15
    private static let recentReloadWindowNanoseconds: UInt64 = 300_000_000
#if os(watchOS)
    private static let watchReloadStartDelaySeconds: TimeInterval = 1
#endif

    private let gate = ReloadGate()
    private(set) var activeProvider: CGMProvider = CGMProviderRegistry.makeProvider(for: SharedData.cgmProviderKind)

    @Published var isReloading = false
    @Published private(set) var libreLinkUpResponse = "[...]"
    @Published private(set) var didLastReloadFail = false

    /// Switches the active CGM backend. Decision 7.1: this is a "disconnect"
    /// from the user's perspective, identical to clearing credentials. Cached
    /// `LibreLinkUpHistory` is left in place — it'll be overwritten on the
    /// next successful reload by the new provider, so any stale-data window
    /// is brief.
    ///
    /// Kept free of platform-specific plumbing on purpose: iOS callers that
    /// want the watch to follow the new provider immediately should call
    /// `WatchConnectivityManager.shared.sendSettingsSnapshotToWatch()`
    /// themselves after this (Settings + first-launch picker already do).
    func switchProvider(to kind: CGMProviderKind) {
        SharedData.cgmProviderKind = kind
        UserDefaults.group.connected = .disconnected
        activeProvider = CGMProviderRegistry.makeProvider(for: kind)
        Logger.libreLinkUpService.info("switched active provider to \(kind.rawValue, privacy: .public)")
    }

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

    /// NOTE: unused - probably obsolete
    func hasFreshReading(maxAgeMinutes: Int? = nil, now: Date = Date()) -> Bool {
        let minutes = maxAgeMinutes ?? activeProvider.cadenceMinutes
        return now.timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate) < Double(minutes * 60)
    }

    private func canReload() -> Bool {
        let connected = UserDefaults.group.connected
        return connected == .connected
    }

    /// True when a fetch can be skipped because the cached reading is younger
    /// than `maxAgeMinutes` plus the provider's upload-propagation grace. Only
    /// providers that opt into `reloadThrottleByReadingAge` use this; for
    /// everyone else it's always false so the conventional call-age throttle
    /// takes over.
    ///
    /// Checked twice in `requestReloadIfNeeded` — once before the gate and once
    /// inside the lease — because a peer process may refresh the cache while we
    /// wait on the gate. `context` distinguishes the two in the log.
    private func hasFreshEnoughReading(maxAgeMinutes: Int, force: Bool, context: String) -> Bool {
        guard !force, activeProvider.reloadThrottleByReadingAge else { return false }
        let lastReadingAge = Date().timeIntervalSince(LibreLinkUpHistory.shared.lastReadingDate)
        let thresholdSeconds = Double(maxAgeMinutes * 60) + activeProvider.reloadThrottleGraceSeconds
        guard lastReadingAge < thresholdSeconds else { return false }
        Logger.libreLinkUpService.info("requestReloadIfNeeded skipped \(context, privacy: .public): cached reading is \(Int(lastReadingAge))s old (threshold \(Int(thresholdSeconds))s); no network call")
        return true
    }

    /// Awaitable: returns when either (a) no reload was needed, or (b) the reload finished.
    ///
    /// `maxAgeMinutes == nil` (default) means "use the active provider's
    /// cadence" — i.e. don't refetch if we already pulled within one cadence
    /// window. Callers can still pass an explicit value to override.
    @discardableResult
    func requestReloadIfNeeded(maxAgeMinutes: Int? = nil, force: Bool = false) async -> Bool {
        let maxAgeMinutes = maxAgeMinutes ?? activeProvider.cadenceMinutes
        Logger.libreLinkUpService.info("requestReloadIfNeeded called (maxAgeMinutes: \(maxAgeMinutes), force: \(force))")

#if os(watchOS)
        // Only delay when WC has plausibly delivered within one cadence window
        // (i.e. data isn't yet stale), so an in-flight snapshot can land before
        // we check the throttle. Scales with the provider: Libre 3 min, Dexcom
        // 8 min — a fixed window would treat an active Dexcom feed (≤5-min
        // cadence) as quiet between snapshots.
        if Self.watchReloadStartDelaySeconds > 0,
           Date().timeIntervalSince(SharedData.watchPeerSnapshotLastReceivedDate) <= activeProvider.staleReadingAfter {
            Logger.libreLinkUpService.info("requestReloadIfNeeded delaying start by \(Self.watchReloadStartDelaySeconds, privacy: .public)s")
            let delayNanoseconds = UInt64(Self.watchReloadStartDelaySeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
#endif

        let baselineUpdatedAt = LibreLinkUpHistory.shared.updatedAt
        let baselineLastReadingDate = LibreLinkUpHistory.shared.lastReadingDate
        
        _ = self.refreshHistoryFromPersistence()
        _ = self.refreshSensorSettingsFromPersistence()
        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()

        // Reading-age throttle (Dexcom: skip the fetch entirely when we
        // already have a reading younger than the source cadence). Libre
        // keeps the conventional call-age throttle below.
        if hasFreshEnoughReading(maxAgeMinutes: maxAgeMinutes, force: force, context: "before lease") {
            return false
        }

        if !force,
           await self.consumeRecentSuccessfulPeerResultIfAvailable(maxAgeMinutes: maxAgeMinutes) {
            return false
        }

        return await gate.runOrJoin(
            op: { [weak self] in
            guard let self else { return false }
            let secondsSinceLastSuccessfulAPICall = Date().timeIntervalSince(LibreLinkUpHistory.shared.lastSuccessfulLibreLinkUpAPICall)
            Logger.libreLinkUpService.info("requestReloadIfNeeded refreshed persisted snapshot before checks (secondsSinceLastSuccessfulAPICall: \(String(format: "%.1f", secondsSinceLastSuccessfulAPICall)))")

            guard self.canReload() else {
                Logger.libreLinkUpService.info("requestReloadIfNeeded skipped: not connected (state: \(UserDefaults.group.connected.rawValue))")
                return false
            }
            // Re-check reading-age inside the lease — a peer process may have
            // refreshed the cache while we were waiting on the gate.
            if self.hasFreshEnoughReading(maxAgeMinutes: maxAgeMinutes, force: force, context: "after lease") {
                return false
            }
            if !force,
               await self.consumeRecentSuccessfulPeerResultIfAvailable(maxAgeMinutes: maxAgeMinutes) {
                return false
            }
            self.isReloading = true
            defer { self.isReloading = false }

            Logger.libreLinkUpService.info("requestReloadIfNeeded starting network reload via \(self.activeProvider.kind.rawValue, privacy: .public) provider")
            await self.activeProvider.reload()
            self.libreLinkUpResponse = self.activeProvider.lastReloadResponseMessage
            self.didLastReloadFail = self.activeProvider.lastReloadDidFail
            if self.didLastReloadFail {
                await self.gate.recordCompletion(
                    succeeded: false,
                    lastReadingDate: LibreLinkUpHistory.shared.lastReadingDate,
                    historyUpdatedAt: LibreLinkUpHistory.shared.updatedAt
                )
                Logger.libreLinkUpService.error("requestReloadIfNeeded completed with failure")
            } else {
                LibreLinkUpHistory.shared.updateLastSuccessfulLibreLinkUpAPICall()
                await self.gate.recordCompletion(
                    succeeded: true,
                    lastReadingDate: LibreLinkUpHistory.shared.lastReadingDate,
                    historyUpdatedAt: LibreLinkUpHistory.shared.updatedAt
                )
                Logger.libreLinkUpService.info("requestReloadIfNeeded completed successfully")
            }
            LibreWristUpdateNotifier.postDataDidChange()
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

    private func consumeRecentSuccessfulPeerResultIfAvailable(maxAgeMinutes: Int) async -> Bool {
        guard let recentStatus = await self.gate.recentSuccessfulCompletion(maxAgeMinutes: maxAgeMinutes) else {
            return false
        }

        _ = self.refreshHistoryFromPersistence(force: true)
        _ = self.refreshSensorSettingsFromPersistence(force: true)
        let history = LibreLinkUpHistory.shared
        if history.lastReadingDate >= recentStatus.lastReadingDate || history.updatedAt >= recentStatus.historyUpdatedAt {
            let age = Date().timeIntervalSince(recentStatus.startedAt)
            Logger.libreLinkUpService.info("requestReloadIfNeeded skipped: peer reload started \(String(format: "%.1f", age))s ago and newer data is already persisted")
            return true
        }

        Logger.libreLinkUpService.info("requestReloadIfNeeded found recent successful reload status but persisted history has not advanced yet; waiting briefly before re-checking")
        try? await Task.sleep(nanoseconds: Self.recentReloadWindowNanoseconds)
        _ = self.refreshHistoryFromPersistence(force: true)
        _ = self.refreshSensorSettingsFromPersistence(force: true)
        if LibreLinkUpHistory.shared.lastReadingDate >= recentStatus.lastReadingDate
            || LibreLinkUpHistory.shared.updatedAt >= recentStatus.historyUpdatedAt {
            Logger.libreLinkUpService.info("requestReloadIfNeeded observed fresh persisted data after brief post-status wait")
            return true
        }

        return false
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
                LibreWristUpdateNotifier.postDataDidChange()
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

    struct ReloadStatusSnapshot: Codable {
        let startedAt: Date
        let finishedAt: Date?
        let succeeded: Bool?
        let lastReadingDate: Date
        let historyUpdatedAt: Date
    }

    private enum LeaseClaimResult {
        case acquired(LeaseSnapshot)
        case heldByPeer
    }

    private let ownerID = UUID().uuidString

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

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
              confirmedLease.ownerID == ownerID else {
            Logger.libreLinkUpService.info("ReloadGate: lease claim lost to peer process")
            return .heldByPeer
        }

        do {
            try writeStatus(
                ReloadStatusSnapshot(
                    startedAt: now,
                    finishedAt: nil,
                    succeeded: nil,
                    lastReadingDate: .distantPast,
                    historyUpdatedAt: .distantPast
                )
            )
        } catch {
            Logger.libreLinkUpService.error("ReloadGate failed to persist in-flight reload status")
        }

        return .acquired(confirmedLease)
    }

    private func releaseLeaseIfOwned(_ lease: LeaseSnapshot) {
        do {
            guard let currentLease = try readLease(),
                  currentLease.ownerID == lease.ownerID else {
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

    func recordCompletion(
        succeeded: Bool,
        lastReadingDate: Date,
        historyUpdatedAt: Date,
        finishedAt: Date = Date()
    ) {
        do {
            let existingStatus = try readStatus()
            let startedAt = existingStatus?.startedAt ?? finishedAt
            try writeStatus(
                ReloadStatusSnapshot(
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    succeeded: succeeded,
                    lastReadingDate: lastReadingDate,
                    historyUpdatedAt: historyUpdatedAt
                )
            )
        } catch {
            Logger.libreLinkUpService.error("ReloadGate failed to persist reload completion status")
        }
    }

    func recentSuccessfulCompletion(maxAgeMinutes: Int, now: Date = Date()) -> ReloadStatusSnapshot? {
        do {
            guard let status = try readStatus(),
                  status.succeeded == true,
                  now.timeIntervalSince(status.startedAt) < Double(maxAgeMinutes * 60) else {
                return nil
            }
            return status
        } catch {
            Logger.libreLinkUpService.error("ReloadGate failed to read reload status")
            return nil
        }
    }

    private func readStatus() throws -> ReloadStatusSnapshot? {
        try FileStoreIO.readSnapshot(
            ReloadStatusSnapshot.self,
            from: statusFileURL(),
            using: decoder,
            fileManager: fileManager
        )
    }

    private func writeStatus(_ status: ReloadStatusSnapshot) throws {
        _ = try FileStoreIO.writeSnapshot(
            status,
            to: statusFileURL(),
            using: encoder,
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

    private func statusFileURL() -> URL {
        FileStoreIO.makeStoreURL(
            fileName: "librelinkup-reload-status.json",
            using: fileManager,
            appGroupID: SharedDefaults.appGroupID
        )
    }
}
