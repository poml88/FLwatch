//
//  PasswordKeychain.swift
//  LibreWrist
//
//  Created by Peter Müller on 09.09.25.
//

import Foundation
import Security

enum KeychainErr: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let s): return "Keychain status: \(s)"
        case .invalidUTF8: return "Keychain value is not valid UTF-8"
        }
    }
}

/// Stores and reads a single secret: "llu.password".
enum PasswordKeychain {
    /// Key names
    private static let account = "llu.password"
    private static let service = Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"

    /// Optional: if you enabled **Keychain Sharing**, put the group name in Info.plist under "KEYCHAIN_ACCESS_GROUP"
    private static var accessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "KEYCHAIN_ACCESS_GROUP") as? String
    }

    // MARK: - Public API

    static func read() throws -> String? {
        var query: [String: Any] = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainErr.unexpectedStatus(status)
        }
        guard let str = String(data: data, encoding: .utf8) else { throw KeychainErr.invalidUTF8 }
        return str
    }

    static func save(_ password: String) throws {
        let data = Data(password.utf8)

        // Try update first
        var query = baseQuery()
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound { throw KeychainErr.unexpectedStatus(updateStatus) }

        // Not found → add
        query[kSecValueData as String] = data
        // Choose the policy you want:
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        // or kSecAttrAccessibleWhenUnlocked

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainErr.unexpectedStatus(addStatus) }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainErr.unexpectedStatus(status)
        }
    }

    // MARK: - Internals

    private static func baseQuery() -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let group = accessGroup { q[kSecAttrAccessGroup as String] = group }
        return q
    }
}
