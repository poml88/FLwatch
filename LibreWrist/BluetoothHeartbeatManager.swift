//
//  BluetoothHeartbeatManager.swift
//  LibreWrist
//
//  Created by Karl Meyer on 07.03.26.
//

#if os(iOS)
import Foundation
import CoreBluetooth
import OSLog
import WidgetKit

@MainActor
final class PhoneHeartbeatRefreshCoordinator {
    static let shared = PhoneHeartbeatRefreshCoordinator()

    private static let nominalRefreshInterval: TimeInterval = 60
    private static let refreshJitterAllowance: TimeInterval = 5
    private static let minimumRefreshInterval = nominalRefreshInterval - refreshJitterAllowance
    private var refreshTask: Task<Void, Never>?

    private init() {}

    func recordHeartbeat(source: String, bypassPropagationDelay: Bool = false) {
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
            // Give the publisher's official app a head start to upload the
            // just-advertised reading to the cloud before we fetch; without
            // it the fetch races the upload and returns the previous reading.
            // A disconnect tick (expired Dexcom G7 dropping with no data)
            // carries no pending upload to wait for, so skip the grace delay.
            let propagationDelay = bypassPropagationDelay ? 0 : HeartbeatConnectionProfileFactory.current.fetchDelay
            if propagationDelay > 0 {
                Logger.connectivity.info("Heartbeat: waiting \(propagationDelay, privacy: .public)s for publisher upload to propagate")
                try? await Task.sleep(nanoseconds: UInt64(propagationDelay * 1_000_000_000))
            }
            // A data-bearing tick (value notification, or Libre's connect) is
            // positive evidence a new reading exists, so force past the
            // reading-age throttle and peer-result reuse — otherwise the fetch
            // can skip and serve a stale cached/peer reading despite the fresh
            // heartbeat. The disconnect metronome tick (bypassPropagationDelay)
            // may carry no new data, so it stays throttled. The lease still
            // serializes calls, so force can't cause concurrent duplicates.
            let forceReload = !bypassPropagationDelay
            await LibreLinkUpService.shared.requestReloadIfNeeded(force: forceReload)
            await LowGlucoseNotificationManager.shared.evaluateCurrentReading()
            // Persisting a newer history already triggers glucose export; the
            // foreground/BG catch-up paths retry anything missed while locked.
            // Commented out the following export trigger.
//            await AppleHealthExportManager.shared.exportAllAvailableDataIfNeeded()
            await LiveActivityManager.shared.refreshFromCurrentHistory(
                useLiveActivities: SharedData.useLiveActivities,
                reloadFailed: LibreLinkUpService.shared.didLastReloadFail,
                refreshIOB: false
            )
            ///this is probably counter-productive, because it fires every minute for Libre and consumes the budget within the hour. it is better NOT to call it here.
            ///Recommendation: drop the reloadAllTimelines() from BluetoothHeartbeatManager.swift:69 entirely and test. Worst case the phone widget lags a reading by up to widgetUpdateFrequency minutes — which is exactly the staleness the user already opted into via that setting. You stay inside the OS budget all day instead of burning it in an hour.
           /// Note the other reloadAllTimelines() callers are fine to leave: the Siri intents, AddInsulin, PhoneAppConnectView, and the foreground PhoneAppHomeView path (:259) are all event-driven user actions — rare, and exactly when an instant refresh is warranted. Only the per-heartbeat one is the budget killer.
//            WidgetCenter.shared.reloadAllTimelines()
            WatchConnectivityManager.shared.sendLibreLinkUpSnapshotToWatch()
            Logger.connectivity.info("Heartbeat refresh pipeline completed")
            refreshTask = nil
        }
    }
}

@MainActor
final class BluetoothHeartbeatManager: NSObject, ObservableObject {
    static let shared = BluetoothHeartbeatManager()
    private static let minimumHeartbeatInterval: TimeInterval = 30
    private static let connectionTimeout: TimeInterval = 5
    private static let watchdogPollInterval: UInt64 = 30_000_000_000

    // Per-sensor BLE timing (which events tick, connection strategy, watchdog
    // window) lives in the profile, read live so a provider switch applies on
    // the next callback. The shared CoreBluetooth engine below is identical
    // for both sensors.
    private var profile: HeartbeatConnectionProfile { HeartbeatConnectionProfileFactory.current }

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
    private var hasReceivedCentralStateUpdate = false
    private var restoredPeripheralAwaitingResume: CBPeripheral?

    private override init() {
        super.init()
        // The active CGM provider can change at runtime (Settings picker, or a
        // WC settings-snapshot from the phone). When it does, reconcile BLE
        // ownership: stand down for `.libre3BLE` (the direct manager owns the
        // single link), re-arm for the cloud providers if the user enabled the
        // heartbeat. Decoupled via NotificationCenter so the shared orchestrator
        // that posts it carries no dependency on this phone-only class.
        NotificationCenter.default.addObserver(
            forName: .activeCGMProviderDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncWithActiveProvider()
            }
        }
    }

    private var selectedPeripheralIdentifier: UUID? {
        UUID(uuidString: selectedPeripheralUUID)
    }

    private var selectedCharacteristicIdentifier: CBUUID? {
        guard !selectedCharacteristicUUID.isEmpty else { return nil }
        return CBUUID(string: selectedCharacteristicUUID)
    }

    private var isCentralPoweredOn: Bool {
        hasReceivedCentralStateUpdate && centralManager?.state == .poweredOn
    }

    var isEnabled: Bool {
        SharedData.bluetoothHeartbeatEnabled
    }

    /// The heartbeat exists purely to harvest a BLE timing tick that schedules
    /// a *cloud* poll. In `.libre3BLE` mode the sensor pushes the actual data
    /// and `Libre3DirectManager` owns the single BLE connection, so the
    /// heartbeat must never create a central or scan — it would fight the
    /// direct manager for the link (plan §4/§6). Every start path gates on this.
    private var isHeartbeatApplicableForActiveProvider: Bool {
        SharedData.cgmProviderKind != .libre3BLE
    }

    /// Reconcile the heartbeat with the active provider after a provider
    /// switch. Called from `LibreLinkUpService.switchProvider`: stand the
    /// central down for direct-BLE, re-arm it for the cloud providers if the
    /// user had the heartbeat enabled.
    func syncWithActiveProvider() {
        guard isHeartbeatApplicableForActiveProvider else {
            stopMonitoring()
            return
        }
        guard isEnabled else { return }
        startIfNeeded()
        if isCentralPoweredOn {
            connectToSelectedDeviceIfAvailable()
            startScanning()
        }
        startWatchdogIfNeeded()
    }

    var settingsDisplayStatus: ConnectionStatus {
        guard hasReceivedCentralStateUpdate, let centralManager else {
            return isEnabled ? status : .disabled
        }

        switch centralManager.state {
        case .poweredOff:
            return .bluetoothOff
        case .unsupported:
            return .unsupported
        case .unauthorized:
            return .unauthorized
        case .poweredOn:
            return isEnabled ? status : .disabled
        default:
            return .unavailable
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        SharedData.bluetoothHeartbeatEnabled = isEnabled
        guard isHeartbeatApplicableForActiveProvider else {
            // Direct-BLE provider owns the link; never run the heartbeat,
            // regardless of the stored toggle.
            stopMonitoring()
            return
        }
        if isEnabled {
            startIfNeeded()
            if isCentralPoweredOn {
                connectToSelectedDeviceIfAvailable()
                startScanning()
            }
            startWatchdogIfNeeded()
        } else {
            stopMonitoring()
        }
    }

    func startIfNeeded() {
        guard isHeartbeatApplicableForActiveProvider else { return }
        guard centralManager == nil else { return }
        hasReceivedCentralStateUpdate = false
        Logger.connectivity.info("Creating CBCentralManager")
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
        guard isHeartbeatApplicableForActiveProvider else {
            status = .disabled
            return
        }
        guard isEnabled else {
            status = .disabled
            return
        }
        startIfNeeded()
        guard let centralManager, isCentralPoweredOn else {
            if let centralManager {
                switch centralManager.state {
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
            return
        }

        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
        status = .scanning
    }

    func stopScanning() {
        guard isCentralPoweredOn else {
            isScanning = false
            if isEnabled, status == .scanning {
                status = connectedPeripheral == nil ? .idle : .connected
            }
            return
        }

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
            if isCentralPoweredOn {
                centralManager?.cancelPeripheralConnection(connectedPeripheral)
            }
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
        // Cancel any in-flight connect as well as an established one. A
        // pending-connect sensor (Dexcom G7) sits in `.connecting` and is *not*
        // tracked by `connectedPeripheral`, so without this the standing connect
        // survives teardown and iOS keeps waking us to retry it after a switch.
        if isCentralPoweredOn, let centralManager {
            if let pendingID = pendingConnectionPeripheralID,
               let pending = peripheralsByIdentifier[pendingID] {
                centralManager.cancelPeripheralConnection(pending)
            }
            if let connectedPeripheral {
                centralManager.cancelPeripheralConnection(connectedPeripheral)
            }
        }
        pendingConnectionPeripheralID = nil
        connectedPeripheral = nil
        status = .disabled
    }

    private func matchesHeartbeatName(_ name: String) -> Bool {
        let range = NSRange(location: 0, length: name.utf16.count)
        // Libre 3 advertises its serial as 12 hex characters; some Libre
        // variants include "ABBOTT" in the advertised name.
        if heartbeatNameRegex?.firstMatch(in: name, options: [], range: range) != nil
            || name.contains("ABBOTT") {
            return true
        }
        // Dexcom: G7 / G7 15-day advertises as "DX…" (e.g. "DXCMPq", "DX02…");
        // G5 / G6 / G6 Firefly advertises as "DEXCOM…". Matches xdrip4ios's
        // peripheral name filter (see CGMG7Transmitter / CGMG6FireflyTransmitter).
        if name.hasPrefix("DX") || name.hasPrefix("DEXCOM") {
            return true
        }
        return false
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
        guard let centralManager, isCentralPoweredOn else { return }

        if let selectedPeripheralIdentifier {
            let restoredPeripherals = centralManager.retrievePeripherals(withIdentifiers: [selectedPeripheralIdentifier])
            if let peripheral = restoredPeripherals.first, isSelectedDevice(peripheral) {
                peripheralsByIdentifier[peripheral.identifier] = peripheral
                connect(peripheral, using: centralManager)
                return
            }
            // Stored UUID points at a device whose name no longer matches the
            // selection (stale after a sensor/provider change); drop it and
            // fall back to discovering the selected device by name.
            selectedPeripheralUUID = ""
            SharedData.bluetoothHeartbeatPeripheralUUID = ""
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

    /// Identity of the user's chosen heartbeat device is its *name*; the stored
    /// UUID is only a fast-path for `retrievePeripherals`. Name is authoritative
    /// so a stale restored peripheral (e.g. a Dexcom left over from before the
    /// user switched to Libre) can't masquerade as the selection and hijack the
    /// connection. Falls back to UUID only when a peripheral has no cached name.
    private func isSelectedDevice(_ peripheral: CBPeripheral) -> Bool {
        guard !selectedDeviceName.isEmpty else { return false }
        let name = effectiveName(for: peripheral).uppercased()
        if !name.isEmpty {
            return name == selectedDeviceName
        }
        return selectedPeripheralIdentifier == peripheral.identifier
    }

    private func connect(_ peripheral: CBPeripheral, using centralManager: CBCentralManager) {
        guard isCentralPoweredOn else { return }
        // Single chokepoint for *initiating* a connection. Gating it on the
        // active provider neutralizes every re-arm path at once (disconnect,
        // connect-timeout, connect-failure, rediscovery, poweredOn, restored-
        // peripheral resume) so the heartbeat link can't be revived after a
        // switch to `.libre3BLE`, where `Libre3DirectManager` owns the sensor.
        guard isHeartbeatApplicableForActiveProvider else { return }
        guard isSelectedDevice(peripheral) else {
            Logger.connectivity.info("Ignoring connect to non-selected device \(self.effectiveName(for: peripheral).uppercased(), privacy: .public)")
            if peripheral.state == .connected || peripheral.state == .connecting {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            return
        }
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
        // Pending-connect sensors (Dexcom G7) advertise only briefly every
        // cycle; leave the connect pending until iOS satisfies it. Timing it
        // out here would cancel-and-retry every few seconds in a tight loop.
        if profile.usesPersistentConnection {
            startConnectionTimeout(for: peripheral.identifier)
        }
    }

    private func recordHeartbeat(source: String, bypassPropagationDelay: Bool = false) {
        let now = Date()
        let secondsSinceLastHeartbeat = now.timeIntervalSince(SharedData.bluetoothHeartbeatLastEventDate)
        guard secondsSinceLastHeartbeat >= Self.minimumHeartbeatInterval else {
            Logger.connectivity.debug("Skipping heartbeat; last heartbeat was \(secondsSinceLastHeartbeat, privacy: .public)s ago")
            return
        }

        lastHeartbeatDate = now
        SharedData.bluetoothHeartbeatLastEventDate = now
        PhoneHeartbeatRefreshCoordinator.shared.recordHeartbeat(source: source, bypassPropagationDelay: bypassPropagationDelay)
    }

    private func resumeRestoredPeripheralIfNeeded() {
        guard let restoredPeripheralAwaitingResume else { return }
        guard isCentralPoweredOn else { return }

        Logger.connectivity.info("Resuming restored peripheral \(restoredPeripheralAwaitingResume.identifier.uuidString, privacy: .public) state=\(restoredPeripheralAwaitingResume.state.rawValue, privacy: .public)")
        self.restoredPeripheralAwaitingResume = nil
        // Service discovery is only valid once connected; a restored
        // peripheral is often still .connecting (state=1). Discovering then
        // throws "API MISUSE: can only accept commands while connected".
        if restoredPeripheralAwaitingResume.state == .connected {
            subscribeToHeartbeatCharacteristics(for: restoredPeripheralAwaitingResume, rediscoverServices: true)
        } else if let centralManager {
            connect(restoredPeripheralAwaitingResume, using: centralManager)
        }
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
        if isCentralPoweredOn {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
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
        guard silenceInterval >= profile.watchdogTimeout else { return }

        Logger.connectivity.warning("Bluetooth heartbeat watchdog fired after \(silenceInterval, privacy: .public)s without notifications")
        subscribeToHeartbeatCharacteristics(for: connectedPeripheral, rediscoverServices: true)
        if isCentralPoweredOn {
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
        }
    }
}

extension BluetoothHeartbeatManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        hasReceivedCentralStateUpdate = true

        guard isEnabled else {
            status = .disabled
            return
        }

        switch central.state {
        case .poweredOn:
            resumeRestoredPeripheralIfNeeded()
            connectToSelectedDeviceIfAvailable()
            startScanning()
            startWatchdogIfNeeded()
        case .poweredOff:
            status = .bluetoothOff
            isScanning = false
        case .unsupported:
            status = .unsupported
        case .unauthorized:
            status = .unauthorized
        default:
            isScanning = false
            status = .unavailable
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        Logger.connectivity.info("centralManager willRestoreState")
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                peripheral.delegate = self
                peripheralsByIdentifier[peripheral.identifier] = peripheral
            }
            // Cancel standing connects to any restored peripheral that isn't the
            // currently-selected device — e.g. a previously-selected sensor left
            // over from before a provider switch. Otherwise its connect/notify/
            // disconnect events would fire heartbeats for the wrong sensor.
            for peripheral in restoredPeripherals where !isSelectedDevice(peripheral) {
                Logger.connectivity.info("Cancelling restored non-selected peripheral \(self.effectiveName(for: peripheral).uppercased(), privacy: .public)")
                central.cancelPeripheralConnection(peripheral)
            }
            if let restored = restoredPeripherals.first(where: { isSelectedDevice($0) }) {
                connectedPeripheral = restored
                if selectedPeripheralUUID.isEmpty {
                    selectedPeripheralUUID = restored.identifier.uuidString
                    SharedData.bluetoothHeartbeatPeripheralUUID = restored.identifier.uuidString
                }
                status = restored.state == .connected ? .connected : .idle
                lastNotificationDate = Date()
                startWatchdogIfNeeded()
                restoredPeripheralAwaitingResume = restored
                Logger.connectivity.info("Queued restored peripheral for resume after poweredOn: \(restored.identifier.uuidString, privacy: .public) state=\(restored.state.rawValue, privacy: .public)")
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
        // A connect already in flight when the user switched to `.libre3BLE`
        // can still land here — drop it so the heartbeat doesn't grab the link
        // the direct manager owns.
        guard isHeartbeatApplicableForActiveProvider else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        guard isSelectedDevice(peripheral) else {
            Logger.connectivity.info("Connected to non-selected device \(self.effectiveName(for: peripheral).uppercased(), privacy: .public); cancelling")
            central.cancelPeripheralConnection(peripheral)
            return
        }
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
        if profile.firesHeartbeatOnConnect {
            recordHeartbeat(source: "connect:\(effectiveName(for: peripheral).uppercased())")
        }
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
            if profile.usesPersistentConnection {
                startScanning()
            }
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
        // An expired Dexcom G7 connects then drops ~1 s later without ever
        // sending a value; the disconnect is the only tick left to keep Share
        // polling alive. No upload is pending, so skip the propagation delay.
        if profile.firesHeartbeatOnDisconnect {
            recordHeartbeat(source: "disconnect:\(effectiveName(for: peripheral).uppercased())", bypassPropagationDelay: true)
        }
        if isEnabled, !selectedDeviceName.isEmpty {
            status = .idle
            connectToSelectedDeviceIfAvailable()
            // For pending-connect sensors (Dexcom G7) a disconnect is the
            // normal end of a ~5 min cycle; just re-arm the standing connect.
            // Rescanning would spin the nil-service scan pointlessly.
            if profile.usesPersistentConnection {
                startScanning()
            }
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
