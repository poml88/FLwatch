//
//  DexcomShareClient.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  URLSession wrapper for the unofficial Dexcom Share API. Stateless: knows
//  nothing about persistence, regions on disk, or the active provider. Three
//  calls — authenticate, loginById, readLatestGlucose — plus error mapping.
//

import Foundation
import OSLog

actor DexcomShareClient {

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - Auth

    /// Step 1 of login. Returns the user's stable accountId GUID.
    /// Throws `.accountNotFound` on the all-zeros sentinel (wrong region or
    /// wrong username); throws `.accountPasswordInvalid` on bad password.
    func authenticate(email: String, password: String, region: ShareRegion) async throws -> String {
        let url = makeURL(region: region, path: "/General/AuthenticatePublisherAccount")
        let body: [String: String] = [
            "accountName":   email,
            "password":      password,
            "applicationId": DexcomShareConstants.applicationId,
        ]
        let id = try await postExpectingString(url: url, body: body)
        if isAllZeroGUID(id) {
            throw DexcomShareError.accountNotFound
        }
        return id
    }

    /// Step 2 of login. Exchanges a stable accountId for a fresh sessionId GUID.
    /// Throws `.sessionInvalid` on the all-zeros sentinel.
    func loginById(accountId: String, password: String, region: ShareRegion) async throws -> String {
        let url = makeURL(region: region, path: "/General/LoginPublisherAccountById")
        let body: [String: String] = [
            "accountId":     accountId,
            "password":      password,
            "applicationId": DexcomShareConstants.applicationId,
        ]
        let id = try await postExpectingString(url: url, body: body)
        if isAllZeroGUID(id) {
            throw DexcomShareError.sessionInvalid
        }
        return id
    }

    // MARK: - Read glucose

    /// Returns the latest glucose entries within the requested window. Server
    /// orders newest-first.
    func readLatestGlucose(
        sessionId: String,
        region: ShareRegion,
        minutes: Int,
        maxCount: Int
    ) async throws -> [ShareGlucoseEntry] {
        var components = URLComponents(string: region.host
                                       + DexcomShareConstants.basePath
                                       + "/Publisher/ReadPublisherLatestGlucoseValues")!
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "minutes",   value: String(minutes)),
            URLQueryItem(name: "maxCount",  value: String(maxCount)),
        ]
        guard let url = components.url else {
            throw DexcomShareError.malformedResponse("could not build glucose URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DexcomShareConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await perform(request: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            throw makeError(data: data, status: status)
        }
        do {
            return try decoder.decode([ShareGlucoseEntry].self, from: data)
        } catch {
            let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
            Logger.dexcomShare.error("Failed to decode EGV array: \(bodyText, privacy: .private(mask: .hash))")
            throw DexcomShareError.malformedResponse("could not decode glucose array: \(error.localizedDescription)")
        }
    }

    // MARK: - Internals

    private func makeURL(region: ShareRegion, path: String) -> URL {
        // Force-unwrap is safe: hosts and paths are constants.
        URL(string: region.host + DexcomShareConstants.basePath + path)!
    }

    /// Posts a JSON body and expects a single quoted-GUID-string response, e.g.
    ///     "abc12345-...-...-...-...".
    private func postExpectingString(url: URL, body: [String: String]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DexcomShareConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await perform(request: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            throw makeError(data: data, status: status)
        }
        guard let raw = String(data: data, encoding: .utf8) else {
            throw DexcomShareError.malformedResponse("non-utf8 response body")
        }
        // Body is a JSON-encoded string: leading/trailing quotes and whitespace.
        return raw.trimmingCharacters(in: .init(charactersIn: "\" \r\n\t"))
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            throw DexcomShareError.network(urlError)
        }
    }

    private func makeError(data: Data, status: Int) -> Error {
        if let parsed = try? decoder.decode(ShareErrorResponse.self, from: data) {
            return DexcomShareError(parsed, status: status)
        }
        let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
        return DexcomShareError.http(status: status, code: nil, message: bodyText)
    }

    private func isAllZeroGUID(_ id: String) -> Bool {
        id == "00000000-0000-0000-0000-000000000000"
    }
}
