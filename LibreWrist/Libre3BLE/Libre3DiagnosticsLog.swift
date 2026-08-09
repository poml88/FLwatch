//
//  Libre3DiagnosticsLog.swift
//  FLwatch
//
//  Content policy, in two tiers:
//
//  * Support-safe rings — the rare-event ring, notable-event ring, and reconnect
//    trace contain no glucose values, sensor identifiers, credentials, or BLE
//    payloads — durations, event names, and error codes only. The trace is a
//    separate, bounded per-attempt timeline; it must never be written into either
//    event ring. This is the same content policy as
//    `Libre3DirectManager.supportSafeDescription(for:)`. These three are what the
//    support-email blocks draw from.
//  * Local stuck-glucose evidence — a maximum of ten anomaly snapshots. Each
//    contains only eight compact decoded realtime fingerprints; no decrypted
//    plaintext, credentials, or sensor identifiers. It is written only when the
//    stuck detector fires, exported only by an explicit developer clipboard
//    action, and never folded into a support email.
//

#if os(iOS)
import Foundation

/// Compact evidence retained only when the diagnostic stuck detector fires.
/// Frames are kept as raw scalar fields so formatting work happens only when the
/// developer opens or exports the evidence.
struct Libre3StuckEvidenceSnapshot: Codable, Identifiable, Equatable {
    struct Frame: Codable, Equatable {
        let receivedAt: Date
        let lifeCount: UInt16
        let currentWord: UInt16
        let uncappedCurrentMgDL: UInt16
        let currentGlucoseMgDL: UInt16?
        let dqErrorRaw: UInt16
        let sensorConditionRaw: UInt8
        let actionableStatus: UInt8
        let rateOfChangeRaw: Int16
        let trendAndStatusByte: UInt8
        let isUsable: Bool
    }

    let id: UUID
    let detectedAt: Date
    let run: Int
    let frames: [Frame]
}

@MainActor
enum Libre3DiagnosticsLog {
    private static let storageEntryLimit = 100
    private static let supportEntryLimit = 20
    private static let supportCharacterLimit = 1_500
    private static let reconnectTraceStorageEntryLimit = 120
    private static let reconnectTraceSupportEntryLimit = 12
    private static let reconnectTraceSupportCharacterLimit = 1_200
    private static let notableEventStorageEntryLimit = 50
    private static let stuckSnapshotStorageLimit = 10

    /// Entries stay in UTC internally so persisted rings retain one sortable format.
    private static let storageTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Human-readable diagnostics use the device's current time zone.
    private static let localTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Records rare events only. Do not add per-reading events, lifecycle
    /// backoff retries, or ESA/data-quality episodes here.
    static func record(_ event: String) {
        let entry = timestamped(event, at: Date())
        SharedData.libre3DiagnosticEvents = appending(
            entry, to: SharedData.libre3DiagnosticEvents, limit: storageEntryLimit
        )
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    /// Records a genuinely important line in both the general rare-event ring
    /// and the longer-lived notable-event ring using one identical timestamp.
    static func recordNotable(_ event: String, at date: Date = Date()) {
        let entry = timestamped(event, at: date)
        SharedData.libre3DiagnosticEvents = appending(
            entry, to: SharedData.libre3DiagnosticEvents, limit: storageEntryLimit
        )
        SharedData.libre3NotableEvents = appending(
            entry, to: SharedData.libre3NotableEvents, limit: notableEventStorageEntryLimit
        )
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func recentEntries(limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        return SharedData.libre3DiagnosticEvents
            .suffix(limit)
            .reversed()
            .map { localizedEntry($0) }
    }

    /// Records the compact connect/reconnect timeline separately from the
    /// rare-event ring. Callers must follow the same support-safe content policy.
    static func traceReconnect(_ line: String) {
        let entry = timestamped(line, at: Date())
        SharedData.libre3ReconnectTrace = appending(
            entry, to: SharedData.libre3ReconnectTrace, limit: reconnectTraceStorageEntryLimit
        )
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func notableEntries() -> [String] {
        SharedData.libre3NotableEvents.reversed().map { localizedEntry($0) }
    }

    // MARK: - Stuck-glucose evidence (local developer diagnostics)

    /// Decode the compact snapshot ring. The raw key previously held the removed
    /// high-volume stream format; if that obsolete payload is encountered, clear
    /// it once instead of retaining or repeatedly trying to decode it.
    private static func storedStuckSnapshots() -> [Libre3StuckEvidenceSnapshot] {
        if let snapshots = SharedData.store.getArray(
            [Libre3StuckEvidenceSnapshot].self,
            forKey: .libre3StuckSnapshots
        ) {
            return snapshots
        }
        if SharedData.store.object(forKey: DefaultsKey.libre3StuckSnapshots.rawValue) != nil {
            SharedData.store.removeObject(forKey: DefaultsKey.libre3StuckSnapshots.rawValue)
        }
        return []
    }

    /// Retained anomaly snapshots, newest first.
    static func stuckSnapshots() -> [Libre3StuckEvidenceSnapshot] {
        storedStuckSnapshots().reversed()
    }

    /// One persistence write per detected anomaly — never per packet.
    static func recordStuckSnapshot(
        run: Int,
        frames: [Libre3StuckEvidenceSnapshot.Frame],
        at detectedAt: Date = Date()
    ) {
        var snapshots = storedStuckSnapshots()
        snapshots.append(
            Libre3StuckEvidenceSnapshot(
                id: UUID(),
                detectedAt: detectedAt,
                run: run,
                frames: frames
            )
        )
        if snapshots.count > stuckSnapshotStorageLimit {
            snapshots.removeFirst(snapshots.count - stuckSnapshotStorageLimit)
        }
        SharedData.store.setArray(snapshots, forKey: .libre3StuckSnapshots)
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func stuckEvidenceExportText() -> String {
        let snapshots = stuckSnapshots()
        guard !snapshots.isEmpty else { return "" }
        let header = "\(appBuildDescription) — Libre 3 stuck-glucose evidence exported \(localTimestamp(from: Date()))"
        let blocks = snapshots.map { snapshot -> String in
            let head = "\(localTimestamp(from: snapshot.detectedAt)) run=\(snapshot.run)"
            let frames = snapshot.frames.map { frame in
                let glucose = frame.currentGlucoseMgDL.map(String.init) ?? "nil"
                let word = String(format: "0x%04x", Int(frame.currentWord))
                let dq = String(format: "0x%04x", Int(frame.dqErrorRaw))
                let trendStatus = String(format: "0x%02x", Int(frame.trendAndStatusByte))
                return "    \(localTimestamp(from: frame.receivedAt)) lc=\(frame.lifeCount) glucose=\(glucose) uncapped=\(frame.uncappedCurrentMgDL) word=\(word) dq=\(dq) condition=\(frame.sensorConditionRaw) actionable=\(frame.actionableStatus) rocRaw=\(frame.rateOfChangeRaw) trendStatus=\(trendStatus) usable=\(frame.isUsable)"
            }
            return ([head] + frames).joined(separator: "\n")
        }
        return ([header, ""] + blocks).joined(separator: "\n")
    }

    static func clearStuckSnapshots() {
        SharedData.store.removeObject(forKey: DefaultsKey.libre3StuckSnapshots.rawValue)
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    /// All retained rare events and reconnect-trace lines, newest first.
    /// Both rings remain separate on the write side.
    static func mergedEntries() -> [String] {
        (SharedData.libre3DiagnosticEvents + SharedData.libre3ReconnectTrace)
            .sorted(by: >)
            .map { localizedEntry($0) }
    }

    /// Clipboard export of lifetime stats plus every entry still retained by the
    /// three bounded rings. Unlike email, this applies no additional caps.
    static func fullExportText() -> String {
        let header = "\(appBuildDescription) — Libre 3 diagnostics exported \(localTimestamp(from: Date()))"
        let glucoseOnlyLastSeen = SharedData.libre3GlucoseOnlyDeathLastSeen
            .map { localTimestamp(from: $0) } ?? "never"
        let notable = notableEntries()
        let merged = mergedEntries()
        return ([
            header,
            "",
            "Lifetime stats:",
            "Glucose-only deaths: \(SharedData.libre3GlucoseOnlyDeathCount) · last \(glucoseOnlyLastSeen)",
            "",
            "Notable events:",
        ]
            + (notable.isEmpty ? ["None"] : notable)
            + ["", "Merged retained log:"]
            + (merged.isEmpty ? ["None"] : merged))
            .joined(separator: "\n")
    }

    /// Owns support-mail formatting. Both the count and character caps matter:
    /// `mailto:` URL length is constrained, and long entries can hit that limit
    /// well before the 20-entry bound.
    static func supportEmailBlock() -> String {
        let header = "Libre3 diagnostics:"
        var lines = [header]
        var characterCount = header.count

        for entry in recentEntries(limit: supportEntryLimit) {
            let addedCharacters = 1 + entry.count   // separating newline + entry
            guard characterCount + addedCharacters <= supportCharacterLimit else { break }
            lines.append(entry)
            characterCount += addedCharacters
        }

        guard lines.count > 1 else { return "" }
        return lines.joined(separator: "\n")
    }

    static func reconnectTraceEmailBlock() -> String {
        let header = "Libre3 reconnect trace:"
        var lines = [header]
        var characterCount = header.count

        for storedEntry in SharedData.libre3ReconnectTrace
            .suffix(reconnectTraceSupportEntryLimit)
            .reversed() {
            let entry = localizedEntry(storedEntry)
            let addedCharacters = 1 + entry.count   // separating newline + entry
            guard characterCount + addedCharacters <= reconnectTraceSupportCharacterLimit else { break }
            lines.append(entry)
            characterCount += addedCharacters
        }

        guard lines.count > 1 else { return "" }
        return lines.joined(separator: "\n")
    }

    static func clear() {
        SharedData.libre3DiagnosticEvents = []
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func clearReconnectTrace() {
        SharedData.libre3ReconnectTrace = []
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func clearNotableEvents() {
        SharedData.libre3NotableEvents = []
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func clearAllLogs() {
        SharedData.libre3DiagnosticEvents = []
        SharedData.libre3ReconnectTrace = []
        SharedData.libre3NotableEvents = []
        SharedData.store.removeObject(forKey: DefaultsKey.libre3StuckSnapshots.rawValue)
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func resetLifetimeEventStats() {
        SharedData.libre3GlucoseOnlyDeathCount = 0
        SharedData.libre3GlucoseOnlyDeathLastSeen = nil
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    /// Shared export header prefix, so the two clipboard exports always name the
    /// same build.
    private static var appBuildDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? "unknown"
        return "FLwatch \(version) (\(build))"
    }

    private static func timestamped(_ event: String, at date: Date) -> String {
        "\(storageTimestampFormatter.string(from: date)) \(event)"
    }

    private static func localTimestamp(from date: Date) -> String {
        // Refresh in case the device's time zone changed while the app was running.
        localTimestampFormatter.timeZone = TimeZone.current
        return localTimestampFormatter.string(from: date)
    }

    /// Converts the leading stored timestamp while leaving the diagnostic text intact.
    private static func localizedEntry(_ entry: String) -> String {
        guard let separator = entry.firstIndex(of: " ") else { return entry }
        let timestamp = String(entry[..<separator])
        guard let date = storageTimestampFormatter.date(from: timestamp) else { return entry }
        return localTimestamp(from: date) + String(entry[separator...])
    }

    private static func appending(_ entry: String, to existing: [String], limit: Int) -> [String] {
        var entries = existing
        entries.append(entry)
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        return entries
    }
}
#endif
