import SwiftUI
import Charts

/// Weekly statistics for one week in the month view
struct WeeklyStats: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let startDate: Date
    let focusSeconds: Int
    let sessionsCompleted: Int
    let breakCompliance: Double  // 0.0 to 1.0
}

/// Month tab content for the analytics dashboard
///
/// Shows the last 30 days aggregated by week with focus time bar chart,
/// compliance line chart, summary stat cards, and best week insight.
struct MonthView: View {
    @State private var weeklyStats: [WeeklyStats] = []
    @State private var eyeHealthMetrics: EyeHealthMetrics?

    // MARK: - Computed Stats

    private var totalFocusSeconds: Int {
        weeklyStats.map(\.focusSeconds).reduce(0, +)
    }

    private var totalSessions: Int {
        weeklyStats.map(\.sessionsCompleted).reduce(0, +)
    }

    private var overallCompliance: Int {
        guard !weeklyStats.isEmpty else { return 100 }
        let avg = weeklyStats.map(\.breakCompliance).reduce(0, +) / Double(weeklyStats.count)
        return Int(avg * 100)
    }

    private var bestWeek: WeeklyStats? {
        weeklyStats.max(by: { $0.focusSeconds < $1.focusSeconds })
    }

    // MARK: - Body

    var body: some View {
        if weeklyStats.allSatisfy({ $0.focusSeconds == 0 }) && !weeklyStats.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No Data This Month")
                    .font(.headline)
                Text("Use Blink for a few weeks to see monthly trends.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { loadData() }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text("Last 30 Days")
                        .font(.title2)
                        .fontWeight(.semibold)

                    // Stat cards
                    HStack(spacing: 12) {
                        StatCardView(
                            value: formatDuration(totalFocusSeconds),
                            label: "Total Focus",
                            sublabel: "Time"
                        )
                        StatCardView(
                            value: "\(totalSessions)",
                            label: "Sessions",
                            sublabel: "Completed"
                        )
                        StatCardView(
                            value: "\(overallCompliance)%",
                            label: "Break",
                            sublabel: "Compliance"
                        )
                        StatCardView(
                            value: eyeHealthMetrics?.grade ?? "\u{2014}",
                            label: "Eye",
                            sublabel: "Health"
                        )
                    }

                    // Weekly focus time bar chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Focus Time")
                            .font(.headline)

                        Chart(weeklyStats) { week in
                            BarMark(
                                x: .value("Week", weekLabel(for: week)),
                                y: .value("Focus", week.focusSeconds / 60)
                            )
                            .foregroundStyle(Color.blue)
                        }
                        .chartYAxisLabel("Minutes")
                        .frame(height: 200)
                    }

                    // Weekly compliance line chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Break Compliance")
                            .font(.headline)

                        Chart(weeklyStats) { week in
                            LineMark(
                                x: .value("Week", weekLabel(for: week)),
                                y: .value("Compliance", week.breakCompliance * 100)
                            )
                            .foregroundStyle(Color.green)

                            PointMark(
                                x: .value("Week", weekLabel(for: week)),
                                y: .value("Compliance", week.breakCompliance * 100)
                            )
                            .foregroundStyle(Color.green)
                        }
                        .chartYAxisLabel("%")
                        .chartYScale(domain: 0...100)
                        .frame(height: 150)
                    }

                    // Insights
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights")
                            .font(.headline)

                        if let best = bestWeek, best.focusSeconds > 0 {
                            let label = weekLabel(for: best)
                            Text("Best week: \(label) with \(formatDuration(best.focusSeconds))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if weeklyStats.allSatisfy({ $0.focusSeconds == 0 }) {
                            Text("No focus sessions recorded in the last 30 days.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .onAppear { loadData() }
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today) else { return }

        // Gather all events for the 30-day range
        guard let rangeEnd = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        let allEvents = AnalyticsService.shared.eventsForDateRange(from: thirtyDaysAgo, to: rangeEnd)

        // Group days into weeks (each week is 7 days, starting from oldest)
        var weeks: [WeeklyStats] = []
        let totalDays = 30
        let daysPerWeek = 7

        // We'll create weeks: days 0-6, 7-13, 14-20, 21-27, 28-29
        var weekNum = 1
        var dayIndex = 0

        while dayIndex < totalDays {
            let weekDays = min(daysPerWeek, totalDays - dayIndex)
            guard let weekStart = calendar.date(byAdding: .day, value: dayIndex, to: thirtyDaysAgo) else {
                dayIndex += weekDays
                continue
            }
            guard let weekEnd = calendar.date(byAdding: .day, value: weekDays, to: weekStart) else {
                dayIndex += weekDays
                continue
            }

            let weekEvents = allEvents.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }

            let focusSec = weekEvents
                .filter { $0.type == .sessionCompleted || $0.type == .sessionReset }
                .compactMap(\.durationSeconds)
                .reduce(0, +)

            let sessions = weekEvents.filter { $0.type == .sessionCompleted }.count

            let completed = weekEvents.filter { $0.type == .breakCompleted }.count
            let skipped = weekEvents.filter { $0.type == .breakSkipped }.count
            let totalBreaks = completed + skipped
            let compliance = totalBreaks > 0 ? Double(completed) / Double(totalBreaks) : 1.0

            weeks.append(WeeklyStats(
                weekNumber: weekNum,
                startDate: weekStart,
                focusSeconds: focusSec,
                sessionsCompleted: sessions,
                breakCompliance: compliance
            ))

            weekNum += 1
            dayIndex += weekDays
        }

        weeklyStats = weeks

        // Calculate eye health from the full 30-day range
        eyeHealthMetrics = EyeHealthCalculator.calculate(from: allEvents)
    }

    // MARK: - Helpers

    private func weekLabel(for week: WeeklyStats) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Wk \(week.weekNumber): \(formatter.string(from: week.startDate))"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
