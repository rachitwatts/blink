import XCTest
@testable import BlinkWatch

/// Tests for WatchTimerEngine core logic
@MainActor
final class WatchTimerEngineTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        WatchAppState.shared.reset()
        WatchSettings.shared.resetToDefaults()
        WatchTimerEngine.shared.restartSession()
    }

    override func tearDown() async throws {
        WatchTimerEngine.shared.stop()
        WatchAppState.shared.reset()
    }

    // MARK: - Initial State

    func testInitialState() {
        let appState = WatchAppState.shared

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.breakRemainingSeconds, 0)
    }

    // MARK: - Pause/Resume

    func testTogglePause() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        XCTAssertEqual(appState.timerState, .workRunning)

        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workPaused)

        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testCannotPauseDuringBreak() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)

        engine.togglePause()
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    // MARK: - Restart

    func testRestartSession() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        appState.workElapsedSeconds = 600

        engine.restartSession()

        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    // MARK: - Break

    func testStartBreakNow() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared
        let settings = WatchSettings.shared

        engine.startBreakNow()

        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertEqual(appState.breakRemainingSeconds, settings.breakDurationSeconds)
    }

    func testSnoozeBreak() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared
        let settings = WatchSettings.shared

        engine.startBreakNow()
        engine.snoozeBreak()

        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertEqual(appState.snoozeRemainingSeconds, settings.snoozeDurationSeconds)
    }

    func testSkipBreak() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        engine.startBreakNow()
        engine.skipBreak()

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    func testCannotStartBreakDuringBreak() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        engine.startBreakNow()
        let breakRemaining = appState.breakRemainingSeconds

        // Try starting another break - should be ignored
        engine.startBreakNow()
        XCTAssertEqual(appState.breakRemainingSeconds, breakRemaining)
    }

    // MARK: - Tick Handlers

    func testWorkTickIncrementsElapsed() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        appState.timerState = .workRunning
        appState.workElapsedSeconds = 0

        engine.tick()

        XCTAssertEqual(appState.workElapsedSeconds, 1)
    }

    func testWorkTickTriggersBreakAtDuration() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared
        let settings = WatchSettings.shared

        appState.timerState = .workRunning
        appState.workElapsedSeconds = settings.workDurationSeconds - 1

        engine.tick()

        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    func testBreakTickDecrementsRemaining() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        appState.timerState = .breakRunning
        appState.breakRemainingSeconds = 60

        engine.tick()

        XCTAssertEqual(appState.breakRemainingSeconds, 59)
    }

    func testBreakTickCompletesAtZero() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        appState.timerState = .breakRunning
        appState.breakRemainingSeconds = 0

        engine.tick()

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    func testSnoozeTickDecrementsRemaining() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        appState.timerState = .snoozeRunning
        appState.snoozeRemainingSeconds = 60

        engine.tick()

        XCTAssertEqual(appState.snoozeRemainingSeconds, 59)
    }

    func testSnoozeTickTriggersBreakAtZero() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        appState.timerState = .snoozeRunning
        appState.snoozeRemainingSeconds = 0

        engine.tick()

        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    func testPausedTickDoesNotIncrement() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared

        appState.timerState = .workPaused
        appState.workElapsedSeconds = 100

        engine.tick()

        XCTAssertEqual(appState.workElapsedSeconds, 100)
    }

    // MARK: - Display

    func testDisplayTimeElapsed() {
        let appState = WatchAppState.shared
        let settings = WatchSettings.shared

        settings.displayMode = .elapsed
        appState.workElapsedSeconds = 125  // 2:05

        XCTAssertEqual(appState.displayTime, "02:05")
    }

    func testDisplayTimeRemaining() {
        let appState = WatchAppState.shared
        let settings = WatchSettings.shared

        settings.displayMode = .remaining
        settings.workDurationMinutes = 25
        appState.workElapsedSeconds = 125  // 22:55 remaining

        XCTAssertEqual(appState.displayTime, "22:55")
    }

    // MARK: - Progress

    func testWorkProgressAtZero() {
        let appState = WatchAppState.shared
        appState.workElapsedSeconds = 0

        XCTAssertEqual(appState.workProgress, 0.0)
    }

    func testWorkProgressAtHalf() {
        let appState = WatchAppState.shared
        let settings = WatchSettings.shared

        appState.workElapsedSeconds = settings.workDurationSeconds / 2

        XCTAssertEqual(appState.workProgress, 0.5, accuracy: 0.001)
    }

    func testBreakProgressAtHalf() {
        let appState = WatchAppState.shared
        let settings = WatchSettings.shared

        appState.timerState = .breakRunning
        appState.breakRemainingSeconds = settings.breakDurationSeconds / 2

        XCTAssertEqual(appState.breakProgress, 0.5, accuracy: 0.001)
    }

    // MARK: - Full Cycle

    func testFullWorkBreakCycle() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared
        let settings = WatchSettings.shared

        settings.workDurationMinutes = 1   // 60 seconds
        settings.breakDurationMinutes = 1  // 60 seconds

        appState.timerState = .workRunning
        appState.workElapsedSeconds = 0

        // Tick through entire work duration
        for _ in 0..<settings.workDurationSeconds {
            engine.tick()
        }

        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertEqual(appState.breakRemainingSeconds, settings.breakDurationSeconds)

        // Tick through entire break duration + 1 to complete
        for _ in 0..<settings.breakDurationSeconds {
            engine.tick()
        }
        engine.tick()

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    func testSnoozeToBreakCycle() {
        let appState = WatchAppState.shared
        let engine = WatchTimerEngine.shared
        let settings = WatchSettings.shared

        settings.snoozeDurationMinutes = 1  // 60 seconds

        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)

        engine.snoozeBreak()
        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertEqual(appState.snoozeRemainingSeconds, settings.snoozeDurationSeconds)

        // Tick through snooze + 1 to re-trigger
        for _ in 0..<settings.snoozeDurationSeconds {
            engine.tick()
        }
        engine.tick()

        XCTAssertEqual(appState.timerState, .breakRunning)
    }
}
