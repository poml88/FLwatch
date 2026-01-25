//
//  GraphGlucoseMeasurementIOBEntry.swift
//  FLwatch
//
//  Created by Peter Müller on 19.01.26.
//

import WidgetKit

struct GraphGlucoseMeasurementIOBEntry: TimelineEntry {
    let date: Date
    let lastGlucoseMeasurement: LibreLinkUpGlucose
    var graph: [LibreLinkUpGlucose]
    var currentIOB: Double
    let uom: Int
    let maxBG: Int
    
    static let sampleEntry = GraphGlucoseMeasurementIOBEntry(
        date: Date(),
        lastGlucoseMeasurement: LibreLinkUpGlucose(
            glucose: Glucose(105, id: 1, date: Date(), source: "Sample"),
            color: .green,
            trendArrow: .stable
        ),
        graph: [
            LibreLinkUpGlucose(glucose: Glucose(95, id: 0, date: Date().addingTimeInterval(-7200), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(97, id: 1, date: Date().addingTimeInterval(-6300), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(100, id: 2, date: Date().addingTimeInterval(-5400), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(102, id: 3, date: Date().addingTimeInterval(-4500), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(104, id: 4, date: Date().addingTimeInterval(-3600), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(106, id: 5, date: Date().addingTimeInterval(-2700), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(107, id: 6, date: Date().addingTimeInterval(-1800), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(108, id: 7, date: Date().addingTimeInterval(-900), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(115, id: 8, date: Date().addingTimeInterval(-500), source: "Sample"), color: .green, trendArrow: .stable),
            LibreLinkUpGlucose(glucose: Glucose(105, id: 9, date: Date(), source: "Sample"), color: .green, trendArrow: .stable)
        ],
        currentIOB: 0.1,
        uom: 1,
        maxBG: 250
    )
    
    
    static let invalidEntry = GraphGlucoseMeasurementIOBEntry(
        date: Date(),
        lastGlucoseMeasurement: LibreLinkUpGlucose(
            glucose: Glucose(0, id: 0, date: Date(), source: ""),
            color: .gray,
            trendArrow: .unknown
        ),
        graph: [LibreLinkUpGlucose(glucose: Glucose(0, id: 0, date: Date(), source: "Sample"), color: .green, trendArrow: .stable)
               ],
        currentIOB: -1,
        uom: 1,
        maxBG: 250
    )
    
    
    static func getPatientGraph(timeout: TimeInterval = 10,
                                completion: @escaping (GraphGlucoseMeasurementIOBEntry?, Error?) -> Void) {
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
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
        
        var graph: [LibreLinkUpGlucose] = []
        //        var lastGlucoseMeasurement1: GlucoseMeasurement
        
        let regionalSiteURLRU: String = "https://api.libreview.ru"
        let regionalSiteURLCN: String = "https://api-cn.myfreestyle.cn"
        var regionalSiteURL: String { SharedData.libreLinkUpRegion == "ru" ? regionalSiteURLRU : SharedData.libreLinkUpRegion == "cn" ? regionalSiteURLCN : "https://api-\(SharedData.libreLinkUpRegion).libreview.io" }
        
        
        var request = URLRequest(url: URL(string: "\(regionalSiteURL)/llu/connections/\(SharedData.libreLinkUpPatientId)/graph")!)
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
                           let data = json["data"] as? [String: Any],
                           let connection = data["connection"] as? [String: Any],
                           let patientDevice = connection["patientDevice"] as? [String: Any]
                        {
                            let uom = connection["uom"] as? Int ?? 1 // test mmol units: let uom = 0
                            if let lastGlucoseMeasurement = connection["glucoseMeasurement"] as? [String: Any],
                               let measurementData = try? JSONSerialization.data(withJSONObject: lastGlucoseMeasurement),
                               let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData),
                               let date = dateFormatter.date(from: measurement.timestamp)
                            {
                                
                                //                                let lifeCount = Int(round(date.timeIntervalSince(activationDate) / 60))
                                let lastGlucose = LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: 999, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow)
                                
                                //                                let measurementString = "\(measurement)"
                                //                                Logger.libreLinkUp.debug("LibreLinkUp: last glucose measurement: \(measurementString) (JSON: \(lastGlucoseMeasurement))")
                                
                                
                                var i = 0
                                
                                if let graphData = data["graphData"] as? [[String: Any]]
                                {
                                    for glucoseMeasurement in graphData {
                                        if let measurementData = try? JSONSerialization.data(withJSONObject: glucoseMeasurement),
                                           let measurement = try? JSONDecoder().decode(GlucoseMeasurement.self, from: measurementData) {
                                            i += 1
                                            let date = dateFormatter.date(from: measurement.timestamp)!
                                            //                                            var lifeCount = Int(date.timeIntervalSince(activationDate)) / 60
                                            // FIXME: lifeCount not always multiple of 5
                                            //                                            if lifeCount % 5 == 1 { lifeCount -= 1 }
                                            graph.append(LibreLinkUpGlucose(glucose: Glucose(measurement.valueInMgPerDl, id: i, date: date, source: "LibreLinkUp"), color: measurement.measurementColor, trendArrow: measurement.trendArrow))
                                            //                                            let measurementString = "\(measurement)"
                                            //                                            Logger.libreLinkUp.debug("LibreLinkUp: graph measurement # \(i) of \(graphData.count): \(measurementString) (JSON: \(glucoseMeasurement)), lifeCount = \(lifeCount)")
                                        }
                                    }
                                }
                                
                                let dateTwoHoursTenAgo: Date = Date(timeIntervalSinceNow: -2 * 60 * 60 - 10 * 60)
                                graph = graph.filter { $0.glucose.date > dateTwoHoursTenAgo } // delete everything older than 2 hours.
                                
                                graph.append(lastGlucose)
//                                if graph.count == 1 { graph.append(lastGlucose) }
                                
                                let indexOfMaxGlucoseItem = graph.indices.max(by:
                                                                                                                { graph[$0].glucose.value < graph[$1].glucose.value }
                                ) ?? 0 // Seems to work also with one value only, I guess because it is optional
                                let maxBG = { graph.count > 0 ? graph[indexOfMaxGlucoseItem].glucose.value : 250 }()
                                
                                InsulinDeliveryHistorySingleton.shared.read() // widget has to read the history from UserDefaults, as the singleton is only updated in the main app.
                                let currentIOB = CurrentIOBSingleton.shared.getCurrentIOB()
                                let entry = GraphGlucoseMeasurementIOBEntry(date: date,
                                                                            lastGlucoseMeasurement: lastGlucose,
                                                                            graph: graph,
                                                                            currentIOB: currentIOB,
                                                                            uom: uom,
                                                                            maxBG: maxBG)
//                           print("GRAPH: \(graph)")
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
}

