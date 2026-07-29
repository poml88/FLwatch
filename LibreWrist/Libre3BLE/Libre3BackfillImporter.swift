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

    /// Lower bound for the backfill request, in `lifeCount` minutes.
    ///
    /// **The patch returns entries strictly NEWER than `from`** (per the libre3BT
    /// sample / Juggluco `Libre3GattCallback`). We want to **fill the gap since the
    /// last historical sample we already hold**, but never reach back further than
    /// the 6 h 10 m display window:
    ///
    ///   `from = max(lastHistoricalLifeCount, currentLifeCount − 6h10m)`
    ///
    /// So a small gap fetches only the gap; a gap older than the window (or no
    /// history at all, e.g. a cold start) fetches exactly the window. Aligned down
    /// to the 5-minute commit grid and floored at 5 — Juggluco's
    /// `max(lastReceived, 5)`. **Never 0** (the patch ignores a 0/too-small
    /// request).
    static func backfillStartLifeCount(
        lastHistoricalLifeCount: UInt16?,
        currentLifeCount: UInt16?
    ) -> UInt16 {
        let windowStart: Int = {
            guard let current = currentLifeCount, Int(current) > Int(displayWindowMinutes) else { return 5 }
            return Int(current) - Int(displayWindowMinutes)
        }()
        let raw = max(windowStart, Int(lastHistoricalLifeCount ?? 0))
        let aligned = (raw / 5) * 5
        return UInt16(max(5, aligned))
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
}
#endif
