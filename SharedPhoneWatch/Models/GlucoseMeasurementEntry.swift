//
//  GlucoseMeasurementEntry.swift
//  LibreWrist
//
//  Created by Peter Müller on 08.10.24.
//

import WidgetKit

struct GlucoseMeasurementEntry: TimelineEntry {
    let date: Date
    let glucoseMeasurement: GlucoseMeasurement
    let currentIOB: Double
    
    static let sampleEntry = GlucoseMeasurementEntry(date: Date(), glucoseMeasurement: GlucoseMeasurement(factoryTimestamp: "", timestamp: "", type: 0, alarmType: 3, valueInMgPerDl: 105, trendArrow: .stable, trendMessage: "", measurementColor: .green, glucoseUnits: 1, value: 105, isHigh: false, isLow: false), currentIOB: 0.1)
    
    static let invalidEntry = GlucoseMeasurementEntry(date: Date(), glucoseMeasurement: GlucoseMeasurement(factoryTimestamp: "", timestamp: "", type: 0, alarmType: 3, valueInMgPerDl: 0, trendArrow: .unknown, trendMessage: "", measurementColor: .gray, glucoseUnits: 1, value: 0, isHigh: false, isLow: false), currentIOB: -1)
    
    static func getLastGlucoseMeasurement(completion: @escaping (GlucoseMeasurementEntry?, Any?) -> ()) {
        
        var insulinDeliveryHistory: [InsulinDelivery] = UserDefaults.group.insulinDeliveryHistory ?? []
        var sumIOB: Double = 0
        for item in insulinDeliveryHistory {
            
                let IOB =   updateIOB(timeStamp: item.timeStamp) * item.insulinUnits
                sumIOB = sumIOB + IOB
            
        }
        let currentIOB = sumIOB
        
        
        if !(settings.libreLinkUpUserId.isEmpty ||
             settings.libreLinkUpToken.isEmpty) {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
            
            var request = URLRequest(url: URL(string: "https://api-\(settings.libreLinkUpRegion).libreview.io/llu/connections")!)
            request.timeoutInterval = 15
            request.httpMethod = "GET"
            print("\(request)")
            let headers = LLUHeaders().headers
            var authenticatedHeaders = headers
            authenticatedHeaders["Authorization"] = "Bearer \(settings.libreLinkUpToken)"
            authenticatedHeaders["Account-Id"] = settings.libreLinkUpUserId.SHA256
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
                                   let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData) {
                                    let date = dateFormatter.date(from: measurement.timestamp)!
                                    let glucoseMeasurementEntry = GlucoseMeasurementEntry(date: date, glucoseMeasurement: measurement, currentIOB: currentIOB)
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
    
    static func updateIOB(timeStamp time: Double) -> Double {
        let model = ExponentialInsulinModel(actionDuration: 270 * 60, peakActivityTime: 120 * 60, delay: 15 * 60)
        let result = model.percentEffectRemaining(at: Date().timeIntervalSince1970 - time)
        return result
    }
    
}

