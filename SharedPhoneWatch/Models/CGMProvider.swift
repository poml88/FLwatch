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
