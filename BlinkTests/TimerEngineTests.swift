import XCTest
@testable import Blink

/// Tests for TimerEngine core logic.
/// Isolation (mocks, reset, ephemeral defaults) is provided by `BlinkTestCase`.
final class TimerEngineTests: BlinkTestCase {

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

    // MARK: - Stuck Overlay Recovery Tests (issue #54)

    func testSnoozeWhileNotInBreakDismissesOverlay() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Simulate a stuck overlay: window visible but engine already left the break.
        appState.timerState = .workRunning
        appState.isOverlayVisible = true

        engine.snoozeBreak()

        // Overlay is force-dismissed; timer state is left untouched.
        XCTAssertFalse(appState.isOverlayVisible)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testSkipWhileNotInBreakDismissesOverlay() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Simulate a stuck overlay: window visible but engine already left the break.
        appState.timerState = .workRunning
        appState.isOverlayVisible = true

        engine.skipBreak()

        // Overlay is force-dismissed; timer state is left untouched.
        XCTAssertFalse(appState.isOverlayVisible)
        XCTAssertEqual(appState.timerState, .workRunning)
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

        // Full title: paused prefix + the current display time (not just the glyph).
        XCTAssertEqual(appState.menuBarTitle, "⏸ \(appState.displayTime)")
    }

    // MARK: - AppState Display Tests

    func testWorkProgressAtZero() {
        let appState = AppState.shared

        appState.workElapsedSeconds = 0

        XCTAssertEqual(appState.workProgress, 0.0)
    }

    func testWorkProgressAtHalf() {
        let appState = AppState.shared
        let settings = Settings.shared

        // Default work duration is 25 min = 1500 sec; half = 750
        appState.workElapsedSeconds = settings.workDurationSeconds / 2

        XCTAssertEqual(appState.workProgress, 0.5, accuracy: 0.001)
    }

    func testWorkProgressAtFull() {
        let appState = AppState.shared
        let settings = Settings.shared

        appState.workElapsedSeconds = settings.workDurationSeconds

        XCTAssertEqual(appState.workProgress, 1.0)
    }

    func testDisplayTimeAtZeroElapsed() {
        let appState = AppState.shared
        let settings = Settings.shared

        settings.displayMode = .elapsed
        appState.workElapsedSeconds = 0

        XCTAssertEqual(appState.displayTime, "00:00")
    }

    func testDisplayTimeAtZeroRemaining() {
        let appState = AppState.shared
        let settings = Settings.shared

        settings.displayMode = .remaining
        settings.workDurationMinutes = 25
        appState.workElapsedSeconds = 0

        // Remaining = 25 * 60 - 0 = 1500 sec = 25:00
        XCTAssertEqual(appState.displayTime, "25:00")
    }

    func testDisplayTimeOverflowMinutes() {
        let appState = AppState.shared
        let settings = Settings.shared

        settings.displayMode = .elapsed
        appState.workElapsedSeconds = 6000  // 100 minutes exactly

        // formatTime uses "%d:%02d" for >= 100 minutes
        XCTAssertEqual(appState.displayTime, "100:00")
    }

    func testDisplayTimeDuringBreak() {
        let appState = AppState.shared

        appState.timerState = .breakRunning
        appState.breakRemainingSeconds = 185  // 3:05

        // During break, displayTime always shows breakRemainingSeconds
        XCTAssertEqual(appState.displayTime, "03:05")
    }

    func testDisplayTimeDuringSnooze() {
        let appState = AppState.shared

        appState.timerState = .snoozeRunning
        appState.snoozeRemainingSeconds = 245  // 4:05

        // During snooze, displayTime shows snoozeRemainingSeconds
        XCTAssertEqual(appState.displayTime, "04:05")
    }

    // MARK: - Tick Handler Tests

    // Work tick (active user)

    func testTickIncrementsWorkElapsedWhenActive() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        mockIdle.idleTime = 0
        appState.timerState = .workRunning
        appState.workElapsedSeconds = 0

        engine.tick()

        XCTAssertEqual(appState.workElapsedSeconds, 1)
    }

    func testTickTriggersBreakWhenDurationReached() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        mockIdle.idleTime = 0
        appState.timerState = .workRunning
        appState.workElapsedSeconds = settings.workDurationSeconds - 1

        engine.tick()

        // workElapsedSeconds incremented to workDurationSeconds, triggering break
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    func testTickTriggersBreakSetsOverlayVisible() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        mockIdle.idleTime = 0
        appState.timerState = .workRunning
        appState.workElapsedSeconds = settings.workDurationSeconds - 1

        engine.tick()

        XCTAssertTrue(appState.isOverlayVisible)
    }

    // Work tick (idle states)

    func testTickDoesNotIncrementWhenMediumIdle() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        mockIdle.idleTime = 120  // Between idleIgnoreThreshold(60) and idleResetThreshold(300)
        appState.timerState = .workRunning
        appState.workElapsedSeconds = 100

        engine.tick()

        // Medium idle: timer pauses without changing state
        XCTAssertEqual(appState.workElapsedSeconds, 100)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testTickResetsSessionOnReturnFromLongIdle() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        appState.timerState = .workRunning
        appState.workElapsedSeconds = 500

        // First: go into long idle
        mockIdle.idleTime = 400  // Above idleResetThreshold(300)
        engine.tick()

        // Then: return to activity
        mockIdle.idleTime = 0
        engine.tick()

        // Session was reset to 0 on return, then incremented by 1
        XCTAssertEqual(appState.workElapsedSeconds, 1)
    }

    func testTickDoesNotResetWithoutLongIdle() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        mockIdle.idleTime = 0
        appState.timerState = .workRunning
        appState.workElapsedSeconds = 500

        engine.tick()

        // Normal active tick: just increments
        XCTAssertEqual(appState.workElapsedSeconds, 501)
    }

    // Break tick

    func testBreakTickDecrementsRemaining() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        appState.timerState = .breakRunning
        appState.breakRemainingSeconds = 60

        engine.tick()

        XCTAssertEqual(appState.breakRemainingSeconds, 59)
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    func testBreakTickCompletesAtZero() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        appState.timerState = .breakRunning
        appState.breakRemainingSeconds = 0

        engine.tick()

        // Break complete: returns to work with elapsed reset
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    func testCompleteBreakIgnoredWhenNotInBreakState() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Set up a work session in progress
        appState.timerState = .workRunning
        appState.workElapsedSeconds = 500

        // Calling completeBreak() should be a no-op when not in breakRunning
        engine.completeBreak()

        // State should be unchanged - guard prevents reset
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 500)
    }

    // Snooze tick

    func testSnoozeTickDecrementsRemaining() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        appState.timerState = .snoozeRunning
        appState.snoozeRemainingSeconds = 60

        engine.tick()

        XCTAssertEqual(appState.snoozeRemainingSeconds, 59)
        XCTAssertEqual(appState.timerState, .snoozeRunning)
    }

    func testSnoozeTickTriggersBreakAtZero() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        appState.timerState = .snoozeRunning
        appState.snoozeRemainingSeconds = 0

        engine.tick()

        // Snooze expired: triggers break
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)
    }

    // Paused

    func testTickWhilePausedDoesNotIncrement() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        mockIdle.idleTime = 0
        appState.timerState = .workPaused
        appState.workElapsedSeconds = 100

        engine.tick()

        XCTAssertEqual(appState.workElapsedSeconds, 100)
        XCTAssertEqual(appState.timerState, .workPaused)
    }

    // Full cycles

    func testFullWorkBreakCycle() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        // Use short durations for test speed
        settings.workDurationMinutes = 1   // 60 seconds
        settings.breakDurationMinutes = 1  // 60 seconds

        mockIdle.idleTime = 0
        appState.timerState = .workRunning
        appState.workElapsedSeconds = 0

        // Tick through entire work duration
        for _ in 0..<settings.workDurationSeconds {
            engine.tick()
        }

        // Should have triggered break
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)
        XCTAssertEqual(appState.breakRemainingSeconds, settings.breakDurationSeconds)

        // Tick through entire break duration
        for _ in 0..<settings.breakDurationSeconds {
            engine.tick()
        }

        // Break should still be running (decremented to 0 but not completed yet)
        // One more tick to complete the break at 0
        engine.tick()

        // Should have returned to work
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Lock Screen Tests

    // These exercise completeBreak()'s real lock behavior via an injected spy
    // (the previous versions only re-computed the predicate in the test body,
    // and would have passed even if completeBreak never locked).

    func testCompleteBreakLocksScreenWhenEnabledAndIdle() {
        Settings.shared.lockScreenAfterBreak = true
        mockIdle.idleTime = 120  // above idleIgnoreThreshold (60s)
        AppState.shared.timerState = .breakRunning

        TimerEngine.shared.completeBreak()

        XCTAssertEqual(mockScreenLock.lockCount, 1, "Should lock when enabled and idle")
        XCTAssertEqual(AppState.shared.timerState, .workRunning)
    }

    func testCompleteBreakDoesNotLockWhenUserActive() {
        Settings.shared.lockScreenAfterBreak = true
        mockIdle.idleTime = 5  // below threshold → user is active
        AppState.shared.timerState = .breakRunning

        TimerEngine.shared.completeBreak()

        XCTAssertEqual(mockScreenLock.lockCount, 0, "Must not lock while the user is active")
    }

    func testCompleteBreakDoesNotLockWhenDisabled() {
        Settings.shared.lockScreenAfterBreak = false
        mockIdle.idleTime = 120  // idle, but the setting is off
        AppState.shared.timerState = .breakRunning

        TimerEngine.shared.completeBreak()

        XCTAssertEqual(mockScreenLock.lockCount, 0, "Must not lock when the setting is disabled")
    }

    func testLockScreenSettingDefaultsToTrue() {
        Settings.shared.resetToDefaults()
        XCTAssertTrue(Settings.shared.lockScreenAfterBreak, "Lock screen should default to on")
    }

    func testSkipBreakDoesNotCallCompleteBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Start break then skip it
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)

        engine.skipBreak()

        // skipBreak resets to workRunning directly, never calls completeBreak
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    func testSnoozeBreakDoesNotCallCompleteBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Start break then snooze
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)

        engine.snoozeBreak()

        // snoozeBreak transitions to snoozeRunning, never calls completeBreak
        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    func testSnoozeToBreakCycle() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        // Use short snooze for test speed
        settings.snoozeDurationMinutes = 1  // 60 seconds

        // Start a break
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)

        // Snooze the break
        engine.snoozeBreak()
        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertFalse(appState.isOverlayVisible)
        XCTAssertEqual(appState.snoozeRemainingSeconds, settings.snoozeDurationSeconds)

        // Tick through entire snooze duration
        for _ in 0..<settings.snoozeDurationSeconds {
            engine.tick()
        }

        // Snooze should still be running (decremented to 0 but not re-triggered yet)
        // One more tick to trigger break at 0
        engine.tick()

        // Break should re-trigger
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)
    }

    func testStartBreakNowDuringSnoozeResumesBreak() throws {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Start break and snooze it
        engine.startBreakNow()
        let breakDuration = appState.breakRemainingSeconds
        engine.snoozeBreak()
        XCTAssertEqual(appState.timerState, .snoozeRunning)

        // Simulate a few ticks of snooze elapsed
        for _ in 0..<5 {
            engine.tick()
        }
        XCTAssertEqual(appState.timerState, .snoozeRunning)

        // Resume break during snooze
        engine.startBreakNow()

        // Should resume the break with full duration
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)
        XCTAssertEqual(appState.breakRemainingSeconds, breakDuration)
        XCTAssertEqual(appState.snoozeRemainingSeconds, 0)
    }
}
