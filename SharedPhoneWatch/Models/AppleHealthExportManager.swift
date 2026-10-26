//
//  AppleHealthExportManager.swift
//  LibreWrist
//
//  Created on 11.03.26.
//

import Foundation
import OSLog

#if os(iOS) && canImport(HealthKit)
import HealthKit
#endif

/// The two sample kinds FLwatch writes. Apple Health tracks write permission per
/// type, and users frequently want only one of them, so authorization and the
/// export preference are both handled per kind rather than as one bundle.
enum AppleHealthDataKind: CaseIterable, Sendable {
    case glucose
    case insulin
}

enum AppleHealthAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case denied
    /// Denied, and re-requesting would not present a sheet: HealthKit only asks
    /// once per type, so the user has to change it in the Health app itself.
    case deniedNeedsHealthApp
    case authorized

    var statusText: String {
        switch self {
        case .unavailable:
            return String(localized: "Apple Health is not available on this device.")
        case .notDetermined:
            return String(localized: "Permission has not been requested yet.")
        case .denied:
            return String(localized: "Apple Health write access is not granted.")
        case .deniedNeedsHealthApp:
            return String(
                localized: "Apple Health write access is not granted. Apple Health asks only once, so this has to be changed in the Health app.",
                comment: "Status under an Apple Health export switch when permission was refused and cannot be re-requested in-app"
            )
        case .authorized:
            return String(localized: "Apple Health export is authorized.")
        }
    }
}

/// Serializes exports, deletes, and saved-identifier record updates so a catch-up
/// cannot re-save a sample while another operation is saving or forgetting it.
private actor AppleHealthExportGate {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        while isBusy {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waiters.append(continuation)
            }
        }
        isBusy = true
    }

    func release() {
        isBusy = false
        guard !waiters.isEmpty else { return }
        waiters.removeFirst().resume()
    }
}

final class AppleHealthExportManager {
    static let shared = AppleHealthExportManager()

    private let exportGate = AppleHealthExportGate()

    private init() {}

    func isExportEnabled(for kind: AppleHealthDataKind) -> Bool {
        switch kind {
        case .glucose: return SharedData.appleHealthExportGlucoseEnabled
        case .insulin: return SharedData.appleHealthExportInsulinEnabled
        }
    }

    private func setExportEnabled(_ enabled: Bool, for kind: AppleHealthDataKind) {
        switch kind {
        case .glucose: SharedData.appleHealthExportGlucoseEnabled = enabled
        case .insulin: SharedData.appleHealthExportInsulinEnabled = enabled
        }
    }

    /// Authorization for one kind without the extra async probe that tells the
    /// two denied cases apart. Used by the export paths — they only care whether
    /// writing is allowed — and as the settings UI's initial value, so its status
    /// line does not flicker while `authorizationState(for:)` refines it.
    func writeAuthorizationSnapshot(for kind: AppleHealthDataKind) -> AppleHealthAuthorizationState {
#if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        switch healthStore.authorizationStatus(for: sampleType(for: kind)) {
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
#else
        return .unavailable
#endif
    }

    func authorizationState(for kind: AppleHealthDataKind) async -> AppleHealthAuthorizationState {
        let snapshot = writeAuthorizationSnapshot(for: kind)
#if os(iOS) && canImport(HealthKit)
        guard snapshot == .denied else { return snapshot }
        return await requestingWouldPresentSheet(for: kind) ? .denied : .deniedNeedsHealthApp
#else
        return snapshot
#endif
    }

    private func isAuthorized(for kind: AppleHealthDataKind) -> Bool {
        writeAuthorizationSnapshot(for: kind) == .authorized
    }

    /// Turns a preference back off when its Apple Health permission is gone —
    /// the user may have revoked it in the Health app while we were not running.
    func syncPreferenceWithAuthorization(for kind: AppleHealthDataKind) async -> AppleHealthAuthorizationState {
        let state = await authorizationState(for: kind)
        if state != .authorized {
            setExportEnabled(false, for: kind)
        }
        return state
    }

    @discardableResult
    func requestWriteAuthorizationAndEnableExport(for kind: AppleHealthDataKind) async -> AppleHealthAuthorizationState {
#if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            setExportEnabled(false, for: kind)
            return .unavailable
        }

        do {
            try await requestAuthorization(for: kind)
        } catch {
            Logger.healthKit.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
            setExportEnabled(false, for: kind)
            return await authorizationState(for: kind)
        }

        let state = await authorizationState(for: kind)
        if state == .authorized {
            await exportGate.acquire()
            setExportEnabled(true, for: kind)
            setSavedSyncIdentifiers([], for: kind)
            await performAvailableDataExportIfNeeded(for: kind)
            await exportGate.release()
        } else {
            setExportEnabled(false, for: kind)
        }
        return state
#else
        setExportEnabled(false, for: kind)
        return .unavailable
#endif
    }

    func disableExport(for kind: AppleHealthDataKind) {
        setExportEnabled(false, for: kind)
    }

    func exportAllAvailableDataIfNeeded() async {
        for kind in AppleHealthDataKind.allCases {
            await exportAvailableDataIfNeeded(for: kind)
        }
    }

    private func exportAvailableDataIfNeeded(for kind: AppleHealthDataKind) async {
#if os(iOS) && canImport(HealthKit)
        await exportGate.acquire()
        await performAvailableDataExportIfNeeded(for: kind)
        await exportGate.release()
#else
        _ = kind
#endif
    }

#if os(iOS) && canImport(HealthKit)
    /// Caller holds the gate before taking the snapshot, so trimming cannot
    /// forget a newer identifier saved while a catch-up was waiting for the gate.
    private func performAvailableDataExportIfNeeded(for kind: AppleHealthDataKind) async {
        guard isExportEnabled(for: kind), isAuthorized(for: kind) else { return }

        switch kind {
        case .glucose:
            let glucoseReadings = await MainActor.run {
                LibreLinkUpHistory.shared.fullLibreLinkUpGlucose
            }
            await performGlucoseExport(Self.glucoseExportCandidates(from: graphHistoryReadings(from: glucoseReadings)), isCatchUp: true)
        case .insulin:
            await performInsulinExport(uniqueInsulinDeliveries(InsulinDeliveryHistorySingleton.persistedHistorySnapshot()), isCatchUp: true)
        }
    }
#endif

    func exportInsulinCatchUpIfNeeded() async {
        await exportAvailableDataIfNeeded(for: .insulin)
    }

    /// Exports historical candidates; callers must exclude the newest live reading.
    func exportGlucoseSamplesIfNeeded(_ readings: [LibreLinkUpGlucose]) async {
#if os(iOS) && canImport(HealthKit)
        let uniqueReadings = Self.glucoseExportCandidates(from: readings)
        guard !uniqueReadings.isEmpty else { return }

        await exportGate.acquire()
        if isExportEnabled(for: .glucose), isAuthorized(for: .glucose) {
            await performGlucoseExport(uniqueReadings)
        }
        await exportGate.release()
#else
        _ = readings
#endif
    }

#if os(iOS) && canImport(HealthKit)
    private func performGlucoseExport(_ uniqueReadings: [LibreLinkUpGlucose], isCatchUp: Bool = false) async {
        var savedIdentifiers = savedSyncIdentifiers(for: .glucose)
        if isCatchUp {
            let retainedIdentifiers = savedIdentifiers.intersection(uniqueReadings.map(Self.glucoseSyncIdentifier(for:)))
            if retainedIdentifiers != savedIdentifiers {
                setSavedSyncIdentifiers(retainedIdentifiers, for: .glucose)
                savedIdentifiers = retainedIdentifiers
            }
        }
        let newReadings = uniqueReadings.filter {
            !savedIdentifiers.contains(Self.glucoseSyncIdentifier(for: $0))
        }
        Logger.healthKit.debug("Glucose export: \(uniqueReadings.count, privacy: .public) candidates, \(uniqueReadings.count - newReadings.count, privacy: .public) already saved, \(newReadings.count, privacy: .public) new")
        guard !newReadings.isEmpty else { return }

        do {
            let samples = newReadings.map { reading -> HKQuantitySample in
                let syncIdentifier = Self.glucoseSyncIdentifier(for: reading)

                let quantity = HKQuantity(unit: HKUnit(from: "mg/dL"), doubleValue: Double(reading.glucose.value))
                let metadata: [String: Any] = [
                    HKMetadataKeySyncIdentifier: syncIdentifier,
                    HKMetadataKeySyncVersion: 1,
                    "LibreWristSource": reading.glucose.source
                ]
                return HKQuantitySample(
                    type: glucoseType,
                    quantity: quantity,
                    start: reading.glucose.date,
                    end: reading.glucose.date,
                    metadata: metadata
                )
            }

            try await save(samples: samples)
            savedIdentifiers.formUnion(newReadings.map(Self.glucoseSyncIdentifier(for:)))
            setSavedSyncIdentifiers(savedIdentifiers, for: .glucose)
            Logger.healthKit.info("Apple Health accepted \(samples.count, privacy: .public) glucose sample(s).")
        } catch {
            Logger.healthKit.error("Glucose export failed: \(error.localizedDescription, privacy: .public)")
        }
    }
#endif

    func exportInsulinDeliveriesIfNeeded(_ deliveries: [InsulinDelivery]) async {
#if os(iOS) && canImport(HealthKit)
        let uniqueDeliveries = uniqueInsulinDeliveries(deliveries)
        guard !uniqueDeliveries.isEmpty else { return }

        await exportGate.acquire()
        if isExportEnabled(for: .insulin), isAuthorized(for: .insulin) {
            await performInsulinExport(uniqueDeliveries)
        }
        await exportGate.release()
#else
        _ = deliveries
#endif
    }

#if os(iOS) && canImport(HealthKit)
    private func performInsulinExport(_ uniqueDeliveries: [InsulinDelivery], isCatchUp: Bool = false) async {
        var savedIdentifiers = savedSyncIdentifiers(for: .insulin)
        if isCatchUp {
            let retainedIdentifiers = savedIdentifiers.intersection(uniqueDeliveries.map(Self.insulinSyncIdentifier(for:)))
            if retainedIdentifiers != savedIdentifiers {
                setSavedSyncIdentifiers(retainedIdentifiers, for: .insulin)
                savedIdentifiers = retainedIdentifiers
            }
        }
        let newDeliveries = uniqueDeliveries.filter {
            !savedIdentifiers.contains(Self.insulinSyncIdentifier(for: $0))
        }
        Logger.healthKit.debug("Insulin export: \(uniqueDeliveries.count, privacy: .public) candidates, \(uniqueDeliveries.count - newDeliveries.count, privacy: .public) already saved, \(newDeliveries.count, privacy: .public) new")
        guard !newDeliveries.isEmpty else { return }

        do {
            let samples = newDeliveries.map { delivery -> HKQuantitySample in
                let syncIdentifier = Self.insulinSyncIdentifier(for: delivery)

                let eventDate = Date(timeIntervalSince1970: delivery.timeStamp)
                let quantity = HKQuantity(unit: HKUnit.internationalUnit(), doubleValue: delivery.insulinUnits)
                let metadata: [String: Any] = [
                    HKMetadataKeySyncIdentifier: syncIdentifier,
                    HKMetadataKeySyncVersion: 1,
                    HKMetadataKeyWasUserEntered: true,
                    HKMetadataKeyInsulinDeliveryReason: HKInsulinDeliveryReason.bolus.rawValue
                ]
                return HKQuantitySample(
                    type: insulinType,
                    quantity: quantity,
                    start: eventDate,
                    end: eventDate,
                    metadata: metadata
                )
            }

            try await save(samples: samples)
            savedIdentifiers.formUnion(newDeliveries.map(Self.insulinSyncIdentifier(for:)))
            setSavedSyncIdentifiers(savedIdentifiers, for: .insulin)
            Logger.healthKit.info("Apple Health accepted \(samples.count, privacy: .public) insulin sample(s).")
        } catch {
            Logger.healthKit.error("Insulin export failed: \(error.localizedDescription, privacy: .public)")
        }
    }
#endif

    func deleteInsulinDeliveriesIfPresent(_ deliveries: [InsulinDelivery]) async {
#if os(iOS) && canImport(HealthKit)
        // No export-preference check on purpose: samples we wrote earlier should
        // still be cleaned up after the user turns insulin export back off.
        let uniqueDeliveries = uniqueInsulinDeliveries(deliveries)
        guard !uniqueDeliveries.isEmpty else { return }

        // Shares the export gate: a delete racing an export could re-add what it
        // just removed, or remove what the export is about to write.
        await exportGate.acquire()
        // Forget the identifiers even if permission is gone or deletion fails,
        // so entering the same dose again can export it.
        let identifiersToDelete = uniqueDeliveries.map(Self.insulinSyncIdentifier(for:))
        let retainedIdentifiers = savedSyncIdentifiers(for: .insulin).subtracting(identifiersToDelete)
        setSavedSyncIdentifiers(retainedIdentifiers, for: .insulin)
        if isAuthorized(for: .insulin) {
            await performInsulinDelete(uniqueDeliveries)
        }
        await exportGate.release()
#else
        _ = deliveries
#endif
    }

#if os(iOS) && canImport(HealthKit)
    // HealthKit rewrites same-version re-saves (observed 2026-10-26, contrary to
    // HKMetadata.h and WWDC20 session 10184). This defaults record only prevents
    // rewrites. Losing it on reinstall or a crash between save and record write
    // costs at most one extra rewrite per sample, never a missed export.
    // Access within this process is protected by exportGate; concurrent extension
    // writes can lose a record update and permit a rewrite. Identifiers are added
    // only on success.
    private func savedSyncIdentifiers(for kind: AppleHealthDataKind) -> Set<String> {
        switch kind {
        case .glucose: return Set(SharedData.appleHealthSavedGlucoseSyncIdentifiers)
        case .insulin: return Set(SharedData.appleHealthSavedInsulinSyncIdentifiers)
        }
    }

    private func setSavedSyncIdentifiers(_ identifiers: Set<String>, for kind: AppleHealthDataKind) {
        switch kind {
        case .glucose: SharedData.appleHealthSavedGlucoseSyncIdentifiers = identifiers.sorted()
        case .insulin: SharedData.appleHealthSavedInsulinSyncIdentifiers = identifiers.sorted()
        }
    }

    private func performInsulinDelete(_ uniqueDeliveries: [InsulinDelivery]) async {
        let dates = uniqueDeliveries.map { Date(timeIntervalSince1970: $0.timeStamp) }
        let identifiersToDelete = Set(uniqueDeliveries.map(Self.insulinSyncIdentifier(for:)))

        do {
            let existingSamples = try await existingInsulinSamples(
                start: dates.min() ?? .distantPast,
                end: dates.max() ?? .distantFuture
            )
            let matchingSamples = existingSamples.filter { sample in
                guard let syncIdentifier = sample.metadata?[HKMetadataKeySyncIdentifier] as? String else {
                    return false
                }
                return identifiersToDelete.contains(syncIdentifier)
            }

            guard !matchingSamples.isEmpty else { return }
            try await delete(samples: matchingSamples)
            Logger.healthKit.info("Deleted \(matchingSamples.count, privacy: .public) insulin sample(s) from Apple Health.")
        } catch {
            Logger.healthKit.error("Insulin delete failed: \(error.localizedDescription, privacy: .public)")
        }
    }
#endif

    static func glucoseSyncIdentifier(for reading: LibreLinkUpGlucose) -> String {
        // Truncated to the whole second, never rounded: LibreLinkUpHistory persists
        // dates as ISO8601, which drops the fractional second. A reading exported
        // live (date x.7) and the same reading exported after a reload (date x.0)
        // must produce the same identity: a different sync identifier creates a
        // new sample in HealthKit.
        let timestamp = Int(reading.glucose.date.timeIntervalSince1970.rounded(.down))
        // Identity must not change when a Libre 3 BLE value is locally corrected.
        // All current providers initialize rawValue as uncorrected mg/dL × 10, so
        // this remains byte-for-byte compatible with existing uncalibrated IDs.
        let uncorrectedMgDL = reading.glucose.rawValue / 10
        return "librewrist.glucose.\(timestamp).\(uncorrectedMgDL)"
    }

    static func insulinSyncIdentifier(for delivery: InsulinDelivery) -> String {
        // Deliberately still rounded, unlike the glucose identifier above: insulin
        // timestamps are stored as a TimeInterval and round-trip through JSON
        // losslessly, so they never shift. Switching this to truncation would give
        // every already-exported injection a new identity and duplicate it once.
        let timestamp = Int(delivery.timeStamp.rounded())
        let units = Int((delivery.insulinUnits * 100).rounded())
        return "librewrist.insulin.\(timestamp).\(units).\(delivery.insulinType)"
    }

#if os(iOS) && canImport(HealthKit)
    private let healthStore = HKHealthStore()

    private func sampleType(for kind: AppleHealthDataKind) -> HKQuantityType {
        switch kind {
        case .glucose: return glucoseType
        case .insulin: return insulinType
        }
    }

    private var glucoseType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
    }

    private var insulinType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .insulinDelivery)!
    }

    private func requestAuthorization(for kind: AppleHealthDataKind) async throws {
        // Only this kind's type is requested, so allowing glucose and refusing
        // insulin (or the reverse) is a normal, fully supported outcome.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [sampleType(for: kind)], read: []) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                    return
                }
                continuation.resume(throwing: AppleHealthExportError.authorizationFailed)
            }
        }
    }

    /// Whether asking for this kind again would actually show the Apple Health
    /// sheet. HealthKit asks once per type: once the user has answered, a repeat
    /// request silently succeeds without changing anything, so the settings UI
    /// must send them to the Health app instead of a sheet that never appears.
    private func requestingWouldPresentSheet(for kind: AppleHealthDataKind) async -> Bool {
        do {
            let status = try await healthStore.statusForAuthorizationRequest(
                toShare: [sampleType(for: kind)],
                read: []
            )
            return status == .shouldRequest
        } catch {
            Logger.healthKit.error("Request status lookup failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func save(samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                    return
                }
                continuation.resume(throwing: AppleHealthExportError.saveFailed)
            }
        }
    }

    private func delete(samples: [HKObject]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.delete(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                    return
                }
                continuation.resume(throwing: AppleHealthExportError.deleteFailed)
            }
        }
    }

    private func existingInsulinSamples(start: Date, end: Date) async throws -> [HKQuantitySample] {
        let queryStart = start.addingTimeInterval(-5 * 60)
        let queryEnd = end.addingTimeInterval(5 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: insulinType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }
#endif

    static func glucoseExportCandidates(from readings: [LibreLinkUpGlucose]) -> [LibreLinkUpGlucose] {
        var seen = Set<String>()
        return readings
            .filter { reading in
                // The initial history contains made-up readings with source
                // "DiaBLE". Export only readings stamped by a real provider;
                // extend this list when adding a provider.
                switch reading.glucose.source {
                case CGMReadingSource.libre3BLE, "LibreLinkUp", "Dexcom": return true
                default: return false
                }
            }
            .sorted { $0.glucose.date < $1.glucose.date }
            .filter { reading in
                let syncIdentifier = Self.glucoseSyncIdentifier(for: reading)
                return seen.insert(syncIdentifier).inserted
            }
    }

    private func graphHistoryReadings(from readings: [LibreLinkUpGlucose]) -> [LibreLinkUpGlucose] {
        Array(readings.dropFirst())
    }

    private func uniqueInsulinDeliveries(_ deliveries: [InsulinDelivery]) -> [InsulinDelivery] {
        var seen = Set<String>()
        return deliveries
            .sorted { $0.timeStamp < $1.timeStamp }
            .filter { delivery in
                let syncIdentifier = Self.insulinSyncIdentifier(for: delivery)
                return seen.insert(syncIdentifier).inserted
            }
    }
}

private enum AppleHealthExportError: LocalizedError {
    case authorizationFailed
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "Apple Health authorization did not complete successfully."
        case .saveFailed:
            return "Apple Health did not confirm that the samples were saved."
        case .deleteFailed:
            return "Apple Health did not confirm that the samples were deleted."
        }
    }
}
