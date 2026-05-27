//
//  DexcomShareTokenStore.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  Keychain wrapper for Dexcom Share's three secret strings:
//    - password (the user's Dexcom account password)
//    - accountId (the GUID returned by AuthenticatePublisherAccount; stable per-account)
//    - sessionId (the GUID returned by LoginPublisherAccountById; ~7-day lifetime)
//
//  Mirrors PasswordKeychain's style. Each token kind is its own keychain item
//  under the same service so they can be independently read/written/deleted.
//

import Foundation
import Security

enum DexcomShareTokenStoreError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let s): return "Keychain status: \(s)"
        case .invalidUTF8:             return "Keychain value is not valid UTF-8"
        }
    }
}

enum DexcomShareTokenStore {

    enum Kind: String {
        case password  = "dexcom.share.password"
        case accountId = "dexcom.share.accountId"
        case sessionId = "dexcom.share.sessionId"
    }

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
    }

    private static var accessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "KEYCHAIN_ACCESS_GROUP") as? String
    }

    // MARK: - Public API

    static func read(_ kind: Kind) throws -> String? {
        var query = baseQuery(account: kind.rawValue)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw DexcomShareTokenStoreError.unexpectedStatus(status)
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw DexcomShareTokenStoreError.invalidUTF8
        }
        return string
    }

    static func save(_ value: String, kind: Kind) throws {
        let data = Data(value.utf8)

        var query = baseQuery(account: kind.rawValue)
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw DexcomShareTokenStoreError.unexpectedStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw DexcomShareTokenStoreError.unexpectedStatus(addStatus)
        }
    }

    static func delete(_ kind: Kind) throws {
        let status = SecItemDelete(baseQuery(account: kind.rawValue) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DexcomShareTokenStoreError.unexpectedStatus(status)
        }
    }

    /// Wipes all three keychain items in one call. Used by `signOut()`.
    static func deleteAll() throws {
        try delete(.password)
        try delete(.accountId)
        try delete(.sessionId)
    }

    // MARK: - Internals

    private static func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }
}
