//
//  NightscoutUploadManager.swift
//  LibreWrist
//
//  Main-app-owned coordinator with an explicit serialized worker. Shared
//  targets compile this type, but every entry point is a pure no-op outside
//  the main iOS application process.
//

import Foundation
import Observation
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
@Observable
final class NightscoutUploadStatus {
    enum PauseReason: Equatable {
        case credentialsRejected
        case endpointUnavailable
        case authorizationUnavailable
        case invalidServerURL
    }

    enum Activity: Equatable {
        case ready
        case retrying
        case retryDeferred
        case documentRejected
        case paused(reason: PauseReason, until: Date)
    }

    private(set) var lastSuccessfulUploadAt = SharedData.nightscoutLastSuccessfulUploadDate
    private(set) var activity: Activity = .ready

    fileprivate func recordSuccessfulPass(at date: Date = Date()) {
        SharedData.nightscoutLastSuccessfulUploadDate = date
        lastSuccessfulUploadAt = date
    }

    fileprivate func markReady() {
        guard activity != .ready else { return }
        activity = .ready
    }

    fileprivate func markRetrying() {
        guard activity != .retrying else { return }
        activity = .retrying
    }

    fileprivate func markRetryDeferred() {
        guard activity != .retryDeferred else { return }
        activity = .retryDeferred
    }

    fileprivate func markDocumentRejected() {
        guard activity != .documentRejected else { return }
        activity = .documentRejected
    }

    fileprivate func markPaused(reason: PauseReason, until: Date) {
        let nextActivity = Activity.paused(reason: reason, until: until)
        guard activity != nextActivity else { return }
        activity = nextActivity
    }

    fileprivate func reset() {
        SharedData.nightscoutLastSuccessfulUploadDate = nil
        lastSuccessfulUploadAt = nil
        activity = .ready
    }
}

@MainActor
final class NightscoutUploadManager {
    static let shared = NightscoutUploadManager()
    let status = NightscoutUploadStatus()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "NightscoutUpload"
    )
    private static let circuitHalfOpenInterval: TimeInterval = 30 * 60
    private static let maximumBackoffDuration: TimeInterval = 5
    private static let minimumFillableGapMinutes = 15
    private static let documentSuppressionRetention: TimeInterval = 24 * 60 * 60
    private static let maximumGlucoseSuppressions = 5_000
    private static let maximumInsulinSuppressions = 1_000

    private struct NetworkContext {
        let baseURL: NightscoutBaseURL
        let accessToken: String
        let client: NightscoutClientV3
        let outbox: NightscoutOutbox
    }

    /// A removal advances the generation so a suspended pass can neither
    /// persist confirmations nor repopulate status after it resumes.
    private final class NetworkPassState {
        let configurationGeneration: UInt
        var hadNetworkSuccess = false

        init(configurationGeneration: UInt) {
            self.configurationGeneration = configurationGeneration
        }
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

    private enum NightscoutGlucoseProvenance: Equatable {
        case minute
        case historical
    }

    private struct NamespaceCircuitBreaker {
        let statusCode: Int
        let reason: NightscoutUploadStatus.PauseReason
        var nextProbeAt: Date
    }

    private struct GlucoseDocumentSuppression {
        let fingerprint: String
        let blockedAt: Date
    }

    private struct PendingGlucoseUpload {
        let upload: NightscoutEntryUpload
        let lifeCount: Int
        let provenance: NightscoutGlucoseProvenance
    }

    private enum GlucoseDocumentOutcome {
        case confirmed
        case skipped
        case stop
    }

    /// One serialized reconciliation pass. Deadline-bound lifecycle work is
    /// kept separate from ordinary hot-path work: merging the two would let an
    /// expired BG budget discard a newly arrived glucose reading. Completion
    /// IDs belong to callers awaiting this particular work, not to the worker
    /// as a whole, because unrelated unbounded work may continue afterwards.
    private struct PendingWork {
        var glucoseUploads: [String: PendingGlucoseUpload] = [:]
        var glucoseSensorSerial: String?
        var drainInsulin = false
        var deadline: Date?
        var completionIDs = Set<UUID>()

        init(
            glucoseUploads: [String: PendingGlucoseUpload] = [:],
            glucoseSensorSerial: String? = nil,
            drainInsulin: Bool = false,
            deadline: Date? = nil
        ) {
            self.glucoseUploads = glucoseUploads
            self.glucoseSensorSerial = glucoseSensorSerial
            self.drainInsulin = drainInsulin
            self.deadline = deadline
        }

        var isEmpty: Bool {
            glucoseUploads.isEmpty && !drainInsulin
        }

        mutating func merge(_ other: PendingWork) {
            if !other.glucoseUploads.isEmpty {
                if glucoseSensorSerial == nil || glucoseSensorSerial == other.glucoseSensorSerial {
                    glucoseUploads.merge(other.glucoseUploads) { current, newest in
                        if current.provenance == .minute,
                           newest.provenance == .historical {
                            return current
                        }
                        return newest
                    }
                } else {
                    // A newly paired sensor supersedes queued glucose work from
                    // the old serial. A later lifecycle sweep safely recovers
                    // any old document that was not already fingerprinted.
                    glucoseUploads = other.glucoseUploads
                }
                glucoseSensorSerial = other.glucoseSensorSerial
            }
            drainInsulin = drainInsulin || other.drainInsulin
            completionIDs.formUnion(other.completionIDs)
            switch (deadline, other.deadline) {
            case (nil, let otherDeadline?):
                deadline = otherDeadline
            case (let currentDeadline?, let otherDeadline?):
                deadline = min(currentDeadline, otherDeadline)
            case (_, nil):
                break
            }
        }
    }

    private var outboxStorage: NightscoutOutbox?
    private var clients: [String: NightscoutClientV3] = [:]
    private var pendingBoundedWork: [PendingWork] = []
    private var pendingUnboundedWork = PendingWork()
    private var isWorkerRunning = false
    /// Retained so removing the configuration can promptly cancel in-flight I/O.
    private var workerTask: Task<Void, Never>?
    private var workWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var workDeadlineTasks: [UUID: Task<Void, Never>] = [:]
    private var namespaceCircuitBreakers: [String: NamespaceCircuitBreaker] = [:]
    private var retryNotBefore: [String: Date] = [:]
    private var blockedGlucoseFingerprints: [String: GlucoseDocumentSuppression] = [:]
    private var blockedInsulinRevisions: [String: Date] = [:]
    private var lastAutomaticConfigurationSignature: String?
    private var loggedRejectedSources = Set<String>()
    private var configurationGeneration: UInt = 0

    private init() {}

    // MARK: - Public integration surface

    /// Queues a provenance-aware hot-path reconciliation. Minute candidates
    /// always take precedence over historical candidates for the same upload
    /// identifier, independent of enqueue/merge order.
    func reconcileGlucose(
        minuteCandidates: [LibreLinkUpGlucose],
        historicalCandidates: [LibreLinkUpGlucose],
        sensorSerial: String
    ) {
        guard automaticNetworkContext() != nil, !sensorSerial.isEmpty else { return }
        enqueue(PendingWork(
            glucoseUploads: glucoseUploads(
                minuteCandidates: minuteCandidates,
                historicalCandidates: historicalCandidates
            ),
            glucoseSensorSerial: sensorSerial
        ))
    }

    /// Seeds the complete retained glucose and insulin windows, then awaits the
    /// serialized network pass. Insulin seeding is provider-independent; only
    /// network execution is held until a direct-BLE provider is active.
    func reconcileRetainedDataAndWait(maximumDuration: TimeInterval? = nil) async {
        guard NightscoutExecutionContext.isMainAppProcess else { return }
        let history = LibreLinkUpHistory.shared
        let sensorSerial = SharedData.libre3Serial
        var minuteCandidates = history.libreLinkUpMinuteGlucose
        let minuteLifeCounts = Set(minuteCandidates.map { $0.glucose.id })
        // The full graph conditionally injects its latest minute at index zero.
        // Membership in the minute overlay is the only reliable provenance.
        var historicalCandidates = (
            history.fullLibreLinkUpGlucose + history.libreLinkUpGlucose
        ).filter { !minuteLifeCounts.contains($0.glucose.id) }
        if let latest = history.latestLibreLinkUpGlucose {
            if minuteLifeCounts.contains(latest.glucose.id) {
                minuteCandidates.append(latest)
            } else {
                historicalCandidates.append(latest)
            }
        }

        let deadline = maximumDuration.map { Date().addingTimeInterval(max(0, $0)) }
        var work = PendingWork(deadline: deadline)
        if let namespace = recordingNamespace(),
           let activeOutbox = try? outbox() {
            let retainedTreatments = InsulinDeliveryHistorySingleton
                .retainedPersistedHistorySnapshot()
                .map { NightscoutTreatmentUpload(delivery: $0) }
            do {
                try activeOutbox.recordPresent(
                    retainedTreatments,
                    namespace: namespace
                )
            } catch {
                Self.logger.error("Failed to seed retained insulin deliveries into the Nightscout outbox.")
            }
        }
        let canRunNetwork = automaticNetworkContext() != nil
        if canRunNetwork, !sensorSerial.isEmpty {
            work.glucoseUploads = glucoseUploads(
                minuteCandidates: minuteCandidates,
                historicalCandidates: historicalCandidates
            )
            work.glucoseSensorSerial = sensorSerial
        }
        if canRunNetwork {
            work.drainInsulin = true
        }
        guard !work.isEmpty else { return }
        let completionID = UUID()
        work.completionIDs.insert(completionID)
        await enqueueAndWait(work, completionID: completionID)
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
        guard NightscoutExecutionContext.isMainAppProcess,
              SharedData.nightscoutUploadEnabled,
              let outbox = try? outbox() else { return }
        var queuedDeletion = false
        for namespace in outbox.insulinNamespaces(for: identifier) {
            do {
                let result = try outbox.recordAbsent(
                    identifier: identifier,
                    namespace: namespace
                )
                queuedDeletion = queuedDeletion || result == .queuedDeletion
            } catch {
                Self.logger.error("Failed to persist a Nightscout insulin deletion state.")
            }
        }
        guard queuedDeletion, automaticNetworkContext() != nil else { return }
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

    /// Stops current work before removing every persisted part of the active
    /// configuration. The saved URL, rather than an editable UI draft, owns the
    /// outbox namespace being discarded.
    @discardableResult
    func removeConfiguration() throws -> Int {
        guard NightscoutExecutionContext.isMainAppProcess else { return 0 }

        // Delete the secret before mutating any other state. If this fails the
        // configuration remains intact; if a later file write fails, the token
        // presence gate still prevents another automatic network context.
        try NightscoutSecretKeychain.delete()

        configurationGeneration &+= 1
        workerTask?.cancel()
        workerTask = nil
        isWorkerRunning = false
        pendingBoundedWork.removeAll()
        pendingUnboundedWork = PendingWork()
        resumeAllWorkWaiters()

        let namespace = try? NightscoutBaseURL(normalizing: SharedData.nightscoutURL)
        let discardedCount: Int
        if let namespace {
            discardedCount = try outbox().forget(namespace: namespace)
            clients.removeValue(forKey: namespace.absoluteString)
            resetBlockingState(for: namespace)
        } else {
            discardedCount = 0
            resetAllBlockingState()
        }

        SharedData.nightscoutURL = ""
        SharedData.nightscoutUploadEnabled = false
        lastAutomaticConfigurationSignature = nil
        status.reset()
        return discardedCount
    }

    // MARK: - Explicit serialized worker

    private func enqueue(_ work: PendingWork) {
        guard NightscoutExecutionContext.isMainAppProcess, !work.isEmpty else { return }
        if work.deadline == nil {
            pendingUnboundedWork.merge(work)
        } else {
            // A BG deadline belongs only to the lifecycle pass that created it.
            // Keeping bounded work separate prevents hot-path pushes from
            // inheriting a deadline that may expire before they are processed.
            pendingBoundedWork.append(work)
        }
        guard !isWorkerRunning else { return }

        let workerGeneration = configurationGeneration
        isWorkerRunning = true
        workerTask = Task { @MainActor [weak self] in
            await self?.runWorker(configurationGeneration: workerGeneration)
        }
    }

    private func runWorker(configurationGeneration workerGeneration: UInt) async {
        while workerGeneration == configurationGeneration,
              !Task.isCancelled,
              (!pendingBoundedWork.isEmpty || !pendingUnboundedWork.isEmpty) {
            let work: PendingWork
            if !pendingBoundedWork.isEmpty {
                work = pendingBoundedWork.removeFirst()
            } else {
                work = pendingUnboundedWork
                pendingUnboundedWork = PendingWork()
            }
            await perform(work, configurationGeneration: workerGeneration)
            resumeWorkWaiters(work.completionIDs)
        }

        guard workerGeneration == configurationGeneration else { return }
        isWorkerRunning = false
        workerTask = nil
    }

    /// Registers the continuation before enqueueing so even an immediately
    /// completed pass cannot lose its wake-up. Both normal completion and the
    /// deadline/cancellation paths remove the continuation before resuming it,
    /// making races between those paths harmless and resumption idempotent.
    private func enqueueAndWait(_ work: PendingWork, completionID: UUID) async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                workWaiters[completionID] = continuation
                if let deadline = work.deadline {
                    workDeadlineTasks[completionID] = Task { @MainActor [weak self] in
                        let remaining = deadline.timeIntervalSinceNow
                        if remaining > 0 {
                            try? await Task.sleep(
                                nanoseconds: UInt64(remaining * 1_000_000_000)
                            )
                        }
                        guard !Task.isCancelled else { return }
                        self?.resumeWorkWaiter(completionID)
                    }
                }
                enqueue(work)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resumeWorkWaiter(completionID)
            }
        }
    }

    private func resumeWorkWaiters(_ completionIDs: Set<UUID>) {
        for completionID in completionIDs {
            resumeWorkWaiter(completionID)
        }
    }

    private func resumeWorkWaiter(_ completionID: UUID) {
        workDeadlineTasks.removeValue(forKey: completionID)?.cancel()
        workWaiters.removeValue(forKey: completionID)?.resume()
    }

    private func resumeAllWorkWaiters() {
        for completionID in Array(workWaiters.keys) {
            resumeWorkWaiter(completionID)
        }
    }

    private func perform(
        _ work: PendingWork,
        configurationGeneration passGeneration: UInt
    ) async {
        let pass = NetworkPassState(configurationGeneration: passGeneration)
        guard isCurrent(pass), !Task.isCancelled else { return }
        guard let context = automaticNetworkContext(),
              shouldAttemptNetwork(for: context.baseURL, pass: pass) else { return }
        guard work.deadline.map({ $0 > Date() }) ?? true else { return }

        defer {
            if isCurrent(pass), pass.hadNetworkSuccess {
                status.recordSuccessfulPass()
            }
        }

        var shouldContinue = true
        if !work.glucoseUploads.isEmpty {
            shouldContinue = await reconcileGlucoseUploads(
                Array(work.glucoseUploads.values),
                sensorSerial: work.glucoseSensorSerial ?? "",
                context: context,
                pass: pass,
                deadline: work.deadline
            )
        }
        if work.drainInsulin, shouldContinue {
            await drainInsulin(context: context, pass: pass, deadline: work.deadline)
        }
    }

    // MARK: - Glucose reconciliation

    private func reconcileGlucoseUploads(
        _ uploads: [PendingGlucoseUpload],
        sensorSerial: String,
        context: NetworkContext,
        pass: NetworkPassState,
        deadline: Date?
    ) async -> Bool {
        guard !sensorSerial.isEmpty,
              let lowestLifeCount = uploads.map(\.lifeCount).min(),
              let highestLifeCount = uploads.map(\.lifeCount).max() else {
            return true
        }
        let batchBounds = lowestLifeCount...highestLifeCount
        var coverage = context.outbox.minuteCoverage(
            namespace: context.baseURL,
            sensorSerial: sensorSerial
        )
        var confirmations: [NightscoutGlucosePassConfirmation] = []
        var confirmedMinuteLifeCounts = Set<Int>()

        func finish(_ shouldContinue: Bool) -> Bool {
            guard isCurrent(pass) else { return false }
            guard !confirmations.isEmpty || !confirmedMinuteLifeCounts.isEmpty else {
                return shouldContinue
            }
            do {
                try context.outbox.confirmGlucosePass(
                    confirmations,
                    confirmedMinuteLifeCounts: confirmedMinuteLifeCounts,
                    sensorSerial: sensorSerial,
                    namespace: context.baseURL
                )
                return shouldContinue
            } catch {
                Self.logger.error("Failed to persist the completed Nightscout glucose pass.")
                return false
            }
        }

        // Establish minute ownership before evaluating history. A minute and
        // historical reading for one lifeCount can have different timestamp-
        // derived identifiers, so dictionary deduplication cannot prevent a
        // twin; the coverage check below is the authoritative arbitration.
        let minuteUploads = uploads
            .filter { $0.provenance == .minute }
            .sorted { $0.upload.eventDate < $1.upload.eventDate }
        for candidate in minuteUploads {
            guard isCurrent(pass), !Task.isCancelled,
                  deadline.map({ $0 > Date() }) ?? true else {
                return finish(false)
            }
            let upload = candidate.upload
            let fingerprint = upload.fingerprint
            if context.outbox.glucoseFingerprint(
                for: upload.identifier,
                namespace: context.baseURL
            )?.fingerprint == fingerprint {
                if !coverage.contains(candidate.lifeCount) {
                    coverage.insert(candidate.lifeCount)
                    confirmedMinuteLifeCounts.insert(candidate.lifeCount)
                }
                continue
            }
            switch await putGlucoseDocument(
                upload,
                fingerprint: fingerprint,
                context: context,
                pass: pass,
                deadline: deadline
            ) {
            case .confirmed:
                confirmations.append(NightscoutGlucosePassConfirmation(
                    upload: upload,
                    confirmedAt: Date()
                ))
                coverage.insert(candidate.lifeCount)
                confirmedMinuteLifeCounts.insert(candidate.lifeCount)
            case .skipped:
                continue
            case .stop:
                return finish(false)
            }
        }

        let historicalUploads = uploads
            .filter { $0.provenance == .historical }
            .sorted { $0.upload.eventDate < $1.upload.eventDate }
        for candidate in historicalUploads {
            guard isCurrent(pass), !Task.isCancelled,
                  deadline.map({ $0 > Date() }) ?? true else {
                return finish(false)
            }
            guard let runWidth = coverage.uncoveredRunWidth(
                containing: candidate.lifeCount,
                batchBounds: batchBounds
            ), runWidth >= Self.minimumFillableGapMinutes else {
                continue
            }
            let upload = candidate.upload
            let fingerprint = upload.fingerprint
            if context.outbox.glucoseFingerprint(
                for: upload.identifier,
                namespace: context.baseURL
            )?.fingerprint == fingerprint {
                continue
            }
            switch await putGlucoseDocument(
                upload,
                fingerprint: fingerprint,
                context: context,
                pass: pass,
                deadline: deadline
            ) {
            case .confirmed:
                confirmations.append(NightscoutGlucosePassConfirmation(
                    upload: upload,
                    confirmedAt: Date()
                ))
            case .skipped:
                continue
            case .stop:
                return finish(false)
            }
        }
        return finish(true)
    }

    private func putGlucoseDocument(
        _ upload: NightscoutEntryUpload,
        fingerprint: String,
        context: NetworkContext,
        pass: NetworkPassState,
        deadline: Date?
    ) async -> GlucoseDocumentOutcome {
        guard isCurrent(pass), !Task.isCancelled else { return .stop }
        let identifierKey = context.baseURL.absoluteString
            + "|"
            + upload.identifier.uuidString.lowercased()
        if isGlucoseDocumentSuppressed(key: identifierKey, fingerprint: fingerprint) {
            return .skipped
        }
        do {
            try await withBackoff(deadline: deadline) {
                guard markNetworkAttemptStarting(for: context.baseURL, pass: pass) else {
                    throw CancellationError()
                }
                try await context.client.putEntry(
                    identifier: upload.identifier,
                    body: upload.body,
                    accessToken: context.accessToken,
                    deadline: deadline
                )
            }
            guard isCurrent(pass) else { return .stop }
            markNetworkSuccess(for: context.baseURL, pass: pass)
            blockedGlucoseFingerprints.removeValue(forKey: identifierKey)
            return .confirmed
        } catch let error as NightscoutClientError {
            guard isCurrent(pass) else { return .stop }
            switch handleClientFailure(
                error,
                operation: "entry PUT",
                baseURL: context.baseURL,
                glucoseSuppression: (identifierKey, fingerprint),
                insulinRevision: nil,
                pass: pass
            ) {
            case .documentSuppressed:
                return .skipped
            case .namespaceCircuitOpened, .retryLater:
                return .stop
            }
        } catch is CancellationError {
            markNetworkAttemptDeferred(for: context.baseURL, pass: pass)
            return .stop
        } catch {
            Self.logger.error("Nightscout entry upload stopped after a local cancellation error.")
            return .stop
        }
    }

    // MARK: - Insulin convergence

    private func drainInsulin(
        context: NetworkContext,
        pass: NetworkPassState,
        deadline: Date?
    ) async {
        let items = context.outbox.pendingInsulinItems(namespace: context.baseURL)
        for item in items {
            guard isCurrent(pass), !Task.isCancelled,
                  deadline.map({ $0 > Date() }) ?? true else { return }
            let shouldContinue = await convergeInsulinItem(
                identifier: item.id,
                context: context,
                pass: pass,
                deadline: deadline
            )
            if !shouldContinue { return }
        }
    }

    /// Returns false when a namespace-wide or retryable failure should stop
    /// this drain pass.
    private func convergeInsulinItem(
        identifier: UUID,
        context: NetworkContext,
        pass: NetworkPassState,
        deadline: Date?
    ) async -> Bool {
        while let current = context.outbox.insulinItem(
            identifier: identifier,
            namespace: context.baseURL
        ) {
            guard isCurrent(pass), !Task.isCancelled,
                  deadline.map({ $0 > Date() }) ?? true else { return false }
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
                        context: context,
                        pass: pass,
                        deadline: deadline
                    ) {
                        guard markNetworkAttemptStarting(for: context.baseURL, pass: pass) else {
                            throw CancellationError()
                        }
                        try await context.client.putTreatment(
                            identifier: payload.identifier,
                            body: payload.body,
                            accessToken: context.accessToken,
                            deadline: deadline
                        )
                    }
                    if case .superseded = outcome { continue }
                    guard isCurrent(pass) else { return false }
                    markNetworkSuccess(for: context.baseURL, pass: pass)
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
                        insulinRevision: started.revision,
                        pass: pass
                    ) {
                    case .documentSuppressed:
                        return true
                    case .namespaceCircuitOpened, .retryLater:
                        return false
                    }
                } catch is CancellationError {
                    markNetworkAttemptDeferred(for: context.baseURL, pass: pass)
                    return false
                } catch {
                    Self.logger.error("Nightscout insulin upload stopped after a local persistence or cancellation error.")
                    return false
                }

            case .absent(let tombstone):
                do {
                    let outcome = try await withInsulinBackoff(
                        identifier: identifier,
                        expectedRevision: current.revision,
                        context: context,
                        pass: pass,
                        deadline: deadline
                    ) {
                        guard markNetworkAttemptStarting(for: context.baseURL, pass: pass) else {
                            throw CancellationError()
                        }
                        try await context.client.deleteTreatment(
                            identifier: tombstone.identifier,
                            accessToken: context.accessToken,
                            deadline: deadline
                        )
                    }
                    if case .superseded = outcome { continue }
                    guard isCurrent(pass) else { return false }
                    markNetworkSuccess(for: context.baseURL, pass: pass)
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
                        insulinRevision: current.revision,
                        pass: pass
                    ) {
                    case .documentSuppressed:
                        return true
                    case .namespaceCircuitOpened, .retryLater:
                        return false
                    }
                } catch is CancellationError {
                    markNetworkAttemptDeferred(for: context.baseURL, pass: pass)
                    return false
                } catch {
                    Self.logger.error("Nightscout insulin deletion stopped after a local persistence or cancellation error.")
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Configuration and persistence gates

    private func isCurrent(_ pass: NetworkPassState) -> Bool {
        pass.configurationGeneration == configurationGeneration
    }

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
        minuteCandidates: [LibreLinkUpGlucose],
        historicalCandidates: [LibreLinkUpGlucose]
    ) -> [String: PendingGlucoseUpload] {
        var uploads: [String: PendingGlucoseUpload] = [:]

        func add(
            _ candidates: [LibreLinkUpGlucose],
            provenance: NightscoutGlucoseProvenance
        ) {
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
                let key = upload.identifier.uuidString.lowercased()
                let pendingUpload = PendingGlucoseUpload(
                    upload: upload,
                    lifeCount: candidate.glucose.id,
                    provenance: provenance
                )
                if uploads[key]?.provenance != .minute || provenance == .minute {
                    uploads[key] = pendingUpload
                }
            }
        }

        add(historicalCandidates, provenance: .historical)
        add(minuteCandidates, provenance: .minute)
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
        pass: NetworkPassState,
        now: Date = Date()
    ) -> Bool {
        guard isCurrent(pass) else { return false }
        if let nextRetryAt = retryNotBefore[baseURL.absoluteString] {
            guard now >= nextRetryAt else { return false }
            retryNotBefore.removeValue(forKey: baseURL.absoluteString)
        }
        guard var breaker = namespaceCircuitBreakers[baseURL.absoluteString] else {
            return true
        }
        guard now >= breaker.nextProbeAt else { return false }

        // Move the next probe before starting this one so repeated triggers do
        // not create a burst if the half-open pass contains no eligible work.
        breaker.nextProbeAt = now.addingTimeInterval(Self.circuitHalfOpenInterval)
        namespaceCircuitBreakers[baseURL.absoluteString] = breaker
        status.markPaused(reason: breaker.reason, until: breaker.nextProbeAt)
        Self.logger.info(
            "Nightscout circuit half-open; attempting one recovery pass after HTTP \(breaker.statusCode, privacy: .public)."
        )
        return true
    }

    private func markNetworkAttemptStarting(
        for baseURL: NightscoutBaseURL,
        pass: NetworkPassState
    ) -> Bool {
        guard isCurrent(pass), !Task.isCancelled else { return false }
        guard namespaceCircuitBreakers[baseURL.absoluteString] != nil else { return true }
        status.markRetrying()
        return true
    }

    private func markNetworkAttemptDeferred(
        for baseURL: NightscoutBaseURL,
        pass: NetworkPassState
    ) {
        guard isCurrent(pass) else { return }
        guard let breaker = namespaceCircuitBreakers[baseURL.absoluteString] else { return }
        status.markPaused(reason: breaker.reason, until: breaker.nextProbeAt)
    }

    private func markNetworkSuccess(
        for baseURL: NightscoutBaseURL,
        pass: NetworkPassState
    ) {
        guard isCurrent(pass) else { return }
        retryNotBefore.removeValue(forKey: baseURL.absoluteString)
        if namespaceCircuitBreakers.removeValue(forKey: baseURL.absoluteString) != nil {
            Self.logger.info("Nightscout circuit closed after a successful authenticated v3 request.")
        }
        pass.hadNetworkSuccess = true
        status.markReady()
    }

    /// Applies the failure policy at the narrowest safe scope:
    /// - authentication and missing-v3-endpoint failures pause the namespace;
    /// - permanent payload failures suppress only that document revision;
    /// - retryable transport, rate-limit, and server failures end this pass.
    /// A later lifecycle/hot-path reconciliation supplies the recovery retry.
    private func handleClientFailure(
        _ error: NightscoutClientError,
        operation: String,
        baseURL: NightscoutBaseURL,
        glucoseSuppression: (key: String, fingerprint: String)?,
        insulinRevision: UUID?,
        pass: NetworkPassState
    ) -> FailureDisposition {
        guard isCurrent(pass) else { return .retryLater }
        let namespaceFailureReason: NightscoutUploadStatus.PauseReason?
        switch error {
        case .httpStatus(let code, _, _):
            if code == 401 || code == 403 {
                namespaceFailureReason = .credentialsRejected
            } else if code == 404 || code == 405 || code == 410 {
                namespaceFailureReason = .endpointUnavailable
            } else {
                namespaceFailureReason = nil
            }
        case .invalidBaseURL:
            namespaceFailureReason = .invalidServerURL
        case .missingAccessToken, .invalidAuthorizationResponse:
            namespaceFailureReason = .authorizationUnavailable
        case .requestEncoding, .invalidResponse, .transport:
            namespaceFailureReason = nil
        }
        if let namespaceFailureReason {
            openCircuit(
                for: baseURL,
                error: error,
                reason: namespaceFailureReason,
                operation: operation,
                pass: pass
            )
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
            status.markDocumentRejected()
            logClientFailure(error, operation: operation, disposition: "document suppressed")
            return .documentSuppressed
        }

        if let retryAfter = error.retryAfter, retryAfter > 0 {
            let namespace = baseURL.absoluteString
            let requestedRetryAt = Date().addingTimeInterval(retryAfter)
            retryNotBefore[namespace] = max(
                retryNotBefore[namespace] ?? .distantPast,
                requestedRetryAt
            )
        }
        status.markRetryDeferred()
        logClientFailure(error, operation: operation, disposition: "retry deferred")
        return .retryLater
    }

    private func openCircuit(
        for baseURL: NightscoutBaseURL,
        error: NightscoutClientError,
        reason: NightscoutUploadStatus.PauseReason,
        operation: String,
        pass: NetworkPassState,
        now: Date = Date()
    ) {
        guard isCurrent(pass) else { return }
        let nextProbeAt = now.addingTimeInterval(Self.circuitHalfOpenInterval)
        namespaceCircuitBreakers[baseURL.absoluteString] = NamespaceCircuitBreaker(
            statusCode: error.statusCode ?? 0,
            reason: reason,
            nextProbeAt: nextProbeAt
        )
        status.markPaused(reason: reason, until: nextProbeAt)
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
        retryNotBefore.removeValue(forKey: baseURL.absoluteString)
        blockedGlucoseFingerprints = blockedGlucoseFingerprints.filter {
            !$0.key.hasPrefix(prefix)
        }
        blockedInsulinRevisions = blockedInsulinRevisions.filter {
            !$0.key.hasPrefix(prefix)
        }
        status.markReady()
    }

    private func resetAllBlockingState() {
        namespaceCircuitBreakers.removeAll()
        retryNotBefore.removeAll()
        blockedGlucoseFingerprints.removeAll()
        blockedInsulinRevisions.removeAll()
        status.markReady()
    }

    private func withBackoff<T>(
        deadline: Date?,
        operation: () async throws -> T
    ) async throws -> T {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            let currentDeadline = deadline
            if let currentDeadline, currentDeadline <= Date() { throw CancellationError() }
            do {
                return try await operation()
            } catch let error as NightscoutClientError {
                guard error.isRetryable, attempt < 2 else { throw error }
                let exponentialDelay = pow(2.0, Double(attempt))
                guard let delay = try retryDelay(
                    requested: error.retryAfter ?? exponentialDelay,
                    deadline: deadline
                ) else { throw error }
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
        pass: NetworkPassState,
        deadline: Date?,
        operation: () async throws -> T
    ) async throws -> InsulinOperationOutcome<T> {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            guard isCurrent(pass) else { return .superseded }
            let currentDeadline = deadline
            if let currentDeadline, currentDeadline <= Date() { throw CancellationError() }
            do {
                let value = try await operation()
                guard isCurrent(pass),
                      context.outbox.insulinItem(
                    identifier: identifier,
                    namespace: context.baseURL
                )?.revision == expectedRevision else {
                    return .superseded
                }
                return .completed(value)
            } catch let error as NightscoutClientError {
                guard isCurrent(pass),
                      context.outbox.insulinItem(
                    identifier: identifier,
                    namespace: context.baseURL
                )?.revision == expectedRevision else {
                    return .superseded
                }
                guard error.isRetryable, attempt < 2 else { throw error }
                let exponentialDelay = pow(2.0, Double(attempt))
                guard let delay = try retryDelay(
                    requested: error.retryAfter ?? exponentialDelay,
                    deadline: deadline
                ) else { throw error }
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard isCurrent(pass),
                      context.outbox.insulinItem(
                    identifier: identifier,
                    namespace: context.baseURL
                )?.revision == expectedRevision else {
                    return .superseded
                }
            }
        }
    }

    private func retryDelay(requested: TimeInterval, deadline: Date?) throws -> TimeInterval? {
        // A longer server-directed delay ends this pass. The namespace-level
        // retryNotBefore value prevents later triggers from retrying early.
        guard requested <= Self.maximumBackoffDuration else { return nil }
        let delay = max(requested, 1)
        if let deadline, deadline.timeIntervalSinceNow <= delay {
            throw CancellationError()
        }
        return delay
    }

}
