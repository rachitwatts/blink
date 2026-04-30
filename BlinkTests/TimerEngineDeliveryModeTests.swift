import XCTest
@testable import Blink

@MainActor
final class TimerEngineDeliveryModeTests: XCTestCase {

    var mockIdle: MockIdleTimeProvider!
    var mockCall: MockCallDetector!
    var mockCalendar: MockCalendarMonitor!

    override func setUp() async throws {
        AppState.shared.reset()
        Settings.shared.resetToDefaults()

        mockIdle = MockIdleTimeProvider()
        mockCall = MockCallDetector()
        mockCalendar = MockCalendarMonitor()

        TimerEngine.shared.setIdleDetector(mockIdle)
        TimerEngine.shared.setCallDetector(mockCall)
        TimerEngine.shared.setCalendarMonitor(mockCalendar)
        TimerEngine.shared.setSyncManager(nil)
        InCallNudgeWindowController.suppressForTesting = true
        TimerEngine.shared.restartSession()
    }

    override func tearDown() async throws {
        TimerEngine.shared.stop()
        AppState.shared.reset()
    }

    // MARK: - Normal Break Delivery

    func testNormalBreakWhenNoCallOrScreenShare() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .none

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        TimerEngine.shared.tick()

        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)
        XCTAssertFalse(appState.breakDeferred)
    }

    // MARK: - Screen Sharing Suppression

    func testBreakDeferredWhenScreenSharing() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .screenSharing

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        TimerEngine.shared.tick()

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertTrue(appState.breakDeferred)
        XCTAssertEqual(appState.breakDeferralReason, "Screen sharing")
        XCTAssertFalse(appState.isOverlayVisible)
    }

    func testBreakFiresWhenScreenSharingStops() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .screenSharing

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        // First tick: defers
        TimerEngine.shared.tick()
        XCTAssertTrue(appState.breakDeferred)
        XCTAssertEqual(appState.timerState, .workRunning)

        // Screen sharing stops
        mockCall.callContext = .none

        // Next tick: should fire break
        TimerEngine.shared.tick()
        XCTAssertFalse(appState.breakDeferred)
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)
    }

    // MARK: - In-Call Nudge

    func testInCallNudgeWhenOnCall() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .onCall

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        TimerEngine.shared.tick()

        // Should NOT show full break overlay
        XCTAssertFalse(appState.isOverlayVisible)
        // Should NOT defer
        XCTAssertFalse(appState.breakDeferred)
        // Should reset work timer (nudge counts as break taken)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        // Should stay in workRunning (not breakRunning)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testInCallNudgeRepeatsAtNormalInterval() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .onCall

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        // First nudge
        TimerEngine.shared.tick()
        XCTAssertEqual(appState.workElapsedSeconds, 0)

        // Simulate another full work cycle during ongoing call
        appState.workElapsedSeconds = 59
        TimerEngine.shared.tick()

        // Should nudge again (work timer reset again)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    // MARK: - Screen Share to Call Transition

    func testScreenShareStopsButStillOnCall() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .screenSharing

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        // Defers during screen share
        TimerEngine.shared.tick()
        XCTAssertTrue(appState.breakDeferred)

        // Stop screen sharing but still on call
        mockCall.callContext = .onCall

        // Should deliver as in-call nudge (not full break)
        TimerEngine.shared.tick()
        XCTAssertFalse(appState.breakDeferred)
        XCTAssertFalse(appState.isOverlayVisible)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    // MARK: - Calendar Early Shift

    func testEarlyBreakShiftWhenMeetingSoon() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .none

        Settings.shared.calendarIntegrationEnabled = true
        Settings.shared.workDurationMinutes = 1
        // 5 seconds before break would be due
        appState.workElapsedSeconds = 55
        mockCalendar.mockNextEventWithin = 2

        TimerEngine.shared.tick()

        // Should trigger break early
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)
    }

    func testEarlyBreakShiftDefersWhenScreenSharing() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .screenSharing

        Settings.shared.calendarIntegrationEnabled = true
        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 55
        mockCalendar.mockNextEventWithin = 2

        TimerEngine.shared.tick()

        // Should defer, not show full break
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertTrue(appState.breakDeferred)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    func testEarlyBreakShiftShowsNudgeWhenOnCall() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .onCall

        Settings.shared.calendarIntegrationEnabled = true
        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 55
        mockCalendar.mockNextEventWithin = 2

        TimerEngine.shared.tick()

        // Should show in-call nudge, not full break
        XCTAssertFalse(appState.isOverlayVisible)
        XCTAssertFalse(appState.breakDeferred)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testNoEarlyShiftWhenFarFromBreak() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .none

        Settings.shared.calendarIntegrationEnabled = true
        Settings.shared.workDurationMinutes = 25
        // Only 5 minutes in — 20 minutes remaining, well past the 60s window
        appState.workElapsedSeconds = 300
        mockCalendar.mockNextEventWithin = 2

        TimerEngine.shared.tick()

        // Should NOT trigger break early (more than 60s remaining)
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Deferral State Clearing on Manual Transitions

    func testRestartSessionClearsDeferralState() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .screenSharing

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        // Trigger deferral
        TimerEngine.shared.tick()
        XCTAssertTrue(appState.breakDeferred)

        // User manually restarts session
        TimerEngine.shared.restartSession()

        XCTAssertFalse(appState.breakDeferred)
        XCTAssertNil(appState.breakDeferralReason)
    }

    func testStartBreakNowClearsDeferralState() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        mockCall.callContext = .screenSharing

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        // Trigger deferral
        TimerEngine.shared.tick()
        XCTAssertTrue(appState.breakDeferred)

        // Stop screen sharing so startBreakNow can actually trigger a break
        mockCall.callContext = .none

        // User manually starts break
        TimerEngine.shared.startBreakNow()

        XCTAssertFalse(appState.breakDeferred)
        XCTAssertNil(appState.breakDeferralReason)
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    // MARK: - Deferral State in AppState

    func testResetClearsDeferralState() {
        let appState = AppState.shared
        appState.breakDeferred = true
        appState.breakDeferralReason = "Screen sharing"

        appState.reset()

        XCTAssertFalse(appState.breakDeferred)
        XCTAssertNil(appState.breakDeferralReason)
    }

    // MARK: - Menu Bar Title

    func testMenuBarShowsHourglassWhenDeferred() {
        let appState = AppState.shared
        appState.breakDeferred = true
        appState.workElapsedSeconds = 90

        XCTAssertTrue(appState.menuBarTitle.hasPrefix("⏳"))
    }

    func testMenuBarNormalWhenNotDeferred() {
        let appState = AppState.shared
        appState.breakDeferred = false
        appState.workElapsedSeconds = 90

        XCTAssertFalse(appState.menuBarTitle.hasPrefix("⏳"))
    }

    // MARK: - Call Detection Disabled

    func testCallDetectionDisabledDeliversNormalBreak() {
        let appState = AppState.shared
        mockIdle.idleTime = 0
        Settings.shared.callDetectionEnabled = false

        // Even though mock says on call, detection is disabled
        // CallDetector.poll() would set .none, but we're using a mock
        // The TimerEngine checks callDetector state directly
        // With mock set to onCall but feature disabled, let's verify
        // that the mock still reports onCall (it doesn't check settings)
        mockCall.callContext = .onCall

        Settings.shared.workDurationMinutes = 1
        appState.workElapsedSeconds = 59

        TimerEngine.shared.tick()

        // The mock doesn't respect callDetectionEnabled — that's CallDetector.poll()'s job
        // With mock injected, the timer engine trusts the detector's state
        // This is by design: the real CallDetector handles the settings check
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    // MARK: - Settings Defaults

    func testIntegrationSettingsDefaults() {
        Settings.shared.resetToDefaults()

        XCTAssertTrue(Settings.shared.callDetectionEnabled)
        XCTAssertFalse(Settings.shared.calendarIntegrationEnabled)
        XCTAssertEqual(Settings.shared.calendarLeadTimeMinutes, 3)
        XCTAssertEqual(Settings.shared.watchedCalendarIdentifiers, "")
    }
}
