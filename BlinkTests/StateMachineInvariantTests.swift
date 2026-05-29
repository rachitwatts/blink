import XCTest
@testable import Blink

/// Property/invariant tests: drive the timer state machine through many
/// randomized action sequences and assert core invariants hold after every
/// step. Catches whole classes of regressions (negative timers, orphaned
/// overlays, illegal transitions) that single-scenario tests miss.
///
/// Uses a seeded generator so any failure is deterministically reproducible
/// from its seed.
final class StateMachineInvariantTests: BlinkTestCase {

    /// Deterministic SplitMix64 generator.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func assertInvariants(_ context: String) {
        let s = AppState.shared
        XCTAssertGreaterThanOrEqual(s.workElapsedSeconds, 0, "workElapsed negative \(context)")
        XCTAssertGreaterThanOrEqual(s.breakRemainingSeconds, 0, "breakRemaining negative \(context)")
        XCTAssertGreaterThanOrEqual(s.snoozeRemainingSeconds, 0, "snoozeRemaining negative \(context)")
        // The overlay may only be visible while a break is actually running.
        if s.isOverlayVisible {
            XCTAssertEqual(s.timerState, .breakRunning,
                           "overlay visible outside breakRunning \(context)")
        }
        // Snooze hides the overlay (the snooze contract; #54-class).
        if s.timerState == .snoozeRunning {
            XCTAssertFalse(s.isOverlayVisible, "Overlay must be hidden during snooze \(context)")
        }
        // Work states never show the overlay.
        if s.timerState == .workRunning || s.timerState == .workPaused {
            XCTAssertFalse(s.isOverlayVisible, "Overlay must be hidden during work \(context)")
        }
    }

    func testInvariantsHoldUnderRandomActionSequences() {
        let styles: [BreakStyle] = [.gentle, .enforced, .notificationOnly]
        let idleSamples: [TimeInterval] = [0, 30, 120, 400]

        for seed in UInt64(1)...40 {
            var rng = SeededGenerator(seed: seed)

            // Fresh engine state for this seed.
            TimerEngine.shared.restartSession()
            TimerEngine.shared.stop()
            AppState.shared.reset()
            Settings.shared.breakStyle = styles.randomElement(using: &rng)!
            Settings.shared.workDurationMinutes = 1   // short cycles → exercises transitions
            Settings.shared.snoozeDurationMinutes = 1
            Settings.shared.breakDurationMinutes = 1

            for step in 0..<150 {
                let op = Int.random(in: 0..<7, using: &rng)
                switch op {
                case 0, 1:  // bias toward ticks
                    mockIdle.idleTime = idleSamples.randomElement(using: &rng)!
                    TimerEngine.shared.tick()
                case 2:
                    TimerEngine.shared.togglePause()
                case 3:
                    TimerEngine.shared.snoozeBreak()
                case 4:
                    TimerEngine.shared.skipBreak()
                case 5:
                    TimerEngine.shared.startBreakNow()
                default:
                    TimerEngine.shared.restartSession()
                }
                assertInvariants("(seed=\(seed), step=\(step), op=\(op))")
            }
        }
    }

    /// After skip or restart from any state, we land cleanly in work with no overlay.
    func testSkipAndRestartAlwaysLandInCleanWorkState() {
        Settings.shared.breakStyle = .gentle
        TimerEngine.shared.startBreakNow()
        TimerEngine.shared.skipBreak()
        XCTAssertEqual(AppState.shared.timerState, .workRunning)
        XCTAssertFalse(AppState.shared.isOverlayVisible)
        XCTAssertEqual(AppState.shared.workElapsedSeconds, 0)

        TimerEngine.shared.startBreakNow()
        TimerEngine.shared.restartSession()
        XCTAssertEqual(AppState.shared.timerState, .workRunning)
        XCTAssertFalse(AppState.shared.isOverlayVisible)
        XCTAssertEqual(AppState.shared.workElapsedSeconds, 0)
    }
}
