import Foundation
import ActivityKit
import OSLog

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private static let maxGraphPoints = 72
    private static let maxMinutePoints = 48
    private static let foregroundRestartThreshold: TimeInterval = 60 * 60

    private init() {}


    private func reusableActivity() -> Activity<FLWatchAttributes>? {
        Activity<FLWatchAttributes>.activities.first { activity in
            guard activity.attributes.activityIdentifier == FLWatchAttributes.glucoseActivityIdentifier else { return false }
            switch activity.activityState {
            case .active, .stale:
                return true
            case .pending, .ended, .dismissed:
                return false
            @unknown default:
                return false
            }
        }
    }

    private func shouldRestart(_ activity: Activity<FLWatchAttributes>, ifOlderThan threshold: TimeInterval?) -> Bool {
        guard let threshold else { return false }
        return Date.now.timeIntervalSince(activity.attributes.startedAt) >= threshold
    }

    private func dismissEndedActivitiesOfThisType() async {
        for activity in Activity<FLWatchAttributes>.activities {
            guard activity.attributes.activityIdentifier == FLWatchAttributes.glucoseActivityIdentifier else { continue }
            guard activity.activityState == .ended else { continue }
            let previousId = activity.id
            await activity.end(nil, dismissalPolicy: .immediate)
            Logger.liveActivity.info("Dismissed ended Live Activity \(previousId, privacy: .public) before starting a new one.")
        }
    }

    func startIfAllowed(useLiveActivities: Bool) {
        Task {
            await refreshFromCurrentHistory(useLiveActivities: useLiveActivities)
        }
    }

    func refreshFromCurrentHistory(
        useLiveActivities: Bool,
        reloadFailed: Bool = false,
        restartIfOlderThan threshold: TimeInterval? = nil,
        refreshIOB: Bool = true
    ) async {
        guard useLiveActivities else {
            await endAllActivities()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Logger.liveActivity.log("Live Activities not authorized/enabled by system.")
            return
        }

        if reloadFailed {
            Logger.liveActivity.info("Reload failed; refreshing persisted glucose data before rebuilding Live Activity.")
            _ = await LibreLinkUpService.refreshHistoryFromPersistenceAsync(force: true)
        } else {
            _ = await LibreLinkUpService.refreshHistoryFromPersistenceAsync()
        }

        let state = await MainActor.run { () -> FLWatchAttributes.ContentState in
            let history = LibreLinkUpHistory.shared
            let insulinHistory = InsulinDeliveryHistorySingleton.shared
            insulinHistory.read()
            let currentIOB = CurrentIOBSingleton.shared
            if refreshIOB {
                currentIOB.updateCurrentIOBAndGraphs()
            }
            _ = SensorSettingsStore.shared.refreshFromPersistence(force: reloadFailed)
            let sensorSettings = SensorSettingsStore.shared.sensorSettings
            let cutoffDate = Date.now.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
            let showIOBCurve = SharedData.showIOBCurvePhone
            let showActivityCurve = SharedData.showActivityCurvePhone
            let showInsulinDeliveryMarks = SharedData.showInsulinDeliveryMarksPhone

            let graphPoints = Array(history.libreLinkUpGlucose
                .filter { $0.glucose.date >= cutoffDate }
                .sorted { $0.glucose.date < $1.glucose.date }
                .sampled(maxCount: Self.maxGraphPoints)
                .map {
                    FLWatchAttributes.GraphPoint(
                        timestamp: $0.glucose.date,
                        valueInMgPerDl: $0.glucose.value,
                        colorRawValue: $0.color.rawValue
                    )
                })

            let minutePoints = Array(history.libreLinkUpMinuteGlucose
                .filter { $0.glucose.date >= cutoffDate }
                .sorted { $0.glucose.date < $1.glucose.date }
                .sampled(maxCount: Self.maxMinutePoints)
                .map {
                    FLWatchAttributes.GraphPoint(
                        timestamp: $0.glucose.date,
                        valueInMgPerDl: $0.glucose.value,
                        colorRawValue: MeasurementColor.yellow.rawValue
                    )
                })

            let iobPoints = Array(currentIOB.insulinOnBoardCurve
                .filter { $0.date >= cutoffDate }
                .map {
                    FLWatchAttributes.ActivityPoint(
                        timestamp: $0.date,
                        valueInHundredths: Int(($0.value * Double(FLWatchAttributes.iobValueScale)).rounded())
                    )
                })

            let activityPoints = Array(currentIOB.insulinActivityCurve
                .filter { $0.date >= cutoffDate }
                .map {
                    FLWatchAttributes.ActivityPoint(
                        timestamp: $0.date,
                        valueInHundredths: Int(($0.value * Double(FLWatchAttributes.activityValueScale)).rounded())
                    )
                })

            let insulinMarkers = Array(insulinHistory.insulinDeliveryHistory
                .filter { Date(timeIntervalSince1970: $0.timeStamp) >= cutoffDate }
                .sorted { $0.timeStamp < $1.timeStamp }
                .map {
                    FLWatchAttributes.InsulinMarker(
                        timestamp: Date(timeIntervalSince1970: $0.timeStamp),
                        insulinUnitsInHundredths: Int(($0.insulinUnits * 100).rounded())
                    )
                })

            let state = FLWatchAttributes.ContentState(
                latestGlucoseValue: history.currentGlucose,
                latestTrend: history.currentTrendArrow,
                latestTimestamp: history.lastReadingDate,
                latestColor: history.latestLibreLinkUpGlucose?.color.rawValue ?? 0,
                graphPoints: graphPoints,
                minutePoints: minutePoints,
                glucoseUnit: sensorSettings.uom,
                targetLow: sensorSettings.targetLow,
                targetHigh: sensorSettings.targetHigh,
                alarmLow: sensorSettings.alarmLow,
                maxGlucoseValue: history.maxBG,
                currentIOBInHundredths: Int((currentIOB.currentIOB * Double(FLWatchAttributes.iobValueScale)).rounded()),
                iobPoints: iobPoints,
                maxIOBInHundredths: max(1, Int((currentIOB.maxIOB * Double(FLWatchAttributes.iobValueScale)).rounded())),
                activityPoints: activityPoints,
                maxActivityInHundredths: max(1, Int((currentIOB.maxActivity * Double(FLWatchAttributes.activityValueScale)).rounded())),
                insulinMarkers: insulinMarkers,
                showIOBCurve: showIOBCurve,
                showActivityCurve: showActivityCurve,
                showInsulinDeliveryMarks: showInsulinDeliveryMarks
            )

            if let payloadSize = Self.encodedSize(of: state) {
                Logger.liveActivity.debug("Live Activity state payload size: \(payloadSize, privacy: .public) bytes")
            }

            return state
        }
        let content = ActivityContent(
            state: state,
            staleDate: state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleActivityAfterInterval)
        )

        if let existing = reusableActivity() {
            if shouldRestart(existing, ifOlderThan: threshold) {
                let ageInMinutes = Int(Date.now.timeIntervalSince(existing.attributes.startedAt) / 60)
                Logger.liveActivity.info("Restarting aged Live Activity \(existing.id, privacy: .public) after \(ageInMinutes, privacy: .public) minutes in foreground.")
                do {
                    let attrs = FLWatchAttributes()
                    let activity = try Activity.request(attributes: attrs, content: content, pushType: nil)
                    Logger.liveActivity.log("Started replacement Live Activity \(activity.id, privacy: .public) from foreground refresh.")
                    await existing.end(nil, dismissalPolicy: .immediate)
                    Logger.liveActivity.info("Ended previous Live Activity \(existing.id, privacy: .public) after successful replacement.")
                    await dismissEndedActivitiesOfThisType()
                } catch {
                    Logger.liveActivity.error("Failed to restart Live Activity: \(error.localizedDescription)")
                    await existing.update(content)
                    Logger.liveActivity.log("Kept existing Live Activity \(existing.id, privacy: .public) after replacement failed.")
                }
                return
            }
            await existing.update(content)
            Logger.liveActivity.log("Updated Live Activity \(existing.id, privacy: .public) from BG refresh/history.")
        } else {
            do {
                await dismissEndedActivitiesOfThisType()
                let attrs = FLWatchAttributes()
                let activity = try Activity.request(attributes: attrs, content: content, pushType: nil)
                Logger.liveActivity.log("Started local Live Activity \(activity.id, privacy: .public) from BG refresh/history.")
            } catch {
                Logger.liveActivity.error("Failed to start Live Activity: \(error.localizedDescription)")
            }
        }
    }

    func handleUserSettingsChange(useLiveActivities: Bool, frequentUpdates: Bool) async {
        _ = frequentUpdates
        if useLiveActivities {
            await refreshFromCurrentHistory(useLiveActivities: true)
        } else {
            await endAllActivities()
        }
    }

    var foregroundRestartAgeThreshold: TimeInterval {
        Self.foregroundRestartThreshold
    }

    func endAllActivities() async {
        for activity in Activity<FLWatchAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            Logger.liveActivity.info("Ended local Live Activity \(activity.id, privacy: .public)")
        }
    }

    private static func encodedSize(of state: FLWatchAttributes.ContentState) -> Int? {
        do {
            let stateData = try JSONEncoder().encode(state)
            let attrsData = try JSONEncoder().encode(FLWatchAttributes())
            return stateData.count + attrsData.count
        } catch {
            Logger.liveActivity.error("Failed to measure Live Activity payload size: \(error.localizedDescription)")
            return nil
        }
    }
}
private extension Array {
    /// Downsamples to *exactly* `maxCount` elements (when the array is larger)
    /// while preserving full detail for the most recent readings. The array is
    /// assumed oldest-first (the most recent reading is last).
    ///
    /// The newest `recentKeep` (12) elements are always kept un-thinned, since
    /// recent glucose detail matters most on the chart. The older remainder is
    /// sampled down to fill the entire leftover budget (`maxCount - 12`) using
    /// a fractional step, so the full point budget is used (no wasted slots)
    /// and the older region stays as dense as the cap allows. Spacing in the
    /// older region varies by at most one source sample — unavoidable for a
    /// non-integer downsample ratio. Returns the array unchanged when it
    /// already fits, so sparse feeds (Libre) pass through and dense feeds get
    /// thinned instead of clipped.
    func sampled(maxCount: Int) -> [Element] {
        guard count > maxCount, maxCount > 1 else {
            return self
        }

        let recentKeep = Swift.min(12, maxCount)      // newest readings kept at full detail
        let tailStart = count - recentKeep            // first index of the kept recent tail
        let olderBudget = maxCount - recentKeep       // points allotted to the older remainder

        var indices: [Int] = []
        if tailStart > 0, olderBudget > 0 {
            if tailStart <= olderBudget {
                indices.append(contentsOf: 0..<tailStart)         // older region fits, keep all
            } else if olderBudget == 1 {
                indices.append(0)
            } else {
                // Spread olderBudget picks evenly across indices 0..<tailStart.
                let step = Double(tailStart - 1) / Double(olderBudget - 1)
                indices.append(contentsOf: (0..<olderBudget).map {
                    Int((Double($0) * step).rounded())
                })
            }
        }
        indices.append(contentsOf: tailStart..<count) // append the recent tail in full
        return indices.map { self[$0] }
    }
}
