// FLWatchAttributes.swift
import Foundation
import ActivityKit

public struct FLWatchAttributes: ActivityAttributes, Codable {
    public static let staleActivityAfterInterval: TimeInterval = 20 * 60
    public static let staleGlucoseAfterInterval: TimeInterval = 9 * 60
    public static let glucoseActivityIdentifier = "librewrist.glucose"
    public static let iobValueScale = 100
    public static let activityValueScale = 1000

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

    public struct ActivityPoint: Hashable, Identifiable {
        public let timestamp: Date
        public let valueInHundredths: Int

        public var id: Date { timestamp }

        public init(timestamp: Date, valueInHundredths: Int) {
            self.timestamp = timestamp
            self.valueInHundredths = valueInHundredths
        }
    }

    public struct InsulinMarker: Hashable, Identifiable {
        public let timestamp: Date
        public let insulinUnitsInHundredths: Int

        public var id: Date { timestamp }

        public init(timestamp: Date, insulinUnitsInHundredths: Int) {
            self.timestamp = timestamp
            self.insulinUnitsInHundredths = insulinUnitsInHundredths
        }
    }

    public struct ContentState: Codable, Hashable {
        // Dynamic state updated locally by the app (BG refresh + foreground refreshes).
        // Presentation-independent formatting and graph domains are resolved before the update so
        // WidgetKit's repeated Live Activity renders only perform size-dependent drawing work.
        public var latestGlucoseText: String
        public var latestTrend: String
        public var latestTimestamp: Date
        public var graphReferenceTimestamp: Date
        public var latestColor: Int
        public var graphPoints: [GraphPoint]
        public var minutePoints: [GraphPoint]
        public var glucoseUnit: Int
        public var targetLow: Int
        public var targetHigh: Int
        public var alarmLow: Int
        public var chartYScaleMaximum: Int
        public var currentIOBText: String?
        public var iobPoints: [ActivityPoint]
        public var maxIOBInHundredths: Int
        public var activityPoints: [ActivityPoint]
        public var maxActivityInHundredths: Int
        public var insulinMarkers: [InsulinMarker]
        public var showIOBCurve: Bool
        public var showActivityCurve: Bool
        public var showInsulinDeliveryMarks: Bool

        private enum CodingKeys: String, CodingKey {
            case latestGlucoseText = "l"
            case latestTrend = "r"
            case latestTimestamp = "t"
            case graphReferenceTimestamp = "x"
            case latestColor = "c"
            case graphPoints = "g"
            case minutePoints = "m"
            case glucoseUnit = "u"
            case targetLow = "lo"
            case targetHigh = "hi"
            case alarmLow = "a"
            case chartYScaleMaximum = "ym"
            case currentIOBText = "i"
            case iobPoints = "ic"
            case maxIOBInHundredths = "im"
            case activityPoints = "ac"
            case maxActivityInHundredths = "am"
            case insulinMarkers = "d"
            case showIOBCurve = "si"
            case showActivityCurve = "sa"
            case showInsulinDeliveryMarks = "sd"
        }

        public init(
            latestGlucoseText: String,
            latestTrend: String,
            latestTimestamp: Date,
            graphReferenceTimestamp: Date,
            latestColor: Int,
            graphPoints: [GraphPoint],
            minutePoints: [GraphPoint],
            glucoseUnit: Int,
            targetLow: Int,
            targetHigh: Int,
            alarmLow: Int,
            chartYScaleMaximum: Int,
            currentIOBText: String?,
            iobPoints: [ActivityPoint],
            maxIOBInHundredths: Int,
            activityPoints: [ActivityPoint],
            maxActivityInHundredths: Int,
            insulinMarkers: [InsulinMarker],
            showIOBCurve: Bool,
            showActivityCurve: Bool,
            showInsulinDeliveryMarks: Bool
        ) {
            self.latestGlucoseText = latestGlucoseText
            self.latestTrend = latestTrend
            self.latestTimestamp = latestTimestamp
            self.graphReferenceTimestamp = graphReferenceTimestamp
            self.latestColor = latestColor
            self.graphPoints = graphPoints
            self.minutePoints = minutePoints
            self.glucoseUnit = glucoseUnit
            self.targetLow = targetLow
            self.targetHigh = targetHigh
            self.alarmLow = alarmLow
            self.chartYScaleMaximum = chartYScaleMaximum
            self.currentIOBText = currentIOBText
            self.iobPoints = iobPoints
            self.maxIOBInHundredths = maxIOBInHundredths
            self.activityPoints = activityPoints
            self.maxActivityInHundredths = maxActivityInHundredths
            self.insulinMarkers = insulinMarkers
            self.showIOBCurve = showIOBCurve
            self.showActivityCurve = showActivityCurve
            self.showInsulinDeliveryMarks = showInsulinDeliveryMarks
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let baseTimestamp = try container.decode(Double.self, forKey: .latestTimestamp)

            latestGlucoseText = try container.decode(String.self, forKey: .latestGlucoseText)
            latestTrend = try container.decode(String.self, forKey: .latestTrend)
            latestTimestamp = Date(timeIntervalSince1970: baseTimestamp)
            graphReferenceTimestamp = Date(
                timeIntervalSince1970: try container.decode(Double.self, forKey: .graphReferenceTimestamp)
            )
            latestColor = try container.decode(Int.self, forKey: .latestColor)
            graphPoints = try Self.decodePoints(from: container, forKey: .graphPoints, baseTimestamp: baseTimestamp)
            minutePoints = try Self.decodePoints(from: container, forKey: .minutePoints, baseTimestamp: baseTimestamp)
            glucoseUnit = try container.decode(Int.self, forKey: .glucoseUnit)
            targetLow = try container.decode(Int.self, forKey: .targetLow)
            targetHigh = try container.decode(Int.self, forKey: .targetHigh)
            alarmLow = try container.decode(Int.self, forKey: .alarmLow)
            chartYScaleMaximum = try container.decode(Int.self, forKey: .chartYScaleMaximum)
            currentIOBText = try container.decodeIfPresent(String.self, forKey: .currentIOBText)
            iobPoints = try Self.decodeActivityPoints(from: container, forKey: .iobPoints, baseTimestamp: baseTimestamp)
            maxIOBInHundredths = try container.decode(Int.self, forKey: .maxIOBInHundredths)
            activityPoints = try Self.decodeActivityPoints(from: container, forKey: .activityPoints, baseTimestamp: baseTimestamp)
            maxActivityInHundredths = try container.decode(Int.self, forKey: .maxActivityInHundredths)
            insulinMarkers = try Self.decodeInsulinMarkers(from: container, forKey: .insulinMarkers, baseTimestamp: baseTimestamp)
            showIOBCurve = try container.decode(Bool.self, forKey: .showIOBCurve)
            showActivityCurve = try container.decode(Bool.self, forKey: .showActivityCurve)
            showInsulinDeliveryMarks = try container.decode(Bool.self, forKey: .showInsulinDeliveryMarks)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let baseTimestamp = latestTimestamp.timeIntervalSince1970

            try container.encode(latestGlucoseText, forKey: .latestGlucoseText)
            try container.encode(latestTrend, forKey: .latestTrend)
            try container.encode(baseTimestamp, forKey: .latestTimestamp)
            try container.encode(
                graphReferenceTimestamp.timeIntervalSince1970,
                forKey: .graphReferenceTimestamp
            )
            try container.encode(latestColor, forKey: .latestColor)
            try Self.encodePoints(graphPoints, to: &container, forKey: .graphPoints, baseTimestamp: baseTimestamp)
            try Self.encodePoints(minutePoints, to: &container, forKey: .minutePoints, baseTimestamp: baseTimestamp)
            try container.encode(glucoseUnit, forKey: .glucoseUnit)
            try container.encode(targetLow, forKey: .targetLow)
            try container.encode(targetHigh, forKey: .targetHigh)
            try container.encode(alarmLow, forKey: .alarmLow)
            try container.encode(chartYScaleMaximum, forKey: .chartYScaleMaximum)
            try container.encodeIfPresent(currentIOBText, forKey: .currentIOBText)
            try Self.encodeActivityPoints(iobPoints, to: &container, forKey: .iobPoints, baseTimestamp: baseTimestamp)
            try container.encode(maxIOBInHundredths, forKey: .maxIOBInHundredths)
            try Self.encodeActivityPoints(activityPoints, to: &container, forKey: .activityPoints, baseTimestamp: baseTimestamp)
            try container.encode(maxActivityInHundredths, forKey: .maxActivityInHundredths)
            try Self.encodeInsulinMarkers(insulinMarkers, to: &container, forKey: .insulinMarkers, baseTimestamp: baseTimestamp)
            try container.encode(showIOBCurve, forKey: .showIOBCurve)
            try container.encode(showActivityCurve, forKey: .showActivityCurve)
            try container.encode(showInsulinDeliveryMarks, forKey: .showInsulinDeliveryMarks)
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

        private static func decodeActivityPoints(
            from container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys,
            baseTimestamp: Double
        ) throws -> [ActivityPoint] {
            let encodedPoints = try container.decode([[Int]].self, forKey: key)
            return encodedPoints.compactMap { encodedPoint in
                guard encodedPoint.count >= 2 else {
                    return nil
                }

                return ActivityPoint(
                    timestamp: Date(timeIntervalSince1970: baseTimestamp + Double(encodedPoint[0])),
                    valueInHundredths: encodedPoint[1]
                )
            }
        }

        private static func encodeActivityPoints(
            _ points: [ActivityPoint],
            to container: inout KeyedEncodingContainer<CodingKeys>,
            forKey key: CodingKeys,
            baseTimestamp: Double
        ) throws {
            let encodedPoints = points.map { point in
                [
                    Int(point.timestamp.timeIntervalSince1970.rounded() - baseTimestamp.rounded()),
                    point.valueInHundredths
                ]
            }
            try container.encode(encodedPoints, forKey: key)
        }

        private static func decodeInsulinMarkers(
            from container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys,
            baseTimestamp: Double
        ) throws -> [InsulinMarker] {
            let encodedMarkers = try container.decode([[Int]].self, forKey: key)
            return encodedMarkers.compactMap { encodedMarker in
                guard encodedMarker.count >= 2 else {
                    return nil
                }

                return InsulinMarker(
                    timestamp: Date(timeIntervalSince1970: baseTimestamp + Double(encodedMarker[0])),
                    insulinUnitsInHundredths: encodedMarker[1]
                )
            }
        }

        private static func encodeInsulinMarkers(
            _ markers: [InsulinMarker],
            to container: inout KeyedEncodingContainer<CodingKeys>,
            forKey key: CodingKeys,
            baseTimestamp: Double
        ) throws {
            let encodedMarkers = markers.map { marker in
                [
                    Int(marker.timestamp.timeIntervalSince1970.rounded() - baseTimestamp.rounded()),
                    marker.insulinUnitsInHundredths
                ]
            }
            try container.encode(encodedMarkers, forKey: key)
        }
    }

    // static attributes provided when the local activity is created
    public var activityIdentifier: String
    public var startedAt: Date

    private enum CodingKeys: String, CodingKey {
        case activityIdentifier
        case startedAt
    }

    public init(
        activityIdentifier: String = FLWatchAttributes.glucoseActivityIdentifier,
        startedAt: Date = .now
    ) {
        self.activityIdentifier = activityIdentifier
        self.startedAt = startedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activityIdentifier = try container.decodeIfPresent(String.self, forKey: .activityIdentifier)
            ?? FLWatchAttributes.glucoseActivityIdentifier
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activityIdentifier, forKey: .activityIdentifier)
        try container.encode(startedAt, forKey: .startedAt)
    }
}
