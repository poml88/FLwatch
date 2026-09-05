//
//  Libre3DirectConnectionState.swift
//  FLwatch
//
//  Lifecycle of the direct-BLE link owned by `Libre3DirectManager`. The phone
//  exposes it through `Libre3DirectProvider`; Workout Mode will expose the same
//  engine state directly on the watch.
//

import Foundation

enum Libre3DirectConnectionState: Equatable {
    /// No paired sensor, or the provider isn't `.libre3BLE` — engine idle.
    case idle
    /// Looking for the sensor (scan / retrieve known peripheral).
    case scanning
    /// Found the peripheral; CoreBluetooth connect in progress.
    case connecting
    /// Connected; running the Phase 1–6 authorization handshake.
    case authorizing
    /// Authorized and subscribed; decoding live glucose notifications.
    case streaming
    /// A connect/auth/decode step failed; carries a user-facing reason. The
    /// manager normally keeps an event-driven CoreBluetooth intent standing;
    /// repeated credential failures are the explicit user-action exception.
    case failed(String)

    var isError: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Whether the engine is working towards a link rather than streaming over
    /// one or standing down. `.failed` is included: the manager normally keeps a
    /// CoreBluetooth intent standing through a failure and retries, so that state
    /// means "still trying", not "given up".
    var isAcquiring: Bool {
        switch self {
        case .scanning, .connecting, .authorizing, .failed: return true
        case .idle, .streaming:                             return false
        }
    }

    /// Short, user-facing status line.
    var message: String {
        switch self {
        case .idle:           return String(localized: "Idle")
        case .scanning:       return String(localized: "Searching for sensor…")
        case .connecting:     return String(localized: "Connecting…")
        case .authorizing:    return String(localized: "Authorizing…")
        case .streaming:      return String(localized: "Streaming")
        case .failed(let m):  return m
        }
    }
}
