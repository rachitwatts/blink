import Foundation

enum AnalysisScope {
    case today, week, month, allTime
}

final class EyeHealthAnalyzer {

    // MARK: - Analysis

    static func analyze(events: [SessionEvent], settings: Settings, scope: AnalysisScope, previousPeriodEvents: [SessionEvent] = []) -> [EyeHealthInsight] {
        guard !events.isEmpty else { return [] }

        var insights: [EyeHealthInsight] = []

        let detectors: [(([SessionEvent], Settings, AnalysisScope) -> EyeHealthInsight?)] = [
            detectTimeOfDaySkips,
            detectConsecutiveSkips,
            detectSnoozeThenComplete,
            detectLongNoBreakRun,
            detectWorstDayCompliance,
            detectBreakTooLong,
            detectMorningSkipPattern
        ]

        for detector in detectors {
            if let pattern = detector(events, settings, scope) {
                insights.append(pattern)
                if let suggestion = generateSuggestion(for: pattern, events: events, settings: settings) {
                    insights.append(suggestion)
                }
            }
        }

        // Declining compliance needs both current and prior period
        let combinedForDeclining = previousPeriodEvents + events
        if let pattern = detectDecliningCompliance(combinedForDeclining, settings, scope) {
            insights.append(pattern)
            if let suggestion = generateSuggestion(for: pattern, events: events, settings: settings) {
                insights.append(suggestion)
            }
        }

        insights.sort { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity < rhs.severity
            }
            if lhs.category != rhs.category {
                return lhs.category == .pattern
            }
            return false
        }

        return insights
    }

    // MARK: - Dismissal Persistence

    private static let dismissedKey = "dismissedEyeHealthInsights"

    static func dismiss(_ insightID: String) {
        var dismissed = loadDismissed()
        dismissed.insert(insightID)
        saveDismissed(dismissed)
    }

    static func resetDismissals() {
        UserDefaults.standard.removeObject(forKey: dismissedKey)
    }

    static func loadDismissed() -> Set<String> {
        guard let raw = UserDefaults.standard.string(forKey: dismissedKey), !raw.isEmpty else {
            return []
        }
        return Set(raw.components(separatedBy: ","))
    }

    static func filterDismissed(_ insights: [EyeHealthInsight], dismissed: Set<String>) -> [EyeHealthInsight] {
        insights.filter { !dismissed.contains($0.id) }
    }

    private static func saveDismissed(_ ids: Set<String>) {
        UserDefaults.standard.set(ids.sorted().joined(separator: ","), forKey: dismissedKey)
    }

    // MARK: - Pattern Detectors

    /// Detector 1: >60% of skips cluster in a 3-hour window
    private static func detectTimeOfDaySkips(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        let skips = events.filter { $0.type == .breakSkipped }
        guard skips.count >= 3 else { return nil }

        let calendar = Calendar.current
        var hourCounts = [Int: Int]()
        for skip in skips {
            let hour = calendar.component(.hour, from: skip.timestamp)
            hourCounts[hour, default: 0] += 1
        }

        // Slide a 3-hour window across 24 hours and find the peak
        var bestWindowStart = 0
        var bestWindowCount = 0
        for start in 0..<24 {
            var count = 0
            for offset in 0..<3 {
                let hour = (start + offset) % 24
                count += hourCounts[hour, default: 0]
            }
            if count > bestWindowCount {
                bestWindowCount = count
                bestWindowStart = start
            }
        }

        let skipRate = Double(bestWindowCount) / Double(skips.count)
        guard skipRate > 0.6 else { return nil }

        let windowEnd = (bestWindowStart + 3) % 24
        let startLabel = formatHour(bestWindowStart)
        let endLabel = formatHour(windowEnd)
        let pct = Int(skipRate * 100)

        return EyeHealthInsight(
            id: "time_of_day_skips",
            category: .pattern,
            severity: .medium,
            title: "Skip-heavy period",
            description: "\(pct)% of your skipped breaks happen between \(startLabel)\u{2013}\(endLabel).",
            icon: "clock.badge.exclamationmark"
        )
    }

    /// Detector 2: 3+ breaks skipped in a row
    private static func detectConsecutiveSkips(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        var streak = 0
        var maxStreak = 0

        for event in events {
            if event.type == .breakSkipped {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else if event.type == .breakCompleted {
                streak = 0
            }
        }

        guard maxStreak >= 3 else { return nil }

        return EyeHealthInsight(
            id: "consecutive_skips",
            category: .pattern,
            severity: .high,
            title: "Consecutive skip streak",
            description: "You skipped \(maxStreak) breaks in a row.",
            icon: "forward.fill"
        )
    }

    /// Detector 3: >50% of completed breaks had 2+ snoozes first
    private static func detectSnoozeThenComplete(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        var snoozeCount = 0
        var completedWithHeavySnooze = 0
        var totalCompleted = 0

        for event in events {
            switch event.type {
            case .breakSnoozed:
                snoozeCount += 1
            case .breakCompleted:
                totalCompleted += 1
                if snoozeCount >= 2 {
                    completedWithHeavySnooze += 1
                }
                snoozeCount = 0
            case .breakSkipped:
                snoozeCount = 0
            case .breakStarted:
                // A new break cycle resets snooze tracking
                snoozeCount = 0
            default:
                break
            }
        }

        guard totalCompleted >= 3 else { return nil }
        let rate = Double(completedWithHeavySnooze) / Double(totalCompleted)
        guard rate > 0.5 else { return nil }

        let pct = Int(rate * 100)
        return EyeHealthInsight(
            id: "snooze_then_complete",
            category: .pattern,
            severity: .medium,
            title: "Snooze before every break",
            description: "\(pct)% of your completed breaks needed 2+ snoozes first.",
            icon: "alarm.waves.left.and.right"
        )
    }

    /// Detector 4: 3+ sessions completed without any break taken
    private static func detectLongNoBreakRun(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        var sessionsWithoutBreak = 0
        var maxRun = 0

        for event in events {
            if event.type == .sessionCompleted {
                sessionsWithoutBreak += 1
                maxRun = max(maxRun, sessionsWithoutBreak)
            } else if event.type == .breakCompleted {
                sessionsWithoutBreak = 0
            }
        }

        guard maxRun >= 3 else { return nil }

        return EyeHealthInsight(
            id: "long_no_break_run",
            category: .pattern,
            severity: .high,
            title: "Long stretch without breaks",
            description: "You completed \(maxRun) work sessions without taking a break.",
            icon: "eye.trianglebadge.exclamationmark"
        )
    }

    /// Detector 5: One weekday has compliance 20+ points below average (week/month/allTime only)
    private static func detectWorstDayCompliance(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        guard scope != .today else { return nil }

        let calendar = Calendar.current
        var dayCompleted = [Int: Int]()  // weekday -> completed count
        var dayTotal = [Int: Int]()      // weekday -> total (completed + skipped)

        for event in events {
            let weekday = calendar.component(.weekday, from: event.timestamp)
            if event.type == .breakCompleted {
                dayCompleted[weekday, default: 0] += 1
                dayTotal[weekday, default: 0] += 1
            } else if event.type == .breakSkipped {
                dayTotal[weekday, default: 0] += 1
            }
        }

        // Need at least 2 weekdays with data
        let activeDays = dayTotal.filter { $0.value > 0 }
        guard activeDays.count >= 2 else { return nil }

        var dayCompliance = [Int: Double]()
        var totalCompleted = 0
        var totalBreaks = 0
        for (weekday, total) in dayTotal where total > 0 {
            let completed = dayCompleted[weekday, default: 0]
            dayCompliance[weekday] = Double(completed) / Double(total) * 100
            totalCompleted += completed
            totalBreaks += total
        }

        let avgCompliance = Double(totalCompleted) / Double(totalBreaks) * 100

        // Find worst day
        guard let (worstDay, worstCompliance) = dayCompliance.min(by: { $0.value < $1.value }) else { return nil }
        guard avgCompliance - worstCompliance >= 20 else { return nil }

        let dayName = calendar.weekdaySymbols[worstDay - 1]
        let worstPct = Int(worstCompliance)
        let avgPct = Int(avgCompliance)

        return EyeHealthInsight(
            id: "worst_day_compliance",
            category: .pattern,
            severity: .medium,
            title: "\(dayName)s are tough",
            description: "Your break compliance on \(dayName)s is \(worstPct)% vs \(avgPct)% average.",
            icon: "calendar.badge.exclamationmark"
        )
    }

    /// Detector 6: Snooze rate >40% AND break duration above default (5 min)
    private static func detectBreakTooLong(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        let snoozed = events.filter { $0.type == .breakSnoozed }.count
        let started = events.filter { $0.type == .breakStarted }.count
        guard started >= 3 else { return nil }

        let snoozeRate = Double(snoozed) / Double(started)
        guard snoozeRate > 0.4, settings.breakDurationMinutes > 5 else { return nil }

        return EyeHealthInsight(
            id: "break_too_long",
            category: .pattern,
            severity: .low,
            title: "Break duration might be too long",
            description: "Your snooze rate is \(Int(snoozeRate * 100))% with \(settings.breakDurationMinutes)-minute breaks.",
            icon: "timer.circle"
        )
    }

    /// Detector 7: First 2+ breaks of the day are always/usually skipped
    private static func detectMorningSkipPattern(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        let calendar = Calendar.current

        // Group break outcomes by day
        var dayOutcomes = [Date: [(type: EventType, timestamp: Date)]]()
        for event in events {
            guard event.type == .breakCompleted || event.type == .breakSkipped else { continue }
            let dayStart = calendar.startOfDay(for: event.timestamp)
            dayOutcomes[dayStart, default: []].append((type: event.type!, timestamp: event.timestamp))
        }

        // Sort outcomes within each day by timestamp
        for key in dayOutcomes.keys {
            dayOutcomes[key]?.sort { $0.timestamp < $1.timestamp }
        }

        // Check how many days have their first 2+ break outcomes as skips
        var daysWithEarlySkips = 0
        var daysChecked = 0

        for (_, outcomes) in dayOutcomes {
            guard outcomes.count >= 2 else { continue }
            daysChecked += 1

            let firstTwo = Array(outcomes.prefix(2))
            if firstTwo.allSatisfy({ $0.type == .breakSkipped }) {
                daysWithEarlySkips += 1
            }
        }

        guard daysChecked >= 2 else { return nil }
        let rate = Double(daysWithEarlySkips) / Double(daysChecked)
        guard rate >= 0.6 else { return nil }

        return EyeHealthInsight(
            id: "morning_skip_pattern",
            category: .pattern,
            severity: .medium,
            title: "Early breaks get skipped",
            description: "On \(daysWithEarlySkips) of \(daysChecked) days, your first breaks were skipped.",
            icon: "sunrise"
        )
    }

    /// Detector 8: Current period's compliance is 15+ points below previous period (week/month/allTime only)
    private static func detectDecliningCompliance(_ events: [SessionEvent], _ settings: Settings, _ scope: AnalysisScope) -> EyeHealthInsight? {
        guard scope != .today else { return nil }

        let calendar = Calendar.current
        let now = Date()

        let (currentStart, previousStart, previousEnd): (Date, Date, Date) = {
            switch scope {
            case .week:
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
                return (weekStart, prevWeekStart, weekStart)
            case .month:
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!
                return (monthStart, prevMonthStart, monthStart)
            case .allTime, .today:
                // For allTime, compare last 30 days vs previous 30 days
                let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
                let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now)!
                return (thirtyDaysAgo, sixtyDaysAgo, thirtyDaysAgo)
            }
        }()

        let currentEvents = events.filter { $0.timestamp >= currentStart }
        let previousEvents = events.filter { $0.timestamp >= previousStart && $0.timestamp < previousEnd }

        let currentCompliance = complianceRate(for: currentEvents)
        let previousCompliance = complianceRate(for: previousEvents)

        guard let current = currentCompliance, let previous = previousCompliance else { return nil }
        let drop = previous - current
        guard drop >= 15 else { return nil }

        let periodLabel: String = {
            switch scope {
            case .week: return "week"
            case .month: return "month"
            case .allTime: return "30 days"
            case .today: return "period"
            }
        }()

        return EyeHealthInsight(
            id: "declining_compliance",
            category: .pattern,
            severity: .high,
            title: "Compliance is declining",
            description: "Your break compliance dropped from \(Int(previous))% to \(Int(current))% compared to last \(periodLabel).",
            icon: "arrow.down.right"
        )
    }

    // MARK: - Suggestion Generator

    private static func generateSuggestion(for pattern: EyeHealthInsight, events: [SessionEvent], settings: Settings) -> EyeHealthInsight? {
        switch pattern.id {
        case "time_of_day_skips":
            return EyeHealthInsight(
                id: "time_of_day_skips_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Adjust your schedule",
                description: "Try scheduling deep work outside your peak skip window, or use shorter breaks during that time.",
                icon: "lightbulb"
            )

        case "consecutive_skips":
            return EyeHealthInsight(
                id: "consecutive_skips_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Start with a micro-break",
                description: "Even a 30-second break helps. Try completing just the next one.",
                icon: "lightbulb"
            )

        case "snooze_then_complete":
            let snoozeMins = settings.snoozeDurationMinutes
            return EyeHealthInsight(
                id: "snooze_then_complete_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Shorten your snooze",
                description: "You eventually take breaks after snoozing. Try a shorter snooze (currently \(snoozeMins)m).",
                icon: "lightbulb"
            )

        case "long_no_break_run":
            let maxRun = countMaxSessionsWithoutBreak(events)
            return EyeHealthInsight(
                id: "long_no_break_run_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Shorter work sessions",
                description: "You went \(maxRun) sessions without a break. Consider a shorter work duration.",
                icon: "lightbulb"
            )

        case "worst_day_compliance":
            return EyeHealthInsight(
                id: "worst_day_compliance_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Plan for tough days",
                description: "Plan lighter work on your lowest-compliance day to leave room for breaks.",
                icon: "lightbulb"
            )

        case "break_too_long":
            let current = settings.breakDurationMinutes
            let suggested = max(3, current - 2)
            return EyeHealthInsight(
                id: "break_too_long_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Try shorter breaks",
                description: "Your \(current)-minute break might feel too long. Try \(suggested) minutes.",
                icon: "lightbulb"
            )

        case "morning_skip_pattern":
            return EyeHealthInsight(
                id: "morning_skip_pattern_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Ease into breaks",
                description: "You tend to skip early breaks. Try starting Blink after your first coffee.",
                icon: "lightbulb"
            )

        case "declining_compliance":
            return EyeHealthInsight(
                id: "declining_compliance_suggestion",
                category: .suggestion,
                severity: pattern.severity,
                title: "Reflect on what changed",
                description: "Your compliance dropped recently. Consider what changed in your routine.",
                icon: "lightbulb"
            )

        default:
            return nil
        }
    }

    // MARK: - Helpers

    private static func complianceRate(for events: [SessionEvent]) -> Double? {
        let completed = events.filter { $0.type == .breakCompleted }.count
        let skipped = events.filter { $0.type == .breakSkipped }.count
        let total = completed + skipped
        guard total >= 3 else { return nil }
        return Double(completed) / Double(total) * 100
    }

    private static func countMaxSessionsWithoutBreak(_ events: [SessionEvent]) -> Int {
        var count = 0
        var maxCount = 0
        for event in events {
            if event.type == .sessionCompleted {
                count += 1
                maxCount = max(maxCount, count)
            } else if event.type == .breakCompleted {
                count = 0
            }
        }
        return maxCount
    }

    private static func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h) \(suffix)"
    }
}
