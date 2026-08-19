//
//  Libre3Mode.swift
//  FLwatch
//
//  The three Libre 3 direct-BLE pairing modes. Persisted (so the UI can show
//  how the current sensor was paired) and used by `Libre3PairingCoordinator` to
//  choose the LibreCRKit `Libre3NFCScanMode`. Also holds `Libre3ActivatingApp`,
//  which decides how the LibreView Account ID folds into the receiver ID.
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
    var usesLibreViewAccount: Bool { self != .flwatchOnly }

    /// Receiver ID for `accountID` under this app's fold, or `nil` when the value
    /// doesn't come from one: `.freeStyleLibre3` is routed through LibreCRKit's
    /// own FNV so the long-validated path stays byte-identical, and `.flwatchOnly`
    /// has no account at all.
    ///
    /// The `.libreByAbbott` fold was transcribed from that app as:
    ///
    ///     sum(int.from_bytes(b[i:i+4], "big", signed=True)
    ///         for i in range(0, len(b), 4))
    ///
    /// with two clarifications. The sum is wrapped to 32 bits — the field on the
    /// wire is 4 bytes, which the Python's unbounded accumulation doesn't reflect
    /// but the original `int` arithmetic would have. And `signed` makes no
    /// difference once wrapped: signed and unsigned readings of the same word
    /// differ by exactly 2³². A trailing partial word — impossible for the
    /// 36-character UUIDs LibreView returns, but defined here anyway — is read the
    /// way Python's `int.from_bytes` reads a short slice.
    func receiverIDValue(forAccountID accountID: String) -> UInt32? {
        guard self == .libreByAbbott else { return nil }
        let bytes = Array(accountID.lowercased().utf8)
        var sum: UInt32 = 0
        for start in stride(from: 0, to: bytes.count, by: 4) {
            var value: UInt32 = 0
            // A short slice ends up left-padded, matching `int.from_bytes`.
            for byte in bytes[start..<min(start + 4, bytes.count)] {
                value = (value << 8) | UInt32(byte)
            }
            sum = sum &+ value
        }
        return sum
    }
}
