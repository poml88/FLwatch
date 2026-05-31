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

struct PhoneAppLibre3ConnectView: View {
    @StateObject private var coordinator = Libre3PairingCoordinator()
    @State private var selectedMode: Libre3Mode = .takeover
    @State private var showFreshActivationConfirm = false

    /// LibreView patient UUID whose FNV-32a hash is the receiver ID. Persisted
    /// to the app group; read by `Libre3StateStore.receiverID()`.
    @AppStorage(DefaultsKey.libre3LibreViewPatientId.rawValue, store: UserDefaults.group)
    private var libreViewPatientId: String = ""

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
        }
        .navigationTitle("Libre 3 (Bluetooth)")
        .confirmationDialog(
            "Activate a new sensor?",
            isPresented: $showFreshActivationConfirm,
            titleVisibility: .visible
        ) {
            Button("Activate (starts 14-day clock)", role: .destructive) {
                startScan(mode: .activateFresh)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This starts the sensor's 14-day wear clock and can't be undone. Most users should activate the sensor in the FreeStyle Libre 3 app instead, then take it over here.")
        }
    }

    // MARK: - Setup (not yet paired)

    @ViewBuilder
    private var setupSections: some View {
        Section {
            TextField("LibreView Patient UUID", text: $libreViewPatientId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .disabled(coordinator.state == .scanning)
        } header: {
            Text("LibreView account")
        } footer: {
            Text("The patient UUID of the LibreView account that activated this sensor. Its hash becomes the receiver ID — takeover and parallel join only work when it matches the activating account, otherwise the sensor rejects pairing (error 0xB1).")
        }

        Section {
            Picker("Pairing mode", selection: $selectedMode) {
                Text("Take over").tag(Libre3Mode.takeover)
                Text("Parallel").tag(Libre3Mode.parallelJoin)
                Text("Fresh").tag(Libre3Mode.activateFresh)
            }
            .pickerStyle(.segmented)
            .disabled(coordinator.state == .scanning)

            Text(modeDescription(selectedMode))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if selectedMode.isExperimental {
                Label(
                    "Experimental. Whether the Libre app keeps working depends on your sensor's firmware. Opens a second, independent session.",
                    systemImage: "flask"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
            if selectedMode.startsIrreversibleWearClock {
                Label(
                    "Irreversible: starts the sensor's 14-day wear clock.",
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
        } header: {
            Text("Sensor")
        } footer: {
            Text("Pairing is complete. Live glucose over Bluetooth is being built — it isn't streaming yet.")
        }

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

    // MARK: - Actions

    private func startScan(mode: Libre3Mode) {
        Task { await coordinator.pair(mode: mode) }
    }

    // MARK: - Copy

    private func modeDescription(_ mode: Libre3Mode) -> LocalizedStringKey {
        switch mode {
        case .takeover:
            return "Take over a sensor you already started in the Libre 3 app. FLwatch becomes the sensor's receiver; the Libre app and LibreView sharing stop. Recommended."
        case .parallelJoin:
            return "Join a sensor you already started in the Libre 3 app without taking it over, so the Libre app and LibreView keep working alongside FLwatch."
        case .activateFresh:
            return "Activate a brand-new, unused sensor with FLwatch. With a LibreView Patient ID above, the sensor stays tied to that account (LibreView keeps working); without one it's activated with a random receiver — FLwatch-only, no LibreView."
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

    private func modeShortName(_ mode: Libre3Mode) -> String {
        switch mode {
        case .takeover: return String(localized: "Take over")
        case .parallelJoin: return String(localized: "Parallel")
        case .activateFresh: return String(localized: "Fresh activation")
        }
    }
}
#endif
