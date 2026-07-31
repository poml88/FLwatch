//
//  LibreWristTests.swift
//  LibreWristTests
//
//  Created by Peter Müller on 29.07.24.
//

import XCTest
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

    func testInsulinSyncIdentifierIgnoresRecordUUID() throws {
        let first = InsulinDelivery(id: UUID(), timestamp: 1_710_000_000, insulinUnits: 4.5, insulinType: InsulinType.rapidActing.rawValue)
        let second = InsulinDelivery(id: UUID(), timestamp: 1_710_000_000, insulinUnits: 4.5, insulinType: InsulinType.rapidActing.rawValue)

        XCTAssertEqual(
            AppleHealthExportManager.insulinSyncIdentifier(for: first),
            AppleHealthExportManager.insulinSyncIdentifier(for: second)
        )
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
        for lifeCount in UInt16(100)...UInt16(104) {
            _ = advance(&tracker, lifeCount: lifeCount)
        }
        return tracker
    }

    func testStuckTrackerReportsEpisodeAfterFourAdvancingRepeats() throws {
        var tracker = Libre3StuckGlucoseTracker()
        XCTAssertEqual(advance(&tracker, lifeCount: 100), .reset)          // seeds
        XCTAssertEqual(advance(&tracker, lifeCount: 101), .advanced(run: 1))
        XCTAssertEqual(advance(&tracker, lifeCount: 102), .advanced(run: 2))
        XCTAssertEqual(advance(&tracker, lifeCount: 103), .advanced(run: 3))
        XCTAssertEqual(advance(&tracker, lifeCount: 104), .episodeDetected(run: 4))
        // Once per episode, not once per frame.
        XCTAssertEqual(advance(&tracker, lifeCount: 105), .advanced(run: 5))
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
        for lifeCount in UInt16(100)...UInt16(104) {
            _ = advance(&tracker, lifeCount: lifeCount)
        }
        XCTAssertEqual(tracker.run, 4)

        // Value changes: the completed episode is reported and its latch clears.
        XCTAssertEqual(
            advance(&tracker, lifeCount: 105, word: 0x0200),
            .episodeEnded(run: 4, reason: .valueChanged)
        )

        for lifeCount in UInt16(106)...UInt16(108) {
            _ = advance(&tracker, lifeCount: lifeCount, word: 0x0200)
        }
        XCTAssertEqual(
            advance(&tracker, lifeCount: 109, word: 0x0200),
            .episodeDetected(run: 4)
        )
    }

    func testStuckTrackerReportsUncertainEpisodeEndReasons() throws {
        var gap = detectedStuckTracker()
        XCTAssertEqual(
            advance(&gap, lifeCount: 106),
            .episodeEnded(run: 4, reason: .lifeCountGap)
        )

        var backwards = detectedStuckTracker()
        XCTAssertEqual(
            advance(&backwards, lifeCount: 103),
            .episodeEnded(run: 4, reason: .lifeCountBackwards)
        )

        var unusable = detectedStuckTracker()
        XCTAssertEqual(
            unusable.advance(
                lifeCount: 105,
                word: 0x0100,
                uncappedMgDL: 120,
                isUsable: false
            ),
            .episodeEnded(run: 4, reason: .unusableReading)
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

}
