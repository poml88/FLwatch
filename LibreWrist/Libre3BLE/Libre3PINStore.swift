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
//  It also holds the Phase-5 **reconnect key** (the 16-byte kEnc captured from
//  the first-pair Phase 6). On reconnect the cached/direct handshake
//  (`runCachedReconnectHandshake`, PLAN Phase 5) feeds this kEnc straight into
//  the Phase-5 block encryptor as `phase5RawKey` — matching LibreCRKit's
//  `runTakeoverHandshake` default (`{ $0.kEnc }`) and Juggluco's model of
//  exporting the authorization material once at first-pair and reusing it on
//  every reconnect. It's session-secret material, so it lives beside the PIN in
//  the keychain rather than the app group.
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

    private static let pinAccount = "libre3.ble.pin"
    private static let reconnectKeyAccount = "libre3.ble.kenc"

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
    }

    private static var accessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "KEYCHAIN_ACCESS_GROUP") as? String
    }

    // MARK: - BLE PIN

    static func read() throws -> Data? { try read(account: pinAccount) }
    static func save(_ pin: Data) throws { try save(pin, account: pinAccount) }
    static func delete() throws { try delete(account: pinAccount) }

    // MARK: - Reconnect key (Phase-6 kEnc reused as the cached-reconnect Phase-5 key)

    static func readReconnectKey() throws -> Data? { try read(account: reconnectKeyAccount) }
    static func saveReconnectKey(_ key: Data) throws { try save(key, account: reconnectKeyAccount) }
    static func deleteReconnectKey() throws { try delete(account: reconnectKeyAccount) }

    // MARK: - Internals

    private static func read(account: String) throws -> Data? {
        var query = baseQuery(account: account)
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

    private static func save(_ value: Data, account: String) throws {
        var query = baseQuery(account: account)
        let update: [String: Any] = [kSecValueData as String: value]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw Libre3PINStoreError.unexpectedStatus(updateStatus)
        }

        query[kSecValueData as String] = value
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw Libre3PINStoreError.unexpectedStatus(addStatus)
        }
    }

    private static func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Libre3PINStoreError.unexpectedStatus(status)
        }
    }

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
#endif
