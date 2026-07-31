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
    @AppStorage("developerModeEnabled") private var developerModeEnabled = false

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

    // This is deliberately conservative guidance, not a guarantee that blood and
    // interstitial glucose currently match. A short flat stretch can be a plateau
    // within a larger post-meal or post-treatment excursion, so assess both the
    // current trend and the preceding hour before recommending a comparison.
    private static let stabilityWindowSeconds: TimeInterval = 10 * 60
    private static let stabilityWindowGraceSeconds: TimeInterval = 60
    private static let stabilityMinSamples = 7
    private static let stabilityMinEarlySamples = 2
    private static let stabilityEarlySampleAgeSeconds: TimeInterval = 8 * 60
    private static let stabilityMaxLatestSampleAgeSeconds: TimeInterval = 2 * 60
    private static let stabilityMaxRangeMgDL = 7
    private static let stabilityMaxAbsoluteSlopeMgDLPerMinute = 0.5
    private static let recentContextWindowSeconds: TimeInterval = 60 * 60
    private static let recentContextWindowGraceSeconds: TimeInterval = 5 * 60
    private static let recentContextMinCoverageSeconds: TimeInterval = 45 * 60
    private static let recentContextMinSamples = 15
    private static let recentContextMaxRangeMgDL = 25

    private enum StabilityAssessment {
        case steady
        case recentlyChanging
        case unstable
        case insufficientData

        var message: LocalizedStringKey {
            switch self {
            case .steady:
                return "Recent sensor readings look steady. This is usually a better time to compare, but the values may still differ."
            case .recentlyChanging:
                return "Sensor readings are flat now, but glucose changed substantially during the past hour. Wait longer before comparing."
            case .unstable:
                return "Glucose is moving. Wait for a steady stretch before comparing."
            case .insufficientData:
                return "Not enough recent sensor history to assess whether glucose has settled."
            }
        }

        var systemImage: String {
            switch self {
            case .steady: return "checkmark.circle.fill"
            case .recentlyChanging: return "exclamationmark.triangle.fill"
            case .unstable: return "exclamationmark.triangle.fill"
            case .insufficientData: return "clock"
            }
        }

        var tint: Color {
            switch self {
            case .steady: return .green
            case .recentlyChanging: return .orange
            case .unstable: return .orange
            case .insufficientData: return .secondary
            }
        }
    }

    /// Chronological raw (uncorrected) Libre 3 BLE points for the hour-long
    /// context, plus one five-minute boundary interval. The regular history
    /// supplies five-minute points, while the minute history fills the gap between
    /// its newest point and now. The live point appears in both arrays, so
    /// de-duplicate by sensor life-count before assessing it.
    private var recentRawSamples: [(date: Date, valueMgDL: Int)] {
        let cutoff = Date().addingTimeInterval(
            -(Self.recentContextWindowSeconds + Self.recentContextWindowGraceSeconds)
        )
        let points = history.fullLibreLinkUpGlucose + history.libreLinkUpMinuteGlucose
        var samplesByLifeCount: [Int: (date: Date, valueMgDL: Int)] = [:]

        for point in points
        where point.glucose.source == "Libre3 BLE" && point.glucose.date > cutoff {
            let sample = (
                date: point.glucose.date,
                valueMgDL: point.glucose.rawValue / 10
            )
            if let existing = samplesByLifeCount[point.glucose.id],
               existing.date >= sample.date {
                continue
            }
            samplesByLifeCount[point.glucose.id] = sample
        }

        return samplesByLifeCount.values.sorted { $0.date < $1.date }
    }

    private var stabilityAssessment: StabilityAssessment? {
        guard !SharedData.libre3Serial.isEmpty else { return nil }
        let now = Date()
        let contextSamples = recentRawSamples
        let stabilityCutoff = now.addingTimeInterval(-Self.stabilityWindowSeconds)
        let stabilitySupportCutoff = now.addingTimeInterval(
            -(Self.stabilityWindowSeconds + Self.stabilityWindowGraceSeconds)
        )
        let earlySampleCutoff = now.addingTimeInterval(-Self.stabilityEarlySampleAgeSeconds)
        let shortSamples = contextSamples.filter { $0.date > stabilityCutoff }
        let shortAnalysisSamples = contextSamples.filter { $0.date > stabilitySupportCutoff }

        guard shortSamples.count >= Self.stabilityMinSamples,
              shortAnalysisSamples.filter({ $0.date <= earlySampleCutoff }).count >= Self.stabilityMinEarlySamples,
              let latestSample = shortSamples.last,
              now.timeIntervalSince(latestSample.date) <= Self.stabilityMaxLatestSampleAgeSeconds else {
            return .insufficientData
        }

        let shortValues = shortAnalysisSamples.map { $0.valueMgDL }
        let previousValues = shortValues.dropLast().suffix(3)
        guard let previousMedian = Self.median(Array(previousValues)) else {
            return .insufficientData
        }

        // Never smooth away a new turn at the end of the series. Rolling medians
        // are used only to prevent one isolated interior BLE point from deciding
        // the result.
        if abs(Double(latestSample.valueMgDL) - previousMedian) > Double(Self.stabilityMaxRangeMgDL) {
            return .unstable
        }

        guard let shortRange = Self.rollingMedianRange(shortValues),
              shortRange <= Double(Self.stabilityMaxRangeMgDL) else {
            return .unstable
        }

        guard let shortSlope = Self.medianPairwiseSlopeMgDLPerMinute(shortAnalysisSamples),
              abs(shortSlope) <= Self.stabilityMaxAbsoluteSlopeMgDLPerMinute else {
            return .unstable
        }

        guard contextSamples.count >= Self.recentContextMinSamples,
              let oldestContextSample = contextSamples.first,
              now.timeIntervalSince(oldestContextSample.date) >= Self.recentContextMinCoverageSeconds else {
            return .insufficientData
        }

        let contextValues = contextSamples.map { $0.valueMgDL }
        if let contextRange = Self.rollingMedianRange(contextValues),
           contextRange > Double(Self.recentContextMaxRangeMgDL) {
            return .recentlyChanging
        }

        return .steady
    }

    private static func rollingMedianRange(_ values: [Int]) -> Double? {
        guard values.count >= 3 else { return nil }
        let medians = (1..<(values.count - 1)).compactMap { index in
            median(Array(values[(index - 1)...(index + 1)]))
        }
        guard let low = medians.min(), let high = medians.max() else { return nil }
        return high - low
    }

    private static func median(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Double(sorted[middle - 1] + sorted[middle]) / 2
        }
        return Double(sorted[middle])
    }

    /// The median slope between every pair of points (Theil-Sen style) is robust
    /// to one noisy BLE value while still detecting a sustained rise or fall.
    private static func medianPairwiseSlopeMgDLPerMinute(
        _ samples: [(date: Date, valueMgDL: Int)]
    ) -> Double? {
        guard samples.count >= 2 else { return nil }
        var slopes: [Double] = []

        for earlierIndex in 0..<(samples.count - 1) {
            for laterIndex in (earlierIndex + 1)..<samples.count {
                let elapsedMinutes = samples[laterIndex].date.timeIntervalSince(
                    samples[earlierIndex].date
                ) / 60
                guard elapsedMinutes > 0 else { continue }
                let change = Double(
                    samples[laterIndex].valueMgDL - samples[earlierIndex].valueMgDL
                )
                slopes.append(change / elapsedMinutes)
            }
        }

        guard !slopes.isEmpty else { return nil }
        let sorted = slopes.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private var stabilityDiagnosticsText: String {
        let now = Date()
        let contextSamples = recentRawSamples
        let stabilityCutoff = now.addingTimeInterval(-Self.stabilityWindowSeconds)
        let stabilitySupportCutoff = now.addingTimeInterval(
            -(Self.stabilityWindowSeconds + Self.stabilityWindowGraceSeconds)
        )
        let earlySampleCutoff = now.addingTimeInterval(-Self.stabilityEarlySampleAgeSeconds)
        let shortSamples = contextSamples.filter { $0.date > stabilityCutoff }
        let shortAnalysisSamples = contextSamples.filter { $0.date > stabilitySupportCutoff }
        let earlySampleCount = shortAnalysisSamples.filter { $0.date <= earlySampleCutoff }.count
        let latestAgeSeconds = shortSamples.last.map { now.timeIntervalSince($0.date) }
        let contextCoverageSeconds = contextSamples.first.map { now.timeIntervalSince($0.date) }
        let shortRange = Self.rollingMedianRange(shortAnalysisSamples.map { $0.valueMgDL })
        let shortSlope = Self.medianPairwiseSlopeMgDLPerMinute(shortAnalysisSamples)
        let contextRange = Self.rollingMedianRange(contextSamples.map { $0.valueMgDL })

        let latestAgePassed = latestAgeSeconds.map {
            $0 <= Self.stabilityMaxLatestSampleAgeSeconds
        } ?? false
        let contextCoveragePassed = contextCoverageSeconds.map {
            $0 >= Self.recentContextMinCoverageSeconds
        } ?? false
        let shortRangePassed = shortRange.map {
            $0 <= Double(Self.stabilityMaxRangeMgDL)
        } ?? false
        let shortSlopePassed = shortSlope.map {
            abs($0) <= Self.stabilityMaxAbsoluteSlopeMgDLPerMinute
        } ?? false

        var lines = [
            "10m samples: \(debugGate(shortSamples.count >= Self.stabilityMinSamples)) \(shortSamples.count) / >=\(Self.stabilityMinSamples)",
            "8-11m support: \(debugGate(earlySampleCount >= Self.stabilityMinEarlySamples)) \(earlySampleCount) / >=\(Self.stabilityMinEarlySamples)",
            "Newest age: \(debugGate(latestAgePassed)) \(debugMinutes(latestAgeSeconds)) / <=2.0m",
            "Hour samples (<=65m): \(debugGate(contextSamples.count >= Self.recentContextMinSamples)) \(contextSamples.count) / >=\(Self.recentContextMinSamples)",
            "Hour coverage: \(debugGate(contextCoveragePassed)) \(debugMinutes(contextCoverageSeconds)) / >=45.0m",
            "Short median range (<=11m): \(debugGate(shortRangePassed)) \(debugRange(shortRange)) / <=\(Self.stabilityMaxRangeMgDL) mg/dL",
            "Short slope: \(debugGate(shortSlopePassed)) \(debugSlope(shortSlope)) / abs <=\(Self.stabilityMaxAbsoluteSlopeMgDLPerMinute) mg/dL/min",
            "Hour median range (<=65m): \(debugRange(contextRange)) / recent if >\(Self.recentContextMaxRangeMgDL) mg/dL",
            "",
            "Samples (* = last 10m, + = 10-11m support; raw mg/dL):"
        ]

        lines.append(contentsOf: contextSamples.map { sample in
            let marker = sample.date > stabilityCutoff
                ? "*"
                : sample.date > stabilitySupportCutoff ? "+" : " "
            let age = max(0, now.timeIntervalSince(sample.date)) / 60
            let ageText = age.formatted(.number.precision(.fractionLength(1)))
            let time = sample.date.formatted(date: .omitted, time: .standard)
            return "\(marker) \(ageText)m  \(time)  \(sample.valueMgDL)"
        })
        return lines.joined(separator: "\n")
    }

    private func debugGate(_ passed: Bool) -> String {
        passed ? "PASS" : "FAIL"
    }

    private func debugMinutes(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "none" }
        return (seconds / 60).formatted(.number.precision(.fractionLength(1))) + "m"
    }

    private func debugRange(_ range: Double?) -> String {
        guard let range else { return "none" }
        return range.formatted(.number.precision(.fractionLength(1))) + " mg/dL"
    }

    private func debugSlope(_ slope: Double?) -> String {
        guard let slope else { return "none" }
        let sign = slope > 0 ? "+" : slope < 0 ? "−" : ""
        let magnitude = abs(slope).formatted(.number.precision(.fractionLength(2)))
        return sign + magnitude + " mg/dL/min"
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
                    bloodValueMgDL: entries.first(where: { $0.id == entry.id })?.bloodValueMgDL,
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

            Text("Compare only when glucose is reasonably stable; the helper below can guide you. Avoid comparisons while glucose may still be affected by a meal, insulin, exercise, or treatment of a low. Because this correction is a fixed offset, use several steady comparisons near the range that matters to you—for the lower range, about 80–120 mg/dL (4.4–6.7 mmol/L), rather than at a high glucose level.")

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

            if let stabilityAssessment {
                Label(stabilityAssessment.message, systemImage: stabilityAssessment.systemImage)
                    .font(.footnote)
                    .foregroundStyle(stabilityAssessment.tint)
            }

            if developerModeEnabled {
                DisclosureGroup {
                    Text(verbatim: stabilityDiagnosticsText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                } label: {
                    Text(verbatim: "Stability diagnostics")
                }
            }

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
    @State private var bloodValue: Double?
    @State private var date: Date

    private let id: UUID
    private let glucoseUnit: GlucoseUnit
    private let onSave: (Libre3CalibrationLogEntry) -> Void

    init(
        entry: Libre3CalibrationLogEntry,
        bloodValueMgDL: Int?,
        glucoseUnit: GlucoseUnit,
        onSave: @escaping (Libre3CalibrationLogEntry) -> Void
    ) {
        id = entry.id
        self.glucoseUnit = glucoseUnit
        self.onSave = onSave
        _sensorValue = State(initialValue: Self.displayValue(entry.sensorValueMgDL, unit: glucoseUnit))
        _bloodValue = State(
            initialValue: bloodValueMgDL.map { Self.displayValue($0, unit: glucoseUnit) }
        )
        _date = State(initialValue: entry.date)
    }

    private var sensorValueMgDL: Int { convertToMgDL(sensorValue) }
    private var bloodValueMgDL: Int? { bloodValue.map { convertToMgDL($0) } }
    private var valuesAreValid: Bool {
        guard let bloodValueMgDL else { return false }
        return (20...600).contains(sensorValueMgDL) && (20...600).contains(bloodValueMgDL)
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
                    if bloodValue != nil && !valuesAreValid {
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
                        guard let bloodValueMgDL else { return }
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
