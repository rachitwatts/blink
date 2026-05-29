import SwiftUI

/// Today tab content for the analytics dashboard
///
/// Shows stat cards (focus time, sessions, break compliance),
/// a visual timeline of the day, and a chronological session log.
/// Data is loaded from AnalyticsService on appear.
struct TodayView: View {
    @State private var events: [SessionEvent] = []
    @State private var eyeHealthMetrics: EyeHealthMetrics?
    @State private var showEyeHealthDeepDive = false

    // MARK: - Computed Stats

    /// Pure presentation logic lives in `TodayStats` (unit-tested).
    private var stats: TodayStats { TodayStats(events: events) }

    // MARK: - Body

    var body: some View {
        let sessionEvents = events.filter { $0.type == .sessionCompleted || $0.type == .sessionReset || $0.type == .breakCompleted || $0.type == .breakSkipped || $0.type == .breakSnoozed }
        if sessionEvents.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No Sessions Yet")
                    .font(.headline)
                Text("Complete your first focus session to see analytics.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { loadData() }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date header
                    Text(Date(), format: .dateTime.weekday(.wide).month().day())
                        .font(.title2)
                        .fontWeight(.semibold)

                    // Stat cards
                    HStack(spacing: 12) {
                        StatCardView(value: stats.focusTimeFormatted, label: "Focus", sublabel: "Time")
                        StatCardView(value: "\(stats.sessionsCompleted)", label: "Sessions", sublabel: "Completed")
                        StatCardView(value: "\(stats.breakCompliancePercent)%", label: "Break", sublabel: "Compliance")
                        Button(action: { showEyeHealthDeepDive = true }) {
                            StatCardView(value: eyeHealthMetrics?.grade ?? "\u{2014}", label: "Eye", sublabel: "Health")
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(6)
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    // Timeline
                    let timeline = TodayStats.timelineSegments(from: events)
                    if !timeline.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timeline")
                                .font(.headline)
                            TimelineView(
                                segments: timeline,
                                dayStart: Calendar.current.startOfDay(for: Date()),
                                dayEnd: Date()
                            )
                        }
                    }

                    // Session log
                    SessionLogView(entries: TodayStats.sessionLogEntries(from: events))

                    // Contextual tip when eye health is poor
                    if let tip = eyeHealthMetrics?.tip {
                        InsightTipView(tip: tip)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .onAppear { loadData() }
            .sheet(isPresented: $showEyeHealthDeepDive) {
                EyeHealthDeepDiveView(events: events, scope: .today)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        events = AnalyticsService.shared.eventsForToday()
        eyeHealthMetrics = EyeHealthCalculator.calculate(from: events)
    }
}
