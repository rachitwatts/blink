import SwiftUI

/// A segment of the daily timeline bar
///
/// Represents a contiguous period of focus, break, or idle time.
struct TimelineSegment: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let type: SegmentType

    enum SegmentType {
        case focus
        case breakTime
        case idle
    }
}

/// Horizontal timeline bar showing focus/break/idle blocks for the day
///
/// Renders colored segments proportionally within a GeometryReader.
/// Includes a legend below the bar.
struct TimelineView: View {
    let segments: [TimelineSegment]
    let dayStart: Date
    let dayEnd: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let totalSeconds = max(1, dayEnd.timeIntervalSince(dayStart))

                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))

                    // Segments
                    ForEach(segments) { segment in
                        let startOffset = segment.startTime.timeIntervalSince(dayStart)
                        let duration = segment.endTime.timeIntervalSince(segment.startTime)
                        let xPosition = (startOffset / totalSeconds) * geometry.size.width
                        let width = (duration / totalSeconds) * geometry.size.width

                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(segment.type))
                            .frame(width: max(2, width), height: geometry.size.height - 4)
                            .offset(x: xPosition, y: 2)
                    }
                }
            }
            .frame(height: 24)

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .blue, label: "Focus")
                LegendItem(color: .green.opacity(0.6), label: "Break")
                LegendItem(color: Color(nsColor: .separatorColor), label: "Idle")
            }
            .font(.caption2)
        }
    }

    private func colorFor(_ type: TimelineSegment.SegmentType) -> Color {
        switch type {
        case .focus: return .blue
        case .breakTime: return .green.opacity(0.6)
        case .idle: return Color(nsColor: .separatorColor)
        }
    }
}

// MARK: - Legend Item

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}
