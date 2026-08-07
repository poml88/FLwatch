//
//  NightscoutOutbox.swift
//  LibreWrist
//
//  URL-namespaced durable state for glucose reconciliation and insulin
//  desired-state convergence.
//

import Foundation

struct NightscoutGlucoseFingerprintRecord: Codable, Equatable, Sendable {
    let fingerprint: String
    let eventDate: Date
    let confirmedAt: Date
}

/// Compact ownership record for lifeCounts that were confirmed from the raw
/// minute stream. Ranges are always sorted, disjoint, and non-adjacent.
struct NightscoutMinuteCoverage: Equatable, Sendable {
    private(set) var coveredMinutes: [ClosedRange<Int>]

    init(_ coveredMinutes: [ClosedRange<Int>] = []) {
        self.coveredMinutes = Self.normalized(coveredMinutes)
    }

    func contains(_ lifeCount: Int) -> Bool {
        coveredMinutes.contains { $0.contains(lifeCount) }
    }

    mutating func insert(_ lifeCount: Int) {
        coveredMinutes = Self.normalized(coveredMinutes + [lifeCount...lifeCount])
    }

    mutating func formUnion(_ lifeCounts: Set<Int>) {
        guard !lifeCounts.isEmpty else { return }
        coveredMinutes = Self.normalized(
            coveredMinutes + lifeCounts.map { $0...$0 }
        )
    }

    /// Returns the inclusive width of the uncovered run containing lifeCount,
    /// bounded by the current candidate batch when coverage is absent on a side.
    func uncoveredRunWidth(
        containing lifeCount: Int,
        batchBounds: ClosedRange<Int>
    ) -> Int? {
        guard batchBounds.contains(lifeCount), !contains(lifeCount) else { return nil }
        let previousUpper = coveredMinutes.last { $0.upperBound < lifeCount }?.upperBound
        let nextLower = coveredMinutes.first { $0.lowerBound > lifeCount }?.lowerBound
        let lowerBound = max(
            previousUpper.map { $0 + 1 } ?? batchBounds.lowerBound,
            batchBounds.lowerBound
        )
        let upperBound = min(
            nextLower.map { $0 - 1 } ?? batchBounds.upperBound,
            batchBounds.upperBound
        )
        guard lowerBound <= lifeCount, lifeCount <= upperBound else { return nil }
        return upperBound - lowerBound + 1
    }

    private static func normalized(
        _ ranges: [ClosedRange<Int>]
    ) -> [ClosedRange<Int>] {
        let sorted = ranges.sorted {
            if $0.lowerBound == $1.lowerBound {
                return $0.upperBound < $1.upperBound
            }
            return $0.lowerBound < $1.lowerBound
        }
        guard var current = sorted.first else { return [] }
        var result: [ClosedRange<Int>] = []
        for range in sorted.dropFirst() {
            let isAdjacent = current.upperBound < Int.max
                && range.lowerBound == current.upperBound + 1
            if range.lowerBound <= current.upperBound || isAdjacent {
                current = current.lowerBound...max(current.upperBound, range.upperBound)
            } else {
                result.append(current)
                current = range
            }
        }
        result.append(current)
        return result
    }
}

struct NightscoutGlucosePassConfirmation: Sendable {
    let upload: NightscoutEntryUpload
    let confirmedAt: Date
}

struct NightscoutInsulinTombstone: Codable, Equatable, Sendable {
    let identifier: UUID
    let requestedAt: Date
}

/// The latest local intent for one treatment. `uploadAttempted` distinguishes
/// a purely local pending PUT—which a delete can cancel—from a treatment that
/// may already exist remotely and therefore requires a durable DELETE.
enum NightscoutInsulinDesiredState: Codable, Equatable, Sendable {
    case present(payload: NightscoutTreatmentUpload, uploadAttempted: Bool)
    case absent(NightscoutInsulinTombstone)

    private enum CodingKeys: String, CodingKey {
        case kind
        case payload
        case uploadAttempted
        case tombstone
    }

    private enum Kind: String, Codable {
        case present
        case absent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .present:
            self = .present(
                payload: try container.decode(NightscoutTreatmentUpload.self, forKey: .payload),
                uploadAttempted: try container.decode(Bool.self, forKey: .uploadAttempted)
            )
        case .absent:
            self = .absent(try container.decode(NightscoutInsulinTombstone.self, forKey: .tombstone))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .present(let payload, let uploadAttempted):
            try container.encode(Kind.present, forKey: .kind)
            try container.encode(payload, forKey: .payload)
            try container.encode(uploadAttempted, forKey: .uploadAttempted)
        case .absent(let tombstone):
            try container.encode(Kind.absent, forKey: .kind)
            try container.encode(tombstone, forKey: .tombstone)
        }
    }
}

/// A revision changes whenever local intent changes. Network completions may
/// resolve only the revision they started with, preventing a stale PUT or
/// DELETE from erasing a newer desired state queued during its suspension.
struct NightscoutInsulinOutboxItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let revision: UUID
    var desiredState: NightscoutInsulinDesiredState
    var updatedAt: Date
}

enum NightscoutAbsentRecordingResult: Equatable, Sendable {
    case queuedDeletion
    case cancelledUnstartedUpload
    case unchanged
}

final class NightscoutOutbox {
    private struct StoredMinuteRange: Codable, Equatable {
        let lowerBound: Int
        let upperBound: Int

        var range: ClosedRange<Int>? {
            guard lowerBound <= upperBound else { return nil }
            return lowerBound...upperBound
        }
    }

    private struct MinuteCoverageState: Codable, Equatable {
        let sensorSerial: String
        let coveredMinutes: [StoredMinuteRange]

        private enum CodingKeys: String, CodingKey {
            case sensorSerial
            case coveredMinutes
        }

        init(sensorSerial: String, coverage: NightscoutMinuteCoverage) {
            self.sensorSerial = sensorSerial
            self.coveredMinutes = coverage.coveredMinutes.map {
                StoredMinuteRange(lowerBound: $0.lowerBound, upperBound: $0.upperBound)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let serial = try container.decodeIfPresent(String.self, forKey: .sensorSerial) ?? ""
            let storedRanges = try container.decodeIfPresent(
                [StoredMinuteRange].self,
                forKey: .coveredMinutes
            ) ?? []
            self.init(
                sensorSerial: serial,
                coverage: NightscoutMinuteCoverage(storedRanges.compactMap(\.range))
            )
        }

        var coverage: NightscoutMinuteCoverage {
            NightscoutMinuteCoverage(coveredMinutes.compactMap(\.range))
        }
    }

    private struct NamespaceState: Codable, Equatable {
        var glucoseFingerprints: [String: NightscoutGlucoseFingerprintRecord] = [:]
        var insulinItems: [String: NightscoutInsulinOutboxItem] = [:]
        var minuteCoverage: MinuteCoverageState?

        private enum CodingKeys: String, CodingKey {
            case glucoseFingerprints
            case insulinItems
            case minuteCoverage
        }

        init() {}

        init(from decoder: Decoder) throws {
            // Schema 1 has no minuteCoverage key. decodeIfPresent keeps that
            // deployed snapshot readable instead of bricking the whole outbox.
            let container = try decoder.container(keyedBy: CodingKeys.self)
            glucoseFingerprints = try container.decodeIfPresent(
                [String: NightscoutGlucoseFingerprintRecord].self,
                forKey: .glucoseFingerprints
            ) ?? [:]
            insulinItems = try container.decodeIfPresent(
                [String: NightscoutInsulinOutboxItem].self,
                forKey: .insulinItems
            ) ?? [:]
            minuteCoverage = try container.decodeIfPresent(
                MinuteCoverageState.self,
                forKey: .minuteCoverage
            )
            if let minuteCoverage {
                self.minuteCoverage = MinuteCoverageState(
                    sensorSerial: minuteCoverage.sensorSerial,
                    coverage: minuteCoverage.coverage
                )
            }
        }
    }

    private struct Snapshot: Codable {
        var schemaVersion: Int = 2
        var namespaces: [String: NamespaceState] = [:]
    }

    // Coverage is the long-lived minute dedup record. Fingerprints only need
    // to span the retained glucose window for historical fills/value changes.
    private static let glucoseFingerprintRetention: TimeInterval = 13 * 60 * 60
    private static let maximumGlucoseFingerprintsPerNamespace = 2_000

    private let fileManager: FileManager
    private let storeURL: URL
    private let encoder: JSONEncoder
    private var snapshot: Snapshot
    /// Successful atomic writes performed by this instance; exposed internally
    /// so the catch-up write-amplification regression test can assert one pass.
    private(set) var persistenceWriteCount = 0

    convenience init(fileManager: FileManager = .default) throws {
        try self.init(
            fileManager: fileManager,
            storeURL: FileStoreIO.makeStoreURL(
                fileName: "nightscout-outbox.json",
                using: fileManager,
                appGroupID: SharedDefaults.appGroupID
            )
        )
    }

    init(fileManager: FileManager, storeURL: URL) throws {
        self.fileManager = fileManager
        self.storeURL = storeURL
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var loadedSnapshot = try FileStoreIO.readSnapshot(
            Snapshot.self,
            from: storeURL,
            using: decoder,
            fileManager: fileManager
        ) ?? Snapshot()
        loadedSnapshot.schemaVersion = 2
        self.snapshot = loadedSnapshot
    }

    func glucoseFingerprint(
        for identifier: UUID,
        namespace: NightscoutBaseURL
    ) -> NightscoutGlucoseFingerprintRecord? {
        snapshot.namespaces[namespace.absoluteString]?
            .glucoseFingerprints[Self.key(for: identifier)]
    }

    func minuteCoverage(
        namespace: NightscoutBaseURL,
        sensorSerial: String
    ) -> NightscoutMinuteCoverage {
        guard !sensorSerial.isEmpty,
              let storedCoverage = snapshot.namespaces[namespace.absoluteString]?.minuteCoverage,
              storedCoverage.sensorSerial == sensorSerial else {
            return NightscoutMinuteCoverage()
        }
        return storedCoverage.coverage
    }

    /// Commits all successful PUT fingerprints and minute-ownership changes in
    /// one atomic snapshot write. A crash before this commit only causes safe,
    /// idempotent re-PUTs during the next reconciliation.
    func confirmGlucosePass(
        _ confirmations: [NightscoutGlucosePassConfirmation],
        confirmedMinuteLifeCounts: Set<Int>,
        sensorSerial: String,
        namespace: NightscoutBaseURL,
        persistedAt: Date = Date()
    ) throws {
        let previousSnapshot = snapshot
        var state = namespaceState(for: namespace)
        for confirmation in confirmations {
            let upload = confirmation.upload
            state.glucoseFingerprints[Self.key(for: upload.identifier)] = NightscoutGlucoseFingerprintRecord(
                fingerprint: upload.fingerprint,
                eventDate: upload.eventDate,
                confirmedAt: confirmation.confirmedAt
            )
        }
        if !sensorSerial.isEmpty, !confirmedMinuteLifeCounts.isEmpty {
            var coverage = state.minuteCoverage?.sensorSerial == sensorSerial
                ? state.minuteCoverage?.coverage ?? NightscoutMinuteCoverage()
                : NightscoutMinuteCoverage()
            coverage.formUnion(confirmedMinuteLifeCounts)
            state.minuteCoverage = MinuteCoverageState(
                sensorSerial: sensorSerial,
                coverage: coverage
            )
        }
        Self.pruneGlucoseFingerprints(in: &state, now: persistedAt)
        guard state != namespaceState(for: namespace) else { return }
        snapshot.namespaces[namespace.absoluteString] = state
        try persistOrRollBack(to: previousSnapshot)
    }

    /// Replaces the durable desired state with a new, unattempted PUT. An
    /// identical existing payload is already the same intent and is left
    /// untouched so its revision and upload-attempt knowledge survive.
    func recordPresent(
        _ payload: NightscoutTreatmentUpload,
        namespace: NightscoutBaseURL,
        now: Date = Date()
    ) throws {
        let key = Self.key(for: payload.identifier)
        if let existing = snapshot.namespaces[namespace.absoluteString]?.insulinItems[key],
           case .present(let existingPayload, _) = existing.desiredState,
           existingPayload == payload {
            return
        }

        let previousSnapshot = snapshot
        var state = namespaceState(for: namespace)
        state.insulinItems[key] = NightscoutInsulinOutboxItem(
            id: payload.identifier,
            revision: UUID(),
            desiredState: .present(payload: payload, uploadAttempted: false),
            updatedAt: now
        )
        snapshot.namespaces[namespace.absoluteString] = state
        try persistOrRollBack(to: previousSnapshot)
    }

    /// Cancels an unstarted local PUT without producing network work. Once a
    /// PUT has started its outcome is uncertain, so absence must instead be
    /// represented by a durable tombstone and converged with DELETE.
    @discardableResult
    func recordAbsent(
        identifier: UUID,
        namespace: NightscoutBaseURL,
        now: Date = Date()
    ) throws -> NightscoutAbsentRecordingResult {
        let key = Self.key(for: identifier)
        let existing = snapshot.namespaces[namespace.absoluteString]?.insulinItems[key]

        if let existing {
            switch existing.desiredState {
            case .present(_, let uploadAttempted) where !uploadAttempted:
                let previousSnapshot = snapshot
                var state = namespaceState(for: namespace)
                state.insulinItems.removeValue(forKey: key)
                snapshot.namespaces[namespace.absoluteString] = state
                try persistOrRollBack(to: previousSnapshot)
                return .cancelledUnstartedUpload
            case .absent:
                return .unchanged
            case .present:
                break
            }
        }

        let previousSnapshot = snapshot
        var state = namespaceState(for: namespace)
        state.insulinItems[key] = NightscoutInsulinOutboxItem(
            id: identifier,
            revision: UUID(),
            desiredState: .absent(
                NightscoutInsulinTombstone(identifier: identifier, requestedAt: now)
            ),
            updatedAt: now
        )
        snapshot.namespaces[namespace.absoluteString] = state
        try persistOrRollBack(to: previousSnapshot)
        return .queuedDeletion
    }

    func insulinItem(
        identifier: UUID,
        namespace: NightscoutBaseURL
    ) -> NightscoutInsulinOutboxItem? {
        snapshot.namespaces[namespace.absoluteString]?.insulinItems[Self.key(for: identifier)]
    }

    func pendingInsulinItems(namespace: NightscoutBaseURL) -> [NightscoutInsulinOutboxItem] {
        guard let items = snapshot.namespaces[namespace.absoluteString]?.insulinItems.values else {
            return []
        }
        return items.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.updatedAt < $1.updatedAt
        }
    }

    /// Durably crosses the point after which a local delete must assume that
    /// the treatment could exist on the server. The revision guard rejects a
    /// stale worker that was superseded before it reached this point.
    func markUploadAttemptStarted(
        identifier: UUID,
        revision: UUID,
        namespace: NightscoutBaseURL,
        now: Date = Date()
    ) throws -> NightscoutInsulinOutboxItem? {
        let key = Self.key(for: identifier)
        guard var item = snapshot.namespaces[namespace.absoluteString]?.insulinItems[key],
              item.revision == revision,
              case .present(let payload, let uploadAttempted) = item.desiredState else {
            return nil
        }
        if uploadAttempted { return item }

        let previousSnapshot = snapshot
        item.desiredState = .present(payload: payload, uploadAttempted: true)
        item.updatedAt = now
        var state = namespaceState(for: namespace)
        state.insulinItems[key] = item
        snapshot.namespaces[namespace.absoluteString] = state
        try persistOrRollBack(to: previousSnapshot)
        return item
    }

    /// Removes an item only when the completed network operation still matches
    /// its revision. A concurrent user edit therefore remains queued.
    @discardableResult
    func resolveInsulinItem(
        identifier: UUID,
        expectedRevision: UUID,
        namespace: NightscoutBaseURL
    ) throws -> Bool {
        let key = Self.key(for: identifier)
        guard snapshot.namespaces[namespace.absoluteString]?.insulinItems[key]?.revision == expectedRevision else {
            return false
        }

        let previousSnapshot = snapshot
        var state = namespaceState(for: namespace)
        state.insulinItems.removeValue(forKey: key)
        snapshot.namespaces[namespace.absoluteString] = state
        try persistOrRollBack(to: previousSnapshot)
        return true
    }

    func unresolvedCount(namespace: NightscoutBaseURL) -> Int {
        snapshot.namespaces[namespace.absoluteString]?.insulinItems.count ?? 0
    }

    @discardableResult
    func forget(namespace: NightscoutBaseURL) throws -> Int {
        guard let state = snapshot.namespaces[namespace.absoluteString] else { return 0 }
        let unresolvedCount = state.insulinItems.count
        let previousSnapshot = snapshot
        snapshot.namespaces.removeValue(forKey: namespace.absoluteString)
        try persistOrRollBack(to: previousSnapshot)
        return unresolvedCount
    }

    private func namespaceState(for namespace: NightscoutBaseURL) -> NamespaceState {
        snapshot.namespaces[namespace.absoluteString] ?? NamespaceState()
    }

    private func persistOrRollBack(to previousSnapshot: Snapshot) throws {
        do {
            _ = try FileStoreIO.writeSnapshot(
                snapshot,
                to: storeURL,
                using: encoder,
                fileManager: fileManager
            )
            persistenceWriteCount += 1
        } catch {
            snapshot = previousSnapshot
            throw error
        }
    }

    private static func key(for identifier: UUID) -> String {
        identifier.uuidString.lowercased()
    }

    private static func pruneGlucoseFingerprints(in state: inout NamespaceState, now: Date) {
        let cutoff = now.addingTimeInterval(-glucoseFingerprintRetention)
        state.glucoseFingerprints = state.glucoseFingerprints.filter { _, record in
            record.eventDate >= cutoff
        }

        let excess = state.glucoseFingerprints.count - maximumGlucoseFingerprintsPerNamespace
        guard excess > 0 else { return }
        let oldestKeys = state.glucoseFingerprints
            .sorted { $0.value.eventDate < $1.value.eventDate }
            .prefix(excess)
            .map(\.key)
        for key in oldestKeys {
            state.glucoseFingerprints.removeValue(forKey: key)
        }
    }
}
