//
//  GlucoseActivityManager.swift
//  FLwatch
//
//  Created by Peter Müller on 30.09.25.
//



// LiveActivityManager.swift
import Foundation
import ActivityKit
import SwiftUI
import os

final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    // Replace with your server base URL (https)
    private let SERVER_BASE_URL = URL(string: "https://fps.cmdline.net")!
    private let logger = Logger(subsystem: "de.poeml.philipp.LibreWrist", category: "LiveActivity")

    // Call this once on app launch if "use live activity" is ON
    func startIfAllowed(useLiveActivities: Bool) {
        guard useLiveActivities else {
            logger.log("Live activities disabled by user setting.")
            return
        }
        startObservingPushToStartTokens()
        observeActivityInstances()
    }

    // MARK: - Push-to-start tokens (Activity.pushToStartTokenUpdates)
    func startObservingPushToStartTokens() {
        if #available(iOS 17.2, *) {
            Task {
                logger.log("Begin observing push-to-start tokens")
                for await tokenData in Activity<FLWatchAttributes>.pushToStartTokenUpdates {
                    let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                    logger.log("Observed push-to-start token: \(tokenHex, privacy: .public)")
                    await uploadPushToStartToken(tokenHex)
                }
            }
        } else {
            logger.log("pushToStartTokenUpdates requires iOS 17.2+; current OS version does not support it.")
        }
    }

    // Uploads push-to-start token + Libre credentials to your server
    func uploadPushToStartToken(_ tokenHex: String) async {
        // read SharedData values (you provided these accessors)
        let region = SharedData.libreLinkUpRegion
        let libreToken = SharedData.libreLinkUpToken
        let userIdHash = SharedData.libreLinkUpUserId.SHA256
        let patientID = SharedData.libreLinkUpPatientId

        guard !tokenHex.isEmpty,
              !region.isEmpty,
              !libreToken.isEmpty,
              !userIdHash.isEmpty,
              !patientID.isEmpty
        else {
            logger.error("Missing required SharedData values; cannot upload push-to-start token.")
            return
        }

        let payload: [String: Any] = [
            "push_to_start_token": tokenHex,
            "libre_region": region,
            "libre_token": libreToken,
            "user_id_hash": userIdHash,
            "patient_ID": patientID,
            "bundle_id": Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
        ]

        do {
            let endpoint = SERVER_BASE_URL.appendingPathComponent("live-activity/register")
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    logger.log("Registered push-to-start token with server.")
                } else {
                    logger.error("Server returned status \(http.statusCode). Body: \(String(data: data, encoding: .utf8) ?? "<no body>")")
                }
            }
        } catch {
            logger.error("Failed uploading push-to-start token: \(error.localizedDescription)")
        }
    }

    // MARK: - Observe Activity instances to get the activity push token (Activity.pushTokenUpdates)
    // Updated observeActivityInstances: after capturing the activity we also monitor its pushTokenUpdates.
    func observeActivityInstances() {
        Task {
            logger.log("Start observing Activity instances (improved)")
            for await activity in Activity<FLWatchAttributes>.activityUpdates {
                logger.log("Observed activity instance: \(activity.id, privacy: .public)")

                // Monitor pushTokenUpdates (non-throwing sequence -> use `for await` without try/catch)
                Task {
                    for await tokenData in activity.pushTokenUpdates {
                        let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                        logger.log("Observed activity push token for activity \(activity.id): \(tokenHex, privacy: .public)")
                        await uploadActivityPushToken(tokenHex, activityId: activity.id, userIdHash: activity.attributes.userIdHash)
                    }
                    // Sequence completed -> treat as removed
                    logger.log("pushTokenUpdates sequence ended for activity \(activity.id, privacy: .public). Treating as removed.")
                    await notifyServerActivityRemoved(activityId: activity.id, userIdHash: activity.attributes.userIdHash)
                }

                // Monitor activity state transitions (active / stale / ended / dismissed)
                Task {
                    for await state in activity.activityStateUpdates {
                        switch state {
                        case .active:
                            logger.log("Activity \(activity.id, privacy: .public) became active.")
                        case .stale:
                            logger.log("Activity \(activity.id, privacy: .public) became stale.")
                            await notifyServerActivityRemoved(activityId: activity.id, userIdHash: activity.attributes.userIdHash)
                        case .ended:
                            logger.log("Activity \(activity.id, privacy: .public) ended.")
                            await notifyServerActivityRemoved(activityId: activity.id, userIdHash: activity.attributes.userIdHash)
                        case .dismissed:
                            logger.log("Activity \(activity.id, privacy: .public) dismissed by user.")
                            await notifyServerActivityRemoved(activityId: activity.id, userIdHash: activity.attributes.userIdHash)
                        @unknown default:
                            logger.log("Activity \(activity.id, privacy: .public) unknown state.")
                        }
                    }
                    logger.log("activityStateUpdates sequence completed for activity \(activity.id, privacy: .public). Notifying server.")
                    await notifyServerActivityRemoved(activityId: activity.id, userIdHash: activity.attributes.userIdHash)
                }
            }
        }
    }

    func uploadActivityPushToken(_ tokenHex: String, activityId: String, userIdHash: String) async {
        let payload: [String: Any] = [
            "activity_id": activityId,
            "activity_push_token": tokenHex,
            "user_id_hash": userIdHash,
            "bundle_id": Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
        ]

        do {
            let endpoint = SERVER_BASE_URL.appendingPathComponent("live-activity/activity-token")
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    logger.log("Uploaded activity push token to server.")
                } else {
                    logger.error("Server returned status \(http.statusCode). Body: \(String(data: data, encoding: .utf8) ?? "<no body>")")
                }
            }
        } catch {
            logger.error("Failed uploading activity push token: \(error.localizedDescription)")
        }
    }

    // Optional helper: request that the system show the Activity (for debug / local start)
    // Updated to use modern async API (await + new label)
    @available(iOS 17.5, *)
    func requestLocalActivityStartIfNeeded(userIdHash: String, initialState: ActivityContent<FLWatchAttributes.ContentState>) {
        let attrs = FLWatchAttributes(userIdHash: userIdHash)
        do {
            let _ = try Activity.request(attributes: attrs, content: initialState, pushType: .token)
            logger.log("Requested local Activity start (debug).")
        } catch {
            logger.error("Local activity request failed: \(error.localizedDescription)")
        }
    }

}

// File: `SharedPhoneWatch/Models/GlucoseActivityManager.swift`
// Summary of changes:
// - Add unregister endpoints and a subscription update endpoint
// - When observing Activity instances, spawn a Task that monitors `activity.pushTokenUpdates`
//   and calls the server when that async sequence completes (Activity ended / removed by user).
// - Provide a single entrypoint to react to user toggling the Live Activity setting or frequent-updates flag.



extension LiveActivityManager {
    // Call when user changes settings (enable/disable live activity or frequent updates).
    // - when disabling, unregister push-to-start token and tell server to stop pushing
    // - when enabling, start the push-to-start observation (already done in startIfAllowed)
    func handleUserSettingsChange(useLiveActivities: Bool, frequentUpdates: Bool) async {
        // notify server about subscription change (server should enable/disable pushes/frequency)
        await updateServerSubscription(enabled: useLiveActivities, frequentUpdates: frequentUpdates)

        if !useLiveActivities {
            // TODO: Previously attempted to read `SharedData.storedPushToStartTokenHex` which does not exist.
            // If you persist the push-to-start token locally, unregister it here:
            // if let tokenHex = <yourStoredToken>, !tokenHex.isEmpty { await unregisterPushToStartToken(tokenHex) }

            // notify server to remove any activity records for this user
            let userHash = SharedData.libreLinkUpUserId.SHA256
            await notifyServerRemoveAllActivities(forUserHash: userHash)

            // optionally end local activities (best-effort)
            for activity in Activity<FLWatchAttributes>.activities {
                if activity.attributes.userIdHash == userHash {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    logger.info("Ended local activity \(activity.id, privacy: .public)")
                }
            }
        } else {
            // if enabling, ensure push-to-start observation is active
            startObservingPushToStartTokens()
            observeActivityInstances() // idempotent; safe to call again
        }
    }

    // POST to inform server to update subscription / frequency preferences
    func updateServerSubscription(enabled: Bool, frequentUpdates: Bool) async {
        let payload: [String: Any] = [
            "user_id_hash": SharedData.libreLinkUpUserId.SHA256,
            "live_activity_enabled": enabled,
            "frequent_updates": frequentUpdates,
            "bundle_id": Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
        ]
        do {
            let endpoint = SERVER_BASE_URL.appendingPathComponent("live-activity/update-subscription")
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    logger.log("Updated server subscription")
                } else {
                    logger.error("Server returned status \(http.statusCode). Body: \(String(data: data, encoding: .utf8) ?? "<no body>")")
                }
            }
        } catch {
            logger.error("Failed updating subscription: \(error.localizedDescription)")
        }
    }

    // Unregister push-to-start token from server
    func unregisterPushToStartToken(_ tokenHex: String) async {
        guard !tokenHex.isEmpty else { return }
        let payload: [String: Any] = [
            "push_to_start_token": tokenHex,
            "user_id_hash": SharedData.libreLinkUpUserId.SHA256,
            "bundle_id": Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
        ]
        do {
            let endpoint = SERVER_BASE_URL.appendingPathComponent("live-activity/unregister-push-to-start")
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    logger.log("Unregistered push-to-start token with server.")
                } else {
                    logger.error("Server returned status \(http.statusCode). Body: \(String(data: data, encoding: .utf8) ?? "<no body>")")
                }
            }
        } catch {
            logger.error("Failed unregistering push-to-start token: \(error.localizedDescription)")
        }
    }

    // Inform server that a given activity has been removed/ended on device
    func notifyServerActivityRemoved(activityId: String, userIdHash: String) async {
        let payload: [String: Any] = [
            "activity_id": activityId,
            "user_id_hash": userIdHash,
            "bundle_id": Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
        ]
        do {
            let endpoint = SERVER_BASE_URL.appendingPathComponent("live-activity/activity-removed")
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    logger.log("Notified server that activity \(activityId, privacy: .public) was removed.")
                } else {
                    logger.error("Server returned status \(http.statusCode). Body: \(String(data: data, encoding: .utf8) ?? "<no body>")")
                }
            }
        } catch {
            logger.error("Failed notifying server about removed activity: \(error.localizedDescription)")
        }
    }

    // Helper to notify server to remove all activities for a user (when user disables live-activities)
    func notifyServerRemoveAllActivities(forUserHash userHash: String) async {
        let payload: [String: Any] = [
            "user_id_hash": userHash,
            "bundle_id": Bundle.main.bundleIdentifier ?? "de.poeml.philipp.LibreWrist"
        ]
        do {
            let endpoint = SERVER_BASE_URL.appendingPathComponent("live-activity/remove-all-for-user")
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    logger.log("Server removed all activities for user.")
                } else {
                    logger.error("Server returned status \(http.statusCode). Body: \(String(data: data, encoding: .utf8) ?? "<no body>")")
                }
            }
        } catch {
            logger.error("Failed notifying server to remove all activities: \(error.localizedDescription)")
        }
    }


}
