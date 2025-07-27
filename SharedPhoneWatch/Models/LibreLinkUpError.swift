//
//  LibreLinkUpError.swift
//  LibreWrist
//
//  Created by Peter Müller on 10.09.24.
//

import Foundation

enum LibreLinkUpError: LocalizedError {
    case noConnectionLogin
    case noConnectionGraph
    case notAuthenticated
    case jsonDecoding
    case touNotAccepted
    case verifyEmail
    case unknownStatus4
    case followerNotConnectToPatient
    case lockedAccount
    case loggingIntoWrongRegionalServer
    case unknownErrorGraph
    case ppNotAccepted
    
    var errorDescription: String? {
        switch self {
        case .noConnectionLogin:     String(localized: "No connection. Unknown error during login. Network?")
        case .noConnectionGraph:     String(localized: "No connection. Network?")
        case .notAuthenticated: String(localized: "Not authenticated. Check credentials.")
        case .jsonDecoding:     String(localized: "JSON decoding error.")
        case .touNotAccepted:   String(localized: "LibreLinkUp's Terms of Use were updated. Open LibreLinkUp App, log in, and accept Terms of Use. (tip: try log out and re-login)")
        case .ppNotAccepted:    String(localized: "LibreLinkUp's Privacy Policy was updated. Open LibreLinkUp App, log in, and accept Privacy Policy. (tip: try log out and re-login)")
        case .verifyEmail:      String(localized: "LLU email address not yet verified. Verify using LLU app.")
        case .unknownStatus4:   String(localized: "Unknown status 4 error.")
        case .followerNotConnectToPatient: String(localized: "Follower not connected to patient. Please invite in Libre app and accept in LibreLinkUp app. See setup and usage guide.")
        case .lockedAccount:    String(localized: "Account temporarily locked. Too many failed login attempts. Try again in 5 minutes.")
        case .loggingIntoWrongRegionalServer: String(localized: "Trying to log into wrong regional server. Please contact support.")
        case .unknownErrorGraph: String(localized: "Unknown error during graph request.")
        }
    }
}
