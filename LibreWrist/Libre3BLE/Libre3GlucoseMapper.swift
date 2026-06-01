//
//  Libre3GlucoseMapper.swift
//  FLwatch
//
//  Pure mapping from LibreCRKit's decoded `RealtimeGlucoseReading` to FLwatch's
//  canonical `LibreLinkUpGlucose`, mirroring `DexcomShareTrendMapper`. This is
//  the BLE analogue of that mapper: it converts a push-decoded sensor reading
//  into the same model every downstream surface (home, watch, widgets) already
//  consumes via `LibreLinkUpHistory`.
//
//  iOS-only: references LibreCRKit types, which link to the phone target only.
//

#if os(iOS)
import Foundation
import LibreCRKit

enum Libre3GlucoseMapper {

    // MARK: - Trend arrow
    //
    // LibreCRKit's `Libre3Trend` has the five Libre levels (plus an
    // undetermined/raw escape). FLwatch's `TrendArrow` is a superset that also
    // models the two Dexcom "very quickly" extremes — Libre never produces
    // those, so the five real levels map straight across and anything
    // undetermined/unknown becomes `.notDetermined` (same as Dexcom's
    // non-computable).

    static func trendArrow(from trend: Libre3Trend) -> TrendArrow {
        switch trend {
        case .notDetermined:  return .notDetermined
        case .fallingQuickly: return .fallingQuickly
        case .falling:        return .falling
        case .stable:         return .stable
        case .rising:         return .rising
        case .risingQuickly:  return .risingQuickly
        case .raw:            return .notDetermined
        }
    }

    // MARK: - Color classification
    //
    // Like Dexcom Share (and unlike the LLU cloud path, which gets a server
    // color), the BLE path has no pre-computed color, so classify against the
    // user's target range — identical bands to `DexcomShareTrendMapper.color`.

    static func color(forMgDL value: Int, settings: SensorSettings) -> MeasurementColor {
        if value < settings.targetLow  { return .red }
        if value > settings.targetHigh { return .yellow }
        return .green
    }

    // MARK: - Glucose construction
    //
    // Returns `nil` when the current value isn't displayable (warm-up, sensor
    // error, or out of the 39–501 display range): `currentGlucoseMgDL` is the
    // already-normalized/clamped display value and is `nil` in those cases, so a
    // `nil` here means "don't surface this reading".
    //
    // `id` is the sensor `lifeCount` (minutes since activation) — monotonic and
    // stable across reconnects, so it keys cleanly into LibreLinkUpHistory's
    // id-based de-duplication. `date` is anchored to the sensor-start wall clock
    // (`sensorStartDate + lifeCount·60s`) so timestamps stay consistent across
    // reconnects (PLAN §8).

    static func makeGlucose(
        from reading: RealtimeGlucoseReading,
        sensorStartDate: Date,
        settings: SensorSettings
    ) -> LibreLinkUpGlucose? {
        guard let mgDL = reading.currentGlucoseMgDL else { return nil }
        let value = Int(mgDL)
        let date = sensorStartDate.addingTimeInterval(Double(reading.lifeCount) * 60)
        let arrow = trendArrow(from: reading.trendKind)
        let rate = Double(reading.rateOfChangeMgDLPerMinute ?? 0)
        let glucose = Glucose(
            value,
            temperature: 0,
            trendRate: rate,
            trendArrow: arrow,
            id: Int(reading.lifeCount),
            date: date,
            source: "Libre3 BLE"
        )
        return LibreLinkUpGlucose(
            glucose: glucose,
            color: color(forMgDL: value, settings: settings),
            trendArrow: arrow
        )
    }
}
#endif
