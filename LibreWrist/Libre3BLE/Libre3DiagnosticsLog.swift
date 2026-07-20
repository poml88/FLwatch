//
//  Libre3DiagnosticsLog.swift
//  FLwatch
//
//  Both the rare-event ring and the reconnect trace contain no glucose values,
//  sensor identifiers, credentials, or BLE payloads — durations, event names,
//  and error codes only. The trace is a separate, bounded per-attempt timeline;
//  it must never be written into the rare-event ring. This is the same content
//  policy as `Libre3DirectManager.supportSafeDescription(for:)`.
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

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Records rare events only. Do not add per-reading events, lifecycle
    /// backoff retries, or ESA/data-quality episodes here.
    static func record(_ event: String) {
        let timestamp = timestampFormatter.string(from: Date())
        var entries = SharedData.libre3DiagnosticEvents
        entries.append("\(timestamp) \(event)")
        if entries.count > storageEntryLimit {
            entries.removeFirst(entries.count - storageEntryLimit)
        }
        SharedData.libre3DiagnosticEvents = entries
    }

    static func recentEntries(limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        return Array(SharedData.libre3DiagnosticEvents.suffix(limit).reversed())
    }

    /// Records the compact connect/reconnect timeline separately from the
    /// rare-event ring. Callers must follow the same support-safe content policy.
    static func traceReconnect(_ line: String) {
        let timestamp = timestampFormatter.string(from: Date())
        var entries = SharedData.libre3ReconnectTrace
        entries.append("\(timestamp) \(line)")
        if entries.count > reconnectTraceStorageEntryLimit {
            entries.removeFirst(entries.count - reconnectTraceStorageEntryLimit)
        }
        SharedData.libre3ReconnectTrace = entries
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
    }

    static func clearReconnectTrace() {
        SharedData.libre3ReconnectTrace = []
    }
}
#endif
