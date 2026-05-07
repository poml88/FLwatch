//
//  DexcomShareProvider.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  CGMProvider conformance for the unofficial Dexcom Share API. Owns:
//    - region auto-detect on first connect
//    - session-id refresh on `sessionInvalid`
//    - mapping ShareGlucoseEntry → LibreLinkUpGlucose
//    - writing the result into the shared LibreLinkUpHistory store
//

import Foundation
import OSLog

@MainActor
final class DexcomShareProvider: CGMProvider {

    let kind: CGMProviderKind = .dexcomShare

    private let client: DexcomShareClient

    /// Last user-visible status string. Read by `LibreLinkUpService` after each `reload()`.
    private(set) var lastReloadResponseMessage: String = "[...]"

    /// Whether the most recent `reload()` ended in failure.
    private(set) var lastReloadDidFail: Bool = false

    init(client: DexcomShareClient = DexcomShareClient()) {
        self.client = client
    }

    // MARK: - CGMProvider

    func reload() async {
        lastReloadDidFail = false
        DebugMessageSingleton.shared.libreLinkUpOverlayError = ""

        guard let password = (try? DexcomShareTokenStore.read(.password)) ?? nil,
              !password.isEmpty,
              !SharedData.dexcomShareUsername.isEmpty,
              SharedData.dexcomShareRegionIsKnown else {
            lastReloadDidFail = true
            lastReloadResponseMessage = String(localized: "Dexcom account is not connected.")
            Logger.dexcomShare.info("reload skipped: missing credentials")
            return
        }

        let region = SharedData.dexcomShareRegion

        do {
            let entries = try await fetchGlucose(region: region)
            applyEntries(entries)
            lastReloadResponseMessage = entries.isEmpty
                ? String(localized: "Dexcom returned no recent readings.")
                : "[OK]"
            Logger.dexcomShare.info("reload succeeded with \(entries.count, privacy: .public) entries")
        } catch DexcomShareError.sessionInvalid {
            // Cached session is no longer valid; transparently re-login and retry once.
            Logger.dexcomShare.info("session invalid; re-logging in once and retrying")
            do {
                try await reauthenticate(region: region, password: password)
                let entries = try await fetchGlucose(region: region)
                applyEntries(entries)
                lastReloadResponseMessage = entries.isEmpty
                    ? String(localized: "Dexcom returned no recent readings.")
                    : "[OK]"
                Logger.dexcomShare.info("reload-after-reauth succeeded with \(entries.count, privacy: .public) entries")
            } catch {
                lastReloadDidFail = true
                lastReloadResponseMessage = error.localizedDescription
                handleAuthFailure(error)
                Logger.dexcomShare.error("reload-after-reauth failed: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            lastReloadDidFail = true
            lastReloadResponseMessage = error.localizedDescription
            handleAuthFailure(error)
            Logger.dexcomShare.error("reload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Connect / sign out (called from the connect view in Phase 3)

    /// Performs both auth steps, persists credentials and tokens, and triggers
    /// a first reload. Auto-detects the region on first ever connect: tries
    /// the saved region (default US) and falls back to the other on `accountNotFound`.
    /// `accountPasswordInvalid` does not trigger a fall-back — wrong password
    /// means the region was already correct.
    func connect(email: String, password: String) async throws {
        let initialRegion: ShareRegion
        let allowFallback: Bool
        if SharedData.dexcomShareRegionIsKnown {
            initialRegion = SharedData.dexcomShareRegion
            allowFallback = false
        } else {
            initialRegion = .us
            allowFallback = true
        }

        let (resolvedRegion, accountId, sessionId) = try await fullLogin(
            email: email,
            password: password,
            region: initialRegion,
            allowFallback: allowFallback
        )

        SharedData.dexcomShareUsername = email
        SharedData.dexcomShareRegion = resolvedRegion
        try DexcomShareTokenStore.save(password,  kind: .password)
        try DexcomShareTokenStore.save(accountId, kind: .accountId)
        try DexcomShareTokenStore.save(sessionId, kind: .sessionId)

        // Stamp sensor type so the rest of the app knows it's a Dexcom session.
        // Sensor settings (target/alarm thresholds) are kept as-is — Share
        // doesn't return them and we don't want to clobber the user's choices.
        let existing = SensorSettingsStore.shared.sensorSettings
        _ = SensorSettingsStore.shared.replaceCacheAndPersist(
            sensorSettings: existing,
            sensorType: .dexcomG7
        )

        await reload()
    }

    /// Wipes Dexcom credentials. Does not touch LibreLinkUp credentials.
    func signOut() async {
        SharedData.dexcomShareUsername = ""
        try? DexcomShareTokenStore.deleteAll()
    }

    func isAuthenticated() -> Bool {
        guard !SharedData.dexcomShareUsername.isEmpty,
              SharedData.dexcomShareRegionIsKnown,
              let pwd = (try? DexcomShareTokenStore.read(.password)) ?? nil, !pwd.isEmpty,
              let acc = (try? DexcomShareTokenStore.read(.accountId)) ?? nil, !acc.isEmpty else {
            return false
        }
        return true
    }

    // MARK: - Auth helpers

    /// Re-runs `loginById` using the stored accountId, refreshing only the sessionId.
    /// Falls back to a full `authenticate` + `loginById` if the accountId is missing.
    private func reauthenticate(region: ShareRegion, password: String) async throws {
        if let accountId = try DexcomShareTokenStore.read(.accountId), !accountId.isEmpty {
            let newSessionId = try await client.loginById(
                accountId: accountId,
                password: password,
                region: region
            )
            try DexcomShareTokenStore.save(newSessionId, kind: .sessionId)
            return
        }

        let email = SharedData.dexcomShareUsername
        let (_, accountId, sessionId) = try await fullLogin(
            email: email,
            password: password,
            region: region,
            allowFallback: false
        )
        try DexcomShareTokenStore.save(accountId, kind: .accountId)
        try DexcomShareTokenStore.save(sessionId, kind: .sessionId)
    }

    /// Authenticate + loginById, with optional region fall-back if the account
    /// isn't found at the first-tried region.
    private func fullLogin(
        email: String,
        password: String,
        region: ShareRegion,
        allowFallback: Bool
    ) async throws -> (ShareRegion, String, String) {
        do {
            let accountId = try await client.authenticate(email: email, password: password, region: region)
            let sessionId = try await client.loginById(accountId: accountId, password: password, region: region)
            return (region, accountId, sessionId)
        } catch DexcomShareError.accountNotFound where allowFallback {
            let fallback = region.other
            Logger.dexcomShare.info("accountNotFound at \(region.rawValue, privacy: .public); falling back to \(fallback.rawValue, privacy: .public)")
            let accountId = try await client.authenticate(email: email, password: password, region: fallback)
            let sessionId = try await client.loginById(accountId: accountId, password: password, region: fallback)
            return (fallback, accountId, sessionId)
        }
    }

    /// On terminal auth failures, mark the connection state so the rest of the
    /// app can surface the right UI (re-prompt for password, show locked-out screen).
    private func handleAuthFailure(_ error: Error) {
        guard let dx = error as? DexcomShareError else { return }
        switch dx {
        case .accountPasswordInvalid, .accountNotFound:
            UserDefaults.group.connected = .failed
        case .maxAuthenticationAttempts:
            UserDefaults.group.connected = .locked
        default:
            break
        }
    }

    // MARK: - Fetch + apply

    /// 24 h × 5 min cadence is plenty for the home graph.
    private static let graphMinutes = 1440
    private static let graphMaxCount = 288

    private func fetchGlucose(region: ShareRegion) async throws -> [ShareGlucoseEntry] {
        guard let sessionId = try DexcomShareTokenStore.read(.sessionId), !sessionId.isEmpty else {
            throw DexcomShareError.sessionInvalid
        }
        return try await client.readLatestGlucose(
            sessionId: sessionId,
            region: region,
            minutes: Self.graphMinutes,
            maxCount: Self.graphMaxCount
        )
    }

    /// Maps the Share entries into LibreLinkUpGlucose values and writes them to
    /// the shared LibreLinkUpHistory store, mirroring what `LibreLinkUp.reloadLibreLinkUp()`
    /// does for the Libre flow.
    private func applyEntries(_ entries: [ShareGlucoseEntry]) {
        guard !entries.isEmpty else { return }

        // Server returns newest-first. Sort defensively so downstream logic that
        // assumes index 0 is the latest stays correct.
        let sortedNewestFirst = entries.sorted { $0.wallTime > $1.wallTime }
        let settings = SensorSettingsStore.shared.sensorSettings

        // Build LibreLinkUpGlucose, computing trend rate from each entry's
        // immediate predecessor in time.
        var fullHistoryNewestFirst: [LibreLinkUpGlucose] = []
        fullHistoryNewestFirst.reserveCapacity(sortedNewestFirst.count)
        for (index, entry) in sortedNewestFirst.enumerated() {
            let previous: ShareGlucoseEntry? = (index + 1 < sortedNewestFirst.count) ? sortedNewestFirst[index + 1] : nil
            let mapped = DexcomShareTrendMapper.makeGlucose(entry: entry, previous: previous, settings: settings)
            fullHistoryNewestFirst.append(mapped)
        }

        let lastMeasurement = fullHistoryNewestFirst[0]

        // Filter the graph window to the last 6 h (matching what the LLU flow does).
        let sixHoursTenAgo = Date(timeIntervalSinceNow: -6 * 60 * 60 - 10 * 60)
        var filteredGraph = fullHistoryNewestFirst.filter { $0.glucose.date > sixHoursTenAgo }
        if filteredGraph.isEmpty {
            filteredGraph.append(fullHistoryNewestFirst[0])
            if fullHistoryNewestFirst.indices.contains(1) {
                filteredGraph.append(fullHistoryNewestFirst[1])
            }
        }

        // Share has no minute-resolution stream — the 5-min cadence is the only
        // resolution we have. Use the most recent ~25 minutes (5 entries) for the
        // "minute" stream so consumers that read it still see something fresh.
        let minuteHistory = Array(fullHistoryNewestFirst.prefix(5))

        let indexOfMaxGlucoseItem = filteredGraph.indices.max(by: {
            filteredGraph[$0].glucose.value < filteredGraph[$1].glucose.value
        }) ?? 0
#if os(iOS)
        let maxBG = filteredGraph.isEmpty ? 250 : filteredGraph[indexOfMaxGlucoseItem].glucose.value
#endif
#if os(watchOS)
        let maxBG = filteredGraph.isEmpty ? 225 : filteredGraph[indexOfMaxGlucoseItem].glucose.value
#endif

        _ = LibreLinkUpHistory.shared.replaceCacheAndPersist(
            fullLibreLinkUpGlucose: fullHistoryNewestFirst,
            libreLinkUpGlucose: filteredGraph,
            libreLinkUpMinuteGlucose: minuteHistory,
            latestLibreLinkUpGlucose: lastMeasurement,
            lastReadingDate: lastMeasurement.glucose.date,
            currentGlucose: lastMeasurement.glucose.value,
            currentTrendArrow: lastMeasurement.trendArrow?.symbol ?? "---",
            maxBG: maxBG,
            lastSuccessfulLibreLinkUpAPICall: Date()
        )
    }
}
