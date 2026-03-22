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
