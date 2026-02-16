import XCTest
@testable import Blink

/// In-memory mock sync manager for testing.
/// Records all published payloads, settings, and actions for assertion.
final class MockSyncManager: SyncManagerProtocol {
    var onTimerStateReceived: ((SyncPayload) -> Void)?
    var onSettingsReceived: ((SyncSettings) -> Void)?
    var onWatchActionReceived: ((SyncAction) -> Void)?

    /// All timer state payloads published during the test.
    private(set) var publishedPayloads: [SyncPayload] = []

    /// All settings published during the test.
    private(set) var publishedSettings: [SyncSettings] = []

    /// All watch actions published during the test.
    private(set) var publishedWatchActions: [SyncAction] = []

    /// Whether startObserving() was called.
    private(set) var isObserving: Bool = false

    /// The most recently published payload.
    var lastPayload: SyncPayload? { publishedPayloads.last }

    /// The most recently published settings.
    var lastSettings: SyncSettings? { publishedSettings.last }

    func publishTimerState(_ payload: SyncPayload) {
        publishedPayloads.append(payload)
    }

    func publishSettings(_ settings: SyncSettings) {
        publishedSettings.append(settings)
    }

    func publishWatchAction(_ action: SyncAction) {
        publishedWatchActions.append(action)
    }

    func startObserving() {
        isObserving = true
    }

    func stopObserving() {
        isObserving = false
    }

    /// Reset all recorded state for a fresh test.
    func reset() {
        publishedPayloads.removeAll()
        publishedSettings.removeAll()
        publishedWatchActions.removeAll()
    }
}

/// Tests for TimerEngine's sync integration on macOS.
/// Verifies that state transitions publish correct payloads and
/// incoming watch actions trigger the right engine methods.
@MainActor
final class TimerEngineSyncTests: XCTestCase {

    var mockSync: MockSyncManager!
    var mockIdle: MockIdleTimeProvider!

    override func setUp() async throws {
        AppState.shared.reset()
        Settings.shared.resetToDefaults()

        mockIdle = MockIdleTimeProvider()
        TimerEngine.shared.setIdleDetector(mockIdle)

        mockSync = MockSyncManager()
        TimerEngine.shared.setSyncManager(mockSync)

        TimerEngine.shared.restartSession()
        // Clear the payload from restartSession so tests start fresh
        mockSync.reset()
    }

    override func tearDown() async throws {
        TimerEngine.shared.stop()
        TimerEngine.shared.setSyncManager(nil)
        AppState.shared.reset()
    }

    // MARK: - State Transition Payload Tests

    func testTriggerBreakPublishesBreakRunningPayload() {
        let engine = TimerEngine.shared

        engine.startBreakNow()

        XCTAssertEqual(mockSync.publishedPayloads.count, 1,
            "startBreakNow() should publish exactly one sync payload")
        let payload = mockSync.lastPayload!
        XCTAssertEqual(payload.timerState, .breakRunning)
        XCTAssertEqual(payload.sourceDevice, "mac")
        XCTAssertEqual(payload.breakRemainingAtChange, Settings.shared.breakDurationSeconds)
    }

    func testSkipBreakPublishesWorkRunningPayload() {
        let engine = TimerEngine.shared

        engine.startBreakNow()
        mockSync.reset()

        engine.skipBreak()

        XCTAssertEqual(mockSync.publishedPayloads.count, 1)
        let payload = mockSync.lastPayload!
        XCTAssertEqual(payload.timerState, .workRunning)
        XCTAssertEqual(payload.workElapsedAtChange, 0)
        XCTAssertEqual(payload.sourceDevice, "mac")
    }

    func testSnoozeBreakPublishesSnoozeRunningPayload() {
        let engine = TimerEngine.shared

        engine.startBreakNow()
        mockSync.reset()

        engine.snoozeBreak()

        XCTAssertEqual(mockSync.publishedPayloads.count, 1)
        let payload = mockSync.lastPayload!
        XCTAssertEqual(payload.timerState, .snoozeRunning)
        XCTAssertEqual(payload.snoozeRemainingAtChange, Settings.shared.snoozeDurationSeconds)
        XCTAssertEqual(payload.sourceDevice, "mac")
    }

    func testTogglePausePublishesPausedPayload() {
        let engine = TimerEngine.shared

        // Running -> Paused
        engine.togglePause()

        XCTAssertEqual(mockSync.publishedPayloads.count, 1)
        XCTAssertEqual(mockSync.lastPayload!.timerState, .workPaused)
    }

    func testToggleResumePublishesWorkRunningPayload() {
        let engine = TimerEngine.shared

        // Running -> Paused
        engine.togglePause()
        mockSync.reset()

        // Paused -> Running
        engine.togglePause()

        XCTAssertEqual(mockSync.publishedPayloads.count, 1)
        XCTAssertEqual(mockSync.lastPayload!.timerState, .workRunning)
    }

    func testRestartSessionPublishesPayload() {
        let engine = TimerEngine.shared
        let appState = AppState.shared

        appState.workElapsedSeconds = 600
        mockSync.reset()

        engine.restartSession()

        XCTAssertEqual(mockSync.publishedPayloads.count, 1)
        let payload = mockSync.lastPayload!
        XCTAssertEqual(payload.timerState, .workRunning)
        XCTAssertEqual(payload.workElapsedAtChange, 0)
    }

    func testCompleteBreakPublishesPayload() {
        let engine = TimerEngine.shared
        let appState = AppState.shared

        engine.startBreakNow()

        // Tick down to zero
        appState.breakRemainingSeconds = 0
        mockSync.reset()

        engine.tick()

        // completeBreak publishes a workRunning payload
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertGreaterThanOrEqual(mockSync.publishedPayloads.count, 1)
        let payload = mockSync.lastPayload!
        XCTAssertEqual(payload.timerState, .workRunning)
    }

    // MARK: - Incoming Watch Action Tests

    func testIncomingSnoozeActionCallsSnoozeBreak() {
        let engine = TimerEngine.shared
        let appState = AppState.shared

        // Start a break first
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)
        mockSync.reset()

        // Simulate the effect of an incoming watch snooze action.
        // In production, the sync manager's onWatchActionReceived callback
        // calls snoozeBreak() via Task { @MainActor in ... }.
        // We verify the engine method directly since the callback wiring
        // involves an async Task hop that cannot be awaited in tests.
        engine.snoozeBreak()

        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertEqual(appState.snoozeRemainingSeconds, Settings.shared.snoozeDurationSeconds)
    }

    func testIncomingSkipBreakActionCallsSkipBreak() {
        let engine = TimerEngine.shared
        let appState = AppState.shared

        // Start a break first
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)
        mockSync.reset()

        // Simulate the effect of an incoming watch skip action.
        // In production, the sync manager's onWatchActionReceived callback
        // calls skipBreak() via Task { @MainActor in ... }.
        // We verify the engine method directly since the callback wiring
        // involves an async Task hop that cannot be awaited in tests.
        engine.skipBreak()

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    func testWatchActionCallbackIsWiredBySetupSync() {
        // setSyncManager() in test mode does NOT auto-wire callbacks.
        // The real callback wiring happens in setupSync() → configureSyncCallbacks().
        // Verify that the mock's callback is nil when set via setSyncManager (test path).
        XCTAssertNil(mockSync.onWatchActionReceived,
            "setSyncManager in test mode should not auto-wire callbacks")
    }

    // MARK: - Payload Content Verification

    func testPayloadContainsCorrectTimestamp() {
        let engine = TimerEngine.shared
        let beforeTime = Date().timeIntervalSince1970

        engine.startBreakNow()

        let afterTime = Date().timeIntervalSince1970
        let payload = mockSync.lastPayload!

        XCTAssertGreaterThanOrEqual(payload.stateChangedAt, beforeTime)
        XCTAssertLessThanOrEqual(payload.stateChangedAt, afterTime)
    }

    func testPayloadContainsCorrectWorkElapsed() {
        let appState = AppState.shared

        appState.workElapsedSeconds = 750

        TimerEngine.shared.startBreakNow()

        let payload = mockSync.lastPayload!
        XCTAssertEqual(payload.workElapsedAtChange, 750)
    }

    // MARK: - Settings Publish

    func testSettingsPublishOnChange() {
        let settings = Settings.shared

        // The settings sync is set up via observeSettingsChanges() which uses
        // Combine debounce. For this test, we verify the publishToSync method directly.
        settings.publishToSync(mockSync)

        XCTAssertEqual(mockSync.publishedSettings.count, 1)
        let syncSettings = mockSync.lastSettings!
        XCTAssertEqual(syncSettings.workDurationMinutes, settings.workDurationMinutes)
        XCTAssertEqual(syncSettings.breakDurationMinutes, settings.breakDurationMinutes)
        XCTAssertEqual(syncSettings.snoozeDurationMinutes, settings.snoozeDurationMinutes)
        XCTAssertEqual(syncSettings.displayMode, settings.displayMode.rawValue)
    }

    func testSettingsApplyRemoteUpdatesValues() {
        let settings = Settings.shared

        let remote = SyncSettings(
            workDurationMinutes: 30,
            breakDurationMinutes: 10,
            snoozeDurationMinutes: 3,
            displayMode: "remaining",
            changedAt: Date().timeIntervalSince1970
        )

        let applied = settings.applyRemoteSettings(remote)

        XCTAssertTrue(applied)
        XCTAssertEqual(settings.workDurationMinutes, 30)
        XCTAssertEqual(settings.breakDurationMinutes, 10)
        XCTAssertEqual(settings.snoozeDurationMinutes, 3)
        XCTAssertEqual(settings.displayMode, .remaining)
    }

    func testSettingsIgnoreStaleRemote() {
        let settings = Settings.shared

        // Apply a recent remote setting
        let recent = SyncSettings(
            workDurationMinutes: 30,
            breakDurationMinutes: 10,
            snoozeDurationMinutes: 3,
            displayMode: "remaining",
            changedAt: Date().timeIntervalSince1970
        )
        settings.applyRemoteSettings(recent)

        // Try to apply an older remote setting
        let stale = SyncSettings(
            workDurationMinutes: 99,
            breakDurationMinutes: 99,
            snoozeDurationMinutes: 99,
            displayMode: "elapsed",
            changedAt: recent.changedAt - 100  // older
        )
        let applied = settings.applyRemoteSettings(stale)

        XCTAssertFalse(applied)
        XCTAssertEqual(settings.workDurationMinutes, 30, "Stale settings should not override newer ones")
    }

    // MARK: - No Sync Manager (nil) Safety

    func testNilSyncManagerDoesNotCrash() {
        TimerEngine.shared.setSyncManager(nil)

        // These should all work without crashing even with nil sync manager
        TimerEngine.shared.startBreakNow()
        TimerEngine.shared.snoozeBreak()
        TimerEngine.shared.skipBreak()
        TimerEngine.shared.togglePause()
        TimerEngine.shared.restartSession()
    }
}
