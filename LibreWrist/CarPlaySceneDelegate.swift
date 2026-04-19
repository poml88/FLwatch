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

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        disconnect()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
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

        let glucoseItem = CPListItem(
            text: snapshot.primaryText,
            detailText: snapshot.secondaryText
        )
        glucoseItem.isPlaying = false
        glucoseItem.handler = { _, completion in
            completion()
        }

        let refreshItem = CPListItem(
            text: "Tap to refresh now",
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

        let graphInfoItem = CPListItem(
            text: "Glucose Graphs in CarPlay",
            detailText: "Use the widget or Live Activity."
        )
        graphInfoItem.handler = { [weak self] _, completion in
            completion()
            self?.presentGraphInfoAlert()
        }

        let glucoseSection = CPListSection(items: [glucoseItem], header: "Current glucose & IOB", sectionIndexTitle: nil)
        let actionsSection = CPListSection(items: [refreshItem], header: "Actions", sectionIndexTitle: nil)
        let infoSection = CPListSection(items: [graphInfoItem], header: "Info", sectionIndexTitle: nil)

        let template = CPListTemplate(title: "FLwatch", sections: [glucoseSection, actionsSection, infoSection])
        template.tabTitle = "FLwatch"
        return template
    }

    private func presentGraphInfoAlert() {
        guard let interfaceController else { return }

        let okAction = CPAlertAction(title: "OK", style: .default) { _ in }
        let alert = CPActionSheetTemplate(
            title: "Glucose Graphs in CarPlay",
            message: "Use the FLwatch widget or Live Activity to view the glucose graph.",
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
                secondaryText: "No recent reading available."
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

        let readingTimeText = history.lastReadingDate.formatted(date: .omitted, time: .shortened)
        let ageText = minutesAgo == 0 ? "just now (\(readingTimeText))" : "\(minutesAgo)m ago (\(readingTimeText))"
        let secondaryText = "\(iobText) • \(ageText) • \(glucoseUnit.description)"

        return Snapshot(
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }
}

private extension CarPlaySceneDelegate {
    struct Snapshot {
        let primaryText: String
        let secondaryText: String
    }
}
#endif
