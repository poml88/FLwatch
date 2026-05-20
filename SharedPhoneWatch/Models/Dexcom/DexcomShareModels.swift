//
//  DexcomShareModels.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  Domain types for the unofficial Dexcom Share API.
//  Endpoints: share2.dexcom.com (US), shareous1.dexcom.com (everywhere else).
//

import Foundation

// MARK: - Constants

enum DexcomShareConstants {
    /// Well-known applicationId used by Loop, xDrip4iOS, Spike, etc. for
    /// every Share region except Japan, which uses a separate one (below).
    /// Do not change without coordinating with the wider open-source CGM ecosystem.
    static let applicationId = "d89443d2-327c-4a6f-89e5-496bbb0317db"

    /// Japan has its own applicationId that the non-JP one is rejected against.
    static let applicationIdJapan = "d8665ade-9673-4e27-9ff6-92db4ce13d13"

    /// Path prefix shared by every Share endpoint.
    static let basePath = "/ShareWebServices/Services"

    /// User-Agent used on the *read* path (`ReadPublisherLatestGlucoseValues`).
    /// Mirrors xdripswift's `DexcomShareFollowManager` exactly: literal space
    /// between "Dexcom" and "Share".
    static let userAgent = "Dexcom Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0"

    /// User-Agent used on the *auth* endpoints (`AuthenticatePublisherAccount`
    /// and `LoginPublisherAccountById`). xdripswift sends the URL-encoded
    /// space form here even though the read path uses a literal space — the
    /// split is intentional, not a transcription quirk, so we mirror it.
    static let userAgentAuth = "Dexcom%20Share/3.0.2.11 CFNetwork/1390 Darwin/22.0.0"
}

// MARK: - Region

enum ShareRegion: String, Codable, CaseIterable {
    case us
    /// "Outside US": Europe, Australia, Canada, Korea, Hong Kong, etc.
    /// (Historical name kept for compatibility with previously-saved values.)
    case ous
    case japan

    var host: String {
        switch self {
        case .us:    return "https://share2.dexcom.com"
        case .ous:   return "https://shareous1.dexcom.com"
        case .japan: return "https://share.dexcom.jp"
        }
    }

    var displayName: String {
        switch self {
        case .us:    return "United States"
        case .ous:   return "Outside United States"
        case .japan: return "Japan"
        }
    }

    /// Japan rejects the standard applicationId — needs its own.
    var applicationId: String {
        switch self {
        case .japan: return DexcomShareConstants.applicationIdJapan
        default:     return DexcomShareConstants.applicationId
        }
    }
}

// MARK: - Trend

/// Dexcom Share trend codes. Older servers return ints 1..9, newer servers
/// return capitalised strings ("DoubleUp", "Flat", ...). The custom decoder
/// accepts both per-entry — they have been observed mixed inside a single response.
enum ShareTrend: Int, Codable {
    case doubleUp       = 1
    case singleUp       = 2
    case fortyFiveUp    = 3
    case flat           = 4
    case fortyFiveDown  = 5
    case singleDown     = 6
    case doubleDown     = 7
    case notComputable  = 8
    case rateOutOfRange = 9

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self),
           let parsed = ShareTrend(rawValue: intValue) {
            self = parsed
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = Self.fromString(stringValue)
            return
        }
        self = .notComputable
    }

    private static func fromString(_ raw: String) -> ShareTrend {
        switch raw.lowercased() {
        case "doubleup":       return .doubleUp
        case "singleup":       return .singleUp
        case "fortyfiveup":    return .fortyFiveUp
        case "flat":           return .flat
        case "fortyfivedown":  return .fortyFiveDown
        case "singledown":     return .singleDown
        case "doubledown":     return .doubleDown
        case "notcomputable":  return .notComputable
        case "rateoutofrange": return .rateOutOfRange
        case "none":           return .notComputable
        default:               return .notComputable
        }
    }
}

// MARK: - Glucose entry

struct ShareGlucoseEntry: Decodable {
    /// Wall-clock time of the reading, parsed from the `WT` field.
    let wallTime: Date
    /// System time of the reading, parsed from the `ST` field.
    let systemTime: Date
    /// Display time of the reading on the user's device, parsed from `DT`.
    let displayTime: Date
    let trend: ShareTrend
    /// Glucose value in mg/dL.
    let value: Int

    /// Canonical reading time. Each Dexcom EGV carries three clocks (ST/DT/WT)
    /// that differ by seconds; we pick ST (system time, the transmitter clock)
    /// consistently — same choice xdrip4ios's follower parser makes — so dedup,
    /// sorting, and id derivation all key off one timestamp.
    var timestamp: Date { systemTime }

    private enum CodingKeys: String, CodingKey {
        case wt    = "WT"
        case st    = "ST"
        case dt    = "DT"
        case trend = "Trend"
        case value = "Value"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wallTime    = try ShareDateParser.parse(c.decode(String.self, forKey: .wt))
        self.systemTime  = try ShareDateParser.parse(c.decode(String.self, forKey: .st))
        self.displayTime = try ShareDateParser.parse(c.decode(String.self, forKey: .dt))
        self.trend = (try? c.decode(ShareTrend.self, forKey: .trend)) ?? .notComputable
        self.value = try c.decode(Int.self, forKey: .value)
    }
}

// MARK: - Date parsing
//
// Share returns timestamps in Microsoft-AJAX form: "Date(<unix-ms>[<+|-><HHMM>])".
// Examples observed: "Date(1700000000000)", "Date(1700000000000+0200)", "Date(1700000000000-0500)".
// We only need the unix-ms; the offset is informational and can be ignored — every
// downstream consumer already treats Date as a UTC instant.

enum ShareDateParser {
    private static let regex: NSRegularExpression = {
        // The compiled pattern is constant; failing here would be a programmer error.
        try! NSRegularExpression(pattern: #"Date\((-?\d+)(?:[+-]\d{4})?\)"#)
    }()

    static func parse(_ raw: String) throws -> Date {
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              match.numberOfRanges >= 2,
              let msRange = Range(match.range(at: 1), in: raw),
              let ms = Double(raw[msRange]) else {
            throw DexcomShareError.malformedDate(raw)
        }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }
}

// MARK: - Errors

/// Wire shape of an error response body.
struct ShareErrorResponse: Decodable {
    let code: String
    let message: String?
    let subCode: String?

    private enum CodingKeys: String, CodingKey {
        case code    = "Code"
        case message = "Message"
        case subCode = "SubCode"
    }
}

/// Swift-side error type emitted by the Share client.
enum DexcomShareError: Error {
    /// Could not parse a "Date(...)" timestamp.
    case malformedDate(String)
    /// Response body did not match the expected shape.
    case malformedResponse(String)
    /// Underlying network failure.
    case network(URLError)
    /// Non-200 HTTP response that did not parse as a known Share error.
    case http(status: Int, code: String?, message: String?)

    /// Wrong password — region was correct, the user just typed the wrong password.
    case accountPasswordInvalid
    /// Account not found at the host we tried; usually means the wrong region.
    case accountNotFound
    /// Too many bad logins in a short window; Dexcom temporarily locked the account.
    case maxAuthenticationAttempts
    /// Server rejected our cached sessionId — caller should re-login and retry once.
    case sessionInvalid

    /// Anything else — surfaced verbatim so it shows up in the user-visible response field.
    case other(code: String, message: String?)

    /// Best-effort classification of a Share error response into a Swift case.
    init(_ response: ShareErrorResponse, status: Int) {
        let normalized = response.code.lowercased()
        if normalized.contains("accountpasswordinvalid") {
            self = .accountPasswordInvalid
        } else if normalized.contains("maxauth") {
            self = .maxAuthenticationAttempts
        } else if normalized.contains("session")
                    && (normalized.contains("notvalid")
                        || normalized.contains("notfound")
                        || normalized.contains("notactive")
                        || normalized.contains("expired")) {
            self = .sessionInvalid
        } else if normalized.contains("notfound") || normalized.contains("invalidargument") {
            self = .accountNotFound
        } else {
            self = .other(code: response.code, message: response.message)
        }
    }
}

extension DexcomShareError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accountPasswordInvalid:
            return String(localized: "Wrong password for the Dexcom account.")
        case .accountNotFound:
            return String(localized: "Dexcom account not found at this region. Check the email address and try again.")
        case .maxAuthenticationAttempts:
            return String(localized: "Too many failed Dexcom login attempts. Wait a few minutes and try again.")
        case .sessionInvalid:
            return String(localized: "Dexcom session expired.")
        case .malformedDate(let value):
            return "Could not parse Dexcom timestamp: \(value)"
        case .malformedResponse(let detail):
            return "Unexpected Dexcom response: \(detail)"
        case .network(let error):
            return error.localizedDescription
        case .http(let status, _, let message):
            return "Dexcom error (HTTP \(status)): \(message ?? "no body")"
        case .other(let code, let message):
            return "Dexcom error (\(code)): \(message ?? "no message")"
        }
    }
}
