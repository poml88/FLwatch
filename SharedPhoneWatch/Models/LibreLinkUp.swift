//
//  LibreLinkUp.swift
//  LibreWrist
//
//  Created by Peter Müller on 24.08.24.
//

import Foundation
import OSLog
import SwiftUI
import SecureDefaults

// https://github.com/timoschlueter/nightscout-librelink-up
// https://gist.github.com/khskekec/6c13ba01b10d3018d816706a32ae8ab2



class LibreLinkUp  {
    //    class LibreLinkUp: Logging {
    
    //    var main: MainDelegate!
    
    
    let siteURL = "https://api.libreview.io"
    let loginEndpoint = "llu/auth/login"
    let configEndpoint = "llu/config"
    let connectionsEndpoint = "llu/connections"
    let measurementsEndpoint = "lsl/api/measurements"
    
    let regions = ["ae", "ap", "au", "ca", "de", "eu", "eu2", "fr", "jp", "la", "us", "ru"]  // eu2: GB and IE
    
    let regionalSiteURLRU: String = "https://api.libreview.ru"
    var regionalSiteURL: String { settings.libreLinkUpRegion == "ru" ? regionalSiteURLRU : "https://api-\(settings.libreLinkUpRegion).libreview.io" }
        
    var unit: GlucoseUnit = .mgdl
    
    var libreLinkUpResponse: String = "[...]"
    //    var sensorSettings: SensorSettings = SensorSettings()
    
    let headers = LLUHeaders().headers
    
    
    
    
    
    
    //    init(main: MainDelegate) {
    //        self.main = main
    //    }
    //    init() {
    //        //settings = Settings()
    ////        print ("\(settings)")
    //    }
    
    func reloadLibreLinkUp() async {
        
        var dataString = ""
        var retries = 0
        
        
    loop: repeat {
        do {
            let token = settings.libreLinkUpToken
            if settings.libreLinkUpUserId.isEmpty ||
                settings.libreLinkUpToken.isEmpty ||
                settings.libreLinkUpTokenExpirationDate < Date() ||
                retries == 1 {
                do {
                    try await login()
                } catch {
                    libreLinkUpResponse = error.localizedDescription.capitalized
                }
            }
            if !(settings.libreLinkUpUserId.isEmpty ||
                 settings.libreLinkUpToken.isEmpty) {
                let (data, _, graphHistory, logbookData, logbookHistory, _, sensorSettingsRead, sensorType) = try await getPatientGraph()
                dataString = (data as! Data).string
                libreLinkUpResponse = dataString + (logbookData as! Data).string
                
                //                if libreLinkUpHistory.count == 0 {
                //                    libreLinkUpHistory = MockDataPhone
                //                }
                //                libreLinkUpLogbookHistory = logbookHistory
                
                
                
                //                try await LibreLinkUp().getLastGlucoseData()
                
                if graphHistory.count > 0 {
                    DispatchQueue.main.async { [self] in
                        settings.lastOnlineDate = Date()
                        SensorSettingsSingleton.shared.sensorSettings = sensorSettingsRead
                        SensorSettingsSingleton.shared.sensorType = sensorType
                        // TODO: just merge with newer values
                        if graphHistory.count > 1 {                                                                                 // make sure that [0] exists, must be 2 to drop 1.
                            LibreLinkUpHistory.shared.libreLinkUpGlucose = graphHistory.reversed().dropLast(graphHistory.count / 2) // deviding by two reduces graph to 6 hours.
                        } else {
                            LibreLinkUpHistory.shared.libreLinkUpGlucose = graphHistory                                             // is only 1 value
                        }
                        let lastMeasurement = LibreLinkUpHistory.shared.libreLinkUpGlucose[0]
                        LibreLinkUpHistory.shared.lastReadingDate = lastMeasurement.glucose.date
                        //                        minutesSinceLastReading = Int(Date().timeIntervalSince(lastReadingDate) / 60)
                        //                        sensor?.lastReadingDate = lastReadingDate
                        LibreLinkUpHistory.shared.currentGlucose = lastMeasurement.glucose.value
                        LibreLinkUpHistory.shared.currentTrendArrow = lastMeasurement.trendArrow?.symbol ?? "---"
                        // TODO: keep the raw values filling the gaps with -1 values
                        //                        history.rawValues = []
                        //                        history.factoryValues = libreLinkUpHistory.libreLinkUpGlucose.dropFirst().map(\.glucose) // TEST
                        var trend = LibreLinkUpHistory.shared.libreLinkUpMinuteGlucose
                        //                        Logger.general.info("LibreLinkUp: trend: \(trend)")
                        //                        let a: String = "\(lastMeasurement)"
                        //                        Logger.general.info("LibreLinkUp: lastMeasurement: \(a)")
                        
                        if trend.isEmpty || lastMeasurement.id > trend[0].id {
                            trend.insert(lastMeasurement, at: 0)
                        }
                        // keep only the latest 16 minutes considering the 17-minute latency of the historic values update. seems to vary between 21 and 17 minutes.
                        if LibreLinkUpHistory.shared.libreLinkUpGlucose.indices.contains(1) {
                            let lastGraphItem = LibreLinkUpHistory.shared.libreLinkUpGlucose[1].id
                            trend = trend.filter { $0.id > lastGraphItem }
                            trend = trend.filter { $0.id - lastGraphItem < 60 }
                        }
                        LibreLinkUpHistory.shared.libreLinkUpMinuteGlucose = trend
                        Logger.general.info("LibreLinkUp: libreLinkUpHistory.libreLinkUpMinuteGlucose: \(LibreLinkUpHistory.shared.libreLinkUpMinuteGlucose)")
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
            libreLinkUpResponse = error.localizedDescription.capitalized
        }
    } while retries == 1
        
    }
    
    
    
    @discardableResult
    func login() async throws -> (Any, URLResponse) {
        var request = URLRequest(url: URL(string: "\(siteURL)/\(loginEndpoint)")!)
        
        //        let appGroupID = UserDefaults.stringValue(forKey: "APP_GROUP_ID")
        let credentials = [
            //            "email": settings.libreLinkUpEmail,
            //            "password": settings.libreLinkUpPassword
            "email": UserDefaults.group.username,
            "password": SecureDefaults.sgroup.string(forKey: "llu.password")
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
        loop: repeat {
            redirected = false
            Logger.general.info("LibreLinkUp: posting to \(request.url!.absoluteString) \(jsonData!.string), headers: \(self.headers)")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                Logger.general.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \(status)")
                if status == 401 {
                    Logger.general.info("LibreLinkUp: POST not authorized")
                } else {
                    Logger.general.info("LibreLinkUp: POST \((200..<300).contains(status) ? "success" : "error")")
                }
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? Int {
                    
                    let data = json["data"] as? [String: Any]
                    
                    if status == 2 || status == 429 || status == 911 {
                        // {"status":2,"error":{"message":"notAuthenticated"}}
                        // {"status":429,"data":{"code":60,"data":{"failures":3,"interval":60,"lockout":300},"message":"locked"}}
                        // {"status":911} when logging in at a stranger regional server
                        if let data, let message = data["message"] as? String {
                            if message == "locked" {
                                if let data = data["data"] as? [String: Any],
                                   let failures = data["failures"] as? Int,
                                   let interval = data["interval"] as? Int,
                                   let lockout = data["lockout"] as? Int {
                                    Logger.general.info("LibreLinkUp: login failures: \(failures), interval: \(interval) s, lockout: \(lockout) s")
#warning ("warn the user to wait 5 minutes before reattempting")
                                    // TODO: warn the user to wait 5 minutes before reattempting
                                }
                            }
                        }
                        throw LibreLinkUpError.notAuthenticated
                    }
                    
                    // TODO: status 4 requires accepting new Terms of Use: api.libreview.io/auth/continue/tou
                    if status == 4 {
                        Logger.general.info("LibreLinkUp: Terms of Use have been updated and must be accepted by running LibreLink (tip: log out and re-login)")
                        if let data,
                           let user = data["user"] as? [String: Any],
                           let country = user["country"] as? String,
                           let authTicketDict = data["authTicket"] as? [String: Any],
                           let authTicketData = try? JSONSerialization.data(withJSONObject: authTicketDict),
                           let authTicket = try? JSONDecoder().decode(AuthTicket.self, from: authTicketData) {
                            let authTicketString = "\(authTicket)"
                            Logger.general.info("LibreLinkUp: ToU: authTicket: \(authTicketString), expires on \(Date(timeIntervalSince1970: Double(authTicket.expires)))")
                            //call accepttou
                            //loginResponse = try await tou(apiRegion: apiRegion, authToken: authToken)
                        }
                        throw LibreLinkUpError.touNotAccepted
                        
                        //                        LibreLinkUp: response data: {"status":4,"data":{"step":{"type":"tou","componentName":"AcceptDocument","props":{"reaccept":true,"titleKey":"Common.termsOfUse","type":"tou"}},"user":{"accountType":"pat","country":"DE","uiLanguage":"de-DE"},"authTicket":{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjJjMTFhMmNlLTY1MmYtMTFlZi1hOGY5LWU2NTlhODBiNTU2OSIsImZpcnN0TmFtZSI6IkxpYnJlICIsImxhc3ROYW1lIjoiV3Jpc3QiLCJjb3VudHJ5IjoiREUiLCJyZWdpb24iOiJkZSIsInJvbGUiOiJwYXRpZW50IiwiZW1haWwiOiJsaWJyZXdpZGdldEBjbWRsaW5lLm5ldCIsImMiOjEsInMiOiJsbHUuaW9zIiwiZXhwIjoxNzI3MzQyNTE4fQ._-kekmE1JEmpmdUUhpKTyqg15xwGXLSo3vh9wbTLVn8","expires":1727342518,"duration":3600000}}}, status: 200
                        //                        LibreLinkUp: POST success
                        //                        LibreLinkUp: Terms of Use have been updated and must be accepted by running LibreLink (tip: log out and re-login)
                        //                        LibreLinkUp: error: not authenticated
                    }
                    
                    // {"status":0,"data":{"redirect":true,"region":"fr"}}
                    if let redirect = data?["redirect"] as? Bool,
                       let region = data?["region"] as? String {
                        redirected = redirect
//                        DispatchQueue.main.async { [self] in
                            settings.libreLinkUpRegion = region
//                        }
                        Logger.general.info("LibreLinkUp: redirecting to \(self.regionalSiteURL)/\(self.loginEndpoint) ") // The very first time this will be "eu" instead of the "region" because UserDefaults has not been set.
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
                        Logger.general.info("LibreLinkUp: user id: \(id), country: \(country), authTicket: \(authTicketString), expires on \(Date(timeIntervalSince1970: Double(authTicket.expires)))")
                        DispatchQueue.main.async { [self] in
                            settings.libreLinkUpUserId = id
                            settings.libreLinkUpPatientId = id  // avoid scraping patientId when following ourselves
                            settings.libreLinkUpCountry = country
                            settings.libreLinkUpToken = authTicket.token
                            settings.libreLinkUpTokenExpirationDate = Date(timeIntervalSince1970: Double(authTicket.expires))
                        }
                        
                        if !country.isEmpty {
                            // default "de" and "fr" regional servers
                            let defaultRegion = regions.contains(country.lowercased()) ? country.lowercased() : settings.libreLinkUpRegion
                            var request = URLRequest(url: URL(string: "\(siteURL)/\(configEndpoint)/country?country=\(country)")!)
                            for (header, value) in headers {
                                request.setValue(value, forHTTPHeaderField: header)
                            }
                            Logger.general.info("LibreLinkUp: URL request: \(request.url!.absoluteString), headers: \(request.allHTTPHeaderFields!)")
                            let (data, response) = try await URLSession.shared.data(for: request)
                            Logger.general.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
                            do {
                                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let data = json["data"] as? [String: Any],
                                   let server = data["lslApi"] as? String {
                                    let regionIndex = server.firstIndex(of: "-")
                                    let region = regionIndex == nil ? defaultRegion : String(server[server.index(regionIndex!, offsetBy: 1) ..< server.firstIndex(of: ".")!])
                                    Logger.general.info("LibreLinkUp: regional server: \(server), saved default region: \(region)")
//                                    DispatchQueue.main.async { [self] in
                                        settings.libreLinkUpRegion = region
//                                    }
                                    //                                        if settings.userLevel >= .test {
                                    var countryCodes = [String]()
                                    if let countryList = data["CountryList"] as? [String: Any],
                                       let countries = countryList["countries"] as? [[String: Any]] {
                                        for country in countries {
                                            countryCodes.append(country["ValueMember"] as! String)
                                        }
                                        Logger.general.info("LibreLinkUp: country codes: \(countryCodes)")
                                    }
                                    //                                        }
                                }
                            } catch {
                                Logger.general.info("LibreLinkUp: error while decoding response: \(error.localizedDescription)")
                                throw LibreLinkUpError.jsonDecoding
                            }
                        }
                        
                        if settings.libreLinkUpFollowing {
                            Logger.general.info("LibreLinkUp: getting connections for follower user id: \(id)")
                            var request = URLRequest(url: URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)")!)
                            var authenticatedHeaders = headers
                            authenticatedHeaders["Authorization"] = "Bearer \(settings.libreLinkUpToken)"
                            authenticatedHeaders["Account-Id"] = settings.libreLinkUpUserId.SHA256
                            for (header, value) in authenticatedHeaders {
                                request.setValue(value, forHTTPHeaderField: header)
                            }
                            Logger.general.info("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
                            let (data, response) = try await URLSession.shared.data(for: request)
                            Logger.general.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let data = json["data"] as? [[String: Any]] {
                                if data.count > 0 {
                                    let connection = data[0]
                                    let patientId = connection["patientId"] as! String
                                    Logger.general.info("LibreLinkUp: first patient Id: \(patientId)")
                                    DispatchQueue.main.async { [self] in
                                        settings.libreLinkUpPatientId = patientId
                                    }
                                }
                            }
                        }
                        
                    }
                }
                return (data, response)
            }
        } while redirected
            
            return (Data(), URLResponse())
            
        } catch LibreLinkUpError.jsonDecoding {
            Logger.general.info("LibreLinkUp: error while decoding response: \(LibreLinkUpError.jsonDecoding.localizedDescription)")
            throw LibreLinkUpError.jsonDecoding
        } catch LibreLinkUpError.notAuthenticated {
            Logger.general.info("LibreLinkUp: error: \(LibreLinkUpError.notAuthenticated.localizedDescription)")
            throw LibreLinkUpError.notAuthenticated
        } catch LibreLinkUpError.touNotAccepted {
            Logger.general.info("LibreLinkUp: error: \(LibreLinkUpError.touNotAccepted.localizedDescription)")
            throw LibreLinkUpError.touNotAccepted
        } catch {
            Logger.general.info("LibreLinkUp: server error: \(error.localizedDescription)")
            throw LibreLinkUpError.noConnection
        }
    }
    
    
    /// - Returns: (data, response, history, logbookData, logbookHistory, logbookAlarms)
    func getPatientGraph() async throws -> (Any, URLResponse, [LibreLinkUpGlucose], Any, [LibreLinkUpGlucose], [LibreLinkUpAlarm], SensorSettings, SensorType) {
        var request = URLRequest(url: URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)/\(settings.libreLinkUpPatientId)/graph")!)
        var authenticatedHeaders = headers
        authenticatedHeaders["Authorization"] = "Bearer \(settings.libreLinkUpToken)"
        authenticatedHeaders["Account-Id"] = settings.libreLinkUpUserId.SHA256
        for (header, value) in authenticatedHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        Logger.general.info("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
        
        var history: [LibreLinkUpGlucose] = []
        var logbookData: Data = Data()
        var logbookHistory: [LibreLinkUpGlucose] = []
        var logbookAlarms: [LibreLinkUpAlarm] = []
        var sensorSettingsRead: SensorSettings = SensorSettings(uom: 1, targetLow: 70, targetHigh: 180, alarmLow: 80, alarmHigh: 300)
        var sensorType: SensorType = .unknown
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as! HTTPURLResponse).statusCode
            Logger.general.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \(status)")
            // TODO: {"status":911}: server maintenance
            // LibreLinkUp: response data: {"status":4,"error":{"message":"followerNotConnectToPatient"}}, status: 200
            // LibreLinkUp: response data: {"message":"invalid or expired jwt"}, status: 401
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let connection = data["connection"] as? [String: Any],
                   let patientDevice = connection["patientDevice"] as? [String: Any]
                {
                    Logger.general.info("LibreLinkUp: connection data: \(connection)")
                    unit = connection["uom"] as? Int ?? 1 == 1 ? .mgdl : .mmoll
                    let unitString = "\(unit)"
                    Logger.general.info("LibreLinkUp: measurement unit: \(unitString)")
                    
                    let uom = connection["uom"] as? Int ?? 1
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
                        Logger.general.info("LibreLinkUp: active sensors: \(activeSensors)")
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
                                Logger.general.info("LibreLinkUp: active sensor # \(i + 1) of \(activeSensors.count): serial: \(sn), activation date: \(activationDate) (timestamp = \(a)), LibreLink version: \(v), device id: \(deviceId), product type: \(pt), sensor type: \(sensorTypeString), alarms: \(alarms)")
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
                        Logger.general.info("LibreLinkUp: sensor serial: \(serial), activation date: \(activationDate) (timestamp = \(activationTime)), device id: \(deviceId),  product type: \(pt), sensor type: \(sensorType), alarms: \(alarms)")
                        
                        if let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                           let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                           let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData)
                        {
                            let date = dateFormatter.date(from: measurement.timestamp)!
                            let lifeCount = Int(round(date.timeIntervalSince(activationDate) / 60))
                            let lastGlucose = LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: lifeCount, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow)
                            
                            let measurementString = "\(measurement)"
                            Logger.general.info("LibreLinkUp: last glucose measurement: \(measurementString) (JSON: \(lastGlucoseMeasurement))")
#warning ("Do something with trend arrow")
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
                                        let date = dateFormatter.date(from: measurement.timestamp)!
                                        var lifeCount = Int(date.timeIntervalSince(activationDate)) / 60
                                        // FIXME: lifeCount not always multiple of 5
                                        if lifeCount % 5 == 1 { lifeCount -= 1 }
                                        history.append(LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: lifeCount, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow))
                                        let measurementString = "\(measurement)"
                                        Logger.general.info("LibreLinkUp: graph measurement # \(i) of \(graphData.count): \(measurementString) (JSON: \(glucoseMeasurement)), lifeCount = \(lifeCount)")
                                    }
                                }
                            }
                            
                            history.append(lastGlucose)
                            Logger.general.info("LibreLinkUp: graph values: \(history.map { ($0.glucose.id, $0.glucose.value, $0.glucose.date.shortDateTime, $0.color) })")
                            
                            // TODO: https://api-eu.libreview.io/glucoseHistory?from=1700092800&numPeriods=5&period=14
                            //                            if settings.userLevel >= .test {
                            //                                let period = 15
                            //                                let numPeriods = 2
                            //                                if let ticketDict = json["ticket"] as? [String: Any],
                            //                                   let token = ticketDict["token"] as? String {
                            //                                    Logger.general.info("LibreView: new token for glucoseHistory: \(token)")
                            //                                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            //                                    request.setValue(settings.libreLinkUpUserId.SHA256, forHTTPHeaderField: "Account-Id")
                            //                                    request.url = URL(string: "https://api.libreview.io/glucoseHistory?numPeriods=\(numPeriods)&period=\(period)")!
                            //                                    Logger.general.info("LibreView: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
                            //                                    let (data, response) = try await URLSession.shared.data(for: request)
                            //                                    Logger.general.info("LibreView: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
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
                            //                                        Logger.general.info("LibreView: last upload date: \(lastUploadDate.local), last upload CGM date: \(lastUploadCGMDate.local), last upload pro date: \(lastUploadProDate.local), reminder sent: \(reminderSent), devices: \(devices), periods: \(periods.count)")
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
                            //                                            Logger.general.info("LibreView: period # \(i) of \(periods.count), start date: \(startDate.local), end date: \(endDate.local), days of data: \(daysOfData)")
                            //                                            var j = 0
                            //                                            for block in blocks {
                            //                                                j += 1
                            //                                                Logger.general.info("LibreView: block # \(j) of period # \(i): \(block.count) percentiles times: \(block.map { $0["time"] as! Int })")
                            //                                            }
                            //                                        }
                            //                                    }
                            //                                }
                            //                            }
                            
                            if settings.libreLinkUpScrapingLogbook, // currently this block is not used
                               let ticketDict = json["ticket"] as? [String: Any],
                               let token = ticketDict["token"] as? String {
                                Logger.general.info("LibreLinkUp: new token for logbook: \(token)")
                                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                                request.setValue(settings.libreLinkUpUserId.SHA256, forHTTPHeaderField: "Account-Id")
                                request.url = URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)/\(settings.libreLinkUpPatientId)/logbook")!
                                Logger.general.info("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
                                let (data, response) = try await URLSession.shared.data(for: request)
                                Logger.general.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
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
                                                let date = dateFormatter.date(from: measurement.timestamp)!
                                                logbookHistory.append(LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: i, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow))
                                                let measurementString = "\(measurement)"
                                                Logger.general.info("LibreLinkUp: logbook measurement # \(i - history.count) of \(data.count): \(measurementString) (JSON: \(entry))")
                                            }
                                            
                                        } else if type == 2 {  // alarm
                                            if let alarmData = try? JSONSerialization.data(withJSONObject: entry),
                                               var alarm = try? JSONDecoder().decode(LibreLinkUpAlarm.self, from: alarmData) {
                                                alarm.date = dateFormatter.date(from: alarm.timestamp)!
                                                logbookAlarms.append(alarm)
                                                Logger.general.info("LibreLinkUp: logbook alarm: \(alarm) (JSON: \(entry))")
                                            }
                                        }
                                    }
                                    // TODO: merge with history and display trend arrow
                                    Logger.general.info("LibreLinkUp: logbook values: \(logbookHistory.map { ($0.glucose.id, $0.glucose.value, $0.glucose.date.shortDateTime, $0.color, $0.trendArrow!.symbol) }), alarms: \(logbookAlarms.map(\.description))")
                                }
                            }
                        }
                    }
                }
                return (data, response, history, logbookData, logbookHistory, logbookAlarms, sensorSettingsRead, sensorType)
            } catch {
                Logger.general.info("LibreLinkUp: error while decoding response: \(error.localizedDescription)")
                throw LibreLinkUpError.jsonDecoding
            }
        } catch {
            Logger.general.info("LibreLinkUp: server error: \(error.localizedDescription)")
            throw LibreLinkUpError.noConnection
        }
    }
    
    func getLastGlucoseData() async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
        Logger.general.info("LibreLinkUp: getting last glucose data")
        var request = URLRequest(url: URL(string: "\(regionalSiteURL)/\(connectionsEndpoint)")!)
        var authenticatedHeaders = headers
        authenticatedHeaders["Authorization"] = "Bearer \(settings.libreLinkUpToken)"
        authenticatedHeaders["Account-Id"] = settings.libreLinkUpUserId.SHA256
        for (header, value) in authenticatedHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        Logger.general.info("LibreLinkUp: URL request: \(request.url!.absoluteString), authenticated headers: \(request.allHTTPHeaderFields!)")
        let (data, response) = try await URLSession.shared.data(for: request)
        Logger.general.info("LibreLinkUp: response data: \(data.string.trimmingCharacters(in: .newlines)), status: \((response as! HTTPURLResponse).statusCode)")
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let data = json["data"] as? [[String: Any]] {
            if data.count > 0 {
                let connection = data[0]
                if let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                   let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                   let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData) {
                    let date = dateFormatter.date(from: measurement.timestamp)!
                    let lifeCount = 0 // Int(round(date.timeIntervalSince(activationDate) / 60))
                    let lastGlucose = LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: lifeCount, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow)
                    
                    let measurementString = "\(measurement)"
                    Logger.general.info("LibreLinkUp: last glucose measurement: \(measurementString) (JSON: \(lastGlucoseMeasurement))")
                    //                DispatchQueue.main.async { [self] in
                    //                    settings.libreLinkUpPatientId = patientId
                    //                }
                }
            }
        }
        
    }
}
