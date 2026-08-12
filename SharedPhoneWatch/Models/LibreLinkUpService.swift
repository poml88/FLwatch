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
    /// Posted by `DexcomShareProvider` after a successful re-authentication.
    /// `object` is the new sessionId (`String`). The iOS side of
    /// `WatchConnectivityManager` subscribes and forwards it to the watch so
    /// the watch widget's reload gate opens without waiting for the next
    /// settings-snapshot send. Kept here (not in WC manager) so the provider
    /// — which is compiled into widget targets that don't link WC — has no
    /// compile-time dependency on WC.
    static let dexcomShareSessionDidRefresh = Notification.Name("DexcomShareSessionDidRefresh")
    /// Posted by `LibreLinkUpService.switchProvider` after the active CGM
    /// provider changes. The phone-only `BluetoothHeartbeatManager` observes it
    /// to reconcile BLE ownership (stand down for `.libre3BLE`, re-arm for the
    /// cloud providers). Decoupled via NotificationCenter so this shared
    /// orchestrator — compiled into the watch and iOS widget targets, which
    /// don't include the heartbeat manager — has no compile-time dependency on
    /// it. Same rationale as `dexcomShareSessionDidRefresh` above.
    static let activeCGMProviderDidChange = Notification.Name("ActiveCGMProviderDidChange")

    /// Posted by the shared `Libre3DirectProvider.reload()` to ask the phone-only
    /// `Libre3DirectManager` to ensure it's connected. Decoupled via
    /// NotificationCenter (same rationale as `activeCGMProviderDidChange`) so the
    /// shared provider — compiled into the watch + widget targets, which don't
    /// link the BLE engine — never names the phone-only manager type.
    static let libre3DirectReloadRequested = Notification.Name("Libre3DirectReloadRequested")

    /// Posted after either retained Libre 3 diagnostics ring changes so an open
    /// developer-log view can refresh without polling.
    static let libre3DiagnosticsDidChange = Notification.Name("Libre3DiagnosticsDidChange")
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
    /// How recently a *successful* reload must have started for us to reuse its
    /// result instead of fetching again. This is a dedup/anti-hammer guard, not
    /// a cadence throttle — it stays at 60s for every provider so it never
    /// paces faster than once a minute. Cadence-aware pacing is the reading-age
    /// throttle's job (`hasFreshEnoughReading`); sizing this to the cadence is
    /// what made Dexcom drift a whole publish cycle behind the sensor.
    private static let peerReloadDedupeWindow: TimeInterval = 60
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

        // Reset the sensor type so it doesn't lag the new provider until the
        // first reload lands. For Dexcom we keep a previously chosen Dexcom
        // type (the user's picker selection) and otherwise default to G7;
        // for Libre we drop a stale Dexcom stamp to `.unknown` and let the
        // first LLU reload fill in the real model.
        let currentType = SensorSettingsStore.shared.sensorType
        switch kind {
        case .dexcomShare:
            if !currentType.isADexcom {
                _ = SensorSettingsStore.shared.updateSensorType(.dexcomG7)
            }
        case .libreLinkUp, .libre3BLE:
            // Drop a stale Dexcom stamp; the real Libre model fills in on the
            // first reading (cloud reload for LLU, connect-time stamp for BLE).
            if currentType.isADexcom {
                _ = SensorSettingsStore.shared.updateSensorType(.unknown)
            }
        }

        // Reconcile BLE ownership with the new provider. In `.libre3BLE` mode
        // `Libre3DirectManager` owns the sensor link, so the heartbeat central
        // must stand down (plan §4/§6); switching back to a cloud provider
        // re-arms it if the user had it enabled. Posted rather than called
        // directly: the phone app's `BluetoothHeartbeatManager` observes this,
        // keeping this shared type (built into the watch + iOS widget targets,
        // which don't include the manager) free of a compile-time dependency.
        NotificationCenter.default.post(name: .activeCGMProviderDidChange, object: nil)

        Logger.libreLinkUpService.info("switched active provider to \(kind.rawValue, privacy: .public)")
    }

    /// Rebuild `activeProvider` if it no longer matches the persisted
    /// `cgmProviderKind`. `switchProvider` mutates this instance directly, but
    /// only in the process that switched; every other process (widgets,
    /// intents, the watch app when the phone switched) must pick up the change
    /// from the app group. Cheap: only rebuilds on an actual kind mismatch.
    func syncActiveProviderWithPersistedKind() {
        let persisted = SharedData.cgmProviderKind
        guard activeProvider.kind != persisted else { return }
        activeProvider = CGMProviderRegistry.makeProvider(for: persisted)
        Logger.libreLinkUpService.info("activeProvider re-synced to persisted kind \(persisted.rawValue, privacy: .public)")
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
        // Reconcile with the persisted provider kind before doing anything.
        // `switchProvider` only runs in the app that performed the switch;
        // widget/intent extension processes (which WidgetKit keeps alive across
        // refreshes) hold a `shared` whose `activeProvider` was fixed at init.
        // Without this, after a provider switch such a process reloads via the
        // OLD provider and overwrites the shared history with the wrong source's
        // data — clobbering the app's correct graph minutes later.
        syncActiveProviderWithPersistedKind()
        let maxAgeMinutes = maxAgeMinutes ?? activeProvider.cadenceMinutes
        Logger.libreLinkUpService.info("requestReloadIfNeeded called (maxAgeMinutes: \(maxAgeMinutes), force: \(force))")

#if os(watchOS)
        // Brief grace so an in-flight WC glucose snapshot can land and update
        // the cache *before* we check the throttle — letting it skip a redundant
        // network fetch the watch would otherwise make.
        //
        // We gate it on "a snapshot arrived within `staleReadingAfter`" rather
        // than "just now", because that's the proxy for "the phone is actively
        // feeding us": the phone only pushes glucose snapshots from its BT
        // heartbeat / background execution, so a recent snapshot means that
        // pipeline is alive and another one is likely imminent. When it's alive
        // a watch-side network fetch is redundant anyway, so eating 1s to wait
        // for the snapshot is the right trade. The window scales with the
        // provider (Libre 3 min, Dexcom 8 min) so an active Dexcom feed isn't
        // treated as quiet between its ≤5-min snapshots.
        //
        // `watchPeerSnapshotLastReceivedDate` is persisted in the app group, so
        // it stays "recent" across launches. Consequence: in environments with
        // no heartbeat and no background execution (e.g. the Simulator) no
        // snapshots ever arrive, the window lapses, and this delay simply never
        // fires — which is why it's absent from Simulator logs.
        //
        // FUTURE (needs more thought — do NOT implement naively): it's tempting
        // to skip the watch's own network reload entirely while the phone feed
        // is alive, with an early `return` here when a snapshot arrived within
        // ~one cadence. DON'T gate that on `watchPeerSnapshotLastReceivedDate`:
        // that's the snapshot *receipt* time, not the reading's timestamp, and
        // the two diverge by the source's upload lag (Dexcom Share has been seen
        // ~240s behind). So "received within a cadence" does not imply "reading
        // is fresh" — at receipt+280s the reading can already be ~520s old, and
        // a receipt-time gate would suppress a fetch the data clearly needs.
        // This is the same receipt-vs-reading-time trap we removed from the
        // recent-success gate (#3). Worse, this timestamp is bumped even for
        // snapshots we *reject* as stale (it's set before the shouldApplySnapshot
        // guard), so it can arm on data we discarded.
        //
        // The safe, reading-anchored version of this idea is ALREADY what gate
        // #2 (`hasFreshEnoughReading`) does: it suppresses the network call
        // whenever the *reading* is fresh, using `lastReadingDate`, which WC
        // snapshots update. A receipt-time skip only differs from gate #2 in the
        // cases where it's wrong (reading actually stale; relay hiccup — exactly
        // when the watch's own fetch is the useful backstop). So there is most
        // likely nothing worth adding here; leave the 1s delay + gate #2 as-is.
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

        // Reading-age throttle: skip the fetch entirely when we already hold a
        // reading younger than the source cadence (+grace). This is the
        // cadence-aware pacer; the recent-success guard below is only a 60s
        // anti-hammer/dedup window, not a per-cadence throttle.
        if hasFreshEnoughReading(maxAgeMinutes: maxAgeMinutes, force: force, context: "before lease") {
            return false
        }

        if !force,
           await self.consumeRecentSuccessfulPeerResultIfAvailable() {
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
               await self.consumeRecentSuccessfulPeerResultIfAvailable() {
                return false
            }
            self.isReloading = true
            defer { self.isReloading = false }

            Logger.libreLinkUpService.info("requestReloadIfNeeded starting network reload via \(self.activeProvider.kind.rawValue, privacy: .public) provider")
            await self.activeProvider.reload()
            // Both home views observe this service, and `ObservableObject` has no
            // per-property granularity, so re-publishing an identical response
            // string rebuilt them for nothing on every reload. `isReloading` above
            // is left ungated on purpose — it genuinely toggles each cycle.
            let reloadResponse = self.activeProvider.lastReloadResponseMessage
            if self.libreLinkUpResponse != reloadResponse {
                self.libreLinkUpResponse = reloadResponse
            }
            let reloadDidFail = self.activeProvider.lastReloadDidFail
            if self.didLastReloadFail != reloadDidFail {
                self.didLastReloadFail = reloadDidFail
            }
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

    private func consumeRecentSuccessfulPeerResultIfAvailable() async -> Bool {
        guard let recentStatus = await self.gate.recentSuccessfulCompletion(within: Self.peerReloadDedupeWindow) else {
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

    func recentSuccessfulCompletion(within window: TimeInterval, now: Date = Date()) -> ReloadStatusSnapshot? {
        do {
            guard let status = try readStatus(),
                  status.succeeded == true,
                  now.timeIntervalSince(status.startedAt) < window else {
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
