import Foundation
import ActivityKit
import OSLog

final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    private let maxGraphPoints = 24

    private func reusableActivity() -> Activity<FLWatchAttributes>? {
        Activity<FLWatchAttributes>.activities.first { activity in
            guard activity.attributes.activityIdentifier == FLWatchAttributes.glucoseActivityIdentifier else { return false }
            switch activity.activityState {
            case .active, .stale:
                return true
            case .ended, .dismissed:
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

        let userIdHash = SharedData.libreLinkUpUserId.SHA256
        guard !userIdHash.isEmpty else {
            Logger.liveActivity.error("Cannot update Live Activity: empty user id hash.")
            return
        }

        _ = await LibreLinkUpService.refreshHistoryFromPersistenceAsync()

        let state = await MainActor.run { () -> FLWatchAttributes.ContentState in
            let history = LibreLinkUpHistory.shared
            let pointsAscending = history.libreLinkUpGlucose
                .sorted(by: { $0.glucose.date < $1.glucose.date })
                .suffix(maxGraphPoints)
                .map { reading in
                    [Int(reading.glucose.date.timeIntervalSince1970), reading.glucose.value]
                }

            return FLWatchAttributes.ContentState(
                latestGlucoseValue: history.currentGlucose,
                trend: history.currentTrendArrow,
                timestamp: history.lastReadingDate,
                graphPoints: Array(pointsAscending)
            )
        }
        let content = ActivityContent(
            state: state,
            staleDate: state.timestamp.addingTimeInterval(FLWatchAttributes.staleAfterInterval)
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

}
