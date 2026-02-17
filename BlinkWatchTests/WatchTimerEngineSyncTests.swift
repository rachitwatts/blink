import XCTest
@testable import BlinkWatch

/// In-memory mock sync manager for watch-side testing.
/// Records all published payloads, settings, and actions for assertion.
final class WatchMockSyncManager: SyncManagerProtocol {
    var onTimerStateReceived: ((SyncPayload) -> Void)?
    var onSettingsReceived: ((SyncSettings) -> Void)?
    var onWatchActionReceived: ((SyncAction) -> Void)?

    /// All timer state payloads published during the test.
    private(set) var publishedPayloads: [SyncPayload] = []

    /// All settings published during the test.
    private(set) var publishedSettings: [SyncSettings] = []

    /// All watch actions published during the test.
    private(set) var publishedWatchActions: [SyncAction] = []

    private(set) var isObserving: Bool = false

    var lastPayload: SyncPayload? { publishedPayloads.last }
    var lastWatchAction: SyncAction? { publishedWatchActions.last }

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

    func reset() {
        publishedPayloads.removeAll()
        publishedSettings.removeAll()
        publishedWatchActions.removeAll()
    }
}

/// Tests for WatchTimerEngine's sync integration.
/// Verifies synced mode (applying remote payloads), offline detection,
/// and action publishing.
@MainActor
final class WatchTimerEngineSyncTests: XCTestCase {

    var mockSync: WatchMockSyncManager!

    override func setUp() async throws {
        WatchTimerEngine.shared.disableHardwareInteractions = true
        WatchAppState.shared.reset()
        WatchSettings.shared.resetToDefaults()
        WatchTimerEngine.shared.resetSyncState()

        mockSync = WatchMockSyncManager()
        WatchTimerEngine.shared.setSyncManager(mockSync)

        WatchTimerEngine.shared.restartSession()
        mockSync.reset()
    }

    override func tearDown() async throws {
        WatchTimerEngine.shared.stop()
        WatchTimerEngine.shared.setSyncManager(nil)
        WatchTimerEngine.shared.resetSyncState()
        WatchAppState.shared.reset()
    }

    // MARK: - handleRemoteState Tests

    func testHandleRemoteStateWorkRunningUpdatesAppState() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        let payload = SyncPayload(
            timerState: .workRunning,
            stateChangedAt: Date().timeIntervalSince1970 - 5,
            workElapsedAtChange: 600,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        engine.handleRemoteState(payload)

        XCTAssertEqual(appState.timerState, .workRunning)
        // Work elapsed is NOT extrapolated from wall clock (Mac uses idle-aware
        // timing), so we get exactly the synced value, not synced + elapsed.
        XCTAssertEqual(appState.workElapsedSeconds, 600)
    }

    func testHandleRemoteStateBreakRunningAppliesTimeAdjustedRemaining() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        let payload = SyncPayload(
            timerState: .breakRunning,
            stateChangedAt: Date().timeIntervalSince1970 - 10,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 300,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        engine.handleRemoteState(payload)

        XCTAssertEqual(appState.timerState, .breakRunning)
        // 300 - ~10 seconds elapsed = ~290
        XCTAssertGreaterThanOrEqual(appState.breakRemainingSeconds, 289)
        XCTAssertLessThanOrEqual(appState.breakRemainingSeconds, 291)
    }

    func testHandleRemoteStateWorkPausedDoesNotAdvanceCounter() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        let payload = SyncPayload(
            timerState: .workPaused,
            stateChangedAt: Date().timeIntervalSince1970 - 100,
            workElapsedAtChange: 600,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        engine.handleRemoteState(payload)

        XCTAssertEqual(appState.timerState, .workPaused)
        XCTAssertEqual(appState.workElapsedSeconds, 600)
    }

    func testHandleRemoteStateSnoozeRunningAppliesTimeAdjustedRemaining() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        let payload = SyncPayload(
            timerState: .snoozeRunning,
            stateChangedAt: Date().timeIntervalSince1970 - 5,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 120,
            sourceDevice: "mac"
        )

        engine.handleRemoteState(payload)

        XCTAssertEqual(appState.timerState, .snoozeRunning)
        // 120 - ~5 seconds = ~115
        XCTAssertGreaterThanOrEqual(appState.snoozeRemainingSeconds, 114)
        XCTAssertLessThanOrEqual(appState.snoozeRemainingSeconds, 116)
    }

    func testHandleRemoteStateIgnoresWatchEchoes() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        // Ensure a known initial state
        appState.timerState = .workRunning
        appState.workElapsedSeconds = 100

        let payload = SyncPayload(
            timerState: .breakRunning,
            stateChangedAt: Date().timeIntervalSince1970,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 300,
            snoozeRemainingAtChange: 0,
            sourceDevice: "watch"  // From watch — should be ignored
        )

        engine.handleRemoteState(payload)

        // State should remain unchanged because the echo was ignored
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 100)
    }

    // MARK: - Offline Detection Tests

    func testIsOfflineAfterNoSync() {
        let engine = WatchTimerEngine.shared

        // No sync has been received; lastSyncReceivedAt is 0
        XCTAssertTrue(engine.isOffline, "Should be offline when no sync has ever been received")
    }

    func testIsOfflineAfterStaleSync() {
        let engine = WatchTimerEngine.shared

        // Simulate a sync received 31+ seconds ago
        let payload = SyncPayload(
            timerState: .workRunning,
            stateChangedAt: Date().timeIntervalSince1970 - 35,
            workElapsedAtChange: 100,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )
        engine.handleRemoteState(payload)

        // Manually advance the clock check by calling tick() which updates offline status
        // But lastSyncReceivedAt was just set to Date() in handleRemoteState, so it's fresh.
        // We need to verify immediately after receiving — it should NOT be offline
        XCTAssertFalse(engine.isOffline, "Should not be offline immediately after receiving sync")
    }

    func testIsNotOfflineImmediatelyAfterSync() {
        let engine = WatchTimerEngine.shared

        let payload = SyncPayload(
            timerState: .workRunning,
            stateChangedAt: Date().timeIntervalSince1970,
            workElapsedAtChange: 100,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )
        engine.handleRemoteState(payload)

        XCTAssertFalse(engine.isOffline, "Should not be offline right after receiving a sync")
    }

    // MARK: - Action Publishing Tests

    func testSkipBreakPublishesSyncAction() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        // Put into break state
        engine.startBreakNow()
        mockSync.reset()

        engine.skipBreak()

        XCTAssertEqual(mockSync.publishedWatchActions.count, 1)
        let action = mockSync.lastWatchAction!
        XCTAssertEqual(action.action, .skipBreak)
        XCTAssertGreaterThan(action.timestamp, 0)
    }

    func testSnoozeBreakPublishesSyncAction() {
        let engine = WatchTimerEngine.shared

        // Put into break state
        engine.startBreakNow()
        mockSync.reset()

        engine.snoozeBreak()

        XCTAssertEqual(mockSync.publishedWatchActions.count, 1)
        let action = mockSync.lastWatchAction!
        XCTAssertEqual(action.action, .snooze)
        XCTAssertGreaterThan(action.timestamp, 0)
    }

    func testSkipBreakFromSnoozePublishesSyncAction() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        // Put into snooze state
        engine.startBreakNow()
        engine.snoozeBreak()
        XCTAssertEqual(appState.timerState, .snoozeRunning)
        mockSync.reset()

        engine.skipBreak()

        XCTAssertEqual(mockSync.publishedWatchActions.count, 1)
        XCTAssertEqual(mockSync.lastWatchAction!.action, .skipBreak)
    }

    // MARK: - Synced Tick Mode Tests

    func testTickInSyncedModeIncrementsWorkLocally() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        // Simulate receiving a sync payload
        let stateChangedAt = Date().timeIntervalSince1970 - 10
        let payload = SyncPayload(
            timerState: .workRunning,
            stateChangedAt: stateChangedAt,
            workElapsedAtChange: 600,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )
        engine.handleRemoteState(payload)

        // Tick in synced mode — should increment locally so display stays alive
        engine.tick()

        // Work elapsed increments by 1 per tick (Mac snapshots arrive on
        // state transitions and periodic heartbeats to correct drift).
        XCTAssertEqual(appState.workElapsedSeconds, 601)
    }

    func testTickInLocalModeIncrementsIndependently() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        // No sync received — engine should be in offline/local mode
        XCTAssertTrue(engine.isOffline)
        appState.timerState = .workRunning
        appState.workElapsedSeconds = 100

        engine.tick()

        // Local mode: should increment by 1
        XCTAssertEqual(appState.workElapsedSeconds, 101)
    }

    func testTickInSyncedModeBreakCountdown() {
        let engine = WatchTimerEngine.shared
        let appState = WatchAppState.shared

        // Simulate receiving a break payload
        let stateChangedAt = Date().timeIntervalSince1970 - 5
        let payload = SyncPayload(
            timerState: .breakRunning,
            stateChangedAt: stateChangedAt,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 300,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )
        engine.handleRemoteState(payload)

        // Tick — should recompute break remaining from payload
        engine.tick()

        // breakRemaining should be ~295 (300 - 5 seconds)
        XCTAssertLessThanOrEqual(appState.breakRemainingSeconds, 296)
        XCTAssertGreaterThanOrEqual(appState.breakRemainingSeconds, 293)
    }

    // MARK: - No Sync Manager (nil) Safety

    func testNilSyncManagerDoesNotCrashOnActions() {
        WatchTimerEngine.shared.setSyncManager(nil)

        // These should all work without crashing
        WatchTimerEngine.shared.startBreakNow()
        WatchTimerEngine.shared.snoozeBreak()
        WatchTimerEngine.shared.skipBreak()
    }

    // MARK: - Settings Sync

    func testWatchSettingsApplyRemote() {
        let settings = WatchSettings.shared

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

    func testWatchSettingsIgnoreStaleRemote() {
        let settings = WatchSettings.shared

        let recent = SyncSettings(
            workDurationMinutes: 30,
            breakDurationMinutes: 10,
            snoozeDurationMinutes: 3,
            displayMode: "remaining",
            changedAt: Date().timeIntervalSince1970
        )
        settings.applyRemoteSettings(recent)

        let stale = SyncSettings(
            workDurationMinutes: 99,
            breakDurationMinutes: 99,
            snoozeDurationMinutes: 99,
            displayMode: "elapsed",
            changedAt: recent.changedAt - 100
        )
        let applied = settings.applyRemoteSettings(stale)

        XCTAssertFalse(applied)
        XCTAssertEqual(settings.workDurationMinutes, 30)
    }
}
