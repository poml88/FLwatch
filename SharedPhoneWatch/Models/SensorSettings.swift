//
//  SensorSettings.swift
//  LibreWrist
//
//  Created by Peter Müller on 05.09.24.
//

import Foundation
import OSLog
import SwiftUI


struct SensorSettings: Codable, Equatable {
    private static let defaultUom = 1
    private static let defaultTargetLow = 70
    private static let defaultTargetHigh = 180
    private static let defaultAlarmLow = 80
    private static let defaultAlarmHigh = 300

    // Dexcom Share doesn't send alarm thresholds and we classify its colors from
    // the target range instead (see DexcomShareTrendMapper.color). These tiny
    // sentinel values pass the `> 0` and `low < high` normalization untouched
    // while staying below `minDrawableAlarmMgDl`, so the red alarm line is
    // suppressed in every graph. A real Libre alarm is always well above this.
    static let dexcomAlarmLowSentinel = 1
    // Fixed high alarm for Dexcom: never drawn and never reached by a real
    // reading, while staying safely above any low alarm so SensorSettings.init
    // doesn't treat the pair as inverted and reset it.
    static let dexcomAlarmHigh = 1000
    static let minDrawableAlarmMgDl = 10

    let uom: Int
    let targetLow: Int
    let targetHigh: Int
    let alarmLow: Int
    let alarmHigh: Int

    var hasDrawableLowAlarm: Bool { alarmLow >= Self.minDrawableAlarmMgDl }

    /// The alarm pair to store for a provider that carries no real alarm
    /// thresholds of its own — Dexcom Share and Libre 3 direct BLE. When
    /// low-glucose alerts are enabled the low alarm tracks the notification
    /// threshold so the red line appears there; otherwise the low sentinel keeps
    /// it hidden. The high alarm is a fixed out-of-range value that's never drawn
    /// and always above the low alarm.
    static func manualAlarms(notificationsEnabled: Bool, threshold: Int) -> (low: Int, high: Int) {
        let low = notificationsEnabled && threshold >= minDrawableAlarmMgDl ? threshold : dexcomAlarmLowSentinel
        return (low, dexcomAlarmHigh)
    }

    private enum CodingKeys: String, CodingKey {
        case uom
        case targetLow
        case targetHigh
        case alarmLow
        case alarmHigh
    }

    static let defaultValue = SensorSettings()

    init(uom: Int = 1, targetLow: Int = 70, targetHigh: Int = 180, alarmLow: Int = 80, alarmHigh: Int = 300) {
        let normalizedUom = (uom == 0 || uom == 1) ? uom : Self.defaultUom
        var normalizedTargetLow = targetLow > 0 ? targetLow : Self.defaultTargetLow
        var normalizedTargetHigh = targetHigh > 0 ? targetHigh : Self.defaultTargetHigh
        var normalizedAlarmLow = alarmLow > 0 ? alarmLow : Self.defaultAlarmLow
        var normalizedAlarmHigh = alarmHigh > 0 ? alarmHigh : Self.defaultAlarmHigh

        if normalizedTargetLow >= normalizedTargetHigh {
            normalizedTargetLow = Self.defaultTargetLow
            normalizedTargetHigh = Self.defaultTargetHigh
        }
        if normalizedAlarmLow >= normalizedAlarmHigh {
            normalizedAlarmLow = Self.defaultAlarmLow
            normalizedAlarmHigh = Self.defaultAlarmHigh
        }

        self.uom = normalizedUom
        self.targetLow = normalizedTargetLow
        self.targetHigh = normalizedTargetHigh
        self.alarmLow = normalizedAlarmLow
        self.alarmHigh = normalizedAlarmHigh
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            uom: try container.decodeIfPresent(Int.self, forKey: .uom) ?? Self.defaultUom,
            targetLow: try container.decodeIfPresent(Int.self, forKey: .targetLow) ?? Self.defaultTargetLow,
            targetHigh: try container.decodeIfPresent(Int.self, forKey: .targetHigh) ?? Self.defaultTargetHigh,
            alarmLow: try container.decodeIfPresent(Int.self, forKey: .alarmLow) ?? Self.defaultAlarmLow,
            alarmHigh: try container.decodeIfPresent(Int.self, forKey: .alarmHigh) ?? Self.defaultAlarmHigh
        )
    }

    func normalized() -> SensorSettings {
        SensorSettings(uom: uom, targetLow: targetLow, targetHigh: targetHigh, alarmLow: alarmLow, alarmHigh: alarmHigh)
    }
}

@MainActor
@Observable
final class SensorSettingsStore {
    private static let persistenceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LibreWrist",
        category: "SensorSettingsStore"
    )

    private struct Snapshot: Codable, Equatable {
        var sensorSettings: SensorSettings
        var sensorTypeRawValue: String
        var updatedAt: Date

        var sensorType: SensorType {
            SensorType(rawValue: sensorTypeRawValue) ?? .unknown
        }

        init(sensorSettings: SensorSettings = .defaultValue, sensorType: SensorType = .unknown, updatedAt: Date = .distantPast) {
            self.sensorSettings = sensorSettings.normalized()
            self.sensorTypeRawValue = sensorType.rawValue
            self.updatedAt = updatedAt
        }
    }

    static let shared: SensorSettingsStore = SensorSettingsStore()

    private(set) var sensorSettings: SensorSettings
    private(set) var sensorType: SensorType
    private(set) var updatedAt: Date

    private let fileManager: FileManager
    private let storeURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var lastKnownModificationDate: Date?

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.storeURL = FileStoreIO.makeStoreURL(
            fileName: "sensor-settings.json",
            using: fileManager,
            appGroupID: SharedDefaults.appGroupID
        )
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
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
        let initial = storedSnapshot ?? Snapshot()
        self.sensorSettings = initial.sensorSettings
        self.sensorType = initial.sensorType
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
    func replaceCacheAndPersist(sensorSettings: SensorSettings, sensorType: SensorType, updatedAt: Date = Date()) -> Bool {
        let nextSnapshot = Snapshot(sensorSettings: sensorSettings.normalized(), sensorType: sensorType, updatedAt: updatedAt)
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
        apply(snapshot: nextSnapshot)
        lastKnownModificationDate = modificationDate
        return true
    }

    @discardableResult
    func updateSensorSettings(_ sensorSettings: SensorSettings, updatedAt: Date = Date()) -> Bool {
        replaceCacheAndPersist(sensorSettings: sensorSettings, sensorType: sensorType, updatedAt: updatedAt)
    }

    @discardableResult
    func updateSensorType(_ sensorType: SensorType, updatedAt: Date = Date()) -> Bool {
        replaceCacheAndPersist(sensorSettings: sensorSettings, sensorType: sensorType, updatedAt: updatedAt)
    }

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

    @discardableResult
    private func persistCurrentSnapshot() -> Bool {
        let snapshot = Snapshot(sensorSettings: sensorSettings, sensorType: sensorType, updatedAt: updatedAt)
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

    private func apply(snapshot: Snapshot) {
        sensorSettings = snapshot.sensorSettings
        sensorType = snapshot.sensorType
        updatedAt = snapshot.updatedAt
    }

    private static func logPersistenceError(_ error: Error, context: String) {
        persistenceLogger.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
}

typealias SensorSettingsSingleton = SensorSettingsStore

extension EnvironmentValues {
    var sensorSettingsStore: SensorSettingsStore {
        get { self[SensorSettingsStoreKey.self] }
        set { self[SensorSettingsStoreKey.self] = newValue }
    }

    @available(*, deprecated, message: "Use sensorSettingsStore instead.")
    var sensorSettingsSingleton: SensorSettingsStore {
        get { sensorSettingsStore }
        set { sensorSettingsStore = newValue }
    }
}

private struct SensorSettingsStoreKey: EnvironmentKey {
    nonisolated static var defaultValue: SensorSettingsStore {
        MainActor.assumeIsolated { SensorSettingsStore.shared }
    }
}
