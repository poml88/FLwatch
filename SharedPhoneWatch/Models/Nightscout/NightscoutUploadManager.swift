//
//  NightscoutUploadManager.swift
//  LibreWrist
//
//  Main-app-owned coordinator with an explicit serialized worker. Shared
//  targets compile this type, but every entry point is a pure no-op outside
//  the main iOS application process.
//

import Foundation
import OSLog

enum NightscoutExecutionContext {
    static var isMainAppProcess: Bool {
#if FLWATCH_MAIN_APP
        return Bundle.main.bundleURL.pathExtension.lowercased() != "appex"
#else
        return false
#endif
    }
}

@MainActor
final class NightscoutUploadManager {
    static let shared = NightscoutUploadManager()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "NightscoutUpload"
    )
    private static let circuitHalfOpenInterval: TimeInterval = 30 * 60
    private static let documentSuppressionRetention: TimeInterval = 24 * 60 * 60
    private static let maximumGlucoseSuppressions = 5_000
    private static let maximumInsulinSuppressions = 1_000

    private struct NetworkContext {
        let baseURL: NightscoutBaseURL
        let accessToken: String
        let client: NightscoutClientV3
        let outbox: NightscoutOutbox
    }

    private enum InsulinOperationOutcome<T> {
        case completed(T)
        case superseded
    }

    private enum FailureDisposition {
        case namespaceCircuitOpened
        case documentSuppressed
        case retryLater
    }

    private struct NamespaceCircuitBreaker {
        let statusCode: Int
        var nextProbeAt: Date
    }

    private struct GlucoseDocumentSuppression {
        let fingerprint: String
        let blockedAt: Date
    }

    private struct PendingWork {
        var glucoseUploads: [String: NightscoutEntryUpload] = [:]
        var drainInsulin = false

        init(
            glucoseUploads: [String: NightscoutEntryUpload] = [:],
            drainInsulin: Bool = false
        ) {
            self.glucoseUploads = glucoseUploads
            self.drainInsulin = drainInsulin
        }

        var isEmpty: Bool {
            glucoseUploads.isEmpty && !drainInsulin
        }

        mutating func merge(_ other: PendingWork) {
            glucoseUploads.merge(other.glucoseUploads) { _, newest in newest }
            drainInsulin = drainInsulin || other.drainInsulin
        }
    }

    private var outboxStorage: NightscoutOutbox?
    private var clients: [String: NightscoutClientV3] = [:]
    private var pendingWork = PendingWork()
    private var isWorkerRunning = false
    private var workerWaiters: [CheckedContinuation<Void, Never>] = []
    private var namespaceCircuitBreakers: [String: NamespaceCircuitBreaker] = [:]
    private var blockedGlucoseFingerprints: [String: GlucoseDocumentSuppression] = [:]
    private var blockedInsulinRevisions: [String: Date] = [:]
    private var lastAutomaticConfigurationSignature: String?
    private var loggedRejectedSources = Set<String>()

    private init() {}

    // MARK: - Public integration surface

    /// Queues a hot-path glucose reconciliation. Candidates should be ordered
    /// from lowest to highest precedence; a later duplicate timestamp wins.
    func reconcileGlucose(_ candidates: [LibreLinkUpGlucose]) {
        guard automaticNetworkContext() != nil else { return }
        enqueue(PendingWork(glucoseUploads: glucoseUploads(from: candidates)))
    }

    /// Awaited lifecycle catch-up: reconciles the complete retained glucose
    /// window and drains durable insulin desired state before returning.
    func reconcileRetainedDataAndWait() async {
        guard NightscoutExecutionContext.isMainAppProcess else { return }
        let history = LibreLinkUpHistory.shared
        var candidates = history.fullLibreLinkUpGlucose
        candidates.append(contentsOf: history.libreLinkUpGlucose)
        candidates.append(contentsOf: history.libreLinkUpMinuteGlucose)
        if let latest = history.latestLibreLinkUpGlucose {
            candidates.append(latest)
        }

        var work = PendingWork()
        if automaticNetworkContext() != nil {
            work.glucoseUploads = glucoseUploads(from: candidates)
            work.drainInsulin = true
        }
        guard !work.isEmpty else { return }
        enqueue(work)
        await waitForWorkerToBecomeIdle()
    }

    /// Records desired insulin state synchronously before returning to the
    /// model mutator. Provider selection intentionally does not gate recording.
    func recordInsulinPresent(_ delivery: InsulinDelivery) {
        guard let namespace = recordingNamespace(),
              let outbox = try? outbox() else { return }
        do {
            try outbox.recordPresent(
                NightscoutTreatmentUpload(delivery: delivery),
                namespace: namespace
            )
        } catch {
            Self.logger.error("Failed to persist a Nightscout insulin upload state.")
            return
        }
        if automaticNetworkContext() != nil {
            enqueue(PendingWork(drainInsulin: true))
        }
    }

    /// Records a deletion even while a cloud CGM provider is active. If the
    /// corresponding PUT has never started, the pending upload is cancelled
    /// without scheduling unnecessary network work.
    func recordInsulinAbsent(identifier: UUID) {
        guard let namespace = recordingNamespace(),
              let outbox = try? outbox() else { return }
        let result: NightscoutAbsentRecordingResult
        do {
            result = try outbox.recordAbsent(identifier: identifier, namespace: namespace)
        } catch {
            Self.logger.error("Failed to persist a Nightscout insulin deletion state.")
            return
        }
        guard result == .queuedDeletion, automaticNetworkContext() != nil else { return }
        enqueue(PendingWork(drainInsulin: true))
    }

    func testConnection(baseURLString: String, accessToken: String) async -> NightscoutConnectionTestResult {
        guard NightscoutExecutionContext.isMainAppProcess,
              let baseURL = try? NightscoutBaseURL(normalizing: baseURLString) else {
            return .unreachable
        }
        let result = await client(for: baseURL).testConnection(accessToken: accessToken)
        if result == .ok {
            resetBlockingState(for: baseURL)
            Self.logger.info("Nightscout connection test succeeded; upload suppression state reset.")
        }
        return result
    }

    func unresolvedCount(baseURLString: String) throws -> Int {
        guard NightscoutExecutionContext.isMainAppProcess else { return 0 }
        let namespace = try NightscoutBaseURL(normalizing: baseURLString)
        return try outbox().unresolvedCount(namespace: namespace)
    }

    @discardableResult
    func forgetServer(baseURLString: String) throws -> Int {
        guard NightscoutExecutionContext.isMainAppProcess else { return 0 }
        let namespace = try NightscoutBaseURL(normalizing: baseURLString)
        let discardedCount = try outbox().forget(namespace: namespace)
        clients.removeValue(forKey: namespace.absoluteString)
        resetBlockingState(for: namespace)
        return discardedCount
    }

    // MARK: - Explicit serialized worker

    private func enqueue(_ work: PendingWork) {
        guard NightscoutExecutionContext.isMainAppProcess, !work.isEmpty else { return }
        pendingWork.merge(work)
        guard !isWorkerRunning else { return }

        isWorkerRunning = true
        Task { @MainActor [weak self] in
            await self?.runWorker()
        }
    }

    private func runWorker() async {
        while !pendingWork.isEmpty {
            let work = pendingWork
            pendingWork = PendingWork()
            await perform(work)
        }

        isWorkerRunning = false
        let waiters = workerWaiters
        workerWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func waitForWorkerToBecomeIdle() async {
        guard isWorkerRunning else { return }
        await withCheckedContinuation { continuation in
            workerWaiters.append(continuation)
        }
    }

    private func perform(_ work: PendingWork) async {
        guard let context = automaticNetworkContext(),
              shouldAttemptNetwork(for: context.baseURL) else { return }
        var shouldContinue = true
        if !work.glucoseUploads.isEmpty {
            shouldContinue = await reconcileGlucoseUploads(
                Array(work.glucoseUploads.values),
                context: context
            )
        }
        if work.drainInsulin, shouldContinue {
            await drainInsulin(context: context)
        }
    }

    // MARK: - Glucose reconciliation

    private func reconcileGlucoseUploads(
        _ uploads: [NightscoutEntryUpload],
        context: NetworkContext
    ) async -> Bool {
        for upload in uploads.sorted(by: { $0.eventDate < $1.eventDate }) {
            let identifierKey = context.baseURL.absoluteString
                + "|"
                + upload.identifier.uuidString.lowercased()
            let fingerprint = upload.fingerprint
            if context.outbox.glucoseFingerprint(
                for: upload.identifier,
                namespace: context.baseURL
            )?.fingerprint == fingerprint {
                continue
            }
            if isGlucoseDocumentSuppressed(
                key: identifierKey,
                fingerprint: fingerprint
            ) {
                continue
            }

            do {
                try await withBackoff {
                    try await context.client.putEntry(
                        identifier: upload.identifier,
                        body: upload.body,
                        accessToken: context.accessToken
                    )
                }
                markNetworkSuccess(for: context.baseURL)
                try context.outbox.confirmGlucose(upload, namespace: context.baseURL)
                blockedGlucoseFingerprints.removeValue(forKey: identifierKey)
            } catch let error as NightscoutClientError {
                switch handleClientFailure(
                    error,
                    operation: "entry PUT",
                    baseURL: context.baseURL,
                    glucoseSuppression: (identifierKey, fingerprint),
                    insulinRevision: nil
                ) {
                case .documentSuppressed:
                    continue
                case .namespaceCircuitOpened, .retryLater:
                    return false
                }
            } catch {
                Self.logger.error("Nightscout entry upload stopped after a local persistence or cancellation error.")
                return false
            }
        }
        return true
    }

    // MARK: - Insulin convergence

    private func drainInsulin(context: NetworkContext) async {
        let items = context.outbox.pendingInsulinItems(namespace: context.baseURL)
        for item in items {
            let shouldContinue = await convergeInsulinItem(
                identifier: item.id,
                context: context
            )
            if !shouldContinue { return }
        }
    }

    /// Returns false when a namespace-wide or retryable failure should stop
    /// this drain pass.
    private func convergeInsulinItem(identifier: UUID, context: NetworkContext) async -> Bool {
        while let current = context.outbox.insulinItem(
            identifier: identifier,
            namespace: context.baseURL
        ) {
            let revisionKey = insulinSuppressionKey(
                revision: current.revision,
                baseURL: context.baseURL
            )
            if isInsulinRevisionSuppressed(key: revisionKey) { return true }

            switch current.desiredState {
            case .present(let payload, _):
                let started: NightscoutInsulinOutboxItem
                do {
                    guard let marked = try context.outbox.markUploadAttemptStarted(
                        identifier: identifier,
                        revision: current.revision,
                        namespace: context.baseURL
                    ) else {
                        continue
                    }
                    started = marked
                } catch {
                    Self.logger.error("Failed to mark a Nightscout insulin upload attempt as started.")
                    return false
                }

                do {
                    let outcome = try await withInsulinBackoff(
                        identifier: identifier,
                        expectedRevision: started.revision,
                        context: context
                    ) {
                        try await context.client.putTreatment(
                            identifier: payload.identifier,
                            body: payload.body,
                            accessToken: context.accessToken
                        )
                    }
                    if case .superseded = outcome { continue }
                    markNetworkSuccess(for: context.baseURL)
                    // Re-read after the await. A concurrent delete replaces the
                    // revision and must survive this PUT completion.
                    if context.outbox.insulinItem(
                        identifier: identifier,
                        namespace: context.baseURL
                    )?.revision == started.revision {
                        try context.outbox.resolveInsulinItem(
                            identifier: identifier,
                            expectedRevision: started.revision,
                            namespace: context.baseURL
                        )
                    }
                } catch let error as NightscoutClientError {
                    let latest = context.outbox.insulinItem(
                        identifier: identifier,
                        namespace: context.baseURL
                    )
                    if latest?.revision != started.revision {
                        // Desired state changed during an uncertain PUT; loop
                        // immediately so an absent state converges by DELETE.
                        continue
                    }
                    switch handleClientFailure(
                        error,
                        operation: "treatment PUT",
                        baseURL: context.baseURL,
                        glucoseSuppression: nil,
                        insulinRevision: started.revision
                    ) {
                    case .documentSuppressed:
                        return true
                    case .namespaceCircuitOpened, .retryLater:
                        return false
                    }
                } catch {
                    Self.logger.error("Nightscout insulin upload stopped after a local persistence or cancellation error.")
                    return false
                }

            case .absent(let tombstone):
                do {
                    let outcome = try await withInsulinBackoff(
                        identifier: identifier,
                        expectedRevision: current.revision,
                        context: context
                    ) {
                        try await context.client.deleteTreatment(
                            identifier: tombstone.identifier,
                            accessToken: context.accessToken
                        )
                    }
                    if case .superseded = outcome { continue }
                    markNetworkSuccess(for: context.baseURL)
                    // DELETE 404 is success only if no later present revision
                    // was queued while the request was in flight.
                    try context.outbox.resolveInsulinItem(
                        identifier: identifier,
                        expectedRevision: current.revision,
                        namespace: context.baseURL
                    )
                } catch let error as NightscoutClientError {
                    let latest = context.outbox.insulinItem(
                        identifier: identifier,
                        namespace: context.baseURL
                    )
                    if latest?.revision != current.revision {
                        continue
                    }
                    switch handleClientFailure(
                        error,
                        operation: "treatment DELETE",
                        baseURL: context.baseURL,
                        glucoseSuppression: nil,
                        insulinRevision: current.revision
                    ) {
                    case .documentSuppressed:
                        return true
                    case .namespaceCircuitOpened, .retryLater:
                        return false
                    }
                } catch {
                    Self.logger.error("Nightscout insulin deletion stopped after a local persistence or cancellation error.")
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Configuration and persistence gates

    private func recordingNamespace() -> NightscoutBaseURL? {
        guard NightscoutExecutionContext.isMainAppProcess,
              SharedData.nightscoutUploadEnabled else { return nil }
        return try? NightscoutBaseURL(normalizing: SharedData.nightscoutURL)
    }

    private func automaticNetworkContext() -> NetworkContext? {
        guard let baseURL = recordingNamespace(),
              SharedData.cgmProviderKind.isDirectBLE,
              SharedData.nightscoutTokenPresent else {
            return nil
        }
        let storedAccessToken: String?
        do {
            storedAccessToken = try NightscoutSecretKeychain.read()
        } catch {
            Self.logger.error("Nightscout access token could not be read from Keychain.")
            return nil
        }
        guard let accessToken = storedAccessToken,
              !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        updateAutomaticConfiguration(baseURL: baseURL, accessToken: accessToken)

        let activeOutbox: NightscoutOutbox
        do {
            activeOutbox = try outbox()
        } catch {
            Self.logger.error("Nightscout outbox could not be opened.")
            return nil
        }
        return NetworkContext(
            baseURL: baseURL,
            accessToken: accessToken,
            client: client(for: baseURL),
            outbox: activeOutbox
        )
    }

    private func outbox() throws -> NightscoutOutbox {
        if let outboxStorage { return outboxStorage }
        let newOutbox = try NightscoutOutbox()
        outboxStorage = newOutbox
        return newOutbox
    }

    private func client(for baseURL: NightscoutBaseURL) -> NightscoutClientV3 {
        if let existing = clients[baseURL.absoluteString] { return existing }
        let newClient = NightscoutClientV3(baseURL: baseURL)
        clients[baseURL.absoluteString] = newClient
        return newClient
    }

    private func glucoseUploads(
        from candidates: [LibreLinkUpGlucose]
    ) -> [String: NightscoutEntryUpload] {
        var uploads: [String: NightscoutEntryUpload] = [:]
        for candidate in candidates {
            let source = candidate.glucose.source
            guard CGMReadingSource.directBLENightscoutSources.contains(source) else {
                let displaySource = source.isEmpty ? "(empty)" : source
                if loggedRejectedSources.insert(displaySource).inserted {
                    Self.logger.info(
                        "Nightscout skipped cached glucose with non-direct source \(displaySource, privacy: .public)."
                    )
                }
                continue
            }
            guard candidate.glucose.value > 0, !candidate.glucose.hasError else { continue }
            let upload = NightscoutEntryUpload(reading: candidate)
            uploads[upload.identifier.uuidString.lowercased()] = upload
        }
        return uploads
    }

    // MARK: - Failure suppression and recovery

    private func updateAutomaticConfiguration(
        baseURL: NightscoutBaseURL,
        accessToken: String
    ) {
        let tokenDigest = NightscoutDigest.sha256Hex(of: Data(accessToken.utf8))
        let signature = baseURL.absoluteString + "|" + tokenDigest
        if let previous = lastAutomaticConfigurationSignature,
           previous != signature {
            resetAllBlockingState()
            Self.logger.info("Nightscout URL or access token changed; upload suppression state reset.")
        }
        lastAutomaticConfigurationSignature = signature
    }

    private func shouldAttemptNetwork(
        for baseURL: NightscoutBaseURL,
        now: Date = Date()
    ) -> Bool {
        guard var breaker = namespaceCircuitBreakers[baseURL.absoluteString] else {
            return true
        }
        guard now >= breaker.nextProbeAt else { return false }

        // Move the next probe before starting this one so repeated triggers do
        // not create a burst if the half-open pass contains no eligible work.
        breaker.nextProbeAt = now.addingTimeInterval(Self.circuitHalfOpenInterval)
        namespaceCircuitBreakers[baseURL.absoluteString] = breaker
        Self.logger.info(
            "Nightscout circuit half-open; attempting one recovery pass after HTTP \(breaker.statusCode, privacy: .public)."
        )
        return true
    }

    private func markNetworkSuccess(for baseURL: NightscoutBaseURL) {
        if namespaceCircuitBreakers.removeValue(forKey: baseURL.absoluteString) != nil {
            Self.logger.info("Nightscout circuit closed after a successful authenticated v3 request.")
        }
    }

    private func handleClientFailure(
        _ error: NightscoutClientError,
        operation: String,
        baseURL: NightscoutBaseURL,
        glucoseSuppression: (key: String, fingerprint: String)?,
        insulinRevision: UUID?
    ) -> FailureDisposition {
        let namespaceStatusCodes: Set<Int> = [401, 403, 404, 405, 410]
        let isNamespaceFailure: Bool
        switch error {
        case .httpStatus(let code, _, _):
            isNamespaceFailure = namespaceStatusCodes.contains(code)
        case .invalidBaseURL, .missingAccessToken, .invalidAuthorizationResponse:
            isNamespaceFailure = true
        case .requestEncoding, .invalidResponse, .transport:
            isNamespaceFailure = false
        }
        if isNamespaceFailure {
            openCircuit(for: baseURL, error: error, operation: operation)
            return .namespaceCircuitOpened
        }

        if !error.isRetryable {
            let now = Date()
            if let glucoseSuppression {
                blockedGlucoseFingerprints[glucoseSuppression.key] = GlucoseDocumentSuppression(
                    fingerprint: glucoseSuppression.fingerprint,
                    blockedAt: now
                )
            }
            if let insulinRevision {
                blockedInsulinRevisions[
                    insulinSuppressionKey(revision: insulinRevision, baseURL: baseURL)
                ] = now
            }
            pruneDocumentSuppressions(now: now)
            logClientFailure(error, operation: operation, disposition: "document suppressed")
            return .documentSuppressed
        }

        logClientFailure(error, operation: operation, disposition: "retry deferred")
        return .retryLater
    }

    private func openCircuit(
        for baseURL: NightscoutBaseURL,
        error: NightscoutClientError,
        operation: String,
        now: Date = Date()
    ) {
        namespaceCircuitBreakers[baseURL.absoluteString] = NamespaceCircuitBreaker(
            statusCode: error.statusCode ?? 0,
            nextProbeAt: now.addingTimeInterval(Self.circuitHalfOpenInterval)
        )
        logClientFailure(error, operation: operation, disposition: "namespace circuit opened")
    }

    private func logClientFailure(
        _ error: NightscoutClientError,
        operation: String,
        disposition: String
    ) {
        if let statusCode = error.statusCode {
            Self.logger.error(
                "Nightscout \(operation, privacy: .public) failed with HTTP \(statusCode, privacy: .public); \(disposition, privacy: .public)."
            )
        } else {
            // Do not interpolate transport errors: their descriptions can
            // contain the token-exchange URL, whose final path segment is the
            // raw access token.
            Self.logger.error(
                "Nightscout \(operation, privacy: .public) failed without an HTTP response; \(disposition, privacy: .public)."
            )
        }
        if let snippet = error.responseBodySnippet {
            Self.logger.error(
                "Nightscout validation response: \(snippet, privacy: .private)."
            )
        }
    }

    private func isGlucoseDocumentSuppressed(
        key: String,
        fingerprint: String,
        now: Date = Date()
    ) -> Bool {
        guard let suppression = blockedGlucoseFingerprints[key] else { return false }
        guard now.timeIntervalSince(suppression.blockedAt) < Self.documentSuppressionRetention,
              suppression.fingerprint == fingerprint else {
            blockedGlucoseFingerprints.removeValue(forKey: key)
            return false
        }
        return true
    }

    private func isInsulinRevisionSuppressed(
        key: String,
        now: Date = Date()
    ) -> Bool {
        guard let blockedAt = blockedInsulinRevisions[key] else { return false }
        guard now.timeIntervalSince(blockedAt) < Self.documentSuppressionRetention else {
            blockedInsulinRevisions.removeValue(forKey: key)
            return false
        }
        return true
    }

    private func insulinSuppressionKey(
        revision: UUID,
        baseURL: NightscoutBaseURL
    ) -> String {
        baseURL.absoluteString + "|" + revision.uuidString.lowercased()
    }

    private func pruneDocumentSuppressions(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.documentSuppressionRetention)
        blockedGlucoseFingerprints = blockedGlucoseFingerprints.filter {
            $0.value.blockedAt >= cutoff
        }
        blockedInsulinRevisions = blockedInsulinRevisions.filter {
            $0.value >= cutoff
        }

        if blockedGlucoseFingerprints.count > Self.maximumGlucoseSuppressions {
            let excess = blockedGlucoseFingerprints.count - Self.maximumGlucoseSuppressions
            for key in blockedGlucoseFingerprints
                .sorted(by: { $0.value.blockedAt < $1.value.blockedAt })
                .prefix(excess)
                .map(\.key) {
                blockedGlucoseFingerprints.removeValue(forKey: key)
            }
        }
        if blockedInsulinRevisions.count > Self.maximumInsulinSuppressions {
            let excess = blockedInsulinRevisions.count - Self.maximumInsulinSuppressions
            for key in blockedInsulinRevisions
                .sorted(by: { $0.value < $1.value })
                .prefix(excess)
                .map(\.key) {
                blockedInsulinRevisions.removeValue(forKey: key)
            }
        }
    }

    private func resetBlockingState(for baseURL: NightscoutBaseURL) {
        let prefix = baseURL.absoluteString + "|"
        namespaceCircuitBreakers.removeValue(forKey: baseURL.absoluteString)
        blockedGlucoseFingerprints = blockedGlucoseFingerprints.filter {
            !$0.key.hasPrefix(prefix)
        }
        blockedInsulinRevisions = blockedInsulinRevisions.filter {
            !$0.key.hasPrefix(prefix)
        }
    }

    private func resetAllBlockingState() {
        namespaceCircuitBreakers.removeAll()
        blockedGlucoseFingerprints.removeAll()
        blockedInsulinRevisions.removeAll()
    }

    private func withBackoff<T>(
        operation: () async throws -> T
    ) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch let error as NightscoutClientError {
                guard error.isRetryable, attempt < 2 else { throw error }
                let exponentialDelay = pow(2.0, Double(attempt))
                let delay = min(max(error.retryAfter ?? exponentialDelay, 1), 30)
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Insulin retries re-read durable desired state after every network await
    /// and again after each backoff sleep. A superseding delete/upload stops
    /// the stale operation before another request or completion can commit.
    private func withInsulinBackoff<T>(
        identifier: UUID,
        expectedRevision: UUID,
        context: NetworkContext,
        operation: () async throws -> T
    ) async throws -> InsulinOperationOutcome<T> {
        var attempt = 0
        while true {
            do {
                let value = try await operation()
                guard context.outbox.insulinItem(
                    identifier: identifier,
                    namespace: context.baseURL
                )?.revision == expectedRevision else {
                    return .superseded
                }
                return .completed(value)
            } catch let error as NightscoutClientError {
                guard context.outbox.insulinItem(
                    identifier: identifier,
                    namespace: context.baseURL
                )?.revision == expectedRevision else {
                    return .superseded
                }
                guard error.isRetryable, attempt < 2 else { throw error }
                let exponentialDelay = pow(2.0, Double(attempt))
                let delay = min(max(error.retryAfter ?? exponentialDelay, 1), 30)
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard context.outbox.insulinItem(
                    identifier: identifier,
                    namespace: context.baseURL
                )?.revision == expectedRevision else {
                    return .superseded
                }
            }
        }
    }
}
