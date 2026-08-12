//
//  Date.swift
//  LibreWrist
//
//  Created by Peter Müller on 14.08.24.
//

import Foundation

extension Date {

    /// The right-hand edge of a glucose chart's time window, rounded UP to the next
    /// full minute.
    ///
    /// Rounding keeps the value stable within a minute, so a redraw caused by
    /// anything else re-derives an identical x-domain, filter boundary and marker
    /// thresholds instead of shifting them by a fraction of a second. Holding it in
    /// view state also gives the chart an explicit once-a-minute reason to advance:
    /// the graph views no longer read the clock inside `body`, so without it they
    /// would sit still whenever no new reading arrived.
    ///
    /// Rounds up rather than down so the newest reading — which can be a few
    /// seconds old — stays inside the scale instead of being clipped at the edge.
    static func chartWindowEnd(from date: Date = Date()) -> Date {
        let minutes = date.timeIntervalSince1970 / 60
        return Date(timeIntervalSince1970: minutes.rounded(.up) * 60)
    }

    func adding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self)!
    }
    
    func toISOStringFromDate() -> String {
        return Date.isoDateFormatter.string(from: self).appending("Z")
    }
    
    
    private static var isoDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        return dateFormatter
    }()
    
    func toRounded(on amount: Int, _ component: Calendar.Component) -> Date {
        let cal = Calendar.current
        let value = cal.component(component, from: self)

        // Compute nearest multiple of amount:
        let roundedValue = Int(Double(value) / Double(amount)) * amount
        let newDate = cal.date(byAdding: component, value: roundedValue - value, to: self)!

        return newDate.floorAllComponents(before: component)
    }
    
    private func floorAllComponents(before component: Calendar.Component) -> Date {
        // All components to round ordered by length
        let components = [Calendar.Component.year, .month, .day, .hour, .minute, .second, .nanosecond]

        guard let index = components.firstIndex(of: component) else {
            return self
        }

        let cal = Calendar.current
        var date = self

        components.suffix(from: index + 1).forEach { roundComponent in
            let value = cal.component(roundComponent, from: date) * -1
            date = cal.date(byAdding: roundComponent, value: value, to: date)!
        }

        return date
    }
    
    func toLocalTime() -> String {
        return self.formatted(.dateTime.hour().minute())
    }
    
        
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: self)
    }
    var shortDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM-dd HH:mm"
        return formatter.string(from: self)
    }
    var dateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
    var local: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }

}
