//
//  Libre3DiagnosticsLog.swift
//  FLwatch
//
//  Field diagnostics contain no glucose values, sensor identifiers,
//  credentials, or BLE payloads — durations, event names, and error codes only.
//  This is the same content policy as
//  `Libre3DirectManager.supportSafeDescription(for:)`.
//

#if os(iOS)
import Foundation

@MainActor
enum Libre3DiagnosticsLog {
    private static let storageEntryLimit = 100
    private static let supportEntryLimit = 20
    private static let supportCharacterLimit = 1_500

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

    static func clear() {
        SharedData.libre3DiagnosticEvents = []
    }
}
#endif
