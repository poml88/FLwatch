//
//  InsulinObjects.swift
//  LibreWrist
//
//  Created by Peter Müller on 01.09.24.
//

import SwiftUI
import OSLog

enum InsulinType: Int, CaseIterable {
    case rapidActing = 0
    case fastRapidActing = 1
    
    var description: LocalizedStringResource {
        switch self {
        case .rapidActing:
            return "Rapid acting"
        case .fastRapidActing:
            return "Fast rapid acting"
        }
    }
    var fullDescription: LocalizedStringResource {
        switch self {
        case .rapidActing:
            return "Rapid acting (Novolog, ...)"
        case .fastRapidActing:
            return "Fast rapid acting (Fiasp, Lyumjev, ...)"
        }
    }
    var presets: InsulinTypePresets {
        switch self {
        case .rapidActing:
            return .rapidActing
        case .fastRapidActing:
            return .fastRapidActing
        }
    }
}

struct ActivityCurveDataPoint: Codable, Identifiable, Equatable {
    let id: Int //timeinterval
    let date: Date
    let value: Double
}

struct InsulinDelivery: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timeStamp: Double
    let insulinUnits: Double
    let insulinType: Int
    
    init(id: UUID, timestamp: Double, insulinUnits: Double, insulinType: Int) {
        self.id = id
        self.timeStamp = timestamp
        self.insulinUnits = insulinUnits
        self.insulinType = insulinType
    }
}

struct InsulinTypePresets: Codable, Identifiable {
    let id: UUID
    let actionDuration: Double
    let peakActivityTime: Double
    let delay: Double
    
    init(id: UUID, actionDuration: Double, peakActivityTime: Double, delay: Double) {
        self.id = UUID()
        self.actionDuration = actionDuration
        self.peakActivityTime = peakActivityTime
        self.delay = delay
    }
    static let rapidActing = InsulinTypePresets(id: UUID(), actionDuration: 360 * 60, peakActivityTime: 75 * 60, delay: 10 * 60)
    static let fastRapidActing = InsulinTypePresets(id: UUID(), actionDuration: 360 * 60, peakActivityTime: 55 * 60, delay: 10 * 60)
}

@MainActor @Observable class InsulinDeliveryHistorySingleton {
    
    var insulinDeliveryHistory: [InsulinDelivery] = []
    /// Local history is the period during which a dose remains user-manageable.
    /// Nightscout uses the same boundary when accepting new treatment routes.
    nonisolated static let historyRetentionInterval: Double = 12 * 60 * 60
    
    static let shared: InsulinDeliveryHistorySingleton = {
        // nothing at the moment so can be used as well: static let shared: InsulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton()
        // static implies lazy
        let instance = InsulinDeliveryHistorySingleton()
        return instance
    }()
    
    private init() {
        insulinDeliveryHistory = Self.canonicalized(UserDefaults.group.insulinDeliveryHistory ?? [])
    }

    private nonisolated static func canonicalized(_ history: [InsulinDelivery]) -> [InsulinDelivery] {
        var seen = Set<UUID>()
        return history
            .sorted {
                if $0.timeStamp == $1.timeStamp {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.timeStamp < $1.timeStamp
            }
            .filter { seen.insert($0.id).inserted }
    }

    private nonisolated static func retainedHistory(
        from history: [InsulinDelivery],
        now timeIntervalSince1970: Double = Date().timeIntervalSince1970
    ) -> [InsulinDelivery] {
        canonicalized(history).filter {
            timeIntervalSince1970 - $0.timeStamp <= historyRetentionInterval
        }
    }

    private func mergePersistedHistoryIntoMemory() {
        let persistedHistory = UserDefaults.group.insulinDeliveryHistory ?? []
        insulinDeliveryHistory = Self.canonicalized(insulinDeliveryHistory + persistedHistory)
    }

    private func persistCurrentHistory() {
        insulinDeliveryHistory = Self.canonicalized(insulinDeliveryHistory)
        UserDefaults.group.insulinDeliveryHistory = insulinDeliveryHistory
    }

    func historySnapshot() -> [InsulinDelivery] {
        Self.canonicalized(insulinDeliveryHistory)
    }

    nonisolated static func persistedHistorySnapshot() -> [InsulinDelivery] {
        canonicalized(UserDefaults.group.insulinDeliveryHistory ?? [])
    }

    nonisolated static func retainedPersistedHistorySnapshot() -> [InsulinDelivery] {
        retainedHistory(from: UserDefaults.group.insulinDeliveryHistory ?? [])
    }
    
    func save() {
        mergePersistedHistoryIntoMemory()
        persistCurrentHistory()
    }
    
    func read() {
        let persistedHistory = UserDefaults.group.insulinDeliveryHistory ?? []
        let canonicalizedHistory = Self.canonicalized(persistedHistory)
        let retainedHistory = Self.retainedHistory(from: canonicalizedHistory)
        insulinDeliveryHistory = retainedHistory

        if retainedHistory.count != canonicalizedHistory.count {
            UserDefaults.group.insulinDeliveryHistory = retainedHistory
        }
        // Retention pruning is not user intent. Never route removals from this
        // method to Nightscout; routing records age independently instead.
    }
    
    func saveAndUpdateIOB() {
        mergePersistedHistoryIntoMemory()
        persistCurrentHistory()
        Task { @MainActor in
            CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()
        }
    }

    private func recordDeliveryLocally(
        id: UUID,
        timestamp: Date,
        insulinUnits: Double,
        insulinType: Int
    ) -> InsulinDelivery {
        mergePersistedHistoryIntoMemory()
        if let existingDelivery = insulinDeliveryHistory.first(where: { $0.id == id }) {
            NightscoutUploadManager.shared.recordInsulinPresent(existingDelivery)
            return existingDelivery
        }

        let delivery = InsulinDelivery(
            id: id,
            timestamp: timestamp.timeIntervalSince1970,
            insulinUnits: insulinUnits,
            insulinType: insulinType
        )
        insulinDeliveryHistory.append(delivery)
        saveAndUpdateIOB()
        NightscoutUploadManager.shared.recordInsulinPresent(delivery)
        return delivery
    }

    @discardableResult
    func recordDelivery(id: UUID = UUID(), timestamp: Date, insulinUnits: Double, insulinType: Int) -> InsulinDelivery {
        let delivery = recordDeliveryLocally(
            id: id,
            timestamp: timestamp,
            insulinUnits: insulinUnits,
            insulinType: insulinType
        )
        Task {
            await AppleHealthExportManager.shared.exportInsulinDeliveriesIfNeeded([delivery])
        }
        return delivery
    }

    @discardableResult
    func recordDeliveryAndAwaitExport(
        id: UUID = UUID(),
        timestamp: Date,
        insulinUnits: Double,
        insulinType: Int
    ) async -> InsulinDelivery {
        let delivery = recordDeliveryLocally(
            id: id,
            timestamp: timestamp,
            insulinUnits: insulinUnits,
            insulinType: insulinType
        )
        await AppleHealthExportManager.shared.exportInsulinDeliveriesIfNeeded([delivery])
        return delivery
    }

    func replaceHistory(_ history: [InsulinDelivery]) {
        let previousHistory = historySnapshot()
        let nextHistory = Self.canonicalized(history)
        insulinDeliveryHistory = nextHistory
        persistCurrentHistory()
        recordNightscoutChanges(previous: previousHistory, current: nextHistory)
    }

    @discardableResult
    func removeDelivery(id: UUID) -> Bool {
        mergePersistedHistoryIntoMemory()
        let removedDelivery = insulinDeliveryHistory.first { $0.id == id }
        insulinDeliveryHistory.removeAll { $0.id == id }
        if let removedDelivery {
            persistCurrentHistory()
            NightscoutUploadManager.shared.recordInsulinAbsent(identifier: removedDelivery.id)
            return true
        }
        return false
    }

    @discardableResult
    func removeDeliveries(timestamp: Double) -> Bool {
        mergePersistedHistoryIntoMemory()
        let removedDeliveries = insulinDeliveryHistory.filter { $0.timeStamp == timestamp }
        insulinDeliveryHistory.removeAll { $0.timeStamp == timestamp }
        if !removedDeliveries.isEmpty {
            persistCurrentHistory()
            for delivery in removedDeliveries {
                NightscoutUploadManager.shared.recordInsulinAbsent(identifier: delivery.id)
            }
            return true
        }
        return false
    }

    func clearHistory() {
        mergePersistedHistoryIntoMemory()
        let removedDeliveries = historySnapshot()
        insulinDeliveryHistory = []
        persistCurrentHistory()
        for delivery in removedDeliveries {
            NightscoutUploadManager.shared.recordInsulinAbsent(identifier: delivery.id)
        }
    }

    private func recordNightscoutChanges(
        previous: [InsulinDelivery],
        current: [InsulinDelivery]
    ) {
        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let currentByID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for delivery in current where previousByID[delivery.id] != delivery {
            NightscoutUploadManager.shared.recordInsulinPresent(delivery)
        }
        // `replaceHistory` represents user edits only inside the retained
        // window. An omitted older dose may have disappeared through retention
        // pruning and must not be interpreted as deletion intent.
        let retainedPrevious = Self.retainedHistory(from: previous)
        for delivery in retainedPrevious where currentByID[delivery.id] == nil {
            NightscoutUploadManager.shared.recordInsulinAbsent(identifier: delivery.id)
        }
    }
}

@MainActor @Observable class CurrentIOBSingleton {
    
    var currentIOB: Double = 0.0
    var insulinOnBoardCurve: [ActivityCurveDataPoint] = []
    var insulinActivityCurve: [ActivityCurveDataPoint] = []
    var maxIOB: Double = 1
    var maxActivity: Double = 1
    
    nonisolated static let shared: CurrentIOBSingleton = {
        let instance = CurrentIOBSingleton()
        return instance
    }()

    private nonisolated static let historyRetentionInterval: Double = 12 * 60 * 60
    
    private nonisolated init() {}
    
    nonisolated func getCurrentIOB() -> Double {
        Self.currentIOB(from: InsulinDeliveryHistorySingleton.persistedHistorySnapshot())
    }
    
    private nonisolated func updateIOB(timeStamp timeInterval: Double, insulinType type: InsulinType.RawValue) -> Double {
        Self.iobFractionRemaining(timeStamp: timeInterval, insulinType: type)
    }

    private nonisolated static func activeHistory(from history: [InsulinDelivery], now timeIntervalSince1970: Double) -> [InsulinDelivery] {
        history.filter {
            timeIntervalSince1970 - $0.timeStamp <= historyRetentionInterval
        }
    }

    private nonisolated static func currentIOB(from history: [InsulinDelivery], now timeIntervalSince1970: Double = Date().timeIntervalSince1970) -> Double {
        let activeHistory = activeHistory(from: history, now: timeIntervalSince1970)
        var sumIOB: Double = 0

        for item in activeHistory {
            let timeIntervalBetweenDeliveryAndNow = timeIntervalSince1970 - item.timeStamp
            let IOB = iobFractionRemaining(
                timeStamp: timeIntervalBetweenDeliveryAndNow,
                insulinType: item.insulinType
            ) * item.insulinUnits
            sumIOB += IOB
        }

        return sumIOB
    }

    private nonisolated static func makeModel(_ preset: InsulinTypePresets) -> ExponentialInsulinModel {
        ExponentialInsulinModel(
            actionDuration: preset.actionDuration,
            peakActivityTime: preset.peakActivityTime,
            delay: preset.delay
        )
    }

    /// One model per insulin type, built once.
    ///
    /// A model is a pure function of its preset and its initializer runs an `exp()`, yet the
    /// IOB curve evaluates ~97 grid points per dose on every update — so the old code rebuilt
    /// the same two models hundreds of times a minute. `InsulinType.presets` stays the single
    /// source of truth, so editing a preset still flows through here.
    private nonisolated static let rapidActingModel = makeModel(InsulinType.rapidActing.presets)
    private nonisolated static let fastRapidActingModel = makeModel(InsulinType.fastRapidActing.presets)

    private nonisolated static func model(for type: InsulinType.RawValue) -> ExponentialInsulinModel {
        switch InsulinType(rawValue: type) ?? .rapidActing {
        case .rapidActing: return rapidActingModel
        case .fastRapidActing: return fastRapidActingModel
        }
    }

    private nonisolated static func iobFractionRemaining(timeStamp timeInterval: Double, insulinType type: InsulinType.RawValue) -> Double {
        model(for: type).percentEffectRemaining(at: timeInterval)
    }
    
    private func calculateInsulinOnBoardCurve(from history: [InsulinDelivery]) -> [ActivityCurveDataPoint] {
        let timeIntervalSince1970: Double = Date().timeIntervalSince1970
        
        if history.isEmpty { return [] }
        
        // Whether a dose is old enough to be irrelevant does not depend on the grid step, so
        // test it once here rather than re-testing every dose at all ~97 steps.
        let InternvalSixHoursAndTen: Double = 6 * 60 * 60 + 10 * 60
        let contributingHistory = history.filter {
            timeIntervalSince1970 - $0.timeStamp < InternvalSixHoursAndTen // e.g. 600 sec
        }
        if contributingHistory.isEmpty { return [] }

        var activityCurve: [ActivityCurveDataPoint] = []
        let minutes = 5 * 60
        activityCurve.reserveCapacity(97) // (6 h back + 2 h forward) / 5 min, plus the step at 0
        for timeInterval in stride(from: 6 * 60 * 60, through: -2 * 60 * 60, by: -minutes) {
            var sumIOB: Double = 0
            for item in contributingHistory {
                let timeIntervalBetweenDeliveryAndTimeStampToBeCalculated = timeIntervalSince1970 - item.timeStamp - Double(timeInterval) // e.g. 600 sec - 300 sec
//                print("timeIntervalBetweenDeliveryAndTimeStampToBeCalculated: \(timeIntervalBetweenDeliveryAndTimeStampToBeCalculated)")
                if timeIntervalBetweenDeliveryAndTimeStampToBeCalculated >= 0 {
                    let IOB =   updateIOB(timeStamp: timeIntervalBetweenDeliveryAndTimeStampToBeCalculated, insulinType: item.insulinType) * item.insulinUnits
                    sumIOB = sumIOB + IOB
                }
            }
            if sumIOB > 0 {
                let dataPoint: ActivityCurveDataPoint = ActivityCurveDataPoint(id: timeInterval, date: Date(timeIntervalSinceNow: -Double(timeInterval)), value: sumIOB)
//                print("Data point: \(dataPoint)")
                activityCurve.append(dataPoint)
            }
        }
        return activityCurve
    }
    
    /// Differences the IOB curve into per-step insulin activity.
    /// Must be handed the *full* curve including its forward points — the activity value
    /// at a given step is the IOB drop between that step and the next one, so the newest
    /// visible value depends on a point that lies in the future.
    private func calculateinsulinActivityCurve(from IOBcurve: [ActivityCurveDataPoint]) -> [ActivityCurveDataPoint] {
        if IOBcurve.count < 2 { return []}
        
        var activityCurve: [ActivityCurveDataPoint] = []
        for i in 0..<IOBcurve.count - 1 {
            let difference = IOBcurve[i].value - IOBcurve[i + 1].value
            if difference > 0 {
                let dataPoint = ActivityCurveDataPoint(id: IOBcurve[i + 1].id, date: IOBcurve[i + 1].date, value: difference)
//                print("\(dataPoint)")
                activityCurve.append(dataPoint)
            }
        }
        return activityCurve
    }
    
    /// Publishes a fully computed result in one go.
    ///
    /// `@Observable` fires a mutation on every write without comparing values, and each
    /// mutation invalidates every observer — phone home and graph views, watch graph,
    /// CarPlay, Live Activity rebuilds. Redrawing a ~90-point chart costs orders of
    /// magnitude more than computing it, so each property is written exactly once per
    /// update and only when it actually moved. With no insulin on board every value is
    /// identical minute after minute, and this suppresses the redraws entirely.
    private func publish(
        currentIOB newCurrentIOB: Double,
        insulinOnBoardCurve newIOBCurve: [ActivityCurveDataPoint],
        insulinActivityCurve newActivityCurve: [ActivityCurveDataPoint],
        maxIOB newMaxIOB: Double,
        maxActivity newMaxActivity: Double
    ) {
        if currentIOB != newCurrentIOB { currentIOB = newCurrentIOB }
        if insulinOnBoardCurve != newIOBCurve { insulinOnBoardCurve = newIOBCurve }
        if insulinActivityCurve != newActivityCurve { insulinActivityCurve = newActivityCurve }
        if maxIOB != newMaxIOB { maxIOB = newMaxIOB }
        if maxActivity != newMaxActivity { maxActivity = newMaxActivity }
    }

    func updateCurrentIOBAndGraphs() {
        Logger.insulin.debug("Updating IOB graphs: \(Date.now, privacy: .public)")
        let now = Date().timeIntervalSince1970
        let historySnapshot = InsulinDeliveryHistorySingleton.persistedHistorySnapshot()
        let activeHistory = Self.activeHistory(from: historySnapshot, now: now)

        //MARK: Update IOB
        let newCurrentIOB = Self.currentIOB(from: activeHistory, now: now)

#if os(iOS)
        let showIOBCurve = SharedData.showIOBCurvePhone
        let showActivityCurve = SharedData.showActivityCurvePhone
#endif
#if os(watchOS)
        let showIOBCurve = SharedData.showIOBCurveWatch
        let showActivityCurve = SharedData.showActivityCurveWatch
#endif

        //MARK: Update IOB graph
        guard showIOBCurve || showActivityCurve else {
            // `maxIOB = 1000` is the established "no curve" sentinel; `maxActivity` is
            // deliberately left at its previous value, as it always has been.
            publish(
                currentIOB: newCurrentIOB,
                insulinOnBoardCurve: [],
                insulinActivityCurve: [],
                maxIOB: 1000,
                maxActivity: maxActivity
            )
            return
        }

        let fullIOBCurve = calculateInsulinOnBoardCurve(from: activeHistory)
        // Total IOB never rises after `now` — no future doses are ever added — so its
        // maximum always lies at or before `now` and the forward points cannot affect it.
        let newMaxIOB = fullIOBCurve.max { $0.value < $1.value }?.value ?? 1

        //MARK: Update insulin activity graph
        guard showActivityCurve else {
            publish(
                currentIOB: newCurrentIOB,
                // Must take Date.now here rather than reusing `now` from the top: that
                // was sampled before the curve was calculated and would drop its first point.
                insulinOnBoardCurve: fullIOBCurve.filter { $0.date < Date.now },
                insulinActivityCurve: [],
                maxIOB: newMaxIOB,
                maxActivity: maxActivity
            )
            return
        }

        // `calculateInsulinOnBoardCurve` runs ~2 h past `now` on purpose, and only this
        // block needs it. Insulin activity is the derivative of IOB and peaks ~83 min
        // after delivery (10 min delay + 75 min peak), so a dose entered a moment ago has
        // its activity peak entirely in the future. Differencing the *full* curve and
        // taking `maxActivity` from it fixes the chart's y-scale immediately; shortening
        // the window would start a fresh dose near zero and rescale the chart every minute
        // for the next 90 min as the real peak came into view. The forward points are
        // dropped below, after the maximum has been taken.
        let fullActivityCurve = calculateinsulinActivityCurve(from: fullIOBCurve)
        let newMaxActivity = fullActivityCurve.max { $0.value < $1.value }?.value ?? 1

        publish(
            currentIOB: newCurrentIOB,
            insulinOnBoardCurve: fullIOBCurve.filter { $0.date < Date.now },
            insulinActivityCurve: fullActivityCurve.filter { $0.date < Date.now },
            maxIOB: newMaxIOB,
            maxActivity: newMaxActivity
        )
    }
}





extension EnvironmentValues {
    var insulinDeliveryHistorySingleton: InsulinDeliveryHistorySingleton {
        get { self[InsulinDeliveryHistorySingletonKey.self] }
        set { self[InsulinDeliveryHistorySingletonKey.self] = newValue }
    }
    
    var currentIOBSingleton: CurrentIOBSingleton {
        get { self[CurrentIOBSingletonKey.self] }
        set { self[CurrentIOBSingletonKey.self] = newValue }
    }
}


private struct InsulinDeliveryHistorySingletonKey: EnvironmentKey {
    static var defaultValue: InsulinDeliveryHistorySingleton = InsulinDeliveryHistorySingleton.shared
}

private struct CurrentIOBSingletonKey: EnvironmentKey {
    static var defaultValue: CurrentIOBSingleton = CurrentIOBSingleton.shared
}
