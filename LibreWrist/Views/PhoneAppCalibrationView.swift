//
//  PhoneAppCalibrationView.swift
//  FLwatch
//
//  Optional, prospective-only correction for direct Libre 3 BLE readings.
//  Existing glucose history is intentionally never rewritten.
//

#if os(iOS)
import SwiftUI

struct Libre3CalibrationLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var sensorValueMgDL: Int
    var bloodValueMgDL: Int
    var date: Date

    var differenceMgDL: Int { bloodValueMgDL - sensorValueMgDL }
}

struct PhoneAppCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.libreLinkUpHistory) private var history

    @State private var draftOffsetMgDL: Int
    @State private var entries: [Libre3CalibrationLogEntry]
    @State private var editingEntry: Libre3CalibrationLogEntry?
    @State private var isShowingDeleteAllConfirmation = false
    @State private var statusMessage: String?

    private let glucoseUnit: GlucoseUnit

    init() {
        let currentSerial = SharedData.libre3Serial
        let calibrationBelongsToCurrentSensor = !currentSerial.isEmpty
            && SharedData.libre3CalibrationSensorSerial == currentSerial
        _draftOffsetMgDL = State(
            initialValue: calibrationBelongsToCurrentSensor
                ? SharedData.libre3CalibrationOffsetMgDL
                : 0
        )
        _entries = State(
            initialValue: calibrationBelongsToCurrentSensor
                ? (UserDefaults.group.getArray(forKey: .libre3CalibrationLog) ?? [])
                : []
        )
        glucoseUnit = GlucoseUnit(uom: SensorSettingsStore.shared.sensorSettings.uom)
    }

    private var currentRawMgDL: Int? {
        guard let latest = history.latestLibreLinkUpGlucose,
              latest.glucose.source == "Libre3 BLE" else { return nil }
        return latest.glucose.rawValue / 10
    }

    private var offsetStepMgDL: Int {
        glucoseUnit == .mgdl ? 5 : 2
    }

    private var averageDifferenceMgDL: Double? {
        guard !entries.isEmpty else { return nil }
        return Double(entries.reduce(0) { $0 + $1.differenceMgDL }) / Double(entries.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                warningSection
                offsetSection
                logSection
            }
            .navigationTitle("Sensor calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingEntry) { entry in
                Libre3CalibrationEntryEditorView(
                    entry: entry,
                    glucoseUnit: glucoseUnit,
                    onSave: saveEntry
                )
            }
            .confirmationDialog(
                "Delete all calibration entries?",
                isPresented: $isShowingDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete all", role: .destructive) {
                    entries.removeAll()
                    persistEntries()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var warningSection: some View {
        Section {
            Text("FreeStyle Libre 3 / 3+ sensors are factory calibrated and normally do not require calibration.")
                .font(.headline)

            Text("This setting does not recalibrate the sensor. It applies a local offset only to new glucose readings received by FLwatch. Changes begin with the next received reading and may create a visible step in the graph.")

            Text("Corrected values are used throughout FLwatch, including glucose alerts, Apple Watch, widgets, Live Activities, and Apple Health export.")

            Text("Use this feature at your own risk. If your symptoms do not match the sensor reading or you believe it may be inaccurate, check your glucose with a blood glucose meter and follow the sensor manufacturer's instructions.")
                .foregroundStyle(.secondary)
        } header: {
            Text("Important")
        }
    }

    private var offsetSection: some View {
        Section {
            if let currentRawMgDL {
                LabeledContent(
                    "Current raw sensor value",
                    value: currentRawMgDL.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
                )
            } else {
                Text("A Libre 3 BLE reading is needed before the current raw sensor value can be shown.")
                    .foregroundStyle(.secondary)
            }

            Stepper(
                value: $draftOffsetMgDL,
                in: -30...30,
                step: offsetStepMgDL
            ) {
                LabeledContent("Offset", value: formattedOffset(draftOffsetMgDL))
            }
            .disabled(SharedData.libre3Serial.isEmpty)

            Button("Apply to future readings") {
                applyOffset()
            }
            .disabled(SharedData.libre3Serial.isEmpty)

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Correction")
        } footer: {
            if SharedData.libre3Serial.isEmpty {
                Text("Pair a Libre 3 or Libre 3 Plus sensor before setting an offset.")
            } else {
                Text("Zero disables the correction. Changing this value does not alter readings already stored in the graph.")
            }
        }
    }

    private var logSection: some View {
        Section {
            Button {
                let sensorValue = currentRawMgDL ?? 100
                editingEntry = Libre3CalibrationLogEntry(
                    id: UUID(),
                    sensorValueMgDL: sensorValue,
                    bloodValueMgDL: sensorValue,
                    date: Date()
                )
            } label: {
                Label("Add comparison", systemImage: "plus.circle")
            }
            .disabled(SharedData.libre3Serial.isEmpty)

            ForEach(entries.sorted { $0.date > $1.date }) { entry in
                Button {
                    editingEntry = entry
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            Spacer()
                            Text(formattedDifference(entry.differenceMgDL))
                                .font(.headline)
                        }
                        HStack {
                            Text("Sensor: \(entry.sensorValueMgDL.asGlucose(glucoseUnit: glucoseUnit))")
                            Spacer()
                            Text("Blood: \(entry.bloodValueMgDL.asGlucose(glucoseUnit: glucoseUnit))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        entries.removeAll { $0.id == entry.id }
                        persistEntries()
                    }
                }
            }

            if let averageDifferenceMgDL {
                LabeledContent("Average difference", value: formattedDifference(averageDifferenceMgDL))

                Button("Use average as offset") {
                    draftOffsetMgDL = min(max(Int(averageDifferenceMgDL.rounded()), -30), 30)
                    statusMessage = String(localized: "Average selected. Tap Apply to use it for future readings.")
                }
            }

            if !entries.isEmpty {
                Button("Delete all comparisons", role: .destructive) {
                    isShowingDeleteAllConfirmation = true
                }
            }
        } header: {
            Text("Blood glucose comparisons")
        } footer: {
            Text("Difference is blood value minus the uncorrected sensor value. Tap a row to edit it; swipe to delete it. Entries are cleared when a different sensor is paired.")
        }
    }

    private func applyOffset() {
        let serial = SharedData.libre3Serial
        guard !serial.isEmpty else { return }
        SharedData.libre3CalibrationSensorSerial = serial
        SharedData.libre3CalibrationOffsetMgDL = draftOffsetMgDL
        statusMessage = draftOffsetMgDL == 0
            ? String(localized: "Calibration disabled for future readings.")
            : String(localized: "Saved. The offset applies to the next received reading.")
    }

    private func saveEntry(_ entry: Libre3CalibrationLogEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        persistEntries()
    }

    private func persistEntries() {
        let serial = SharedData.libre3Serial
        guard !serial.isEmpty else { return }
        SharedData.libre3CalibrationSensorSerial = serial
        UserDefaults.group.setArray(entries, forKey: .libre3CalibrationLog)
    }

    private func formattedOffset(_ valueMgDL: Int) -> String {
        formattedDifference(Double(valueMgDL), includeUnit: true)
    }

    private func formattedDifference(_ valueMgDL: Int) -> String {
        formattedDifference(Double(valueMgDL))
    }

    private func formattedDifference(_ valueMgDL: Double, includeUnit: Bool = true) -> String {
        let displayedValue = glucoseUnit == .mmoll
            ? valueMgDL * GlucoseUnit.exchangeRate
            : valueMgDL
        let magnitude = abs(displayedValue).formatted(
            .number.precision(.fractionLength(glucoseUnit == .mmoll ? 1 : 0))
        )
        let sign = displayedValue > 0 ? "+" : displayedValue < 0 ? "−" : ""
        return includeUnit
            ? "\(sign)\(magnitude) \(glucoseUnit.description)"
            : "\(sign)\(magnitude)"
    }
}

private struct Libre3CalibrationEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var sensorValue: Double
    @State private var bloodValue: Double
    @State private var date: Date

    private let id: UUID
    private let glucoseUnit: GlucoseUnit
    private let onSave: (Libre3CalibrationLogEntry) -> Void

    init(
        entry: Libre3CalibrationLogEntry,
        glucoseUnit: GlucoseUnit,
        onSave: @escaping (Libre3CalibrationLogEntry) -> Void
    ) {
        id = entry.id
        self.glucoseUnit = glucoseUnit
        self.onSave = onSave
        _sensorValue = State(initialValue: Self.displayValue(entry.sensorValueMgDL, unit: glucoseUnit))
        _bloodValue = State(initialValue: Self.displayValue(entry.bloodValueMgDL, unit: glucoseUnit))
        _date = State(initialValue: entry.date)
    }

    private var sensorValueMgDL: Int { convertToMgDL(sensorValue) }
    private var bloodValueMgDL: Int { convertToMgDL(bloodValue) }
    private var valuesAreValid: Bool {
        (20...600).contains(sensorValueMgDL) && (20...600).contains(bloodValueMgDL)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Sensor") {
                        HStack(spacing: 4) {
                            TextField(
                                "Sensor value",
                                value: $sensorValue,
                                format: .number.precision(.fractionLength(glucoseUnit == .mmoll ? 1 : 0))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)

                            Text(glucoseUnit.description)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Blood") {
                        HStack(spacing: 4) {
                            TextField(
                                "Blood value",
                                value: $bloodValue,
                                format: .number.precision(.fractionLength(glucoseUnit == .mmoll ? 1 : 0))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)

                            Text(glucoseUnit.description)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DatePicker("Date and time", selection: $date)
                } footer: {
                    if !valuesAreValid {
                        Text("Enter plausible glucose values between 20 and 600 mg/dL (or the equivalent in mmol/L).")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            Libre3CalibrationLogEntry(
                                id: id,
                                sensorValueMgDL: sensorValueMgDL,
                                bloodValueMgDL: bloodValueMgDL,
                                date: date
                            )
                        )
                        dismiss()
                    }
                    .disabled(!valuesAreValid)
                }
            }
        }
    }

    private static func displayValue(_ valueMgDL: Int, unit: GlucoseUnit) -> Double {
        unit == .mmoll ? Double(valueMgDL) * GlucoseUnit.exchangeRate : Double(valueMgDL)
    }

    private func convertToMgDL(_ displayedValue: Double) -> Int {
        let mgDL = glucoseUnit == .mmoll
            ? displayedValue / GlucoseUnit.exchangeRate
            : displayedValue
        return Int(mgDL.rounded())
    }
}

#Preview {
    PhoneAppCalibrationView()
}
#endif
