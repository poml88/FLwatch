//
//  Libre3DiagnosticsLog.swift
//  FLwatch
//
//  The rare-event ring, notable-event ring, and reconnect trace contain no
//  glucose values, sensor identifiers, credentials, or BLE payloads — durations,
//  event names, and error codes only. The trace is a separate, bounded
//  per-attempt timeline; it must never be written into either event ring. This is
//  the same content policy as `Libre3DirectManager.supportSafeDescription(for:)`.
//

#if os(iOS)
import Foundation

@MainActor
enum Libre3DiagnosticsLog {
    private static let storageEntryLimit = 100
    private static let supportEntryLimit = 20
    private static let supportCharacterLimit = 1_500
    private static let reconnectTraceStorageEntryLimit = 40
    private static let reconnectTraceSupportEntryLimit = 12
    private static let reconnectTraceSupportCharacterLimit = 1_200
    private static let notableEventStorageEntryLimit = 50

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
        return Array(SharedData.libre3DiagnosticEvents.suffix(limit).reversed())
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
        Array(SharedData.libre3NotableEvents.reversed())
    }

    /// All retained rare events and reconnect-trace lines, newest first.
    /// Both rings remain separate on the write side.
    static func mergedEntries() -> [String] {
        (SharedData.libre3DiagnosticEvents + SharedData.libre3ReconnectTrace)
            .sorted(by: >)
    }

    /// Clipboard export of lifetime stats plus every entry still retained by the
    /// three bounded rings. Unlike email, this applies no additional caps.
    static func fullExportText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? "unknown"
        let header = "FLwatch \(version) (\(build)) — Libre 3 diagnostics exported \(timestampFormatter.string(from: Date()))"
        let glucoseOnlyLastSeen = SharedData.libre3GlucoseOnlyDeathLastSeen
            .map { timestampFormatter.string(from: $0) } ?? "never"
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

        for entry in SharedData.libre3ReconnectTrace
            .suffix(reconnectTraceSupportEntryLimit)
            .reversed() {
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
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    static func resetLifetimeEventStats() {
        SharedData.libre3GlucoseOnlyDeathCount = 0
        SharedData.libre3GlucoseOnlyDeathLastSeen = nil
        NotificationCenter.default.post(name: .libre3DiagnosticsDidChange, object: nil)
    }

    private static func timestamped(_ event: String, at date: Date) -> String {
        "\(timestampFormatter.string(from: date)) \(event)"
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
