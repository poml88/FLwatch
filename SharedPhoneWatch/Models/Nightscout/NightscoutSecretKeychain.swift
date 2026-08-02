//
//  NightscoutSecretKeychain.swift
//  LibreWrist
//
//  Stores the user's raw Nightscout admin access token. Only a non-secret
//  presence flag is mirrored to the app-group defaults.
//

import Foundation
import Security

enum NightscoutSecretKeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain status: \(status)"
        case .invalidUTF8:
            return "The Nightscout token is not valid UTF-8."
        }
    }
}

@MainActor
enum NightscoutSecretKeychain {
    private static let account = "nightscout.admin-access-token"
    private static let service = Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
    private static var hasLoadedCache = false
    private static var cachedToken: String?

    private static var accessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "KEYCHAIN_ACCESS_GROUP") as? String
    }

    static func read() throws -> String? {
        if hasLoadedCache { return cachedToken }

        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            hasLoadedCache = true
            cachedToken = nil
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NightscoutSecretKeychainError.unexpectedStatus(status)
        }
        guard let token = String(data: data, encoding: .utf8) else {
            throw NightscoutSecretKeychainError.invalidUTF8
        }
        hasLoadedCache = true
        cachedToken = token
        return token
    }

    static func save(_ token: String) throws {
        guard !token.isEmpty else {
            try delete()
            return
        }

        let data = Data(token.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            hasLoadedCache = true
            cachedToken = token
            SharedData.nightscoutTokenPresent = true
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw NightscoutSecretKeychainError.unexpectedStatus(updateStatus)
        }

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NightscoutSecretKeychainError.unexpectedStatus(addStatus)
        }
        hasLoadedCache = true
        cachedToken = token
        SharedData.nightscoutTokenPresent = true
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NightscoutSecretKeychainError.unexpectedStatus(status)
        }
        hasLoadedCache = true
        cachedToken = nil
        SharedData.nightscoutTokenPresent = false
    }

    private static func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
