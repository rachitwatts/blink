import SwiftUI

struct EyeHealthDeepDiveView: View {
    let events: [SessionEvent]
    let scope: AnalysisScope
    var previousPeriodEvents: [SessionEvent] = []

    @State private var dismissed: Set<String> = EyeHealthAnalyzer.loadDismissed()
    @Environment(\.dismiss) private var dismiss

    private var metrics: EyeHealthMetrics {
        EyeHealthCalculator.calculate(from: events)
    }

    private var allInsights: [EyeHealthInsight] {
        EyeHealthAnalyzer.analyze(events: events, settings: Settings.shared, scope: scope, previousPeriodEvents: previousPeriodEvents)
    }

    private var visibleInsights: [EyeHealthInsight] {
        EyeHealthAnalyzer.filterDismissed(allInsights, dismissed: dismissed)
    }

    private var dismissedCount: Int {
        allInsights.count - visibleInsights.count
    }

    private var scopeLabel: String {
        switch scope {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .allTime: return "All Time"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .padding(.trailing, 16)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    scoreBreakdownSection
                    insightsSection
                    footerSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 480, minHeight: 500)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(gradeColor(for: metrics.grade))
                    .frame(width: 80, height: 80)

                Text(metrics.grade)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(scopeLabel)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Score Breakdown

    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)

            VStack(spacing: 10) {
                complianceBar(
                    label: "Break Compliance",
                    value: metrics.breakCompliance,
                    color: complianceColor(metrics.breakCompliance)
                )

                complianceBar(
                    label: "Snooze Rate",
                    value: metrics.snoozeRate,
                    color: snoozeRateColor(metrics.snoozeRate)
                )
            }

            HStack(spacing: 4) {
                Text("\(metrics.breaksCompleted) completed")
                Text("\u{00B7}")
                Text("\(metrics.breaksSkipped) skipped")
                Text("\u{00B7}")
                Text("\(metrics.breaksSnoozed) snoozed")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private func complianceBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * min(1, CGFloat(value))), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Insights")
                    .font(.headline)

                if !visibleInsights.isEmpty {
                    Text("\(visibleInsights.count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary))
                }
            }

            if visibleInsights.isEmpty {
                emptyState
            } else {
                ForEach(visibleInsights) { insight in
                    insightCard(insight)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: dismissed)
    }

    private func insightCard(_ insight: EyeHealthInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundColor(iconColor(for: insight))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { dismissInsight(insight.id) }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Your eye health habits look solid! Keep it up.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        if dismissedCount > 0 {
            Button(action: resetDismissals) {
                Text("Reset dismissed insights")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func dismissInsight(_ id: String) {
        EyeHealthAnalyzer.dismiss(id)
        dismissed = EyeHealthAnalyzer.loadDismissed()
    }

    private func resetDismissals() {
        EyeHealthAnalyzer.resetDismissals()
        dismissed = []
    }

    // MARK: - Color Helpers

    private func gradeColor(for grade: String) -> Color {
        switch grade {
        case "A+", "A": return .green
        case "A-": return .green.opacity(0.8)
        case "B+": return .orange
        case "B": return .orange.opacity(0.8)
        case "C": return .orange.opacity(0.6)
        case "D": return .red
        default: return .gray
        }
    }

    private func complianceColor(_ value: Double) -> Color {
        if value >= 0.8 { return .green }
        if value >= 0.5 { return .yellow }
        return .red
    }

    private func snoozeRateColor(_ value: Double) -> Color {
        if value <= 0.2 { return .green }
        if value <= 0.4 { return .yellow }
        return .red
    }

    private func iconColor(for insight: EyeHealthInsight) -> Color {
        if insight.category == .suggestion { return .blue }
        switch insight.severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}
