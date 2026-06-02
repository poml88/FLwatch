//
//  LibreViewAccountClient.swift
//  LibreWrist
//
//  Fetches the LibreView **AccountId** for a set of FreeStyle LibreLink
//  credentials, so the user doesn't have to know it by heart to take over a
//  Libre 3 sensor. Its FNV-32a hash is the receiver ID the sensor was activated
//  with (`Libre3StateStore.receiverID()`), so the AccountId must come from the
//  account that activated the sensor in the FreeStyle Libre 3 app.
//
//  This is the **LibreView / FreeStyle LibreLink** API (`nisperson/
//  getauthentication`), NOT the LibreLinkUp *sharing* API in `LibreLinkUp.swift`
//  — they are different services. The flow mirrors Juggluco's `Libreview.java`
//  (`libreconfig` → `postgetauth`):
//
//    1. GET the FSL3 assets manifest → `Configuration` (a config URL).
//    2. GET that config → `newYuUrl` (API base) + `newYuApiKey`.
//    3. POST `{newYuUrl}/api/nisperson/getauthentication` with the credentials
//       → `result.AccountId`.
//

import Foundation
import OSLog
import Security

enum LibreViewAccountError: Error, LocalizedError {
    case missingCredentials
    case configUnavailable
    case badResponse(Int)
    /// LibreView returned a non-zero `status` (e.g. wrong username/password).
    case serverStatus(status: Int, reason: String)
    case accountIdMissing

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Enter your LibreView email and password first."
        case .configUnavailable:
            return "Couldn't reach LibreView to read its configuration."
        case .badResponse(let code):
            return "LibreView returned HTTP \(code)."
        case .serverStatus(let status, let reason):
            if reason.localizedCaseInsensitiveContains("password")
                || reason.localizedCaseInsensitiveContains("username") {
                return "Wrong email or password."
            }
            return reason.isEmpty ? "LibreView login failed (status \(status))." : reason
        case .accountIdMissing:
            return "LibreView login succeeded but returned no Account ID."
        }
    }
}

/// One-shot client for the LibreView `getauthentication` call. Stateless apart
/// from the persisted device ID; safe to instantiate per request.
struct LibreViewAccountClient {

    // Mirrors Juggluco's Libre 3 constants (`Libreview.java`).
    private static let assetsManifest =
        "https://fsll3.freestyleserver.com/Payloads/Mobile/FSLibre3/Android/Assets/3.3.0/DE.json"
    private static let gatewayType = "FSLibreLink3.Android"
    private static let appVersion = "3.3.0"
    private static let appBuild = "3.3.0.9092"
    /// Reported as the OS in `Abbott-ADC-App-Platform`. The server is indifferent
    /// to the exact value; a recent Android release keeps the shape Juggluco sends.
    private static let osVersion = "14"

    /// Fetch the AccountId for the given credentials. Runs the full config →
    /// getauthentication flow. Throws `LibreViewAccountError` on failure.
    func fetchAccountID(email: String, password: String) async throws -> String {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            throw LibreViewAccountError.missingCredentials
        }

        let config = try await fetchConfig()
        // `SetDevice` starts false; LibreView replies status 20 /
        // "wrongDeviceForUser" the first time a device ID is seen, after which the
        // same request with SetDevice=true registers it (Juggluco's retry loop).
        var setDevice = false
        for _ in 0..<2 {
            let result = try await postAuthentication(
                config: config, email: email, password: password, setDevice: setDevice
            )
            switch result {
            case .accountID(let id):
                return id
            case .retryWithSetDevice:
                setDevice = true
            }
        }
        throw LibreViewAccountError.serverStatus(status: 20, reason: "wrongDeviceForUser")
    }

    // MARK: - Step 1 + 2: configuration

    private struct LibreViewConfig {
        let baseURL: String
        let apiKey: String
    }

    private func fetchConfig() async throws -> LibreViewConfig {
        guard let manifestURL = URL(string: Self.assetsManifest) else {
            throw LibreViewAccountError.configUnavailable
        }
        let manifest = try await getJSON(manifestURL)
        guard let configURLString = manifest["Configuration"] as? String,
              let configURL = URL(string: configURLString) else {
            throw LibreViewAccountError.configUnavailable
        }
        let config = try await getJSON(configURL)
        guard let baseURL = config["newYuUrl"] as? String, !baseURL.isEmpty else {
            throw LibreViewAccountError.configUnavailable
        }
        let apiKey = (config["newYuApiKey"] as? String) ?? ""
        return LibreViewConfig(baseURL: baseURL, apiKey: apiKey)
    }

    // MARK: - Step 3: getauthentication

    private enum AuthResult {
        case accountID(String)
        case retryWithSetDevice
    }

    private func postAuthentication(
        config: LibreViewConfig, email: String, password: String, setDevice: Bool
    ) async throws -> AuthResult {
        let base = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: "\(base)/api/nisperson/getauthentication") else {
            throw LibreViewAccountError.configUnavailable
        }

        let language = Self.languageTag()
        let body: [String: Any] = [
            "Culture": language,
            "DeviceId": Self.deviceID(),
            "Password": password,
            "SetDevice": setDevice,
            "UserName": email,
            "Domain": "Libreview",
            "GatewayType": Self.gatewayType
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Android", forHTTPHeaderField: "Platform")
        request.setValue(Self.appVersion, forHTTPHeaderField: "Version")
        request.setValue(
            "Android/\(Self.osVersion)/FSL3/\(Self.appBuild)",
            forHTTPHeaderField: "Abbott-ADC-App-Platform"
        )
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("", forHTTPHeaderField: "x-newyu-token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LibreViewAccountError.badResponse(-1)
        }
        guard http.statusCode == 200 else {
            throw LibreViewAccountError.badResponse(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int else {
            throw LibreViewAccountError.accountIdMissing
        }

        if status != 0 {
            let reason = (json["reason"] as? String) ?? ""
            if status == 20, reason.localizedCaseInsensitiveContains("wrongDeviceForUser") {
                return .retryWithSetDevice
            }
            Logger.libreLinkUp.error("LibreView getauthentication status \(status): \(reason, privacy: .public)")
            throw LibreViewAccountError.serverStatus(status: status, reason: reason)
        }

        guard let result = json["result"] as? [String: Any],
              let accountID = result["AccountId"] as? String, !accountID.isEmpty else {
            throw LibreViewAccountError.accountIdMissing
        }
        return .accountID(accountID)
    }

    // MARK: - Helpers

    private func getJSON(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LibreViewAccountError.configUnavailable
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LibreViewAccountError.configUnavailable
        }
        return json
    }

    /// `language-REGION` tag (e.g. `en-US`), matching the `Culture` /
    /// `Accept-Language` Juggluco derives from the device locale.
    private static func languageTag() -> String {
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? "US"
        return "\(language)-\(region)"
    }

    /// Stable random device ID for this install, persisted in the app group so
    /// LibreView keeps seeing the same device across re-fetches (a fresh ID each
    /// time would force the SetDevice handshake repeatedly).
    private static func deviceID() -> String {
        if let existing = UserDefaults.group.string(forKey: DefaultsKey.libre3LibreViewDeviceId.rawValue),
           !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.group.set(generated, forKey: DefaultsKey.libre3LibreViewDeviceId.rawValue)
        return generated
    }
}

/// Stores the LibreView password (separate secret from the LibreLinkUp
/// `llu.password` in `PasswordKeychain`). Same generic-password keychain pattern.
enum LibreViewPasswordKeychain {
    private static let account = "libreview.password"
    private static let service = Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func read() throws -> String? {
        var query = baseQuery()
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
        var query = baseQuery()
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound { throw KeychainErr.unexpectedStatus(updateStatus) }
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainErr.unexpectedStatus(addStatus) }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainErr.unexpectedStatus(status)
        }
    }
}
