import XCTest
@testable import Blink

/// Tests for TimerState enum computed properties
final class TimerStateTests: XCTestCase {

    // MARK: - isActive Tests

    func testWorkRunningIsActive() {
        XCTAssertTrue(TimerState.workRunning.isActive)
    }

    func testWorkPausedIsNotActive() {
        XCTAssertFalse(TimerState.workPaused.isActive)
    }

    func testBreakRunningIsActive() {
        XCTAssertTrue(TimerState.breakRunning.isActive)
    }

    func testSnoozeRunningIsActive() {
        XCTAssertTrue(TimerState.snoozeRunning.isActive)
    }

    // MARK: - shouldShowOverlay Tests

    func testBreakRunningShouldShowOverlay() {
        XCTAssertTrue(TimerState.breakRunning.shouldShowOverlay)
    }

    func testWorkRunningDoesNotShowOverlay() {
        XCTAssertFalse(TimerState.workRunning.shouldShowOverlay)
    }

    func testWorkPausedDoesNotShowOverlay() {
        XCTAssertFalse(TimerState.workPaused.shouldShowOverlay)
    }

    func testSnoozeDoesNotShowOverlay() {
        XCTAssertFalse(TimerState.snoozeRunning.shouldShowOverlay)
    }
}
