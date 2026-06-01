//
//  Libre3DirectProvider.swift
//  FLwatch
//
//  CGMProvider conformance for `.libre3BLE` — FreeStyle Libre 3 read directly
//  over Bluetooth LE.
//
//  Unlike the cloud providers (LibreLinkUp / Dexcom Share) this source is
//  *push*, not *pull*: the sensor wakes the phone ~once/min with an encrypted
//  notification that the iOS-only `Libre3DirectManager` decrypts on-device and
//  writes straight into the shared `LibreLinkUpHistory` store — the same sink
//  every other surface already reads. Because of that, `reload()` performs NO
//  network round-trip. It exists only so the registry/orchestrator contract
//  (`CGMProvider.reload()`) keeps working; from Phase 3 it will "kick" the
//  manager (ensure connected/authorized) and surface its status.
//
//  This type is compiled into every target that builds the provider registry
//  (phone, watch, widgets), so it must stay free of any iOS-only BLE / NFC /
//  LibreCRKit imports. All of that lives behind `#if os(iOS)` in
//  `LibreWrist/Libre3BLE/` and is reached only from the phone app.
//

import Foundation

@MainActor
final class Libre3DirectProvider: CGMProvider {

    let kind: CGMProviderKind = .libre3BLE

    // Cadence (1 min) and stale window (3 min) come from `CGMProviderKind`,
    // matching the Libre minute cadence the rest of the app was built around.

    /// Push model: the freshest decoded reading is the source of truth, so
    /// throttle by the cached reading's age (like the other minute-cadence
    /// source) rather than by a non-existent "last API call".
    var reloadThrottleByReadingAge: Bool { true }

    var noDataReceivedHint: String {
        String(localized: "Keep your phone near the sensor.")
    }

    private(set) var lastReloadResponseMessage: String = "[...]"
    private(set) var lastReloadDidFail: Bool = false

    // MARK: - CGMProvider

    func reload() async {
        // Direct BLE is push, not pull — there is nothing to fetch here. On the
        // phone app, "reload" just *kicks* the BLE engine (ensure a connection
        // attempt is in flight) and mirrors its status; it never does network
        // I/O. Other targets that build the provider registry (watch + the iOS
        // widget/Live-Activity extensions) don't run the engine — the kick is a
        // harmless no-op there (nobody is listening).
        //
        // This file is SHARED (it compiles into watch + widget targets), so it
        // must not name the phone-only `Libre3DirectManager` type — that's the
        // `Cannot find 'Libre3DirectManager' in scope` trap. Instead it talks to
        // the engine the same decoupled way `BluetoothHeartbeatManager` is
        // reached from shared code: post a NotificationCenter request, and read
        // the engine's status back from the app group (which the manager writes).
        NotificationCenter.default.post(name: .libre3DirectReloadRequested, object: nil)
        lastReloadDidFail = SharedData.libre3EngineDidFail
        lastReloadResponseMessage = SharedData.libre3EngineStatusMessage
    }
}
