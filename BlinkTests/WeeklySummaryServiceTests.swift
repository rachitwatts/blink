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

    func testPerfectWeekCelebrationFullText() {
        let m = metrics(compliance: 1.0, grade: "A+")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "Perfect week! You completed 100% of breaks with an A+ grade. Keep it up!")
    }

    func testHighButNotPerfectCelebrationFullText() {
        let m = metrics(compliance: 0.96, grade: "A")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "Great week! You completed 96% of breaks — grade: A. Your eyes thank you.")
    }

    // Threshold boundaries: 95 → celebration, 80 → solid, 50 → mid, below → low.

    func testBoundaryAt95IsCelebration() {
        let m = metrics(compliance: 0.95, grade: "A")
        XCTAssertTrue(WeeklySummaryService.summaryBody(metrics: m, insights: []).hasPrefix("Great week!"))
    }

    func testJustBelow95FallsToSolid() {
        let m = metrics(compliance: 0.94, grade: "A-")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "Solid week — 94% break compliance (grade: A-). Can you hit 90% next week?")
    }

    func testBoundaryAt50IsMidNotLow() {
        let m = metrics(compliance: 0.50, grade: "C")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "You completed 50% of breaks this week (grade: C). Try completing one more break each day.")
    }

    func testJustBelow50IsLow() {
        let m = metrics(compliance: 0.49, grade: "D")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "You skipped most breaks this week (49% compliance). Even a 30-second break helps — try taking the next one.")
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

    func testFallbackSolidWeekFullText() {
        let m = metrics(compliance: 0.85, grade: "B+")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "Solid week — 85% break compliance (grade: B+). Can you hit 90% next week?")
    }

    func testFallbackMidComplianceFullText() {
        let m = metrics(compliance: 0.60, grade: "C")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "You completed 60% of breaks this week (grade: C). Try completing one more break each day.")
    }

    func testFallbackLowComplianceFullText() {
        let m = metrics(compliance: 0.30, grade: "D")
        XCTAssertEqual(WeeklySummaryService.summaryBody(metrics: m, insights: []),
                       "You skipped most breaks this week (30% compliance). Even a 30-second break helps — try taking the next one.")
    }
}
