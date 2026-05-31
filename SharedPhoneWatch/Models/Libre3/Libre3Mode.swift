//
//  Libre3Mode.swift
//  FLwatch
//
//  The three Libre 3 direct-BLE pairing modes. Persisted (so the UI can show
//  how the current sensor was paired) and used by `Libre3PairingCoordinator` to
//  choose the LibreCRKit `Libre3NFCScanMode`.
//
//  Kept in shared code (no LibreCRKit / CoreNFC import) because it round-trips
//  through `SharedData`, which compiles into the watch + widget targets that
//  don't link LibreCRKit. The mode → `Libre3NFCScanMode` mapping lives phone-
//  side in the coordinator, where the LibreCRKit types are available.
//

import Foundation

enum Libre3Mode: String, Codable, CaseIterable, Identifiable {
    /// Take over an already-active sensor (NFC `0xA8`, `switchReceiver`).
    /// Rotates the BLE PIN → FLwatch becomes the sole receiver; the vendor app
    /// loses the sensor and its LibreView upload stops. Fully grounded — the
    /// recommended primary flow (and the one implemented first, M1).
    case takeover

    /// Non-destructive parallel join of an already-active sensor (NFC `0xA0`,
    /// reads the *existing* PIN without rotating it), so the vendor app keeps
    /// working. Experimental and firmware-dependent — see PLAN §11.
    case parallelJoin

    /// Activate a brand-new sensor (NFC `0xA0` on state `0x01`). **Irreversible**
    /// — starts the 14-day wear clock. Advanced; recommend vendor-app activation
    /// instead (PLAN §5).
    case activateFresh

    var id: String { rawValue }

    /// Fresh activation is irreversible (starts the wear clock) → demands a hard
    /// confirmation before firing the command.
    var startsIrreversibleWearClock: Bool { self == .activateFresh }

    /// Parallel join rests on unvalidated firmware behaviour (PLAN §11) → gate
    /// behind a firmware check + an explicit "experimental" affordance.
    var isExperimental: Bool { self == .parallelJoin }

    /// True for modes that act on a sensor the vendor app already activated
    /// (takeover / parallel join), as opposed to activating a fresh one.
    var requiresAlreadyActiveSensor: Bool { self != .activateFresh }
}
