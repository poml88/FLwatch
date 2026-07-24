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
    /// Selects the retry strategy for obtaining heartbeat callbacks.
    /// Libre 3 uses a successful connect as its tick, so an attempt that does
    /// not connect quickly is cancelled and discovery restarts. Dexcom G7 uses
    /// the disconnect callback as its tick; its connect request remains pending
    /// until the next brief advertising window.
    ///
    /// Despite the historical name, this does not mean FLwatch owns Libre's
    /// authenticated sensor connection; the official Libre app retains that role.
    var usesPersistentConnection: Bool { get }
    /// Treat a successful BLE connect as a tick. True for Libre 3 (it advertises
    /// a fresh value on connect); false for G7 (the connect carries no new
    /// value — the value-update and disconnect do).
    var firesHeartbeatOnConnect: Bool { get }
    /// Treat a BLE disconnect as a tick. True for G7: an expired G7 connects
    /// then drops ~1 s later without ever sending a value, so the disconnect is
    /// the only signal left to keep Share polling alive. (A live G7's data-
    /// bearing notification fires first and debounces the disconnect out.)
    /// False for Libre 3 because its heartbeat is recorded on connect, not disconnect.
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
        case .libre3BLE:
            // The heartbeat is disabled in direct-BLE mode (Libre3DirectManager
            // owns the sensor link), so this profile is never actually
            // consulted. Return the Libre profile as a harmless default to keep
            // the switch exhaustive.
            return LibreHeartbeatProfile()
        }
    }

    /// Profile for the currently-active provider. Read live, so a provider
    /// switch takes effect on the next BLE callback without an explicit rebuild.
    static var current: HeartbeatConnectionProfile {
        make(for: SharedData.cgmProviderKind)
    }
}
