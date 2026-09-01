//
//  LibreWristTests.swift
//  LibreWristTests
//
//  Created by Peter Müller on 29.07.24.
//

import XCTest
// Needed only to name `Libre3ReceiverID.Derivation` in the activating-app
// mapping assertions; `@testable import FLwatch` does not re-export it.
import LibreCRKit
@testable import FLwatch

final class LibreWristTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testGlucoseSyncIdentifierIsStable() throws {
        let reading = LibreLinkUpGlucose(
            glucose: Glucose(143, id: 42, date: Date(timeIntervalSince1970: 1_710_000_000), source: "LibreLinkUp"),
            color: .green,
            trendArrow: .stable
        )

        XCTAssertEqual(
            AppleHealthExportManager.glucoseSyncIdentifier(for: reading),
            "librewrist.glucose.1710000000.143"
        )
    }

    func testGlucoseSyncIdentifierSurvivesHistoryRoundTrip() throws {
        // LibreLinkUpHistory persists with these strategies, and `.iso8601` drops
        // the fractional second. An identifier keyed on the *rounded* second would
        // therefore change on the first reload after a cold start and re-export the
        // whole retained window as duplicates.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Libre 3 anchors are `Date() − lifeCount·60`, so every 5-minute point of a
        // sensor's history inherits the same fractional second: the series flips all
        // together, not point by point.
        let anchor = Date(timeIntervalSince1970: 1_786_313_175.73)
        let readings = (0..<3).map { step in
            LibreLinkUpGlucose(
                glucose: Glucose(
                    109,
                    id: step,
                    date: anchor.addingTimeInterval(Double(step) * 300),
                    source: "Libre3 BLE"
                ),
                color: .green,
                trendArrow: .stable
            )
        }

        let restored = try decoder.decode([LibreLinkUpGlucose].self, from: encoder.encode(readings))

        XCTAssertEqual(
            readings.map(AppleHealthExportManager.glucoseSyncIdentifier(for:)),
            restored.map(AppleHealthExportManager.glucoseSyncIdentifier(for:))
        )
    }

    func testGlucoseSyncIdentifierTruncatesTowardTheStoredSecond() throws {
        // Truncation has to be the direction: the persisted copy of a reading is the
        // one that survives, so its identifier is what Apple Health already holds.
        let reading = LibreLinkUpGlucose(
            glucose: Glucose(
                109,
                id: 1,
                date: Date(timeIntervalSince1970: 1_786_313_475.7),
                source: "Libre3 BLE"
            ),
            color: .green,
            trendArrow: .stable
        )

        XCTAssertEqual(
            AppleHealthExportManager.glucoseSyncIdentifier(for: reading),
            "librewrist.glucose.1786313475.109"
        )
    }

    func testInsulinSyncIdentifierIgnoresRecordUUID() throws {
        let first = InsulinDelivery(id: UUID(), timestamp: 1_710_000_000, insulinUnits: 4.5, insulinType: InsulinType.rapidActing.rawValue)
        let second = InsulinDelivery(id: UUID(), timestamp: 1_710_000_000, insulinUnits: 4.5, insulinType: InsulinType.rapidActing.rawValue)

        XCTAssertEqual(
            AppleHealthExportManager.insulinSyncIdentifier(for: first),
            AppleHealthExportManager.insulinSyncIdentifier(for: second)
        )
    }

    private func directBLENightscoutReading(
        lifeCount: Int,
        date: Date,
        value: Int,
        trendArrow: TrendArrow = .notDetermined
    ) -> LibreLinkUpGlucose {
        LibreLinkUpGlucose(
            glucose: Glucose(
                value,
                trendArrow: trendArrow,
                id: lifeCount,
                date: date,
                source: CGMReadingSource.libre3BLE
            ),
            color: .green,
            trendArrow: trendArrow
        )
    }

    func testNightscoutMinuteDiffReturnsCompleteBackfillBurst() {
        let anchor = Date(timeIntervalSince1970: 1_786_313_000)
        let reading: (Int) -> LibreLinkUpGlucose = { lifeCount in
            self.directBLENightscoutReading(
                lifeCount: lifeCount,
                date: anchor.addingTimeInterval(Double(lifeCount * 60)),
                value: 100 + lifeCount % 20
            )
        }
        let previous = [reading(100), reading(116)]
        let next = (100...116).map(reading)

        let changed = LibreLinkUpHistory.changedNightscoutCandidates(
            previous: previous,
            next: next
        )

        XCTAssertEqual(Set(changed.map { $0.glucose.id }), Set(101...115))
    }

    func testNightscoutMinuteDiffIgnoresUnchangedAndRemovalOnlyTransitions() {
        let anchor = Date(timeIntervalSince1970: 1_786_313_000)
        let previous = (100...102).map { lifeCount in
            directBLENightscoutReading(
                lifeCount: lifeCount,
                date: anchor.addingTimeInterval(Double(lifeCount * 60)),
                value: 120
            )
        }

        XCTAssertTrue(
            LibreLinkUpHistory.changedNightscoutCandidates(
                previous: previous,
                next: previous
            ).isEmpty
        )
        XCTAssertTrue(
            LibreLinkUpHistory.changedNightscoutCandidates(
                previous: previous,
                next: Array(previous.dropFirst())
            ).isEmpty
        )
    }

    func testNightscoutMinuteAndHistoricalRevisionShareStableIdentifier() {
        let date = Date(timeIntervalSince1970: 1_786_313_475)
        let historical = directBLENightscoutReading(
            lifeCount: 13_310,
            date: date,
            value: 105
        )
        let minute = directBLENightscoutReading(
            lifeCount: 13_310,
            date: date,
            value: 90
        )
        let historicalUpload = NightscoutEntryUpload(reading: historical)
        let minuteUpload = NightscoutEntryUpload(reading: minute)

        XCTAssertEqual(historicalUpload.identifier, minuteUpload.identifier)
        XCTAssertNotEqual(historicalUpload.fingerprint, minuteUpload.fingerprint)
        XCTAssertEqual(
            LibreLinkUpHistory.changedNightscoutCandidates(
                previous: [historical],
                next: [minute]
            ),
            [minute]
        )
    }

    func testNightscoutMinuteCoverageMergesAdjacentRanges() {
        var coverage = NightscoutMinuteCoverage([100...105, 107...110])

        coverage.insert(106)

        XCTAssertEqual(coverage.coveredMinutes, [100...110])
    }

    func testNightscoutGapWidthMeasuresInclusiveRunLength() {
        let fifteenMinuteGap = NightscoutMinuteCoverage([100...100, 116...120])
        let fourteenMinuteGap = NightscoutMinuteCoverage([100...100, 115...120])

        XCTAssertEqual(
            fifteenMinuteGap.uncoveredRunWidth(containing: 105, batchBounds: 100...120),
            15
        )
        XCTAssertEqual(
            fourteenMinuteGap.uncoveredRunWidth(containing: 105, batchBounds: 100...120),
            14
        )
    }

    func testNightscoutGapWidthBoundsEmptyAndLeadingRunsToBatch() {
        let emptyCoverage = NightscoutMinuteCoverage()
        let leadingCoverage = NightscoutMinuteCoverage([60...70])
        let coverageBeforeBatch = NightscoutMinuteCoverage([100...100])

        XCTAssertEqual(
            emptyCoverage.uncoveredRunWidth(containing: 55, batchBounds: 50...70),
            21
        )
        XCTAssertEqual(
            leadingCoverage.uncoveredRunWidth(containing: 55, batchBounds: 50...70),
            10
        )
        XCTAssertEqual(
            coverageBeforeBatch.uncoveredRunWidth(containing: 155, batchBounds: 150...158),
            9
        )
    }

    func testNightscoutOutboxDecodesPreCoverageSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("nightscout-outbox.json")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let preCoverageSnapshot = Data(
            #"{"schemaVersion":1,"namespaces":{"https://example.com":{"glucoseFingerprints":{},"insulinItems":{}}}}"#.utf8
        )
        try preCoverageSnapshot.write(to: storeURL, options: .atomic)

        let outbox = try NightscoutOutbox(
            fileManager: .default,
            storeURL: storeURL
        )
        let namespace = try NightscoutBaseURL(normalizing: "https://example.com")

        XCTAssertEqual(
            outbox.minuteCoverage(namespace: namespace, sensorSerial: "test-sensor"),
            NightscoutMinuteCoverage()
        )
    }

    func testNightscoutGlucoseCatchUpPersistsOncePerPass() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("nightscout-outbox.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let outbox = try NightscoutOutbox(
            fileManager: .default,
            storeURL: storeURL
        )
        let namespace = try NightscoutBaseURL(normalizing: "https://example.com")
        let startDate = Date()
        let confirmations = (0..<200).map { offset in
            let reading = LibreLinkUpGlucose(
                glucose: Glucose(
                    100 + offset % 40,
                    id: 1_000 + offset,
                    date: startDate.addingTimeInterval(Double(offset * 60)),
                    source: CGMReadingSource.libre3BLE
                ),
                color: .green,
                trendArrow: .stable
            )
            return NightscoutGlucosePassConfirmation(
                upload: NightscoutEntryUpload(reading: reading),
                confirmedAt: startDate
            )
        }

        try outbox.confirmGlucosePass(
            confirmations,
            confirmedMinuteLifeCounts: Set(1_000..<1_200),
            sensorSerial: "test-sensor",
            namespace: namespace,
            persistedAt: startDate
        )

        XCTAssertEqual(outbox.persistenceWriteCount, 1)
        XCTAssertEqual(
            outbox.minuteCoverage(namespace: namespace, sensorSerial: "test-sensor")
                .coveredMinutes,
            [1_000...1_199]
        )
    }

    func testNightscoutMinuteCoverageResetsForNewSensorSerial() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("nightscout-outbox.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let outbox = try NightscoutOutbox(
            fileManager: .default,
            storeURL: storeURL
        )
        let namespace = try NightscoutBaseURL(normalizing: "https://example.com")

        try outbox.confirmGlucosePass(
            [],
            confirmedMinuteLifeCounts: [100, 101],
            sensorSerial: "old-sensor",
            namespace: namespace
        )
        try outbox.confirmGlucosePass(
            [],
            confirmedMinuteLifeCounts: [1, 2],
            sensorSerial: "new-sensor",
            namespace: namespace
        )

        XCTAssertEqual(
            outbox.minuteCoverage(namespace: namespace, sensorSerial: "old-sensor"),
            NightscoutMinuteCoverage()
        )
        XCTAssertEqual(
            outbox.minuteCoverage(namespace: namespace, sensorSerial: "new-sensor")
                .coveredMinutes,
            [1...2]
        )
    }

    func testNightscoutOutboxDecodesPreTreatmentRoutingSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent("nightscout-outbox.json")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let schemaTwoSnapshot = Data(
            #"{"schemaVersion":2,"namespaces":{"https://example.com":{"glucoseFingerprints":{},"insulinItems":{},"minuteCoverage":{"sensorSerial":"sensor","coveredMinutes":[{"lowerBound":1,"upperBound":2}]}}}}"#.utf8
        )
        try schemaTwoSnapshot.write(to: storeURL, options: .atomic)

        let outbox = try NightscoutOutbox(fileManager: .default, storeURL: storeURL)
        let namespace = try NightscoutBaseURL(normalizing: "https://example.com")

        XCTAssertEqual(
            outbox.minuteCoverage(namespace: namespace, sensorSerial: "sensor")
                .coveredMinutes,
            [1...2]
        )
    }

    @MainActor
    func testNightscoutTreatmentDeleteURLRequestsPermanentRemoval() throws {
        let identifier = try XCTUnwrap(
            UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        )
        let client = try NightscoutClientV3(baseURLString: "https://example.com")

        let url = try client.endpointURL(
            pathSegments: [
                "api",
                "v3",
                "treatments",
                identifier.uuidString.lowercased()
            ],
            queryItems: NightscoutClientV3.permanentDeleteQueryItems
        )

        XCTAssertEqual(
            url.absoluteString,
            "https://example.com/api/v3/treatments/11111111-2222-3333-4444-555555555555?permanent=true"
        )
    }

    func testNightscoutDeleteBeforeTreatmentPUTCancelsPendingUpload() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let upload = nightscoutTreatment(identifier: UUID(), eventDate: Date())

        try fixture.outbox.recordPresent(upload, namespace: fixture.namespace)
        let result = try fixture.outbox.recordAbsent(
            identifier: upload.identifier,
            namespace: fixture.namespace
        )

        XCTAssertEqual(result, .cancelledUnstartedUpload)
        XCTAssertNil(fixture.outbox.insulinItem(
            identifier: upload.identifier,
            namespace: fixture.namespace
        ))
        XCTAssertTrue(fixture.outbox.insulinNamespaces(for: upload.identifier).isEmpty)
    }

    func testNightscoutPresentRespectsLocalHistoryRetentionBoundary() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let now = Date(timeIntervalSince1970: 1_786_115_812)
        let retention = InsulinDeliveryHistorySingleton.historyRetentionInterval
        let expired = nightscoutTreatment(
            identifier: UUID(),
            eventDate: now.addingTimeInterval(-retention - 1)
        )
        let retained = nightscoutTreatment(
            identifier: UUID(),
            eventDate: now.addingTimeInterval(-retention + 1)
        )

        try fixture.outbox.recordPresent(
            expired,
            namespace: fixture.namespace,
            now: now
        )

        XCTAssertNil(fixture.outbox.insulinItem(
            identifier: expired.identifier,
            namespace: fixture.namespace
        ))
        XCTAssertEqual(fixture.outbox.persistenceWriteCount, 0)

        try fixture.outbox.recordPresent(
            retained,
            namespace: fixture.namespace,
            now: now
        )

        XCTAssertNotNil(fixture.outbox.insulinItem(
            identifier: retained.identifier,
            namespace: fixture.namespace
        ))
        XCTAssertEqual(fixture.outbox.persistenceWriteCount, 1)
    }

    func testNightscoutPrunesStalePresentItemsButKeepsBoundaryAndTombstone() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let absentNamespace = try NightscoutBaseURL(normalizing: "https://other.example.com")
        let now = Date(timeIntervalSince1970: 1_786_115_812)
        let retention = InsulinDeliveryHistorySingleton.historyRetentionInterval
        let boundaryDate = now.addingTimeInterval(-retention)
        let staleDate = boundaryDate.addingTimeInterval(-1)

        let staleViaPresent = nightscoutTreatment(identifier: UUID(), eventDate: staleDate)
        let retainedViaPresent = nightscoutTreatment(identifier: UUID(), eventDate: boundaryDate)
        let tombstoneUpload = nightscoutTreatment(identifier: UUID(), eventDate: staleDate)
        try fixture.outbox.recordPresent(
            [staleViaPresent, tombstoneUpload],
            namespace: fixture.namespace,
            now: boundaryDate
        )
        let pendingTombstone = try XCTUnwrap(fixture.outbox.insulinItem(
            identifier: tombstoneUpload.identifier,
            namespace: fixture.namespace
        ))
        _ = try fixture.outbox.markUploadAttemptStarted(
            identifier: tombstoneUpload.identifier,
            revision: pendingTombstone.revision,
            namespace: fixture.namespace,
            now: boundaryDate
        )
        XCTAssertEqual(
            try fixture.outbox.recordAbsent(
                identifier: tombstoneUpload.identifier,
                namespace: fixture.namespace,
                now: boundaryDate
            ),
            .queuedDeletion
        )

        try fixture.outbox.recordPresent(
            retainedViaPresent,
            namespace: fixture.namespace,
            now: now
        )

        XCTAssertNil(fixture.outbox.insulinItem(
            identifier: staleViaPresent.identifier,
            namespace: fixture.namespace
        ))
        XCTAssertNotNil(fixture.outbox.insulinItem(
            identifier: retainedViaPresent.identifier,
            namespace: fixture.namespace
        ))
        let retainedTombstone = try XCTUnwrap(fixture.outbox.insulinItem(
            identifier: tombstoneUpload.identifier,
            namespace: fixture.namespace
        ))
        guard case .absent = retainedTombstone.desiredState else {
            return XCTFail("Expected pruning to retain the deletion tombstone")
        }

        let staleViaAbsent = nightscoutTreatment(identifier: UUID(), eventDate: staleDate)
        let retainedViaAbsent = nightscoutTreatment(identifier: UUID(), eventDate: boundaryDate)
        try fixture.outbox.recordPresent(
            [staleViaAbsent, retainedViaAbsent],
            namespace: absentNamespace,
            now: boundaryDate
        )

        XCTAssertEqual(
            try fixture.outbox.recordAbsent(
                identifier: UUID(),
                namespace: absentNamespace,
                now: now
            ),
            .unchanged
        )
        XCTAssertNil(fixture.outbox.insulinItem(
            identifier: staleViaAbsent.identifier,
            namespace: absentNamespace
        ))
        XCTAssertNotNil(fixture.outbox.insulinItem(
            identifier: retainedViaAbsent.identifier,
            namespace: absentNamespace
        ))
    }

    func testNightscoutDeleteAfterTreatmentPUTStartsKeepsTombstone() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let upload = nightscoutTreatment(identifier: UUID(), eventDate: Date())
        try fixture.outbox.recordPresent(upload, namespace: fixture.namespace)
        let pending = try XCTUnwrap(fixture.outbox.insulinItem(
            identifier: upload.identifier,
            namespace: fixture.namespace
        ))
        _ = try fixture.outbox.markUploadAttemptStarted(
            identifier: upload.identifier,
            revision: pending.revision,
            namespace: fixture.namespace
        )

        XCTAssertEqual(
            try fixture.outbox.recordAbsent(
                identifier: upload.identifier,
                namespace: fixture.namespace
            ),
            .queuedDeletion
        )
        let tombstone = try XCTUnwrap(fixture.outbox.insulinItem(
            identifier: upload.identifier,
            namespace: fixture.namespace
        ))
        guard case .absent = tombstone.desiredState else {
            return XCTFail("Expected a durable deletion tombstone")
        }
        XCTAssertFalse(try fixture.outbox.resolveInsulinItem(
            identifier: upload.identifier,
            expectedRevision: pending.revision,
            namespace: fixture.namespace
        ))
        XCTAssertEqual(
            fixture.outbox.insulinItem(
                identifier: upload.identifier,
                namespace: fixture.namespace
            )?.revision,
            tombstone.revision
        )
    }

    func testNightscoutResolvedTreatmentRouteMakesCatchUpNoOp() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        // Exercise precision that ISO-8601 persistence cannot represent so the
        // upload must already be canonical before its outbox round trip.
        let now = Date(timeIntervalSince1970: 1_786_115_812.683_742)
        let upload = nightscoutTreatment(identifier: UUID(), eventDate: now)
        try fixture.outbox.recordPresent(upload, namespace: fixture.namespace, now: now)
        let pending = try XCTUnwrap(fixture.outbox.insulinItem(
            identifier: upload.identifier,
            namespace: fixture.namespace
        ))

        XCTAssertTrue(try fixture.outbox.resolveInsulinItem(
            identifier: upload.identifier,
            expectedRevision: pending.revision,
            namespace: fixture.namespace,
            now: now
        ))
        XCTAssertEqual(
            fixture.outbox.treatmentRoute(
                identifier: upload.identifier,
                namespace: fixture.namespace,
                now: now
            )?.confirmedPayload,
            upload
        )
        let reloadedOutbox = try NightscoutOutbox(
            fileManager: .default,
            storeURL: fixture.directory.appendingPathComponent("nightscout-outbox.json")
        )
        XCTAssertEqual(
            reloadedOutbox.treatmentRoute(
                identifier: upload.identifier,
                namespace: fixture.namespace,
                now: now
            )?.confirmedPayload,
            upload
        )

        try reloadedOutbox.recordPresent(
            upload,
            namespace: fixture.namespace,
            now: now.addingTimeInterval(60)
        )

        XCTAssertNil(reloadedOutbox.insulinItem(
            identifier: upload.identifier,
            namespace: fixture.namespace
        ))
        XCTAssertEqual(reloadedOutbox.persistenceWriteCount, 0)
    }

    func testNightscoutResolvedDeleteRemovesTreatmentRoute() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let now = Date()
        let upload = nightscoutTreatment(identifier: UUID(), eventDate: now)
        try resolveNightscoutTreatment(
            upload,
            in: fixture.outbox,
            namespace: fixture.namespace,
            now: now
        )
        XCTAssertEqual(
            try fixture.outbox.recordAbsent(
                identifier: upload.identifier,
                namespace: fixture.namespace,
                now: now
            ),
            .queuedDeletion
        )
        let deletion = try XCTUnwrap(fixture.outbox.insulinItem(
            identifier: upload.identifier,
            namespace: fixture.namespace
        ))

        XCTAssertTrue(try fixture.outbox.resolveInsulinItem(
            identifier: upload.identifier,
            expectedRevision: deletion.revision,
            namespace: fixture.namespace,
            now: now
        ))
        XCTAssertNil(fixture.outbox.treatmentRoute(
            identifier: upload.identifier,
            namespace: fixture.namespace,
            now: now
        ))
    }

    func testNightscoutTreatmentRoutesRemainURLNamespaced() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let otherNamespace = try NightscoutBaseURL(normalizing: "https://other.example.com")
        let now = Date()
        let upload = nightscoutTreatment(identifier: UUID(), eventDate: now)
        try resolveNightscoutTreatment(
            upload,
            in: fixture.outbox,
            namespace: fixture.namespace,
            now: now
        )
        try resolveNightscoutTreatment(
            upload,
            in: fixture.outbox,
            namespace: otherNamespace,
            now: now
        )

        XCTAssertEqual(
            fixture.outbox.insulinNamespaces(for: upload.identifier, now: now)
                .map(\.absoluteString),
            [fixture.namespace.absoluteString, otherNamespace.absoluteString].sorted()
        )
    }

    func testNightscoutTreatmentRouteExpiresButTombstoneDoesNot() throws {
        let fixture = try makeNightscoutOutboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let now = Date()
        let upload = nightscoutTreatment(identifier: UUID(), eventDate: now)
        try resolveNightscoutTreatment(
            upload,
            in: fixture.outbox,
            namespace: fixture.namespace,
            now: now
        )
        XCTAssertEqual(
            try fixture.outbox.recordAbsent(
                identifier: upload.identifier,
                namespace: fixture.namespace,
                now: now.addingTimeInterval(12 * 60 * 60)
            ),
            .queuedDeletion
        )
        let later = now.addingTimeInterval(14 * 60 * 60)

        XCTAssertNil(fixture.outbox.treatmentRoute(
            identifier: upload.identifier,
            namespace: fixture.namespace,
            now: later
        ))
        XCTAssertNotNil(fixture.outbox.insulinItem(
            identifier: upload.identifier,
            namespace: fixture.namespace
        ))
        XCTAssertEqual(
            fixture.outbox.insulinNamespaces(for: upload.identifier, now: later)
                .map(\.absoluteString),
            [fixture.namespace.absoluteString]
        )
    }

    private func makeNightscoutOutboxFixture() throws -> (
        outbox: NightscoutOutbox,
        namespace: NightscoutBaseURL,
        directory: URL
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outbox = try NightscoutOutbox(
            fileManager: .default,
            storeURL: directory.appendingPathComponent("nightscout-outbox.json")
        )
        return (
            outbox,
            try NightscoutBaseURL(normalizing: "https://example.com"),
            directory
        )
    }

    private func nightscoutTreatment(
        identifier: UUID,
        eventDate: Date,
        units: Double = 2.5
    ) -> NightscoutTreatmentUpload {
        NightscoutTreatmentUpload(delivery: InsulinDelivery(
            id: identifier,
            timestamp: eventDate.timeIntervalSince1970,
            insulinUnits: units,
            insulinType: InsulinType.rapidActing.rawValue
        ))
    }

    private func resolveNightscoutTreatment(
        _ upload: NightscoutTreatmentUpload,
        in outbox: NightscoutOutbox,
        namespace: NightscoutBaseURL,
        now: Date
    ) throws {
        try outbox.recordPresent(upload, namespace: namespace, now: now)
        let pending = try XCTUnwrap(outbox.insulinItem(
            identifier: upload.identifier,
            namespace: namespace
        ))
        XCTAssertTrue(try outbox.resolveInsulinItem(
            identifier: upload.identifier,
            expectedRevision: pending.revision,
            namespace: namespace,
            now: now
        ))
    }

    func testLibreLinkUpParsesFactoryTimestampAsUTC() throws {
        let parsedDate = try XCTUnwrap(
            LibreLinkUp.parseMeasurementDate(
                factoryTimestamp: "3/22/2026 8:05:43 PM",
                timestamp: "3/22/2026 9:05:43 PM"
            )
        )

        XCTAssertEqual(Int(parsedDate.timeIntervalSince1970), 1_774_209_943)
    }

    // MARK: - Libre 3 glucose colors

    func testLibre3GlucoseColorClassificationUsesTargetAndFixedLimits() {
        let settings = SensorSettings(
            uom: 1,
            targetLow: 80,
            targetHigh: 180,
            alarmLow: 70,
            alarmHigh: 250
        )
        let cases: [(value: Int, expected: MeasurementColor)] = [
            (69, .red),
            (70, .yellow),
            (79, .yellow),
            (80, .green),
            (180, .green),
            (181, .yellow),
            (250, .yellow),
            (251, .orange)
        ]

        for testCase in cases {
            XCTAssertEqual(
                Libre3GlucoseMapper.color(forMgDL: testCase.value, settings: settings),
                testCase.expected,
                "Unexpected Libre 3 color for \(testCase.value) mg/dL"
            )
        }
    }

    func testLibre3GlucoseColorClassificationKeepsTargetBoundariesGreen() {
        let settings = SensorSettings(
            uom: 1,
            targetLow: 70,
            targetHigh: 250,
            alarmLow: 70,
            alarmHigh: 250
        )

        XCTAssertEqual(Libre3GlucoseMapper.color(forMgDL: 69, settings: settings), .red)
        XCTAssertEqual(Libre3GlucoseMapper.color(forMgDL: 70, settings: settings), .green)
        XCTAssertEqual(Libre3GlucoseMapper.color(forMgDL: 250, settings: settings), .green)
        XCTAssertEqual(Libre3GlucoseMapper.color(forMgDL: 251, settings: settings), .orange)
    }

    // MARK: - Libre 3 backfill bounds

    func testHistoricalBackfillStartLifeCountBoundsAndAligns() {
        XCTAssertEqual(
            Libre3BackfillImporter.backfillStartLifeCount(
                lastHistoricalLifeCount: nil,
                currentLifeCount: 1_000
            ),
            630
        )
        XCTAssertEqual(
            Libre3BackfillImporter.backfillStartLifeCount(
                lastHistoricalLifeCount: 915,
                currentLifeCount: 1_000
            ),
            915
        )
        XCTAssertEqual(
            Libre3BackfillImporter.backfillStartLifeCount(
                lastHistoricalLifeCount: 917,
                currentLifeCount: 1_000
            ),
            915
        )
        XCTAssertEqual(
            Libre3BackfillImporter.backfillStartLifeCount(
                lastHistoricalLifeCount: nil,
                currentLifeCount: 10
            ),
            5
        )
        // A replacement sensor is seeded with the previous sensor's history, whose
        // life counts it cannot reach for a fortnight. Requesting from there would
        // return an empty burst, so the window bound wins instead.
        XCTAssertEqual(
            Libre3BackfillImporter.backfillStartLifeCount(
                lastHistoricalLifeCount: 20_160,
                currentLifeCount: 61
            ),
            5
        )
        // Equality is an ordinary reconnect with no gap yet, and stays eligible
        // (aligned down to the 5-minute commit grid).
        XCTAssertEqual(
            Libre3BackfillImporter.backfillStartLifeCount(
                lastHistoricalLifeCount: 61,
                currentLifeCount: 61
            ),
            60
        )
    }

    func testClinicalBackfillStartLifeCountBoundsWithoutUnderflow() {
        XCTAssertEqual(
            Libre3BackfillImporter.clinicalBackfillStartLifeCount(
                lastMinuteLifeCount: nil,
                currentLifeCount: 100
            ),
            80
        )
        XCTAssertEqual(
            Libre3BackfillImporter.clinicalBackfillStartLifeCount(
                lastMinuteLifeCount: 95,
                currentLifeCount: 100
            ),
            95
        )
        XCTAssertEqual(
            Libre3BackfillImporter.clinicalBackfillStartLifeCount(
                lastMinuteLifeCount: nil,
                currentLifeCount: 20
            ),
            1
        )
        XCTAssertEqual(
            Libre3BackfillImporter.clinicalBackfillStartLifeCount(
                lastMinuteLifeCount: nil,
                currentLifeCount: 5
            ),
            1
        )
        // Same rejection as the historical bound: the previous sensor's minute
        // resume point falls back to the 20-minute clinical window.
        XCTAssertEqual(
            Libre3BackfillImporter.clinicalBackfillStartLifeCount(
                lastMinuteLifeCount: 20_160,
                currentLifeCount: 81
            ),
            61
        )
        XCTAssertEqual(
            Libre3BackfillImporter.clinicalBackfillStartLifeCount(
                lastMinuteLifeCount: 81,
                currentLifeCount: 81
            ),
            81
        )
    }

    func testClinicalBackfillRequestThresholdIncludesSafetyMinute() {
        XCTAssertFalse(
            Libre3BackfillImporter.shouldRequestClinicalBackfill(
                currentLifeCount: 80,
                warmupMinutes: 60
            )
        )
        XCTAssertTrue(
            Libre3BackfillImporter.shouldRequestClinicalBackfill(
                currentLifeCount: 81,
                warmupMinutes: 60
            )
        )
        XCTAssertTrue(
            Libre3BackfillImporter.shouldRequestClinicalBackfill(
                currentLifeCount: 1_000,
                warmupMinutes: 60
            )
        )
    }

    // MARK: - Libre 3 clinical minute backfill

    func testClinicalBackfillPolicyRejectsWarmupPerRecord() {
        let boundaryDate = Date(timeIntervalSince1970: 10_000)
        let boundary = Libre3ClinicalBackfillPolicy.Boundary(
            lifeCount: 100,
            date: boundaryDate
        )

        XCTAssertEqual(
            Libre3ClinicalBackfillPolicy.disposition(
                recordLifeCount: 59,
                mappedDate: boundaryDate.addingTimeInterval(-60),
                boundary: boundary,
                warmupMinutes: 60
            ),
            .rejectWarmup
        )

        // Even if the sensor emits clinical data when the request threshold has
        // not been reached, each record still enforces warm-up independently.
        XCTAssertFalse(
            Libre3BackfillImporter.shouldRequestClinicalBackfill(
                currentLifeCount: 80,
                warmupMinutes: 60
            )
        )
        let belowThresholdBoundary = Libre3ClinicalBackfillPolicy.Boundary(
            lifeCount: 79,
            date: boundaryDate
        )
        XCTAssertEqual(
            Libre3ClinicalBackfillPolicy.disposition(
                recordLifeCount: 59,
                mappedDate: boundaryDate.addingTimeInterval(-60),
                boundary: belowThresholdBoundary,
                warmupMinutes: 60
            ),
            .rejectWarmup
        )

        // Warm-up remains the fundamental reason even if the same record would
        // also fail the newer-than-boundary check.
        let olderBoundary = Libre3ClinicalBackfillPolicy.Boundary(
            lifeCount: 50,
            date: boundaryDate
        )
        XCTAssertEqual(
            Libre3ClinicalBackfillPolicy.disposition(
                recordLifeCount: 59,
                mappedDate: boundaryDate,
                boundary: olderBoundary,
                warmupMinutes: 60
            ),
            .rejectWarmup
        )
    }

    func testClinicalBackfillPolicyEnforcesRealtimeBoundaryAndDate() {
        let boundaryDate = Date(timeIntervalSince1970: 10_000)
        let boundary = Libre3ClinicalBackfillPolicy.Boundary(
            lifeCount: 100,
            date: boundaryDate
        )

        XCTAssertEqual(
            Libre3ClinicalBackfillPolicy.disposition(
                recordLifeCount: 99,
                mappedDate: boundaryDate.addingTimeInterval(-60),
                boundary: boundary,
                warmupMinutes: 60
            ),
            .accept
        )
        for lifeCount in [UInt16(100), UInt16(101)] {
            XCTAssertEqual(
                Libre3ClinicalBackfillPolicy.disposition(
                    recordLifeCount: lifeCount,
                    mappedDate: boundaryDate.addingTimeInterval(-60),
                    boundary: boundary,
                    warmupMinutes: 60
                ),
                .rejectNotOlder
            )
        }
        for mappedDate in [boundaryDate, boundaryDate.addingTimeInterval(1)] {
            XCTAssertEqual(
                Libre3ClinicalBackfillPolicy.disposition(
                    recordLifeCount: 99,
                    mappedDate: mappedDate,
                    boundary: boundary,
                    warmupMinutes: 60
                ),
                .rejectSkew
            )
        }
    }

    func testClinicalGlucoseMapperRejectsUnavailableAndMapsValidValue() throws {
        let settings = SensorSettings(
            uom: 1,
            targetLow: 80,
            targetHigh: 180,
            alarmLow: 70,
            alarmHigh: 250
        )
        let anchor = Date(timeIntervalSince1970: 1_000)

        XCTAssertNil(
            Libre3GlucoseMapper.makeGlucose(
                fromClinicalLifeCount: 42,
                currentGlucoseMgDL: nil,
                sensorStartDate: anchor,
                settings: settings
            )
        )

        let mapped = try XCTUnwrap(
            Libre3GlucoseMapper.makeGlucose(
                fromClinicalLifeCount: 42,
                currentGlucoseMgDL: 120,
                sensorStartDate: anchor,
                settings: settings,
                calibrationOffsetMgDL: 5
            )
        )
        XCTAssertEqual(mapped.glucose.value, 125)
        XCTAssertEqual(mapped.glucose.id, 42)
        XCTAssertEqual(mapped.glucose.date, anchor.addingTimeInterval(Double(42 * 60)))
        XCTAssertEqual(mapped.glucose.trendArrow, .notDetermined)
        XCTAssertEqual(mapped.glucose.trendRate, 0)
        XCTAssertEqual(mapped.trendArrow, .notDetermined)
    }

    func testClinicalBackfillDuplicatePreservesFirstValue() throws {
        let settings = SensorSettings(
            uom: 1,
            targetLow: 80,
            targetHigh: 180,
            alarmLow: 70,
            alarmHigh: 250
        )
        let anchor = Date(timeIntervalSince1970: 1_000)
        let first = try XCTUnwrap(
            Libre3GlucoseMapper.makeGlucose(
                fromClinicalLifeCount: 42,
                currentGlucoseMgDL: 100,
                sensorStartDate: anchor,
                settings: settings
            )
        )
        let duplicate = try XCTUnwrap(
            Libre3GlucoseMapper.makeGlucose(
                fromClinicalLifeCount: 42,
                currentGlucoseMgDL: 140,
                sensorStartDate: anchor,
                settings: settings
            )
        )
        var buffer: [Int: LibreLinkUpGlucose] = [:]

        XCTAssertTrue(Libre3ClinicalBackfillPolicy.insertFirst(first, into: &buffer))
        XCTAssertFalse(Libre3ClinicalBackfillPolicy.insertFirst(duplicate, into: &buffer))
        XCTAssertEqual(buffer[42]?.glucose.value, 100)
    }

    // MARK: - Libre 3 frozen-value run tracking

    /// Feed a frame and return the outcome, defaulting the raw fields so a test
    /// only states what it is actually varying.
    private func advance(
        _ tracker: inout Libre3StuckGlucoseTracker,
        lifeCount: UInt16,
        word: UInt16 = 0x0100,
        uncappedMgDL: UInt16 = 120
    ) -> Libre3StuckGlucoseTracker.Outcome {
        tracker.advance(lifeCount: lifeCount, word: word, uncappedMgDL: uncappedMgDL)
    }

    private func detectedStuckTracker() -> Libre3StuckGlucoseTracker {
        var tracker = Libre3StuckGlucoseTracker()
        for lifeCount in UInt16(100)...UInt16(105) {
            _ = advance(&tracker, lifeCount: lifeCount)
        }
        return tracker
    }

    func testStuckTrackerReportsEpisodeAfterSixConsecutiveReadings() throws {
        var tracker = Libre3StuckGlucoseTracker()
        XCTAssertEqual(advance(&tracker, lifeCount: 100), .reset)          // seeds
        XCTAssertEqual(advance(&tracker, lifeCount: 101), .advanced(run: 1))
        XCTAssertEqual(advance(&tracker, lifeCount: 102), .advanced(run: 2))
        XCTAssertEqual(advance(&tracker, lifeCount: 103), .advanced(run: 3))
        XCTAssertEqual(advance(&tracker, lifeCount: 104), .advanced(run: 4))
        XCTAssertEqual(advance(&tracker, lifeCount: 105), .episodeDetected(run: 5))
        // Once per episode, not once per frame.
        XCTAssertEqual(advance(&tracker, lifeCount: 106), .advanced(run: 6))
    }

    func testStuckTrackerIgnoresSameMinuteResends() throws {
        var tracker = Libre3StuckGlucoseTracker()
        _ = advance(&tracker, lifeCount: 100)
        XCTAssertEqual(
            advance(&tracker, lifeCount: 100, word: 0x0200, uncappedMgDL: 140),
            .sameMinuteResend
        )
        XCTAssertEqual(tracker.run, 0, "a resend must not inflate the run")
        // The differing resend must not replace the original minute's baseline.
        XCTAssertEqual(advance(&tracker, lifeCount: 101), .advanced(run: 1))
    }

    func testStuckTrackerRejectsUnusableFrames() throws {
        var tracker = Libre3StuckGlucoseTracker()
        _ = advance(&tracker, lifeCount: 100)
        _ = advance(&tracker, lifeCount: 101)
        XCTAssertEqual(tracker.run, 1)

        XCTAssertEqual(
            tracker.advance(
                lifeCount: 102,
                word: 0x0100,
                uncappedMgDL: 120,
                isUsable: false
            ),
            .reset
        )
        XCTAssertEqual(tracker.run, 0)
        // The first clean frame after the blocked value only re-seeds.
        XCTAssertEqual(advance(&tracker, lifeCount: 103), .reset)
    }

    func testStuckTrackerResetsOnGapBackwardsAndChangedValue() throws {
        // A skipped minute breaks the run even though the value is unchanged.
        var gap = Libre3StuckGlucoseTracker()
        _ = advance(&gap, lifeCount: 100)
        _ = advance(&gap, lifeCount: 101)
        XCTAssertEqual(advance(&gap, lifeCount: 103), .reset)
        XCTAssertEqual(gap.run, 0)

        // A backwards frame does too.
        var backwards = Libre3StuckGlucoseTracker()
        _ = advance(&backwards, lifeCount: 100)
        _ = advance(&backwards, lifeCount: 101)
        XCTAssertEqual(advance(&backwards, lifeCount: 100), .reset)

        // So does a changed value on an otherwise adjacent minute.
        var changed = Libre3StuckGlucoseTracker()
        _ = advance(&changed, lifeCount: 100)
        _ = advance(&changed, lifeCount: 101)
        XCTAssertEqual(advance(&changed, lifeCount: 102, word: 0x0200), .reset)
    }

    /// The display value is capped at 39/501, so two different raw words can map
    /// to the same mg/dL. Both fields must match for the run to advance.
    func testStuckTrackerRequiresBothWordAndUncappedToMatch() throws {
        var wordOnly = Libre3StuckGlucoseTracker()
        _ = advance(&wordOnly, lifeCount: 100, word: 0x0100, uncappedMgDL: 501)
        XCTAssertEqual(
            advance(&wordOnly, lifeCount: 101, word: 0x0100, uncappedMgDL: 520),
            .reset
        )

        var uncappedOnly = Libre3StuckGlucoseTracker()
        _ = advance(&uncappedOnly, lifeCount: 100, word: 0x0100, uncappedMgDL: 120)
        XCTAssertEqual(
            advance(&uncappedOnly, lifeCount: 101, word: 0x0180, uncappedMgDL: 120),
            .reset
        )
    }

    /// A recovered value must re-arm the episode report, otherwise a sensor that
    /// freezes twice only ever produces one notable event.
    func testStuckTrackerReportsASecondEpisodeAfterRecovery() throws {
        var tracker = Libre3StuckGlucoseTracker()
        for lifeCount in UInt16(100)...UInt16(105) {
            _ = advance(&tracker, lifeCount: lifeCount)
        }
        XCTAssertEqual(tracker.run, 5)

        // Value changes: the completed episode is reported and its latch clears.
        XCTAssertEqual(
            advance(&tracker, lifeCount: 106, word: 0x0200),
            .episodeEnded(run: 5, reason: .valueChanged)
        )

        for lifeCount in UInt16(107)...UInt16(110) {
            _ = advance(&tracker, lifeCount: lifeCount, word: 0x0200)
        }
        XCTAssertEqual(
            advance(&tracker, lifeCount: 111, word: 0x0200),
            .episodeDetected(run: 5)
        )
    }

    func testStuckTrackerReportsUncertainEpisodeEndReasons() throws {
        var gap = detectedStuckTracker()
        XCTAssertEqual(
            advance(&gap, lifeCount: 107),
            .episodeEnded(run: 5, reason: .lifeCountGap)
        )

        var backwards = detectedStuckTracker()
        XCTAssertEqual(
            advance(&backwards, lifeCount: 104),
            .episodeEnded(run: 5, reason: .lifeCountBackwards)
        )

        var unusable = detectedStuckTracker()
        XCTAssertEqual(
            unusable.advance(
                lifeCount: 106,
                word: 0x0100,
                uncappedMgDL: 120,
                isUsable: false
            ),
            .episodeEnded(run: 5, reason: .unusableReading)
        )
    }

    func testStuckTrackerResetClearsRunAndSeed() throws {
        var tracker = Libre3StuckGlucoseTracker()
        _ = advance(&tracker, lifeCount: 100)
        _ = advance(&tracker, lifeCount: 101)
        XCTAssertEqual(tracker.run, 1)

        tracker.reset()
        XCTAssertEqual(tracker.run, 0)
        // Post-reset the next frame only re-seeds, so an adjacent minute carrying
        // the old value cannot resume the previous run.
        XCTAssertEqual(advance(&tracker, lifeCount: 102), .reset)
    }

    // MARK: - Libre 3 disconnect handoff

    func testDidConnectAdoptsWhenDisconnectHandoffIsInactive() throws {
        let policy = Libre3DisconnectHandoffPolicy()

        XCTAssertEqual(policy.connectedAdoptionDecision, .adopt)
    }

    func testPeerConnectedAdoptsWhenDisconnectHandoffIsInactive() throws {
        let policy = Libre3DisconnectHandoffPolicy()

        XCTAssertEqual(policy.connectedAdoptionDecision, .adopt)
    }

    func testConnectedCallbacksAreIgnoredDuringDisconnectHandoff() throws {
        var policy = Libre3DisconnectHandoffPolicy()
        policy.begin()

        XCTAssertEqual(
            policy.connectedAdoptionDecision,
            .ignorePendingDisconnect
        )
        // `didConnect` and `.peerConnected` share this same acceptance policy.
        XCTAssertEqual(
            policy.connectedAdoptionDecision,
            .ignorePendingDisconnect
        )
    }

    func testIgnoredConnectedCallbackDoesNotClearDisconnectHandoff() throws {
        var policy = Libre3DisconnectHandoffPolicy()
        policy.begin()

        _ = policy.connectedAdoptionDecision

        XCTAssertTrue(policy.isWaitingForDisconnect)
    }

    func testOnlyMatchingDisconnectClearsDisconnectHandoff() throws {
        var policy = Libre3DisconnectHandoffPolicy()
        policy.begin()

        XCTAssertFalse(policy.completeDisconnect(matchesTarget: false))
        XCTAssertTrue(policy.isWaitingForDisconnect)
        XCTAssertTrue(policy.completeDisconnect(matchesTarget: true))
        XCTAssertFalse(policy.isWaitingForDisconnect)
    }

    func testCompletedDisconnectHandoffRearmsOnlyOnce() throws {
        var policy = Libre3DisconnectHandoffPolicy()
        policy.begin()

        // Only the first matching completion can re-arm lifecycle work.
        XCTAssertTrue(policy.completeDisconnect(matchesTarget: true))
        XCTAssertFalse(policy.completeDisconnect(matchesTarget: true))
        XCTAssertEqual(policy.connectedAdoptionDecision, .adopt)
    }

    func testNewDisconnectHandoffInvalidatesEarlierGeneration() throws {
        var policy = Libre3DisconnectHandoffPolicy()
        let firstGeneration = policy.begin()
        let secondGeneration = policy.begin()

        XCTAssertFalse(policy.isCurrent(firstGeneration))
        XCTAssertTrue(policy.isCurrent(secondGeneration))
    }

    func testResetInvalidatesDisconnectHandoffGeneration() throws {
        var policy = Libre3DisconnectHandoffPolicy()
        let generation = policy.begin()

        policy.reset()

        XCTAssertFalse(policy.isCurrent(generation))
        XCTAssertFalse(policy.isWaitingForDisconnect)
        XCTAssertEqual(policy.connectedAdoptionDecision, .adopt)
    }

    func testConnectIntentIsRequestedOnlyWhenDisconnected() throws {
        XCTAssertTrue(
            Libre3ConnectIntentPolicy.shouldRequestConnect(for: .disconnected)
        )
        XCTAssertFalse(
            Libre3ConnectIntentPolicy.shouldRequestConnect(for: .connecting)
        )
        XCTAssertFalse(
            Libre3ConnectIntentPolicy.shouldRequestConnect(for: .connected)
        )
        XCTAssertFalse(
            Libre3ConnectIntentPolicy.shouldRequestConnect(for: .disconnecting)
        )
    }

    func testDisconnectHandoffRecoveryCompletesForMissingPeripheral() throws {
        XCTAssertEqual(
            Libre3DisconnectHandoffRecoveryPolicy.action(for: nil),
            .completeAndRearm
        )
    }

    func testDisconnectHandoffRecoveryCompletesWhenDisconnected() throws {
        XCTAssertEqual(
            Libre3DisconnectHandoffRecoveryPolicy.action(for: .disconnected),
            .completeAndRearm
        )
    }

    func testDisconnectHandoffRecoveryRetriesCancellationForActiveStates() throws {
        XCTAssertEqual(
            Libre3DisconnectHandoffRecoveryPolicy.action(for: .connecting),
            .retryCancellation
        )
        XCTAssertEqual(
            Libre3DisconnectHandoffRecoveryPolicy.action(for: .connected),
            .retryCancellation
        )
        XCTAssertEqual(
            Libre3DisconnectHandoffRecoveryPolicy.action(for: .disconnecting),
            .retryCancellation
        )
    }

    // MARK: - Libre 3 post-auth re-arm

    func testPostAuthRearmPlanHasSevenUniqueCharacteristics() throws {
        let plan = Libre3PostAuthRearmPlan.standard

        XCTAssertEqual(plan.characteristics.count, 7)
        XCTAssertEqual(Set(plan.characteristics).count, 7)
    }

    func testPostAuthRearmPlanContainsEveryDataPlaneCharacteristic() throws {
        let plan = Libre3PostAuthRearmPlan.standard

        for characteristic in Libre3PostAuthRearmPlan.dataPlaneCharacteristics {
            XCTAssertTrue(plan.characteristics.contains(characteristic))
        }
    }

    func testPostAuthRearmPlanAddsBothBackfillResponseCharacteristics() throws {
        let plan = Libre3PostAuthRearmPlan.standard

        for characteristic in Libre3PostAuthRearmPlan.responseCharacteristics {
            XCTAssertTrue(plan.characteristics.contains(characteristic))
        }
    }

    func testPostAuthRearmPlanForcesTheSameSevenCharacteristics() throws {
        let plan = Libre3PostAuthRearmPlan.standard

        XCTAssertEqual(plan.forceReArm, Set(plan.characteristics))
    }

    func testBackfillWaitsForRearmAndUsableGlucose() throws {
        XCTAssertFalse(
            Libre3BackfillReadiness(
                rearmCompleted: false,
                usableGlucoseReceived: false
            ).canRequestBackfill
        )
        XCTAssertFalse(
            Libre3BackfillReadiness(
                rearmCompleted: true,
                usableGlucoseReceived: false
            ).canRequestBackfill
        )
        XCTAssertFalse(
            Libre3BackfillReadiness(
                rearmCompleted: false,
                usableGlucoseReceived: true
            ).canRequestBackfill
        )
    }

    func testBackfillStartsAfterRearmAndUsableGlucose() throws {
        let readiness = Libre3BackfillReadiness(
            rearmCompleted: true,
            usableGlucoseReceived: true
        )

        XCTAssertTrue(readiness.canRequestBackfill)
    }

    // MARK: - Libre 3 no-stream diagnostics

    func testOneNoStreamAttemptOnlyIncrementsCounter() throws {
        var tracker = Libre3NoStreamCycleTracker()

        XCTAssertFalse(tracker.finishAttempt(producedUsableGlucose: false))
        XCTAssertEqual(tracker.cycles, 1)
    }

    func testThirdNoStreamAttemptProducesWarningOnly() throws {
        var tracker = Libre3NoStreamCycleTracker()

        XCTAssertFalse(tracker.finishAttempt(producedUsableGlucose: false))
        XCTAssertFalse(tracker.finishAttempt(producedUsableGlucose: false))
        XCTAssertTrue(tracker.finishAttempt(producedUsableGlucose: false))
        XCTAssertEqual(tracker.cycles, 3)
    }

    func testTenNoStreamAttemptsProduceOnlyOneWarning() throws {
        var tracker = Libre3NoStreamCycleTracker()
        var warningCount = 0

        for _ in 1...10 {
            if tracker.finishAttempt(producedUsableGlucose: false) {
                warningCount += 1
            }
        }

        XCTAssertEqual(tracker.cycles, 10)
        XCTAssertEqual(warningCount, 1)
    }

    func testUsableGlucoseResetsNoStreamCounter() throws {
        var tracker = Libre3NoStreamCycleTracker()
        _ = tracker.finishAttempt(producedUsableGlucose: false)
        _ = tracker.finishAttempt(producedUsableGlucose: false)

        tracker.recordUsableGlucose()

        XCTAssertEqual(tracker.cycles, 0)
    }

    // MARK: - Libre 3 sensor-not-responding hint

    func testSensorSilenceRunOpensWithoutReporting() throws {
        let now = Date()

        let opened = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: nil,
            failureCount: 0,
            now: now,
            notificationAlreadySubmitted: false
        )

        XCTAssertEqual(opened.runStartedAt, now)
        XCTAssertEqual(opened.failureCount, 1)
        XCTAssertFalse(opened.shouldReport)
    }

    func testSensorSilenceDurationAloneDoesNotReport() throws {
        // The false positive the count gate exists for: one silent attempt, hours
        // out of range (attempts that never connect leave the clock running), then
        // one more silent attempt. Old enough, but only two observed failures.
        let now = Date()

        let evaluation = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: now.addingTimeInterval(-6 * 3600),
            failureCount: 1,
            now: now,
            notificationAlreadySubmitted: false
        )

        XCTAssertEqual(evaluation.failureCount, 2)
        XCTAssertFalse(evaluation.shouldReport)
    }

    func testSensorSilenceCountAloneDoesNotReport() throws {
        // The dense run the duration gate exists for: `reconnectBackoff` retries
        // the first three failures immediately, so the count is reached long
        // before a marginal link has had a chance to recover.
        let now = Date()

        let evaluation = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: now.addingTimeInterval(-60),
            failureCount: Libre3SensorNotRespondingPolicy.minimumFailures,
            now: now,
            notificationAlreadySubmitted: false
        )

        XCTAssertGreaterThan(
            evaluation.failureCount,
            Libre3SensorNotRespondingPolicy.minimumFailures
        )
        XCTAssertFalse(evaluation.shouldReport)
    }

    func testSensorSilenceReportsOnceWhenBothThresholdsMet() throws {
        let now = Date()
        let start = now.addingTimeInterval(-Libre3SensorNotRespondingPolicy.minimumRunDuration)
        let priorFailures = Libre3SensorNotRespondingPolicy.minimumFailures - 1

        let crossing = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: start,
            failureCount: priorFailures,
            now: now,
            notificationAlreadySubmitted: false
        )
        XCTAssertTrue(crossing.shouldReport)

        // Every later failure in the same run keeps the hint, never re-posts it.
        let repeated = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: start,
            failureCount: crossing.failureCount,
            now: now.addingTimeInterval(600),
            notificationAlreadySubmitted: true
        )
        XCTAssertEqual(repeated.runStartedAt, start)
        XCTAssertFalse(repeated.shouldReport)
    }

    func testSensorSilenceRetriesUntilNotificationIsSubmitted() throws {
        let now = Date()
        let start = now.addingTimeInterval(-Libre3SensorNotRespondingPolicy.minimumRunDuration)

        // A post lost to suspension, or one `add` threw on, leaves the flag false.
        // Later failures in the same run must ask again rather than assume the
        // first attempt landed — otherwise one lost task silences the whole outage.
        let retry = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: start,
            failureCount: Libre3SensorNotRespondingPolicy.minimumFailures + 3,
            now: now,
            notificationAlreadySubmitted: false
        )

        XCTAssertTrue(retry.shouldReport)
    }

    func testStaleFailureCountWithoutRunStartOpensFreshRun() throws {
        let now = Date()

        // A count with no run start is not a run, however large it is.
        let evaluation = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: nil,
            failureCount: 99,
            now: now,
            notificationAlreadySubmitted: false
        )

        XCTAssertEqual(evaluation.failureCount, 1)
        XCTAssertFalse(evaluation.shouldReport)
    }

    func testOnlyAuthStageNotifyTimeoutsQualify() throws {
        let notifyTimeout = SensorSessionTransportError.notifyTimeout(
            characteristic: "08982198-EF89-11E9-81B4-2A2AE2DBCCE4",
            seconds: 2
        )

        XCTAssertTrue(
            Libre3SensorNotRespondingPolicy.qualifies(stage: "auth", error: notifyTimeout)
        )
        // The same silence after the handshake is a data-plane problem.
        XCTAssertFalse(
            Libre3SensorNotRespondingPolicy.qualifies(stage: "streaming", error: notifyTimeout)
        )
        // A link that dropped mid-handshake is not a sensor that stayed silent.
        XCTAssertFalse(
            Libre3SensorNotRespondingPolicy.qualifies(
                stage: "auth",
                error: SensorSessionTransportError.notifyStreamEnded(have: 0, want: 23)
            )
        )
        XCTAssertFalse(Libre3SensorNotRespondingPolicy.qualifies(stage: "auth", error: nil))
    }

    func testFutureRunStartRestartsSensorSilenceRun() throws {
        let now = Date()

        // A persisted start ahead of the clock (time zone / clock correction)
        // must not defer the hint forever.
        let evaluation = Libre3SensorNotRespondingPolicy.evaluate(
            runStartedAt: now.addingTimeInterval(3600),
            failureCount: Libre3SensorNotRespondingPolicy.minimumFailures,
            now: now,
            notificationAlreadySubmitted: false
        )

        XCTAssertEqual(evaluation.runStartedAt, now)
        XCTAssertEqual(evaluation.failureCount, 1)
        XCTAssertFalse(evaluation.shouldReport)
    }

    // MARK: - Libre 3 skipped-CCCD tracing

    // These cover the parser only. The inputs are hand-copied from
    // `SensorSession`, so they do NOT protect the cross-module contract: a
    // reworded log line in LibreCRKit leaves these passing while production
    // tracing stops. See the note on `Libre3CCCDSkipLog`.
    func testConnectTimeHandshakeCCCDSkipIsTraced() throws {
        let uuid = LibreSensorGATT.Char.secCommandResponse.uuidString

        XCTAssertEqual(
            Libre3CCCDSkipLog.handshakeSkipTraceLine(
                for: "setNotifyValue: skipping \(uuid) — already notifying"
            ),
            "cccd-skip char=command"
        )
    }

    func testSetNotifyNoOpOnHandshakeCharacteristicIsTraced() throws {
        let uuid = LibreSensorGATT.Char.secChallengeData.uuidString

        XCTAssertEqual(
            Libre3CCCDSkipLog.handshakeSkipTraceLine(
                for: "setNotify: \(uuid) already on — no CCCD write"
            ),
            "cccd-skip char=challenge"
        )
    }

    func testDataPlaneCCCDSkipIsNotTraced() throws {
        // Data-plane characteristics are armed after the handshake and have their
        // own re-arm handling, so their skips say nothing about a silent auth.
        let uuid = LibreSensorGATT.Char.glucoseData.uuidString

        XCTAssertNil(
            Libre3CCCDSkipLog.handshakeSkipTraceLine(
                for: "setNotifyValue: skipping \(uuid) — already notifying"
            )
        )
    }

    func testSkippedCCCDDisableIsNotTraced() throws {
        // A skipped disable leaves the characteristic armed — harmless, and not
        // evidence of anything.
        let uuid = LibreSensorGATT.Char.secCommandResponse.uuidString

        XCTAssertNil(
            Libre3CCCDSkipLog.handshakeSkipTraceLine(
                for: "setNotify: \(uuid) already off — no CCCD write"
            )
        )
    }

    func testUnrelatedBLETimingLinesAreNotTraced() throws {
        let uuid = LibreSensorGATT.Char.secCommandResponse.uuidString

        XCTAssertNil(
            Libre3CCCDSkipLog.handshakeSkipTraceLine(
                for: "setNotify: \(uuid) writing setNotifyValue(true) — awaiting ack (timeout 10s)"
            )
        )
        XCTAssertNil(
            Libre3CCCDSkipLog.handshakeSkipTraceLine(
                for: "discoverAndSubscribe: complete in 812ms (all notify subs already on)"
            )
        )
    }

    // MARK: - Libre 3 peripheral discovery

    func testKnownPeripheralUsesRetrievedPathAfterManyNoStreamAttempts() throws {
        var tracker = Libre3NoStreamCycleTracker()
        for _ in 1...10 {
            _ = tracker.finishAttempt(producedUsableGlucose: false)
        }
        var connectedLookupCount = 0

        let selection = Libre3PeripheralDiscoveryPolicy.select(
            retrieveSaved: { "saved" },
            retrieveConnected: {
                connectedLookupCount += 1
                return "connected"
            }
        )

        guard case .retrieved(let value) = selection else {
            return XCTFail("Expected the retrieved-peripheral path")
        }
        XCTAssertEqual(value, "saved")
        XCTAssertEqual(connectedLookupCount, 0)
        XCTAssertEqual(tracker.cycles, 10)
    }

    func testConnectedPeripheralIsUsedWhenSavedLookupMisses() throws {
        let selection = Libre3PeripheralDiscoveryPolicy.select(
            retrieveSaved: { nil as String? },
            retrieveConnected: { "connected" }
        )

        guard case .alreadyConnected(let value) = selection else {
            return XCTFail("Expected the already-connected path")
        }
        XCTAssertEqual(value, "connected")
    }

    func testMissingPeripheralFallsThroughToScan() throws {
        let selection = Libre3PeripheralDiscoveryPolicy.select(
            retrieveSaved: { nil as String? },
            retrieveConnected: { nil as String? }
        )

        guard case .scan = selection else {
            return XCTFail("Expected the scan path")
        }
    }

    func testPeripheralCandidateIsReturnedOnlyAfterAuthentication() throws {
        let candidate = UUID()
        var tracker = Libre3PeripheralBindingTracker()

        tracker.recordCandidate(candidate)

        XCTAssertEqual(tracker.candidateID, candidate)
        XCTAssertNil(tracker.authenticatedCandidate(UUID()))
        XCTAssertEqual(tracker.authenticatedCandidate(candidate), candidate)
        XCTAssertNil(tracker.candidateID)
    }

    // MARK: - Libre 3 glucose silence recovery

    func testGlucoseSilenceRearmsAfterThreshold() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertTrue(
            Libre3GlucoseSilenceRecoveryPolicy.shouldRearm(
                now: now,
                lastGlucoseAt: now.addingTimeInterval(-151),
                lastAttemptAt: nil,
                isWarmingUp: false,
                isExpired: false,
                needsReplacement: false
            )
        )
    }

    func testGlucoseSilenceRecoveryWaitsDuringWarmupAndRetryThrottle() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let quietSince = now.addingTimeInterval(-300)

        XCTAssertFalse(
            Libre3GlucoseSilenceRecoveryPolicy.shouldRearm(
                now: now,
                lastGlucoseAt: quietSince,
                lastAttemptAt: nil,
                isWarmingUp: true,
                isExpired: false,
                needsReplacement: false
            )
        )
        XCTAssertFalse(
            Libre3GlucoseSilenceRecoveryPolicy.shouldRearm(
                now: now,
                lastGlucoseAt: quietSince,
                lastAttemptAt: now.addingTimeInterval(-149),
                isWarmingUp: false,
                isExpired: false,
                needsReplacement: false
            )
        )
    }

    // MARK: - Libre 3 awaiting first reading

    /// Anchor + 60 min warm-up, matching a Libre 3's NFC-reported cycle.
    private func awaitingFirstReading(
        atMinutesAfterAnchor minutes: Double,
        firstReadingAt: Date? = nil,
        isExpired: Bool = false,
        needsReplacement: Bool = false,
        hasConnectionError: Bool = false,
        sensorStartDate: Date? = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> Bool {
        Libre3AwaitingFirstReadingPolicy.isAwaitingFirstReading(
            now: Date(timeIntervalSince1970: 1_800_000_000).addingTimeInterval(minutes * 60),
            sensorStartDate: sensorStartDate,
            warmupMinutes: 60,
            firstReadingAt: firstReadingAt,
            isExpired: isExpired,
            needsReplacement: needsReplacement,
            hasConnectionError: hasConnectionError
        )
    }

    func testAwaitingFirstReadingSpansWarmupEndUntilTheFirstValue() throws {
        // During warm-up the countdown owns the UI, so this must stay quiet.
        XCTAssertFalse(awaitingFirstReading(atMinutesAfterAnchor: 59))
        // The lifecycle clock ends warm-up exactly here, a minute before the
        // sensor's first displayable frame.
        XCTAssertTrue(awaitingFirstReading(atMinutesAfterAnchor: 60))
        XCTAssertTrue(awaitingFirstReading(atMinutesAfterAnchor: 60.5))
        XCTAssertTrue(awaitingFirstReading(atMinutesAfterAnchor: 61))
    }

    func testAwaitingFirstReadingEndsOnceAReadingHasArrived() throws {
        let anchor = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertFalse(
            awaitingFirstReading(
                atMinutesAfterAnchor: 61,
                firstReadingAt: anchor.addingTimeInterval(61 * 60)
            )
        )
    }

    /// A sensor that never delivers must fall through to the normal stale-data
    /// warning rather than reading as "about to work" forever.
    func testAwaitingFirstReadingStopsAtTheWindowCutoff() throws {
        XCTAssertTrue(awaitingFirstReading(atMinutesAfterAnchor: 69.9))
        XCTAssertFalse(awaitingFirstReading(atMinutesAfterAnchor: 70))
        XCTAssertFalse(awaitingFirstReading(atMinutesAfterAnchor: 120))
    }

    /// Bluetooth-off clears the warm-up countdown while leaving the anchor and the
    /// nil first-reading date intact, so without the connection-error check this
    /// would claim the sensor is ready over a dead radio. Expiry and replacement
    /// own their own UI for the same reason.
    func testAwaitingFirstReadingYieldsToTransportAndLifecycleFaults() throws {
        XCTAssertFalse(awaitingFirstReading(atMinutesAfterAnchor: 61, hasConnectionError: true))
        XCTAssertFalse(awaitingFirstReading(atMinutesAfterAnchor: 61, isExpired: true))
        XCTAssertFalse(awaitingFirstReading(atMinutesAfterAnchor: 61, needsReplacement: true))
        // No anchor means the sensor's lifecycle is not yet classified.
        XCTAssertFalse(awaitingFirstReading(atMinutesAfterAnchor: 61, sensorStartDate: nil))
    }

    // MARK: - Libre 3 reconnect escalation

    func testTransportFailuresNeverTriggerAuthenticationEscalation() throws {
        var tracker = Libre3ReconnectFailureTracker()

        for _ in 1...10 {
            XCTAssertFalse(tracker.recordFailure(.transport))
        }

        XCTAssertEqual(tracker.overallFailures, 10)
        XCTAssertEqual(tracker.authenticationFailures, 0)
    }

    func testSixAuthenticationFailuresTriggerEscalation() throws {
        var tracker = Libre3ReconnectFailureTracker()

        for _ in 1..<Libre3ReconnectFailureTracker.authenticationEscalationThreshold {
            XCTAssertFalse(tracker.recordFailure(.credential))
        }

        XCTAssertTrue(tracker.recordFailure(.credential))
        XCTAssertFalse(tracker.recordFailure(.transport))
        XCTAssertFalse(tracker.recordFailure(.credential))
    }

    func testTransportFailureDoesNotConsumeOrResetAuthenticationSequence() throws {
        var tracker = Libre3ReconnectFailureTracker()
        _ = tracker.recordFailure(.credential)
        _ = tracker.recordFailure(.credential)

        _ = tracker.recordFailure(.transport)

        XCTAssertEqual(tracker.authenticationFailures, 2)
    }

    func testAuthorizationSuccessClearsAuthenticationFailureRun() throws {
        var tracker = Libre3ReconnectFailureTracker()
        _ = tracker.recordFailure(.credential)

        tracker.recordAuthorizationSucceeded()

        XCTAssertEqual(tracker.authenticationFailures, 0)
        XCTAssertEqual(tracker.overallFailures, 1)
    }

    func testAuthorizationRecoveryUsesOneFullFallbackOnThirdAttempt() throws {
        let expected: [Libre3AuthorizationPath] = [
            .cached, .cached, .full, .cached, .cached, .cached,
        ]

        let actual = (0..<6).map {
            Libre3AuthorizationRecoveryPolicy.path(
                hasReconnectKey: true,
                authenticationFailures: $0
            )
        }

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(
            Libre3AuthorizationRecoveryPolicy.path(
                hasReconnectKey: true,
                authenticationFailures: 6
            ),
            .cached
        )
        XCTAssertEqual(
            Libre3AuthorizationRecoveryPolicy.path(
                hasReconnectKey: false,
                authenticationFailures: 2
            ),
            .full
        )
    }

    func testOnlyChallengeLoadDoneWriteDisconnectIsCredentialShaped() throws {
        XCTAssertEqual(
            Libre3AuthorizationRecoveryPolicy.challengeLoadDoneDisconnectCategory(
                phase5WriteCompleted: false
            ),
            .transport
        )
        XCTAssertEqual(
            Libre3AuthorizationRecoveryPolicy.challengeLoadDoneDisconnectCategory(
                phase5WriteCompleted: true
            ),
            .credential
        )
    }

    // MARK: - Libre 3 patch-control sequence

    func testPatchControlSequenceAdvancesAndResets() throws {
        var sequence = Libre3PatchControlSequence()

        XCTAssertEqual(sequence.next(), 1)
        XCTAssertEqual(sequence.next(), 2)

        sequence.reset()

        XCTAssertEqual(sequence.next(), 1)
    }

    func testLibreLinkUpFallsBackToOffsetTimestamp() throws {
        let parsedDate = try XCTUnwrap(
            LibreLinkUp.parseMeasurementDate(
                factoryTimestamp: nil,
                timestamp: "2026-03-22T21:05:43+01:00"
            )
        )

        XCTAssertEqual(Int(parsedDate.timeIntervalSince1970), 1_774_209_943)
    }

    // MARK: - Libre 3 activating app

    /// `Libre3ActivatingApp.usesLibreViewAccount` and its phone-side `derivation`
    /// answer the same question — does this app fold a LibreView Account ID into a
    /// receiver ID — but can't be one property: the enum is shared code compiled
    /// into the watch and widget targets, which don't link LibreCRKit and so can't
    /// name `Libre3ReceiverID.Derivation`.
    ///
    /// A case added to one switch but not the other makes
    /// `Libre3StateStore.receiverID()` throw `invalidReceiverIDConfiguration` for
    /// a perfectly valid app, blocking pairing. Comments drift; this doesn't.
    func testActivatingAppAccountUseMatchesDerivation() throws {
        // Exact, not just present: a mapping that swapped the two vendor apps
        // would satisfy the consistency loop below while sending each sensor the
        // other app's receiver ID.
        XCTAssertEqual(Libre3ActivatingApp.freeStyleLibre3.derivation, .freeStyleLibre3)
        XCTAssertEqual(Libre3ActivatingApp.libreByAbbott.derivation, .libreByAbbott)
        XCTAssertNil(Libre3ActivatingApp.flwatchOnly.derivation)

        for app in Libre3ActivatingApp.allCases {
            XCTAssertEqual(
                app.usesLibreViewAccount,
                app.derivation != nil,
                "\(app.rawValue): usesLibreViewAccount and derivation disagree"
            )
        }
    }

    /// Known-answer vectors for both folds, so moving the arithmetic into
    /// LibreCRKit can't quietly change what goes on the wire.
    ///
    /// The expected values were computed from the implementation that shipped in
    /// build 202 (commit 8fdc80a), before either fold moved to the package — the
    /// identity assertions above can't catch this, since they stay true even if
    /// the package's arithmetic changes underneath them. A sensor only ever
    /// accepts the ID it was activated with, so a drift here strands every
    /// already-paired sensor until its wear ends.
    ///
    /// Goes through `receiverIDPreview` deliberately: it is what the connect
    /// screen displays, so this pins the readout and the wire value together.
    func testReceiverIDFoldsMatchTheShippedValues() throws {
        // Throwaway UUID in LibreView's format (lowercase, dashed, 36 chars).
        let accountID = "3f2b7c10-9a4d-4e21-8b56-0c1d2e3f4a5b"

        XCTAssertEqual(
            Libre3StateStore.receiverIDPreview(forAccountID: accountID, activatingApp: .freeStyleLibre3),
            "0xb063dfc1 / c1df63b0"
        )
        XCTAssertEqual(
            Libre3StateStore.receiverIDPreview(forAccountID: accountID, activatingApp: .libreByAbbott),
            "0x27bff6bc / bcf6bf27"
        )

        // Both folds lowercase first, so an Account ID pasted in upper case still
        // reaches the sensor as the same value. LibreView issues them lowercase;
        // this guards the normalization, not a case we expect to see.
        XCTAssertEqual(
            Libre3StateStore.receiverIDPreview(forAccountID: accountID.uppercased(), activatingApp: .freeStyleLibre3),
            "0xb063dfc1 / c1df63b0"
        )
        XCTAssertEqual(
            Libre3StateStore.receiverIDPreview(forAccountID: accountID.uppercased(), activatingApp: .libreByAbbott),
            "0x27bff6bc / bcf6bf27"
        )
    }

}
