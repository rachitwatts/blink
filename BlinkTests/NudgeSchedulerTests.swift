import XCTest
@testable import Blink

@MainActor
final class NudgeSchedulerTests: XCTestCase {

    var scheduler: NudgeScheduler!
    var appState: AppState!
    var settings: Settings!

    override func setUp() async throws {
        appState = AppState.shared
        appState.reset()

        settings = Settings.shared
        settings.resetToDefaults()
        settings.nudgesEnabled = true
        settings.nudgeIntervalMinutes = 1  // 60 seconds for faster tests

        scheduler = NudgeScheduler.shared
        scheduler.reset()
    }

    override func tearDown() async throws {
        appState.reset()
        settings.resetToDefaults()
        scheduler.reset()
    }

    // MARK: - Basic Timing Tests

    func testNudgeShowsAfterIntervalReached() async {
        // Tick for 59 seconds - no nudge yet
        for _ in 0..<59 {
            scheduler.tick()
        }
        XCTAssertFalse(appState.isNudgeVisible)

        // 60th tick - nudge should show
        scheduler.tick()
        XCTAssertTrue(appState.isNudgeVisible)
        XCTAssertNotNil(appState.activeNudgeType)
    }

    func testTimerResetsAfterNudgeShown() async {
        // Tick to trigger nudge
        for _ in 0..<60 {
            scheduler.tick()
        }
        XCTAssertTrue(appState.isNudgeVisible)

        // Dismiss nudge
        scheduler.dismissNudge()
        XCTAssertFalse(appState.isNudgeVisible)

        // Timer should have reset - need another 60 ticks
        XCTAssertEqual(scheduler.testElapsedSeconds, 0)
    }

    func testResetTimerClearsElapsed() async {
        // Tick partway
        for _ in 0..<30 {
            scheduler.tick()
        }
        XCTAssertEqual(scheduler.testElapsedSeconds, 30)

        // Reset
        scheduler.resetTimer()
        XCTAssertEqual(scheduler.testElapsedSeconds, 0)
    }

    // MARK: - Suppression Tests

    func testNoTickWhenNudgesDisabled() async {
        settings.nudgesEnabled = false

        for _ in 0..<100 {
            scheduler.tick()
        }

        XCTAssertFalse(appState.isNudgeVisible)
    }

    func testNoTickWhenSessionPaused() async {
        scheduler.pauseNudgesForSession()

        for _ in 0..<100 {
            scheduler.tick()
        }

        XCTAssertFalse(appState.isNudgeVisible)
    }

    func testNoTickWhenNudgeAlreadyVisible() async {
        // Show a nudge manually
        scheduler.testShowNudge(.blink)
        XCTAssertTrue(appState.isNudgeVisible)

        // More ticks shouldn't change anything
        for _ in 0..<100 {
            scheduler.tick()
        }

        // Still showing same nudge, elapsed didn't accumulate
        XCTAssertTrue(appState.isNudgeVisible)
        XCTAssertEqual(scheduler.testElapsedSeconds, 0)
    }

    func testResumeNudgesAfterBreak() async {
        scheduler.pauseNudgesForSession()
        XCTAssertTrue(appState.nudgesPausedForSession)

        scheduler.resumeNudges()
        XCTAssertFalse(appState.nudgesPausedForSession)
    }

    // MARK: - Type Selection Tests

    func testNoNudgeWhenAllTypesDisabled() async {
        settings.nudgeBlinkEnabled = false
        settings.nudgePostureEnabled = false
        settings.nudgeStretchEnabled = false

        for _ in 0..<100 {
            scheduler.tick()
        }

        // Should not show nudge when no types enabled
        XCTAssertFalse(appState.isNudgeVisible)
    }

    func testOnlyEnabledTypesShown() async {
        settings.nudgeBlinkEnabled = true
        settings.nudgePostureEnabled = false
        settings.nudgeStretchEnabled = false

        // Run multiple cycles to verify only blink shows
        for cycle in 0..<5 {
            scheduler.reset()
            for _ in 0..<60 {
                scheduler.tick()
            }
            XCTAssertEqual(appState.activeNudgeType, .blink, "Cycle \(cycle): Only blink should show")
            scheduler.dismissNudge()
        }
    }

    func testWeightedRandomIncludesBlink() async {
        // Enable all types
        settings.nudgeBlinkEnabled = true
        settings.nudgePostureEnabled = true
        settings.nudgeStretchEnabled = true

        var blinkCount = 0
        let iterations = 100

        for _ in 0..<iterations {
            scheduler.reset()
            for _ in 0..<60 {
                scheduler.tick()
            }
            if appState.activeNudgeType == .blink {
                blinkCount += 1
            }
            scheduler.dismissNudge()
        }

        // Blink has 2x weight out of 4 total, so expect ~50% (allow 30-70% range)
        let blinkRatio = Double(blinkCount) / Double(iterations)
        XCTAssertGreaterThan(blinkRatio, 0.30, "Blink should appear at least 30% of the time")
        XCTAssertLessThan(blinkRatio, 0.70, "Blink should appear less than 70% of the time")
    }

    // MARK: - Dismiss Tests

    func testDismissNudgeClearsState() async {
        scheduler.testShowNudge(.posture)
        XCTAssertTrue(appState.isNudgeVisible)
        XCTAssertEqual(appState.activeNudgeType, .posture)

        scheduler.dismissNudge()
        XCTAssertFalse(appState.isNudgeVisible)
        XCTAssertNil(appState.activeNudgeType)
    }

    func testPauseForSessionDismissesCurrentNudge() async {
        scheduler.testShowNudge(.blink)
        XCTAssertTrue(appState.isNudgeVisible)

        scheduler.pauseNudgesForSession()
        XCTAssertFalse(appState.isNudgeVisible)
        XCTAssertTrue(appState.nudgesPausedForSession)
    }
}
