import XCTest
@testable import Blink

/// Tests for the gentle-break phase machine (floating → dimmed → fullscreen).
///
/// This logic drove issues #48/#50 and had ZERO coverage — `breakStyle`
/// defaults to `.gentle`, so the phase machine ran invisibly in every other
/// test without a single assertion on `breakPhase`.
final class GentleBreakPhaseTests: BlinkTestCase {

    // MARK: - P2.9: pure computePhase (boundary + skipped-boundary)

    func testComputePhaseStaysFloatingBeforeDimThreshold() {
        XCTAssertEqual(TimerEngine.computePhase(elapsed: 9, current: .floating), .floating)
    }

    func testComputePhaseGoesDimmedAtThreshold() {
        XCTAssertEqual(TimerEngine.computePhase(elapsed: 10, current: .floating), .dimmed)
    }

    /// The key fix: `>=` means a skipped tick that lands PAST the boundary
    /// still triggers the transition (the old `== 10` would have missed it).
    func testComputePhaseGoesDimmedWhenBoundaryWasSkipped() {
        XCTAssertEqual(TimerEngine.computePhase(elapsed: 13, current: .floating), .dimmed)
    }

    func testComputePhaseStaysDimmedBeforeFullscreenThreshold() {
        XCTAssertEqual(TimerEngine.computePhase(elapsed: 19, current: .dimmed), .dimmed)
    }

    func testComputePhaseGoesFullscreenAtThreshold() {
        XCTAssertEqual(TimerEngine.computePhase(elapsed: 20, current: .dimmed), .fullscreen)
    }

    func testComputePhaseGoesFullscreenWhenBoundaryWasSkipped() {
        XCTAssertEqual(TimerEngine.computePhase(elapsed: 99, current: .dimmed), .fullscreen)
    }

    func testComputePhaseFullscreenIsTerminal() {
        XCTAssertEqual(TimerEngine.computePhase(elapsed: 999, current: .fullscreen), .fullscreen)
    }

    /// A huge elapsed jump from floating advances exactly ONE stage per call
    /// (to dimmed), never skipping straight to fullscreen — the dimmed stage
    /// is always shown.
    func testComputePhaseAdvancesOneStagePerCall() {
        let next = TimerEngine.computePhase(elapsed: 25, current: .floating)
        XCTAssertEqual(next, .dimmed, "Should advance floating→dimmed only, not skip to fullscreen")
    }

    // MARK: - P2.8: phase machine via tick()

    /// An auto-triggered gentle break starts in the floating phase.
    func testAutoGentleBreakStartsFloating() {
        Settings.shared.breakStyle = .gentle
        Settings.shared.workDurationMinutes = 1
        mockIdle.idleTime = 0
        AppState.shared.timerState = .workRunning
        AppState.shared.workElapsedSeconds = Settings.shared.workDurationSeconds - 1

        TimerEngine.shared.tick()

        XCTAssertEqual(AppState.shared.timerState, .breakRunning)
        XCTAssertEqual(AppState.shared.breakPhase, .floating)
        XCTAssertTrue(AppState.shared.isOverlayVisible)
    }

    func testGentlePhaseAdvancesToDimmedAtTenSeconds() {
        startGentleBreak(remaining: 300, elapsed: 9, phase: .floating)

        TimerEngine.shared.tick()

        XCTAssertEqual(AppState.shared.breakElapsedSeconds, 10)
        XCTAssertEqual(AppState.shared.breakPhase, .dimmed)
    }

    func testGentlePhaseAdvancesToFullscreenAtTwentySeconds() {
        startGentleBreak(remaining: 300, elapsed: 19, phase: .dimmed)

        TimerEngine.shared.tick()

        XCTAssertEqual(AppState.shared.breakElapsedSeconds, 20)
        XCTAssertEqual(AppState.shared.breakPhase, .fullscreen)
    }

    func testGentlePhaseStaysFloatingBeforeThreshold() {
        startGentleBreak(remaining: 300, elapsed: 5, phase: .floating)

        TimerEngine.shared.tick()

        XCTAssertEqual(AppState.shared.breakPhase, .floating)
    }

    /// Driving a full gentle break tick-by-tick walks floating→dimmed→fullscreen.
    func testGentleBreakFullSequenceReachesFullscreen() {
        startGentleBreak(remaining: 300, elapsed: 0, phase: .floating)

        var sawDimmed = false
        for _ in 0..<21 {
            TimerEngine.shared.tick()
            if AppState.shared.breakPhase == .dimmed { sawDimmed = true }
        }

        XCTAssertTrue(sawDimmed, "Should pass through the dimmed phase")
        XCTAssertEqual(AppState.shared.breakPhase, .fullscreen)
    }

    /// A manual gentle break (Start Break Now) jumps straight to fullscreen
    /// and never runs the progressive phases.
    func testManualGentleBreakStartsFullscreen() {
        Settings.shared.breakStyle = .gentle
        AppState.shared.timerState = .workRunning

        TimerEngine.shared.startBreakNow()

        XCTAssertEqual(AppState.shared.timerState, .breakRunning)
        XCTAssertEqual(AppState.shared.breakPhase, .fullscreen)
    }

    func testManualGentleBreakNeverLeavesFullscreen() {
        Settings.shared.breakStyle = .gentle
        Settings.shared.breakDurationMinutes = 5
        AppState.shared.timerState = .workRunning
        TimerEngine.shared.startBreakNow()

        for _ in 0..<25 {
            TimerEngine.shared.tick()
            XCTAssertEqual(AppState.shared.breakPhase, .fullscreen)
        }
    }

    /// A break that ends before 20s never escalates to fullscreen, and
    /// completing resets the phase to floating.
    func testGentleBreakEndingEarlyNeverReachesFullscreen() {
        startGentleBreak(remaining: 6, elapsed: 0, phase: .floating)

        var sawFullscreen = false
        for _ in 0..<7 {
            TimerEngine.shared.tick()
            if AppState.shared.breakPhase == .fullscreen { sawFullscreen = true }
        }

        XCTAssertFalse(sawFullscreen, "A 6s break must never reach the fullscreen phase")
        XCTAssertEqual(AppState.shared.timerState, .workRunning, "Break should have completed")
        XCTAssertEqual(AppState.shared.breakPhase, .floating, "completeBreak resets phase")
    }

    // MARK: - Helpers

    /// Put the engine into a running gentle break with explicit phase state.
    private func startGentleBreak(remaining: Int, elapsed: Int, phase: BreakPhase) {
        Settings.shared.breakStyle = .gentle
        AppState.shared.timerState = .breakRunning
        AppState.shared.breakRemainingSeconds = remaining
        AppState.shared.breakElapsedSeconds = elapsed
        AppState.shared.breakPhase = phase
    }
}
