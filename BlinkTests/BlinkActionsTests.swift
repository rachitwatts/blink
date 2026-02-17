import XCTest
@testable import Blink

/// Tests for BlinkActions dispatcher
@MainActor
final class BlinkActionsTests: XCTestCase {

    // MARK: - Properties

    var mockIdle: MockIdleTimeProvider!

    // MARK: - Setup

    override func setUp() async throws {
        // Reset state before each test
        AppState.shared.reset()
        Settings.shared.resetToDefaults()

        // Inject mock idle time provider
        mockIdle = MockIdleTimeProvider()
        TimerEngine.shared.setIdleDetector(mockIdle)

        // Reset engine internal state (shouldResetOnNextActivity)
        TimerEngine.shared.restartSession()
    }

    override func tearDown() async throws {
        // Clean up after each test
        TimerEngine.shared.stop()
        AppState.shared.reset()
    }

    // MARK: - Take Break Tests

    func testTakeBreakDuringWork() {
        let appState = AppState.shared

        // Initial state is workRunning
        XCTAssertEqual(appState.timerState, .workRunning)

        let result = BlinkActions.execute(.takeBreak)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Break started")
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    func testTakeBreakDuringBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Enter break state
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)

        let result = BlinkActions.execute(.takeBreak)

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("Cannot start break"))
    }

    func testTakeBreakDuringSnooze() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Enter snooze state: start break then snooze it
        engine.startBreakNow()
        engine.snoozeBreak()
        XCTAssertEqual(appState.timerState, .snoozeRunning)

        let result = BlinkActions.execute(.takeBreak)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Break started")
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    // MARK: - Snooze Tests

    func testSnoozeDuringBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Enter break state
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertGreaterThan(appState.breakRemainingSeconds, 0)

        let result = BlinkActions.execute(.snooze)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Break snoozed")
        XCTAssertEqual(appState.timerState, .snoozeRunning)
    }

    func testSnoozeDuringWork() {
        let appState = AppState.shared

        // Initial state is workRunning
        XCTAssertEqual(appState.timerState, .workRunning)

        let result = BlinkActions.execute(.snooze)

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("Cannot snooze"))
    }

    // MARK: - Restart Tests

    func testRestartFromAnyState() {
        let appState = AppState.shared

        let result = BlinkActions.execute(.restart)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Session restarted")
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    // MARK: - Status Tests

    func testStatusReportsState() {
        let appState = AppState.shared

        // Default state is workRunning
        XCTAssertEqual(appState.timerState, .workRunning)

        let result = BlinkActions.execute(.status)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.message.contains("Working"))
        XCTAssertTrue(result.message.contains("elapsed"))
    }

    // MARK: - BlinkAction Raw Value Tests

    func testBlinkActionRawValues() {
        XCTAssertEqual(BlinkAction(rawValue: "break"), .takeBreak)
        XCTAssertEqual(BlinkAction(rawValue: "snooze"), .snooze)
        XCTAssertEqual(BlinkAction(rawValue: "restart"), .restart)
        XCTAssertEqual(BlinkAction(rawValue: "status"), .status)
        XCTAssertNil(BlinkAction(rawValue: "invalid"))
    }
}
