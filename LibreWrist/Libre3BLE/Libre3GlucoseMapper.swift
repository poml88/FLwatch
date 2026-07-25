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

    /// Realtime frames normally represent the sensor's current value, so their
    /// BLE receipt time is the most accurate available wall-clock timestamp.
    /// Retain the lifetime-derived timestamp when the two disagree materially,
    /// which defensively preserves an unexpectedly old realtime value.
    private static let realtimeReceiptTolerance: TimeInterval = 3 * 60

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
    // id-based de-duplication. A normal realtime value uses its BLE receipt time;
    // if that differs from `sensorStartDate + lifeCount·60s` by more than three
    // minutes, retain the lifetime-derived timestamp as a defensive fallback.

    static func makeGlucose(
        from reading: RealtimeGlucoseReading,
        sensorStartDate: Date,
        receivedAt: Date,
        settings: SensorSettings,
        calibrationOffsetMgDL: Int = 0
    ) -> LibreLinkUpGlucose? {
        guard let mgDL = reading.currentGlucoseMgDL else { return nil }

        let rawValueMgDL = Int(mgDL)
        let value = calibratedValue(
            rawValueMgDL: rawValueMgDL,
            offsetMgDL: calibrationOffsetMgDL
        )

        let lifetimeDerivedDate = sensorStartDate.addingTimeInterval(
            Double(reading.lifeCount) * 60
        )
        let date = abs(receivedAt.timeIntervalSince(lifetimeDerivedDate)) <= Self.realtimeReceiptTolerance
            ? receivedAt
            : lifetimeDerivedDate
        
        let arrow = trendArrow(from: reading.trendKind)
        let rate = Double(reading.rateOfChangeMgDLPerMinute ?? 0)
        var glucose = Glucose(
            rawValueMgDL,
            temperature: 0,
            trendRate: rate,
            trendArrow: arrow,
            id: Int(reading.lifeCount),
            date: date,
            source: "Libre3 BLE"
        )
        glucose.value = value
        return LibreLinkUpGlucose(
            glucose: glucose,
            color: color(forMgDL: value, settings: settings),
            trendArrow: arrow
        )
    }

    // MARK: - Historical backfill samples
    //
    // Historical pages carry 5-min-spaced samples (no trend / rate-of-change —
    // those are realtime-only), used to seed the graph window on connect. `id`
    // is the sample's `lifeCount` so it de-duplicates against realtime points
    // on the same minute grid; `date` uses the same sensor-start anchor.
    // Returns `nil` for samples outside the 39–501 display range
    // (`glucoseMgDL` is the already-clamped display value, `nil` when
    // unavailable).

    static func makeGlucose(
        fromHistorical sample: HistoricalReadingSample,
        sensorStartDate: Date,
        settings: SensorSettings,
        calibrationOffsetMgDL: Int = 0
    ) -> LibreLinkUpGlucose? {
        guard let mgDL = sample.glucoseMgDL else { return nil }
        let rawValueMgDL = Int(mgDL)
        let value = calibratedValue(rawValueMgDL: rawValueMgDL, offsetMgDL: calibrationOffsetMgDL)
        let date = sensorStartDate.addingTimeInterval(Double(sample.lifeCount) * 60)
        var glucose = Glucose(
            rawValueMgDL,
            temperature: 0,
            trendRate: 0,
            trendArrow: .notDetermined,
            id: Int(sample.lifeCount),
            date: date,
            source: "Libre3 BLE"
        )
        glucose.value = value
        return LibreLinkUpGlucose(
            glucose: glucose,
            color: color(forMgDL: value, settings: settings),
            trendArrow: .notDetermined
        )
    }

    // MARK: - Embedded historical sample
    //
    // Every realtime reading also carries the sensor's most recent 5-minute
    // historical sample (~15–20 min behind now). Folding it into the historical
    // series extends the graph at realtime pace even when on-demand backfill
    // returns nothing — it's the same 5-minute record the sensor commits. Mapped
    // only when the reading marks it valid and its own data quality is good.

    static func makeGlucose(
        fromEmbeddedHistorical reading: RealtimeGlucoseReading,
        sensorStartDate: Date,
        settings: SensorSettings,
        calibrationOffsetMgDL: Int = 0
    ) -> LibreLinkUpGlucose? {
        guard reading.isHistoricalGlucoseValid,
              reading.isHistoricalDQGood,
              reading.historicalLifeCount > 0,
              let mgDL = reading.historicalGlucoseMgDL else { return nil }
        let rawValueMgDL = Int(mgDL)
        let value = calibratedValue(rawValueMgDL: rawValueMgDL, offsetMgDL: calibrationOffsetMgDL)
        let date = sensorStartDate.addingTimeInterval(Double(reading.historicalLifeCount) * 60)
        var glucose = Glucose(
            rawValueMgDL,
            temperature: 0,
            trendRate: 0,
            trendArrow: .notDetermined,
            id: Int(reading.historicalLifeCount),
            date: date,
            source: "Libre3 BLE"
        )
        glucose.value = value
        return LibreLinkUpGlucose(
            glucose: glucose,
            color: color(forMgDL: value, settings: settings),
            trendArrow: .notDetermined
        )
    }

    /// Apply a prospective FLwatch-local correction while preserving Glucose's
    /// immutable `rawValue` as the original sensor-reported value. Recomputing
    /// color here keeps every downstream surface consistent with the value it sees.
    private static func calibratedValue(rawValueMgDL: Int, offsetMgDL: Int) -> Int {
        min(max(rawValueMgDL + offsetMgDL, 39), 501)
    }
}
#endif
