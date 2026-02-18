import SwiftUI

/// Timer section: work/break duration chips + sound/lock toggles
struct TimerSettingsSection: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Timer")
                .font(.title2)
                .fontWeight(.semibold)

            // Work duration chips
            PresetChipRow(
                label: "Work duration",
                presets: [15, 20, 25, 30, 45],
                value: $settings.workDurationMinutes,
                unit: "min",
                range: 1...60
            )

            // Break duration chips
            PresetChipRow(
                label: "Break duration",
                presets: [3, 5, 8, 10, 15],
                value: $settings.breakDurationMinutes,
                unit: "min",
                range: 1...30
            )

            Divider()

            // Sound toggle
            Toggle("Play sound when break starts", isOn: $settings.soundEnabled)
                .toggleStyle(.switch)

            // Lock screen toggle
            Toggle("Lock screen after break", isOn: $settings.lockScreenAfterBreak)
                .toggleStyle(.switch)

            Text("Locks when break ends and you're away")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
