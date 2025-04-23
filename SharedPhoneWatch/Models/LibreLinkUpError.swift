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

    var errorDescription: String? {
        switch self {
        case .noConnectionLogin:     "No connection. Unknown error during login. Network?"
        case .noConnectionGraph:     "No connection. Network?"
        case .notAuthenticated: "Not authenticated. Check credentials."
        case .jsonDecoding:     "JSON decoding error."
        case .touNotAccepted:   "LibreLinkUp's Terms of Use were updated. Open LibreLinkUp App, log in, and accept Terms of Use."
        case .verifyEmail:      "LLU email address not yet verified. Verify using LLU app."
        case .unknownStatus4:   "Unknown status 4 error."
        case .followerNotConnectToPatient: "Follower not connected to patient. Please invite in Libre app and accept in LibreLinkUp app."
        case .lockedAccount:    "Account temporarily locked. Too many failed login attempts. Try again in 5 minutes."
        case .loggingIntoWrongRegionalServer: "Trying to log into wrong regional server. Please contact support."
        case .unknownErrorGraph: "Unknown error during graph request."
        }
    }
}
