//
//  NightscoutModels.swift
//  LibreWrist
//
//  API v3 request models and stable identifiers used by the Nightscout
//  uploader. Identifiers and fingerprints deliberately avoid Swift's
//  per-process-seeded Hasher.
//

import CryptoKit
import Foundation

struct NightscoutEntryBody: Codable, Equatable, Sendable {
    let date: Int64
    let utcOffset: Int
    let app: String
    let type: String
    let sgv: Int
    let direction: String
    let device: String
    let dateString: String
}

struct NightscoutEntryUpload: Codable, Equatable, Sendable {
    let identifier: UUID
    let eventDate: Date
    let body: NightscoutEntryBody

    init(reading: LibreLinkUpGlucose) {
        let signature = NightscoutEntryChangeSignature(reading: reading)
        let source = signature.identity.source
        // Nightscout treats `date` as immutable for an existing identifier.
        // Build both from the same whole-second timestamp so realtime and
        // historical representations cannot share an identifier while
        // disagreeing only in fractional milliseconds.
        let eventDate = Date(
            timeIntervalSince1970: TimeInterval(signature.identity.epochSeconds)
        )

        self.identifier = NightscoutDigest.uuidV5(
            namespace: NightscoutDigest.glucoseNamespace,
            name: "\(source)|sgv|\(signature.identity.epochSeconds)"
        )
        self.eventDate = eventDate
        self.body = NightscoutEntryBody(
            date: signature.date,
            utcOffset: signature.utcOffset,
            app: NightscoutModelFactory.appName,
            type: "sgv",
            sgv: signature.sgv,
            direction: signature.direction,
            device: source,
            dateString: NightscoutModelFactory.iso8601String(from: eventDate)
        )
    }

    var fingerprint: String {
        let significantFields = NightscoutEntryFingerprintFields(
            date: body.date,
            utcOffset: body.utcOffset,
            app: body.app,
            sgv: body.sgv,
            direction: body.direction,
            device: body.device
        )
        return NightscoutDigest.sha256Hex(
            of: NightscoutModelFactory.canonicalData(for: significantFields)
        )
    }
}

struct NightscoutEntryIdentity: Hashable, Sendable {
    let source: String
    let epochSeconds: Int64
}

/// Cheap hot-path comparison matching every field used by the durable
/// fingerprint, without constructing a formatter or JSON encoder.
struct NightscoutEntryChangeSignature: Hashable, Sendable {
    let identity: NightscoutEntryIdentity
    let date: Int64
    let utcOffset: Int
    let sgv: Int
    let direction: String

    init(reading: LibreLinkUpGlucose) {
        let epochSeconds = Int64(
            reading.glucose.date.timeIntervalSince1970.rounded(.towardZero)
        )
        let eventDate = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        identity = NightscoutEntryIdentity(
            source: NightscoutModelFactory.deviceName(from: reading.glucose.source),
            epochSeconds: epochSeconds
        )
        date = epochSeconds * 1_000
        utcOffset = NightscoutModelFactory.utcOffsetMinutes(for: eventDate)
        sgv = reading.glucose.value
        direction = (reading.trendArrow ?? reading.glucose.trendArrow).nightscoutDirection
    }
}

private struct NightscoutEntryFingerprintFields: Encodable {
    let date: Int64
    let utcOffset: Int
    let app: String
    let sgv: Int
    let direction: String
    let device: String
}

struct NightscoutTreatmentBody: Codable, Equatable, Sendable {
    let date: Int64
    let utcOffset: Int
    let app: String
    let eventType: String
    let insulin: Double
    let enteredBy: String
    let notes: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case date
        case utcOffset
        case app
        case eventType
        case insulin
        case enteredBy
        case notes
        case createdAt = "created_at"
    }
}

struct NightscoutTreatmentUpload: Codable, Equatable, Sendable {
    let identifier: UUID
    let body: NightscoutTreatmentBody

    /// Derived from the server-visible millisecond timestamp so equality stays
    /// stable across outbox persistence. Older snapshots may contain a stored
    /// `eventDate`; synthesized decoding safely ignores that extra key.
    var eventDate: Date {
        Date(timeIntervalSince1970: Double(body.date) / 1_000)
    }

    init(delivery: InsulinDelivery) {
        let sourceDate = Date(timeIntervalSince1970: delivery.timeStamp)
        let epochMilliseconds = NightscoutModelFactory.epochMilliseconds(for: sourceDate)
        let eventDate = Date(timeIntervalSince1970: Double(epochMilliseconds) / 1_000)
        self.identifier = delivery.id
        self.body = NightscoutTreatmentBody(
            date: epochMilliseconds,
            utcOffset: NightscoutModelFactory.utcOffsetMinutes(for: eventDate),
            app: NightscoutModelFactory.appName,
            eventType: "Correction Bolus",
            insulin: delivery.insulinUnits,
            enteredBy: NightscoutModelFactory.appName,
            notes: NightscoutModelFactory.insulinTypeName(for: delivery.insulinType),
            createdAt: NightscoutModelFactory.iso8601String(from: eventDate)
        )
    }
}

extension TrendArrow {
    var nightscoutDirection: String {
        switch self {
        case .fallingVeryQuickly: return "DoubleDown"
        case .fallingQuickly: return "SingleDown"
        case .falling: return "FortyFiveDown"
        case .stable: return "Flat"
        case .rising: return "FortyFiveUp"
        case .risingQuickly: return "SingleUp"
        case .risingVeryQuickly: return "DoubleUp"
        case .unknown, .notDetermined: return "NONE"
        }
    }
}

enum NightscoutModelFactory {
    static let appName = "FLwatch"
    private static let iso8601FormatStyle = Date.ISO8601FormatStyle(
        includingFractionalSeconds: true,
        timeZone: TimeZone(secondsFromGMT: 0)!
    )
    private static let canonicalEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static func epochMilliseconds(for date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    static func utcOffsetMinutes(for date: Date) -> Int {
        TimeZone.current.secondsFromGMT(for: date) / 60
    }

    static func iso8601String(from date: Date) -> String {
        date.formatted(iso8601FormatStyle)
    }

    static func deviceName(from source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }

    static func insulinTypeName(for rawValue: Int) -> String {
        guard let insulinType = InsulinType(rawValue: rawValue) else {
            return "Unknown insulin"
        }
        switch insulinType {
        case .rapidActing: return "Rapid acting"
        case .fastRapidActing: return "Fast rapid acting"
        }
    }

    static func canonicalData<T: Encodable>(for value: T) -> Data {
        // All supported Nightscout payload values are directly encodable. An
        // empty value is preferable to a process-random fallback if a future
        // model change accidentally makes encoding fail.
        return (try? canonicalEncoder.encode(value)) ?? Data()
    }
}

enum NightscoutDigest {
    /// Immutable FLwatch namespace for glucose-entry identities. Changing this
    /// value would create duplicate Nightscout entries for existing readings.
    static let glucoseNamespace = UUID(uuidString: "7530E32F-98E5-5FC1-9B2B-89A4B81DF3C8")!

    /// UUIDv5-shaped identity using the plan's SHA-256 name digest. The UUID
    /// version and RFC 4122 variant bits are set after truncating the digest.
    static func uuidV5(namespace: UUID, name: String) -> UUID {
        var namespaceBytes = namespace.uuid
        var input = withUnsafeBytes(of: &namespaceBytes) { Data($0) }
        input.append(Data(name.utf8))

        var bytes = Array(SHA256.hash(data: input).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
