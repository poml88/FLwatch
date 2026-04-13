//
//  CarPlaySceneDelegate.swift
//  FLwatch
//

#if os(iOS)
import CarPlay
import Foundation
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private weak var interfaceController: CPInterfaceController?
    private var observers: [NSObjectProtocol] = []

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        startObservingUpdates()
        updateCarPlayUI(animated: false)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        stopObservingUpdates()
        self.interfaceController = nil
    }

    private func startObservingUpdates() {
        guard observers.isEmpty else { return }

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .libreWristDataDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateCarPlayUI()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateCarPlayUI()
                }
            }
        )
    }

    private func stopObservingUpdates() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func updateCarPlayUI(animated: Bool = true) {
        guard let interfaceController else { return }

        LibreLinkUpHistory.shared.refreshFromPersistence(force: true)
        SensorSettingsStore.shared.refreshFromPersistence(force: true)
        InsulinDeliveryHistorySingleton.shared.read()
        CurrentIOBSingleton.shared.updateCurrentIOBAndGraphs()

        let template = makeRootTemplate()
        interfaceController.setRootTemplate(template, animated: animated) { _, _ in }
    }

    private func makeRootTemplate() -> CPTemplate {
        let snapshot = makeSnapshot()

        let glucoseItem = CPListItem(
            text: snapshot.primaryText,
            detailText: snapshot.secondaryText
        )
        glucoseItem.isPlaying = false

        let statusItem = CPListItem(
            text: snapshot.statusTitle,
            detailText: snapshot.statusDetail
        )

        let refreshItem = CPListItem(
            text: "Refresh now",
            detailText: "Ask FLwatch to fetch the latest glucose reading."
        )
        refreshItem.handler = { [weak self] _, completion in
            Task { @MainActor [weak self] in
                _ = await LibreLinkUpService.shared.requestReloadIfNeeded(maxAgeMinutes: 1, force: true)
                await LowGlucoseNotificationManager.shared.evaluateCurrentReading()
                await LiveActivityManager.shared.refreshFromCurrentHistory(
                    useLiveActivities: SharedData.useLiveActivities,
                    reloadFailed: LibreLinkUpService.shared.didLastReloadFail
                )
                self?.updateCarPlayUI()
                completion()
            }
        }

        let infoSection = CPListSection(items: [glucoseItem, statusItem], header: "Glucose", sectionIndexTitle: nil)
        let actionsSection = CPListSection(items: [refreshItem], header: "Actions", sectionIndexTitle: nil)

        let template = CPListTemplate(title: "FLwatch", sections: [infoSection, actionsSection])
        template.tabTitle = "FLwatch"
        return template
    }

    private func makeSnapshot(now: Date = Date()) -> Snapshot {
        let history = LibreLinkUpHistory.shared
        let uom = SensorSettingsStore.shared.sensorSettings.uom
        let currentIOB = CurrentIOBSingleton.shared.currentIOB
        let glucoseUnit = GlucoseUnit(uom: uom)

        guard history.currentGlucose > 0,
              history.lastReadingDate > .distantPast else {
            return Snapshot(
                primaryText: "--",
                secondaryText: "No recent reading available.",
                statusTitle: "Status",
                statusDetail: "FLwatch has not loaded a glucose value yet."
            )
        }

        let minutesAgo = max(Int(now.timeIntervalSince(history.lastReadingDate) / 60), 0)
        let isStale = now.timeIntervalSince(history.lastReadingDate) > 5 * 60
        let trend = history.currentTrendArrow == "---" ? "-" : history.currentTrendArrow
        let glucoseValue = history.currentGlucose.asGlucose(glucoseUnitValue: uom)
        let primaryText = isStale ? "\(glucoseValue) \(trend) (old)" : "\(glucoseValue) \(trend)"

        let iobText: String = {
            guard currentIOB >= 0 else { return "IOB -.-u" }
            return "IOB \(String(format: "%.1f", currentIOB))u"
        }()

        let ageText = minutesAgo == 0 ? "just now" : "\(minutesAgo)m ago"
        let secondaryText = "\(iobText) • \(ageText) • \(glucoseUnit.description)"

        let statusDetail: String
        if LibreLinkUpService.shared.didLastReloadFail {
            statusDetail = "Last reload failed. Showing cached data from \(ageText)."
        } else if isStale {
            statusDetail = "Reading is stale. Last value was seen \(ageText)."
        } else {
            statusDetail = "Reading is current. Last value was seen \(ageText)."
        }

        return Snapshot(
            primaryText: primaryText,
            secondaryText: secondaryText,
            statusTitle: "Status",
            statusDetail: statusDetail
        )
    }
}

private extension CarPlaySceneDelegate {
    struct Snapshot {
        let primaryText: String
        let secondaryText: String
        let statusTitle: String
        let statusDetail: String
    }
}
#endif
