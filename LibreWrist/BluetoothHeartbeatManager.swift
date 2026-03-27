//
//  BluetoothHeartbeatManager.swift
//  LibreWrist
//
//  Created by Codex on 07.03.26.
//

#if os(iOS)
import Foundation
import CoreBluetooth
import OSLog
import UserNotifications
import WidgetKit

@MainActor
final class PhoneHeartbeatRefreshCoordinator {
    static let shared = PhoneHeartbeatRefreshCoordinator()

    private static let minimumRefreshInterval: TimeInterval = 60
    private var refreshTask: Task<Void, Never>?

    private init() {}

    func recordHeartbeat(source: String) {
        let now = Date()
        SharedData.bluetoothHeartbeatLastEventDate = now
        Logger.connectivity.info("Bluetooth heartbeat received from \(source, privacy: .public)")

        guard refreshTask == nil else {
            Logger.connectivity.debug("Skipping heartbeat refresh; refresh already in flight")
            return
        }

        let secondsSinceLastRefresh = now.timeIntervalSince(SharedData.bluetoothHeartbeatLastRefreshDate)
        guard secondsSinceLastRefresh >= Self.minimumRefreshInterval else {
            Logger.connectivity.debug("Skipping heartbeat refresh; last refresh was \(secondsSinceLastRefresh, privacy: .public)s ago")
            return
        }

        SharedData.bluetoothHeartbeatLastRefreshDate = now
        refreshTask = Task {
            await LibreLinkUpService.shared.requestReloadIfNeeded(maxAgeMinutes: 1)
            await LowGlucoseNotificationManager.shared.evaluateCurrentReading()
            await AppleHealthExportManager.shared.exportAllAvailableDataIfNeeded()
            await LiveActivityManager.shared.refreshFromCurrentHistory(
                useLiveActivities: SharedData.useLiveActivities,
                reloadFailed: LibreLinkUpService.shared.didLastReloadFail
            )
            WidgetCenter.shared.reloadAllTimelines()
            WatchConnectivityManager.shared.sendLibreLinkUpSnapshotToWatch()
            Logger.connectivity.info("Heartbeat refresh pipeline completed")
            refreshTask = nil
        }
    }
}

@MainActor
final class LowGlucoseNotificationManager: NSObject {
    static let shared = LowGlucoseNotificationManager()

    private static let notificationIdentifierPrefix = "low-glucose-alert"
    private static let categoryIdentifier = "LOW_GLUCOSE_ALERT"
    private static let maxReadingAge: TimeInterval = 3 * 60
    private static let repeatInterval: TimeInterval = 5 * 60
    private static let deliveryDelay: TimeInterval = 1
    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    func configureForegroundPresentation() {
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryIdentifier,
                actions: [],
                intentIdentifiers: [],
                options: [.allowInCarPlay]
            )
        ])
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus != .denied else {
            return false
        }

        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .carPlay]

        do {
            return try await notificationCenter.requestAuthorization(options: options)
        } catch {
            Logger.connectivity.error("Low glucose notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func evaluateCurrentReading(now: Date = Date()) async {
        guard SharedData.lowGlucoseNotificationsEnabled else {
            await clearPendingNotifications(resetCooldown: true)
            return
        }

        let settings = await notificationCenter.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }
        guard settings.alertSetting == .enabled || settings.notificationCenterSetting == .enabled else {
            Logger.connectivity.info("Low glucose notification skipped: alerts disabled in system settings")
            return
        }
        let history = LibreLinkUpHistory.shared
        let threshold = SharedData.lowGlucoseNotificationThreshold

        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast else {
            await clearPendingNotifications(resetCooldown: true)
            return
        }
        guard now.timeIntervalSince(history.lastReadingDate) <= Self.maxReadingAge else {
            Logger.connectivity.info("Low glucose notification skipped: glucose value is stale")
            await clearPendingNotifications(resetCooldown: true)
            return
        }

        if history.currentGlucose >= threshold {
            await clearPendingNotifications(resetCooldown: true)
            return
        }

        let secondsSinceLastNotification = now.timeIntervalSince(SharedData.lowGlucoseNotificationLastSentDate)
        guard secondsSinceLastNotification >= Self.repeatInterval else {
            return
        }

        let glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
        let currentValue = formattedGlucoseValue(history.currentGlucose, glucoseUnit: glucoseUnit)
        let thresholdValue = formattedGlucoseValue(threshold, glucoseUnit: glucoseUnit)
        let trendArrow = history.currentTrendArrow == "---" ? "-" : history.currentTrendArrow

        let content = UNMutableNotificationContent()
        content.title = "Low glucose"
        content.body = "Current glucose is \(currentValue) \(trendArrow), below your alert limit of \(thresholdValue)."
        if settings.soundSetting == .enabled {
            content.sound = .default
        } else {
            Logger.connectivity.info("Low glucose notification scheduled without sound because sounds are disabled in system settings")
        }
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        content.categoryIdentifier = Self.categoryIdentifier

        let requestIdentifier = "\(Self.notificationIdentifierPrefix)-\(Int(now.timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: Self.deliveryDelay, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            SharedData.lowGlucoseNotificationLastSentDate = now
        } catch {
            Logger.connectivity.error("Low glucose notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disableNotifications() async {
        await clearPendingNotifications(resetCooldown: true)
    }

    private func clearPendingNotifications(resetCooldown: Bool) async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let matchingPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.notificationIdentifierPrefix) }
        if !matchingPendingIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: matchingPendingIdentifiers)
        }

        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        let matchingDeliveredIdentifiers = deliveredNotifications
            .map(\.request.identifier)
            .filter { $0.hasPrefix(Self.notificationIdentifierPrefix) }
        if !matchingDeliveredIdentifiers.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: matchingDeliveredIdentifiers)
        }

        if resetCooldown {
            SharedData.lowGlucoseNotificationLastSentDate = .distantPast
        }
    }

    private func formattedGlucoseValue(_ valueInMgDl: Int, glucoseUnit: GlucoseUnit) -> String {
        switch glucoseUnit {
        case .mgdl:
            return "\(valueInMgDl) \(glucoseUnit.description)"
        case .mmoll:
            let mmolValue = valueInMgDl.displayedGlucoseValue(glucoseUnit: glucoseUnit)
            let formatted = GlucoseFormatters.mmolLFormatter.string(from: mmolValue as NSNumber) ?? String(format: "%.1f", mmolValue)
            return "\(formatted) \(glucoseUnit.description)"
        }
    }
}

extension LowGlucoseNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier.hasPrefix("low-glucose-alert") else {
            return []
        }
        return [.banner, .list, .sound]
    }
}

@MainActor
final class BluetoothHeartbeatManager: NSObject, ObservableObject {
    static let shared = BluetoothHeartbeatManager()
    private static let minimumHeartbeatInterval: TimeInterval = 30
    private static let connectionTimeout: TimeInterval = 5
    private static let notificationWatchdogTimeout: TimeInterval = 120
    private static let watchdogPollInterval: UInt64 = 30_000_000_000

    struct DiscoveredDevice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let lastSeen: Date
        let rssi: Int
    }

    enum ConnectionStatus: String {
        case disabled
        case unavailable
        case bluetoothOff
        case idle
        case scanning
        case connecting
        case connected
        case unauthorized
        case unsupported

        var description: String {
            switch self {
            case .disabled:
                return "Disabled"
            case .unavailable:
                return "Bluetooth unavailable"
            case .bluetoothOff:
                return "Bluetooth powered off"
            case .idle:
                return "Idle"
            case .scanning:
                return "Scanning for nearby heartbeat devices"
            case .connecting:
                return "Connecting to selected heartbeat device"
            case .connected:
                return "Connected to heartbeat device"
            case .unauthorized:
                return "Bluetooth permission not granted"
            case .unsupported:
                return "Bluetooth not supported on this device"
            }
        }
    }

    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var status: ConnectionStatus = .unavailable
    @Published private(set) var isScanning = false
    @Published private(set) var selectedDeviceName = SharedData.bluetoothHeartbeatDeviceName
    @Published private(set) var selectedPeripheralUUID = SharedData.bluetoothHeartbeatPeripheralUUID
    @Published private(set) var selectedCharacteristicUUID = SharedData.bluetoothHeartbeatCharacteristicUUID
    @Published private(set) var lastHeartbeatDate = SharedData.bluetoothHeartbeatLastEventDate.timeIntervalSince1970 > 0
        ? SharedData.bluetoothHeartbeatLastEventDate
        : nil

    private let heartbeatNameRegex = try? NSRegularExpression(pattern: "^[0-9A-F]{12}$")
    private var centralManager: CBCentralManager?
    private var peripheralsByIdentifier: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var pendingReconnect = false
    private var pendingConnectionPeripheralID: UUID?
    private var lastNotificationDate: Date?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    private var selectedPeripheralIdentifier: UUID? {
        UUID(uuidString: selectedPeripheralUUID)
    }

    private var selectedCharacteristicIdentifier: CBUUID? {
        guard !selectedCharacteristicUUID.isEmpty else { return nil }
        return CBUUID(string: selectedCharacteristicUUID)
    }

    var isEnabled: Bool {
        SharedData.bluetoothHeartbeatEnabled
    }

    func setEnabled(_ isEnabled: Bool) {
        SharedData.bluetoothHeartbeatEnabled = isEnabled
        if isEnabled {
            startIfNeeded()
            connectToSelectedDeviceIfAvailable()
            startScanning()
            startWatchdogIfNeeded()
        } else {
            stopMonitoring()
        }
    }

    func startIfNeeded() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
                CBCentralManagerOptionRestoreIdentifierKey: "de.poeml.philipp.LibreWrist.bluetoothHeartbeat"
            ]
        )
    }

    func startScanning() {
        guard isEnabled else {
            status = .disabled
            return
        }
        startIfNeeded()
        guard let centralManager else { return }

        switch centralManager.state {
        case .poweredOn:
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            isScanning = true
            status = .scanning
        case .poweredOff:
            status = .bluetoothOff
        case .unsupported:
            status = .unsupported
        case .unauthorized:
            status = .unauthorized
        default:
            status = .unavailable
        }
    }

    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        if isEnabled, status == .scanning {
            status = connectedPeripheral == nil ? .idle : .connected
        }
    }

    func selectDevice(_ device: DiscoveredDevice) {
        selectedDeviceName = device.name
        selectedPeripheralUUID = device.id.uuidString
        SharedData.bluetoothHeartbeatDeviceName = device.name
        SharedData.bluetoothHeartbeatPeripheralUUID = device.id.uuidString
        peripheralsByIdentifier[device.id]?.delegate = self
        connectToSelectedDeviceIfAvailable()
    }

    func clearSelection() {
        SharedData.bluetoothHeartbeatDeviceName = ""
        SharedData.bluetoothHeartbeatPeripheralUUID = ""
        SharedData.bluetoothHeartbeatCharacteristicUUID = ""
        selectedDeviceName = ""
        selectedPeripheralUUID = ""
        selectedCharacteristicUUID = ""
        pendingReconnect = false
        pendingConnectionPeripheralID = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        if let connectedPeripheral {
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
        }
        connectedPeripheral = nil
        if isEnabled {
            startScanning()
        }
    }

    func stopMonitoring() {
        watchdogTask?.cancel()
        watchdogTask = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        stopScanning()
        pendingReconnect = false
        pendingConnectionPeripheralID = nil
        if let connectedPeripheral {
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
        }
        connectedPeripheral = nil
        status = .disabled
    }

    private func matchesHeartbeatName(_ name: String) -> Bool {
        let range = NSRange(location: 0, length: name.utf16.count)
        return heartbeatNameRegex?.firstMatch(in: name, options: [], range: range) != nil
    }

    private func updateDiscoveredDevice(peripheral: CBPeripheral, name: String, rssi: Int) {
        peripheralsByIdentifier[peripheral.identifier] = peripheral
        let device = DiscoveredDevice(id: peripheral.identifier, name: name, lastSeen: Date(), rssi: rssi)
        discoveredDevices.removeAll(where: { $0.id == peripheral.identifier })
        discoveredDevices.append(device)
        discoveredDevices.sort {
            if $0.name == $1.name {
                return $0.lastSeen > $1.lastSeen
            }
            return $0.name < $1.name
        }
    }

    private func connectToSelectedDeviceIfAvailable() {
        guard isEnabled else { return }
        guard !selectedDeviceName.isEmpty else { return }
        guard connectedPeripheral.map({ effectiveName(for: $0).uppercased() }) != selectedDeviceName else { return }
        guard let centralManager else { return }

        if let selectedPeripheralIdentifier {
            let restoredPeripherals = centralManager.retrievePeripherals(withIdentifiers: [selectedPeripheralIdentifier])
            if let peripheral = restoredPeripherals.first {
                peripheralsByIdentifier[peripheral.identifier] = peripheral
                connect(peripheral, using: centralManager)
                return
            }
        }

        if let peripheral = peripheralsByIdentifier.values.first(where: { self.effectiveName(for: $0).uppercased() == self.selectedDeviceName }) {
            if selectedPeripheralUUID.isEmpty {
                selectedPeripheralUUID = peripheral.identifier.uuidString
                SharedData.bluetoothHeartbeatPeripheralUUID = peripheral.identifier.uuidString
            }
            connect(peripheral, using: centralManager)
            return
        }

        startScanning()
    }

    private func effectiveName(for peripheral: CBPeripheral, advertisementData: [String: Any]? = nil) -> String {
        if let localName = advertisementData?[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
            return localName
        }
        return peripheral.name ?? ""
    }

    private func connect(_ peripheral: CBPeripheral, using centralManager: CBCentralManager) {
        guard peripheral.state != .connected, peripheral.state != .connecting else { return }
        pendingReconnect = true
        pendingConnectionPeripheralID = peripheral.identifier
        status = .connecting
        peripheral.delegate = self
        centralManager.connect(
            peripheral,
            options: [
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
            ]
        )
        startConnectionTimeout(for: peripheral.identifier)
    }

    private func recordHeartbeat(source: String) {
        let now = Date()
        let secondsSinceLastHeartbeat = now.timeIntervalSince(SharedData.bluetoothHeartbeatLastEventDate)
        guard secondsSinceLastHeartbeat >= Self.minimumHeartbeatInterval else {
            Logger.connectivity.debug("Skipping heartbeat; last heartbeat was \(secondsSinceLastHeartbeat, privacy: .public)s ago")
            return
        }

        lastHeartbeatDate = now
        SharedData.bluetoothHeartbeatLastEventDate = now
        PhoneHeartbeatRefreshCoordinator.shared.recordHeartbeat(source: source)
    }

    private func subscribeToHeartbeatCharacteristics(for peripheral: CBPeripheral, rediscoverServices: Bool = false) {
        if !rediscoverServices,
           let services = peripheral.services,
           !services.isEmpty {
            services.forEach { service in
                peripheral.discoverCharacteristics(nil, for: service)
            }
            return
        }
        peripheral.discoverServices(nil)
    }

    private func subscribe(to characteristics: [CBCharacteristic], on peripheral: CBPeripheral) {
        let preferredUUID = selectedCharacteristicIdentifier
        let sortedCharacteristics = characteristics.sorted { lhs, rhs in
            let lhsPreferred = preferredUUID == lhs.uuid
            let rhsPreferred = preferredUUID == rhs.uuid
            if lhsPreferred == rhsPreferred {
                return lhs.uuid.uuidString < rhs.uuid.uuidString
            }
            return lhsPreferred && !rhsPreferred
        }

        sortedCharacteristics.forEach { characteristic in
            let supportsNotify = characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
            guard supportsNotify else { return }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    private func storeNotifyingCharacteristic(_ characteristic: CBCharacteristic) {
        selectedCharacteristicUUID = characteristic.uuid.uuidString
        SharedData.bluetoothHeartbeatCharacteristicUUID = characteristic.uuid.uuidString
    }

    private func startWatchdogIfNeeded() {
        guard watchdogTask == nil || watchdogTask?.isCancelled == true else { return }
        watchdogTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.watchdogPollInterval)
                self.evaluateWatchdog()
            }
        }
    }

    private func startConnectionTimeout(for peripheralID: UUID) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(Self.connectionTimeout))
            guard !Task.isCancelled else { return }
            self.handleConnectionTimeout(for: peripheralID)
        }
    }

    private func handleConnectionTimeout(for peripheralID: UUID) {
        guard pendingConnectionPeripheralID == peripheralID else { return }
        guard let peripheral = peripheralsByIdentifier[peripheralID] else { return }
        guard peripheral.state == .connecting else { return }

        Logger.connectivity.warning("Bluetooth heartbeat connect timed out for \(self.effectiveName(for: peripheral).uppercased(), privacy: .public)")
        pendingConnectionPeripheralID = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        centralManager?.cancelPeripheralConnection(peripheral)
        status = .idle
        connectToSelectedDeviceIfAvailable()
        startScanning()
    }

    private func evaluateWatchdog() {
        guard isEnabled else { return }
        guard let connectedPeripheral else { return }
        guard connectedPeripheral.state == .connected else { return }
        guard let lastNotificationDate else { return }

        let silenceInterval = Date().timeIntervalSince(lastNotificationDate)
        guard silenceInterval >= Self.notificationWatchdogTimeout else { return }

        Logger.connectivity.warning("Bluetooth heartbeat watchdog fired after \(silenceInterval, privacy: .public)s without notifications")
        subscribeToHeartbeatCharacteristics(for: connectedPeripheral, rediscoverServices: true)
        centralManager?.cancelPeripheralConnection(connectedPeripheral)
    }
}

extension BluetoothHeartbeatManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard isEnabled else {
            status = .disabled
            return
        }

        switch central.state {
        case .poweredOn:
            connectToSelectedDeviceIfAvailable()
            startScanning()
            startWatchdogIfNeeded()
        case .poweredOff:
            status = .bluetoothOff
            stopScanning()
        case .unsupported:
            status = .unsupported
        case .unauthorized:
            status = .unauthorized
        default:
            status = .unavailable
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                peripheral.delegate = self
                peripheralsByIdentifier[peripheral.identifier] = peripheral
            }
            if let restored = restoredPeripherals.first(where: { $0.identifier == selectedPeripheralIdentifier }) ?? restoredPeripherals.first {
                connectedPeripheral = restored
                if selectedPeripheralUUID.isEmpty {
                    selectedPeripheralUUID = restored.identifier.uuidString
                    SharedData.bluetoothHeartbeatPeripheralUUID = restored.identifier.uuidString
                }
                status = restored.state == .connected ? .connected : .idle
                lastNotificationDate = Date()
                startWatchdogIfNeeded()
                subscribeToHeartbeatCharacteristics(for: restored, rediscoverServices: true)
                if restored.state != .connected, let centralManager {
                    connect(restored, using: centralManager)
                }
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = effectiveName(for: peripheral, advertisementData: advertisementData).uppercased()
        guard matchesHeartbeatName(name) else { return }

        updateDiscoveredDevice(peripheral: peripheral, name: name, rssi: RSSI.intValue)

        if selectedPeripheralIdentifier == peripheral.identifier || name == selectedDeviceName {
            if selectedPeripheralUUID.isEmpty {
                selectedPeripheralUUID = peripheral.identifier.uuidString
                SharedData.bluetoothHeartbeatPeripheralUUID = peripheral.identifier.uuidString
            }
            connectToSelectedDeviceIfAvailable()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        pendingConnectionPeripheralID = nil
        connectedPeripheral = peripheral
        pendingReconnect = false
        selectedPeripheralUUID = peripheral.identifier.uuidString
        SharedData.bluetoothHeartbeatPeripheralUUID = peripheral.identifier.uuidString
        peripheral.delegate = self
        status = .connected
        lastNotificationDate = Date()
        startWatchdogIfNeeded()
        stopScanning()
        recordHeartbeat(source: "connect:\(effectiveName(for: peripheral).uppercased())")
        subscribeToHeartbeatCharacteristics(for: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        pendingConnectionPeripheralID = nil
        let message = error?.localizedDescription ?? "unknown"
        Logger.connectivity.error("Bluetooth heartbeat connect failed: \(message, privacy: .public)")
        status = .idle
        if pendingReconnect {
            connectToSelectedDeviceIfAvailable()
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        if peripheral.identifier == pendingConnectionPeripheralID {
            connectionTimeoutTask?.cancel()
            connectionTimeoutTask = nil
            pendingConnectionPeripheralID = nil
        }
        if peripheral.identifier == connectedPeripheral?.identifier {
            connectedPeripheral = nil
        }
        lastNotificationDate = nil
        Logger.connectivity.info("Bluetooth heartbeat device disconnected: \(self.effectiveName(for: peripheral).uppercased(), privacy: .public)")
        if isEnabled, !selectedDeviceName.isEmpty {
            status = .idle
            connectToSelectedDeviceIfAvailable()
            startScanning()
        }
    }
}

extension BluetoothHeartbeatManager: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        if let error {
            Logger.connectivity.error("Bluetooth heartbeat service discovery failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        if let error {
            Logger.connectivity.error("Bluetooth heartbeat characteristic discovery failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        if let characteristics = service.characteristics {
            subscribe(to: characteristics, on: peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error {
            Logger.connectivity.error("Bluetooth heartbeat notification subscription failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        if characteristic.isNotifying {
            storeNotifyingCharacteristic(characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error {
            Logger.connectivity.error("Bluetooth heartbeat notification update failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        lastNotificationDate = Date()
        storeNotifyingCharacteristic(characteristic)
        recordHeartbeat(source: "notification:\(effectiveName(for: peripheral).uppercased())")
    }
}
#endif
