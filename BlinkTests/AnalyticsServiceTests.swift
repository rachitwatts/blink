import XCTest
@testable import Blink

/// Tests for AnalyticsService recording + querying. BlinkTestCase configures
/// the service with an in-memory SwiftData container, so each test starts empty
/// and nothing is written to the real on-disk store.
final class AnalyticsServiceTests: BlinkTestCase {

    private var analytics: AnalyticsService { AnalyticsService.shared }

    func testRecordsEventsIntoStore() {
        analytics.recordSessionCompleted(actualDuration: 1500, configuredDuration: 1500)
        analytics.recordBreakCompleted(actualDuration: 300)
        let all = analytics.allEvents()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.map(\.type), [.sessionCompleted, .breakCompleted])
    }

    func testSessionCompletedStoresDurations() {
        analytics.recordSessionCompleted(actualDuration: 1490, configuredDuration: 1500)
        let event = analytics.allEvents().first
        XCTAssertEqual(event?.type, .sessionCompleted)
        XCTAssertEqual(event?.durationSeconds, 1490)
        XCTAssertEqual(event?.configuredDurationSeconds, 1500)
    }

    func testBreakSnoozedStoresMetadata() {
        analytics.recordBreakSnoozed(snoozeDuration: 300, breakId: "abc")
        let event = analytics.allEvents().first
        XCTAssertEqual(event?.type, .breakSnoozed)
        XCTAssertEqual(event?.metadata?["breakId"], "abc")
        XCTAssertEqual(event?.metadata?["snoozeDuration"], "300")
    }

    func testEventsForTodayIncludesJustRecorded() {
        analytics.recordBreakStarted(trigger: "auto", configuredDuration: 300)
        XCTAssertEqual(analytics.eventsForToday().count, 1)
    }

    func testEventsForDateRangeFiltersByTimestamp() {
        analytics.recordBreakStarted(trigger: "auto", configuredDuration: 300)
        // A range entirely in the past excludes today's event…
        let pastOnly = analytics.eventsForDateRange(from: .distantPast,
                                                    to: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(pastOnly.isEmpty)
        // …a wide range includes it.
        let wide = analytics.eventsForDateRange(from: .distantPast, to: .distantFuture)
        XCTAssertEqual(wide.count, 1)
    }

    func testFirstEventDateIsNilThenSet() {
        XCTAssertNil(analytics.firstEventDate())
        analytics.recordSessionCompleted(actualDuration: 60, configuredDuration: 60)
        XCTAssertNotNil(analytics.firstEventDate())
    }

    func testResetAllDataClearsStore() throws {
        analytics.recordSessionCompleted(actualDuration: 60, configuredDuration: 60)
        analytics.recordBreakSkipped(remainingSeconds: 30)
        XCTAssertEqual(analytics.allEvents().count, 2)

        try analytics.resetAllData()

        XCTAssertTrue(analytics.allEvents().isEmpty)
    }

    func testTodaySummaryComputesFocusAndSessions() {
        analytics.recordSessionCompleted(actualDuration: 1800, configuredDuration: 1800)
        analytics.recordSessionCompleted(actualDuration: 1800, configuredDuration: 1800)

        let summary = analytics.todaySummary()
        XCTAssertEqual(summary.sessionsCompleted, 2)
        XCTAssertEqual(summary.focusTimeFormatted, "1h 0m", "3600s of focus → 1h 0m")
    }
}
