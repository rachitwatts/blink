import XCTest
@testable import Blink

/// Tests for EyeHealthAnalyzer (was 0% covered, 504 lines of detector logic).
/// Inherits BlinkTestCase for an isolated Settings store; the analyzer's
/// dismissal store is pointed at the same ephemeral suite.
final class EyeHealthAnalyzerTests: BlinkTestCase {

    override func setUp() async throws {
        try await super.setUp()
        EyeHealthAnalyzer.setStoreForTesting(testDefaults)
    }

    // MARK: - Helpers

    private func event(_ type: EventType, hour: Int = 12, day: Int = 2) -> SessionEvent {
        let ts = Calendar.current.date(
            from: DateComponents(year: 2025, month: 6, day: day, hour: hour, minute: 0))!
        return SessionEvent(eventType: type, timestamp: ts)
    }

    private func ids(_ insights: [EyeHealthInsight]) -> [String] { insights.map(\.id) }

    // MARK: - analyze: detectors

    func testEmptyEventsReturnsNoInsights() {
        XCTAssertTrue(EyeHealthAnalyzer.analyze(events: [], settings: Settings.shared, scope: .week).isEmpty)
    }

    func testConsecutiveSkipsDetectedWithPairedSuggestion() {
        // 3 skips in a row, spread across hours so the time-of-day detector
        // doesn't also fire and muddy the assertion.
        let events = [event(.breakSkipped, hour: 2),
                      event(.breakSkipped, hour: 10),
                      event(.breakSkipped, hour: 18)]
        let result = ids(EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: .week))
        XCTAssertTrue(result.contains("consecutive_skips"))
        XCTAssertTrue(result.contains("consecutive_skips_suggestion"))
    }

    func testCompletionResetsConsecutiveSkipStreak() {
        let events = [event(.breakSkipped, hour: 2),
                      event(.breakSkipped, hour: 10),
                      event(.breakCompleted, hour: 11),
                      event(.breakSkipped, hour: 18)]
        let result = ids(EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: .week))
        XCTAssertFalse(result.contains("consecutive_skips"), "Max streak is 2, below the 3 threshold")
    }

    func testLongNoBreakRunDetected() {
        let events = [event(.sessionCompleted), event(.sessionCompleted), event(.sessionCompleted)]
        let result = ids(EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: .week))
        XCTAssertTrue(result.contains("long_no_break_run"))
        XCTAssertTrue(result.contains("long_no_break_run_suggestion"))
    }

    func testTimeOfDaySkipsDetectedWhenClustered() {
        let events = (0..<5).map { _ in event(.breakSkipped, hour: 14) }
        let result = ids(EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: .week))
        XCTAssertTrue(result.contains("time_of_day_skips"))
    }

    func testBreakTooLongDetectedOnlyWithLongerDuration() {
        Settings.shared.breakDurationMinutes = 10
        let events = (0..<5).map { _ in event(.breakStarted) } + (0..<3).map { _ in event(.breakSnoozed) }
        let withLong = ids(EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: .week))
        XCTAssertTrue(withLong.contains("break_too_long"))

        Settings.shared.breakDurationMinutes = 5  // default → guard fails
        let withDefault = ids(EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: .week))
        XCTAssertFalse(withDefault.contains("break_too_long"))
    }

    func testDecliningComplianceDetected() {
        let current = [event(.breakCompleted), event(.breakSkipped), event(.breakSkipped), event(.breakSkipped)]
        let previous = [event(.breakCompleted), event(.breakCompleted), event(.breakCompleted), event(.breakCompleted)]
        let result = ids(EyeHealthAnalyzer.analyze(
            events: current, settings: Settings.shared, scope: .week, previousPeriodEvents: previous))
        XCTAssertTrue(result.contains("declining_compliance"))
    }

    func testWorstDayAndDecliningFireForWeekButNotToday() {
        // Fixture that genuinely satisfies the worst-day inner guards (≥2 active
        // weekdays, ≥20pt gap) so the scope guard is the deciding factor:
        // Monday all-completed (100%), Tuesday all-skipped (0%) → 50pt gap.
        let current = (0..<4).map { _ in event(.breakCompleted, day: 2) }   // Monday
                    + (0..<4).map { _ in event(.breakSkipped, day: 3) }     // Tuesday
        let previous = (0..<4).map { _ in event(.breakCompleted, day: 2) }  // prior 100% → decline

        let week = ids(EyeHealthAnalyzer.analyze(
            events: current, settings: Settings.shared, scope: .week, previousPeriodEvents: previous))
        XCTAssertTrue(week.contains("worst_day_compliance"), "Worst-day should fire for .week")
        XCTAssertTrue(week.contains("declining_compliance"), "Declining should fire for .week")

        let today = ids(EyeHealthAnalyzer.analyze(
            events: current, settings: Settings.shared, scope: .today, previousPeriodEvents: previous))
        XCTAssertFalse(today.contains("worst_day_compliance"), "Worst-day is suppressed for .today")
        XCTAssertFalse(today.contains("declining_compliance"), "Declining is suppressed for .today")
    }

    func testInsightsSortedSeverestFirst() {
        // consecutive_skips (high) + time_of_day clustered (medium) both fire.
        let events = (0..<5).map { _ in event(.breakSkipped, hour: 14) }
        let insights = EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: .week)
        XCTAssertEqual(insights.first?.severity, .high, "Highest-severity insight should sort first")
    }

    // MARK: - Dismissal persistence (injected store)

    func testDismissPairsPatternAndSuggestion() {
        EyeHealthAnalyzer.dismiss("consecutive_skips")
        let dismissed = EyeHealthAnalyzer.loadDismissed()
        XCTAssertTrue(dismissed.contains("consecutive_skips"))
        XCTAssertTrue(dismissed.contains("consecutive_skips_suggestion"))
    }

    func testDismissingSuggestionAlsoDismissesPattern() {
        EyeHealthAnalyzer.dismiss("consecutive_skips_suggestion")
        let dismissed = EyeHealthAnalyzer.loadDismissed()
        XCTAssertTrue(dismissed.contains("consecutive_skips"))
        XCTAssertTrue(dismissed.contains("consecutive_skips_suggestion"))
    }

    func testFilterDismissedRemovesMatchingInsights() {
        let insights = [
            EyeHealthInsight(id: "a", category: .pattern, severity: .high, title: "", description: "", icon: ""),
            EyeHealthInsight(id: "b", category: .pattern, severity: .low, title: "", description: "", icon: ""),
        ]
        let filtered = EyeHealthAnalyzer.filterDismissed(insights, dismissed: ["a"])
        XCTAssertEqual(filtered.map(\.id), ["b"])
    }

    func testResetDismissalsClearsStore() {
        EyeHealthAnalyzer.dismiss("consecutive_skips")
        XCTAssertFalse(EyeHealthAnalyzer.loadDismissed().isEmpty)
        EyeHealthAnalyzer.resetDismissals()
        XCTAssertTrue(EyeHealthAnalyzer.loadDismissed().isEmpty)
    }
}
