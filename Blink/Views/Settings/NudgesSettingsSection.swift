import SwiftUI

/// Nudges section: master toggle + interval slider + per-type toggles
struct NudgesSettingsSection: View {
    @ObservedObject var settings: Settings

    private var intervalBinding: Binding<Double> {
        Binding(
            get: { Double(settings.nudgeIntervalMinutes) },
            set: { settings.nudgeIntervalMinutes = Int($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nudges")
                .font(.title2)
                .fontWeight(.semibold)

            // Master toggle
            Toggle("Enable micro nudges", isOn: $settings.nudgesEnabled)
                .toggleStyle(.switch)

            if settings.nudgesEnabled {
                VStack(alignment: .leading, spacing: 16) {
                    // Interval slider
                    LabeledSlider(
                        label: "Remind every",
                        value: intervalBinding,
                        in: 2...30,
                        step: 1,
                        unit: " min"
                    )

                    Divider()

                    // Per-type toggles with icons
                    VStack(alignment: .leading, spacing: 10) {
                        NudgeToggle(
                            icon: "eye",
                            label: "Blink reminders",
                            isOn: $settings.nudgeBlinkEnabled
                        )
                        NudgeToggle(
                            icon: "figure.stand",
                            label: "Posture reminders",
                            isOn: $settings.nudgePostureEnabled
                        )
                        NudgeToggle(
                            icon: "arrow.up.arrow.down",
                            label: "Neck stretch reminders",
                            isOn: $settings.nudgeStretchEnabled
                        )
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: settings.nudgesEnabled)
    }
}

/// Toggle row with leading SF Symbol icon
private struct NudgeToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(label, systemImage: icon)
        }
        .toggleStyle(.switch)
    }
}
