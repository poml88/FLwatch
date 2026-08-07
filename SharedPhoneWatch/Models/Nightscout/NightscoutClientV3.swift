//
//  NightscoutClientV3.swift
//  LibreWrist
//
//  HTTPS-only Nightscout API v3 client. The raw access token is exchanged for
//  a short-lived JWT and is never placed in logs.
//

import CryptoKit
import Foundation

struct NightscoutBaseURL: Hashable, Sendable {
    let absoluteString: String

    var url: URL {
        // Construction validates this string, so failure here would indicate
        // corrupted in-process state rather than user input.
        URL(string: absoluteString)!
    }

    init(normalizing rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw NightscoutClientError.invalidBaseURL
        }

        components.scheme = "https"
        components.host = host
        components.user = nil
        components.password = nil
        components.path = ""
        components.query = nil
        components.fragment = nil

        guard let normalizedURL = components.url else {
            throw NightscoutClientError.invalidBaseURL
        }
        self.absoluteString = normalizedURL.absoluteString
    }
}

struct NightscoutAuthorization: Equatable, Sendable {
    let jwt: String
    let expiresAt: Date
    let permissionGroups: [String]
}

enum NightscoutDeleteResult: Equatable, Sendable {
    case deleted
    case alreadyAbsent
}

enum NightscoutConnectionTestResult: Equatable, Sendable {
    case ok
    case unreachable
    case notV3Server
    case tokenLacksWrites
}

enum NightscoutClientError: Error, LocalizedError {
    case invalidBaseURL
    case missingAccessToken
    case requestEncoding
    case invalidResponse
    case invalidAuthorizationResponse
    case transport(Error)
    case httpStatus(code: Int, retryAfter: TimeInterval?, responseBodySnippet: String?)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid HTTPS Nightscout URL."
        case .missingAccessToken:
            return "Enter a Nightscout access token."
        case .requestEncoding:
            return "A Nightscout document could not be encoded."
        case .invalidResponse:
            return "Nightscout returned an invalid response."
        case .invalidAuthorizationResponse:
            return "Nightscout returned an invalid authorization response."
        case .transport(let error):
            return error.localizedDescription
        case .httpStatus(let code, _, _):
            return "Nightscout returned HTTP \(code)."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .transport, .invalidResponse:
            return true
        case .httpStatus(let code, _, _):
            return code == 429 || (500...599).contains(code)
        case .invalidBaseURL, .missingAccessToken, .requestEncoding, .invalidAuthorizationResponse:
            return false
        }
    }

    var retryAfter: TimeInterval? {
        guard case .httpStatus(_, let retryAfter, _) = self else { return nil }
        return retryAfter
    }

    var statusCode: Int? {
        guard case .httpStatus(let code, _, _) = self else { return nil }
        return code
    }

    var responseBodySnippet: String? {
        guard case .httpStatus(_, _, let snippet) = self else { return nil }
        return snippet
    }
}

@MainActor
final class NightscoutClientV3 {
    let baseURL: NightscoutBaseURL
    private static let defaultRequestDuration: TimeInterval = 30
    private static let maximumBudgetedRequestDuration: TimeInterval = 5

    private struct CachedAuthorization {
        let accessTokenDigest: String
        let authorization: NightscoutAuthorization
    }

    private struct AuthorizationResponse: Decodable {
        let token: String
        let exp: Double?
        let permissionGroups: [String]

        private enum CodingKeys: String, CodingKey {
            case token
            case exp
            case permissionGroups
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            token = try container.decode(String.self, forKey: .token)

            if let numericExpiration = try? container.decode(Double.self, forKey: .exp) {
                exp = numericExpiration
            } else if let stringExpiration = try? container.decode(String.self, forKey: .exp) {
                exp = Double(stringExpiration)
            } else {
                exp = nil
            }

            // Nightscout emits one permission array per assigned role, e.g.
            // `[["*"], ["*:*:read"]]`. Accept the older flat shapes too so
            // connection testing works across supported server versions.
            if let groupedPermissions = try? container.decode(
                [[String]].self,
                forKey: .permissionGroups
            ) {
                permissionGroups = groupedPermissions.flatMap { $0 }
            } else if let groups = try? container.decode([String].self, forKey: .permissionGroups) {
                permissionGroups = groups
            } else if let group = try? container.decode(String.self, forKey: .permissionGroups) {
                permissionGroups = [group]
            } else {
                permissionGroups = []
            }
        }
    }

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cachedAuthorization: CachedAuthorization?

    init(baseURL: NightscoutBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        self.decoder = JSONDecoder()
    }

    convenience init(baseURLString: String, session: URLSession = .shared) throws {
        try self.init(baseURL: NightscoutBaseURL(normalizing: baseURLString), session: session)
    }

    func authorization(
        accessToken: String,
        forceRefresh: Bool = false,
        deadline: Date? = nil
    ) async throws -> NightscoutAuthorization {
        let trimmedToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw NightscoutClientError.missingAccessToken }

        let tokenDigest = NightscoutDigest.sha256Hex(of: Data(trimmedToken.utf8))
        if !forceRefresh,
           let cachedAuthorization,
           cachedAuthorization.accessTokenDigest == tokenDigest,
           cachedAuthorization.authorization.expiresAt.timeIntervalSinceNow > 30 {
            return cachedAuthorization.authorization
        }

        // The access token is encoded as exactly one path segment. This URL is
        // intentionally never logged because the token is part of the path.
        let requestURL = try endpointURL(
            pathSegments: ["api", "v2", "authorization", "request", trimmedToken]
        )
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try Self.applyTimeout(to: &request, deadline: deadline)

        let (data, response) = try await perform(request)
        try validateSuccess(response)

        guard let decoded = try? decoder.decode(AuthorizationResponse.self, from: data),
              !decoded.token.isEmpty,
              let expirationSeconds = decoded.exp ?? Self.jwtExpiration(from: decoded.token) else {
            throw NightscoutClientError.invalidAuthorizationResponse
        }

        let result = NightscoutAuthorization(
            jwt: decoded.token,
            expiresAt: Date(timeIntervalSince1970: expirationSeconds),
            permissionGroups: decoded.permissionGroups
        )
        cachedAuthorization = CachedAuthorization(
            accessTokenDigest: tokenDigest,
            authorization: result
        )
        return result
    }

    func putEntry(
        identifier: UUID,
        body: NightscoutEntryBody,
        accessToken: String,
        deadline: Date? = nil
    ) async throws {
        _ = try await authorizedRequest(
            method: "PUT",
            pathSegments: ["api", "v3", "entries", identifier.uuidString.lowercased()],
            body: body,
            accessToken: accessToken,
            deadline: deadline
        )
    }

    func putTreatment(
        identifier: UUID,
        body: NightscoutTreatmentBody,
        accessToken: String,
        deadline: Date? = nil
    ) async throws {
        _ = try await authorizedRequest(
            method: "PUT",
            pathSegments: ["api", "v3", "treatments", identifier.uuidString.lowercased()],
            body: body,
            accessToken: accessToken,
            deadline: deadline
        )
    }

    func deleteTreatment(
        identifier: UUID,
        accessToken: String,
        deadline: Date? = nil
    ) async throws -> NightscoutDeleteResult {
        // A normal v3 DELETE only sets `isValid=false`; some Nightscout graph
        // versions continue rendering those treatments. A user deleting a
        // dose in FLwatch expects it to disappear, so this operation is the
        // deliberate irreversible form of DELETE.
        let response = try await authorizedRequest(
            method: "DELETE",
            pathSegments: ["api", "v3", "treatments", identifier.uuidString.lowercased()],
            queryItems: Self.permanentDeleteQueryItems,
            bodyData: nil,
            accessToken: accessToken,
            acceptedStatusCodes: Set(200...299).union([404]),
            deadline: deadline
        )
        return response.statusCode == 404 ? .alreadyAbsent : .deleted
    }

    func testConnection(accessToken: String) async -> NightscoutConnectionTestResult {
        do {
            let authorization = try await authorization(accessToken: accessToken, forceRefresh: true)
            guard Self.hasRequiredWritePermissions(authorization.permissionGroups) else {
                return .tokenLacksWrites
            }

            _ = try await authorizedRequest(
                method: "GET",
                pathSegments: ["api", "v3", "status"],
                bodyData: nil,
                accessToken: accessToken
            )
            return .ok
        } catch let error as NightscoutClientError {
            switch error {
            case .transport, .invalidResponse, .requestEncoding:
                return .unreachable
            case .httpStatus(let code, _, _):
                if code == 401 || code == 403 {
                    return .tokenLacksWrites
                }
                if code == 429 || (500...599).contains(code) {
                    return .unreachable
                }
                return .notV3Server
            case .invalidAuthorizationResponse:
                return .notV3Server
            case .invalidBaseURL, .missingAccessToken:
                return .unreachable
            }
        } catch {
            return .unreachable
        }
    }

    func invalidateAuthorization() {
        cachedAuthorization = nil
    }

    static func hasRequiredWritePermissions(_ permissionGroups: [String]) -> Bool {
        let required = [
            "api:entries:create",
            "api:entries:update",
            "api:treatments:create",
            "api:treatments:update",
            "api:treatments:delete"
        ]
        return required.allSatisfy { permission in
            permissionGroups.contains { shiroPattern($0, grants: permission) }
        }
    }

    static func shiroPattern(_ pattern: String, grants permission: String) -> Bool {
        let patternSegments = pattern
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
            .map(String.init)
        let permissionSegments = permission
            .split(separator: ":", omittingEmptySubsequences: false)
            .map(String.init)

        guard !patternSegments.isEmpty, !permissionSegments.isEmpty else { return false }

        for (index, permissionSegment) in permissionSegments.enumerated() {
            // Apache Shiro treats omitted trailing pattern parts as wildcards.
            guard index < patternSegments.count else { return true }
            let patternSegment = patternSegments[index]
            let alternatives = patternSegment
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard alternatives.contains("*") || alternatives.contains(permissionSegment) else {
                return false
            }
        }

        // If the pattern has extra parts, each must itself be a wildcard to
        // imply the shorter permission.
        return patternSegments.dropFirst(permissionSegments.count).allSatisfy { segment in
            segment
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .contains("*")
        }
    }

    private func authorizedRequest<T: Encodable>(
        method: String,
        pathSegments: [String],
        body: T,
        accessToken: String,
        deadline: Date? = nil
    ) async throws -> HTTPURLResponse {
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            throw NightscoutClientError.requestEncoding
        }
        return try await authorizedRequest(
            method: method,
            pathSegments: pathSegments,
            bodyData: bodyData,
            accessToken: accessToken,
            deadline: deadline
        )
    }

    private func authorizedRequest(
        method: String,
        pathSegments: [String],
        queryItems: [URLQueryItem] = [],
        bodyData: Data?,
        accessToken: String,
        acceptedStatusCodes: Set<Int> = Set(200...299),
        deadline: Date? = nil
    ) async throws -> HTTPURLResponse {
        for attempt in 0...1 {
            let auth = try await authorization(
                accessToken: accessToken,
                forceRefresh: attempt == 1,
                deadline: deadline
            )
            var request = URLRequest(url: try endpointURL(
                pathSegments: pathSegments,
                queryItems: queryItems
            ))
            request.httpMethod = method
            request.httpBody = bodyData
            request.setValue("Bearer \(auth.jwt)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if bodyData != nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            try Self.applyTimeout(to: &request, deadline: deadline)

            let (data, response) = try await perform(request)
            if response.statusCode == 401, attempt == 0 {
                invalidateAuthorization()
                continue
            }
            try validate(
                response,
                responseData: data,
                acceptedStatusCodes: acceptedStatusCodes,
                captureResponseSnippet: true
            )
            return response
        }
        throw NightscoutClientError.httpStatus(
            code: 401,
            retryAfter: nil,
            responseBodySnippet: nil
        )
    }

    func endpointURL(
        pathSegments: [String],
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard var components = URLComponents(url: baseURL.url, resolvingAgainstBaseURL: false) else {
            throw NightscoutClientError.invalidBaseURL
        }
        components.percentEncodedPath = "/" + pathSegments.map(Self.percentEncodedPathSegment).joined(separator: "/")
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw NightscoutClientError.invalidBaseURL }
        return url
    }

    static let permanentDeleteQueryItems = [
        URLQueryItem(name: "permanent", value: "true")
    ]

    private static func applyTimeout(to request: inout URLRequest, deadline: Date?) throws {
        if let deadline {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw CancellationError() }
            request.timeoutInterval = min(maximumBudgetedRequestDuration, remaining)
        } else {
            request.timeoutInterval = defaultRequestDuration
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard NightscoutExecutionContext.isMainAppProcess else {
            throw NightscoutClientError.invalidResponse
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NightscoutClientError.invalidResponse
            }
            return (data, httpResponse)
        } catch let error as NightscoutClientError {
            throw error
        } catch {
            throw NightscoutClientError.transport(error)
        }
    }

    private func validateSuccess(_ response: HTTPURLResponse) throws {
        try validate(
            response,
            responseData: Data(),
            acceptedStatusCodes: Set(200...299),
            captureResponseSnippet: false
        )
    }

    private func validate(
        _ response: HTTPURLResponse,
        responseData: Data,
        acceptedStatusCodes: Set<Int>,
        captureResponseSnippet: Bool
    ) throws {
        guard acceptedStatusCodes.contains(response.statusCode) else {
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap {
                TimeInterval($0)
            }
            let snippet: String?
            if captureResponseSnippet, !responseData.isEmpty {
                snippet = String(decoding: responseData.prefix(1_024), as: UTF8.self)
            } else {
                snippet = nil
            }
            throw NightscoutClientError.httpStatus(
                code: response.statusCode,
                retryAfter: retryAfter,
                responseBodySnippet: snippet
            )
        }
    }

    private static func percentEncodedPathSegment(_ value: String) -> String {
        value.utf8.map { byte in
            switch byte {
            case 0x41...0x5A, 0x61...0x7A, 0x30...0x39, 0x2D, 0x2E, 0x5F, 0x7E:
                return String(UnicodeScalar(byte))
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
    }

    private static func jwtExpiration(from token: String) -> Double? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = payload.count % 4
        if padding != 0 {
            payload.append(String(repeating: "=", count: 4 - padding))
        }
        guard let data = Data(base64Encoded: payload),
              let decodedObject = try? JSONSerialization.jsonObject(with: data),
              let object = decodedObject as? [String: Any] else {
            return nil
        }
        if let expiration = object["exp"] as? Double { return expiration }
        if let expiration = object["exp"] as? Int { return Double(expiration) }
        if let expiration = object["exp"] as? String { return Double(expiration) }
        return nil
    }
}
