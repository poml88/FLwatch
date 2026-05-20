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
    //
    // Share's follower flow is two steps (xdripswift's DexcomShareFollowManager):
    //   1) POST /General/AuthenticatePublisherAccount → returns the stable accountId
    //   2) POST /General/LoginPublisherAccountById     → exchanges accountId for sessionId
    //
    // The single-step /General/LoginPublisherAccountByName endpoint exists too,
    // but xdripswift uses it only on the upload path (xdrip → Share for Loop to
    // read). FLwatch reads, so we mirror the follower (two-step) flow.

    /// Step 1: accountName + password → stable accountId GUID. All-zeros sentinel
    /// means the account does not exist at this region — usually a wrong-region
    /// situation rather than a wrong password.
    func authenticate(email: String, password: String, region: ShareRegion) async throws -> String {
        let url = makeURL(region: region, path: "/General/AuthenticatePublisherAccount")
        let body: [String: String] = [
            "accountName":   email,
            "password":      password,
            "applicationId": region.applicationId,
        ]
        do {
            let id = try await postAuthExpectingString(url: url, body: body)
            if isAllZeroGUID(id) {
                Logger.dexcomShare.error("authenticate at \(region.rawValue, privacy: .public): all-zero accountId — treating as accountNotFound")
                throw DexcomShareError.accountNotFound
            }
            return id
        } catch let error as DexcomShareError {
            Logger.dexcomShare.error("authenticate at \(region.rawValue, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    /// Step 2: accountId + password → fresh sessionId GUID. An all-zeros sentinel
    /// at this step indicates session-acquisition failure (typically wrong password).
    func loginById(accountId: String, password: String, region: ShareRegion) async throws -> String {
        let url = makeURL(region: region, path: "/General/LoginPublisherAccountById")
        let body: [String: String] = [
            "accountId":     accountId,
            "password":      password,
            "applicationId": region.applicationId,
        ]
        do {
            let id = try await postAuthExpectingString(url: url, body: body)
            if isAllZeroGUID(id) {
                Logger.dexcomShare.error("loginById at \(region.rawValue, privacy: .public): all-zero sessionId — treating as accountPasswordInvalid")
                throw DexcomShareError.accountPasswordInvalid
            }
            Logger.dexcomShare.info("login at \(region.rawValue, privacy: .public) succeeded")
            return id
        } catch let error as DexcomShareError {
            Logger.dexcomShare.error("loginById at \(region.rawValue, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            throw error
        }
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
        // Match xdrip4ios's read-path shape exactly: only Accept + User-Agent;
        // no Content-Type; empty body. Some Share servers silently return `[]`
        // when given Content-Type: application/json with a stub `{}` body, so
        // do not add either even if "more correct" per HTTP convention.
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(DexcomShareConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = Data()

        let (data, response) = try await perform(request: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            throw makeError(data: data, status: status)
        }

        do {
            let entries = try decoder.decode([ShareGlucoseEntry].self, from: data)
            Logger.dexcomShare.info("readLatestGlucose: \(entries.count, privacy: .public) entries")
            return entries
        } catch {
            let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
            Logger.dexcomShare.error("Failed to decode EGV array; body=\(bodyText, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw DexcomShareError.malformedResponse("could not decode glucose array: \(error.localizedDescription)")
        }
    }

    // MARK: - Internals

    private func makeURL(region: ShareRegion, path: String) -> URL {
        // Force-unwrap is safe: hosts and paths are constants.
        URL(string: region.host + DexcomShareConstants.basePath + path)!
    }

    /// Posts a JSON body to an auth endpoint and expects a single quoted-GUID-
    /// string response, e.g. `"abc12345-...-...-...-..."`. Matches xdripswift's
    /// `DexcomShareFollowManager` auth request shape exactly: Content-Type +
    /// URL-encoded-space User-Agent, no Accept header.
    private func postAuthExpectingString(url: URL, body: [String: String]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DexcomShareConstants.userAgentAuth, forHTTPHeaderField: "User-Agent")
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
        let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
        if let parsed = try? decoder.decode(ShareErrorResponse.self, from: data) {
            Logger.dexcomShare.error("HTTP \(status, privacy: .public) error: Code=\(parsed.code, privacy: .public) SubCode=\(parsed.subCode ?? "nil", privacy: .public) Message=\(parsed.message ?? "nil", privacy: .public)")
            return DexcomShareError(parsed, status: status)
        }
        Logger.dexcomShare.error("HTTP \(status, privacy: .public) error: unparseable body: \(bodyText, privacy: .public)")
        return DexcomShareError.http(status: status, code: nil, message: bodyText)
    }

    private func isAllZeroGUID(_ id: String) -> Bool {
        id == "00000000-0000-0000-0000-000000000000"
    }
}
