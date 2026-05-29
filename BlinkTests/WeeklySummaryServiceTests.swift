import XCTest
@testable import Blink

/// Tests for the pure weekly-summary message selection (extracted from the
/// notification-driven service so the threshold/branch logic is testable).
@MainActor
final class WeeklySummaryServiceTests: XCTestCase {

    private func metrics(compliance: Double,
                         grade: String,
                         completed: Int = 5,
                         skipped: Int = 5) -> EyeHealthMetrics {
        EyeHealthMetrics(
            breakCompliance: compliance, snoozeRate: 0, grade: grade, tip: nil,
            breaksCompleted: completed, breaksSkipped: skipped,
            breaksSnoozed: 0, breaksStarted: completed + skipped)
    }

    private func insight(_ id: String,
                         _ category: EyeHealthInsight.Category,
                         _ description: String) -> EyeHealthInsight {
        EyeHealthInsight(id: id, category: category, severity: .medium,
                         title: "", description: description, icon: "")
    }

    func testNoBreakDataMessage() {
        let m = metrics(compliance: 0, grade: "—", completed: 0, skipped: 0)
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "No break data this week. Open Blink and let it run during your work sessions!")
    }

    func testPerfectWeekCelebration() {
        let m = metrics(compliance: 1.0, grade: "A+")
        XCTAssertTrue(WeeklySummaryService.summaryBody(metrics: m, insights: []).contains("Perfect week"))
    }

    func testHighButNotPerfectCelebration() {
        let m = metrics(compliance: 0.96, grade: "A")
        let body = WeeklySummaryService.summaryBody(metrics: m, insights: [])
        XCTAssertTrue(body.contains("Great week"))
    }

    func testTopInsightWithSuggestionCombinesDescriptions() {
        let m = metrics(compliance: 0.6, grade: "C")
        let insights = [
            insight("consecutive_skips", .pattern, "You skipped 4 breaks in a row."),
            insight("consecutive_skips_suggestion", .suggestion, "Even a 30-second break helps."),
        ]
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: insights),
                       "You skipped 4 breaks in a row. Even a 30-second break helps.")
    }

    func testTopInsightWithoutSuggestionUsesPatternOnly() {
        let m = metrics(compliance: 0.6, grade: "C")
        let insights = [insight("consecutive_skips", .pattern, "You skipped 4 breaks in a row.")]
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: insights),
                       "You skipped 4 breaks in a row.")
    }

    func testFallbackSolidWeek() {
        let m = metrics(compliance: 0.85, grade: "B+")
        XCTAssertTrue(WeeklySummaryService.summaryBody(metrics: m, insights: []).hasPrefix("Solid week"))
    }

    func testFallbackMidCompliance() {
        let m = metrics(compliance: 0.60, grade: "C")
        XCTAssertTrue(WeeklySummaryService.summaryBody(metrics: m, insights: []).contains("You completed 60%"))
    }

    func testFallbackLowCompliance() {
        let m = metrics(compliance: 0.30, grade: "D")
        XCTAssertTrue(WeeklySummaryService.summaryBody(metrics: m, insights: []).contains("skipped most breaks"))
    }
}
