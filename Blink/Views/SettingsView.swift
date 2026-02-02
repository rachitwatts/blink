import SwiftUI

/// Settings view shown in a separate window
///
/// Contains configuration for:
/// - Work/break durations
/// - Display mode (elapsed/remaining)
/// - Sound toggle
/// - Advanced: idle thresholds
/// - Keyboard shortcuts info
struct SettingsView: View {

    // MARK: - State

    @ObservedObject private var settings = Settings.shared

    /// Track if advanced section is expanded
    @State private var isAdvancedExpanded: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("Settings")
                .font(.headline)

            Divider()

            // Timer Settings
            timerSection

            Divider()

            // Display Settings
            displaySection

            Divider()

            // Advanced Settings (collapsible)
            advancedSection

            Divider()

            // Keyboard Shortcuts Info
            shortcutsSection

            Spacer()
        }
        .padding(20)
        .frame(width: 340, height: 420)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timer")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Work duration
            HStack {
                Text("Work duration")
                Spacer()
                Stepper(
                    "\(settings.workDurationMinutes) min",
                    value: $settings.workDurationMinutes,
                    in: 1...60,
                    step: 1
                )
                .frame(width: 120)
            }

            // Break duration
            HStack {
                Text("Break duration")
                Spacer()
                Stepper(
                    "\(settings.breakDurationMinutes) min",
                    value: $settings.breakDurationMinutes,
                    in: 1...30,
                    step: 1
                )
                .frame(width: 120)
            }

            // Sound toggle
            Toggle("Play sound when break starts", isOn: $settings.soundEnabled)
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text("Menu bar shows")
                Spacer()
                Picker("", selection: displayModeBinding) {
                    Text("Elapsed time").tag(DisplayMode.elapsed)
                    Text("Remaining time").tag(DisplayMode.remaining)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }

    /// Custom binding for displayMode since it's a computed property
    private var displayModeBinding: Binding<DisplayMode> {
        Binding(
            get: { settings.displayMode },
            set: { settings.displayMode = $0 }
        )
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        DisclosureGroup(
            isExpanded: $isAdvancedExpanded,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    // Idle ignore threshold
                    HStack {
                        Text("Idle ignore")
                        Spacer()
                        Stepper(
                            "\(settings.idleIgnoreThreshold)s",
                            value: $settings.idleIgnoreThreshold,
                            in: 30...120,
                            step: 10
                        )
                        .frame(width: 100)
                    }

                    // Idle reset threshold
                    HStack {
                        Text("Idle reset")
                        Spacer()
                        Stepper(
                            "\(settings.idleResetThreshold)s",
                            value: $settings.idleResetThreshold,
                            in: 120...600,
                            step: 30
                        )
                        .frame(width: 100)
                    }

                    // Explanation
                    Text("Idle under \(settings.idleIgnoreThreshold)s counts as active (reading/thinking). Idle over \(settings.idleResetThreshold)s resets the session when you return.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            },
            label: {
                Text("Advanced")
            }
        )
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Pause/Resume")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘⇧B")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }

                GridRow {
                    Text("Restart Session")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘⇧R")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }

            // Permission note
            if !isAccessibilityEnabled() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Enable Accessibility to use global shortcuts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)

                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Helpers

    /// Check if Accessibility permission is granted
    private func isAccessibilityEnabled() -> Bool {
        // Check without prompting
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to Accessibility pane
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
