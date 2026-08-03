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
    private struct NamespaceState: Codable {
        var glucoseFingerprints: [String: NightscoutGlucoseFingerprintRecord] = [:]
        var insulinItems: [String: NightscoutInsulinOutboxItem] = [:]
    }

    private struct Snapshot: Codable {
        var schemaVersion: Int = 1
        var namespaces: [String: NamespaceState] = [:]
    }

    private static let glucoseFingerprintRetention: TimeInterval = 30 * 24 * 60 * 60
    private static let maximumGlucoseFingerprintsPerNamespace = 20_000

    private let fileManager: FileManager
    private let storeURL: URL
    private let encoder: JSONEncoder
    private var snapshot: Snapshot

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.storeURL = FileStoreIO.makeStoreURL(
            fileName: "nightscout-outbox.json",
            using: fileManager,
            appGroupID: SharedDefaults.appGroupID
        )
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.snapshot = try FileStoreIO.readSnapshot(
            Snapshot.self,
            from: storeURL,
            using: decoder,
            fileManager: fileManager
        ) ?? Snapshot()
    }

    func glucoseFingerprint(
        for identifier: UUID,
        namespace: NightscoutBaseURL
    ) -> NightscoutGlucoseFingerprintRecord? {
        snapshot.namespaces[namespace.absoluteString]?
            .glucoseFingerprints[Self.key(for: identifier)]
    }

    func confirmGlucose(
        _ upload: NightscoutEntryUpload,
        namespace: NightscoutBaseURL,
        confirmedAt: Date = Date()
    ) throws {
        let previousSnapshot = snapshot
        var state = namespaceState(for: namespace)
        state.glucoseFingerprints[Self.key(for: upload.identifier)] = NightscoutGlucoseFingerprintRecord(
            fingerprint: upload.fingerprint,
            eventDate: upload.eventDate,
            confirmedAt: confirmedAt
        )
        Self.pruneGlucoseFingerprints(in: &state, now: confirmedAt)
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
