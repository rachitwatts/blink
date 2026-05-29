import XCTest
@testable import Blink

/// Tests for the pure eye-health grade calculation (previously ~48% covered).
final class EyeHealthCalculatorTests: XCTestCase {

    private func events(started: Int = 0,
                        completed: Int = 0,
                        skipped: Int = 0,
                        snoozed: Int = 0,
                        inCallNudges: Int = 0,
                        sessionsCompleted: Int = 0) -> [SessionEvent] {
        var types: [EventType] = []
        types += Array(repeating: .breakStarted, count: started)
        types += Array(repeating: .breakCompleted, count: completed)
        types += Array(repeating: .breakSkipped, count: skipped)
        types += Array(repeating: .breakSnoozed, count: snoozed)
        types += Array(repeating: .inCallNudgeShown, count: inCallNudges)
        types += Array(repeating: .sessionCompleted, count: sessionsCompleted)
        return types.map { SessionEvent(eventType: $0) }
    }

    // MARK: - Empty / unavailable

    func testNoBreakOutcomesReturnsUnavailableGrade() {
        let m = EyeHealthCalculator.calculate(from: [])
        XCTAssertEqual(m.grade, "—")
        XCTAssertEqual(m.breakCompliance, 0.0)
        XCTAssertEqual(m.breaksCompleted, 0)
        XCTAssertNil(m.tip)
    }

    func testOnlyNonBreakEventsStillUnavailable() {
        let m = EyeHealthCalculator.calculate(from: events(sessionsCompleted: 5))
        XCTAssertEqual(m.grade, "—")
    }

    // MARK: - Compliance / snooze math

    func testComplianceIsCompletedOverTotal() {
        let m = EyeHealthCalculator.calculate(from: events(started: 4, completed: 3, skipped: 1))
        XCTAssertEqual(m.breakCompliance, 0.75, accuracy: 0.0001)
        XCTAssertEqual(m.breaksCompleted, 3)
        XCTAssertEqual(m.breaksSkipped, 1)
    }

    func testInCallNudgeCountsAsEffectiveCompletion() {
        // 2 completed + 2 in-call nudges vs 0 skipped → full compliance.
        let m = EyeHealthCalculator.calculate(from: events(started: 4, completed: 2, inCallNudges: 2))
        XCTAssertEqual(m.breakCompliance, 1.0, accuracy: 0.0001)
    }

    func testSnoozeRateIsCappedAtOne() {
        // More snoozes than starts shouldn't exceed 1.0.
        let m = EyeHealthCalculator.calculate(from: events(started: 2, completed: 2, snoozed: 5))
        XCTAssertEqual(m.snoozeRate, 1.0, accuracy: 0.0001)
    }

    func testSnoozeRateZeroWhenNoStarts() {
        let m = EyeHealthCalculator.calculate(from: events(completed: 1))
        XCTAssertEqual(m.snoozeRate, 0.0)
    }

    // MARK: - Grade boundaries

    func testPerfectComplianceIsAPlus() {
        let m = EyeHealthCalculator.calculate(from: events(started: 20, completed: 20))
        XCTAssertEqual(m.grade, "A+")
    }

    func testGradeA() {
        // compliance 0.90, snooze 0.20 → A (not A+: compliance < 0.95)
        let m = EyeHealthCalculator.calculate(from: events(started: 20, completed: 18, skipped: 2, snoozed: 4))
        XCTAssertEqual(m.grade, "A")
    }

    func testGradeB() {
        // compliance 0.70, snooze 0.50 → B
        let m = EyeHealthCalculator.calculate(from: events(started: 10, completed: 7, skipped: 3, snoozed: 5))
        XCTAssertEqual(m.grade, "B")
    }

    func testGradeC() {
        // compliance 0.50 → C (fails B's 0.70 floor)
        let m = EyeHealthCalculator.calculate(from: events(started: 10, completed: 5, skipped: 5))
        XCTAssertEqual(m.grade, "C")
    }

    func testGradeD() {
        // compliance 0.40 → D
        let m = EyeHealthCalculator.calculate(from: events(started: 10, completed: 4, skipped: 6))
        XCTAssertEqual(m.grade, "D")
    }

    // MARK: - Tips

    func testNoTipForGoodGrades() {
        let m = EyeHealthCalculator.calculate(from: events(started: 20, completed: 20))
        XCTAssertNil(m.tip, "A+ should not produce a tip")
    }

    func testTipPresentForPoorGrade() {
        let m = EyeHealthCalculator.calculate(from: events(started: 10, completed: 4, skipped: 6))
        XCTAssertNotNil(m.tip, "D grade should produce an actionable tip")
    }

    func testSkippedMajorityTipMentionsCounts() {
        let m = EyeHealthCalculator.calculate(from: events(started: 10, completed: 4, skipped: 6))
        // Assert the data the tip must convey (6 skipped of 10), not the exact copy.
        let tip = m.tip ?? ""
        XCTAssertTrue(tip.contains("6"), "Tip should name the skipped count")
        XCTAssertTrue(tip.contains("10"), "Tip should name the total count")
    }
}
