//
//  Libre3PINStore.swift
//  FLwatch
//
//  Keychain wrapper for the Libre 3 BLE PIN — the 4-byte secret returned by the
//  NFC activation/switch response and used as the `tail4` in the Phase-5
//  challenge. It's the one sensitive bit of the pairing, so (per PLAN §9) it
//  lives in the keychain rather than the app group; the non-secret metadata
//  (serial, BLE address, receiver ID) goes in `SharedData`.
//
//  Mirrors `DexcomShareTokenStore`'s style, but stores raw `Data` (the PIN is
//  binary, not a UTF-8 string). Keychain survival across reinstall is NOT
//  required (PLAN §9: re-pair via NFC after reinstall) — this is for secrecy.
//

#if os(iOS)
import Foundation
import Security

enum Libre3PINStoreError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let s): return "Keychain status: \(s)"
        }
    }
}

enum Libre3PINStore {

    private static let account = "libre3.ble.pin"

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
    }

    private static var accessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "KEYCHAIN_ACCESS_GROUP") as? String
    }

    // MARK: - Public API

    static func read() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw Libre3PINStoreError.unexpectedStatus(status)
        }
        return data
    }

    static func save(_ pin: Data) throws {
        var query = baseQuery()
        let update: [String: Any] = [kSecValueData as String: pin]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw Libre3PINStoreError.unexpectedStatus(updateStatus)
        }

        query[kSecValueData as String] = pin
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw Libre3PINStoreError.unexpectedStatus(addStatus)
        }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Libre3PINStoreError.unexpectedStatus(status)
        }
    }

    // MARK: - Internals

    private static func baseQuery() -> [String: Any] {
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
#endif
