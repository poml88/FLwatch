//
//  LibreLinkUpHistory.swift
//  LibreWrist
//
//  Created by Peter Müller on 10.09.24.
//

import Foundation
import OSLog
import SwiftUI

@MainActor
@Observable
final class LibreLinkUpHistoryStore {
    private static let persistenceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "LibreLinkUpHistoryStore"
    )

    private struct Snapshot: Codable {
        var fullLibreLinkUpGlucose: [LibreLinkUpGlucose]
        var libreLinkUpGlucose: [LibreLinkUpGlucose]
        var libreLinkUpMinuteGlucose: [LibreLinkUpGlucose]
        var latestLibreLinkUpGlucose: LibreLinkUpGlucose?
        var lastReadingDate: Date
        var currentGlucose: Int
        var currentTrendArrow: String
        var maxBG: Int
        var lastSuccessfulLibreLinkUpAPICall: Date
        var updatedAt: Date

        private enum CodingKeys: String, CodingKey {
            case fullLibreLinkUpGlucose
            case libreLinkUpGlucose
            case libreLinkUpMinuteGlucose
            case latestLibreLinkUpGlucose
            case lastReadingDate
            case currentGlucose
            case currentTrendArrow
            case maxBG
            case lastSuccessfulLibreLinkUpAPICall = "lastOnlineDate"
            case updatedAt
        }

        init(
            fullLibreLinkUpGlucose: [LibreLinkUpGlucose],
            libreLinkUpGlucose: [LibreLinkUpGlucose],
            libreLinkUpMinuteGlucose: [LibreLinkUpGlucose],
            latestLibreLinkUpGlucose: LibreLinkUpGlucose?,
            lastReadingDate: Date,
            currentGlucose: Int,
            currentTrendArrow: String,
            maxBG: Int,
            lastSuccessfulLibreLinkUpAPICall: Date,
            updatedAt: Date
        ) {
            self.fullLibreLinkUpGlucose = fullLibreLinkUpGlucose
            self.libreLinkUpGlucose = libreLinkUpGlucose
            self.libreLinkUpMinuteGlucose = libreLinkUpMinuteGlucose
            self.latestLibreLinkUpGlucose = latestLibreLinkUpGlucose
            self.lastReadingDate = lastReadingDate
            self.currentGlucose = currentGlucose
            self.currentTrendArrow = currentTrendArrow
            self.maxBG = maxBG
            self.lastSuccessfulLibreLinkUpAPICall = lastSuccessfulLibreLinkUpAPICall
            self.updatedAt = updatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let graphHistory = try container.decode([LibreLinkUpGlucose].self, forKey: .libreLinkUpGlucose)
            self.fullLibreLinkUpGlucose = try container.decodeIfPresent([LibreLinkUpGlucose].self, forKey: .fullLibreLinkUpGlucose) ?? graphHistory
            self.libreLinkUpGlucose = graphHistory
            self.libreLinkUpMinuteGlucose = try container.decode([LibreLinkUpGlucose].self, forKey: .libreLinkUpMinuteGlucose)
            self.latestLibreLinkUpGlucose = try container.decodeIfPresent(LibreLinkUpGlucose.self, forKey: .latestLibreLinkUpGlucose)
            self.lastReadingDate = try container.decode(Date.self, forKey: .lastReadingDate)
            self.currentGlucose = try container.decode(Int.self, forKey: .currentGlucose)
            self.currentTrendArrow = try container.decode(String.self, forKey: .currentTrendArrow)
            self.maxBG = try container.decode(Int.self, forKey: .maxBG)
            self.lastSuccessfulLibreLinkUpAPICall = try container.decode(Date.self, forKey: .lastSuccessfulLibreLinkUpAPICall)
            self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }

    // Legacy UserDefaults payload to support migration to file-based stores.
    private struct LegacySnapshot: Codable {
        var libreLinkUpGlucose: [LibreLinkUpGlucose]
        var libreLinkUpMinuteGlucose: [LibreLinkUpGlucose]
        var latestLibreLinkUpGlucose: LibreLinkUpGlucose?
        var lastReadingDate: Date
        var currentGlucose: Int
        var currentTrendArrow: String
        var maxBG: Int
        var lastOnlineDate: Date?
        var lastReloadAttemptDate: Date?
    }

    static let shared: LibreLinkUpHistoryStore = LibreLinkUpHistoryStore()

    private(set) var fullLibreLinkUpGlucose: [LibreLinkUpGlucose]
    private(set) var libreLinkUpGlucose: [LibreLinkUpGlucose]
    private(set) var libreLinkUpMinuteGlucose: [LibreLinkUpGlucose]
    private(set) var latestLibreLinkUpGlucose: LibreLinkUpGlucose?
    private(set) var lastReadingDate: Date
    private(set) var currentGlucose: Int // always in mg/dl
    private(set) var currentTrendArrow: String
    private(set) var maxBG: Int
    private(set) var lastSuccessfulLibreLinkUpAPICall: Date
    private(set) var updatedAt: Date

    private let fileManager: FileManager
    private let storeURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var lastKnownModificationDate: Date?

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.storeURL = FileStoreIO.makeStoreURL(
            fileName: "librelinkup-history.json",
            using: fileManager,
            appGroupID: SharedDefaults.appGroupID
        )
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        // NOTE: `.iso8601` writes whole seconds — a reading's fractional second does
        // not survive a persist/reload cycle. Anything keyed on a reading's date has
        // to be stable under that truncation; see `glucoseSyncIdentifier`, which
        // floors for exactly this reason and is also the change key a few lines into
        // `replaceCacheAndPersist`.
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        let storedSnapshot: Snapshot?
        var shouldRepairCorruptedStore = false
        do {
            storedSnapshot = try FileStoreIO.readSnapshot(
                Snapshot.self,
                from: storeURL,
                using: decoder,
                fileManager: fileManager
            )
        } catch let persistenceError as FileStorePersistenceError {
            if case .failedToDecodeSnapshot = persistenceError {
                shouldRepairCorruptedStore = true
            }
            Self.logPersistenceError(persistenceError, context: "Initialization read failed")
            storedSnapshot = nil
        } catch {
            Self.logPersistenceError(error, context: "Initialization read failed")
            storedSnapshot = nil
        }
        let initial = storedSnapshot
            ?? Self.readLegacySnapshotFromUserDefaults()
            ?? Self.defaultSnapshot()
        self.fullLibreLinkUpGlucose = initial.fullLibreLinkUpGlucose
        self.libreLinkUpGlucose = initial.libreLinkUpGlucose
        self.libreLinkUpMinuteGlucose = initial.libreLinkUpMinuteGlucose
        self.latestLibreLinkUpGlucose = initial.latestLibreLinkUpGlucose
        self.lastReadingDate = initial.lastReadingDate
        self.currentGlucose = initial.currentGlucose
        self.currentTrendArrow = initial.currentTrendArrow
        self.maxBG = initial.maxBG
        self.lastSuccessfulLibreLinkUpAPICall = initial.lastSuccessfulLibreLinkUpAPICall
        self.updatedAt = initial.updatedAt

        if fileManager.fileExists(atPath: storeURL.path) {
            if shouldRepairCorruptedStore {
                _ = persistCurrentSnapshot()
            } else {
                self.lastKnownModificationDate = FileStoreIO.modificationDate(at: storeURL, fileManager: fileManager)
            }
        } else {
            _ = persistCurrentSnapshot()
        }
    }

    @discardableResult
    func replaceCacheAndPersist(
        fullLibreLinkUpGlucose: [LibreLinkUpGlucose]? = nil,
        libreLinkUpGlucose: [LibreLinkUpGlucose],
        libreLinkUpMinuteGlucose: [LibreLinkUpGlucose],
        latestLibreLinkUpGlucose: LibreLinkUpGlucose?,
        lastReadingDate: Date,
        currentGlucose: Int,
        currentTrendArrow: String,
        maxBG: Int,
        lastSuccessfulLibreLinkUpAPICall: Date,
        updatedAt: Date = Date()
    ) -> Bool {
        let normalizedLatest = latestLibreLinkUpGlucose
            ?? libreLinkUpGlucose.first
            ?? libreLinkUpMinuteGlucose.first
        let normalizedFullGraphHistory = fullLibreLinkUpGlucose ?? libreLinkUpGlucose
        // Health export omits the newest live point, so only changes to the
        // remaining historical series should trigger a reconciliation.
        let previousExportIdentifiers = self.fullLibreLinkUpGlucose
            .dropFirst()
            .map { AppleHealthExportManager.glucoseSyncIdentifier(for: $0) }
        let nextExportIdentifiers = normalizedFullGraphHistory
            .dropFirst()
            .map { AppleHealthExportManager.glucoseSyncIdentifier(for: $0) }
        let shouldExportGlucose = !nextExportIdentifiers.isEmpty
            && nextExportIdentifiers != previousExportIdentifiers
        let nextSnapshot = Snapshot(
            fullLibreLinkUpGlucose: normalizedFullGraphHistory,
            libreLinkUpGlucose: libreLinkUpGlucose,
            libreLinkUpMinuteGlucose: libreLinkUpMinuteGlucose,
            latestLibreLinkUpGlucose: normalizedLatest,
            lastReadingDate: lastReadingDate,
            currentGlucose: currentGlucose,
            currentTrendArrow: currentTrendArrow,
            maxBG: maxBG,
            lastSuccessfulLibreLinkUpAPICall: lastSuccessfulLibreLinkUpAPICall,
            updatedAt: updatedAt
        )

        let modificationDate: Date
        do {
            modificationDate = try FileStoreIO.writeSnapshot(
                nextSnapshot,
                to: storeURL,
                using: encoder,
                fileManager: fileManager
            )
        } catch {
            Self.logPersistenceError(error, context: "replaceCacheAndPersist write failed")
            return false
        }

        let nightscoutMinuteCandidates: [LibreLinkUpGlucose]
        let nightscoutHistoricalCandidates: [LibreLinkUpGlucose]
        let nightscoutSensorSerial: String?
        if NightscoutExecutionContext.isMainAppProcess,
           SharedData.cgmProviderKind.isDirectBLE,
           SharedData.nightscoutUploadEnabled {
            nightscoutSensorSerial = SharedData.libre3Serial
            let previousMinuteLifeCounts = Set(
                self.libreLinkUpMinuteGlucose.map { $0.glucose.id }
            )
            let nextMinuteLifeCounts = Set(
                libreLinkUpMinuteGlucose.map { $0.glucose.id }
            )
            var changedHistoricalCandidates: [LibreLinkUpGlucose] = []
            // The existing Health identifier comparison tells the Nightscout
            // hot path when the retained historical series changed. This is
            // safe while retained Libre 3 values/directions remain immutable;
            // any future historical calibration or trend remapping must make
            // this a Nightscout-specific change check. The full lifecycle sweep
            // remains the recovery path.
            if shouldExportGlucose {
                changedHistoricalCandidates.append(contentsOf: Self.changedNightscoutCandidates(
                    previous: self.fullLibreLinkUpGlucose.filter {
                        !previousMinuteLifeCounts.contains($0.glucose.id)
                    },
                    next: normalizedFullGraphHistory.filter {
                        !nextMinuteLifeCounts.contains($0.glucose.id)
                    }
                ))
            }
            // Diff the complete bounded minute overlay so a clinical backfill
            // burst reaches Nightscout immediately instead of waiting for the
            // next retained-data sweep. The same signature comparison also keeps
            // steady-state pushes and overlay trimming idempotent.
            nightscoutMinuteCandidates = Self.changedNightscoutCandidates(
                previous: self.libreLinkUpMinuteGlucose,
                next: libreLinkUpMinuteGlucose
            )
            nightscoutHistoricalCandidates = changedHistoricalCandidates
        } else {
            nightscoutMinuteCandidates = []
            nightscoutHistoricalCandidates = []
            nightscoutSensorSerial = nil
        }

        apply(snapshot: nextSnapshot)
        lastKnownModificationDate = modificationDate
        if shouldExportGlucose {
            Task {
                await AppleHealthExportManager.shared.exportGlucoseSamplesIfNeeded(normalizedFullGraphHistory)
            }
        }
        if let nightscoutSensorSerial,
           (!nightscoutMinuteCandidates.isEmpty || !nightscoutHistoricalCandidates.isEmpty) {
            NightscoutUploadManager.shared.reconcileGlucose(
                minuteCandidates: nightscoutMinuteCandidates,
                historicalCandidates: nightscoutHistoricalCandidates,
                sensorSerial: nightscoutSensorSerial
            )
        }
        return true
    }

    nonisolated static func changedNightscoutCandidates(
        previous: [LibreLinkUpGlucose],
        next: [LibreLinkUpGlucose]
    ) -> [LibreLinkUpGlucose] {
        var previousSignatures: [NightscoutEntryIdentity: NightscoutEntryChangeSignature] = [:]
        for reading in previous
        where CGMReadingSource.directBLENightscoutSources.contains(reading.glucose.source) {
            let signature = NightscoutEntryChangeSignature(reading: reading)
            previousSignatures[signature.identity] = signature
        }

        var nextReadings: [
            NightscoutEntryIdentity: (
                signature: NightscoutEntryChangeSignature,
                reading: LibreLinkUpGlucose
            )
        ] = [:]
        for reading in next
        where CGMReadingSource.directBLENightscoutSources.contains(reading.glucose.source) {
            let signature = NightscoutEntryChangeSignature(reading: reading)
            nextReadings[signature.identity] = (signature, reading)
        }

        return nextReadings.compactMap { identity, value in
            previousSignatures[identity] == value.signature ? nil : value.reading
        }
    }

    /// Records that a reload succeeded without changing any reading.
    ///
    /// Deliberately does not route through `replaceCacheAndPersist`. That method
    /// derives its HealthKit and Nightscout work by diffing the incoming series
    /// against the stored one, so when the two are the same object the answer is
    /// always "nothing to export" — this path skips building those comparisons
    /// instead of computing empty results from them. Persisting and moving
    /// `updatedAt` is still required: the reload gate uses both timestamps to tell
    /// peer processes that a refresh completed.
    @discardableResult
    func updateLastSuccessfulLibreLinkUpAPICall(_ lastSuccessfulLibreLinkUpAPICall: Date = Date(), updatedAt: Date = Date()) -> Bool {
        let snapshot = Snapshot(
            fullLibreLinkUpGlucose: fullLibreLinkUpGlucose,
            libreLinkUpGlucose: libreLinkUpGlucose,
            libreLinkUpMinuteGlucose: libreLinkUpMinuteGlucose,
            latestLibreLinkUpGlucose: latestLibreLinkUpGlucose,
            lastReadingDate: lastReadingDate,
            currentGlucose: currentGlucose,
            currentTrendArrow: currentTrendArrow,
            maxBG: maxBG,
            lastSuccessfulLibreLinkUpAPICall: lastSuccessfulLibreLinkUpAPICall,
            updatedAt: updatedAt
        )

        let modificationDate: Date
        do {
            modificationDate = try FileStoreIO.writeSnapshot(
                snapshot,
                to: storeURL,
                using: encoder,
                fileManager: fileManager
            )
        } catch {
            Self.logPersistenceError(error, context: "updateLastSuccessfulLibreLinkUpAPICall write failed")
            return false
        }

        // Only the two timestamps can differ here, so `apply` writes just those.
        apply(snapshot: snapshot)
        lastKnownModificationDate = modificationDate
        return true
    }

    /// Refreshes the in-memory store from app-group persistence.
    /// Useful in widgets/intents where another process may have written newer data.
    @discardableResult
    func refreshFromPersistence(force: Bool = false) -> Bool {
        // Routine refreshes can skip the JSON decode when the file mtime is unchanged.
        let preflightModificationDate: Date? = force
            ? nil
            : FileStoreIO.modificationDate(at: storeURL, fileManager: fileManager)
        if !force,
           let preflightModificationDate,
           let lastKnownModificationDate,
           preflightModificationDate == lastKnownModificationDate {
            return false
        }

        let snapshot: Snapshot
        do {
            guard let loadedSnapshot = try FileStoreIO.readSnapshot(
                Snapshot.self,
                from: storeURL,
                using: decoder,
                fileManager: fileManager
            ) else {
                return false
            }
            snapshot = loadedSnapshot
        } catch {
            Self.logPersistenceError(error, context: "refreshFromPersistence read failed")
            return false
        }

        // Forced refreshes keep the original read-then-stat ordering.
        let diskModificationDate = force
            ? FileStoreIO.modificationDate(at: storeURL, fileManager: fileManager)
            : preflightModificationDate
        if !force {
            let isNewerByUpdatedAt = snapshot.updatedAt > updatedAt
            let isNewerByModificationDate: Bool = {
                guard let diskModificationDate,
                      let lastKnownModificationDate else {
                    return false
                }
                return diskModificationDate > lastKnownModificationDate
            }()
            guard isNewerByUpdatedAt || isNewerByModificationDate else {
                return false
            }
        }

        apply(snapshot: snapshot)
        lastKnownModificationDate = diskModificationDate
        return true
    }

    @available(*, deprecated, message: "Use refreshFromPersistence(force:) instead.")
    @discardableResult
    func refreshFromPersistedSnapshot() -> Bool {
        refreshFromPersistence()
    }

    @discardableResult
    private func persistCurrentSnapshot() -> Bool {
        let snapshot = Snapshot(
            fullLibreLinkUpGlucose: fullLibreLinkUpGlucose,
            libreLinkUpGlucose: libreLinkUpGlucose,
            libreLinkUpMinuteGlucose: libreLinkUpMinuteGlucose,
            latestLibreLinkUpGlucose: latestLibreLinkUpGlucose,
            lastReadingDate: lastReadingDate,
            currentGlucose: currentGlucose,
            currentTrendArrow: currentTrendArrow,
            maxBG: maxBG,
            lastSuccessfulLibreLinkUpAPICall: lastSuccessfulLibreLinkUpAPICall,
            updatedAt: updatedAt
        )
        let modificationDate: Date
        do {
            modificationDate = try FileStoreIO.writeSnapshot(
                snapshot,
                to: storeURL,
                using: encoder,
                fileManager: fileManager
            )
        } catch {
            Self.logPersistenceError(error, context: "persistCurrentSnapshot write failed")
            return false
        }
        lastKnownModificationDate = modificationDate
        return true
    }

    /// Publishes a snapshot, writing each property only when it actually moved.
    ///
    /// `@Observable` fires a mutation on every write without comparing values, and
    /// each mutation invalidates every observer — both home views, both graphs, the
    /// Live Activity and the widgets. Reloads that find nothing new still land here
    /// (a successful poll with no fresh reading, a duplicate BLE packet, a repeated
    /// watch snapshot), and rebuilding a chart costs orders of magnitude more than
    /// comparing the series that produced it, so the comparison always pays for
    /// itself. The two timestamps below move on nearly every call by design; they
    /// are gated only so that re-applying an identical snapshot is a complete no-op.
    private func apply(snapshot: Snapshot) {
        let normalizedLatest = snapshot.latestLibreLinkUpGlucose
            ?? snapshot.libreLinkUpGlucose.first
            ?? snapshot.libreLinkUpMinuteGlucose.first
        if fullLibreLinkUpGlucose != snapshot.fullLibreLinkUpGlucose {
            fullLibreLinkUpGlucose = snapshot.fullLibreLinkUpGlucose
        }
        if libreLinkUpGlucose != snapshot.libreLinkUpGlucose {
            libreLinkUpGlucose = snapshot.libreLinkUpGlucose
        }
        if libreLinkUpMinuteGlucose != snapshot.libreLinkUpMinuteGlucose {
            libreLinkUpMinuteGlucose = snapshot.libreLinkUpMinuteGlucose
        }
        if latestLibreLinkUpGlucose != normalizedLatest {
            latestLibreLinkUpGlucose = normalizedLatest
        }
        if lastReadingDate != snapshot.lastReadingDate {
            lastReadingDate = snapshot.lastReadingDate
        }
        if currentGlucose != snapshot.currentGlucose {
            currentGlucose = snapshot.currentGlucose
        }
        if currentTrendArrow != snapshot.currentTrendArrow {
            currentTrendArrow = snapshot.currentTrendArrow
        }
        if maxBG != snapshot.maxBG {
            maxBG = snapshot.maxBG
        }
        if lastSuccessfulLibreLinkUpAPICall != snapshot.lastSuccessfulLibreLinkUpAPICall {
            lastSuccessfulLibreLinkUpAPICall = snapshot.lastSuccessfulLibreLinkUpAPICall
        }
        if updatedAt != snapshot.updatedAt {
            updatedAt = snapshot.updatedAt
        }
    }

    private static func defaultSnapshot(now: Date = Date()) -> Snapshot {
        let graphHistory = defaultGraphEntries(now: now)
        let minuteHistory = defaultMinuteEntries(now: now)
        return Snapshot(
            fullLibreLinkUpGlucose: graphHistory,
            libreLinkUpGlucose: graphHistory,
            libreLinkUpMinuteGlucose: minuteHistory,
            latestLibreLinkUpGlucose: graphHistory.first,
            lastReadingDate: now.addingTimeInterval(-999 * 60),
            currentGlucose: 0,
            currentTrendArrow: "---",
            maxBG: 100,
            lastSuccessfulLibreLinkUpAPICall: now.addingTimeInterval(-1 * 60 * 60 * 24),
            updatedAt: .distantPast
        )
    }

    private static func defaultGraphEntries(now: Date = Date()) -> [LibreLinkUpGlucose] {
        [
            LibreLinkUpGlucose(
                glucose: Glucose(rawValue: 1000,
                                 rawTemperature: 4,
                                 temperatureAdjustment: 4,
                                 trendRate: 4.0,
                                 trendArrow: .stable,
                                 id: 6020,
                                 date: now.addingTimeInterval(-3 * 60 * 60),
                                 hasError: false),
                color: .green,
                trendArrow: TrendArrow(rawValue: 0)
            ),
            LibreLinkUpGlucose(
                glucose: Glucose(rawValue: 1500,
                                 rawTemperature: 4,
                                 temperatureAdjustment: 4,
                                 trendRate: 4.0,
                                 trendArrow: .stable,
                                 id: 6025,
                                 date: now.addingTimeInterval(-2 * 60 * 60),
                                 hasError: false),
                color: .green,
                trendArrow: TrendArrow(rawValue: 0)
            ),
            LibreLinkUpGlucose(
                glucose: Glucose(rawValue: 800,
                                 rawTemperature: 4,
                                 temperatureAdjustment: 4,
                                 trendRate: 4.0,
                                 trendArrow: .stable,
                                 id: 6030,
                                 date: now.addingTimeInterval(-1 * 60 * 60),
                                 hasError: false),
                color: .green,
                trendArrow: TrendArrow(rawValue: 0)
            )
        ]
    }

    private static func defaultMinuteEntries(now: Date = Date()) -> [LibreLinkUpGlucose] {
        [
            LibreLinkUpGlucose(
                glucose: Glucose(rawValue: 820,
                                 rawTemperature: 4,
                                 temperatureAdjustment: 4,
                                 trendRate: 4.0,
                                 trendArrow: .stable,
                                 id: 1,
                                 date: now.addingTimeInterval(-1 * 60 * 60 - 120),
                                 hasError: false),
                color: .green,
                trendArrow: TrendArrow(rawValue: 0)
            ),
            LibreLinkUpGlucose(
                glucose: Glucose(rawValue: 810,
                                 rawTemperature: 4,
                                 temperatureAdjustment: 4,
                                 trendRate: 4.0,
                                 trendArrow: .stable,
                                 id: 2,
                                 date: now.addingTimeInterval(-1 * 60 * 60 - 60),
                                 hasError: false),
                color: .green,
                trendArrow: TrendArrow(rawValue: 0)
            ),
            LibreLinkUpGlucose(
                glucose: Glucose(rawValue: 800,
                                 rawTemperature: 4,
                                 temperatureAdjustment: 4,
                                 trendRate: 4.0,
                                 trendArrow: .stable,
                                 id: 3,
                                 date: now.addingTimeInterval(-1 * 60 * 60),
                                 hasError: false),
                color: .green,
                trendArrow: TrendArrow(rawValue: 0)
            )
        ]
    }

    private static func readLegacySnapshotFromUserDefaults() -> Snapshot? {
        guard let legacySnapshot: LegacySnapshot = UserDefaults.group.getObject(forKey: .libreLinkUpHistorySnapshot) else {
            return nil
        }
        return Snapshot(
            fullLibreLinkUpGlucose: legacySnapshot.libreLinkUpGlucose,
            libreLinkUpGlucose: legacySnapshot.libreLinkUpGlucose,
            libreLinkUpMinuteGlucose: legacySnapshot.libreLinkUpMinuteGlucose,
            latestLibreLinkUpGlucose: legacySnapshot.latestLibreLinkUpGlucose
                ?? legacySnapshot.libreLinkUpGlucose.first
                ?? legacySnapshot.libreLinkUpMinuteGlucose.first,
            lastReadingDate: legacySnapshot.lastReadingDate,
            currentGlucose: legacySnapshot.currentGlucose,
            currentTrendArrow: legacySnapshot.currentTrendArrow,
            maxBG: legacySnapshot.maxBG,
            lastSuccessfulLibreLinkUpAPICall: legacySnapshot.lastOnlineDate ?? Date(timeIntervalSinceNow: -1 * 60 * 60 * 24),
            updatedAt: .distantPast
        )
    }

    private static func logPersistenceError(_ error: Error, context: String) {
        persistenceLogger.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
}

typealias LibreLinkUpHistory = LibreLinkUpHistoryStore

extension EnvironmentValues {
    var libreLinkUpHistory: LibreLinkUpHistoryStore {
        get { self[LibreLinkUpHistoryStoreKey.self] }
        set { self[LibreLinkUpHistoryStoreKey.self] = newValue }
    }
}


private struct LibreLinkUpHistoryStoreKey: EnvironmentKey {
    nonisolated static var defaultValue: LibreLinkUpHistoryStore {
        MainActor.assumeIsolated { LibreLinkUpHistoryStore.shared }
    }
}
