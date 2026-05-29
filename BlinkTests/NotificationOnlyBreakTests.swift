import XCTest
@testable import Blink

/// Tests for the notification-only break style — a delivery branch in
/// triggerBreak() that the existing delivery-mode tests never covered.
/// It must send a notification and reset to work WITHOUT ever entering the
/// break state or showing an overlay.
final class NotificationOnlyBreakTests: BlinkTestCase {

    override func setUp() async throws {
        try await super.setUp()
        Settings.shared.breakStyle = .notificationOnly
    }

    func testAutoNotificationOnlyNeverShowsOverlay() {
        Settings.shared.workDurationMinutes = 1
        mockIdle.idleTime = 0
        AppState.shared.timerState = .workRunning
        AppState.shared.workElapsedSeconds = Settings.shared.workDurationSeconds - 1

        TimerEngine.shared.tick()  // crosses the work-duration boundary

        XCTAssertEqual(AppState.shared.timerState, .workRunning, "Must stay in work, never breakRunning")
        XCTAssertFalse(AppState.shared.isOverlayVisible, "Notification-only must not show an overlay")
        XCTAssertEqual(AppState.shared.breakRemainingSeconds, 0, "Break countdown must not start")
    }

    func testAutoNotificationOnlyResetsWorkElapsed() {
        Settings.shared.workDurationMinutes = 1
        mockIdle.idleTime = 0
        AppState.shared.timerState = .workRunning
        AppState.shared.workElapsedSeconds = Settings.shared.workDurationSeconds - 1

        TimerEngine.shared.tick()

        XCTAssertEqual(AppState.shared.workElapsedSeconds, 0, "Work session restarts after the reminder")
    }

    func testManualNotificationOnlyStartBreakNowStaysInWork() {
        AppState.shared.timerState = .workRunning
        AppState.shared.workElapsedSeconds = 300

        TimerEngine.shared.startBreakNow()

        XCTAssertEqual(AppState.shared.timerState, .workRunning)
        XCTAssertFalse(AppState.shared.isOverlayVisible)
        XCTAssertEqual(AppState.shared.workElapsedSeconds, 0)
    }
}
