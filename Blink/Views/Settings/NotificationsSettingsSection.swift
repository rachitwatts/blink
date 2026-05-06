import SwiftUI

struct NotificationsSettingsSection: View {
    @ObservedObject var settings: Settings

    private let weekdays = Calendar.current.weekdaySymbols
    private let hours = Array(0..<24)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.title2)
                .fontWeight(.semibold)

            // MARK: - Weekly Summary

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Weekly summary", isOn: $settings.weeklySummaryEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: settings.weeklySummaryEnabled) { _, _ in
                        WeeklySummaryService.shared.reschedule()
                    }

                Text("One notification per week with your top eye health insight and an actionable suggestion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.weeklySummaryEnabled {
                    scheduleControls
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Day")
                    .frame(width: 60, alignment: .leading)
                Picker("", selection: $settings.weeklySummaryDay) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekdays[weekday - 1]).tag(weekday)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .onChange(of: settings.weeklySummaryDay) { _, _ in
                    WeeklySummaryService.shared.reschedule()
                }
            }

            HStack {
                Text("Time")
                    .frame(width: 60, alignment: .leading)
                Picker("", selection: $settings.weeklySummaryHour) {
                    ForEach(hours, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .labelsHidden()
                .frame(width: 100)

                Text(":")

                Picker("", selection: $settings.weeklySummaryMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .labelsHidden()
                .frame(width: 70)
            }
            .onChange(of: settings.weeklySummaryHour) { _, _ in
                WeeklySummaryService.shared.reschedule()
            }
            .onChange(of: settings.weeklySummaryMinute) { _, _ in
                WeeklySummaryService.shared.reschedule()
            }
        }
        .padding(.leading, 20)
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h) \(suffix)"
    }
}
