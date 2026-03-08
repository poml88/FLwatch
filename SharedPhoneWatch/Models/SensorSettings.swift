//
//  SensorSettings.swift
//  LibreWrist
//
//  Created by Peter Müller on 05.09.24.
//

import Foundation
import SwiftUI

struct SensorSettings: Codable, Equatable {
    let uom: Int
    let targetLow: Int
    let targetHigh: Int
    let alarmLow: Int
    let alarmHigh: Int

    static let defaultValue = SensorSettings()

    init(uom: Int = 1, targetLow: Int = 70, targetHigh: Int = 180, alarmLow: Int = 80, alarmHigh: Int = 300) {
        self.uom = uom
        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.alarmLow = alarmLow
        self.alarmHigh = alarmHigh
    }
}

@Observable
final class SensorSettingsStore {
    private struct Snapshot: Codable, Equatable {
        var sensorSettings: SensorSettings
        var sensorTypeRawValue: String
        var updatedAt: Date

        var sensorType: SensorType {
            SensorType(rawValue: sensorTypeRawValue) ?? .unknown
        }

        init(sensorSettings: SensorSettings = .defaultValue, sensorType: SensorType = .unknown, updatedAt: Date = .distantPast) {
            self.sensorSettings = sensorSettings
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
        self.storeURL = Self.makeStoreURL(using: fileManager)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        let initial = Self.readSnapshot(from: storeURL, using: decoder, fileManager: fileManager) ?? Snapshot()
        self.sensorSettings = initial.sensorSettings
        self.sensorType = initial.sensorType
        self.updatedAt = initial.updatedAt

        if fileManager.fileExists(atPath: storeURL.path) {
            self.lastKnownModificationDate = Self.modificationDate(at: storeURL, fileManager: fileManager)
        } else {
            _ = persistCurrentSnapshot()
        }
    }

    @discardableResult
    func replaceCacheAndPersist(sensorSettings: SensorSettings, sensorType: SensorType, updatedAt: Date = Date()) -> Bool {
        let nextSnapshot = Snapshot(sensorSettings: sensorSettings, sensorType: sensorType, updatedAt: updatedAt)
        guard let modificationDate = Self.writeSnapshot(nextSnapshot, to: storeURL, using: encoder, fileManager: fileManager) else {
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
        if !force,
           let diskModificationDate = Self.modificationDate(at: storeURL, fileManager: fileManager),
           let lastKnownModificationDate,
           diskModificationDate <= lastKnownModificationDate {
            return false
        }

        guard let snapshot = Self.readSnapshot(from: storeURL, using: decoder, fileManager: fileManager) else {
            return false
        }

        apply(snapshot: snapshot)
        lastKnownModificationDate = Self.modificationDate(at: storeURL, fileManager: fileManager)
        return true
    }

    @discardableResult
    private func persistCurrentSnapshot() -> Bool {
        let snapshot = Snapshot(sensorSettings: sensorSettings, sensorType: sensorType, updatedAt: updatedAt)
        guard let modificationDate = Self.writeSnapshot(snapshot, to: storeURL, using: encoder, fileManager: fileManager) else {
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

    private static func makeStoreURL(using fileManager: FileManager) -> URL {
        let directoryURL: URL
        if let appGroupID = SharedDefaults.appGroupID,
           let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            directoryURL = containerURL.appendingPathComponent("Stores", isDirectory: true)
        } else {
            let fallback = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            directoryURL = fallback.appendingPathComponent("Stores", isDirectory: true)
        }

        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("sensor-settings.json", isDirectory: false)
    }

    private static func readSnapshot(from url: URL, using decoder: JSONDecoder, fileManager: FileManager) -> Snapshot? {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let snapshot = try? decoder.decode(Snapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    @discardableResult
    private static func writeSnapshot(_ snapshot: Snapshot, to url: URL, using encoder: JSONEncoder, fileManager: FileManager) -> Date? {
        guard let data = try? encoder.encode(snapshot) else { return nil }
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return modificationDate(at: url, fileManager: fileManager) ?? Date()
        } catch {
            return nil
        }
    }

    private static func modificationDate(at url: URL, fileManager: FileManager) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.modificationDate] as? Date
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
    static var defaultValue: SensorSettingsStore = SensorSettingsStore.shared
}
