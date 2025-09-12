//
//  GlucoseMeasurementEntry.swift
//  LibreWrist
//
//  Created by Peter Müller on 08.10.24.
//

import WidgetKit

struct GlucoseMeasurementIOBEntry: TimelineEntry {
    let date: Date
    let glucoseMeasurement: GlucoseMeasurement
    var currentIOB: Double
    
    static let sampleEntry = GlucoseMeasurementIOBEntry(date: Date(), glucoseMeasurement: GlucoseMeasurement(factoryTimestamp: "", timestamp: "", type: 0, alarmType: 3, valueInMgPerDl: 105, trendArrow: .stable, trendMessage: "", measurementColor: .green, glucoseUnits: 1, value: 105, isHigh: false, isLow: false), currentIOB: 0.1)
    
    static let invalidEntry = GlucoseMeasurementIOBEntry(date: Date(), glucoseMeasurement: GlucoseMeasurement(factoryTimestamp: "", timestamp: "", type: 0, alarmType: 3, valueInMgPerDl: 0, trendArrow: .unknown, trendMessage: "", measurementColor: .gray, glucoseUnits: 1, value: 0, isHigh: false, isLow: false), currentIOB: -1)
    
    
    static func getLastGlucoseMeasurement(timeout: TimeInterval = 10,
                                          completion: @escaping (GlucoseMeasurementIOBEntry?, Error?) -> Void) {
        //        let settings = Settings()
        // Early exit if settings missing – safe single completion path.
        guard !(SharedData.libreLinkUpUserId.isEmpty || SharedData.libreLinkUpToken.isEmpty) else {
            DispatchQueue.main.async {
                let err = NSError(domain: "MissingSettings", code: -5,
                                  userInfo: [NSLocalizedDescriptionKey: "Missing UserId or Token"])
                completion(nil, err)
            }
            return
        }
        
        let syncQueue = DispatchQueue(label: "widget.provider.fetch.lock")
        var finished = false
        func markFinished() -> Bool {
            return syncQueue.sync {
                if finished { return false }
                finished = true
                return true
            }
        }
        
        let timeoutErr = NSError(domain: "WidgetTimeout", code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: "Timeout fetching glucose"])
        let timeoutWork = DispatchWorkItem {
            // Important: check finished for the OUTER block
            guard markFinished() else { return }
            DispatchQueue.main.async {
                completion(nil, timeoutErr)
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
        
        // Build request
        let regionalSiteURLRU = "https://api.libreview.ru"
        let regionalSiteURLCN = "https://api-cn.myfreestyle.cn"
        let regionalSiteURL: String = {
            if SharedData.libreLinkUpRegion == "ru" { return regionalSiteURLRU }
            if SharedData.libreLinkUpRegion == "cn" { return regionalSiteURLCN }
            return "https://api-\(SharedData.libreLinkUpRegion).libreview.io"
        }()
        var request = URLRequest(url: URL(string: "\(regionalSiteURL)/llu/connections")!)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        var authenticatedHeaders = LLUHeaders().headers
        authenticatedHeaders["Authorization"] = "Bearer \(SharedData.libreLinkUpToken)"
        authenticatedHeaders["Account-Id"] = SharedData.libreLinkUpUserId.SHA256
        for (h, v) in authenticatedHeaders { request.setValue(v, forHTTPHeaderField: h) }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Early-return the OUTER closure if another path finished already
            guard markFinished() else { return }
            timeoutWork.cancel()
            
            DispatchQueue.main.async {
                if let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let dataArray = json["data"] as? [[String: Any]],
                           let connection = dataArray.first,
                           let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                           let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                           let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData) {
                            let df = DateFormatter()
                            df.locale = Locale(identifier: "en_US_POSIX")
                            df.dateFormat = "M/d/yyyy h:mm:ss a"
                            if let date = df.date(from: measurement.timestamp) {
                                InsulinDeliveryHistorySingleton.shared.read() // widget has to read the history from UserDefaults, as the singleton is only updated in the main app.
                                let currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                                let entry = GlucoseMeasurementIOBEntry(date: date,
                                                                       glucoseMeasurement: measurement,
                                                                       currentIOB: currentIOB)
                                completion(entry, nil)
                            } else {
                                let err = NSError(domain: "ParseError", code: -2,
                                                  userInfo: [NSLocalizedDescriptionKey: "Invalid timestamp"])
                                completion(nil, err)
                            }
                        } else {
                            let err = NSError(domain: "ResponseError", code: -3,
                                              userInfo: [NSLocalizedDescriptionKey: "No glucose item found in response."])
                            completion(nil, err)
                        }
                    } catch {
                        completion(nil, error)
                    }
                } else if let error = error {
                    completion(nil, error)
                } else {
                    let err = NSError(domain: "UnknownError", code: -4, userInfo: nil)
                    completion(nil, err)
                }
            }
        }.resume()
    }
    
    
//    static func updateIOB(timeStamp time: Double) -> Double {
//        let model = ExponentialInsulinModel(actionDuration: 270 * 60, peakActivityTime: 120 * 60, delay: 15 * 60)
//        let result = model.percentEffectRemaining(at: Date().timeIntervalSince1970 - time)
//        return result
//    }
    
}

