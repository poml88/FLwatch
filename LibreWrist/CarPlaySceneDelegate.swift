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
    private var refreshTimer: Timer?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        connect(interfaceController)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        connect(interfaceController)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        disconnect()
    }

    private func connect(_ interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        startObservingUpdates()
        startRefreshTimer()
        updateCarPlayUI(animated: false)
    }

    private func disconnect() {
        stopObservingUpdates()
        stopRefreshTimer()
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

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCarPlayUI(animated: false)
            }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
        let shouldShowSnoozeAction = LowGlucoseNotificationManager.shared.shouldShowSnoozeAction()
        let shouldShowManualRefreshAction = shouldShowManualRefreshAction()

        let glucoseItem = CPListItem(
            text: snapshot.primaryText,
            detailText: snapshot.secondaryText
        )
        glucoseItem.isPlaying = false
        glucoseItem.handler = { _, completion in
            completion()
        }

        let refreshItem = CPListItem(
            text: String(localized: "Tap to refresh now"),
            detailText: String(localized: "Ask FLwatch to fetch the latest glucose reading.")
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

        let snoozeAlertItem = CPListItem(
            text: String(localized: "Snooze low alert for 15 min"),
            detailText: String(localized: "Pause low glucose alerts temporarily.")
        )
        snoozeAlertItem.handler = { [weak self] _, completion in
            Task { @MainActor [weak self] in
                await LowGlucoseNotificationManager.shared.snoozeLowGlucoseAlerts()
                self?.updateCarPlayUI()
                completion()
            }
        }

        let graphInfoItem = CPListItem(
            text: String(localized: "Glucose Graphs in CarPlay"),
            detailText: String(localized: "Use the widget or Live Activity.")
        )
        graphInfoItem.handler = { [weak self] _, completion in
            completion()
            self?.presentGraphInfoAlert()
        }

        let glucoseSection = CPListSection(items: [glucoseItem], header: String(localized: "Current glucose & IOB"), sectionIndexTitle: nil)
        let infoSection = CPListSection(items: [graphInfoItem], header: String(localized: "Info"), sectionIndexTitle: nil)

        var sections = [glucoseSection]
        var actionItems: [CPListItem] = []
        if shouldShowSnoozeAction {
            actionItems.append(snoozeAlertItem)
        }
        if shouldShowManualRefreshAction {
            actionItems.append(refreshItem)
        }
        if !actionItems.isEmpty {
            sections.append(CPListSection(items: actionItems, header: String(localized: "Actions"), sectionIndexTitle: nil))
        }
        sections.append(infoSection)

        let template = CPListTemplate(title: String(localized: "FLwatch"), sections: sections)
        template.tabTitle = String(localized: "FLwatch")
        return template
    }

    private func presentGraphInfoAlert() {
        guard let interfaceController else { return }

        let okAction = CPAlertAction(title: String(localized: "OK"), style: .default) { _ in }
        let alert = CPActionSheetTemplate(
            title: String(localized: "Glucose Graphs in CarPlay"),
            message: String(localized: "Use the FLwatch widget or Live Activity to view the glucose graph."),
            actions: [okAction]
        )
        interfaceController.presentTemplate(alert, animated: true) { _, _ in }
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
                secondaryText: String(localized: "No recent reading available.")
            )
        }

        let minutesAgo = max(Int(now.timeIntervalSince(history.lastReadingDate) / 60), 0)
        let isStale = now.timeIntervalSince(history.lastReadingDate) > 5 * 60
        let trend = history.currentTrendArrow == "---" ? "-" : history.currentTrendArrow
        let glucoseValue = history.currentGlucose.asGlucose(glucoseUnitValue: uom)
        let currentGlucoseText = "\(glucoseValue) \(trend)"
        let primaryText = isStale
            ? String(format: String(localized: "%@ (old)"), currentGlucoseText)
            : currentGlucoseText

        let readingTimeText = history.lastReadingDate.formatted(date: .omitted, time: .shortened)
        let ageText = minutesAgo == 0
            ? String(format: String(localized: "just now (%@)"), readingTimeText)
            : String(format: String(localized: "%dm ago (%@)"), minutesAgo, readingTimeText)
        let iobPrefix: String = {
            guard currentIOB > 0 else { return "" }
            let iobValue = String(format: "%.1f", currentIOB)
            return String(format: String(localized: "IOB %@u • "), iobValue)
        }()
        let secondaryText = "\(iobPrefix)\(ageText) • \(glucoseUnit.description)"

        return Snapshot(
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    private func shouldShowManualRefreshAction(now: Date = Date()) -> Bool {
        guard SharedData.bluetoothHeartbeatEnabled else {
            return true
        }

        let lastHeartbeatDate = SharedData.bluetoothHeartbeatLastEventDate
        guard lastHeartbeatDate.timeIntervalSince1970 > 0 else {
            return true
        }

        return now.timeIntervalSince(lastHeartbeatDate) > 120
    }
}

private extension CarPlaySceneDelegate {
    struct Snapshot {
        let primaryText: String
        let secondaryText: String
    }
}
#endif
