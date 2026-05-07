import SwiftUI

struct TimerSettingsSection: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Timer")
                .font(.title2)
                .fontWeight(.semibold)

            // Preset picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Rhythm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(TimerPreset.allCases) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: settings.timerPreset == preset
                        ) {
                            settings.timerPreset = preset
                            if preset != .custom {
                                settings.workDurationMinutes = preset.workMinutes
                                settings.breakDurationMinutes = preset.breakMinutes
                            }
                        }
                    }
                }
            }

            // Work duration chips
            PresetChipRow(
                label: "Work duration",
                presets: [15, 20, 25, 30, 45],
                value: $settings.workDurationMinutes,
                unit: "min",
                range: 1...60
            )
            .onChange(of: settings.workDurationMinutes) { _, _ in
                syncPresetFromDurations()
            }

            // Break duration chips
            PresetChipRow(
                label: "Break duration",
                presets: [3, 5, 8, 10, 15],
                value: $settings.breakDurationMinutes,
                unit: "min",
                range: 1...30
            )
            .onChange(of: settings.breakDurationMinutes) { _, _ in
                syncPresetFromDurations()
            }

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

    private func syncPresetFromDurations() {
        let detected = TimerPreset.matching(
            work: settings.workDurationMinutes,
            breakMins: settings.breakDurationMinutes
        )
        if settings.timerPreset != detected {
            settings.timerPreset = detected
        }
    }
}

struct PresetCard: View {
    let preset: TimerPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(preset.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if preset != .custom {
                    Text("\(preset.workMinutes)/\(preset.breakMinutes)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(preset.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.2)
                    : Color.primary.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
