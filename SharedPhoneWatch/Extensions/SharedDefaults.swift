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
    case lowGlucoseNotificationThreshold = "lowGlucoseNotificationThresholdKey"
    case lowGlucoseNotificationLastSentDate = "lowGlucoseNotificationLastSentDateKey"
    case lowGlucoseNotificationPendingRepeat = "lowGlucoseNotificationPendingRepeatKey"
    case lowGlucoseNotificationSnoozeUntilDate = "lowGlucoseNotificationSnoozeUntilDateKey"
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
            // Phase 1: pairing state doesn't exist yet, so report "not set up".
            // Phase 2 will gate this on a persisted Libre3SensorState (serial /
            // BLE address) once NFC pairing lands.
            return false
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
