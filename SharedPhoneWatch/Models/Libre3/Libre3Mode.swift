//
//  Libre3Mode.swift
//  FLwatch
//
//  The three Libre 3 direct-BLE pairing modes. Persisted (so the UI can show
//  how the current sensor was paired) and used by `Libre3PairingCoordinator` to
//  choose the LibreCRKit `Libre3NFCScanMode`. Also holds `Libre3ActivatingApp`,
//  which selects the fold LibreCRKit applies to the LibreView Account ID.
//
//  Kept in shared code (no LibreCRKit / CoreNFC import) because it round-trips
//  through `SharedData`, which compiles into the watch + widget targets that
//  don't link LibreCRKit. For the same reason both mappings onto LibreCRKit
//  types live phone-side: mode → `Libre3NFCScanMode` in the coordinator,
//  activating app → `Libre3ReceiverID.Derivation` in `Libre3StateStore`.
//

import Foundation

enum Libre3Mode: String, Codable, CaseIterable, Identifiable {
    /// Take over an already-active sensor (NFC `0xA8`, `switchReceiver`).
    /// Rotates the BLE PIN → FLwatch becomes the sole receiver; the vendor app
    /// loses the sensor and its LibreView upload stops.
    case takeover

    /// Non-destructive parallel join of an already-active sensor (NFC `0xA0`,
    /// reads the *existing* PIN without rotating it), so the vendor app keeps
    /// its credentials and can reconnect when FLwatch releases the sensor.
    /// This is the recommended pairing mode.
    case parallelJoin

    /// Activate a brand-new sensor (NFC `0xA0` on state `0x01`). **Irreversible**
    /// — starts the sensor's wear period. Advanced; recommend vendor-app activation
    /// instead (PLAN §5).
    case activateFresh

    var id: String { rawValue }

    /// Fresh activation is irreversible (starts the wear clock) → demands a hard
    /// confirmation before firing the command.
    var startsIrreversibleWearClock: Bool { self == .activateFresh }

    /// True for modes that act on a sensor the vendor app already activated
    /// (takeover / parallel join), as opposed to activating a fresh one.
    var requiresAlreadyActiveSensor: Bool { self != .activateFresh }
}

/// The app a sensor was activated with, which decides the receiver ID FLwatch
/// must present over NFC.
///
/// A sensor stores a receiver ID when it is activated and rejects any later
/// `0xA8`/`0xA0` carrying a different one with error `0xB1`. Abbott's apps derive
/// that ID from the same LibreView Account ID but fold it differently, so the
/// user has to tell us which app started the sensor — nothing in the patch info
/// reveals it.
///
/// For **fresh activation** the choice works the other way round: FLwatch writes
/// the ID, and only the matching app could ever take the sensor over afterwards.
/// It is strictly one or the other.
enum Libre3ActivatingApp: String, Codable, CaseIterable, Identifiable {
    /// The classic FreeStyle Libre 3 app (worldwide, and "FreeStyle Libre 3 – US").
    /// Receiver ID = FNV-style multiply-xor over the lowercased Account ID, the
    /// same derivation Juggluco and DiaBLE use.
    case freeStyleLibre3

    /// Abbott's newer US app, "Libre by Abbott". Same LibreView Account ID, folded
    /// differently: the sum of its big-endian 4-byte words, wrapped to 32 bits.
    /// Reverse-engineered from that app and confirmed on hardware 2026-08-19 (a
    /// US Libre 3 Plus, fw 1.4.2.30, paired in Parallel and streaming).
    case libreByAbbott

    /// No vendor app — FLwatch activates the sensor itself and presents its own
    /// permanent installation receiver ID. Chosen for fresh activation, and
    /// required again to re-pair such a sensor afterwards: that ID is the only
    /// one it will accept, and no vendor app can adopt it.
    case flwatchOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .freeStyleLibre3:
            return String(
                localized: "FreeStyle Libre 3",
                comment: "Picker option naming the app that started the sensor: Abbott's classic FreeStyle Libre 3 app. Keep the product name untranslated."
            )
        case .libreByAbbott:
            return String(
                localized: "Libre by Abbott",
                comment: "Picker option naming the app that started the sensor: Abbott's newer US app, called 'Libre by Abbott' in the App Store. Keep the product name untranslated."
            )
        case .flwatchOnly:
            return String(
                localized: "FLwatch only",
                comment: "Picker option for a sensor no vendor app is involved with — FLwatch activates it itself. FLwatch is the app name, keep untranslated."
            )
        }
    }

    /// True when the receiver ID is derived from the user's LibreView Account ID,
    /// so the account rows are needed and takeover / parallel join are possible.
    ///
    /// Answers the same question as the phone-side `derivation` mapping in
    /// `Libre3StateStore`, which can't live here because it names a LibreCRKit
    /// type this file's other targets don't link. Exhaustive on purpose, so a new
    /// case forces both switches to be revisited; that the two agree is asserted
    /// by `LibreWristTests.testActivatingAppAccountUseMatchesDerivation`.
    var usesLibreViewAccount: Bool {
        switch self {
        case .freeStyleLibre3, .libreByAbbott:
            return true
        case .flwatchOnly:
            return false
        }
    }
}
