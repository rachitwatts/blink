import XCTest
@testable import Blink

@MainActor
final class CalendarMonitorTests: XCTestCase {

    override func setUp() async throws {
        Settings.shared.resetToDefaults()
    }

    func testDisabledReturnsNoUpcomingEvents() {
        let monitor = CalendarMonitor.shared
        Settings.shared.calendarIntegrationEnabled = false

        XCTAssertFalse(monitor.nextEventStartsWithin(minutes: 3))
    }

    func testDefaultSettingsCalendarOff() {
        XCTAssertFalse(Settings.shared.calendarIntegrationEnabled)
        XCTAssertEqual(Settings.shared.calendarLeadTimeMinutes, 3)
        XCTAssertEqual(Settings.shared.watchedCalendarIdentifiers, "")
    }
}
