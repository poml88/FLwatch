// FLWatchAttributes.swift
import Foundation
import ActivityKit

public struct FLWatchAttributes: ActivityAttributes, Codable {
    public static let staleAfterInterval: TimeInterval = 5 * 60
    public static let glucoseActivityIdentifier = "librewrist.glucose"

    public struct GraphPoint: Hashable, Identifiable {
        public let timestamp: Date
        public let valueInMgPerDl: Int
        public let colorRawValue: Int

        public var id: Date { timestamp }

        public init(timestamp: Date, valueInMgPerDl: Int, colorRawValue: Int) {
            self.timestamp = timestamp
            self.valueInMgPerDl = valueInMgPerDl
            self.colorRawValue = colorRawValue
        }
    }

    public struct ContentState: Codable, Hashable {
        // dynamic state updated locally by the app (BG refresh + foreground refreshes)
        public var latestGlucoseValue: Int
        public var latestTrend: String
        public var latestTimestamp: Date
        public var latestColor: Int
        public var graphPoints: [GraphPoint]
        public var minutePoints: [GraphPoint]
        public var glucoseUnit: Int
        public var targetLow: Int
        public var targetHigh: Int
        public var alarmLow: Int
        public var maxGlucoseValue: Int

        private enum CodingKeys: String, CodingKey {
            case latestGlucoseValue = "l"
            case latestTrend = "r"
            case latestTimestamp = "t"
            case latestColor = "c"
            case graphPoints = "g"
            case minutePoints = "m"
            case glucoseUnit = "u"
            case targetLow = "lo"
            case targetHigh = "hi"
            case alarmLow = "a"
            case maxGlucoseValue = "mx"
        }

        public init(
            latestGlucoseValue: Int,
            latestTrend: String,
            latestTimestamp: Date,
            latestColor: Int,
            graphPoints: [GraphPoint],
            minutePoints: [GraphPoint],
            glucoseUnit: Int,
            targetLow: Int,
            targetHigh: Int,
            alarmLow: Int,
            maxGlucoseValue: Int
        ) {
            self.latestGlucoseValue = latestGlucoseValue
            self.latestTrend = latestTrend
            self.latestTimestamp = latestTimestamp
            self.latestColor = latestColor
            self.graphPoints = graphPoints
            self.minutePoints = minutePoints
            self.glucoseUnit = glucoseUnit
            self.targetLow = targetLow
            self.targetHigh = targetHigh
            self.alarmLow = alarmLow
            self.maxGlucoseValue = maxGlucoseValue
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let baseTimestamp = try container.decode(Double.self, forKey: .latestTimestamp)

            latestGlucoseValue = try container.decode(Int.self, forKey: .latestGlucoseValue)
            latestTrend = try container.decode(String.self, forKey: .latestTrend)
            latestTimestamp = Date(timeIntervalSince1970: baseTimestamp)
            latestColor = try container.decode(Int.self, forKey: .latestColor)
            graphPoints = try Self.decodePoints(from: container, forKey: .graphPoints, baseTimestamp: baseTimestamp)
            minutePoints = try Self.decodePoints(from: container, forKey: .minutePoints, baseTimestamp: baseTimestamp)
            glucoseUnit = try container.decode(Int.self, forKey: .glucoseUnit)
            targetLow = try container.decode(Int.self, forKey: .targetLow)
            targetHigh = try container.decode(Int.self, forKey: .targetHigh)
            alarmLow = try container.decode(Int.self, forKey: .alarmLow)
            maxGlucoseValue = try container.decode(Int.self, forKey: .maxGlucoseValue)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let baseTimestamp = latestTimestamp.timeIntervalSince1970

            try container.encode(latestGlucoseValue, forKey: .latestGlucoseValue)
            try container.encode(latestTrend, forKey: .latestTrend)
            try container.encode(baseTimestamp, forKey: .latestTimestamp)
            try container.encode(latestColor, forKey: .latestColor)
            try Self.encodePoints(graphPoints, to: &container, forKey: .graphPoints, baseTimestamp: baseTimestamp)
            try Self.encodePoints(minutePoints, to: &container, forKey: .minutePoints, baseTimestamp: baseTimestamp)
            try container.encode(glucoseUnit, forKey: .glucoseUnit)
            try container.encode(targetLow, forKey: .targetLow)
            try container.encode(targetHigh, forKey: .targetHigh)
            try container.encode(alarmLow, forKey: .alarmLow)
            try container.encode(maxGlucoseValue, forKey: .maxGlucoseValue)
        }

        private static func decodePoints(
            from container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys,
            baseTimestamp: Double
        ) throws -> [GraphPoint] {
            let encodedPoints = try container.decode([[Int]].self, forKey: key)
            return encodedPoints.compactMap { encodedPoint in
                guard encodedPoint.count >= 3 else {
                    return nil
                }

                return GraphPoint(
                    timestamp: Date(timeIntervalSince1970: baseTimestamp + Double(encodedPoint[0])),
                    valueInMgPerDl: encodedPoint[1],
                    colorRawValue: encodedPoint[2]
                )
            }
        }

        private static func encodePoints(
            _ points: [GraphPoint],
            to container: inout KeyedEncodingContainer<CodingKeys>,
            forKey key: CodingKeys,
            baseTimestamp: Double
        ) throws {
            let encodedPoints = points.map { point in
                [
                    Int(point.timestamp.timeIntervalSince1970.rounded() - baseTimestamp.rounded()),
                    point.valueInMgPerDl,
                    point.colorRawValue
                ]
            }
            try container.encode(encodedPoints, forKey: key)
        }
    }

    // static attributes provided when the local activity is created
    public var activityIdentifier: String

    public init(activityIdentifier: String = FLWatchAttributes.glucoseActivityIdentifier) {
        self.activityIdentifier = activityIdentifier
    }
}
