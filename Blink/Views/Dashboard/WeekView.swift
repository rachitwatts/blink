import SwiftUI
import Charts

/// Daily statistics for a single day in the week view
struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let focusSeconds: Int
    let sessionsCompleted: Int
    let breakCompliance: Double  // 0.0 to 1.0
    let isWeekend: Bool
}

/// Week tab content for the analytics dashboard
///
/// Shows the last 7 days with a daily focus time bar chart,
/// break compliance line chart, summary stat cards, and text insights.
/// Weekend days are visually dimmed in the bar chart.
struct WeekView: View {
    @State private var dailyStats: [DailyStats] = []
    @State private var eyeHealthMetrics: EyeHealthMetrics?

    // MARK: - Computed Stats

    private var totalFocusSeconds: Int {
        dailyStats.map(\.focusSeconds).reduce(0, +)
    }

    private var totalSessions: Int {
        dailyStats.map(\.sessionsCompleted).reduce(0, +)
    }

    private var overallCompliance: Int {
        let daysWithData = dailyStats.filter { $0.breakCompliance >= 0 }
        guard !daysWithData.isEmpty else { return 100 }
        let avg = daysWithData.map(\.breakCompliance).reduce(0, +) / Double(daysWithData.count)
        return Int(avg * 100)
    }

    private var weekdayStats: [DailyStats] {
        dailyStats.filter { !$0.isWeekend }
    }

    private var avgWeekdayFocusSeconds: Int {
        let weekdays = weekdayStats
        guard !weekdays.isEmpty else { return 0 }
        return weekdays.map(\.focusSeconds).reduce(0, +) / weekdays.count
    }

    private var mostProductiveDay: DailyStats? {
        dailyStats.max(by: { $0.focusSeconds < $1.focusSeconds })
    }

    // MARK: - Body

    var body: some View {
        if dailyStats.allSatisfy({ $0.focusSeconds == 0 }) && !dailyStats.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No Data This Week")
                    .font(.headline)
                Text("Use Blink for a few days to see weekly trends.")
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
                    Text("Last 7 Days")
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

                    // Daily focus time bar chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Focus Time")
                            .font(.headline)

                        Chart(dailyStats) { day in
                            BarMark(
                                x: .value("Focus", day.focusSeconds / 60),
                                y: .value("Day", day.date, unit: .day)
                            )
                            .foregroundStyle(day.isWeekend ? Color.gray.opacity(0.5) : Color.blue)
                        }
                        .chartXAxisLabel("Minutes")
                        .frame(height: 200)
                    }

                    // Break compliance line chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Break Compliance")
                            .font(.headline)

                        Chart(dailyStats) { day in
                            LineMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Compliance", day.breakCompliance * 100)
                            )
                            .foregroundStyle(Color.green)

                            PointMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Compliance", day.breakCompliance * 100)
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

                        if let best = mostProductiveDay, best.focusSeconds > 0 {
                            let dayName = best.date.formatted(.dateTime.weekday(.wide))
                            Text("Most productive day: \(dayName) with \(formatDuration(best.focusSeconds))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if avgWeekdayFocusSeconds > 0 {
                            Text("Avg weekday focus: \(formatDuration(avgWeekdayFocusSeconds))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if dailyStats.allSatisfy({ $0.focusSeconds == 0 }) {
                            Text("No focus sessions recorded this week.")
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
        var stats: [DailyStats] = []

        for dayOffset in (0..<7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let events = AnalyticsService.shared.eventsForDateRange(from: dayStart, to: dayEnd)

            let focusSec = events
                .filter { $0.type == .sessionCompleted || $0.type == .sessionReset }
                .compactMap(\.durationSeconds)
                .reduce(0, +)

            let sessions = events.filter { $0.type == .sessionCompleted }.count

            let completed = events.filter { $0.type == .breakCompleted }.count
            let skipped = events.filter { $0.type == .breakSkipped }.count
            let totalBreaks = completed + skipped
            let compliance = totalBreaks > 0 ? Double(completed) / Double(totalBreaks) : 1.0

            let weekday = calendar.component(.weekday, from: dayStart)
            let isWeekend = weekday == 1 || weekday == 7  // Sunday=1, Saturday=7

            stats.append(DailyStats(
                date: dayStart,
                focusSeconds: focusSec,
                sessionsCompleted: sessions,
                breakCompliance: compliance,
                isWeekend: isWeekend
            ))
        }

        dailyStats = stats

        // Calculate eye health from the week's events
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: today)!
        let weekEvents = AnalyticsService.shared.eventsForDateRange(from: weekStart, to: weekEnd)
        eyeHealthMetrics = EyeHealthCalculator.calculate(from: weekEvents)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
