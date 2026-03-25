//
//  LibreLinkUp.swift
//  LibreWrist
//
//  Created by Peter Müller on 24.08.24.
//

import Foundation
import OSLog
import SwiftUI
import StoreKit

// https://github.com/timoschlueter/nightscout-librelink-up
// https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2

struct LibreLinkUpLastGlucoseEntry {
    let date: Date
    let glucoseMeasurement: GlucoseMeasurement
    var currentIOB: Double
}

struct LibreLinkUpPatient: Codable, Identifiable, Hashable {
    let patientId: String
    let firstName: String
    let lastName: String

    var id: String { patientId }

    var displayName: String {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? patientId : fullName
    }
}

class LibreLinkUp  {
    //    class LibreLinkUp: Logging {
    
    //    var main: MainDelegate!
    
    
    let siteURL = "https://api.libreview.io"
    let loginEndpoint = "llu/auth/login"
    let configEndpoint = "llu/config"
    let connectionsEndpoint = "llu/connections"
    let measurementsEndpoint = "lsl/api/measurements"
    
    let regions = ["ae", "ap", "au", "ca", "de", "eu", "eu2", "fr", "jp", "la", "us", "ru", "cn"]  // eu2: GB and IE
    
    let regionalSiteURLRU: String = "https://api.libreview.ru" // There are various places where these need to be updated as well
    let regionalSiteURLCN: String = "https://api-cn.myfreestyle.cn"
    var regionalSiteURL: String { SharedData.libreLinkUpRegion == "ru" ? regionalSiteURLRU : SharedData.libreLinkUpRegion == "cn" ? regionalSiteURLCN : "https://api-\(SharedData.libreLinkUpRegion).libreview.io" }
        
    var unit: GlucoseUnit = .mgdl
    
    var responseData: String = ""
    var libreLinkUpResponse: String = "[...]"
    var libreLinkUpErrorBool: Bool = false
    //    var sensorSettings: SensorSettings = SensorSettings()
    
    let headers = LLUHeaders().headers
    
    
    
    init() {
        print("New instance of LibreLinkUp")
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed,
                 .timedOut:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private static func makeUTCTimestampFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }

    private static func makeLocalTimestampFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter
    }

    private static func makeISO8601Formatter(withFractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = withFractionalSeconds ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    static func parseMeasurementDate(factoryTimestamp: String?, timestamp: String) -> Date? {
        if let factoryTimestamp, !factoryTimestamp.isEmpty {
            if let date = makeUTCTimestampFormatter().date(from: factoryTimestamp) {
                return date
            }
        }

        if timestamp.contains("T") {
            if let date = makeISO8601Formatter(withFractionalSeconds: true).date(from: timestamp) {
                return date
            }
            if let date = makeISO8601Formatter(withFractionalSeconds: false).date(from: timestamp) {
                return date
            }
        }

        return makeLocalTimestampFormatter().date(from: timestamp)
    }
    
    
    //    init(main: MainDelegate) {
    //        self.main = main
    //    }
    //    init() {
    //        //settings = Settings()
    ////        print ("\(settings)")
    //    }
    
    func reloadLibreLinkUp() async {
        print("reloadLibreLinkUp()")
        var dataString = ""
        var retries = 0
        DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
        
        
    loop: repeat {
        do {
            libreLinkUpErrorBool = false
//            let token = settings.libreLinkUpToken
            if SharedData.libreLinkUpUserId.isEmpty ||
                SharedData.libreLinkUpToken.isEmpty ||
                SharedData.libreLinkUpTokenExpirationDate < Date() ||
                retries == 1 {
                do {
                    libreLinkUpErrorBool = false
                    try await login()
                } catch {
                    libreLinkUpErrorBool = true
                    libreLinkUpResponse = error.localizedDescription
                    throw error
                }
            }
            if !(SharedData.libreLinkUpUserId.isEmpty ||
                 SharedData.libreLinkUpToken.isEmpty) {
                let (data, _, graphHistory, logbookData, logbookHistory, _, sensorSettingsRead, sensorType) = try await getPatientGraph()
                dataString = (data as! Data).string
                libreLinkUpResponse = dataString + (logbookData as! Data).string
                DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
                
                //                if libreLinkUpHistory.count == 0 {
                //                    libreLinkUpHistory = MockDataPhone
                //                }
                //                libreLinkUpLogbookHistory = logbookHistory
                
                
                
                //                try await LibreLinkUp().getLastGlucoseData()
                
                if graphHistory.count > 0 {
                    await MainActor.run {
                        let historyStore = LibreLinkUpHistory.shared
                        let now = Date()
                        SensorSettingsStore.shared.replaceCacheAndPersist(sensorSettings: sensorSettingsRead, sensorType: sensorType)
                        // TODO: just merge with newer values
                        let graphHistoryReversed: [LibreLinkUpGlucose] = graphHistory.reversed()
                        let fullGraphHistory = graphHistoryReversed
                        let dateSixHoursTenAgo: Date = Date(timeIntervalSinceNow: -6 * 60 * 60 - 10 * 60)
                        var filteredGraphHistory = graphHistoryReversed.filter { $0.glucose.date > dateSixHoursTenAgo } // delete everything older than 6 hours.
                        if filteredGraphHistory.isEmpty {
                            filteredGraphHistory.append(graphHistoryReversed[0])
                            if graphHistoryReversed.indices.contains(1) {
                                filteredGraphHistory.append(graphHistoryReversed[1]) // this is only added for trend filter below
                            }
                        }
                        Logger.libreLinkUp.debug("LibreLinkUp: libreLinkUpHistory.libreLinkUpGlucose: \(filteredGraphHistory)")
//                        if graphHistory.count > 1 {                                                                                 // make sure that [0] exists, must be 2 to drop 1.
//                            LibreLinkUpHistory.shared.libreLinkUpGlucose = graphHistory.reversed().dropLast(graphHistory.count / 2) // deviding by two reduces graph to 6 hours.
//                        } else {
//                            LibreLinkUpHistory.shared.libreLinkUpGlucose = graphHistory                                             // is only 1 value
//                        }
                        let lastMeasurement: LibreLinkUpGlucose = graphHistoryReversed[0] // access index 0 seems ok, since graphHistory.count > 0
                        //                        minutesSinceLastReading = Int(Date().timeIntervalSince(lastReadingDate) / 60)
                        //                        sensor?.lastReadingDate = lastReadingDate
                        // TODO: keep the raw values filling the gaps with -1 values
                        //                        history.rawValues = []
                        //                        history.factoryValues = libreLinkUpHistory.libreLinkUpGlucose.dropFirst().map(\.glucose) // TEST
                        var trend = historyStore.libreLinkUpMinuteGlucose
                        //                        Logger.libreLinkUp.info("LibreLinkUp: trend: \(trend)")
                        //                        let a: String = "\(lastMeasurement)"
                        //                        Logger.libreLinkUp.info("LibreLinkUp: lastMeasurement: \(a)")
                        
                        if trend.isEmpty || lastMeasurement.id > trend[0].id { // FIXME: for the first hour of a new sensor values are not inserted into trend or are they filtered out below?
                            // 62 > -2 = insert // 118 > -2 = insert // -2 > 20000 false
                            trend.insert(lastMeasurement, at: 0)
                        }
                        // keep only the latest 16 minutes considering the 17-minute latency of the historic values update. seems to vary between 21 and 17 minutes.
                        if filteredGraphHistory.indices.contains(1) {
                            var lastGraphItem = filteredGraphHistory[1].id // could be -20 after new sensor. // 100
                            if lastGraphItem < 60 {
                                lastGraphItem = 60
                            }
                            trend = trend.filter { $0.id > lastGraphItem } // would be true: -2 > -20 and 62 > -20 // -2 > 100 false // 118 > 100 true
                            trend = trend.filter { $0.id - lastGraphItem < 60 } // 20000 - -20 false // 62 - -20 = 82 false and -2 - -20 = 18 true // 118 - 100 < 60 true
                        }
                        let indexOfMaxGlucoseItem = filteredGraphHistory.indices.max(by:
                                                                                        { filteredGraphHistory[$0].glucose.value < filteredGraphHistory[$1].glucose.value }
                        ) ?? 0 // Seems to work also with one value only, I guess because it is optional
#if os(iOS)
                        let maxBG = filteredGraphHistory.isEmpty ? 250 : filteredGraphHistory[indexOfMaxGlucoseItem].glucose.value
#endif
#if os(watchOS)
                        let maxBG = filteredGraphHistory.isEmpty ? 225 : filteredGraphHistory[indexOfMaxGlucoseItem].glucose.value
#endif
                        _ = historyStore.replaceCacheAndPersist(
                            fullLibreLinkUpGlucose: fullGraphHistory,
                            libreLinkUpGlucose: filteredGraphHistory,
                            libreLinkUpMinuteGlucose: trend,
                            latestLibreLinkUpGlucose: lastMeasurement,
                            lastReadingDate: lastMeasurement.glucose.date,
                            currentGlucose: lastMeasurement.glucose.value, // always mg/dl
                            currentTrendArrow: lastMeasurement.trendArrow?.symbol ?? "---",
                            maxBG: maxBG,
                            lastSuccessfulLibreLinkUpAPICall: now,
                            lastReloadAttemptDate: historyStore.lastReloadAttemptDate
                        )
                        Logger.libreLinkUp.debug("LibreLinkUp: libreLinkUpHistory.libreLinkUpMinuteGlucose: \(historyStore.libreLinkUpMinuteGlucose)")
                        // TODO: merge and update sensor history / trend
                        //                            app.main.didParseSensor(app.sensor)
                    }
                }
                if dataString != "{\"message\":\"MissingCachedUser\"}\n" {
                    break loop
                }
                retries += 1
            }
        } catch {
            libreLinkUpResponse = error.localizedDescription
            libreLinkUpErrorBool = true
        }
    } while retries == 1
        
    }
    
    
    
    @discardableResult
    func login() async throws -> (Any, URLResponse) {
        var request = URLRequest(url: URL(string: "\(siteURL)/\(loginEndpoint)")!)
        request.timeoutInterval = 20
        
        //        let appGroupID = UserDefaults.stringValue(forKey: "APP_GROUP_ID")
        let credentials = [
            "email": UserDefaults.group.username,
            "password": (try? PasswordKeychain.read()) ?? ""
            // with password there was a tricky error: since this library is used by watch and phone I got an error "Type 'SecureDefaults' has no member 'sgroup'"
            // I had to add the SecureDefaults extension to the watch app as well. the watch app called it and it did not know about sgroup. It did work for the phone app though.
        ]
        request.httpMethod = "POST"
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        let jsonData = try? JSONSerialization.data(withJSONObject: credentials)
        request.httpBody = jsonData
        do {
            var redirected: Bool
            var regionIsRussia = false
            var regionIsChina = false
            loop: repeat {
                redirected = false
                var didEstablishAuthSession = false
                Logger.libreLinkUp.debug("LibreLinkUp: posting to \(request.url!.absoluteString) \(jsonData!.string), headers: \(self.headers)")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let response = response as? HTTPURLResponse {
                    let status = response.statusCode
                    Logger.libreLinkUp.debug("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \(status)")
                    responseData = "LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \(status)"
                    if status == 401 {
                        Logger.libreLinkUp.error("LibreLinkUp: POST not authorized")
                    } else {
                        Logger.libreLinkUp.debug("LibreLinkUp: POST \((200..<300).contains(status) ? "success" : "error")")
                    }
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let status = json["status"] as? Int {
                        
                        let data = json["data"] as? [String: Any]
                        
                        if status != 0 {
                            DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: " + responseData
                        } else {
                            DebugMessageSingleton.shared.libreLinkUpResponseError = "none"
                        }
                        
                        if status == 2 {
                            if let storefront = await Storefront.current {
                                let countryCode = storefront.countryCode
                                if countryCode == "RUS" { // || UserDefaults.group.username == "xxx.xxx@yandex.ru" {
                                    if regionIsRussia == false {
                                        regionIsRussia = true
                                        redirected = true
                                        SharedData.libreLinkUpRegion = "ru"
                                        Logger.libreLinkUp.debug("LibreLinkUp: Storefront country code: \(countryCode), redirecting to \(self.regionalSiteURLRU)/\(self.loginEndpoint) ")
                                        request.url = URL(string: "\(regionalSiteURLRU)/\(loginEndpoint)")!
                                        continue loop
                                    }
                                }
                                if countryCode == "CHN" {
                                    if regionIsChina == false {
                                        regionIsChina = true
                                        redirected = true
                                        SharedData.libreLinkUpRegion = "cn"
                                        Logger.libreLinkUp.debug("LibreLinkUp: Storefront country code: \(countryCode), redirecting to \(self.regionalSiteURLCN)/\(self.loginEndpoint) ")
                                        request.url = URL(string: "\(regionalSiteURLCN)/\(loginEndpoint)")!
                                        continue loop
                                    }
                                }
                                // {"status":2,"error":{"message":"incorrect username/password"}}, status: 200
                                regionIsRussia = false
                                regionIsChina = false
                                DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 2 notAuthenticated"
                                throw LibreLinkUpError.notAuthenticated
                            }
                            DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 2 notAuthenticated storefront unavailable"
                            throw LibreLinkUpError.notAuthenticated
                        }
                        
                        if status == 429 {
                            // {"status":429,"data":{"code":60,"data":{"failures":3,"interval":60,"lockout":300},"message":"locked"}}
                            DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 429 lockedAccount"
                            if let data, let message = data["message"] as? String {
                                if message == "locked" {
                                    if let data = data["data"] as? [String: Any],
                                       let failures = data["failures"] as? Int,
                                       let interval = data["interval"] as? Int,
                                       let lockout = data["lockout"] as? Int {
                                        Logger.libreLinkUp.error("LibreLinkUp: login failures: \(failures), interval: \(interval) s, lockout: \(lockout) s")
                                    }
                                }
                            }
                            throw LibreLinkUpError.lockedAccount
                        }
                        if status == 911 {
                            // {"status":911} when logging in at a stranger regional server
                            DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 911 wrong regional server"
                            throw LibreLinkUpError.loggingIntoWrongRegionalServer
                        }
                        
                        // TODO: status 4 requires accepting new Terms of Use: api.libreview.io/auth/continue/tou
                        if status == 4 {
                            if let data, let step = data["step"] as? [String: Any],
                               let type = step["type"] as? String {
                                if type == "verifyEmail" {
                                    print("verifyemail")
                                    Logger.libreLinkUp.error("LibreLinkUp: User has not yet verified his LLU email (tip: log out and re-login)")
                                    DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 4 verifyEmail"
                                    throw LibreLinkUpError.verifyEmail
                                    
                                    //                        LibreLinkUp: response data: {"status":4,"data":{"step":{"type":"verifyEmail","componentName":"VerifyEmail","props":{"email":"xxxxxxxx@cmdline.net"}},"user":{"accountType":"pat","country":"DE","uiLanguage":"de-DE"},"authTicket":{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImQ5OGY3YTAwLTFhZjctMTFmMC05NGViLTVhMzc4MGRlMDYzNiIsImZpcnN0TmFtZSI6IkZMIiwibGFzdE5hbWUiOiJ3YXRjaCAiLCJjb3VudHJ5IjoiREUiLCJyZWdpb24iOiJkZSIsInJvbGUiOiJwYXRpZW50IiwiZW1haWwiOiJmbHdhdGNoQGNtZGxpbmUubmV0IiwicyI6ImxsdS5pb3MiLCJzaWQiOiJiYzMwNzI3MS03ODdjLTQ3NjEtOTIyNy0yMjQwMzliZGQ2MWYiLCJleHAiOjE3NDQ4MzQ4NDEsImlhdCI6MTc0NDgzMTI0MSwianRpIjoiYTk4NTNmZmMtMTYzMC00MDcwLTgyZmUtZjlhOTc2MTUyNzIzIn0.M7nsO65mDx5lFq9IDBFf6OG419Qkaa2avjL1SYoT1tg","expires":1744834841,"duration":3600000}}}, status: 200
                                    
                                    
                                } else if type == "tou" {
                                    print("tou")
                                    Logger.libreLinkUp.error("LibreLinkUp: Terms of Use have been updated and must be accepted by running LibreLink (tip: log out and re-login)")
                                    DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 4 touNotAccepted"
                                    if                                    let user = data["user"] as? [String: Any],
                                                                          let country = user["country"] as? String,
                                                                          let authTicketDict = data["authTicket"] as? [String: Any],
                                                                          let authTicketData = try? JSONSerialization.data(withJSONObject: authTicketDict),
                                                                          let authTicket = try? JSONDecoder().decode(AuthTicket.self, from: authTicketData) {
                                        let authTicketString = "\(authTicket)"
                                        Logger.libreLinkUp.debug("LibreLinkUp: ToU: authTicket: \(authTicketString), expires on \(Date(timeIntervalSince1970: Double(authTicket.expires)))")
                                        //call accepttou
                                        //loginResponse = try await tou(apiRegion: apiRegion, authToken: authToken)
                                    }
                                    throw LibreLinkUpError.touNotAccepted
                                    
                                    //                        LibreLinkUp: response data: {"status":4,"data":{"step":{"type":"tou","componentName":"AcceptDocument","props":{"reaccept":true,"titleKey":"Common.termsOfUse","type":"tou"}},"user":{"accountType":"pat","country":"DE","uiLanguage":"de-DE"},"authTicket":{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjJjMTFhMmNlLTY1MmYtMTFlZi1hOGY5LWU2NTlhODBiNTU2OSIsImZpcnN0TmFtZSI6IkxpYnJlICIsImxhc3ROYW1lIjoiV3Jpc3QiLCJjb3VudHJ5IjoiREUiLCJyZWdpb24iOiJkZSIsInJvbGUiOiJwYXRpZW50IiwiZW1haWwiOiJsaWJyZXdpZGdldEBjbWRsaW5lLm5ldCIsImMiOjEsInMiOiJsbHUuaW9zIiwiZXhwIjoxNzI3MzQyNTE4fQ._-kekmE1JEmpmdUUhpKTyqg15xwGXLSo3vh9wbTLVn8","expires":1727342518,"duration":3600000}}}, status: 200
                                    //                        LibreLinkUp: POST success
                                    //                        LibreLinkUp: Terms of Use have been updated and must be accepted by running LibreLink (tip: log out and re-login)
                                    //                        LibreLinkUp: error: not authenticated
                                    
                                } else if type == "pp" {
                                    print("pp")
                                    Logger.libreLinkUp.error("LibreLinkUp: Privacy policy has been updated and must be accepted by running LibreLink (tip: log out and re-login)")
                                    DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 4 ppNotAccepted"
                                    if                                    let user = data["user"] as? [String: Any],
                                                                          let country = user["country"] as? String,
                                                                          let authTicketDict = data["authTicket"] as? [String: Any],
                                                                          let authTicketData = try? JSONSerialization.data(withJSONObject: authTicketDict),
                                                                          let authTicket = try? JSONDecoder().decode(AuthTicket.self, from: authTicketData) {
                                        let authTicketString = "\(authTicket)"
                                        Logger.libreLinkUp.debug("LibreLinkUp: PP: authTicket: \(authTicketString), expires on \(Date(timeIntervalSince1970: Double(authTicket.expires)))")
                                        //call accepttou
                                        //loginResponse = try await tou(apiRegion: apiRegion, authToken: authToken)
                                    }
                                    throw LibreLinkUpError.ppNotAccepted
                                    
                                    
//                                    LibreLinkUp: response data: {"status":4,"data":{"step":{"type":"pp","componentName":"AcceptDocument","props":{"reaccept":true,"titleKey":"Common.privacyPolicy","type":"pp"}},"user":{"accountType":"pat","country":"DE","uiLanguage":"de-DE"},"authTicket":{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImZmNTkyYjQwLTc1OWEtMTFlZS1iZTkzLWIyNmRmNGI2YzU5MyIsImZpcnN0TmFtZSI6IlBoaWxpcHAgIiwibGFzdE5hbWUiOiJQw7ZtbCAiLCJjb3VudHJ5IjoiREUiLCJyZWdpb24iOiJkZSIsInJvbGUiOiJwYXRpZW50IiwiZW1haWwiOiJwaGlsLnBvZW1sQGdteC5kZSIsInMiOiJsbHUuaW9zIiwic2lkIjoiODUxNTFiZDMtMGJkZC00ZThlLTljNjktOThlM2U5NTdiMjJlIiwidGFza1R5cGUiOiJwcCIsImV4cCI6MTc1MjgyMTM2NSwiaWF0IjoxNzUyODE3NzY1LCJqdGkiOiJmMzc1YzI4My01Y2NkLTQ2NGMtOTk5Yy0xODJlNWNhMDc5YTEifQ.lJxNoaRE3w2JxjEWCeFO8DTeC-W2IgNrnpLpZmM9ldU","expires":1752821365,"duration":3600000}}}, status: 200

                                    
                                } else {
                                    DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 4 unknown step"
                                    throw LibreLinkUpError.unknownStatus4
                                }
                            }
                        }
                        
                        // {"status":0,"data":{"redirect":true,"region":"fr"}}
                        if let redirect = data?["redirect"] as? Bool,
                           let region = data?["region"] as? String {
                            redirected = redirect
                            //                        DispatchQueue.main.async { [self] in
                            SharedData.libreLinkUpRegion = region
                            //                        }
                            Logger.libreLinkUp.debug("LibreLinkUp: redirecting to \(self.regionalSiteURL)/\(self.loginEndpoint) ") // The very first time this will be "eu" instead of the "region" because UserDefaults has not been set.
                            request.url = URL(string: "\(regionalSiteURL)/\(loginEndpoint)")!
                            continue loop
                        }
                        
                        if let data,
                           let user = data["user"] as? [String: Any],
                           let id = user["id"] as? String,
                           let country = user["country"] as? String,
                           let authTicketDict = data["authTicket"] as? [String: Any],
                           let authTicketData = try? JSONSerialization.data(withJSONObject: authTicketDict),
                           let authTicket = try? JSONDecoder().decode(AuthTicket.self, from: authTicketData) {
                            let authTicketString = "\(authTicket)"
                            Logger.libreLinkUp.debug("LibreLinkUp: user id: \(id), country: \(country), authTicket: \(authTicketString), expires on \(Date(timeIntervalSince1970: Double(authTicket.expires)))")
                            
                            SharedData.libreLinkUpUserId = id
                            SharedData.libreLinkUpPatientId = id  // avoid scraping patientId when following ourselves
                            SharedData.libreLinkUpCountry = country
                            SharedData.libreLinkUpToken = authTicket.token
                            SharedData.libreLinkUpTokenExpirationDate = Date(timeIntervalSince1970: Double(authTicket.expires))
                            didEstablishAuthSession = true
                            
                            
                            if !country.isEmpty {
                                // default "de" and "fr" regional servers
                                let defaultRegion = regions.contains(country.lowercased()) ? country.lowercased() : SharedData.libreLinkUpRegion
                                var request = URLRequest(url: URL(string: "\(siteURL)/\(configEndpoint)/country?country=\(country)")!)
                                if regionIsRussia {
                                    request = URLRequest(url: URL(string: "\(regionalSiteURLRU)/\(configEndpoint)/country?country=\(country)")!)
                                }
                                for (header, value) in headers {
                                    request.setValue(value, forHTTPHeaderField: header)
                                }
                                Logger.libreLinkUp.debug("LibreLinkUp: URL request: \(request.url!.absoluteString), headers: \(request.allHTTPHeaderFields!)")
                                let (data, response) = try await URLSession.shared.data(for: request)
                                Logger.libreLinkUp.debug("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
                                do {
                                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                       let data = json["data"] as? [String: Any],
                                       let server = data["lslApi"] as? String {
                                        let regionIndex = server.firstIndex(of: "-")
                                        let region = regionIndex == nil ? defaultRegion : String(server[server.index(regionIndex!, offsetBy: 1) ..< server.firstIndex(of: ".")!])
                                        Logger.libreLinkUp.debug("LibreLinkUp: regional server: \(server), saved default region: \(region)")
                                        //                                    DispatchQueue.main.async { [self] in
                                        SharedData.libreLinkUpRegion = region
                                        //                                    }
                                        //                                        if settings.userLevel >= .test {
                                        var countryCodes = [String]()
                                        if let countryList = data["CountryList"] as? [String: Any],
                                           let countries = countryList["countries"] as? [[String: Any]] {
                                            for country in countries {
                                                countryCodes.append(country["ValueMember"] as! String)
                                            }
                                            Logger.libreLinkUp.debug("LibreLinkUp: country codes: \(countryCodes)")
                                        }
                                        //                                        }
                                    }
                                } catch {
                                    Logger.libreLinkUp.error("LibreLinkUp: error while decoding response: \(error.localizedDescription)")
                                    throw LibreLinkUpError.jsonDecoding
                                }
                            }
                            
                            if SharedData.libreLinkUpFollowing {
                                Logger.libreLinkUp.debug("LibreLinkUp: getting connections for follower user id: \(id)")
                                var request = URLRequest(url: URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)")!)
                                var authenticatedHeaders = headers
                                authenticatedHeaders["Authorization"] = "Bearer \(SharedData.libreLinkUpToken)"
                                authenticatedHeaders["Account-Id"] = SharedData.libreLinkUpUserId.SHA256
                                for (header, value) in authenticatedHeaders {
                                    request.setValue(value, forHTTPHeaderField: header)
                                }
                                Logger.libreLinkUp.debug("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
                                let (data, response) = try await URLSession.shared.data(for: request)
                                Logger.libreLinkUp.debug("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
                                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let data = json["data"] as? [[String: Any]] {
                                    let patients = data.compactMap { connection -> LibreLinkUpPatient? in
                                        guard let patientId = connection["patientId"] as? String else {
                                            return nil
                                        }
                                        let firstName = connection["firstName"] as? String ?? ""
                                        let lastName = connection["lastName"] as? String ?? ""
                                        return LibreLinkUpPatient(
                                            patientId: patientId,
                                            firstName: firstName,
                                            lastName: lastName
                                        )
                                    }
                                    SharedData.libreLinkUpPatients = patients
                                    if let selectedPatient =
                                        patients.first(where: { $0.patientId == SharedData.libreLinkUpLastUsedPatientId }) ??
                                        patients.first {
                                        Logger.libreLinkUp.debug("LibreLinkUp: selected patient after login: \(selectedPatient.displayName), id: \(selectedPatient.patientId)")
                                        await MainActor.run {
                                            SharedData.libreLinkUpPatientId = selectedPatient.patientId
                                            SharedData.libreLinkUpLastUsedPatientId = selectedPatient.patientId
                                        }
                                    } else {
                                        SharedData.libreLinkUpPatients = []
                                    }
                                }
                            } else {
                                SharedData.libreLinkUpPatients = []
                            }
                        }
                        if status == 0 && !didEstablishAuthSession {
                            Logger.libreLinkUp.error("LibreLinkUp: login succeeded without establishing an auth session")
                            DebugMessageSingleton.shared.libreLinkUpResponseError = "Login: status 0 missing user/authTicket"
                            throw LibreLinkUpError.jsonDecoding
                        }
                    }
                    return (data, response)
                }
            } while redirected
            
            return (Data(), URLResponse())
            
        
        } catch LibreLinkUpError.notAuthenticated {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.notAuthenticated.localizedDescription)")
            throw LibreLinkUpError.notAuthenticated
        } catch LibreLinkUpError.lockedAccount {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.lockedAccount.localizedDescription)")
            throw LibreLinkUpError.lockedAccount
        } catch LibreLinkUpError.loggingIntoWrongRegionalServer {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.loggingIntoWrongRegionalServer.localizedDescription)")
            throw LibreLinkUpError.loggingIntoWrongRegionalServer
        } catch LibreLinkUpError.verifyEmail {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.verifyEmail.localizedDescription)")
            throw LibreLinkUpError.verifyEmail
        } catch LibreLinkUpError.touNotAccepted {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.touNotAccepted.localizedDescription)")
            throw LibreLinkUpError.touNotAccepted
        } catch LibreLinkUpError.ppNotAccepted {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.ppNotAccepted.localizedDescription)")
            throw LibreLinkUpError.ppNotAccepted
        } catch LibreLinkUpError.unknownStatus4 {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.unknownStatus4.localizedDescription)")
            throw LibreLinkUpError.unknownStatus4
        } catch LibreLinkUpError.jsonDecoding {
            Logger.libreLinkUp.error("LibreLinkUp: error while decoding response: \(LibreLinkUpError.jsonDecoding.localizedDescription)")
            DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
            throw LibreLinkUpError.jsonDecoding
        } catch {
            Logger.libreLinkUp.error("LibreLinkUp: server error: \(error.localizedDescription)")
            DebugMessageSingleton.shared.libreLinkUpOverlayError = error.localizedDescription
            let errorAsString = "\(error)"
            DebugMessageSingleton.shared.libreLinkUpResponseError = "Login" + errorAsString
            throw LibreLinkUpError.noConnectionLogin
        }
    }
    
    
    /// - Returns: (data, response, history, logbookData, logbookHistory, logbookAlarms)
    func getPatientGraph() async throws -> (Any, URLResponse, [LibreLinkUpGlucose], Any, [LibreLinkUpGlucose], [LibreLinkUpAlarm], SensorSettings, SensorType) {
        
        let patientId = SharedData.libreLinkUpPatientId
        let token = SharedData.libreLinkUpToken
        let accountId = SharedData.libreLinkUpUserId.SHA256
        
        var request = URLRequest(url: URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)/\(patientId)/graph")!)
        request.timeoutInterval = 20
        var authenticatedHeaders = headers
        authenticatedHeaders["Authorization"] = "Bearer \(token)"
        authenticatedHeaders["Account-Id"] = accountId
        for (header, value) in authenticatedHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        Logger.libreLinkUp.debug("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
        
        var history: [LibreLinkUpGlucose] = []
        var logbookData: Data = Data()
        var logbookHistory: [LibreLinkUpGlucose] = []
        var logbookAlarms: [LibreLinkUpAlarm] = []
        var sensorSettingsRead: SensorSettings = SensorSettings(uom: 1, targetLow: 70, targetHigh: 180, alarmLow: 80, alarmHigh: 300)
        var sensorType: SensorType = .unknown
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as! HTTPURLResponse).statusCode
            Logger.libreLinkUp.debug("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \(status)")
            responseData = "LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \(status)"
            
            if status == 401 {
                Logger.general.error("LibreLinkUp: error: Invalid auth session")
                SharedData.libreLinkUpToken = ""
                DebugMessageSingleton.shared.libreLinkUpResponseError = "getPatientGraph: HTTP 401 invalidAuthSession"
                throw LibreLinkUpError.invalidAuthSession
            }

            if status == 429 {
                Logger.general.error("LibreLinkUp: error: Too many requests")
                DebugMessageSingleton.shared.libreLinkUpResponseError = "getPatientGraph: 429 Too many requests"
                throw LibreLinkUpError.tooManyRequests
            }
            // LibreLinkUp: response data: {"status":4,"error":{"message":"followerNotConnectToPatient"}}, status: 200
            // and now
            // LibreLinkUp: response data: {"status":4,"error":{"message":"follower not connect to patient"}}, status: 200
            // LibreLinkUp: response data: {"message":"invalid or expired jwt"}, status: 401
            
            // TODO: status 401
            // LibreLinkUp: response data: {"status":401,"error":{"message":"invalid auth session"}}, status: 401
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? Int {
                
                if status != 0 {
                    DebugMessageSingleton.shared.libreLinkUpResponseError = "getPatientGraph: " + responseData
                } else {
                    DebugMessageSingleton.shared.libreLinkUpResponseError = "none"
                }

                if status == 401 {
                    Logger.general.error("LibreLinkUp: error: Invalid auth session")
                    SharedData.libreLinkUpToken = ""
                    DebugMessageSingleton.shared.libreLinkUpResponseError = "getPatientGraph: status 401 invalidAuthSession"
                    throw LibreLinkUpError.invalidAuthSession
                }

                if status == 911 {
                    Logger.general.error("LibreLinkUp: error: Server maintenance")
                    throw LibreLinkUpError.serverMaintenance
                }
                
                if status == 4 {
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        Logger.general.error("LibreLinkUp: error: \(message)")
                        if message == "followerNotConnectToPatient" || message == "follower not connect to patient" {
                            SharedData.libreLinkUpToken = ""
                            DebugMessageSingleton.shared.libreLinkUpResponseError = "getPatientGraph: status 4 followerNotConnectToPatient"
                            throw LibreLinkUpError.followerNotConnectToPatient
                        }
                    }
                }
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let connection = data["connection"] as? [String: Any],
                   let patientDevice = connection["patientDevice"] as? [String: Any]
                {
                    Logger.libreLinkUp.debug("LibreLinkUp: connection data: \(connection)")
                    let uom = connection["uom"] as? Int ?? 1 // test mmol units: let uom = 0
                    unit = (uom == 1) ? .mgdl : .mmoll
                    let unitString = "\(unit)"
                    Logger.libreLinkUp.debug("LibreLinkUp: measurement unit: \(unitString)")
                    
                    
                    let targetLow = connection["targetLow"] as? Int ?? 0
                    let targetHigh = connection["targetHigh"] as? Int ?? 0
                    
                    let alarmLow = patientDevice["ll"] as? Int ?? 0
                    let alarmHigh = patientDevice["hl"] as? Int ?? 0
                    
                    sensorSettingsRead = SensorSettings(uom: uom, targetLow: targetLow, targetHigh: targetHigh, alarmLow: alarmLow, alarmHigh: alarmHigh)
                    
                    var deviceSerials: [String: String] = [:]
                    var deviceActivationTimes: [String: Int] = [:]
                    var deviceTypes: [String: SensorType] = [:]
                    
                    if let activeSensors = data["activeSensors"] as? [[String: Any]]
                    {
                        Logger.libreLinkUp.debug("LibreLinkUp: active sensors: \(activeSensors)")
                        for (i, activeSensor) in activeSensors.enumerated() {
                            if let sensor = activeSensor["sensor"] as? [String: Any],
                               let device = activeSensor["device"] as? [String: Any],
                               let dtid = device["dtid"] as? Int,
                               let v = device["v"] as? String,
                               let alarms = device["alarms"] as? Bool,
                               let deviceId = sensor["deviceId"] as? String,
                               var sn = sensor["sn"] as? String,
                               let a = sensor["a"] as? Int,
                               // pruduct type should be 0: .libre1, 3: .libre2, 4: .libre3 but happening a Libre 1 with `pt` = 3...
                               let pt = sensor["pt"] as? Int 
                            {
                                 sensorType =
                                dtid == 40068 ? .libre3 :
                                dtid == 40067 ? .libre2 :
                                dtid == 40066 ? .libre1 : .unknown
                                
                                // FIXME:
                                // according to bundle.js, if `alarms` is true 40066 is also a .libre2
                                // but happening a Libre 1 with `alarms` = true...
                                if sensorType == .libre1 && alarms == true { sensorType = .libre2 }
                                deviceTypes[deviceId] = sensorType
                                if sn.count == 10 {
                                    switch sensorType {
                                    case .libre1: sn = "0" + sn
                                    case .libre2: sn = "3" + sn
                                    case .libre3: sn = String(sn.dropLast()) // trim final 0
                                    default: break
                                    }
                                }
                                deviceSerials[deviceId] = sn
                                if deviceActivationTimes[deviceId] == nil || deviceActivationTimes[deviceId]! > a {
                                    deviceActivationTimes[deviceId] = a
                                }
                                let activationDate = Date(timeIntervalSince1970: Double(a))
                                let sensorTypeString = "\(sensorType)"
                                Logger.libreLinkUp.debug("LibreLinkUp: active sensor # \(i + 1) of \(activeSensors.count): serial: \(sn), activation date: \(activationDate) (timestamp = \(a)), LibreLink version: \(v), device id: \(deviceId), product type: \(pt), sensor type: \(sensorTypeString), alarms: \(alarms)")
                            }
                        }
                    }
                    
                    let sensorTypes: [String: SensorType] = deviceTypes
                    if let patientDevice = connection["patientDevice"] as? [String: Any],
                       let patientSensor = connection["sensor"] as? [String: Any],
                       let deviceId = patientDevice["did"] as? String,
                       let dtid = patientDevice["dtid"] as? Int,
                       let alarms = patientDevice["alarms"] as? Bool,
                       var sn = patientSensor["sn"] as? String,
                       let a = patientSensor["a"] as? Int,
                       let pt = patientSensor["pt"] as? Int
                    {
                        // FIXME: pruduct type should be 0: .libre1, 3: .libre2, 4: .libre3 but happening a Libre 1 with `pt` = 3...
                        sensorType = sensorTypes[deviceId] ?? (
                            dtid == 40068 ? .libre3 :
                                dtid == 40067 ? .libre2 :
                                dtid == 40066 ? .libre1 : .unknown
                        )
                        // FIXME:
                        // according to bundle.js, if `alarms` is true 40066 is also a .libre2
                        // but happening a Libre 1 with `alarms` = true...
                        if sensorType == .libre1 && alarms == true { sensorType = .libre2 }
                        if sn.count == 10 {
                            switch sensorType {
                            case .libre1: sn = "0" + sn
                            case .libre2: sn = "3" + sn
                            case .libre3: sn = String(sn.dropLast()) // trim final 0
                            default: break
                            }
                        }
                        let serial = deviceSerials[deviceId] ?? sn
                        let activationTime = deviceActivationTimes[deviceId] ?? a
                        let activationDate = Date(timeIntervalSince1970: Double(activationTime))
                        
                        //                        DispatchQueue.main.async { [self] in
                        //                            if app.sensor == nil {
                        //                                app.sensor = sensorType == .libre3 ? Libre3(main: self.main) : sensorType == .libre2 ? Libre2(main: self.main) : Sensor(main: self.main)
                        //                                app.sensor.type = sensorType
                        //                                app.sensor.serial = serial
                        //                            } else {
                        //                                if app.sensor.serial.isEmpty {
                        //                                    app.sensor.serial = serial
                        //                                }
                        //                            }
                        //                        }
                        //                        let sensor = await main.app.sensor!
                        //                        if sensor.serial.hasSuffix(serial) || deviceTypes.count == 1 {
                        //                            DispatchQueue.main.async { [self] in
                        //                                sensor.activationTime = UInt32(activationTime)
                        //                                sensor.age = Int(Date().timeIntervalSince(activationDate)) / 60
                        //                                sensor.state = .active
                        //                                sensor.lastReadingDate = Date()
                        //                                if sensor.type == .libre3 {
                        //                                    sensor.serial = serial
                        //                                    sensor.maxLife = 20160
                        //                                    let receiverId = settings.libreLinkUpPatientId.fnv32Hash
                        //                                    (sensor as! Libre3).receiverId = receiverId
                        //                                    log("LibreLinkUp: LibreView receiver ID: \(receiverId)")
                        //                                }
                        //                                main.status("\(sensor.type)  +  LLU")
                        //                            }
                        //                        }
                        Logger.libreLinkUp.debug("LibreLinkUp: sensor serial: \(serial), activation date: \(activationDate) (timestamp = \(activationTime)), device id: \(deviceId),  product type: \(pt), sensor type: \(sensorType), alarms: \(alarms)")
                        
                        if let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                           let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                           let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData)
                        {
                            guard let date = Self.parseMeasurementDate(factoryTimestamp: measurement.factoryTimestamp, timestamp: measurement.timestamp) else {
                                Logger.libreLinkUp.error("LibreLinkUp: could not parse latest glucose timestamp. FactoryTimestamp: \(measurement.factoryTimestamp, privacy: .public), Timestamp: \(measurement.timestamp, privacy: .public)")
                                throw LibreLinkUpError.jsonDecoding
                            }
                            let lifeCount = Int(round(date.timeIntervalSince(activationDate) / 60))
                            let lastGlucose = LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: lifeCount, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow)
                            
                            let measurementString = "\(measurement)"
                            Logger.libreLinkUp.debug("LibreLinkUp: last glucose measurement: \(measurementString) (JSON: \(lastGlucoseMeasurement))")
                            //TODO: ("Do something with trend arrow")
                            //                            if lastGlucose.trendArrow != nil {
                            //                                DispatchQueue.main.async { [self] in
                            //                                    PhoneAppHomeView(trendArrow: TrendArrow = lastGlucose.trendArrow)!
                            //                                }
                            //                            }
                            // TODO: scrape historic data only when the 17-minute delay has passed
                            var i = 0
                            
                            if let graphData = data["graphData"] as? [[String: Any]]
                            {
                                for glucoseMeasurement in graphData {
                                    if let measurementData = try? JSONSerialization.data(withJSONObject: glucoseMeasurement),
                                       let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData) {
                                        i += 1
                                        guard let date = Self.parseMeasurementDate(factoryTimestamp: measurement.factoryTimestamp, timestamp: measurement.timestamp) else {
                                            Logger.libreLinkUp.error("LibreLinkUp: skipping graph value with unparsable timestamp. FactoryTimestamp: \(measurement.factoryTimestamp, privacy: .public), Timestamp: \(measurement.timestamp, privacy: .public)")
                                            continue
                                        }
                                        var lifeCount = Int(date.timeIntervalSince(activationDate)) / 60
                                        // FIXME: lifeCount not always multiple of 5
                                        if lifeCount % 5 == 1 { lifeCount -= 1 }
                                        history.append(LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: lifeCount, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow))
                                        let measurementString = "\(measurement)"
                                        Logger.libreLinkUp.debug("LibreLinkUp: graph measurement # \(i) of \(graphData.count): \(measurementString) (JSON: \(glucoseMeasurement)), lifeCount = \(lifeCount)")
                                    }
                                }
                            }
                            
                            history.append(lastGlucose)
                            Logger.libreLinkUp.debug("LibreLinkUp: graph values: \(history.map { ($0.glucose.id, $0.glucose.value, $0.glucose.date.shortDateTime, $0.color) })")
                            
                            // TODO: https://api-eu.libreview.io/glucoseHistory?from=1700092800&numPeriods=5&period=14
                            //                            if settings.userLevel >= .test {
                            //                                let period = 15
                            //                                let numPeriods = 2
                            //                                if let ticketDict = json["ticket"] as? [String: Any],
                            //                                   let token = ticketDict["token"] as? String {
                            //                                    Logger.libreLinkUp.info("LibreView: new token for glucoseHistory: \(token)")
                            //                                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            //                                    request.setValue(settings.libreLinkUpUserId.SHA256, forHTTPHeaderField: "Account-Id")
                            //                                    request.url = URL(string: "https://api.libreview.io/glucoseHistory?numPeriods=\(numPeriods)&period=\(period)")!
                            //                                    Logger.libreLinkUp.info("LibreView: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
                            //                                    let (data, response) = try await URLSession.shared.data(for: request)
                            //                                    Logger.libreLinkUp.info("LibreView: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
                            //                                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                            //                                       // let status = json["status"] as? Int,
                            //                                       let data = json["data"] as? [String: Any] {
                            //                                        let lastUpload = data["lastUpload"] as! Int
                            //                                        let lastUploadDate = Date(timeIntervalSince1970: Double(lastUpload))
                            //                                        let lastUploadCGM = data["lastUploadCGM"] as! Int
                            //                                        let lastUploadCGMDate = Date(timeIntervalSince1970: Double(lastUploadCGM))
                            //                                        let lastUploadPro = data["lastUploadPro"] as! Int
                            //                                        let lastUploadProDate = Date(timeIntervalSince1970: Double(lastUploadPro))
                            //                                        let reminderSent = data["reminderSent"] as! Bool
                            //                                        let devices = data["devices"] as! [Int]
                            //                                        let periods = data["periods"] as! [[String: Any]]
                            //                                        Logger.libreLinkUp.info("LibreView: last upload date: \(lastUploadDate.local), last upload CGM date: \(lastUploadCGMDate.local), last upload pro date: \(lastUploadProDate.local), reminder sent: \(reminderSent), devices: \(devices), periods: \(periods.count)")
                            //                                        var i = 0
                            //                                        for period in periods {
                            //                                            let dateEnd = period["dateEnd"] as! Int
                            //                                            let endDate = Date(timeIntervalSince1970: Double(dateEnd))
                            //                                            let dateStart = period["dateStart"] as! Int
                            //                                            let startDate = Date(timeIntervalSince1970: Double(dateStart))
                            //                                            let daysOfData = period["daysOfData"] as! Int
                            //                                            let data = period["data"] as! [String: Any]
                            //                                            let blocks = data["blocks"] as! [[[String: Any]]]
                            //                                            i += 1
                            //                                            Logger.libreLinkUp.info("LibreView: period # \(i) of \(periods.count), start date: \(startDate.local), end date: \(endDate.local), days of data: \(daysOfData)")
                            //                                            var j = 0
                            //                                            for block in blocks {
                            //                                                j += 1
                            //                                                Logger.libreLinkUp.info("LibreView: block # \(j) of period # \(i): \(block.count) percentiles times: \(block.map { $0["time"] as! Int })")
                            //                                            }
                            //                                        }
                            //                                    }
                            //                                }
                            //                            }
                            
                            //TODO: Dead code. Remove in the future.
                            if SharedData.libreLinkUpScrapingLogbook, // currently this block is not used
                               let ticketDict = json["ticket"] as? [String: Any],
                               let token = ticketDict["token"] as? String {
                                Logger.libreLinkUp.debug("LibreLinkUp: new token for logbook: \(token)")
                                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                                request.setValue(accountId, forHTTPHeaderField: "Account-Id")
                                request.url = URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)/\(patientId)/logbook")!
                                Logger.libreLinkUp.debug("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
                                let (data, response) = try await URLSession.shared.data(for: request)
                                Logger.libreLinkUp.debug("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
                                logbookData = data
                                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let data = json["data"] as? [[String: Any]] {
                                    for entry in data {
                                        let type = entry["type"] as! Int
                                        
                                        // TODO: type 3 has also an alarmType: 0 = fixedLow, 1 = low, 2 = high
                                        
                                        if type == 1 || type == 3 {  // measurement
                                            if let measurementData = try? JSONSerialization.data(withJSONObject: entry),
                                               let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData) {
                                                i += 1
                                                guard let date = Self.parseMeasurementDate(factoryTimestamp: measurement.factoryTimestamp, timestamp: measurement.timestamp) else {
                                                    Logger.libreLinkUp.error("LibreLinkUp: skipping logbook value with unparsable timestamp. FactoryTimestamp: \(measurement.factoryTimestamp, privacy: .public), Timestamp: \(measurement.timestamp, privacy: .public)")
                                                    continue
                                                }
                                                logbookHistory.append(LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: i, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow))
                                                let measurementString = "\(measurement)"
                                                Logger.libreLinkUp.debug("LibreLinkUp: logbook measurement # \(i - history.count) of \(data.count): \(measurementString) (JSON: \(entry))")
                                            }
                                            
                                        } else if type == 2 {  // alarm
                                            if let alarmData = try? JSONSerialization.data(withJSONObject: entry),
                                               var alarm = try? JSONDecoder().decode(LibreLinkUpAlarm.self, from: alarmData) {
                                                guard let date = Self.parseMeasurementDate(factoryTimestamp: alarm.factoryTimestamp, timestamp: alarm.timestamp) else {
                                                    Logger.libreLinkUp.error("LibreLinkUp: skipping alarm with unparsable timestamp. FactoryTimestamp: \(alarm.factoryTimestamp, privacy: .public), Timestamp: \(alarm.timestamp, privacy: .public)")
                                                    continue
                                                }
                                                alarm.date = date
                                                logbookAlarms.append(alarm)
                                                Logger.libreLinkUp.debug("LibreLinkUp: logbook alarm: \(alarm) (JSON: \(entry))")
                                            }
                                        }
                                    }
                                    // TODO: merge with history and display trend arrow
                                    Logger.libreLinkUp.debug("LibreLinkUp: logbook values: \(logbookHistory.map { ($0.glucose.id, $0.glucose.value, $0.glucose.date.shortDateTime, $0.color, $0.trendArrow!.symbol) }), alarms: \(logbookAlarms.map(\.description))")
                                }
                            }
                        }
                    }
                }
                return (data, response, history, logbookData, logbookHistory, logbookAlarms, sensorSettingsRead, sensorType)
            }  catch {
                Logger.libreLinkUp.error("LibreLinkUp: error while decoding response: \(error.localizedDescription)")
                let errorAsString = "\(error)"
                DebugMessageSingleton.shared.libreLinkUpResponseError = "getPatientGraph" + errorAsString
                DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
                throw LibreLinkUpError.jsonDecoding
            }
        } catch LibreLinkUpError.followerNotConnectToPatient {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.followerNotConnectToPatient.localizedDescription)")
            DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
            throw LibreLinkUpError.followerNotConnectToPatient
        } catch LibreLinkUpError.invalidAuthSession {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.invalidAuthSession.localizedDescription)")
            DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
            throw LibreLinkUpError.invalidAuthSession
        } catch LibreLinkUpError.tooManyRequests {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.tooManyRequests.localizedDescription)")
            DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
            throw LibreLinkUpError.tooManyRequests
        } catch LibreLinkUpError.serverMaintenance {
            Logger.libreLinkUp.error("LibreLinkUp: error: \(LibreLinkUpError.serverMaintenance.localizedDescription)")
            DebugMessageSingleton.shared.libreLinkUpOverlayError = ""
            throw LibreLinkUpError.serverMaintenance
        } catch {
            Logger.libreLinkUp.error("LibreLinkUp: server error: \(error.localizedDescription)")
            DebugMessageSingleton.shared.libreLinkUpOverlayError = error.localizedDescription
            let errorAsString = "\(error)"
            DebugMessageSingleton.shared.libreLinkUpResponseError = "getPatientGraph" + errorAsString
            if isNetworkError(error) {
                throw LibreLinkUpError.noConnectionGraph
            } else {
                throw LibreLinkUpError.unknownErrorGraph
            }
        }
    }
    
    func getLastGlucoseDataZZZ() async throws {
        Logger.libreLinkUp.info("LibreLinkUp: getting last glucose data")
        var request = URLRequest(url: URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)")!)
        var authenticatedHeaders = headers
        authenticatedHeaders["Authorization"] = "Bearer \(SharedData.libreLinkUpToken)"
        authenticatedHeaders["Account-Id"] = SharedData.libreLinkUpUserId.SHA256
        for (header, value) in authenticatedHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        Logger.libreLinkUp.info("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
        let (data, response) = try await URLSession.shared.data(for: request)
        Logger.libreLinkUp.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let data = json["data"] as? [[String: Any]] {
            if data.count > 0 {
                let connection = data[0]
                if let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                   let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                   let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData),
                   let date = Self.parseMeasurementDate(factoryTimestamp: measurement.factoryTimestamp, timestamp: measurement.timestamp) {
                    let lifeCount = 0 // Int(round(date.timeIntervalSince(activationDate) / 60))
                    let lastGlucose = LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: lifeCount, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow)
                    
                    let measurementString = "\(measurement)"
                    Logger.libreLinkUp.info("LibreLinkUp: last glucose measurement: \(measurementString) (JSON: \(lastGlucoseMeasurement))")
                    //                DispatchQueue.main.async { [self] in
                    //                    settings.libreLinkUpPatientId = patientId
                    //                }
                }
            }
        }
    }
    
    func getLastGlucoseDataXXX(completion: @escaping (LibreLinkUpLastGlucoseEntry?, Any?) -> ()) {
        if !(SharedData.libreLinkUpUserId.isEmpty ||
             SharedData.libreLinkUpToken.isEmpty) {
            var request = URLRequest(url: URL(string: "\(regionalSiteURL)/llu/connections")!)
            request.timeoutInterval = 15
            request.httpMethod = "GET"
            print("\(request)")
            let headers = LLUHeaders().headers
            var authenticatedHeaders = headers
            authenticatedHeaders["Authorization"] = "Bearer \(SharedData.libreLinkUpToken)"
            authenticatedHeaders["Account-Id"] = SharedData.libreLinkUpUserId.SHA256
            for (header, value) in authenticatedHeaders {
                request.setValue(value, forHTTPHeaderField: header)
            }
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let data = data {
                    do {
                        
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let data = json["data"] as? [[String: Any]] {
                            if data.count > 0 {
                                let connection = data[0]
                                if let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                                   let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                                   let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData),
                                   let date = Self.parseMeasurementDate(factoryTimestamp: measurement.factoryTimestamp, timestamp: measurement.timestamp) {
                                    let currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                                    let glucoseMeasurementEntry = LibreLinkUpLastGlucoseEntry(date: date, glucoseMeasurement: measurement, currentIOB: currentIOB)
                                    let lifeCount = 0 // Int(round(date.timeIntervalSince(activationDate) / 60))
//                                    let lastGlucose = LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: lifeCount, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow)
//
//                                    let measurementString = "\(measurement)"
                                    completion(glucoseMeasurementEntry, nil)
                                }
                            }
                        } else {
                            completion(nil, "No glucose item found in response.")
                        }
                    } catch {
                        completion(nil, error)
                    }
                } else if let error = error {
                    completion(nil, error)
                }
            }
            .resume()
        }
    }
    
    func getLastGlucoseData() async throws -> LibreLinkUpLastGlucoseEntry { // for AppIntent
        if !(SharedData.libreLinkUpUserId.isEmpty ||
             SharedData.libreLinkUpToken.isEmpty) {
            var request = URLRequest(url: URL(string: "\(regionalSiteURL)/llu/connections")!)
            request.timeoutInterval = 15
            request.httpMethod = "GET"
            print("\(request)")
            let headers = LLUHeaders().headers
            var authenticatedHeaders = headers
            authenticatedHeaders["Authorization"] = "Bearer \(SharedData.libreLinkUpToken)"
            authenticatedHeaders["Account-Id"] = SharedData.libreLinkUpUserId.SHA256
            for (header, value) in authenticatedHeaders {
                request.setValue(value, forHTTPHeaderField: header)
            }
            Logger.libreLinkUp.info("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
            let (data, response) = try await URLSession.shared.data(for: request)
            Logger.libreLinkUp.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
                        
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let data = json["data"] as? [[String: Any]] {
                            if data.count > 0 {
                                let connection = data[0]
                                if let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                                   let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                                   let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData),
                                   let date = Self.parseMeasurementDate(factoryTimestamp: measurement.factoryTimestamp, timestamp: measurement.timestamp) {
                                    let currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                                    let glucoseMeasurementEntry = LibreLinkUpLastGlucoseEntry(date: date, glucoseMeasurement: measurement, currentIOB: currentIOB)
                                    return glucoseMeasurementEntry
                                }
                            }
                        
                    
                
            }
        }
        return LibreLinkUpLastGlucoseEntry(date: Date(), glucoseMeasurement: GlucoseMeasurement(factoryTimestamp: "", timestamp: "", type: 0, alarmType: 3, valueInMgPerDl: 0, trendArrow: .stable, trendMessage: "", measurementColor: .green, glucoseUnits: 1, value: 0, isHigh: false, isLow: false), currentIOB: 0.0)
    }
}
