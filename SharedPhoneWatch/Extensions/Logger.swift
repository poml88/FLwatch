//
//  Logger.swift
//  LibreWrist
//
//  Created by Peter Müller on 14.08.24.
//

import OSLog

extension Logger {

    /// The logger's subsystem.
    private static var subsystem = Bundle.main.bundleIdentifier!

    // NOTE: Replace the categories below with your own choosing.

    /// All logs related to data such as decoding error, parsing issues, etc.
    static let data = Logger(subsystem: subsystem, category: "data")

    /// All logs related to services such as network calls, location, etc.
    static let services = Logger(subsystem: subsystem, category: "services")

    /// All logs related to tracking and analytics.
    static let statistics = Logger(subsystem: subsystem, category: "statistics")
    
    static let general = Logger(subsystem: subsystem, category: "general")
    
    static let connectivity = Logger(subsystem: subsystem, category: "connectivity")
    
    static let libreLinkUp = Logger(subsystem: subsystem, category: "LibreLinkUp")
    
    static let bgTaskScheduler = Logger(subsystem: subsystem, category: "BGTaskScheduler")
    
    static let libreLinkUpService = Logger(subsystem: subsystem, category: "LibreLinkUpService")
    
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")

}

