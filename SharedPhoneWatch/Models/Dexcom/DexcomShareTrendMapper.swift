//
//  DexcomShareTrendMapper.swift
//  LibreWrist
//
//  Created by Peter Müller on 07.05.26.
//
//  Pure mapping helpers from Dexcom Share types to FLwatch's existing
//  TrendArrow / MeasurementColor / Glucose representations.
//

import Foundation

enum DexcomShareTrendMapper {

    // MARK: - Trend arrow

    /// Share has 7 active trend levels; FLwatch has 5. Doubles map to the
    /// "quickly" variants, singles and forty-fives both collapse to the
    /// non-quick rising/falling. Non-computable / out-of-range become `.notDetermined`.
    static func arrow(for trend: ShareTrend) -> TrendArrow {
        switch trend {
        case .doubleUp:                          return .risingQuickly
        case .singleUp, .fortyFiveUp:            return .rising
        case .flat:                              return .stable
        case .singleDown, .fortyFiveDown:        return .falling
        case .doubleDown:                        return .fallingQuickly
        case .notComputable, .rateOutOfRange:    return .notDetermined
        }
    }

    // MARK: - Color classification
    //
    // LibreLinkUp gets a pre-computed color from the server. Share doesn't, so
    // we classify against the user's SensorSettings here. The bands are:
    //
    //   value < alarmLow          → red
    //   value > alarmHigh         → red
    //   value < targetLow         → yellow (low warning, between alarm and target)
    //   value > targetHigh        → yellow (high warning)
    //   targetLow ≤ value ≤ targetHigh → green
    //
    // If alarmLow > targetLow (allowed by SensorSettings — that's actually the
    // current default), the low warning band is empty: anything below targetLow
    // is already caught by the alarmLow check and returns red.

    static func color(for valueMgDl: Int, settings: SensorSettings) -> MeasurementColor {
        if valueMgDl < settings.alarmLow  { return .red }
        if valueMgDl > settings.alarmHigh { return .red }
        if valueMgDl < settings.targetLow  { return .yellow }
        if valueMgDl > settings.targetHigh { return .yellow }
        return .green
    }

    // MARK: - Trend rate inference
    //
    // Share doesn't return a numeric trend rate. We approximate it as
    // (value_curr - value_prev) / minutes_between_readings.

    static func trendRate(latest: ShareGlucoseEntry, previous: ShareGlucoseEntry?) -> Double {
        guard let previous else { return 0 }
        let intervalSeconds = latest.wallTime.timeIntervalSince(previous.wallTime)
        guard intervalSeconds > 0 else { return 0 }
        let delta = Double(latest.value - previous.value)
        return delta / (intervalSeconds / 60.0)
    }

    // MARK: - Glucose construction
    //
    // Builds a LibreLinkUpGlucose (the canonical wrapper used everywhere in FLwatch)
    // from a Share entry plus its predecessor (for trend-rate calculation).
    //
    // `id` is derived from epoch-minutes so values stay monotonic even across
    // app restarts and persist sensibly into LibreLinkUpHistory's id-keyed logic.

    static func makeGlucose(
        entry: ShareGlucoseEntry,
        previous: ShareGlucoseEntry?,
        settings: SensorSettings
    ) -> LibreLinkUpGlucose {
        let id = Int(entry.wallTime.timeIntervalSince1970 / 60.0)
        let arrow = self.arrow(for: entry.trend)
        let rate = self.trendRate(latest: entry, previous: previous)
        let glucose = Glucose(
            entry.value,
            temperature: 0,
            trendRate: rate,
            trendArrow: arrow,
            id: id,
            date: entry.wallTime,
            source: "Dexcom"
        )
        return LibreLinkUpGlucose(
            glucose: glucose,
            color: self.color(for: entry.value, settings: settings),
            trendArrow: arrow
        )
    }
}
