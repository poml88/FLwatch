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
//  It also holds the 16-byte Phase-5 raw key established by the full handshake.
//  The cached/direct handshake (`runCachedReconnectHandshake`, PLAN Phase 5)
//  reuses that authorization material on every reconnect. It's secret material,
//  so it lives beside the PIN in the keychain rather than the app group.
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
    // Keep the legacy account name so existing paired sensors retain their key.
    private static let reconnectKeyAccount = "libre3.ble.kenc"
    private static let installationReceiverIDAccount = "libre3.receiverID.installation"

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

    // MARK: - Reconnect key (Phase-5 raw key)

    static func readReconnectKey() throws -> Data? { try read(account: reconnectKeyAccount) }
    static func saveReconnectKey(_ key: Data) throws { try save(key, account: reconnectKeyAccount) }
    static func deleteReconnectKey() throws { try delete(account: reconnectKeyAccount) }

    // MARK: - Installation receiver ID

    /// The receiver ID identifying this FLwatch installation, used for sensors
    /// FLwatch activates itself. Held as little-endian hex text, so the caller
    /// can round-trip it through LibreCRKit's own parser.
    ///
    /// Not a secret — it lives here for the keychain's other property, surviving
    /// reinstall. Everything else this file holds can be re-established by
    /// pairing again; this cannot. Losing it strands every sensor FLwatch
    /// activated, because nothing else can reproduce the ID they hold, and no
    /// vendor app can adopt them either. Deliberately never deleted, including on
    /// disconnect.
    static func readInstallationReceiverID() throws -> Data? {
        try read(account: installationReceiverIDAccount)
    }

    static func saveInstallationReceiverID(_ id: Data) throws {
        try save(id, account: installationReceiverIDAccount)
    }

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
