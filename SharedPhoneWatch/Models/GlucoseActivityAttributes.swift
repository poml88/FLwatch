// FLWatchAttributes.swift
import Foundation
import ActivityKit

public struct FLWatchAttributes: ActivityAttributes, Codable {
    public static let staleAfterInterval: TimeInterval = 20 * 60

    public struct ContentState: Codable, Hashable {
        // dynamic state updated locally by the app (BG refresh + foreground refreshes)
        public var latestGlucoseValue: Int
        public var trend: String
        public var timestamp: Date
        /// compact graph points: array of [ [unix_ts_seconds, glucoseValue], ... ]
        public var graphPoints: [[Int]]
    }

    // static attributes provided when the local activity is created
    public var userIdHash: String

    public init(userIdHash: String) {
        self.userIdHash = userIdHash
    }
}
