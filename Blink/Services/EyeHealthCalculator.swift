import Foundation

/// Metrics describing the user's eye health based on break behavior
struct EyeHealthMetrics {
    let breakCompliance: Double  // 0.0 to 1.0
    let snoozeRate: Double       // 0.0 to 1.0
    let grade: String            // A+, A, A-, B+, B, C, D
    let tip: String?             // Contextual tip if grade is C or below
}

/// Calculates an eye health grade from session events
///
/// Grade is based on break compliance (breaks completed vs skipped)
/// and snooze rate (snoozes vs breaks started). Tips are generated
/// only when grade is C or below.
final class EyeHealthCalculator {
    static func calculate(from events: [SessionEvent]) -> EyeHealthMetrics {
        let breaksCompleted = events.filter { $0.type == .breakCompleted }.count
        let breaksSkipped = events.filter { $0.type == .breakSkipped }.count
        let breaksSnoozed = events.filter { $0.type == .breakSnoozed }.count
        let breaksStarted = events.filter { $0.type == .breakStarted }.count

        let totalBreaks = breaksCompleted + breaksSkipped
        let breakCompliance = totalBreaks > 0 ? Double(breaksCompleted) / Double(totalBreaks) : 1.0
        let snoozeRate = breaksStarted > 0 ? min(1.0, Double(breaksSnoozed) / Double(breaksStarted)) : 0.0

        let grade = calculateGrade(breakCompliance: breakCompliance, snoozeRate: snoozeRate)
        let tip = generateTip(
            grade: grade,
            breaksCompleted: breaksCompleted,
            breaksSkipped: breaksSkipped,
            breaksSnoozed: breaksSnoozed,
            events: events
        )

        return EyeHealthMetrics(
            breakCompliance: breakCompliance,
            snoozeRate: snoozeRate,
            grade: grade,
            tip: tip
        )
    }

    // MARK: - Grade Calculation

    private static func calculateGrade(breakCompliance: Double, snoozeRate: Double) -> String {
        if breakCompliance >= 0.95 && snoozeRate <= 0.10 { return "A+" }
        if breakCompliance >= 0.90 && snoozeRate <= 0.20 { return "A" }
        if breakCompliance >= 0.85 && snoozeRate <= 0.30 { return "A-" }
        if breakCompliance >= 0.80 && snoozeRate <= 0.40 { return "B+" }
        if breakCompliance >= 0.70 && snoozeRate <= 0.50 { return "B" }
        if breakCompliance >= 0.50 { return "C" }
        return "D"
    }

    // MARK: - Tip Generation

    private static func generateTip(
        grade: String,
        breaksCompleted: Int,
        breaksSkipped: Int,
        breaksSnoozed: Int,
        events: [SessionEvent]
    ) -> String? {
        // Only show tips for C or below
        guard grade == "C" || grade == "D" else { return nil }

        let totalBreaks = breaksCompleted + breaksSkipped

        // Prioritize tips based on most actionable insight
        if totalBreaks > 0 && breaksSkipped > totalBreaks / 2 {
            return "You've skipped \(breaksSkipped) of \(totalBreaks) breaks. Try taking the next one \u{2014} even 30 seconds helps."
        }

        if breaksSnoozed > 0 && breaksCompleted == 0 {
            return "Every break was snoozed. Consider a shorter break duration in Settings."
        }

        let sessionsWithoutBreak = countSessionsWithoutBreak(events)
        if sessionsWithoutBreak >= 3 {
            return "You've completed \(sessionsWithoutBreak) sessions without a break. Your eyes need rest."
        }

        let consecutiveSkips = countConsecutiveSkips(events)
        if consecutiveSkips >= 3 {
            return "You've skipped \(consecutiveSkips) breaks in a row. Step away from the screen for a moment."
        }

        return "Your eyes need more rest breaks. Try to complete the next break."
    }

    // MARK: - Helpers

    /// Count the max run of completed sessions without a break completion in between
    private static func countSessionsWithoutBreak(_ events: [SessionEvent]) -> Int {
        var count = 0
        var maxCount = 0

        for event in events {
            if event.type == .sessionCompleted {
                count += 1
            } else if event.type == .breakCompleted {
                maxCount = max(maxCount, count)
                count = 0
            }
        }

        return max(maxCount, count)
    }

    /// Count the number of consecutive skips from the most recent event backward
    private static func countConsecutiveSkips(_ events: [SessionEvent]) -> Int {
        var count = 0
        var maxCount = 0

        for event in events.reversed() {
            if event.type == .breakSkipped {
                count += 1
                maxCount = max(maxCount, count)
            } else if event.type == .breakCompleted || event.type == .breakStarted {
                break
            } else {
                // Non-break event interrupts the consecutive skip run
                if count > 0 {
                    maxCount = max(maxCount, count)
                    count = 0
                }
            }
        }

        return maxCount
    }
}
