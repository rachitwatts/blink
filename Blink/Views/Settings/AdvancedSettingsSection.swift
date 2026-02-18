import SwiftUI

/// Advanced section: idle thresholds with sliders
struct AdvancedSettingsSection: View {
    @ObservedObject var settings: Settings

    private var ignoreBinding: Binding<Double> {
        Binding(
            get: { Double(settings.idleIgnoreThreshold) },
            set: { settings.idleIgnoreThreshold = Int($0) }
        )
    }

    private var resetBinding: Binding<Double> {
        Binding(
            get: { Double(settings.idleResetThreshold) },
            set: { settings.idleResetThreshold = Int($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced")
                .font(.title2)
                .fontWeight(.semibold)

            // Idle ignore slider
            LabeledSlider(
                label: "Idle ignore threshold",
                value: ignoreBinding,
                in: 30...120,
                step: 10,
                unit: "s"
            )

            // Idle reset slider
            LabeledSlider(
                label: "Idle reset threshold",
                value: resetBinding,
                in: 120...600,
                step: 30,
                unit: "s"
            )

            // Explanation
            Text("Idle under \(settings.idleIgnoreThreshold)s counts as active (reading/thinking). Idle over \(settings.idleResetThreshold)s resets the session when you return.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
