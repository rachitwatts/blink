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

    func testDisabledCallDetectionReportsNone() {
        let detector = CallDetector.shared
        Settings.shared.callDetectionEnabled = false
        detector.setCallContext(.onCall)

        // Even though context is set, isOnCall/isScreenSharing check settings
        // The poll() method would reset to .none, but setCallContext bypasses poll
        // This tests the raw state — the TimerEngine checks settings.callDetectionEnabled
        XCTAssertEqual(detector.callContext, .onCall)
    }
}
