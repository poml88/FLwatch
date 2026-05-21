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

    // Dexcom G7 / G6 / ONE all publish on a 5-min cadence (from the kind).
    // Stale window is cadence + 3 min grace = 8 min — matches xdrip4ios's
    // tolerance.
    var staleReadingAfter: TimeInterval { 8 * 60 }

    // Throttle by cached-reading age, not call age. xdrip4ios uses the same
    // pattern: poll on triggers, but skip the network call if a reading
    // younger than the source cadence is already cached.
    var reloadThrottleByReadingAge: Bool { true }

    var noDataReceivedHint: String { String(localized: "Check that Dexcom app is running.") }

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

        // A reload needs a username, a known region, and *a* session to try —
        // either the keychain session (app) or the published app-group session
        // (widget, which can't read the keychain). The password is NOT required
        // up front: it's only needed to re-authenticate an expired session, and
        // the widget intentionally has no way to read it.
        let hasUsableSession =
            (((try? DexcomShareTokenStore.read(.sessionId)) ?? nil).map { !$0.isEmpty } ?? false)
            || !SharedData.dexcomShareSessionId.isEmpty
        guard !SharedData.dexcomShareUsername.isEmpty,
              SharedData.dexcomShareRegionIsKnown,
              hasUsableSession else {
            lastReloadDidFail = true
            lastReloadResponseMessage = String(localized: "Dexcom account is not connected.")
            Logger.dexcomShare.info("reload skipped: missing credentials or session")
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
            // No password reachable (i.e. running in the widget extension): we
            // can't re-authenticate here. Clear the published session so the
            // widget's reload gate (`canActiveProviderReload`) turns off and it
            // stops retrying until the app logs in again and republishes a fresh
            // session. Deliberately do NOT touch `connected` — that's the app's.
            guard let password = (try? DexcomShareTokenStore.read(.password)) ?? nil,
                  !password.isEmpty else {
                SharedData.dexcomShareSessionId = ""
                lastReloadDidFail = true
                lastReloadResponseMessage = String(localized: "Dexcom session expired.")
                Logger.dexcomShare.info("session invalid and no password available; cleared published session, not re-authenticating")
                return
            }
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

    /// Single-step publisher login + persist credentials + first reload.
    /// Auto-detects the Share region on first ever connect by trying each
    /// host in turn (cached region first when available).
    func connect(email: String, password: String) async throws {
        let cached = SharedData.dexcomShareRegionIsKnown ? SharedData.dexcomShareRegion : nil
        if let cached {
            Logger.dexcomShare.info("connect: starting with cached region=\(cached.rawValue, privacy: .public); will try other regions if it fails")
        } else {
            Logger.dexcomShare.info("connect: no region cached; will iterate through all regions")
        }

        let (resolvedRegion, accountId, sessionId) = try await loginIteratingAllRegions(
            email: email,
            password: password,
            preferredFirst: cached
        )
        Logger.dexcomShare.info("connect: login complete at region=\(resolvedRegion.rawValue, privacy: .public)")

        SharedData.dexcomShareUsername = email
        SharedData.dexcomShareRegion = resolvedRegion
        try DexcomShareTokenStore.save(password,  kind: .password)
        try DexcomShareTokenStore.save(accountId, kind: .accountId)
        try DexcomShareTokenStore.save(sessionId, kind: .sessionId)
        SharedData.dexcomShareSessionId = sessionId

        // Stamp sensor type so the rest of the app knows it's a Dexcom session.
        // Share doesn't send alarm thresholds: the alarm line tracks the low-glucose
        // notification threshold when enabled, otherwise stays at the hidden
        // sentinel. The user's unit and target choices are kept as-is.
        let existing = SensorSettingsStore.shared.sensorSettings
        let alarms = SensorSettings.dexcomAlarms(
            notificationsEnabled: SharedData.lowGlucoseNotificationsEnabled,
            threshold: SharedData.lowGlucoseNotificationThreshold
        )
        let dexcomSettings = SensorSettings(
            uom: existing.uom,
            targetLow: existing.targetLow,
            targetHigh: existing.targetHigh,
            alarmLow: alarms.low,
            alarmHigh: alarms.high
        )
        _ = SensorSettingsStore.shared.replaceCacheAndPersist(
            sensorSettings: dexcomSettings,
            sensorType: .dexcomG7
        )

        await reload()
    }

    /// Wipes Dexcom credentials. Does not touch LibreLinkUp credentials.
    func signOut() async {
        SharedData.dexcomShareUsername = ""
        SharedData.dexcomShareSessionId = ""
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

    /// Re-runs `loginById` from the cached accountId at the cached region only,
    /// refreshing just the sessionId. Falls back to a full two-step
    /// `authenticate` + `loginById` if the accountId is missing.
    ///
    /// Deliberately *not* iterating across regions on session refresh: every
    /// failed login attempt on Share counts toward an opaque per-account
    /// rate limit, and a single expired-session event would otherwise trip
    /// three back-to-back login attempts. If a user moves countries the
    /// cached region becomes wrong — but that's rare, and the recovery is
    /// "sign out and sign back in" via the connect UI (which goes through
    /// `connect()` → `loginIteratingAllRegions(...)`).
    private func reauthenticate(region: ShareRegion, password: String) async throws {
        Logger.dexcomShare.info("reauthenticate: refreshing session at cached region=\(region.rawValue, privacy: .public)")
        if let accountId = try DexcomShareTokenStore.read(.accountId), !accountId.isEmpty {
            let newSessionId = try await client.loginById(
                accountId: accountId,
                password: password,
                region: region
            )
            try DexcomShareTokenStore.save(newSessionId, kind: .sessionId)
            SharedData.dexcomShareSessionId = newSessionId
            return
        }

        let email = SharedData.dexcomShareUsername
        let accountId = try await client.authenticate(email: email, password: password, region: region)
        let sessionId = try await client.loginById(accountId: accountId, password: password, region: region)
        try DexcomShareTokenStore.save(accountId, kind: .accountId)
        try DexcomShareTokenStore.save(sessionId, kind: .sessionId)
        SharedData.dexcomShareSessionId = sessionId
    }

    /// Iterates through every Share region until one accepts the credentials.
    ///
    /// `preferredFirst` (when set) is tried before the rest — so a returning
    /// user with a previously-detected region hits it immediately. If the
    /// preferred region fails, *every* other region is still tried, because
    /// the user may have moved countries since they last logged in (and
    /// because some Share hosts return `AccountPasswordInvalid` as an
    /// enumeration-defense for accounts that exist in a different region).
    ///
    /// `maxAuthenticationAttempts` short-circuits the loop: Dexcom has locked
    /// the account out, no other region will let us in either.
    private func loginIteratingAllRegions(
        email: String,
        password: String,
        preferredFirst: ShareRegion?
    ) async throws -> (ShareRegion, String, String) {

        // Build the candidate order: preferred first (if any), then the rest in declaration order.
        var candidates: [ShareRegion] = []
        if let preferredFirst {
            candidates.append(preferredFirst)
        }
        for region in ShareRegion.allCases where region != preferredFirst {
            candidates.append(region)
        }

        var lastError: Error = DexcomShareError.other(code: "NoCandidateTried", message: nil)
        for region in candidates {
            Logger.dexcomShare.info("login attempt at region=\(region.rawValue, privacy: .public) (appId=\(region.applicationId.prefix(8), privacy: .public)...)")
            do {
                let accountId = try await client.authenticate(email: email, password: password, region: region)
                let sessionId = try await client.loginById(accountId: accountId, password: password, region: region)
                Logger.dexcomShare.info("login succeeded at region=\(region.rawValue, privacy: .public)")
                return (region, accountId, sessionId)
            } catch DexcomShareError.maxAuthenticationAttempts {
                Logger.dexcomShare.error("login at region=\(region.rawValue, privacy: .public) reported MaxAuthenticationAttempts; stopping")
                throw DexcomShareError.maxAuthenticationAttempts
            } catch {
                lastError = error
                Logger.dexcomShare.info("login at region=\(region.rawValue, privacy: .public) failed (\(error.localizedDescription, privacy: .public)); trying next region")
                continue
            }
        }

        Logger.dexcomShare.error("login: all \(candidates.count, privacy: .public) regions failed; last error: \(lastError.localizedDescription, privacy: .public)")
        throw lastError
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
    private static let graphMinutes = 720 // 12 hours
    private static let graphMaxCount = 288

    private func fetchGlucose(region: ShareRegion) async throws -> [ShareGlucoseEntry] {
        // Prefer the keychain (source of truth for the app); fall back to the
        // app-group copy so the widget — which can't read the keychain — can
        // still fetch with the session the app published.
        let sessionId = ((try? DexcomShareTokenStore.read(.sessionId)) ?? nil)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? SharedData.dexcomShareSessionId
        guard !sessionId.isEmpty else {
            throw DexcomShareError.sessionInvalid
        }
        let entries = try await client.readLatestGlucose(
            sessionId: sessionId,
            region: region,
            minutes: Self.graphMinutes,
            maxCount: Self.graphMaxCount
        )
        // Republish on every success so a session the widget previously cleared
        // (or one only held in the keychain) is restored to the app group.
        SharedData.dexcomShareSessionId = sessionId
        return entries
    }

    /// Maps the Share entries into LibreLinkUpGlucose values and writes them to
    /// the shared LibreLinkUpHistory store, mirroring what `LibreLinkUp.reloadLibreLinkUp()`
    /// does for the Libre flow.
    private func applyEntries(_ entries: [ShareGlucoseEntry]) {
        guard !entries.isEmpty else { return }

        // Server returns newest-first. Sort defensively so downstream logic that
        // assumes index 0 is the latest stays correct.
        let sortedNewestFirst = entries.sorted { $0.timestamp > $1.timestamp }
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
