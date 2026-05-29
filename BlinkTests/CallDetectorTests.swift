import XCTest
@testable import Blink

final class CallDetectorTests: BlinkTestCase {

    override func setUp() async throws {
        try await super.setUp()
        CallDetector.shared.setCallContext(.none)
    }

    override func tearDown() async throws {
        CallDetector.shared.setCallContext(.none)
        try await super.tearDown()
    }

    func testInitialStateIsNone() {
        let detector = CallDetector.shared
        XCTAssertEqual(detector.callContext, .none)
        XCTAssertFalse(detector.isOnCall)
        XCTAssertFalse(detector.isScreenSharing)
    }

    func testOnCallState() {
        let detector = CallDetector.shared
        detector.setCallContext(.onCall)

        XCTAssertEqual(detector.callContext, .onCall)
        XCTAssertTrue(detector.isOnCall)
        XCTAssertFalse(detector.isScreenSharing)
    }

    func testScreenSharingState() {
        let detector = CallDetector.shared
        detector.setCallContext(.screenSharing)

        XCTAssertEqual(detector.callContext, .screenSharing)
        XCTAssertTrue(detector.isOnCall)
        XCTAssertTrue(detector.isScreenSharing)
    }

    func testDisabledCallDetectionPollResetsToNone() {
        let detector = CallDetector.shared
        // Simulate a prior on-call state, then disable detection and poll:
        // the gate must force the context back to .none.
        detector.setCallContext(.onCall)
        Settings.shared.callDetectionEnabled = false

        detector.pollForTesting()

        XCTAssertEqual(detector.callContext, .none)
        XCTAssertFalse(detector.isOnCall)
    }
}
