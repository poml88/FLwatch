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
final class BluetoothHeartbeatManager: NSObject, ObservableObject {
    static let shared = BluetoothHeartbeatManager()

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
    @Published private(set) var lastHeartbeatDate = SharedData.bluetoothHeartbeatLastEventDate.timeIntervalSince1970 > 0
        ? SharedData.bluetoothHeartbeatLastEventDate
        : nil

    private let heartbeatNameRegex = try? NSRegularExpression(pattern: "^[0-9A-F]{12}$")
    private var centralManager: CBCentralManager?
    private var peripheralsByIdentifier: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var pendingReconnect = false

    private override init() {
        super.init()
    }

    var isEnabled: Bool {
        SharedData.bluetoothHeartbeatEnabled
    }

    func setEnabled(_ isEnabled: Bool) {
        SharedData.bluetoothHeartbeatEnabled = isEnabled
        if isEnabled {
            startIfNeeded()
            startScanning()
            connectToSelectedDeviceIfAvailable()
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

    func selectDevice(named name: String) {
        selectedDeviceName = name
        SharedData.bluetoothHeartbeatDeviceName = name
        connectToSelectedDeviceIfAvailable()
    }

    func clearSelection() {
        SharedData.bluetoothHeartbeatDeviceName = ""
        selectedDeviceName = ""
        pendingReconnect = false
        if let connectedPeripheral {
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
        }
        connectedPeripheral = nil
        if isEnabled {
            startScanning()
        }
    }

    func stopMonitoring() {
        stopScanning()
        pendingReconnect = false
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

        if let peripheral = peripheralsByIdentifier.values.first(where: { effectiveName(for: $0).uppercased() == selectedDeviceName }) {
            pendingReconnect = true
            status = .connecting
            centralManager.connect(peripheral, options: nil)
        } else {
            startScanning()
        }
    }

    private func effectiveName(for peripheral: CBPeripheral, advertisementData: [String: Any]? = nil) -> String {
        if let localName = advertisementData?[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
            return localName
        }
        return peripheral.name ?? ""
    }

    private func recordHeartbeat(source: String) {
        lastHeartbeatDate = Date()
        if let lastHeartbeatDate {
            SharedData.bluetoothHeartbeatLastEventDate = lastHeartbeatDate
        }
        PhoneHeartbeatRefreshCoordinator.shared.recordHeartbeat(source: source)
    }

    private func subscribeToHeartbeatCharacteristics(for peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
}

extension BluetoothHeartbeatManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard isEnabled else {
            status = .disabled
            return
        }

        switch central.state {
        case .poweredOn:
            startScanning()
            connectToSelectedDeviceIfAvailable()
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
            connectedPeripheral = restoredPeripherals.first
            if connectedPeripheral != nil {
                status = .connected
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

        if name == selectedDeviceName {
            recordHeartbeat(source: "advertisement:\(name)")
            connectToSelectedDeviceIfAvailable()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        pendingReconnect = false
        peripheral.delegate = self
        status = .connected
        stopScanning()
        recordHeartbeat(source: "connect:\(effectiveName(for: peripheral).uppercased())")
        subscribeToHeartbeatCharacteristics(for: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        Logger.connectivity.error("Bluetooth heartbeat connect failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
        status = .idle
        if pendingReconnect {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        if peripheral.identifier == connectedPeripheral?.identifier {
            connectedPeripheral = nil
        }
        Logger.connectivity.info("Bluetooth heartbeat device disconnected: \(effectiveName(for: peripheral).uppercased(), privacy: .public)")
        if isEnabled, !selectedDeviceName.isEmpty {
            status = .idle
            startScanning()
            connectToSelectedDeviceIfAvailable()
        }
    }
}

extension BluetoothHeartbeatManager: CBPeripheralDelegate {
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

        service.characteristics?.forEach { characteristic in
            let supportsNotify = characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
            if supportsNotify {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error {
            Logger.connectivity.error("Bluetooth heartbeat notification subscription failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        if characteristic.isNotifying {
            recordHeartbeat(source: "notify-enabled:\(effectiveName(for: peripheral).uppercased())")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error {
            Logger.connectivity.error("Bluetooth heartbeat notification update failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        recordHeartbeat(source: "notification:\(effectiveName(for: peripheral).uppercased())")
    }
}
#endif
