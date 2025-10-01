// FLWatchAttributes.swift
import Foundation
import ActivityKit

public struct FLWatchAttributes: ActivityAttributes, Codable {
    public struct ContentState: Codable, Hashable {
        // dynamic state that will be updated by server pushes
        public var latestGlucoseValue: Int
        public var trend: String
        public var timestamp: Date
        /// compact graph points: array of [ [unix_ts_seconds, glucoseValue], ... ]
        public var graphPoints: [[Int]]
    }

    // static attributes provided at start (sent by server in "start" push)
    public var userIdHash: String

    public init(userIdHash: String) {
        self.userIdHash = userIdHash
    }
}
