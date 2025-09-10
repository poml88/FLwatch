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
    
    
    static func getLastGlucoseMeasurement(timeout: TimeInterval = 3, completion: @escaping (GlucoseMeasurementIOBEntry?, Error?) -> Void) {
        // timeout could be 5-10 seconds.
        // Ensure completion is always called even if settings are missing
        guard !(settings.libreLinkUpUserId.isEmpty || settings.libreLinkUpToken.isEmpty) else {
            DispatchQueue.main.async {
                completion(GlucoseMeasurementIOBEntry.invalidEntry, nil)
            }
            return
        }

        let syncQueue = DispatchQueue(label: "widget.provider.fetch.lock")
        var finished = false

        let timeoutWork = DispatchWorkItem {
            syncQueue.sync {
                guard !finished else { return }
                finished = true
            }
            DispatchQueue.main.async {
                let err = NSError(domain: "WidgetTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout fetching glucose"])
                completion(GlucoseMeasurementIOBEntry.invalidEntry, err)
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        // Build request
        let regionalSiteURLRU: String = "https://api.libreview.ru"
        let regionalSiteURLCN: String = "https://api-cn.myfreestyle.cn"
        var regionalSiteURL: String { settings.libreLinkUpRegion == "ru" ? regionalSiteURLRU : settings.libreLinkUpRegion == "cn" ? regionalSiteURLCN : "https://api-\(settings.libreLinkUpRegion).libreview.io" }

        var request = URLRequest(url: URL(string: "\(regionalSiteURL)/llu/connections")!)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        var authenticatedHeaders = LLUHeaders().headers
        authenticatedHeaders["Authorization"] = "Bearer \(settings.libreLinkUpToken)"
        authenticatedHeaders["Account-Id"] = settings.libreLinkUpUserId.SHA256
        for (header, value) in authenticatedHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            // Ensure we only call completion once
            syncQueue.sync {
                guard !finished else { return }
                finished = true
            }
            timeoutWork.cancel()

            DispatchQueue.main.async {
                if let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let dataArray = json["data"] as? [[String: Any]],
                           dataArray.count > 0,
                           let connection = dataArray.first,
                           let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                           let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                           let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData) {

                            let dateFormatter = DateFormatter()
                            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                            dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"

                            if let date = dateFormatter.date(from: measurement.timestamp) {
                                let currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                                let glucoseMeasurementEntry = GlucoseMeasurementIOBEntry(date: date, glucoseMeasurement: measurement, currentIOB: currentIOB)
                                completion(glucoseMeasurementEntry, nil)
                                return
                            } else {
                                let err = NSError(domain: "ParseError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid timestamp"])
                                completion(GlucoseMeasurementIOBEntry.invalidEntry, err)
                                return
                            }
                        } else {
                            let err = NSError(domain: "ResponseError", code: -3, userInfo: [NSLocalizedDescriptionKey: "No glucose item found in response."])
                            completion(GlucoseMeasurementIOBEntry.invalidEntry, err)
                            return
                        }
                    } catch {
                        completion(GlucoseMeasurementIOBEntry.invalidEntry, error)
                        return
                    }
                } else if let error = error {
                    completion(GlucoseMeasurementIOBEntry.invalidEntry, error)
                } else {
                    let err = NSError(domain: "UnknownError", code: -4, userInfo: nil)
                    completion(GlucoseMeasurementIOBEntry.invalidEntry, err)
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

