import XCTest
@testable import Blink

/// Tests for TodayStats — the pure presentation logic extracted from TodayView.
final class TodayStatsTests: XCTestCase {

    private func event(_ type: EventType, duration: Int? = nil, reason: String? = nil,
                       at seconds: TimeInterval = 0) -> SessionEvent {
        SessionEvent(eventType: type,
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000 + seconds),
                     durationSeconds: duration,
                     reason: reason)
    }

    // MARK: - Stats

    func testFocusTimeSumsSessionAndResetDurations() {
        let stats = TodayStats(events: [
            event(.sessionCompleted, duration: 1800),
            event(.sessionReset, duration: 600),
            event(.breakCompleted, duration: 300),  // breaks don't count toward focus
        ])
        XCTAssertEqual(stats.focusTimeSeconds, 2400)
    }

    func testFocusTimeFormatted() {
        XCTAssertEqual(TodayStats(events: [event(.sessionCompleted, duration: 3660)]).focusTimeFormatted, "1h 1m")
        XCTAssertEqual(TodayStats(events: [event(.sessionCompleted, duration: 600)]).focusTimeFormatted, "10m")
    }

    func testComplianceDefaultsTo100WithNoBreakOutcomes() {
        let stats = TodayStats(events: [event(.sessionCompleted, duration: 1800)])
        XCTAssertEqual(stats.breakCompliancePercent, 100)
    }

    func testCompliancePercentFromCompletedAndSkipped() {
        let stats = TodayStats(events: [
            event(.breakCompleted), event(.breakCompleted), event(.breakCompleted), event(.breakSkipped),
        ])
        XCTAssertEqual(stats.breakCompliancePercent, 75)
        XCTAssertEqual(stats.breaksCompleted, 3)
        XCTAssertEqual(stats.breaksSkipped, 1)
    }

    func testSessionsCompletedCount() {
        let stats = TodayStats(events: [
            event(.sessionCompleted), event(.sessionCompleted), event(.sessionReset),
        ])
        XCTAssertEqual(stats.sessionsCompleted, 2)
    }

    // MARK: - Session log mapping

    func testSessionResetReasonMapping() {
        let idle = TodayStats.sessionLogEntries(from: [event(.sessionReset, duration: 1500, reason: "idle_timeout")])
        XCTAssertTrue(idle.first?.description.contains("idle reset") ?? false)

        let manual = TodayStats.sessionLogEntries(from: [event(.sessionReset, duration: 1500, reason: "manual_restart")])
        XCTAssertTrue(manual.first?.description.contains("manual restart") ?? false)

        let appQuit = TodayStats.sessionLogEntries(from: [event(.sessionReset, duration: 1500, reason: "app_quit")])
        XCTAssertTrue(appQuit.first?.description.contains("app quit") ?? false)
    }

    func testSessionLogIncludesAllOutcomeTypes() {
        let entries = TodayStats.sessionLogEntries(from: [
            event(.sessionCompleted, duration: 1500),
            event(.breakCompleted),
            event(.breakSkipped),
            event(.breakSnoozed),
            event(.appLaunched),  // not a session-log event → ignored
        ])
        XCTAssertEqual(entries.count, 4)
        XCTAssertTrue(entries[0].description.contains("break triggered"))
        XCTAssertEqual(entries[1].description, "Break completed")
        XCTAssertEqual(entries[2].description, "Break skipped")
        XCTAssertEqual(entries[3].description, "Break snoozed")
    }

    // MARK: - Timeline

    func testTimelineSegmentsBuiltFromDurationsAndSorted() {
        let segments = TodayStats.timelineSegments(from: [
            event(.breakCompleted, duration: 300, at: 5000),
            event(.sessionCompleted, duration: 1800, at: 1000),
        ])
        XCTAssertEqual(segments.count, 2)
        XCTAssertLessThan(segments[0].startTime, segments[1].startTime, "Segments are sorted by start time")
    }

    func testTimelineIgnoresEventsWithoutDuration() {
        let segments = TodayStats.timelineSegments(from: [event(.sessionCompleted, duration: nil)])
        XCTAssertTrue(segments.isEmpty)
    }
}
