//
//  PhoneAppLibre3ConnectView.swift
//  FLwatch
//
//  Connect screen for the Libre 3 direct-BLE provider: pick a pairing mode and
//  hold the sensor to the phone to scan over NFC. Replaces the Phase-1
//  placeholder. Phase 2 captures + stores the BLE credentials; live readings
//  arrive with the BLE engine in Phase 3.
//

#if os(iOS)
import SwiftUI
import UIKit

struct PhoneAppLibre3ConnectView: View {
    @StateObject private var coordinator = Libre3PairingCoordinator()
    @ObservedObject private var directManager = Libre3DirectManager.shared
    @State private var selectedMode: Libre3Mode = .parallelJoin
    @State private var showFreshActivationConfirm = false
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false
    @State private var logEntries: [String] = []
    @State private var notableEntries: [String] = []
    @State private var fullHandshakeRecoveryCount = 0
    @State private var fullHandshakeRecoveryLastSeen: Date?
    @State private var glucoseOnlyDeathCount = 0
    @State private var glucoseOnlyDeathLastSeen: Date?

    /// LibreView patient UUID whose FNV-32a hash is the receiver ID. Persisted
    /// to the app group; read by `Libre3StateStore.receiverID()`.
    @AppStorage(DefaultsKey.libre3LibreViewPatientId.rawValue, store: UserDefaults.group)
    private var libreViewPatientId: String = ""

    /// LibreView (FreeStyle LibreLink) email used to fetch the Account ID.
    @AppStorage(DefaultsKey.libre3LibreViewEmail.rawValue, store: UserDefaults.group)
    private var libreViewEmail: String = ""

    /// Password is a keychain secret, loaded on appear and never persisted in
    /// the app group.
    @State private var libreViewPassword: String = ""
    @State private var isFetchingAccountID = false
    @State private var accountIDFetchError: String?

    /// Takeover / parallel join need a patient ID that matches the activating
    /// account, or the sensor returns 0xB1. Block the scan until it's provided.
    private var patientIdMissingForMode: Bool {
        selectedMode.requiresAlreadyActiveSensor
            && libreViewPatientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            switch coordinator.state {
            case .paired(let serial, let bleAddress, let firmware):
                pairedSection(serial: serial, bleAddress: bleAddress, firmware: firmware)
            default:
                setupSections
            }
            if developerModeEnabled {
                developerNotableEventsSection
                developerLogSection
            }
        }
        .navigationTitle("Libre 3 (Bluetooth)")
        .onAppear {
            // Password is a keychain secret, never the app group — load it into
            // the editable field when the screen opens.
            if libreViewPassword.isEmpty, let stored = try? LibreViewPasswordKeychain.read() {
                libreViewPassword = stored ?? ""
            }
            reloadDiagnosticsLog()
        }
        .onReceive(NotificationCenter.default.publisher(for: .libre3DiagnosticsDidChange)) { _ in
            reloadDiagnosticsLog()
        }
        .confirmationDialog(
            "Activate a new sensor?",
            isPresented: $showFreshActivationConfirm,
            titleVisibility: .visible
        ) {
            Button("Activate (starts wear period)", role: .destructive) {
                startScan(mode: .activateFresh)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This starts the sensor’s wear period—14 days for Libre 3 or 15 days for Libre 3 Plus—and can’t be undone. Most users should activate the sensor in the FreeStyle Libre 3 app instead, then pair it here using Parallel mode.")
        }
    }

    // MARK: - Setup (not yet paired)

    @ViewBuilder
    private var setupSections: some View {
        
        Section {
            
            Text("Parallel mode is recommended. It keeps the sensor’s existing Libre 3 credentials valid, allowing you to switch between FLwatch and the FreeStyle Libre 3 app without scanning the sensor again.\n\nOnly one app should access the sensor at a time. While using FLwatch, force-close the Libre 3 app and turn off Bluetooth access for it in iOS Settings. Otherwise, it may take the sensor connection from FLwatch. Switching apps can take 2–3 minutes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

        } header: {
            Text("Libre 3 BLE notes")
        }
        
        
        Section {
            TextField("LibreView email", text: $libreViewEmail)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(coordinator.state == .scanning || isFetchingAccountID)

            SecureField("LibreView password", text: $libreViewPassword)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(coordinator.state == .scanning || isFetchingAccountID)

            Button {
                fetchAccountID()
            } label: {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text(isFetchingAccountID ? "Getting Account ID…" : "Get Account ID")
                    if isFetchingAccountID {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(
                coordinator.state == .scanning
                    || isFetchingAccountID
                    || libreViewEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || libreViewPassword.isEmpty
            )

            if let accountIDFetchError {
                Label(accountIDFetchError, systemImage: "xmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("Account ID", text: $libreViewPatientId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .disabled(coordinator.state == .scanning || isFetchingAccountID)
        } header: {
            Text("LibreView account")
        } footer: {
            Text("Sign in with the LibreView (FreeStyle Libre 3 app) account that activated this sensor and tap Get Account ID to fill it in automatically. Its hash becomes the receiver ID — takeover and parallel join only work when it matches the activating account, otherwise the sensor rejects pairing (error 0xB1).")
        }

        Section {
            Picker("Pairing mode", selection: $selectedMode) {
                Text("Parallel").tag(Libre3Mode.parallelJoin)
                Text("Take over").tag(Libre3Mode.takeover)
                Text("Fresh").tag(Libre3Mode.activateFresh)
            }
            .pickerStyle(.segmented)
            .disabled(coordinator.state == .scanning)

            Text(modeDescription(selectedMode))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if selectedMode.startsIrreversibleWearClock {
                Label(
                    "Irreversible: starts the sensor’s wear period.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        } header: {
            Text("Pairing mode")
        }

        Section {
            Button {
                if selectedMode.startsIrreversibleWearClock {
                    showFreshActivationConfirm = true
                } else {
                    startScan(mode: selectedMode)
                }
            } label: {
                HStack {
                    Image(systemName: "wave.3.right.circle")
                    Text(coordinator.state == .scanning ? "Scanning…" : "Hold sensor to phone to pair")
                }
            }
            .disabled(coordinator.state == .scanning || patientIdMissingForMode)

            if patientIdMissingForMode {
                Label("Enter your LibreView Patient UUID above first — takeover and parallel join need it.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .failed(let message) = coordinator.state {
                Label(message, systemImage: "xmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            Text("Hold the top of your iPhone against the sensor and keep it still until the scan completes.")
        }

        Section {
            Button {
                Task { await coordinator.readSensorInfo() }
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass.circle")
                    Text("Read sensor info (no changes)")
                }
            }
            .disabled(coordinator.state == .scanning)

            if let info = coordinator.lastScannedInfo {
                LabeledContent("Serial", value: info.serial)
                LabeledContent("Model", value: info.model)
                LabeledContent("Firmware", value: info.firmware)
                LabeledContent("Status", value: info.isFresh ? "New (not activated)" : "Active")
                // Raw NFC state byte (diagnostic).
                LabeledContent("State byte", value: String(format: "0x%02X", info.stateByte))
                if let warmup = info.warmupMinutes {
                    // Warm-up *duration* from the patch frame (Libre 3 = 60 min),
                    // not time remaining — elapsed needs the BLE life count.
                    LabeledContent("Warm-up", value: "\(warmup) min")
                }
                // Total rated lifetime (14 days for Libre 3, 15 for Libre 3 Plus),
                // not elapsed wear — elapsed comes from the BLE life count later.
                // Raw minutes shown too, to see if it's constant (rated) or
                // counts down (remaining).
                LabeledContent("Sensor life", value: "\(sensorLifeText(info.wearDurationMinutes)) (\(info.wearDurationMinutes) min)")
            }
        } header: {
            Text("Check sensor")
        } footer: {
            Text("Reads the sensor's details over NFC without pairing or changing anything — safe to use while the Libre 3 app is running.")
        }
    }

    // MARK: - Paired

    @ViewBuilder
    private func pairedSection(serial: String, bleAddress: String, firmware: String) -> some View {
        Section {
            LabeledContent("Status") {
                Label("Paired", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            }
            if !serial.isEmpty { LabeledContent("Serial", value: serial) }
            if !firmware.isEmpty { LabeledContent("Firmware", value: firmware) }
            if !bleAddress.isEmpty {
                LabeledContent("Bluetooth", value: bleAddress)
                    .font(.caption)
            }
            if let mode = SharedData.libre3Mode {
                LabeledContent("Paired via", value: modeShortName(mode))
            }
            if let sensorEndDate {
                LabeledContent(
                    "Remaining",
                    value: remainingSensorLifeText(until: sensorEndDate, now: Date())
                )
                LabeledContent(
                    "Ends",
                    value: sensorEndDate.formatted(date: .abbreviated, time: .shortened)
                )
            }
        } header: {
            Text("Sensor")
        } footer: {
            Text("Pairing is complete. Keep your phone near the sensor — readings arrive about once a minute over Bluetooth.")
        }

        liveSection

        Section {
            Button(role: .destructive) {
                coordinator.disconnect()
            } label: {
                Text("Disconnect sensor")
            }
        } footer: {
            Text("Forgets this sensor and its stored credentials. You'll need to scan again to re-pair.")
        }
    }

    // MARK: - Live connection (Phase 3)

    private var liveSection: some View {
        Section {
            HStack {
                Image(systemName: liveIcon)
                    .foregroundStyle(liveTint)
                Text(directManager.statusMessage)
                Spacer()
                if let mgdl = directManager.currentGlucoseMgDL,
                   directManager.warmupRemainingMinutes == nil {
                    Text("\(mgdl) mg/dL")
                        .font(.headline)
                        .monospacedDigit()
                }
            }

            if directManager.connectionRequiresUserAction {
                Label(
                    "Repeated sensor authorization failures need your attention.",
                    systemImage: "key.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

                Button("Retry connection") {
                    directManager.retryConnection()
                }
            }

            // Terminal replacement state wins over expiry/warm-up/soft attention
            // so an early-failed sensor never reads as merely expired or warming up.
            if directManager.sensorNeedsReplacement {
                Label("Sensor needs replacing — replace it and pair the new one.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if directManager.sensorIsExpired {
                Label("Sensor expired — replace it and pair the new one.", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let remaining = directManager.warmupRemainingMinutes {
                // The sensor reports unusable readings until warm-up finishes, so
                // we suppress the value and show the countdown instead.
                Label("Warming up — about \(remaining) min left", systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if directManager.sensorAttention == .checkSensor {
                Label("Check sensor", systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Connection")
        }
    }

    private var liveIcon: String {
        if directManager.isInErrorState { return "exclamationmark.triangle.fill" }
        return directManager.connectionState == .streaming
            ? "dot.radiowaves.left.and.right"
            : "antenna.radiowaves.left.and.right"
    }

    private var liveTint: Color {
        if directManager.isInErrorState { return .orange }
        return directManager.connectionState == .streaming ? .green : .secondary
    }

    // MARK: - Developer diagnostics

    private var developerNotableEventsSection: some View {
        Section {
            LabeledContent("Full-handshake recoveries") {
                Text(lifetimeEventSummary(
                    count: fullHandshakeRecoveryCount,
                    lastSeen: fullHandshakeRecoveryLastSeen
                ))
                .multilineTextAlignment(.trailing)
            }

            LabeledContent("Glucose-only deaths") {
                Text(lifetimeEventSummary(
                    count: glucoseOnlyDeathCount,
                    lastSeen: glucoseOnlyDeathLastSeen
                ))
                .multilineTextAlignment(.trailing)
            }

            Button("Reset lifetime stats", role: .destructive) {
                Libre3DiagnosticsLog.resetLifetimeEventStats()
                reloadDiagnosticsLog()
            }
            .buttonStyle(.borderless)

            ScrollView(.vertical) {
                Text(
                    notableEntries.isEmpty
                        ? "No notable events recorded."
                        : notableEntries.joined(separator: "\n")
                )
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(height: 180)
        } header: {
            Text("Notable events")
        } footer: {
            Text("Clear removes retained log lines but leaves the lifetime statistics above. Reset lifetime stats clears only those counts and dates.")
        }
    }

    private var developerLogSection: some View {
        Section {
            HStack {
                Button("Clear", role: .destructive) {
                    Libre3DiagnosticsLog.clearAllLogs()
                    reloadDiagnosticsLog()
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Copy all") {
                    UIPasteboard.general.string = Libre3DiagnosticsLog.fullExportText()
                }
                .buttonStyle(.borderless)
            }

            ScrollView(.vertical) {
                Text(
                    logEntries.isEmpty
                        ? "No diagnostics recorded."
                        : logEntries.joined(separator: "\n")
                )
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(height: 300)
        } header: {
            Text("Developer log")
        }
    }

    private func lifetimeEventSummary(count: Int, lastSeen: Date?) -> String {
        guard let lastSeen else { return "\(count) · never" }
        return "\(count) · last \(lastSeen.formatted(date: .abbreviated, time: .shortened))"
    }

    private func reloadDiagnosticsLog() {
        logEntries = Libre3DiagnosticsLog.mergedEntries()
        notableEntries = Libre3DiagnosticsLog.notableEntries()
        fullHandshakeRecoveryCount = SharedData.libre3FullHandshakeRecoveryCount
        fullHandshakeRecoveryLastSeen = SharedData.libre3FullHandshakeRecoveryLastSeen
        glucoseOnlyDeathCount = SharedData.libre3GlucoseOnlyDeathCount
        glucoseOnlyDeathLastSeen = SharedData.libre3GlucoseOnlyDeathLastSeen
    }

    // MARK: - Actions

    private func startScan(mode: Libre3Mode) {
        Task { await coordinator.pair(mode: mode) }
    }

    /// Look up the LibreView AccountId for the entered credentials and write it
    /// into the Account ID field (persisted via `@AppStorage`). Persists the
    /// email + password too so a later re-fetch needs no re-entry.
    private func fetchAccountID() {
        let email = libreViewEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = libreViewPassword
        guard !email.isEmpty, !password.isEmpty else { return }

        accountIDFetchError = nil
        isFetchingAccountID = true
        libreViewEmail = email
        try? LibreViewPasswordKeychain.save(password)

        Task {
            let result: Result<String, Error>
            do {
                let accountID = try await LibreViewAccountClient().fetchAccountID(
                    email: email, password: password
                )
                result = .success(accountID)
            } catch {
                result = .failure(error)
            }
            await MainActor.run {
                isFetchingAccountID = false
                switch result {
                case .success(let accountID):
                    libreViewPatientId = accountID
                    accountIDFetchError = nil
                case .failure(let error):
                    accountIDFetchError = (error as? LibreViewAccountError)?.errorDescription
                        ?? error.localizedDescription
                }
            }
        }
    }

    // MARK: - Copy

    private func modeDescription(_ mode: Libre3Mode) -> LocalizedStringKey {
        switch mode {
        case .takeover:
            return "Make FLwatch the sensor’s receiver. This invalidates the Libre 3 app’s current connection credentials. While using FLwatch, force-close the Libre 3 app and turn off Bluetooth access for it in iOS Settings.\n\nTo return to Libre 3, force-close FLwatch, re-enable Bluetooth access for Libre 3, and select “Start New Sensor.” The app may warn that this will end your current sensor. Scan the same sensor you are already wearing—the sensor will not be stopped. Libre 3 should recognize it as your current sensor and reconnect. You may also need to sign in to LibreView again before uploads resume."
        case .parallelJoin:
            return "Connect FLwatch without replacing the sensor’s existing Libre 3 credentials. To return to the Libre 3 app, force-close FLwatch, enable Bluetooth access for Libre 3 in iOS Settings, and open the Libre 3 app. It will reconnect without another NFC scan and resume uploading data to LibreView."
        case .activateFresh:
            return "Activate a brand-new, unused sensor directly with FLwatch. This immediately starts the sensor’s wear period and cannot be undone. The LibreView Account ID is optional. If you provide the same Account ID used by the Libre 3 app, Libre 3 should be able to take over the sensor later after an NFC scan, but this has not yet been fully tested. If you leave it empty, FLwatch uses its own receiver ID and transferring the sensor to Libre 3 later may not be possible."
        }
    }

    /// Renders the sensor's rated lifetime: whole days when it divides evenly
    /// (14 days / 15 days), else hours.
    private func sensorLifeText(_ minutes: UInt16) -> String {
        let totalHours = Int(minutes) / 60
        if totalHours > 0, totalHours % 24 == 0 {
            return String(localized: "\(totalHours / 24) days")
        }
        return String(localized: "\(totalHours) h")
    }

    /// Uses the same persisted start anchor and sensor-reported wear duration as
    /// the end-of-life notification schedule.
    private var sensorEndDate: Date? {
        guard let startDate = SharedData.libre3SensorStartDate else { return nil }
        let wearDurationMinutes = SharedData.libre3WearDurationMinutes
        guard wearDurationMinutes > 0 else { return nil }
        return startDate.addingTimeInterval(TimeInterval(wearDurationMinutes) * 60)
    }

    private func remainingSensorLifeText(until endDate: Date, now: Date) -> String {
        let remainingSeconds = endDate.timeIntervalSince(now)
        guard remainingSeconds > 0 else { return String(localized: "Ended") }

        // Round up so the UI does not report zero minutes before the actual end.
        let totalMinutes = Int((remainingSeconds + 59) / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return String(localized: "\(days) d \(hours) h")
        }
        if hours > 0 {
            return String(localized: "\(hours) h \(minutes) min")
        }
        return String(localized: "\(minutes) min")
    }

    private func modeShortName(_ mode: Libre3Mode) -> String {
        switch mode {
        case .takeover: return String(localized: "Take over")
        case .parallelJoin: return String(localized: "Parallel")
        case .activateFresh: return String(localized: "Fresh activation")
        }
    }
}

#Preview {
    PhoneAppLibre3ConnectView()
}

#endif
