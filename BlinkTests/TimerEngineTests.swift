import XCTest
@testable import Blink

/// Tests for TimerEngine core logic
@MainActor
final class TimerEngineTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        // Reset state before each test
        AppState.shared.reset()
        Settings.shared.resetToDefaults()
    }

    override func tearDown() async throws {
        // Clean up after each test
        AppState.shared.reset()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        let appState = AppState.shared

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.breakRemainingSeconds, 0)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Pause/Resume Tests

    func testTogglePause() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Initial state: running
        XCTAssertEqual(appState.timerState, .workRunning)

        // Toggle to paused
        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workPaused)

        // Toggle back to running
        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testCannotPauseDuringBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Trigger break
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)

        // Try to pause - should not change state
        engine.togglePause()
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    // MARK: - Restart Tests

    func testRestartSession() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Set some elapsed time
        appState.workElapsedSeconds = 600

        // Restart
        engine.restartSession()

        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testRestartDuringBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Start break
        engine.startBreakNow()
        XCTAssertTrue(appState.isOverlayVisible)

        // Restart
        engine.restartSession()

        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Break Tests

    func testStartBreakNow() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        engine.startBreakNow()

        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertEqual(appState.breakRemainingSeconds, settings.breakDurationSeconds)
        XCTAssertTrue(appState.isOverlayVisible)
    }

    func testSnoozeBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        // Start break
        engine.startBreakNow()
        XCTAssertTrue(appState.isOverlayVisible)

        // Snooze
        engine.snoozeBreak()

        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertEqual(appState.snoozeRemainingSeconds, settings.snoozeDurationSeconds)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    func testSkipBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Start break
        engine.startBreakNow()

        // Skip
        engine.skipBreak()

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Display Tests

    func testDisplayTimeElapsed() {
        let appState = AppState.shared
        let settings = Settings.shared

        settings.displayMode = .elapsed
        appState.workElapsedSeconds = 125  // 2:05

        XCTAssertEqual(appState.displayTime, "02:05")
    }

    func testDisplayTimeRemaining() {
        let appState = AppState.shared
        let settings = Settings.shared

        settings.displayMode = .remaining
        settings.workDurationMinutes = 25
        appState.workElapsedSeconds = 125  // 2:05 elapsed, 22:55 remaining

        XCTAssertEqual(appState.displayTime, "22:55")
    }

    func testMenuBarTitlePaused() {
        let appState = AppState.shared

        appState.workElapsedSeconds = 125
        appState.timerState = .workPaused

        XCTAssertTrue(appState.menuBarTitle.hasPrefix("⏸"))
    }
}
