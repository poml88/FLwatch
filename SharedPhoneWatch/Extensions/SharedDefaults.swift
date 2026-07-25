//
//  SharedDefaults.swift
//  LibreWrist
//
//  Created by Peter Müller on 11.09.25.
//

import Foundation
import SwiftUI // only needed for @AppStorage examples

// MARK: - App group resolver (safe fallback to .standard)
enum SharedDefaults {
    /// Reads APP_GROUP_ID from Info.plist. If missing or invalid, we fall back to `.standard`.
    static var appGroupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String
    }

    static var store: UserDefaults {
        if let id = appGroupID, let ud = UserDefaults(suiteName: id) { return ud }
        return .standard
    }

    /// If you want strict failure when the app group is missing, use:
    /// static var requireStore: UserDefaults { guard let id = appGroupID, let ud = ... else { fatalError("APP_GROUP_ID not configured") } }
}

enum GlucoseAlertTier: String, Codable, CaseIterable, Sendable {
    case low
    case criticalLow
    case high
}

// MARK: - All keys in one place
enum DefaultsKey: String {
    // SharedData keys
    case insulinSelected = "insulinSelectedKey"
    case showInsulinDeliveryMarksPhone = "showInsulinDeliveryMarksPhoneKey"
    case showInsulinDeliveryMarksWatch = "showInsulinDeliveryMarksWatchKey"
    case showIOBCurvePhone = "showIOBCurvePhoneKey"
    case showIOBCurveWatch = "showIOBCurveWatchKey"
    case showActivityCurvePhone = "showActivityCurvePhoneKey"
    case showActivityCurveWatch = "showActivityCurveWatchKey"
    case widgetUpdateFrequency = "widgetUpdateFrequencyKey"
    case tapComplicationReloads = "tapComplicationReloadsKey"
    case useLiveActivities = "useLiveActivitiesKey"
    case appleHealthExportEnabled = "appleHealthExportEnabledKey"
    case bluetoothHeartbeatEnabled = "bluetoothHeartbeatEnabledKey"
    case bluetoothHeartbeatDeviceName = "bluetoothHeartbeatDeviceNameKey"
    case bluetoothHeartbeatPeripheralUUID = "bluetoothHeartbeatPeripheralUUIDKey"
    case bluetoothHeartbeatCharacteristicUUID = "bluetoothHeartbeatCharacteristicUUIDKey"
    case bluetoothHeartbeatLastEventDate = "bluetoothHeartbeatLastEventDateKey"
    case bluetoothHeartbeatLastRefreshDate = "bluetoothHeartbeatLastRefreshDateKey"
    case watchPeerSnapshotLastReceivedDate = "watchPeerSnapshotLastReceivedDateKey"
    case lowGlucoseNotificationsEnabled = "lowGlucoseNotificationsEnabledKey"
    case lowGlucoseCriticalAlertsEnabled = "lowGlucoseCriticalAlertsEnabledKey"
    case lowGlucoseNotificationThreshold = "lowGlucoseNotificationThresholdKey"
    case lowGlucoseNotificationLastSentDate = "lowGlucoseNotificationLastSentDateKey"
    case lowGlucoseNotificationPendingRepeat = "lowGlucoseNotificationPendingRepeatKey"
    case lowGlucoseNotificationSnoozeUntilDate = "lowGlucoseNotificationSnoozeUntilDateKey"
    case criticalLowGlucoseNotificationsEnabled = "criticalLowGlucoseNotificationsEnabledKey"
    case criticalLowGlucoseCriticalAlertsEnabled = "criticalLowGlucoseCriticalAlertsEnabledKey"
    case criticalLowGlucoseNotificationThreshold = "criticalLowGlucoseNotificationThresholdKey"
    case criticalLowGlucoseNotificationLastSentDate = "criticalLowGlucoseNotificationLastSentDateKey"
    case criticalLowGlucoseNotificationPendingRepeat = "criticalLowGlucoseNotificationPendingRepeatKey"
    case highGlucoseNotificationsEnabled = "highGlucoseNotificationsEnabledKey"
    case highGlucoseCriticalAlertsEnabled = "highGlucoseCriticalAlertsEnabledKey"
    case highGlucoseNotificationThreshold = "highGlucoseNotificationThresholdKey"
    case highGlucoseNotificationLastSentDate = "highGlucoseNotificationLastSentDateKey"
    case highGlucoseNotificationPendingRepeat = "highGlucoseNotificationPendingRepeatKey"
    case highGlucoseNotificationSnoozeUntilDate = "highGlucoseNotificationSnoozeUntilDateKey"
    case libre3SignalLossAlertEnabled = "libre3SignalLossAlertEnabledKey"
    case libre3SignalLossCritical = "libre3SignalLossCriticalKey"
    case icrGramsPerUnit = "icrGramsPerUnitKey"
    case roundingStep = "roundingStepKey"
    case carbsPer100g = "carbsPer100gKey"
    case portionGrams = "portionGramsKey"
    case carbsStore = "carbsStoreKey"
    
    // Request reviews SharedData
    case hasDeclinedReview = "hasDeclinedReviewKey"
    case lastReviewPromptDate = "lastReviewPromptDateKey"
    case usedDays = "usedDaysKey"
    case hasPromptedOnce = "hasPromptedOnceKey"
    case hasAgreedToReview = "hasAgreedToReviewKey"

    // Former Settings / other keys
    case libreLinkUpEmail = "libreLinkUpEmail"
    case libreLinkUpPassword = "libreLinkUpPassword"
    case libreLinkUpUserId = "libreLinkUpUserId"
    case libreLinkUpPatientId = "libreLinkUpPatientId"
    case libreLinkUpLastUsedPatientId = "libreLinkUpLastUsedPatientId"
    case libreLinkUpPatients = "libreLinkUpPatients"
    case libreLinkUpCountry = "libreLinkUpCountry"
    case libreLinkUpRegion = "libreLinkUpRegion"
    case libreLinkUpToken = "libreLinkUpToken"
    case libreLinkUpTokenExpirationDate = "libreLinkUpTokenExpirationDate"
    case libreLinkUpFollowing = "libreLinkUpFollowing"
    case libreLinkUpScrapingLogbook = "libreLinkUpScrapingLogbook"
    case lastOnlineDate = "lastOnlineDate"
    case displayingMillimoles = "displayingMillimoles"
    case hasSeenDisclaimer = "hasSeenDisclaimer"
    case hasSeenWelcomeMessage = "hasSeenWelcomeMessage"
    case hasSeenNotification001 = "hasSeenNotification001"
    case lastSeenUpdateNoteVersion = "lastSeenUpdateNoteVersion"
    case libreLinkUpHistorySnapshot = "libreLinkUpHistorySnapshotKey"
    
    
    

    // Private user/session keys (from original private Keys)
    case username = "username"
    case keyConnection = "connection"
    case keyLockTime = "lockTime"
    case insulinDeliveryHistory = "insulinDeliveryHistoryKey"
    case insulinTypeSelected = "insulinTypeSelectedKey"

    // CGM provider selection (Libre vs Dexcom Share)
    case cgmProviderKind = "cgmProviderKindKey"

    // Dexcom Share
    case dexcomShareUsername = "dexcomShareUsernameKey"
    case dexcomShareRegion = "dexcomShareRegionKey"
    case dexcomShareSessionId = "dexcomShareSessionIdKey"

    // Libre 3 direct BLE — non-secret sensor metadata (the BLE PIN is secret and
    // lives in the keychain via `Libre3PINStore`, not here).
    case libre3Serial = "libre3SerialKey"
    case libre3BleAddress = "libre3BleAddressKey"
    case libre3ReceiverIDHex = "libre3ReceiverIDHexKey"
    case libre3FirmwareVersion = "libre3FirmwareVersionKey"
    case libre3Mode = "libre3ModeKey"
    case libre3LibreViewPatientId = "libre3LibreViewPatientIdKey"
    // LibreView (FreeStyle LibreLink) account lookup, used to fetch the
    // AccountId for takeover. The password is a secret kept in the keychain
    // (`LibreViewPasswordKeychain`); only the email + device id live here.
    case libre3LibreViewEmail = "libre3LibreViewEmailKey"
    case libre3LibreViewDeviceId = "libre3LibreViewDeviceIdKey"
    case libre3PeripheralUUID = "libre3PeripheralUUIDKey"
    case libre3SensorStartDate = "libre3SensorStartDateKey"
    case libre3LastLifeCount = "libre3LastLifeCountKey"
    case libre3LastGlucoseMgDL = "libre3LastGlucoseMgDLKey"
    case libre3LastGlucoseAt = "libre3LastGlucoseAtKey"
    // Sensor lifecycle + model, parsed from the NFC patch info at pair time and
    // reused on reconnect (no NFC re-scan) to drive warmup/expiry quality gating
    // and SensorType stamping.
    case libre3WarmupMinutes = "libre3WarmupMinutesKey"
    case libre3WearDurationMinutes = "libre3WearDurationMinutesKey"
    case libre3Generation = "libre3GenerationKey"
    case libre3ProductType = "libre3ProductTypeKey"
    // BLE engine status, published by the phone-only `Libre3DirectManager` and
    // read by the shared `Libre3DirectProvider` (which must not name that
    // phone-only type — it compiles into the watch + widget targets too).
    case libre3EngineDidFail = "libre3EngineDidFailKey"
    case libre3EngineStatusMessage = "libre3EngineStatusMessageKey"
    case libre3SensorNeedsReplacement = "libre3SensorNeedsReplacementKey"
    case libre3ConnectionRequiresUserAction = "libre3ConnectionRequiresUserActionKey"
    case libre3DiagnosticEvents = "libre3DiagnosticEventsKey"
    case libre3ReconnectTrace = "libre3ReconnectTraceKey"
    case libre3NotableEvents = "libre3NotableEventsKey"
    /// Compact stuck-glucose evidence snapshots. Read/written only by the
    /// phone-only `Libre3DiagnosticsLog`, which owns the record type — hence a
    /// key here but no `SharedData` accessor. Reuses the former stream-ring key
    /// so the diagnostics layer can discard that obsolete high-volume payload.
    case libre3StuckSnapshots = "libre3StreamRecordsKey"
    case libre3GlucoseOnlyDeathCount = "libre3GlucoseOnlyDeathCountKey"
    case libre3GlucoseOnlyDeathLastSeen = "libre3GlucoseOnlyDeathLastSeenKey"
    case libre3LastRecordedSignalLossDeliveryDate = "libre3LastRecordedSignalLossDeliveryDateKey"
    // Optional, FLwatch-local correction for newly received Libre 3 BLE values.
    // The log is intentionally small and is cleared when a different sensor is paired.
    case libre3CalibrationOffsetMgDL = "libre3CalibrationOffsetMgDLKey"
    case libre3CalibrationSensorSerial = "libre3CalibrationSensorSerialKey"
    case libre3CalibrationLog = "libre3CalibrationLogKey"
}

// MARK: - Convenience typed helpers + Codable helpers
extension UserDefaults {
    /// Use the resolved app-group store throughout code:
    static var group: UserDefaults { SharedDefaults.store }

    // MARK: - Typed getters with explicit defaultValue (so we don't mix up "0" meaning "no value")
    func getDouble(_ key: DefaultsKey, defaultValue: Double = 0.0) -> Double {
        guard object(forKey: key.rawValue) != nil else { return defaultValue }
        return double(forKey: key.rawValue)
    }
    func setDouble(_ value: Double, forKey key: DefaultsKey) { set(value, forKey: key.rawValue) }

    func getInt(_ key: DefaultsKey, defaultValue: Int = 0) -> Int {
        guard object(forKey: key.rawValue) != nil else { return defaultValue }
        return integer(forKey: key.rawValue)
    }
    func setInt(_ value: Int, forKey key: DefaultsKey) { set(value, forKey: key.rawValue) }

    func getBool(_ key: DefaultsKey, defaultValue: Bool = false) -> Bool {
        guard object(forKey: key.rawValue) != nil else { return defaultValue }
        return bool(forKey: key.rawValue)
    }
    func setBool(_ value: Bool, forKey key: DefaultsKey) { set(value, forKey: key.rawValue) }

    func getString(_ key: DefaultsKey, defaultValue: String = "") -> String {
        string(forKey: key.rawValue) ?? defaultValue
    }
    func setString(_ value: String, forKey key: DefaultsKey) { set(value, forKey: key.rawValue) }
    
    func getStringArray(_ key: DefaultsKey, defaultValue: [String] = []) -> [String] {
        array(forKey: key.rawValue) as? [String] ?? defaultValue
    }
    func setStringArray(_ value: [String], forKey key: DefaultsKey) {set(value, forKey: key.rawValue) }

    func getDate(_ key: DefaultsKey, defaultValue: Date = Date(timeIntervalSince1970: 0)) -> Date {
        if let stored = object(forKey: key.rawValue) as? Date { return stored }
        if let interval = object(forKey: key.rawValue) as? TimeInterval { return Date(timeIntervalSince1970: interval) }
        return defaultValue
    }
    func setDate(_ value: Date, forKey key: DefaultsKey) { set(value.timeIntervalSince1970, forKey: key.rawValue) }

    // MARK: - Codable helpers
    func setObject<T: Encodable>(_ obj: T, forKey key: DefaultsKey) {
        let data = try? JSONEncoder().encode(obj)
        set(data, forKey: key.rawValue)
    }
    func getObject<T: Decodable>(_ type: T.Type = T.self, forKey key: DefaultsKey) -> T? {
        guard let data = data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setArray<T: Encodable>(_ array: [T], forKey key: DefaultsKey) {
        let data = try? JSONEncoder().encode(array)
        set(data, forKey: key.rawValue)
    }
    func getArray<T: Decodable>(_ type: [T].Type = [T].self, forKey key: DefaultsKey) -> [T]? {
        guard let data = data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode([T].self, from: data)
    }
}

// MARK: - High-level properties (kept from your original UserDefaults extension)
enum Connection: Int {
    case disconnected = 0, connected = 1, connecting = 2, failed = -1, locked = -2
}

extension UserDefaults {
    // username stored as optional value (empty string = removed)
    var username: String {
        get { Self.group.getString(.username, defaultValue: "") }
        set {
            if newValue.isEmpty { Self.group.removeObject(forKey: DefaultsKey.username.rawValue) }
            else { Self.group.setString(newValue, forKey: .username) }
        }
    }

    // lock time (stored as TimeInterval)
    fileprivate var lockTime: Date {
        get { Self.group.getDate(.keyLockTime, defaultValue: Date(timeIntervalSinceNow: -12 * 60 * 60)) }
        set { Self.group.setDate(newValue, forKey: .keyLockTime) }
    }

    // connection with automatic "locked" expiry after 5 minutes
    var connected: Connection {
        get {
            let raw = Self.group.getInt(.keyConnection, defaultValue: Connection.disconnected.rawValue)
            if raw == 3 {
                return .connected
            }
            let value = Connection(rawValue: raw) ?? .disconnected
            if value == .locked, lockTime.addingTimeInterval(5 * 60) < Date() {
                return .disconnected
            }
            return value
        }
        set {
            // if we're transitioning into locked, stamp lockTime
            if connected != .locked && newValue == .locked {
                lockTime = Date()
            }
            Self.group.setInt(newValue.rawValue, forKey: .keyConnection)
        }
    }

    // insulinDeliveryHistory (requires InsulinDelivery: Codable)
    var insulinDeliveryHistory: [InsulinDelivery]? {
        get { Self.group.getObject(forKey: .insulinDeliveryHistory) }
        set {
            if let v = newValue { Self.group.setObject(v, forKey: .insulinDeliveryHistory) }
            else { Self.group.removeObject(forKey: DefaultsKey.insulinDeliveryHistory.rawValue) }
        }
    }

    // insulin type (requires InsulinType: RawRepresentable(rawValue: Int))
    var insulinTypeSelected: InsulinType {
        get {
            let raw = Self.group.getInt(.insulinTypeSelected, defaultValue: InsulinType.rapidActing.rawValue)
            return InsulinType(rawValue: raw) ?? .rapidActing
        }
        set { Self.group.setInt(newValue.rawValue, forKey: .insulinTypeSelected) }
    }
}

// MARK: - Thin shared-access static wrappers (optional convenience)
enum SharedData {
    static var store: UserDefaults { UserDefaults.group }

    // Example of a few properties from your original SharedData done tersely:
    static var insulinSelected: Double {
        get { store.getDouble(.insulinSelected, defaultValue: 0.5) }
        set { store.setDouble(newValue, forKey: .insulinSelected) }
    }

    static var widgetUpdateFrequency: Int {
        get { store.getInt(.widgetUpdateFrequency, defaultValue: 5) }
        set { store.setInt(newValue, forKey: .widgetUpdateFrequency) }
    }

    static var showIOBCurvePhone: Bool {
        get { store.getBool(.showIOBCurvePhone, defaultValue: false) }
        set { store.setBool(newValue, forKey: .showIOBCurvePhone) }
    }
    
    static var showInsulinDeliveryMarksPhone: Bool {
        get { store.getBool(.showInsulinDeliveryMarksPhone, defaultValue: false) }
        set { store.setBool(newValue, forKey: .showInsulinDeliveryMarksPhone) }
    }
    
    static var showInsulinDeliveryMarksWatch: Bool {
        get { store.getBool(.showInsulinDeliveryMarksWatch, defaultValue: false) }
        set { store.setBool(newValue, forKey: .showInsulinDeliveryMarksWatch) }
    }
    
    static var showIOBCurveWatch: Bool {
        get { store.getBool(.showIOBCurveWatch, defaultValue: false) }
        set { store.setBool(newValue, forKey: .showIOBCurveWatch) }
    }
    
    static var showActivityCurveWatch: Bool {
        get { store.getBool(.showActivityCurveWatch, defaultValue: false) }
        set { store.setBool(newValue, forKey: .showActivityCurveWatch) }
    }
    
    static var showActivityCurvePhone: Bool {
        get { store.getBool(.showActivityCurvePhone, defaultValue: false) }
        set { store.setBool(newValue, forKey: .showActivityCurvePhone) }
    }
    
    static var tapComplicationReloads: Bool {
        get { store.getBool(.tapComplicationReloads, defaultValue: false) }
        set { store.setBool(newValue, forKey: .tapComplicationReloads) }
    }

    static var useLiveActivities: Bool {
        get { store.getBool(.useLiveActivities, defaultValue: true) }
        set { store.setBool(newValue, forKey: .useLiveActivities) }
    }

    static var appleHealthExportEnabled: Bool {
        get { store.getBool(.appleHealthExportEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .appleHealthExportEnabled) }
    }

    static var bluetoothHeartbeatEnabled: Bool {
        get { store.getBool(.bluetoothHeartbeatEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .bluetoothHeartbeatEnabled) }
    }

    static var bluetoothHeartbeatDeviceName: String {
        get { store.getString(.bluetoothHeartbeatDeviceName, defaultValue: "") }
        set { store.setString(newValue, forKey: .bluetoothHeartbeatDeviceName) }
    }

    static var bluetoothHeartbeatPeripheralUUID: String {
        get { store.getString(.bluetoothHeartbeatPeripheralUUID, defaultValue: "") }
        set { store.setString(newValue, forKey: .bluetoothHeartbeatPeripheralUUID) }
    }

    static var bluetoothHeartbeatCharacteristicUUID: String {
        get { store.getString(.bluetoothHeartbeatCharacteristicUUID, defaultValue: "") }
        set { store.setString(newValue, forKey: .bluetoothHeartbeatCharacteristicUUID) }
    }

    static var bluetoothHeartbeatLastEventDate: Date {
        get { store.getDate(.bluetoothHeartbeatLastEventDate, defaultValue: Date(timeIntervalSince1970: 0)) }
        set { store.setDate(newValue, forKey: .bluetoothHeartbeatLastEventDate) }
    }

    static var bluetoothHeartbeatLastRefreshDate: Date {
        get { store.getDate(.bluetoothHeartbeatLastRefreshDate, defaultValue: Date(timeIntervalSince1970: 0)) }
        set { store.setDate(newValue, forKey: .bluetoothHeartbeatLastRefreshDate) }
    }

    static var watchPeerSnapshotLastReceivedDate: Date {
        get { store.getDate(.watchPeerSnapshotLastReceivedDate, defaultValue: Date(timeIntervalSince1970: 0)) }
        set { store.setDate(newValue, forKey: .watchPeerSnapshotLastReceivedDate) }
    }

    static var lowGlucoseNotificationsEnabled: Bool {
        get { store.getBool(.lowGlucoseNotificationsEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .lowGlucoseNotificationsEnabled) }
    }

    /// When on, low-glucose alerts are delivered as *critical* notifications
    /// (override silent mode / Focus / Do Not Disturb) instead of the default
    /// time-sensitive level. Off by default; requires the critical-alert
    /// entitlement + the user granting critical-alert authorization.
    static var lowGlucoseCriticalAlertsEnabled: Bool {
        get { store.getBool(.lowGlucoseCriticalAlertsEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .lowGlucoseCriticalAlertsEnabled) }
    }

    static var lowGlucoseNotificationThreshold: Int {
        get { store.getInt(.lowGlucoseNotificationThreshold, defaultValue: 70) }
        set { store.setInt(newValue, forKey: .lowGlucoseNotificationThreshold) }
    }

    static var lowGlucoseNotificationLastSentDate: Date {
        get { store.getDate(.lowGlucoseNotificationLastSentDate, defaultValue: .distantPast) }
        set { store.setDate(newValue, forKey: .lowGlucoseNotificationLastSentDate) }
    }

    static var lowGlucoseNotificationPendingRepeat: Bool {
        get { store.getBool(.lowGlucoseNotificationPendingRepeat, defaultValue: false) }
        set { store.setBool(newValue, forKey: .lowGlucoseNotificationPendingRepeat) }
    }

    static var lowGlucoseNotificationSnoozeUntilDate: Date {
        get { store.getDate(.lowGlucoseNotificationSnoozeUntilDate, defaultValue: .distantPast) }
        set { store.setDate(newValue, forKey: .lowGlucoseNotificationSnoozeUntilDate) }
    }

    static var criticalLowGlucoseNotificationsEnabled: Bool {
        get { store.getBool(.criticalLowGlucoseNotificationsEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .criticalLowGlucoseNotificationsEnabled) }
    }

    static var criticalLowGlucoseCriticalAlertsEnabled: Bool {
        get { store.getBool(.criticalLowGlucoseCriticalAlertsEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .criticalLowGlucoseCriticalAlertsEnabled) }
    }

    static var criticalLowGlucoseNotificationThreshold: Int {
        get { store.getInt(.criticalLowGlucoseNotificationThreshold, defaultValue: 55) }
        set { store.setInt(newValue, forKey: .criticalLowGlucoseNotificationThreshold) }
    }

    static var criticalLowGlucoseNotificationLastSentDate: Date {
        get { store.getDate(.criticalLowGlucoseNotificationLastSentDate, defaultValue: .distantPast) }
        set { store.setDate(newValue, forKey: .criticalLowGlucoseNotificationLastSentDate) }
    }

    static var criticalLowGlucoseNotificationPendingRepeat: Bool {
        get { store.getBool(.criticalLowGlucoseNotificationPendingRepeat, defaultValue: false) }
        set { store.setBool(newValue, forKey: .criticalLowGlucoseNotificationPendingRepeat) }
    }

    static var highGlucoseNotificationsEnabled: Bool {
        get { store.getBool(.highGlucoseNotificationsEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .highGlucoseNotificationsEnabled) }
    }

    static var highGlucoseCriticalAlertsEnabled: Bool {
        get { store.getBool(.highGlucoseCriticalAlertsEnabled, defaultValue: false) }
        set { store.setBool(newValue, forKey: .highGlucoseCriticalAlertsEnabled) }
    }

    static var highGlucoseNotificationThreshold: Int {
        get { store.getInt(.highGlucoseNotificationThreshold, defaultValue: 250) }
        set { store.setInt(newValue, forKey: .highGlucoseNotificationThreshold) }
    }

    static var highGlucoseNotificationLastSentDate: Date {
        get { store.getDate(.highGlucoseNotificationLastSentDate, defaultValue: .distantPast) }
        set { store.setDate(newValue, forKey: .highGlucoseNotificationLastSentDate) }
    }

    static var highGlucoseNotificationPendingRepeat: Bool {
        get { store.getBool(.highGlucoseNotificationPendingRepeat, defaultValue: false) }
        set { store.setBool(newValue, forKey: .highGlucoseNotificationPendingRepeat) }
    }

    static var highGlucoseNotificationSnoozeUntilDate: Date {
        get { store.getDate(.highGlucoseNotificationSnoozeUntilDate, defaultValue: .distantPast) }
        set { store.setDate(newValue, forKey: .highGlucoseNotificationSnoozeUntilDate) }
    }

    /// Enables the Libre 3 direct-BLE signal-loss dead-man notification. This is
    /// default-on even before the preference has ever been written.
    static var libre3SignalLossAlertEnabled: Bool {
        get { store.getBool(.libre3SignalLossAlertEnabled, defaultValue: true) }
        set { store.setBool(newValue, forKey: .libre3SignalLossAlertEnabled) }
    }

    /// Requests critical delivery for signal-loss alerts. Actual critical use
    /// is additionally gated by the system critical-alert authorization.
    static var libre3SignalLossCritical: Bool {
        get { store.getBool(.libre3SignalLossCritical, defaultValue: false) }
        set { store.setBool(newValue, forKey: .libre3SignalLossCritical) }
    }
    
    static var libreLinkUpScrapingLogbook: Bool {
        get { store.getBool(.libreLinkUpScrapingLogbook, defaultValue: false) }
        set { store.setBool(newValue, forKey: .libreLinkUpScrapingLogbook) }
    }
    
    static var libreLinkUpFollowing: Bool {
        get { store.getBool(.libreLinkUpFollowing, defaultValue: true) }
        set { store.setBool(newValue, forKey: .libreLinkUpFollowing) }
    }
    
    static var hasSeenDisclaimer: Bool {
        get { store.getBool(.hasSeenDisclaimer, defaultValue: false) }
        set { store.setBool(newValue, forKey: .hasSeenDisclaimer) }
    }
    
    static var hasSeenWelcomeMessage: Bool {
        get { store.getBool(.hasSeenWelcomeMessage, defaultValue: false) }
        set { store.setBool(newValue, forKey: .hasSeenWelcomeMessage) }
    }
    
    static var lastSeenUpdateNoteVersion: Int {
        get {
            if store.object(forKey: DefaultsKey.lastSeenUpdateNoteVersion.rawValue) != nil {
                return store.getInt(.lastSeenUpdateNoteVersion, defaultValue: 0)
            }

            // Migrate the legacy one-off boolean flag to version 1.
            return store.getBool(.hasSeenNotification001, defaultValue: false) ? 1 : 0
        }
        set {
            store.setInt(newValue, forKey: .lastSeenUpdateNoteVersion)
            if newValue >= 1 {
                store.setBool(true, forKey: .hasSeenNotification001)
            }
        }
    }

    static func hasSeenNotification(version: Int) -> Bool {
        lastSeenUpdateNoteVersion >= version
    }

    static func markNotificationSeen(version: Int) {
        lastSeenUpdateNoteVersion = max(lastSeenUpdateNoteVersion, version)
    }
    
    static var libreLinkUpUserId: String {
        get { store.getString(.libreLinkUpUserId, defaultValue: "") }
        set { store.setString(newValue, forKey: .libreLinkUpUserId) }
    }
    
    static var libreLinkUpPatientId: String {
        get { store.getString(.libreLinkUpPatientId, defaultValue: "") }
        set { store.setString(newValue, forKey: .libreLinkUpPatientId) }
    }

    static var libreLinkUpLastUsedPatientId: String {
        get { store.getString(.libreLinkUpLastUsedPatientId, defaultValue: "") }
        set { store.setString(newValue, forKey: .libreLinkUpLastUsedPatientId) }
    }

    static var libreLinkUpPatients: [LibreLinkUpPatient] {
        get { store.getArray(forKey: .libreLinkUpPatients) ?? [] }
        set { store.setArray(newValue, forKey: .libreLinkUpPatients) }
    }
    
    static var libreLinkUpToken: String {
        get { store.getString(.libreLinkUpToken, defaultValue: "") }
        set { store.setString(newValue, forKey: .libreLinkUpToken) }
    }
    
    static var libreLinkUpRegion: String {
        get { store.getString(.libreLinkUpRegion, defaultValue: "eu") }
        set { store.setString(newValue, forKey: .libreLinkUpRegion) }
    }
    
    static var libreLinkUpCountry: String {
        get { store.getString(.libreLinkUpCountry, defaultValue: "") }
        set { store.setString(newValue, forKey: .libreLinkUpCountry) }
    }
    
    static var libreLinkUpTokenExpirationDate: Date {
        get { store.getDate(.libreLinkUpTokenExpirationDate, defaultValue: Date(timeIntervalSinceNow: -1 * 60 * 60 * 24)) }
        set { store.setDate(newValue, forKey: .libreLinkUpTokenExpirationDate) }
    }
    
    static var lastOnlineDateOBSOLETE: Date {
        get { store.getDate(.lastOnlineDate, defaultValue: Date(timeIntervalSinceNow: -1 * 60 * 60 * 24)) }
        set { store.setDate(newValue, forKey: .lastOnlineDate) }
    }
    
    static var usedDays: [String] {
        get { store.getStringArray(.usedDays, defaultValue: []) }
        set { store.setStringArray(newValue, forKey: .usedDays) }
    }

    static var cgmProviderKind: CGMProviderKind {
        get {
            let raw = store.getString(.cgmProviderKind, defaultValue: CGMProviderKind.libreLinkUp.rawValue)
            return CGMProviderKind(rawValue: raw) ?? .libreLinkUp
        }
        set { store.setString(newValue.rawValue, forKey: .cgmProviderKind) }
    }

    static var dexcomShareUsername: String {
        get { store.getString(.dexcomShareUsername, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.dexcomShareUsername.rawValue) }
            else { store.setString(newValue, forKey: .dexcomShareUsername) }
        }
    }

    static var dexcomShareRegion: ShareRegion {
        get {
            let raw = store.getString(.dexcomShareRegion, defaultValue: "")
            return ShareRegion(rawValue: raw) ?? .us
        }
        set { store.setString(newValue.rawValue, forKey: .dexcomShareRegion) }
    }

    /// Non-secret Dexcom Share session GUID, mirrored into the app group so the
    /// widget can read glucose without the keychain password. The app publishes
    /// this on every successful fetch / login; the widget clears it (sets empty)
    /// when Dexcom rejects it as invalid, which gates the widget off until the
    /// app re-authenticates and republishes a fresh value.
    static var dexcomShareSessionId: String {
        get { store.getString(.dexcomShareSessionId, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.dexcomShareSessionId.rawValue) }
            else { store.setString(newValue, forKey: .dexcomShareSessionId) }
        }
    }

    static var dexcomShareRegionIsKnown: Bool {
        !store.getString(.dexcomShareRegion, defaultValue: "").isEmpty
    }

    // MARK: - Libre 3 direct BLE (non-secret sensor metadata)
    //
    // Written by `Libre3StateStore` on the phone after a successful NFC pair.
    // Stored as plain primitives (not the LibreCRKit `Libre3SensorState` type)
    // so shared gates like `hasActiveProviderAccount` can read "is a sensor
    // paired?" from the watch/widget targets, which don't link LibreCRKit. The
    // secret BLE PIN is NOT here — it lives in the keychain.

    static var libre3Serial: String {
        get { store.getString(.libre3Serial, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3Serial.rawValue) }
            else { store.setString(newValue, forKey: .libre3Serial) }
        }
    }

    /// Constant correction applied only as new Libre 3 BLE samples are mapped.
    /// Zero means that calibration is disabled. Existing history is never rewritten.
    static var libre3CalibrationOffsetMgDL: Int {
        get { store.getInt(.libre3CalibrationOffsetMgDL) }
        set { store.setInt(min(max(newValue, -30), 30), forKey: .libre3CalibrationOffsetMgDL) }
    }

    /// Serial associated with the current correction and calibration log. Keeping
    /// this when disconnected lets a user re-pair the same sensor without losing
    /// the setting, while a genuinely different serial resets it during pairing.
    static var libre3CalibrationSensorSerial: String {
        get { store.getString(.libre3CalibrationSensorSerial, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3CalibrationSensorSerial.rawValue) }
            else { store.setString(newValue, forKey: .libre3CalibrationSensorSerial) }
        }
    }

    /// The correction is inert unless it belongs to the currently paired sensor.
    static var effectiveLibre3CalibrationOffsetMgDL: Int {
        let serial = libre3Serial
        guard !serial.isEmpty,
              serial == libre3CalibrationSensorSerial else { return 0 }
        return libre3CalibrationOffsetMgDL
    }

    static func resetLibre3CalibrationForNewSensor() {
        libre3CalibrationOffsetMgDL = 0
        libre3CalibrationSensorSerial = ""
        store.removeObject(forKey: DefaultsKey.libre3CalibrationLog.rawValue)
    }

    static var libre3BleAddress: String {
        get { store.getString(.libre3BleAddress, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3BleAddress.rawValue) }
            else { store.setString(newValue, forKey: .libre3BleAddress) }
        }
    }

    static var libre3FirmwareVersion: String {
        get { store.getString(.libre3FirmwareVersion, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3FirmwareVersion.rawValue) }
            else { store.setString(newValue, forKey: .libre3FirmwareVersion) }
        }
    }

    /// Little-endian hex of FLwatch's receiver ID for this install. Generated
    /// once on first pair and reused so the handshake/reconnect stay stable.
    static var libre3ReceiverIDHex: String {
        get { store.getString(.libre3ReceiverIDHex, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3ReceiverIDHex.rawValue) }
            else { store.setString(newValue, forKey: .libre3ReceiverIDHex) }
        }
    }

    /// LibreView **patient UUID** that activated the sensor. Its FNV-32a hash is
    /// the receiver ID sent in the NFC takeover/parallel command — the sensor
    /// only accepts a receiver ID matching the account/patient that activated
    /// it, else it returns NFC error `0xB1`. Required for takeover/parallel;
    /// fresh activation can use an accountless ID instead.
    static var libre3LibreViewPatientId: String {
        get { store.getString(.libre3LibreViewPatientId, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3LibreViewPatientId.rawValue) }
            else { store.setString(newValue, forKey: .libre3LibreViewPatientId) }
        }
    }

    /// LibreView (FreeStyle LibreLink) account email used to look up the
    /// AccountId for takeover. Stored so the field survives app restarts; the
    /// matching password is a keychain secret (`LibreViewPasswordKeychain`).
    static var libre3LibreViewEmail: String {
        get { store.getString(.libre3LibreViewEmail, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3LibreViewEmail.rawValue) }
            else { store.setString(newValue, forKey: .libre3LibreViewEmail) }
        }
    }

    /// Which pairing mode established the current sensor (for display + future
    /// reconnect policy). `nil` when no Libre 3 sensor is paired.
    static var libre3Mode: Libre3Mode? {
        get {
            let raw = store.getString(.libre3Mode, defaultValue: "")
            return raw.isEmpty ? nil : Libre3Mode(rawValue: raw)
        }
        set {
            if let newValue { store.setString(newValue.rawValue, forKey: .libre3Mode) }
            else { store.removeObject(forKey: DefaultsKey.libre3Mode.rawValue) }
        }
    }

    /// True once a Libre 3 sensor has been paired over BLE (has a serial +
    /// stored PIN). Read by `hasActiveProviderAccount`.
    static var libre3SensorIsPaired: Bool {
        !libre3Serial.isEmpty
    }

    /// CoreBluetooth peripheral identifier (UUID string) of the paired sensor, so
    /// `Libre3DirectManager` reconnect can `retrievePeripherals(withIdentifiers:)`
    /// instead of waiting for a fresh scan advertisement. Empty until first seen.
    static var libre3PeripheralUUID: String {
        get { store.getString(.libre3PeripheralUUID, defaultValue: "") }
        set {
            if newValue.isEmpty { store.removeObject(forKey: DefaultsKey.libre3PeripheralUUID.rawValue) }
            else { store.setString(newValue, forKey: .libre3PeripheralUUID) }
        }
    }

    /// Wall-clock anchor for the sensor start (≈ now − currentLifeCount·60s),
    /// derived once from the first decoded reading and reused to date all
    /// readings stably across reconnects (PLAN §8). `nil` (epoch-0 sentinel)
    /// until seeded.
    static var libre3SensorStartDate: Date? {
        get {
            let date = store.getDate(.libre3SensorStartDate)
            return date.timeIntervalSince1970 == 0 ? nil : date
        }
        set {
            if let newValue { store.setDate(newValue, forKey: .libre3SensorStartDate) }
            else { store.removeObject(forKey: DefaultsKey.libre3SensorStartDate.rawValue) }
        }
    }

    /// Life count (minutes since activation) of the last accepted reading, for
    /// seeding bounded reconnect backfill (Phase 5). 0 = none yet.
    static var libre3LastLifeCount: Int {
        get { store.getInt(.libre3LastLifeCount) }
        set { store.setInt(newValue, forKey: .libre3LastLifeCount) }
    }

    /// Last accepted glucose value (mg/dL) for quick display/seeding. 0 = none.
    static var libre3LastGlucoseMgDL: Int {
        get { store.getInt(.libre3LastGlucoseMgDL) }
        set { store.setInt(newValue, forKey: .libre3LastGlucoseMgDL) }
    }

    static var libre3LastGlucoseAt: Date? {
        get {
            guard store.object(forKey: DefaultsKey.libre3LastGlucoseAt.rawValue) != nil else {
                return nil
            }
            return store.getDate(.libre3LastGlucoseAt)
        }
        set {
            if let newValue { store.setDate(newValue, forKey: .libre3LastGlucoseAt) }
            else { store.removeObject(forKey: DefaultsKey.libre3LastGlucoseAt.rawValue) }
        }
    }

    /// Warm-up duration in minutes (Libre 3 = 60), parsed from the NFC patch
    /// frame at pair time. Feeds `SensorLifecycle` so quality gating suppresses
    /// readings until warm-up completes. Defaults to 60 when unparsed.
    static var libre3WarmupMinutes: Int {
        get { store.getInt(.libre3WarmupMinutes, defaultValue: 60) }
        set { store.setInt(newValue, forKey: .libre3WarmupMinutes) }
    }

    /// Rated total wear in minutes (≈14 days Libre 3 / 15 days Libre 3 Plus),
    /// parsed from the NFC patch frame. Feeds `SensorLifecycle` expiry. 0 = unknown
    /// (treated as never-expiring by the lifecycle).
    static var libre3WearDurationMinutes: Int {
        get { store.getInt(.libre3WearDurationMinutes) }
        set { store.setInt(newValue, forKey: .libre3WearDurationMinutes) }
    }

    /// Sensor generation from the patch frame: 0 = Libre 3, 1 = Libre 3 Plus.
    /// Used (with `libre3ProductType`) for SensorType stamping.
    static var libre3Generation: Int {
        get { store.getInt(.libre3Generation) }
        set { store.setInt(newValue, forKey: .libre3Generation) }
    }

    /// Product type from the patch frame: 4 = Libre 3, 9 = Lingo.
    static var libre3ProductType: Int {
        get { store.getInt(.libre3ProductType) }
        set { store.setInt(newValue, forKey: .libre3ProductType) }
    }

    /// Whether the BLE engine is currently in an error state. Written by the
    /// phone-only `Libre3DirectManager`; read by the shared `Libre3DirectProvider`
    /// so the provider need not reference the phone-only manager type.
    static var libre3EngineDidFail: Bool {
        get { store.getBool(.libre3EngineDidFail) }
        set { store.setBool(newValue, forKey: .libre3EngineDidFail) }
    }

    /// User-visible status string from the BLE engine (same decoupling as above).
    static var libre3EngineStatusMessage: String {
        get { store.getString(.libre3EngineStatusMessage, defaultValue: "[...]") }
        set { store.setString(newValue, forKey: .libre3EngineStatusMessage) }
    }

    /// Phone-only persisted echo of a terminal sensor attention state. This seeds
    /// the phone UI after relaunch; watch targets do not consume it.
    static var libre3SensorNeedsReplacement: Bool {
        get { store.getBool(.libre3SensorNeedsReplacement) }
        set { store.setBool(newValue, forKey: .libre3SensorNeedsReplacement) }
    }

    /// Persists the non-blocking re-scan suggestion across relaunches. The legacy
    /// name/key is retained so an existing terminal flag migrates into the hint
    /// while the reconnect owner is allowed to run again.
    static var libre3ConnectionRequiresUserAction: Bool {
        get { store.getBool(.libre3ConnectionRequiresUserAction) }
        set { store.setBool(newValue, forKey: .libre3ConnectionRequiresUserAction) }
    }

    static var libre3DiagnosticEvents: [String] {
        get { store.getStringArray(.libre3DiagnosticEvents) }
        set { store.setStringArray(newValue, forKey: .libre3DiagnosticEvents) }
    }

    static var libre3ReconnectTrace: [String] {
        get { store.getStringArray(.libre3ReconnectTrace) }
        set { store.setStringArray(newValue, forKey: .libre3ReconnectTrace) }
    }

    static var libre3NotableEvents: [String] {
        get { store.getStringArray(.libre3NotableEvents) }
        set { store.setStringArray(newValue, forKey: .libre3NotableEvents) }
    }

    static var libre3GlucoseOnlyDeathCount: Int {
        get { store.getInt(.libre3GlucoseOnlyDeathCount) }
        set { store.setInt(newValue, forKey: .libre3GlucoseOnlyDeathCount) }
    }

    static var libre3GlucoseOnlyDeathLastSeen: Date? {
        get {
            guard store.object(forKey: DefaultsKey.libre3GlucoseOnlyDeathLastSeen.rawValue) != nil else {
                return nil
            }
            return store.getDate(.libre3GlucoseOnlyDeathLastSeen)
        }
        set {
            if let newValue { store.setDate(newValue, forKey: .libre3GlucoseOnlyDeathLastSeen) }
            else { store.removeObject(forKey: DefaultsKey.libre3GlucoseOnlyDeathLastSeen.rawValue) }
        }
    }

    static var libre3LastRecordedSignalLossDeliveryDate: Date? {
        get {
            guard store.object(forKey: DefaultsKey.libre3LastRecordedSignalLossDeliveryDate.rawValue) != nil else {
                return nil
            }
            return store.getDate(.libre3LastRecordedSignalLossDeliveryDate)
        }
        set {
            if let newValue { store.setDate(newValue, forKey: .libre3LastRecordedSignalLossDeliveryDate) }
            else { store.removeObject(forKey: DefaultsKey.libre3LastRecordedSignalLossDeliveryDate.rawValue) }
        }
    }

    // MARK: - Provider-agnostic credential gates
    //
    // The widgets, watch home view, and intents historically gated on
    // LibreLinkUp's `libreLinkUpUserId`/`libreLinkUpToken`/`username`, which
    // Dexcom never populates. These two helpers branch on the active provider
    // so the same call sites work for both backends. Synchronous and
    // non-isolated on purpose — widget extensions read them off the main actor.

    /// True when the user has configured an account for the active provider
    /// (i.e. has entered credentials at least once). Used for "open the phone
    /// app to sign in" prompts — deliberately lenient (no live-session check).
    static var hasActiveProviderAccount: Bool {
        switch cgmProviderKind {
        case .libreLinkUp:
            return !UserDefaults.group.username.isEmpty
        case .dexcomShare:
            return !dexcomShareUsername.isEmpty
        case .libre3BLE:
            // A sensor is "set up" once it's been paired over NFC (serial + PIN
            // persisted). The phone is the only device that pairs; watch/widgets
            // read this flag from the app group.
            return libre3SensorIsPaired
        }
    }

    /// True when the active provider has enough persisted state to attempt a
    /// reload right now. Stricter than `hasActiveProviderAccount`. Used by the
    /// widgets to bail out early instead of kicking off a doomed reload.
    static var canActiveProviderReload: Bool {
        switch cgmProviderKind {
        case .libre3BLE:
            // Direct BLE is push-only and phone-only: there is no reload to
            // kick, and widgets/watch can't run a BLE session anyway — they
            // only render the snapshot the phone pushes. Always false so no
            // consumer attempts a doomed reload.
            return false
        case .libreLinkUp:
            return !(libreLinkUpUserId.isEmpty || libreLinkUpToken.isEmpty)
        case .dexcomShare:
            // Gate on the app-group sessionId (readable from the widget),
            // not the keychain password. The widget clears this when Dexcom
            // says the session is invalid, which stops it from retrying until
            // the app republishes a fresh session.
            return !dexcomShareUsername.isEmpty
                && dexcomShareRegionIsKnown
                && !dexcomShareSessionId.isEmpty
        }
    }

    // Add other static properties as needed — or prefer using @AppStorage directly (below).
}

/*
// SwiftUI view using @AppStorage directly with the app-group store:
struct ExampleView: View {
    @AppStorage(DefaultsKey.insulinSelected.rawValue, store: UserDefaults.group) private var insulinSelected: Double = 0.0
    @AppStorage(DefaultsKey.showIOBCurvePhone.rawValue, store: UserDefaults.group) private var showIOB: Bool = false

    var body: some View {
        VStack {
            Text("Insulin: \(insulinSelected)")
            Toggle("Show IOB Phone", isOn: $showIOB)
        }
    }
}

// Non-SwiftUI code can call:
let freq = SharedData.widgetUpdateFrequency
 SharedData.insulinSelected = 1.5
 
 
 // Write
 UserDefaults.group.set(1.5, forKey: DefaultsKey.insulinSelected.rawValue)

 // Read
 let insulin = UserDefaults.group.double(forKey: DefaultsKey.insulinSelected.rawValue)

 
 
 // Write
 UserDefaults.group.setDouble(1.5, forKey: .insulinSelected)

 // Read
 let insulin = UserDefaults.group.getDouble(.insulinSelected, defaultValue: 0.0)

 
 
 SharedData.insulinSelected = 1.5
 let insulin = SharedData.insulinSelected

 */
