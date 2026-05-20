//
//  CGMProvider.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  CGM provider abstraction. `LibreLinkUpService` is the orchestrator and
//  holds an `activeProvider` of this protocol; concrete implementations
//  (LibreLinkUpProvider, DexcomShareProvider) wrap each backend's reload
//  pipeline and write into the shared LibreLinkUpHistory store.
//

import Foundation

// MARK: - Kind

enum CGMProviderKind: String, Codable {
    case libreLinkUp
    case dexcomShare
}

// MARK: - Protocol

protocol CGMProvider: AnyObject {
    var kind: CGMProviderKind { get }
    /// User-visible status string from the most recent `reload()`.
    var lastReloadResponseMessage: String { get }
    /// Whether the most recent `reload()` ended in failure.
    var lastReloadDidFail: Bool { get }
    func reload() async

    // MARK: - Cadence-aware timing
    //
    // FLwatch's UI and alert logic was originally built around Libre's
    // minute-by-minute cadence: a reading older than 3 min means "we missed
    // data". Dexcom G7 publishes every ~5 min, so the same thresholds would
    // fire spuriously. Consumers (low-glucose alerts, watch night-view
    // overlay, CarPlay stale tag, reload throttle) read these instead of
    // hard-coded constants.

    /// How often this provider produces a new reading, in minutes.
    /// (Libre 1; Dexcom 5.)
    var cadenceMinutes: Int { get }
    /// Time after the last reading before consumers should consider data stale
    /// and dim or warn the user. Roughly `cadence + 3 min` grace.
    var staleReadingAfter: TimeInterval { get }
    /// If true, the reload-throttle compares the *cached reading's age*
    /// instead of the *last API call's age*. Use this for sources that
    /// publish at a slower cadence than we poll (Dexcom: 5-min cadence,
    /// heartbeat may fire more often) — avoids burning a network call when
    /// we already have a reading younger than the source cadence.
    var reloadThrottleByReadingAge: Bool { get }
    /// Delay between a Bluetooth-heartbeat trigger and the network fetch.
    /// Lets the publisher's official app (e.g. Dexcom G7 app) finish
    /// uploading the just-advertised reading to the Share servers before
    /// we fetch — otherwise the heartbeat-triggered fetch races the upload
    /// and returns the *previous* reading.
    var heartbeatToFetchDelay: TimeInterval { get }

    /// User-visible hint shown in the home-view "no data" overlay,
    /// suggesting the user check the publisher mobile app for the active
    /// provider. Returned localized.
    var noDataReceivedHint: String { get }
}

extension CGMProvider {
    // Libre-like defaults. LibreLinkUpProvider gets these for free,
    // preserving its previously-shipping behavior bit-for-bit.
    var cadenceMinutes: Int { 1 }
    var staleReadingAfter: TimeInterval { 3 * 60 }
    var reloadThrottleByReadingAge: Bool { false }
    var heartbeatToFetchDelay: TimeInterval { 0 }
    var noDataReceivedHint: String { String(localized: "Check that Libre app is running.") }
}

// MARK: - Registry

@MainActor
enum CGMProviderRegistry {
    static func makeProvider(for kind: CGMProviderKind) -> CGMProvider {
        switch kind {
        case .libreLinkUp:
            return LibreLinkUpProvider()
        case .dexcomShare:
            return DexcomShareProvider()
        }
    }
}

// MARK: - LibreLinkUp adapter

/// Thin wrapper around the existing `LibreLinkUp` class so it satisfies
/// `CGMProvider`. Internals of `LibreLinkUp` are unchanged.
@MainActor
final class LibreLinkUpProvider: CGMProvider {
    let kind: CGMProviderKind = .libreLinkUp
    private let libreLinkUp = LibreLinkUp()

    var lastReloadResponseMessage: String { libreLinkUp.libreLinkUpResponse }
    var lastReloadDidFail: Bool { libreLinkUp.libreLinkUpErrorBool }

    func reload() async {
        await libreLinkUp.reloadLibreLinkUp()
    }
}
