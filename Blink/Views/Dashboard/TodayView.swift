import SwiftUI

/// Today tab content for the analytics dashboard
///
/// Shows stat cards (focus time, sessions, break compliance),
/// a visual timeline of the day, and a chronological session log.
/// Data is loaded from AnalyticsService on appear.
struct TodayView: View {
    @State private var events: [SessionEvent] = []
    @State private var eyeHealthMetrics: EyeHealthMetrics?

    // MARK: - Computed Stats

    private var focusTimeSeconds: Int {
        events.filter { $0.type == .sessionCompleted || $0.type == .sessionReset }
            .compactMap { $0.durationSeconds }
            .reduce(0, +)
    }

    private var sessionsCompleted: Int {
        events.filter { $0.type == .sessionCompleted }.count
    }

    private var breaksCompleted: Int {
        events.filter { $0.type == .breakCompleted }.count
    }

    private var breaksSkipped: Int {
        events.filter { $0.type == .breakSkipped }.count
    }

    private var breakCompliancePercent: Int {
        let total = breaksCompleted + breaksSkipped
        guard total > 0 else { return 100 }
        return Int((Double(breaksCompleted) / Double(total)) * 100)
    }

    private var focusTimeFormatted: String {
        let hours = focusTimeSeconds / 3600
        let minutes = (focusTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Session Log

    private var sessionLogEntries: [SessionLogEntry] {
        var entries: [SessionLogEntry] = []
        for event in events {
            guard let type = event.type else { continue }
            switch type {
            case .sessionCompleted:
                let duration = (event.durationSeconds ?? 0) / 60
                entries.append(SessionLogEntry(
                    timestamp: event.timestamp,
                    icon: "✅",
                    description: "\(duration)m focus → break triggered"
                ))
            case .sessionReset:
                let duration = (event.durationSeconds ?? 0) / 60
                let reason = event.reason == "idle_timeout" ? "idle reset" : "manual restart"
                entries.append(SessionLogEntry(
                    timestamp: event.timestamp,
                    icon: "↩️",
                    description: "\(duration)m focus → \(reason)"
                ))
            case .breakCompleted:
                entries.append(SessionLogEntry(
                    timestamp: event.timestamp,
                    icon: "👁",
                    description: "Break completed"
                ))
            case .breakSkipped:
                entries.append(SessionLogEntry(
                    timestamp: event.timestamp,
                    icon: "⚠️",
                    description: "Break skipped"
                ))
            case .breakSnoozed:
                entries.append(SessionLogEntry(
                    timestamp: event.timestamp,
                    icon: "💤",
                    description: "Break snoozed"
                ))
            default:
                break
            }
        }
        return entries
    }

    // MARK: - Timeline

    private var timelineSegments: [TimelineSegment] {
        var segments: [TimelineSegment] = []
        for event in events {
            guard let type = event.type else { continue }
            switch type {
            case .sessionCompleted, .sessionReset:
                if let duration = event.durationSeconds {
                    let start = event.timestamp.addingTimeInterval(-Double(duration))
                    segments.append(TimelineSegment(
                        startTime: start,
                        endTime: event.timestamp,
                        type: .focus
                    ))
                }
            case .breakCompleted:
                if let duration = event.durationSeconds {
                    let start = event.timestamp.addingTimeInterval(-Double(duration))
                    segments.append(TimelineSegment(
                        startTime: start,
                        endTime: event.timestamp,
                        type: .breakTime
                    ))
                }
            default:
                break
            }
        }
        return segments.sorted { $0.startTime < $1.startTime }
    }

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
                        StatCardView(value: focusTimeFormatted, label: "Focus", sublabel: "Time")
                        StatCardView(value: "\(sessionsCompleted)", label: "Sessions", sublabel: "Completed")
                        StatCardView(value: "\(breakCompliancePercent)%", label: "Break", sublabel: "Compliance")
                        StatCardView(value: eyeHealthMetrics?.grade ?? "—", label: "Eye", sublabel: "Health")
                    }

                    // Timeline
                    if !timelineSegments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timeline")
                                .font(.headline)
                            TimelineView(
                                segments: timelineSegments,
                                dayStart: timelineSegments.first?.startTime
                                    ?? Calendar.current.startOfDay(for: Date()),
                                dayEnd: Date()
                            )
                        }
                    }

                    // Session log
                    SessionLogView(entries: sessionLogEntries)

                    // Contextual tip when eye health is poor
                    if let tip = eyeHealthMetrics?.tip {
                        InsightTipView(tip: tip)
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
        events = AnalyticsService.shared.eventsForToday()
        eyeHealthMetrics = EyeHealthCalculator.calculate(from: events)
    }
}
