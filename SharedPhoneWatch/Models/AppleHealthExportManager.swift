//
//  AppleHealthExportManager.swift
//  LibreWrist
//
//  Created by Codex on 11.03.26.
//

import Foundation
import OSLog

#if os(iOS) && canImport(HealthKit)
import HealthKit
#endif

enum AppleHealthAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case denied
    case authorized

    var statusText: String {
        switch self {
        case .unavailable:
            return String(localized: "Apple Health is not available on this device.")
        case .notDetermined:
            return String(localized: "Permission has not been requested yet.")
        case .denied:
            return String(localized: "Apple Health write access is not granted.")
        case .authorized:
            return String(localized: "Apple Health export is authorized.")
        }
    }
}

final class AppleHealthExportManager {
    static let shared = AppleHealthExportManager()

    private init() {}

    var isExportEnabled: Bool {
        get { SharedData.appleHealthExportEnabled }
        set { SharedData.appleHealthExportEnabled = newValue }
    }

    func authorizationState() -> AppleHealthAuthorizationState {
#if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        let statuses = requiredWriteTypes.map(healthStore.authorizationStatus(for:))
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) {
            return .authorized
        }
        if statuses.contains(.sharingDenied) {
            return .denied
        }
        return .notDetermined
#else
        return .unavailable
#endif
    }

    func syncPreferenceWithAuthorization() -> AppleHealthAuthorizationState {
        let state = authorizationState()
        if state != .authorized {
            isExportEnabled = false
        }
        return state
    }

    @discardableResult
    func requestWriteAuthorizationAndEnableExport() async -> AppleHealthAuthorizationState {
#if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            isExportEnabled = false
            return .unavailable
        }

        do {
            try await requestAuthorization()
        } catch {
            Logger.healthKit.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
            isExportEnabled = false
            return authorizationState()
        }

        let state = authorizationState()
        isExportEnabled = (state == .authorized)
        if state == .authorized {
            await exportAllAvailableDataIfNeeded()
        }
        return state
#else
        isExportEnabled = false
        return .unavailable
#endif
    }

    func disableExport() {
        isExportEnabled = false
    }

    func exportAllAvailableDataIfNeeded() async {
        await exportGlucoseSamplesIfNeeded(LibreLinkUpHistory.shared.fullLibreLinkUpGlucose)
        let insulinHistory = InsulinDeliveryHistorySingleton.shared
        insulinHistory.read()
        await exportInsulinDeliveriesIfNeeded(insulinHistory.insulinDeliveryHistory)
    }

    func exportGlucoseSamplesIfNeeded(_ readings: [LibreLinkUpGlucose]) async {
#if os(iOS) && canImport(HealthKit)
        guard isExportEnabled, authorizationState() == .authorized else { return }

        let uniqueReadings = uniqueGlucoseReadings(graphHistoryReadings(from: readings))
        guard !uniqueReadings.isEmpty else { return }

        let dates = uniqueReadings.map(\.glucose.date)
        do {
            let existingIdentifiers = try await existingSyncIdentifiers(
                for: glucoseType,
                start: dates.min() ?? .distantPast,
                end: dates.max() ?? .distantFuture
            )
            let newSamples = uniqueReadings.compactMap { reading -> HKQuantitySample? in
                let syncIdentifier = Self.glucoseSyncIdentifier(for: reading)
                guard !existingIdentifiers.contains(syncIdentifier) else { return nil }

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

            guard !newSamples.isEmpty else { return }
            try await save(samples: newSamples)
            Logger.healthKit.info("Saved \(newSamples.count, privacy: .public) glucose sample(s) to Apple Health.")
        } catch {
            Logger.healthKit.error("Glucose export failed: \(error.localizedDescription, privacy: .public)")
        }
#else
        _ = readings
#endif
    }

    func exportInsulinDeliveriesIfNeeded(_ deliveries: [InsulinDelivery]) async {
#if os(iOS) && canImport(HealthKit)
        guard isExportEnabled, authorizationState() == .authorized else { return }

        let uniqueDeliveries = uniqueInsulinDeliveries(deliveries)
        guard !uniqueDeliveries.isEmpty else { return }

        let dates = uniqueDeliveries.map { Date(timeIntervalSince1970: $0.timeStamp) }
        do {
            let existingIdentifiers = try await existingSyncIdentifiers(
                for: insulinType,
                start: dates.min() ?? .distantPast,
                end: dates.max() ?? .distantFuture
            )
            let newSamples = uniqueDeliveries.compactMap { delivery -> HKQuantitySample? in
                let syncIdentifier = Self.insulinSyncIdentifier(for: delivery)
                guard !existingIdentifiers.contains(syncIdentifier) else { return nil }

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

            guard !newSamples.isEmpty else { return }
            try await save(samples: newSamples)
            Logger.healthKit.info("Saved \(newSamples.count, privacy: .public) insulin sample(s) to Apple Health.")
        } catch {
            Logger.healthKit.error("Insulin export failed: \(error.localizedDescription, privacy: .public)")
        }
#else
        _ = deliveries
#endif
    }

    func deleteInsulinDeliveriesIfPresent(_ deliveries: [InsulinDelivery]) async {
#if os(iOS) && canImport(HealthKit)
        guard authorizationState() == .authorized else { return }

        let uniqueDeliveries = uniqueInsulinDeliveries(deliveries)
        guard !uniqueDeliveries.isEmpty else { return }

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
#else
        _ = deliveries
#endif
    }

    static func glucoseSyncIdentifier(for reading: LibreLinkUpGlucose) -> String {
        let timestamp = Int(reading.glucose.date.timeIntervalSince1970.rounded())
        return "librewrist.glucose.\(timestamp).\(reading.glucose.value)"
    }

    static func insulinSyncIdentifier(for delivery: InsulinDelivery) -> String {
        let timestamp = Int(delivery.timeStamp.rounded())
        let units = Int((delivery.insulinUnits * 100).rounded())
        return "librewrist.insulin.\(timestamp).\(units).\(delivery.insulinType)"
    }

#if os(iOS) && canImport(HealthKit)
    private let healthStore = HKHealthStore()

    private var requiredWriteTypes: Set<HKSampleType> {
        [glucoseType, insulinType]
    }

    private var glucoseType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
    }

    private var insulinType: HKQuantityType {
        HKObjectType.quantityType(forIdentifier: .insulinDelivery)!
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: requiredWriteTypes, read: []) { success, error in
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

    private func existingSyncIdentifiers(
        for sampleType: HKSampleType,
        start: Date,
        end: Date
    ) async throws -> Set<String> {
        let queryStart = start.addingTimeInterval(-5 * 60)
        let queryEnd = end.addingTimeInterval(5 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let syncIdentifiers = Set(
                    (samples ?? []).compactMap { sample in
                        sample.metadata?[HKMetadataKeySyncIdentifier] as? String
                    }
                )
                continuation.resume(returning: syncIdentifiers)
            }
            healthStore.execute(query)
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

    private func uniqueGlucoseReadings(_ readings: [LibreLinkUpGlucose]) -> [LibreLinkUpGlucose] {
        var seen = Set<String>()
        return readings
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
