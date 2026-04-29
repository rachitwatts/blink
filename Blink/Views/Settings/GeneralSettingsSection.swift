import SwiftUI

/// General section: display mode thumbnails + launch at login
struct GeneralSettingsSection: View {
    @ObservedObject var settings: Settings

    private var displayModeBinding: Binding<DisplayMode> {
        Binding(
            get: { settings.displayMode },
            set: { settings.displayMode = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)

            // Display mode thumbnails (at top)
            ThumbnailPicker(selection: displayModeBinding)

            Divider()

            // Break content mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Break content")
                    .font(.headline)

                Picker("", selection: breakContentModeBinding) {
                    ForEach(BreakContentMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 350)

                Text(breakContentDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Launch at login toggle
            Toggle("Launch Blink at login", isOn: $settings.launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setEnabled(newValue)
                }
        }
    }

    private var breakContentModeBinding: Binding<BreakContentMode> {
        Binding(
            get: { settings.breakContentMode },
            set: { settings.breakContentMode = $0 }
        )
    }

    private var breakContentDescription: String {
        switch settings.breakContentMode {
        case .guided:
            return "Show rotating guided exercises during breaks — eye care, breathing, stretches."
        case .staticMessage:
            return "Show \"Look away. Blink. Breathe.\" during breaks."
        case .none:
            return "Show only the countdown timer during breaks."
        }
    }
}
