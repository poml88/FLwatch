//
//  HeartbeatConnectionProfile.swift
//  LibreWrist
//
//  BLE-timing policy for the Bluetooth heartbeat, per sensor family.
//
//  The heartbeat piggybacks on the sensor's BLE connect/notify/disconnect
//  rhythm purely as a timing signal: which of those events counts as a "tick",
//  and how the connection is managed between ticks, differs per sensor. This
//  isolates those (≈6) decisions so the shared CoreBluetooth engine in
//  `BluetoothHeartbeatManager` stays single-sourced and the Libre path can't
//  be disturbed by Dexcom changes. Mirrors xdrip4ios's split into
//  per-transmitter heartbeat classes (DexcomG7 / Libre3).
//

import Foundation

protocol HeartbeatConnectionProfile {
    /// Libre 3 keeps a *persistent* connection that streams a notification
    /// every ~1 min, so a connect that doesn't land quickly is a real failure
    /// worth a timeout + rescan retry. Dexcom G7 instead advertises/connects
    /// for ~1 s every ~5 min then drops; a standing connect left pending lets
    /// iOS reconnect (and background-wake us) on its next advertise, with no
    /// timeout and no rescan. When false, the manager never times the connect
    /// out or rescans to recover — it just re-arms the pending connect.
    var usesPersistentConnection: Bool { get }
    /// Treat a successful BLE connect as a tick. True for Libre 3 (it advertises
    /// a fresh value on connect); false for G7 (the connect carries no new
    /// value — the value-update and disconnect do).
    var firesHeartbeatOnConnect: Bool { get }
    /// Treat a BLE disconnect as a tick. True for G7: an expired G7 connects
    /// then drops ~1 s later without ever sending a value, so the disconnect is
    /// the only signal left to keep Share polling alive. (A live G7's data-
    /// bearing notification fires first and debounces the disconnect out.)
    /// False for Libre, which never drops between readings.
    var firesHeartbeatOnDisconnect: Bool { get }
    /// Notification silence on a live connection tolerated before the manager
    /// rediscovers services and force-reconnects. Sized to ~one sensor cycle:
    /// Libre ~2 min (1-min cadence); Dexcom 5.5 min (5-min cadence) — a tighter
    /// window would force-reconnect a healthy G7 every cycle.
    var watchdogTimeout: TimeInterval { get }
    /// Head start given to the publisher's official app to upload the just-
    /// advertised reading to the cloud before we fetch — otherwise the
    /// heartbeat-triggered fetch races the upload and returns the *previous*
    /// reading. xdrip4ios uses 1 s; we give both sensors 3 s.
    var fetchDelay: TimeInterval { get }
}

extension HeartbeatConnectionProfile {
    var fetchDelay: TimeInterval { 3 }
}

struct LibreHeartbeatProfile: HeartbeatConnectionProfile {
    var usesPersistentConnection: Bool { true }
    var firesHeartbeatOnConnect: Bool { true }
    var firesHeartbeatOnDisconnect: Bool { false }
    var watchdogTimeout: TimeInterval { 120 }
}

struct DexcomG7HeartbeatProfile: HeartbeatConnectionProfile {
    var usesPersistentConnection: Bool { false }
    var firesHeartbeatOnConnect: Bool { false }
    var firesHeartbeatOnDisconnect: Bool { true }
    var watchdogTimeout: TimeInterval { 5.5 * 60 }
}

enum HeartbeatConnectionProfileFactory {
    static func make(for kind: CGMProviderKind) -> HeartbeatConnectionProfile {
        switch kind {
        case .libreLinkUp:
            return LibreHeartbeatProfile()
        case .dexcomShare:
            return DexcomG7HeartbeatProfile()
        }
    }

    /// Profile for the currently-active provider. Read live, so a provider
    /// switch takes effect on the next BLE callback without an explicit rebuild.
    static var current: HeartbeatConnectionProfile {
        make(for: SharedData.cgmProviderKind)
    }
}
