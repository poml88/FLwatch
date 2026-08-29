//
//  Libre3BackfillImporter.swift
//  FLwatch
//
//  Requests bounded historical backfill from the sensor on connect so the graph
//  window is seeded immediately instead of filling in one realtime point per
//  minute (PLAN §4 / Phase 4). The sensor replies with a burst of
//  `HistoricalReadingPage`s on the `historicData` channel, which the manager's
//  data-plane state decodes and the mapper folds into the rolling buffer.
//
//  This mirrors LibreCRKit's validated harness bootstrap exactly: enable the
//  `historicData` notify, then write an AES-CCM-wrapped
//  `historicalBackfillGreaterEqual` command (a per-session advancing sequence,
//  using the `patchControlWrite` packet kind) to `patchControl`.
//
//  iOS-only: references LibreCRKit + CoreBluetooth, phone-target only.
//

#if os(iOS)
import Foundation
import CoreBluetooth
import OSLog
import LibreCRKit

enum Libre3BackfillImporter {

    /// The graph display window (6 h 10 m). We never request more history than
    /// this — it's all the graph shows.
    static let displayWindowMinutes: UInt16 = 6 * 60 + 10

    /// Minute-resolution clinical history requested after a reconnect. Keep the
    /// request deliberately short: it only bridges the gap between the lagging
    /// 5-minute series and the current realtime value.
    static let clinicalWindowMinutes: UInt16 = 20

    /// A resume point is eligible only when it does not exceed the connected
    /// sensor's own life count.
    ///
    /// `lifeCount` is minutes since activation and never runs backwards, so a
    /// larger value cannot belong to this sensor. It belongs to the *previous*
    /// one: readings carry no sensor identity, the persisted history the buffers
    /// are seeded from deliberately keeps the old sensor's values, and a
    /// replacement restarts near 0 — so a 14-day sensor leaves a ~20,160 maximum
    /// behind for a sensor that is at 61. Requesting from an unreachable `from`
    /// returns an empty burst, so the ineligible value is discarded and the caller
    /// falls back to its own window bound.
    ///
    /// Equality stays eligible: that is an ordinary reconnect with no gap yet.
    private static func eligibleResumeLifeCount(
        _ resume: UInt16?,
        currentLifeCount: UInt16
    ) -> Int {
        guard let resume, resume <= currentLifeCount else { return 0 }
        return Int(resume)
    }

    /// Lower bound for the backfill request, in `lifeCount` minutes.
    ///
    /// **The patch returns entries strictly NEWER than `from`** (per the libre3BT
    /// sample / Juggluco `Libre3GattCallback`). We want to **fill the gap since the
    /// last historical sample we already hold**, but never reach back further than
    /// the 6 h 10 m display window:
    ///
    ///   `from = max(eligible(lastHistoricalLifeCount), currentLifeCount − 6h10m)`
    ///
    /// So a small gap fetches only the gap; a gap older than the window (or no
    /// history at all, e.g. a cold start, or a resume point left behind by the
    /// previous sensor — see `eligibleResumeLifeCount`) fetches exactly the
    /// window. Aligned down to the 5-minute commit grid and floored at 5 —
    /// Juggluco's `max(lastReceived, 5)`. **Never 0** (the patch ignores a
    /// 0/too-small request).
    static func backfillStartLifeCount(
        lastHistoricalLifeCount: UInt16?,
        currentLifeCount: UInt16
    ) -> UInt16 {
        let windowStart = Int(currentLifeCount) > Int(displayWindowMinutes)
            ? Int(currentLifeCount) - Int(displayWindowMinutes)
            : 5
        let raw = max(
            windowStart,
            eligibleResumeLifeCount(lastHistoricalLifeCount, currentLifeCount: currentLifeCount)
        )
        let aligned = (raw / 5) * 5
        return UInt16(max(5, aligned))
    }

    /// Lower bound for minute-resolution clinical backfill. Unlike historical
    /// samples, clinical records are not aligned to the 5-minute commit grid.
    /// Compute in `Int` so young sensors cannot underflow UInt16 subtraction, and
    /// drop a resume point that cannot be this sensor's (`eligibleResumeLifeCount`).
    static func clinicalBackfillStartLifeCount(
        lastMinuteLifeCount: UInt16?,
        currentLifeCount: UInt16
    ) -> UInt16 {
        let windowStart = Int(currentLifeCount) - Int(clinicalWindowMinutes)
        let raw = max(
            eligibleResumeLifeCount(lastMinuteLifeCount, currentLifeCount: currentLifeCount),
            windowStart
        )
        return UInt16(clamping: max(1, raw))
    }

    /// Leave one extra minute beyond warm-up plus the requested window because
    /// the clinical command's lower-bound inclusivity has not been confirmed.
    static func shouldRequestClinicalBackfill(
        currentLifeCount: UInt16,
        warmupMinutes: Int
    ) -> Bool {
        Int(currentLifeCount) >= warmupMinutes + Int(clinicalWindowMinutes) + 1
    }

    /// Request the bounded historical backfill: arm the `historicData` notify
    /// (transiently, so the baseline handshake/refresh is untouched), then write
    /// the request. Decoded pages arrive on the session's `notifications()` stream
    /// alongside realtime readings; the manager records them through
    /// `Libre3DataPlaneState` like any other data-plane packet.
    static func requestHistoricalBackfill(
        session: SensorSession,
        crypto: DataPlaneCrypto,
        fromLifeCount: UInt16,
        sequence: UInt16
    ) async throws {
        try await session.setNotify(true, for: LibreSensorGATT.Char.historicData, timeout: 8)
        let command = PatchControlCommand.historicalBackfillGreaterEqual(lifeCount: fromLifeCount)
        let frame = try crypto.encrypt(
            plaintext: command.plaintext,
            sequence: sequence,
            kind: .patchControlWrite
        )
        Logger.libre3.info("Libre3 BLE requesting historical backfill seq=\(sequence, privacy: .public) from lifeCount=\(fromLifeCount, privacy: .public) (\(command.label, privacy: .public))")
        try await session.writeRaw(frame.raw, to: LibreSensorGATT.Char.patchControl, timeout: 10)
        Logger.libre3.info("Libre3 BLE historical backfill command accepted")
    }

    /// Request one-minute clinical records using the same encrypted patch-control
    /// path as historical backfill. The clinical CCCD is already part of the
    /// seven-channel re-arm; this transient enable is therefore normally a logged
    /// no-op and keeps the request self-contained.
    static func requestClinicalBackfill(
        session: SensorSession,
        crypto: DataPlaneCrypto,
        fromLifeCount: UInt16,
        sequence: UInt16
    ) async throws {
        try await session.setNotify(true, for: LibreSensorGATT.Char.clinicalData, timeout: 8)
        let command = PatchControlCommand.clinicalBackfillGreaterEqual(lifeCount: fromLifeCount)
        let frame = try crypto.encrypt(
            plaintext: command.plaintext,
            sequence: sequence,
            kind: .patchControlWrite
        )
        Logger.libre3.info("Libre3 BLE requesting clinical backfill seq=\(sequence, privacy: .public) from lifeCount=\(fromLifeCount, privacy: .public) (\(command.label, privacy: .public))")
        try await session.writeRaw(frame.raw, to: LibreSensorGATT.Char.patchControl, timeout: 10)
        Logger.libre3.info("Libre3 BLE clinical backfill command accepted")
    }
}
#endif
