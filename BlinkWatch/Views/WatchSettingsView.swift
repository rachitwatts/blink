import SwiftUI

/// Settings view for the watch app
///
/// Provides controls for work/break duration and haptic feedback.
/// Simplified compared to the macOS settings panel.
struct WatchSettingsView: View {
    @ObservedObject var settings = WatchSettings.shared

    var body: some View {
        List {
            Section("Work") {
                Stepper(
                    "\(settings.workDurationMinutes) min",
                    value: $settings.workDurationMinutes,
                    in: 1...60
                )
            }

            Section("Break") {
                Stepper(
                    "\(settings.breakDurationMinutes) min",
                    value: $settings.breakDurationMinutes,
                    in: 1...30
                )
            }

            Section("Display") {
                Picker("Mode", selection: Binding(
                    get: { settings.displayMode },
                    set: { settings.displayMode = $0 }
                )) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }

            Section("Feedback") {
                Toggle("Haptic", isOn: $settings.hapticEnabled)
            }
        }
        .navigationTitle("Settings")
    }
}
