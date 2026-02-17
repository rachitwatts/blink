import SwiftUI
import AppKit

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

    /// Analytics reset confirmation
    @State private var showResetConfirmation = false
    @State private var resetConfirmationText = ""
    @State private var showResetError = false
    @State private var resetErrorMessage = ""

    // MARK: - Body

    var body: some View {
        ScrollView {
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

                // Nudge Settings
                nudgeSection

                Divider()

                // Advanced Settings (collapsible)
                advancedSection

                Divider()

                // Keyboard Shortcuts Info
                shortcutsSection

                Divider()

                // Analytics Data
                analyticsSection
            }
            .padding(20)
        }
        .frame(width: 360, height: 540)
        .sheet(isPresented: $showResetConfirmation) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)

                Text("Reset Analytics Data")
                    .font(.headline)

                Text("This will permanently delete all your analytics history. This action cannot be undone.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Type RESET to confirm:")
                    .font(.caption)

                TextField("", text: $resetConfirmationText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        resetConfirmationText = ""
                        showResetConfirmation = false
                    }

                    Button("Delete All Data") {
                        if resetConfirmationText == "RESET" {
                            do {
                                try AnalyticsService.shared.resetAllData()
                                resetConfirmationText = ""
                                showResetConfirmation = false
                            } catch {
                                resetErrorMessage = error.localizedDescription
                                showResetError = true
                            }
                        }
                    }
                    .disabled(resetConfirmationText != "RESET")
                    .foregroundColor(.red)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
        .alert("Reset Failed", isPresented: $showResetError) {
            Button("OK") {}
        } message: {
            Text(resetErrorMessage)
        }
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

            // Lock screen toggle
            Toggle("Lock screen after break", isOn: $settings.lockScreenAfterBreak)

            Text("Locks when break ends and you're away")
                .font(.caption)
                .foregroundColor(.secondary)
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

    // MARK: - Nudge Section

    private var nudgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nudges")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle("Enable micro nudges", isOn: $settings.nudgesEnabled)
                .toggleStyle(.checkbox)

            if settings.nudgesEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    // Interval stepper
                    HStack {
                        Text("Remind every")
                        Stepper(
                            "\(settings.nudgeIntervalMinutes) min",
                            value: $settings.nudgeIntervalMinutes,
                            in: 2...30
                        )
                    }
                    .padding(.leading, 20)

                    // Per-type toggles
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Blink reminders", isOn: $settings.nudgeBlinkEnabled)
                            .toggleStyle(.checkbox)
                        Toggle("Posture reminders", isOn: $settings.nudgePostureEnabled)
                            .toggleStyle(.checkbox)
                        Toggle("Neck stretch reminders", isOn: $settings.nudgeStretchEnabled)
                            .toggleStyle(.checkbox)
                    }
                    .padding(.leading, 20)
                    .foregroundColor(.primary.opacity(0.9))
                }
            }
        }
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

            // Permission status and action
            if isAccessibilityEnabled() {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Shortcuts enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Grant Accessibility permission for global shortcuts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)

                Button("Enable Shortcuts") {
                    requestAccessibilityPermission()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Analytics Section

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Analytics data is stored locally on this Mac.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Reset All Analytics Data...") {
                showResetConfirmation = true
            }
            .foregroundColor(.red)
        }
    }

    // MARK: - Helpers

    /// Check if Accessibility permission is granted
    private func isAccessibilityEnabled() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request Accessibility permission and start listening if granted
    private func requestAccessibilityPermission() {
        // Prompt for permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)

        if granted {
            // Start listening now that we have permission
            HotkeyManager.shared.startListening()
        } else {
            // Open System Settings to Accessibility pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
