//
//  Libre3Mode.swift
//  FLwatch
//
//  The three Libre 3 direct-BLE pairing modes. Persisted (so the UI can show
//  how the current sensor was paired) and used by `Libre3PairingCoordinator` to
//  choose the LibreCRKit `Libre3NFCScanMode`. Also holds the temporary
//  `Libre3ReceiverIDDerivation` probe (see its own doc comment).
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

/// Which derivation turns the LibreView Account ID into the receiver ID sent in
/// the NFC command body.
///
/// **Temporary diagnostic (branch `getLbAReceiverID`).** Sensors started with the
/// US "Libre by Abbott" app reject takeover and parallel join with `0xB1` — a
/// receiver-ID mismatch — even when the Account ID is correct, so that app
/// appears to derive the ID differently. The `newApp…` cases reproduce a
/// derivation reverse-engineered from it. Once one of them is confirmed (or all
/// are ruled out), collapse this back to `.classic` and delete the rest.
///
/// Lives here rather than in its own file only to avoid a manual Xcode
/// target-membership step for something we intend to remove.
enum Libre3ReceiverIDDerivation: String, Codable, CaseIterable, Identifiable {
    /// FNV-style multiply-xor chain over the lowercased Account ID — what the
    /// classic FreeStyle Libre 3 app uses. Validated on hardware, and shared with
    /// Juggluco (`javasettings.cpp`) and DiaBLE. The default, and the only case
    /// that pairs successfully today.
    case classic

    // The reverse-engineered sum, across the readings its transcription leaves
    // open. Ordered by how likely each is to be what the app actually does —
    // the picker shows them numbered in this order so a tester can work down
    // the list.

    /// Sum over the lowercase dashed Account ID's bytes. The most literal
    /// reading of the transcribed Python.
    case textLowerBigEndian
    case textLowerLittleEndian

    /// Sum over the UUID's raw 16 bytes rather than its text. Four 4-byte words
    /// exactly, which is the shape a "sum of 32-bit words" fold is usually
    /// written for — the `.encode()` in the transcription may be the
    /// transcriber's reading rather than the original's.
    case uuidBytesBigEndian
    case uuidBytesLittleEndian

    /// Sum over the UPPERCASE dashed form. Swift's `UUID.uuidString` is
    /// uppercase, so an app that round-trips the ID through `UUID` hashes this.
    case textUpperBigEndian
    case textUpperLittleEndian

    var id: String { rawValue }

    /// Short label for the diagnostic picker, numbered so instructions can just
    /// say "try 1 through 6". Not localized — this UI is temporary.
    var displayName: String {
        switch self {
        case .classic: return "Classic (FNV)"
        case .textLowerBigEndian: return "1 · text lower · BE"
        case .textLowerLittleEndian: return "2 · text lower · LE"
        case .uuidBytesBigEndian: return "3 · UUID bytes · BE"
        case .uuidBytesLittleEndian: return "4 · UUID bytes · LE"
        case .textUpperBigEndian: return "5 · text UPPER · BE"
        case .textUpperLittleEndian: return "6 · text UPPER · LE"
        }
    }

    /// True for the variants that hash the UUID's raw bytes, which need the
    /// Account ID to parse as a UUID.
    var needsUUID: Bool {
        self == .uuidBytesBigEndian || self == .uuidBytesLittleEndian
    }

    /// The reverse-engineered receiver ID for `accountID`, or `nil` for
    /// `.classic` — that one stays routed through LibreCRKit's own FNV so the
    /// working path is byte-identical to what shipped. Also `nil` for the
    /// UUID-byte variants when `accountID` doesn't parse as a UUID, which the
    /// caller likewise resolves to `.classic`.
    ///
    /// Faithful to the Python the derivation was transcribed as:
    ///
    ///     sum(int.from_bytes(b[i:i+4], "big", signed=True)
    ///         for i in range(0, len(b), 4))
    ///
    /// with two clarifications. The sum is wrapped to 32 bits (the field on the
    /// wire is 4 bytes; the Python accumulates unbounded, which the original
    /// `int` arithmetic would not have). And `signed` is irrelevant once wrapped:
    /// signed and unsigned readings of the same word differ by exactly 2³². A
    /// trailing partial word — impossible for the 36-character UUIDs we expect,
    /// but defined here anyway — is read the same way Python's `int.from_bytes`
    /// would read a short slice.
    func newAppValue(forAccountID accountID: String) -> UInt32? {
        let littleEndian: Bool
        let bytes: [UInt8]
        switch self {
        case .classic:
            return nil
        case .textLowerBigEndian, .textLowerLittleEndian:
            littleEndian = self == .textLowerLittleEndian
            bytes = Array(accountID.lowercased().utf8)
        case .textUpperBigEndian, .textUpperLittleEndian:
            littleEndian = self == .textUpperLittleEndian
            bytes = Array(accountID.uppercased().utf8)
        case .uuidBytesBigEndian, .uuidBytesLittleEndian:
            guard let uuid = UUID(uuidString: accountID) else { return nil }
            littleEndian = self == .uuidBytesLittleEndian
            // `uuid.uuid` is a contiguous 16-byte tuple in canonical order.
            bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        }

        var sum: UInt32 = 0
        for start in stride(from: 0, to: bytes.count, by: 4) {
            let word = bytes[start..<min(start + 4, bytes.count)]
            var value: UInt32 = 0
            if littleEndian {
                for (offset, byte) in word.enumerated() {
                    value |= UInt32(byte) << (8 * offset)
                }
            } else {
                // A short slice ends up left-padded, matching `int.from_bytes`.
                for byte in word {
                    value = (value << 8) | UInt32(byte)
                }
            }
            sum = sum &+ value
        }
        return sum
    }
}
