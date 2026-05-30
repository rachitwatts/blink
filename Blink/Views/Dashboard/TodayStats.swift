import Foundation

/// Pure presentation logic for the Today dashboard tab.
///
/// Extracted from `TodayView` so the stat, formatting, and event→row mapping
/// rules are unit-testable without rendering the view.
struct TodayStats {
    let focusTimeSeconds: Int
    let sessionsCompleted: Int
    let breaksCompleted: Int
    let breaksSkipped: Int

    init(events: [SessionEvent]) {
        focusTimeSeconds = events
            .filter { $0.type == .sessionCompleted || $0.type == .sessionReset }
            .compactMap { $0.durationSeconds }
            .reduce(0, +)
        sessionsCompleted = events.filter { $0.type == .sessionCompleted }.count
        breaksCompleted = events.filter { $0.type == .breakCompleted }.count
        breaksSkipped = events.filter { $0.type == .breakSkipped }.count
    }

    /// Percent of breaks completed. Defaults to 100% when there are no break
    /// outcomes yet (nothing has been skipped).
    var breakCompliancePercent: Int {
        let total = breaksCompleted + breaksSkipped
        guard total > 0 else { return 100 }
        return Int((Double(breaksCompleted) / Double(total)) * 100)
    }

    var focusTimeFormatted: String {
        let hours = focusTimeSeconds / 3600
        let minutes = (focusTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func sessionLogEntries(from events: [SessionEvent]) -> [SessionLogEntry] {
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
                let reason: String
                switch event.reason {
                case "idle_timeout": reason = "idle reset"
                case "app_quit": reason = "app quit"
                default: reason = "manual restart"
                }
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

    static func timelineSegments(from events: [SessionEvent]) -> [TimelineSegment] {
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
}
