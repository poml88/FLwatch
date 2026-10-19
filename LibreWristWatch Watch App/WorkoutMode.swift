//
//  WorkoutMode.swift
//  FLwatchWatchApp
//
//  Watch-owned workout configuration and crash-recovery state.
//

import Foundation
import OSLog
import SwiftUI

enum WorkoutTypeOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case hiking
    case yoga
    case glucoseFocus
    case tennis
    case pickleball
    case walking
    case running
    case cycling
    case mixedCardio
    case functionalStrengthTraining
    case traditionalStrengthTraining
    case elliptical
    case rowing
    case stairClimbing

    var id: String { rawValue }

    static var sortedOptions: [WorkoutTypeOption] {
        allCases.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    var displayName: String {
        switch self {
        case .hiking:
            return String(localized: "Hiking", comment: "Workout activity choice on Apple Watch.")
        case .yoga:
            return String(localized: "Yoga", comment: "Workout activity choice on Apple Watch.")
        case .glucoseFocus:
            return String(localized: "Glucose Focus", comment: "Apple Watch mode that keeps direct glucose sensor readings active using a workout session, without saving a workout to Health.")
        case .tennis:
            return String(localized: "Tennis", comment: "Workout activity choice on Apple Watch for playing tennis.")
        case .pickleball:
            return String(localized: "Pickleball", comment: "Workout activity choice on Apple Watch for playing pickleball, a paddle sport.")
        case .walking:
            return String(localized: "Walking", comment: "Workout activity choice on Apple Watch.")
        case .running:
            return String(localized: "Running", comment: "Workout activity choice on Apple Watch.")
        case .cycling:
            return String(localized: "Cycling", comment: "Workout activity choice on Apple Watch.")
        case .mixedCardio:
            return String(localized: "Mixed Cardio", comment: "Workout activity choice on Apple Watch.")
        case .functionalStrengthTraining:
            return String(localized: "Functional Strength", comment: "Workout activity choice on Apple Watch.")
        case .traditionalStrengthTraining:
            return String(localized: "Strength Training", comment: "Workout activity choice on Apple Watch.")
        case .elliptical:
            return String(localized: "Elliptical", comment: "Workout activity choice on Apple Watch.")
        case .rowing:
            return String(localized: "Rowing", comment: "Workout activity choice on Apple Watch.")
        case .stairClimbing:
            return String(localized: "Stair Climbing", comment: "Workout activity choice on Apple Watch.")
        }
    }

    var shortDisplayName: String {
        switch self {
        case .glucoseFocus:
            return String(localized: "Focus", comment: "Short label for Glucose Focus in the active Apple Watch screen's title. Keep very short to fit a 40 mm watch; German: Fokus.")
        case .functionalStrengthTraining:
            return String(localized: "Strength", comment: "Short Apple Watch label for a functional strength workout.")
        case .traditionalStrengthTraining:
            return String(localized: "Weights", comment: "Short Apple Watch label for a traditional strength workout.")
        case .mixedCardio:
            return String(localized: "Cardio", comment: "Short Apple Watch label for a mixed cardio workout.")
        case .stairClimbing:
            return String(localized: "Stairs", comment: "Short Apple Watch label for a stair-climbing workout.")
        default:
            return displayName
        }
    }

    var isOutdoorPreferred: Bool {
        switch self {
        case .hiking, .walking, .running, .cycling, .tennis, .pickleball:
            return true
        case .yoga,
             .glucoseFocus,
             .mixedCardio,
             .functionalStrengthTraining,
             .traditionalStrengthTraining,
             .elliptical,
             .rowing,
             .stairClimbing:
            return false
        }
    }

    var defaultLocation: WorkoutLocationOption {
        isOutdoorPreferred ? .outdoor : .indoor
    }
}

enum WorkoutLocationOption: String, Codable, Sendable {
    case indoor
    case outdoor

    var displayName: String {
        switch self {
        case .indoor:
            return String(localized: "Indoor", comment: "Location label for an indoor Apple Watch workout.")
        case .outdoor:
            return String(localized: "Outdoor", comment: "Location label for an outdoor Apple Watch workout.")
        }
    }
}

enum WorkoutStartResult: Equatable, Sendable {
    case started
    case healthDataUnavailable
    case authorizationFailed
    case bluetoothPermissionDenied
    case providerNotConfigured
    case provisioningUnavailable
    case sensorTimingUnavailable
    case sensorWarmingUp
    case sensorExpired
    case ownershipClaimRejected
    case startFailed

    var userMessage: String {
        switch self {
        case .started:
            return String(localized: "Workout started.", comment: "Confirmation after an Apple Watch workout starts.")
        case .healthDataUnavailable:
            return String(localized: "Health data is not available on this Apple Watch.", comment: "Workout start failure when HealthKit is unavailable.")
        case .authorizationFailed:
            return String(localized: "Workout permission was not granted.", comment: "Workout start failure when HealthKit permission cannot be obtained.")
        case .bluetoothPermissionDenied:
            return String(localized: "Bluetooth access is required for direct sensor readings.", comment: "Workout start failure when Apple Watch Bluetooth permission is denied or restricted.")
        case .providerNotConfigured:
            return String(localized: "Set up the selected glucose provider on your iPhone first.", comment: "Workout start failure when the selected glucose provider has no credentials or paired sensor on Apple Watch.")
        case .provisioningUnavailable:
            return String(localized: "The Libre 3 sensor setup has not reached this Apple Watch yet.", comment: "Workout start failure when direct-sensor credentials have not been provisioned to Apple Watch.")
        case .sensorTimingUnavailable:
            return String(localized: "Waiting for the Libre 3 sensor status from your iPhone.", comment: "Workout start failure when Apple Watch cannot yet determine the sensor warm-up or expiry state.")
        case .sensorWarmingUp:
            return String(localized: "The Libre 3 sensor is still warming up.", comment: "Workout start failure because the paired sensor has not finished warming up.")
        case .sensorExpired:
            return String(localized: "The Libre 3 sensor has expired.", comment: "Workout start failure because the paired sensor is past its wear duration.")
        case .ownershipClaimRejected:
            return String(localized: "Apple Watch could not take ownership of the Libre 3 sensor.", comment: "Workout start failure when the direct-sensor ownership claim is rejected.")
        case .startFailed:
            return String(localized: "Could not start the workout.", comment: "Generic Apple Watch workout start failure.")
        }
    }
}

struct WorkoutAlertState: Codable, Equatable, Sendable {
    var activeGlucoseTier: GlucoseAlertTier?
    var lastGlucoseNotificationDate: Date?
    // Optional fields keep workout snapshots from earlier builds decodable.
    var lowSnoozedUntil: Date?
    var wasDroppingQuickly = false
    var lastRapidDropNotificationDate: Date?
    var rapidDropSnoozedUntil: Date?

    static let empty = WorkoutAlertState()
}

@MainActor
@Observable
final class WorkoutModeStore {
    private struct Snapshot: Codable, Equatable {
        var isActive = false
        var isEnding = false
        var workoutSessionID: UUID?
        var startedAt: Date?
        var lowGlucoseThreshold = 70
        var workoutTypeRawValue = WorkoutTypeOption.yoga.rawValue
        var workoutLocationRawValue = WorkoutLocationOption.indoor.rawValue
        var providerKindRawValue = CGMProviderKind.libreLinkUp.rawValue
        // Optional so workout snapshots written before alerting shipped remain
        // decodable and naturally start with a clear alert state.
        var alertState: WorkoutAlertState?
        // Optional so existing snapshots remain readable after recents are added.
        var recentWorkoutTypeRawValues: [String]?
        var updatedAt = Date.distantPast

        var workoutType: WorkoutTypeOption {
            WorkoutTypeOption(rawValue: workoutTypeRawValue) ?? .yoga
        }

        var workoutLocation: WorkoutLocationOption {
            WorkoutLocationOption(rawValue: workoutLocationRawValue) ?? workoutType.defaultLocation
        }

        var providerKind: CGMProviderKind {
            CGMProviderKind(rawValue: providerKindRawValue) ?? .libreLinkUp
        }

        var recentWorkoutTypes: [WorkoutTypeOption] {
            let types = recentWorkoutTypeRawValues?.compactMap(WorkoutTypeOption.init(rawValue:))
                ?? (updatedAt == .distantPast ? [] : [workoutType])
            var seen = Set<WorkoutTypeOption>()
            return Array(types.filter { seen.insert($0).inserted }.prefix(5))
        }
    }

    static let shared = WorkoutModeStore()

    private(set) var isActive: Bool
    private(set) var isEnding: Bool
    private(set) var workoutSessionID: UUID?
    private(set) var startedAt: Date?
    private(set) var lowGlucoseThreshold: Int
    private(set) var workoutType: WorkoutTypeOption
    private(set) var workoutLocation: WorkoutLocationOption
    private(set) var providerKind: CGMProviderKind
    private(set) var alertState: WorkoutAlertState
    private(set) var recentWorkoutTypes: [WorkoutTypeOption]
    private(set) var updatedAt: Date

    var workoutTypeOptions: [WorkoutTypeOption] {
        // Keep the monitoring mode easy to find without duplicating a recent choice.
        let leadingOptions = recentWorkoutTypes
            + (recentWorkoutTypes.contains(.glucoseFocus) ? [] : [.glucoseFocus])
        return leadingOptions + WorkoutTypeOption.sortedOptions.filter {
            !leadingOptions.contains($0)
        }
    }

    private let fileManager: FileManager
    private let storeURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "WorkoutModeStore"
    )

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.storeURL = FileStoreIO.makeStoreURL(
            fileName: "watch-workout-mode.json",
            using: fileManager,
            appGroupID: SharedDefaults.appGroupID
        )
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        let snapshot: Snapshot
        do {
            snapshot = try FileStoreIO.readSnapshot(
                Snapshot.self,
                from: storeURL,
                using: decoder,
                fileManager: fileManager
            ) ?? Snapshot()
        } catch {
            Self.logger.error("Failed to restore watch workout state: \(error.localizedDescription, privacy: .public)")
            snapshot = Snapshot()
        }

        self.isActive = snapshot.isActive
        self.isEnding = snapshot.isEnding
        self.workoutSessionID = snapshot.workoutSessionID
        self.startedAt = snapshot.startedAt
        self.lowGlucoseThreshold = snapshot.lowGlucoseThreshold
        self.workoutType = snapshot.workoutType
        self.workoutLocation = snapshot.workoutLocation
        self.providerKind = snapshot.providerKind
        self.alertState = snapshot.alertState ?? .empty
        self.recentWorkoutTypes = snapshot.recentWorkoutTypes
        self.updatedAt = snapshot.updatedAt
    }

    @discardableResult
    func savePreferences(
        lowGlucoseThreshold: Int,
        workoutType: WorkoutTypeOption,
        providerKind: CGMProviderKind
    ) -> Bool {
        persist(
            Snapshot(
                isActive: isActive,
                isEnding: isEnding,
                workoutSessionID: workoutSessionID,
                startedAt: startedAt,
                lowGlucoseThreshold: lowGlucoseThreshold,
                workoutTypeRawValue: workoutType.rawValue,
                workoutLocationRawValue: workoutType.defaultLocation.rawValue,
                providerKindRawValue: providerKind.rawValue,
                alertState: isActive ? alertState : nil,
                // Restoring the picker or changing an alert threshold is not a new choice.
                recentWorkoutTypeRawValues: workoutType == self.workoutType
                    ? recentWorkoutTypes.map(\.rawValue)
                    : recentRawValues(selecting: workoutType),
                updatedAt: Date()
            )
        )
    }

    @discardableResult
    func activate(
        workoutSessionID: UUID,
        startedAt: Date,
        lowGlucoseThreshold: Int,
        workoutType: WorkoutTypeOption,
        workoutLocation: WorkoutLocationOption,
        providerKind: CGMProviderKind,
        preservingAlertState: Bool = false
    ) -> Bool {
        persist(
            Snapshot(
                isActive: true,
                isEnding: false,
                workoutSessionID: workoutSessionID,
                startedAt: startedAt,
                lowGlucoseThreshold: lowGlucoseThreshold,
                workoutTypeRawValue: workoutType.rawValue,
                workoutLocationRawValue: workoutLocation.rawValue,
                providerKindRawValue: providerKind.rawValue,
                alertState: preservingAlertState ? alertState : .empty,
                recentWorkoutTypeRawValues: preservingAlertState
                    ? recentWorkoutTypes.map(\.rawValue)
                    : recentRawValues(selecting: workoutType),
                updatedAt: Date()
            )
        )
    }

    @discardableResult
    func markEnding(at date: Date = Date()) -> Bool {
        persist(
            Snapshot(
                isActive: isActive,
                isEnding: true,
                workoutSessionID: workoutSessionID,
                startedAt: startedAt,
                lowGlucoseThreshold: lowGlucoseThreshold,
                workoutTypeRawValue: workoutType.rawValue,
                workoutLocationRawValue: workoutLocation.rawValue,
                providerKindRawValue: providerKind.rawValue,
                alertState: alertState,
                recentWorkoutTypeRawValues: recentWorkoutTypes.map(\.rawValue),
                updatedAt: date
            )
        )
    }

    @discardableResult
    func deactivate(at date: Date = Date()) -> Bool {
        persist(
            Snapshot(
                isActive: false,
                isEnding: false,
                workoutSessionID: nil,
                startedAt: nil,
                lowGlucoseThreshold: lowGlucoseThreshold,
                workoutTypeRawValue: workoutType.rawValue,
                workoutLocationRawValue: workoutLocation.rawValue,
                providerKindRawValue: providerKind.rawValue,
                alertState: nil,
                recentWorkoutTypeRawValues: recentWorkoutTypes.map(\.rawValue),
                updatedAt: date
            )
        )
    }

    @discardableResult
    func updateAlertState(_ alertState: WorkoutAlertState, at date: Date = Date()) -> Bool {
        guard isActive else { return false }
        return persist(
            Snapshot(
                isActive: isActive,
                isEnding: isEnding,
                workoutSessionID: workoutSessionID,
                startedAt: startedAt,
                lowGlucoseThreshold: lowGlucoseThreshold,
                workoutTypeRawValue: workoutType.rawValue,
                workoutLocationRawValue: workoutLocation.rawValue,
                providerKindRawValue: providerKind.rawValue,
                alertState: alertState,
                recentWorkoutTypeRawValues: recentWorkoutTypes.map(\.rawValue),
                updatedAt: date
            )
        )
    }

    private func recentRawValues(selecting workoutType: WorkoutTypeOption) -> [String] {
        Array(([workoutType] + recentWorkoutTypes.filter { $0 != workoutType }).prefix(5))
            .map(\.rawValue)
    }

    private func persist(_ snapshot: Snapshot) -> Bool {
        do {
            _ = try FileStoreIO.writeSnapshot(
                snapshot,
                to: storeURL,
                using: encoder,
                fileManager: fileManager
            )
        } catch {
            Self.logger.error("Failed to persist watch workout state: \(error.localizedDescription, privacy: .public)")
            return false
        }

        apply(snapshot)
        return true
    }

    private func apply(_ snapshot: Snapshot) {
        isActive = snapshot.isActive
        isEnding = snapshot.isEnding
        workoutSessionID = snapshot.workoutSessionID
        startedAt = snapshot.startedAt
        lowGlucoseThreshold = snapshot.lowGlucoseThreshold
        workoutType = snapshot.workoutType
        workoutLocation = snapshot.workoutLocation
        providerKind = snapshot.providerKind
        alertState = snapshot.alertState ?? .empty
        recentWorkoutTypes = snapshot.recentWorkoutTypes
        updatedAt = snapshot.updatedAt
    }
}

private struct WorkoutModeStoreKey: EnvironmentKey {
    nonisolated static var defaultValue: WorkoutModeStore {
        MainActor.assumeIsolated { WorkoutModeStore.shared }
    }
}

extension EnvironmentValues {
    var workoutModeStore: WorkoutModeStore {
        get { self[WorkoutModeStoreKey.self] }
        set { self[WorkoutModeStoreKey.self] = newValue }
    }
}
