import Foundation
import ActivityKit
import OSLog

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private static let maxGraphPoints = 72
    private static let maxMinutePoints = 48

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

    func refreshFromCurrentHistory(useLiveActivities: Bool) async {
        guard useLiveActivities else {
            await endAllActivities()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Logger.liveActivity.log("Live Activities not authorized/enabled by system.")
            return
        }

        _ = await LibreLinkUpService.refreshHistoryFromPersistenceAsync()

        let state = await MainActor.run { () -> FLWatchAttributes.ContentState in
            let history = LibreLinkUpHistory.shared
            let insulinHistory = InsulinDeliveryHistorySingleton.shared
            insulinHistory.read()
            let currentIOB = CurrentIOBSingleton.shared
            currentIOB.updateCurrentIOBAndGraphs()
            _ = SensorSettingsStore.shared.refreshFromPersistence()
            let sensorSettings = SensorSettingsStore.shared.sensorSettings
            let cutoffDate = Date.now.addingTimeInterval(-6 * 60 * 60 - 10 * 60)
            let showIOBCurve = SharedData.showIOBCurvePhone
            let showActivityCurve = SharedData.showActivityCurvePhone
            let showInsulinDeliveryMarks = SharedData.showInsulinDeliveryMarksPhone

            let graphPoints = Array(history.libreLinkUpGlucose
                .filter { $0.glucose.date >= cutoffDate }
                .sorted { $0.glucose.date < $1.glucose.date }
                .suffix(Self.maxGraphPoints)
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
                        valueInHundredths: Int(($0.value * 100).rounded())
                    )
                })

            let activityPoints = Array(currentIOB.insulinActivityCurve
                .filter { $0.date >= cutoffDate }
                .map {
                    FLWatchAttributes.ActivityPoint(
                        timestamp: $0.date,
                        valueInHundredths: Int(($0.value * 100).rounded())
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
                currentIOBInHundredths: Int((currentIOB.currentIOB * 100).rounded()),
                iobPoints: iobPoints,
                maxIOBInHundredths: max(1, Int((currentIOB.maxIOB * 100).rounded())),
                activityPoints: activityPoints,
                maxActivityInHundredths: max(1, Int((currentIOB.maxActivity * 100).rounded())),
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
            staleDate: state.latestTimestamp.addingTimeInterval(FLWatchAttributes.staleAfterInterval)
        )

        if let existing = reusableActivity() {
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
    func sampled(maxCount: Int) -> [Element] {
        guard count > maxCount, maxCount > 1 else {
            return self
        }

        let step = Double(count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            self[Int((Double(index) * step).rounded(.toNearestOrAwayFromZero))]
        }
    }
}
