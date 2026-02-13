import SwiftUI

struct AllTimeView: View {
    @State private var totalFocusSeconds = 0
    @State private var totalSessions = 0
    @State private var overallCompliance = 0
    @State private var heatmapDays: [HeatmapDay] = []
    @State private var heatmapMode: HeatmapMode = .sessions
    @State private var firstEventDate: Date?
    @State private var currentStreak = 0
    @State private var bestStreak = 0
    @State private var bestDaySeconds = 0
    @State private var bestDayDate: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let firstDate = firstEventDate {
                    Text("Since \(firstDate, format: .dateTime.month().day().year())")
                        .font(.title2)
                        .fontWeight(.semibold)
                } else {
                    Text("All Time")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 12) {
                    StatCardView(
                        value: formatDurationLong(totalFocusSeconds),
                        label: "Focused",
                        sublabel: "Lifetime"
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
                        value: "\u{2014}",
                        label: "Eye",
                        sublabel: "Health"
                    )
                }

                HeatmapView(days: heatmapDays, mode: $heatmapMode)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Insights")
                        .font(.headline)

                    if let bestDate = bestDayDate {
                        Text("Best Day: \(formatDuration(bestDaySeconds)) (\(bestDate, format: .dateTime.month().day()))")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Text("Current Streak: \(currentStreak) days with 4+ sessions")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Text("Best Streak: \(bestStreak) days")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    if totalSessions > 0 {
                        let avgPerDay = totalFocusSeconds / max(1, Calendar.current.dateComponents([.day], from: firstEventDate ?? Date(), to: Date()).day ?? 1)
                        Text("Avg Focus/Day: \(formatDuration(avgPerDay))")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        let allEvents = AnalyticsService.shared.allEvents()

        guard !allEvents.isEmpty else { return }

        firstEventDate = allEvents.first?.timestamp

        totalFocusSeconds = allEvents
            .filter { $0.type == .sessionCompleted || $0.type == .sessionReset }
            .compactMap { $0.durationSeconds }
            .reduce(0, +)

        totalSessions = allEvents.filter { $0.type == .sessionCompleted }.count

        let breaksCompleted = allEvents.filter { $0.type == .breakCompleted }.count
        let breaksSkipped = allEvents.filter { $0.type == .breakSkipped }.count
        let totalBreaks = breaksCompleted + breaksSkipped
        overallCompliance = totalBreaks > 0 ? Int((Double(breaksCompleted) / Double(totalBreaks)) * 100) : 100

        buildHeatmapData(from: allEvents)
        calculateStreaksAndBestDay(from: allEvents)
    }

    private func buildHeatmapData(from events: [SessionEvent]) {
        let calendar = Calendar.current

        var daySessionCounts: [Date: Int] = [:]

        for event in events where event.type == .sessionCompleted {
            let day = calendar.startOfDay(for: event.timestamp)
            daySessionCounts[day, default: 0] += 1
        }

        let today = calendar.startOfDay(for: Date())
        var days: [HeatmapDay] = []

        for dayOffset in (0..<90).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let sessionCount = daySessionCounts[date] ?? 0

            days.append(HeatmapDay(
                date: date,
                value: sessionCount,
                eyeHealthGrade: nil
            ))
        }

        heatmapDays = days
    }

    private func calculateStreaksAndBestDay(from events: [SessionEvent]) {
        let calendar = Calendar.current

        var dayFocusSeconds: [Date: Int] = [:]
        var daySessionCounts: [Date: Int] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)

            if event.type == .sessionCompleted {
                daySessionCounts[day, default: 0] += 1
            }

            if event.type == .sessionCompleted || event.type == .sessionReset {
                dayFocusSeconds[day, default: 0] += event.durationSeconds ?? 0
            }
        }

        if let (date, seconds) = dayFocusSeconds.max(by: { $0.value < $1.value }) {
            bestDayDate = date
            bestDaySeconds = seconds
        }

        let sortedDays = daySessionCounts.keys.sorted()
        var currentRun = 0
        var maxRun = 0
        var previousDay: Date?

        for day in sortedDays {
            let count = daySessionCounts[day] ?? 0
            if count >= 4 {
                if let prev = previousDay,
                   calendar.dateComponents([.day], from: prev, to: day).day == 1 {
                    currentRun += 1
                } else {
                    currentRun = 1
                }
                maxRun = max(maxRun, currentRun)
            } else {
                currentRun = 0
            }
            previousDay = day
        }

        bestStreak = maxRun

        let today = calendar.startOfDay(for: Date())
        currentStreak = 0
        for dayOffset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            let count = daySessionCounts[day] ?? 0
            if count >= 4 {
                currentStreak += 1
            } else if dayOffset > 0 {
                break
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatDurationLong(_ seconds: Int) -> String {
        let hours = seconds / 3600
        if hours >= 100 {
            return "\(hours)h"
        }
        return formatDuration(seconds)
    }
}
