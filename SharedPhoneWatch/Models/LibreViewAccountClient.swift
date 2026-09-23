//
//  LibreViewAccountClient.swift
//  LibreWrist
//
//  Fetches the LibreView **AccountId** and country for a set of FreeStyle
//  LibreLink credentials. The AccountId directly produces the receiver ID for
//  FreeStyle Libre 3 and legacy Libre by Abbott, and selects the account-scoped
//  receiver UUID for current Libre by Abbott.
//
//  This is the **LibreView / FreeStyle LibreLink** API (`nisperson/
//  getauthentication`), NOT the LibreLinkUp *sharing* API in `LibreLinkUp.swift`
//  — they are different services. The flow mirrors Juggluco's `Libreview.java`
//  (`libreconfig` → `postgetauth`):
//
//    1. GET the FSL3 assets manifest → `Configuration` (a config URL).
//    2. GET that config → `newYuUrl` (API base) + `newYuApiKey`.
//    3. POST `{newYuUrl}/api/nisperson/getauthentication` with the credentials
//       → `result.AccountId` + `result.Country`.
//

import Foundation
import OSLog
import Security

enum LibreViewAccountError: Error, LocalizedError, Sendable {
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

struct LibreViewAccountLookup: Sendable, Equatable {
    let accountID: String
    /// ISO country code returned by `getauthentication`. It may be empty for an
    /// older or malformed response; the Libre by Abbott client rejects that
    /// rather than guessing a regional host.
    let country: String
}

/// One-shot client for the LibreView `getauthentication` call. Stateless apart
/// from the persisted device ID; safe to instantiate per request.
struct LibreViewAccountClient: Sendable {

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
    func fetchAccountID(email: String, password: String) async throws -> LibreViewAccountLookup {
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
            case .account(let account):
                return account
            case .retryWithSetDevice:
                setDevice = true
            }
        }
        throw LibreViewAccountError.serverStatus(status: 20, reason: "wrongDeviceForUser")
    }

    // MARK: - Step 1 + 2: configuration

    private struct LibreViewConfig: Sendable {
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

    private enum AuthResult: Sendable {
        case account(LibreViewAccountLookup)
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
        let country = (result["Country"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return .account(LibreViewAccountLookup(accountID: accountID, country: country))
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
    fileprivate static func languageTag() -> String {
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

struct Libre1Login: Sendable, Equatable {
    let receiverID: String
    let activeSensorSerial: String?
    let activeSensorReceiverID: UInt32?
    /// True when code 20 required the single user-initiated `force=true` retry.
    let forced: Bool
}

enum Libre1AccountError: Error, LocalizedError, Equatable, Sendable {
    case deviceBound
    case consentsRequired
    case rateLimited
    case countryMissing
    case receiverIDMissing
    case badResponse(status: Int, code: Int?)

    var errorDescription: String? {
        switch self {
        case .deviceBound:
            return String(
                localized: "Libre by Abbott could not bind this FLwatch installation to the account.",
                comment: "Error shown when the Libre by Abbott login still reports that the account belongs to another device after one forced retry."
            )
        case .consentsRequired:
            return String(
                localized: "Libre by Abbott requires account consent before it can return the receiver ID.",
                comment: "Error shown when the Libre by Abbott login rejects the terms-of-use or privacy-policy consent sent by FLwatch."
            )
        case .rateLimited:
            return String(
                localized: "Too many Libre by Abbott login attempts. Try again later.",
                comment: "Error shown when the Libre by Abbott login service rate-limits the user's sign-in attempts."
            )
        case .countryMissing:
            return String(
                localized: "LibreView returned no account country, so FLwatch could not choose the Libre by Abbott login server.",
                comment: "Error shown when LibreView omits the country code needed to select the country-specific Libre by Abbott server."
            )
        case .receiverIDMissing:
            return String(
                localized: "Libre by Abbott login succeeded but returned no valid receiver ID.",
                comment: "Error shown when the Libre by Abbott login response has no valid receiver UUID."
            )
        case .badResponse(let status, let code):
            if let code {
                return String(
                    localized: "Libre by Abbott login failed (HTTP \(status), code \(code)).",
                    comment: "Generic Libre by Abbott login error. The first value is an HTTP status and the second is the service's numeric error code."
                )
            }
            return String(
                localized: "Libre by Abbott login failed (HTTP \(status)).",
                comment: "Generic Libre by Abbott login error when the service returned no numeric error code. The value is an HTTP status."
            )
        }
    }
}

/// One-shot client for the plaintext Libre by Abbott (`libre1`) login. The
/// account-scoped receiver UUID is cached by the caller, but tokens and personal
/// fields are deliberately neither retained nor logged.
struct Libre1AccountClient: Sendable {
    private static let userAgent = "libre1;1.4.0.2058;iOS;26.6.1"
    private static let sharingWebVersion = "1.6.38"

    private struct Consent: Encodable, Sendable {
        let id: String
        let action: String
    }

    private struct LoginRequest: Encodable, Sendable {
        let email: String
        let password: String
        let consents: [Consent]
    }

    private struct ErrorResponse: Decodable, Sendable {
        let code: Int?
    }

    private struct SuccessResponse: Decodable, Sendable {
        struct Include: Decodable, Sendable {
            struct Patient: Decodable, Sendable {
                let domainData: String?
            }

            let patient: Patient?
        }

        let receiverID: String?
        let include: Include?
    }

    private struct DomainData: Decodable, Sendable {
        struct ActiveSensor: Decodable, Sendable {
            let serialNumber: String?
            let receiverId: UInt32?
        }

        let activeSensor: ActiveSensor?
    }

    private enum AttemptResult: Sendable {
        case success(Libre1Login)
        case retryWithForce
    }

    func login(
        email: String,
        password: String,
        country: String
    ) async throws -> Libre1Login {
        let country = country.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard country.unicodeScalars.count == 2,
              country.unicodeScalars.allSatisfy({ $0.value >= 97 && $0.value <= 122 }) else {
            throw Libre1AccountError.countryMissing
        }
        guard let url = URL(string: "https://libreapi-c-\(country).libreview.io/v1/login") else {
            throw Libre1AccountError.countryMissing
        }

        Logger.libre3.info("Libre by Abbott login host: \(url.host ?? "missing", privacy: .public)")

        let body = LoginRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            consents: [
                Consent(id: "touLibre", action: "accept"),
                Consent(id: "pp", action: "accept")
            ]
        )
        // Reuse the exact bytes for the optional forced attempt.
        let bodyData = try JSONEncoder().encode(body)

        switch try await performLogin(url: url, body: bodyData, force: false) {
        case .success(let login):
            return login
        case .retryWithForce:
            switch try await performLogin(url: url, body: bodyData, force: true) {
            case .success(let login):
                return login
            case .retryWithForce:
                // `shouldRetry` never permits a second retry.
                throw Libre1AccountError.deviceBound
            }
        }
    }

    private func performLogin(
        url: URL,
        body: Data,
        force: Bool
    ) async throws -> AttemptResult {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "force", value: force ? "true" : "false")]
        guard let requestURL = components?.url else {
            throw Libre1AccountError.countryMissing
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "X-User-Agent")
        request.setValue(Self.sharingWebVersion, forHTTPHeaderField: "Sharing-Web-Version")
        request.setValue("libre1", forHTTPHeaderField: "X-Bundle-ID")
        request.setValue(Self.deviceID(), forHTTPHeaderField: "X-Device-ID")
        request.setValue("", forHTTPHeaderField: "X-Integrity-Token")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        let languageTag = LibreViewAccountClient.languageTag()
        let language = languageTag.split(separator: "-").first.map(String.init) ?? languageTag
        request.setValue("\(languageTag),\(language);q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("", forHTTPHeaderField: "X-Installation-ID")
        request.setValue("https://libre1.libreview.io", forHTTPHeaderField: "Origin")
        request.setValue("https://libre1.libreview.io/", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Libre1AccountError.badResponse(status: -1, code: nil)
        }

        let bodyCode = Self.responseCode(from: data)
        let willRetry = Self.shouldRetry(
            statusCode: http.statusCode,
            bodyCode: bodyCode,
            force: force
        )
        if http.statusCode != 200 {
            let codeDescription = bodyCode.map(String.init) ?? "missing"
            if willRetry {
                Logger.libre3.info(
                    "Libre by Abbott login requires force=true retry: HTTP \(http.statusCode, privacy: .public), body code \(codeDescription, privacy: .public)"
                )
            } else {
                Logger.libre3.error(
                    "Libre by Abbott login failed: HTTP \(http.statusCode, privacy: .public), body code \(codeDescription, privacy: .public), force=\(force, privacy: .public)"
                )
            }
        }
        if http.statusCode == 429 {
            Self.logRateLimitHeaders(http)
        }
        if willRetry {
            return .retryWithForce
        }

        let login = try Self.parseResponse(
            data: data,
            statusCode: http.statusCode,
            forced: force
        )
        Logger.libre3.info(
            "Libre by Abbott login succeeded; receiver UUID \(login.receiverID, privacy: .private), force=\(force, privacy: .public)"
        )
        return .success(login)
    }

    static func shouldRetry(statusCode: Int, bodyCode: Int?, force: Bool) -> Bool {
        statusCode == 401 && bodyCode == 20 && !force
    }

    static func parseResponse(
        data: Data,
        statusCode: Int,
        forced: Bool
    ) throws -> Libre1Login {
        let code = responseCode(from: data)
        guard statusCode == 200 else {
            if statusCode == 429 { throw Libre1AccountError.rateLimited }
            if code == 20 { throw Libre1AccountError.deviceBound }
            if code == 4 { throw Libre1AccountError.consentsRequired }
            throw Libre1AccountError.badResponse(status: statusCode, code: code)
        }

        guard let response = try? JSONDecoder().decode(SuccessResponse.self, from: data),
              let receiverID = response.receiverID,
              let uuid = UUID(uuidString: receiverID)
        else {
            throw Libre1AccountError.receiverIDMissing
        }

        var activeSensorSerial: String?
        var activeSensorReceiverID: UInt32?
        if let domainData = response.include?.patient?.domainData,
           let data = domainData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(DomainData.self, from: data) {
            activeSensorSerial = decoded.activeSensor?.serialNumber
            activeSensorReceiverID = decoded.activeSensor?.receiverId
        }

        return Libre1Login(
            receiverID: uuid.uuidString.lowercased(),
            activeSensorSerial: activeSensorSerial,
            activeSensorReceiverID: activeSensorReceiverID,
            forced: forced
        )
    }

    private static func responseCode(from data: Data) -> Int? {
        (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.code
    }

    private static func logRateLimitHeaders(_ response: HTTPURLResponse) {
        let limit = response.value(forHTTPHeaderField: "X-Attempts-Limit") ?? "missing"
        let remaining = response.value(forHTTPHeaderField: "X-Attempts-Remaining") ?? "missing"
        let resetAfter = response.value(forHTTPHeaderField: "X-Attempts-Reset-After") ?? "missing"
        let resetAt = response.value(forHTTPHeaderField: "X-Attempts-Reset-At") ?? "missing"
        Logger.libre3.error(
            "Libre by Abbott rate limit: limit=\(limit, privacy: .public), remaining=\(remaining, privacy: .public), reset-after=\(resetAfter, privacy: .public), reset-at=\(resetAt, privacy: .public)"
        )
    }

    /// Stable per-install identity. Generating this only during an explicit
    /// account lookup keeps device binding away from pairing and background work.
    private static func deviceID() -> String {
        let existing = SharedData.libre3Libre1DeviceId
        if let uuid = UUID(uuidString: existing) {
            return uuid.uuidString.lowercased()
        }
        let generated = UUID().uuidString.lowercased()
        SharedData.libre3Libre1DeviceId = generated
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
