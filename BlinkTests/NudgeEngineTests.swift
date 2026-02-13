import XCTest
@testable import Blink

/// Tests for NudgeEngine micro-nudge scheduling logic
@MainActor
final class NudgeEngineTests: XCTestCase {

    // MARK: - Properties

    var mockIdle: MockIdleTimeProvider!

    // MARK: - Setup

    override func setUp() async throws {
        AppState.shared.reset()
        Settings.shared.resetToDefaults()

        mockIdle = MockIdleTimeProvider()
        TimerEngine.shared.setIdleDetector(mockIdle)
        TimerEngine.shared.restartSession()

        NudgeEngine.shared.reset()
        NudgeEngine.shared.start()
    }

    override func tearDown() async throws {
        NudgeEngine.shared.stop()
        TimerEngine.shared.stop()
        AppState.shared.reset()
    }

    // MARK: - Settings Default Tests

    func testNudgeSettingsDefaults() {
        Settings.shared.resetToDefaults()
        XCTAssertFalse(Settings.shared.nudgesEnabled)
        XCTAssertTrue(Settings.shared.blinkNudgeEnabled)
        XCTAssertTrue(Settings.shared.postureNudgeEnabled)
        XCTAssertTrue(Settings.shared.neckStretchNudgeEnabled)
        XCTAssertEqual(Settings.shared.blinkNudgeIntervalMinutes, 10)
        XCTAssertEqual(Settings.shared.postureNudgeIntervalMinutes, 25)
        XCTAssertEqual(Settings.shared.neckStretchNudgeIntervalMinutes, 35)
        XCTAssertEqual(Settings.shared.nudgeDisplayDurationSeconds, 6)
    }

    // MARK: - NudgeType Tests

    func testNudgeTypeProperties() {
        XCTAssertEqual(NudgeType.blink.title, "Blink")
        XCTAssertEqual(NudgeType.posture.title, "Posture")
        XCTAssertEqual(NudgeType.neckStretch.title, "Neck Stretch")
        XCTAssertFalse(NudgeType.blink.message.isEmpty)
        XCTAssertFalse(NudgeType.posture.message.isEmpty)
        XCTAssertFalse(NudgeType.neckStretch.message.isEmpty)
    }

    func testNudgeTypeIsEnabled() {
        let settings = Settings.shared
        settings.blinkNudgeEnabled = true
        settings.postureNudgeEnabled = false
        settings.neckStretchNudgeEnabled = true

        XCTAssertTrue(NudgeType.blink.isEnabled(in: settings))
        XCTAssertFalse(NudgeType.posture.isEnabled(in: settings))
        XCTAssertTrue(NudgeType.neckStretch.isEnabled(in: settings))
    }

    func testNudgeTypeIntervalSeconds() {
        let settings = Settings.shared
        settings.blinkNudgeIntervalMinutes = 10
        settings.postureNudgeIntervalMinutes = 25
        settings.neckStretchNudgeIntervalMinutes = 35

        XCTAssertEqual(NudgeType.blink.intervalSeconds(in: settings), 600)
        XCTAssertEqual(NudgeType.posture.intervalSeconds(in: settings), 1500)
        XCTAssertEqual(NudgeType.neckStretch.intervalSeconds(in: settings), 2100)
    }

    // MARK: - Tick Accumulation Tests

    func testTickDoesNotAccumulateWhenDisabled() {
        Settings.shared.nudgesEnabled = false
        AppState.shared.timerState = .workRunning

        NudgeEngine.shared.tick(idleSeconds: 0)

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 0)
    }

    func testTickAccumulatesWhenEnabled() {
        Settings.shared.nudgesEnabled = true
        AppState.shared.timerState = .workRunning

        NudgeEngine.shared.tick(idleSeconds: 0)

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 1)
    }

    func testTickDoesNotAccumulateDuringBreak() {
        Settings.shared.nudgesEnabled = true
        AppState.shared.timerState = .breakRunning

        NudgeEngine.shared.tick(idleSeconds: 0)

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 0)
    }

    func testTickDoesNotAccumulateWhenPaused() {
        Settings.shared.nudgesEnabled = true
        AppState.shared.timerState = .workPaused

        NudgeEngine.shared.tick(idleSeconds: 0)

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 0)
    }

    func testTickDoesNotAccumulateDuringSnooze() {
        Settings.shared.nudgesEnabled = true
        AppState.shared.timerState = .snoozeRunning

        NudgeEngine.shared.tick(idleSeconds: 0)

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 0)
    }

    func testTickDoesNotAccumulateWhenIdle() {
        Settings.shared.nudgesEnabled = true
        AppState.shared.timerState = .workRunning

        // Idle above idleIgnoreThreshold (60s)
        NudgeEngine.shared.tick(idleSeconds: 120)

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 0)
    }

    func testTickOnlyAccumulatesEnabledTypes() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeEnabled = true
        Settings.shared.postureNudgeEnabled = false
        AppState.shared.timerState = .workRunning

        NudgeEngine.shared.tick(idleSeconds: 0)

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 1)
        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .posture), 0)
    }

    // MARK: - Nudge Trigger Tests

    func testNudgeTriggersAtInterval() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeIntervalMinutes = 1 // 60 seconds for fast test
        AppState.shared.timerState = .workRunning

        // Tick 59 times - no nudge yet
        for _ in 0..<59 {
            NudgeEngine.shared.tick(idleSeconds: 0)
        }
        XCTAssertNil(NudgeEngine.shared.activeNudge)

        // 60th tick should trigger blink nudge
        NudgeEngine.shared.tick(idleSeconds: 0)
        XCTAssertEqual(NudgeEngine.shared.activeNudge, .blink)
    }

    func testNudgeResetsAccumulatorAfterTrigger() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeIntervalMinutes = 1 // 60 seconds
        AppState.shared.timerState = .workRunning

        // Trigger a nudge
        for _ in 0..<60 {
            NudgeEngine.shared.tick(idleSeconds: 0)
        }

        XCTAssertEqual(NudgeEngine.shared.activeNudge, .blink)
        // Accumulator should have been reset to 0
        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 0)
    }

    func testNoNewNudgeWhileOneIsShowing() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeIntervalMinutes = 1 // 60 seconds
        Settings.shared.postureNudgeIntervalMinutes = 1 // 60 seconds
        AppState.shared.timerState = .workRunning

        // Trigger blink nudge
        for _ in 0..<60 {
            NudgeEngine.shared.tick(idleSeconds: 0)
        }
        XCTAssertEqual(NudgeEngine.shared.activeNudge, .blink)

        // More ticks should not trigger another nudge type
        for _ in 0..<60 {
            NudgeEngine.shared.tick(idleSeconds: 0)
        }
        // Still showing blink (no new nudge fires while one is active)
        XCTAssertEqual(NudgeEngine.shared.activeNudge, .blink)
    }

    // MARK: - Dismiss Tests

    func testDismissNudge() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeIntervalMinutes = 1
        AppState.shared.timerState = .workRunning

        for _ in 0..<60 {
            NudgeEngine.shared.tick(idleSeconds: 0)
        }
        XCTAssertNotNil(NudgeEngine.shared.activeNudge)

        NudgeEngine.shared.dismissNudge()
        XCTAssertNil(NudgeEngine.shared.activeNudge)
    }

    // MARK: - Snooze Boost Tests

    func testSnoozeBoostActivation() {
        NudgeEngine.shared.activateSnoozeBoost()
        XCTAssertTrue(NudgeEngine.shared.isSnoozeBoostActive)
    }

    func testSnoozeBoostReducesInterval() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeIntervalMinutes = 10 // 600 seconds

        let normalInterval = NudgeEngine.shared.getEffectiveInterval(for: .blink)
        XCTAssertEqual(normalInterval, 600)

        NudgeEngine.shared.activateSnoozeBoost()

        let boostedInterval = NudgeEngine.shared.getEffectiveInterval(for: .blink)
        XCTAssertEqual(boostedInterval, 400) // 600 * 2/3 = 400
    }

    func testSnoozeBoostMinimumInterval() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeIntervalMinutes = 1 // 60 seconds

        NudgeEngine.shared.activateSnoozeBoost()

        let boostedInterval = NudgeEngine.shared.getEffectiveInterval(for: .blink)
        // 60 * 2/3 = 40, but minimum is 60
        XCTAssertEqual(boostedInterval, 60)
    }

    // MARK: - Reset Tests

    func testResetClearsState() {
        Settings.shared.nudgesEnabled = true
        Settings.shared.blinkNudgeIntervalMinutes = 1
        AppState.shared.timerState = .workRunning

        // Accumulate some ticks
        for _ in 0..<30 {
            NudgeEngine.shared.tick(idleSeconds: 0)
        }
        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 30)

        NudgeEngine.shared.reset()
        NudgeEngine.shared.start()

        XCTAssertEqual(NudgeEngine.shared.getAccumulatedSeconds(for: .blink), 0)
        XCTAssertNil(NudgeEngine.shared.activeNudge)
    }
}
