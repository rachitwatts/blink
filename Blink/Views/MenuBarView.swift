import SwiftUI

/// Menu bar dropdown content
///
/// Provides controls for the timer:
/// - Pause/Resume toggle
/// - Restart Session
/// - Start Break Now
/// - Quit
struct MenuBarView: View {

    // MARK: - State

    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared
    @ObservedObject private var settings = Settings.shared
    @State private var summary: TodaySummary?

    // MARK: - Body

    var body: some View {
        Group {
            // MARK: Today Summary

            if let summary {
                Text("Today: \(summary.focusTimeFormatted) \u{00B7} \(summary.sessionsCompleted) sessions \u{00B7} \(summary.eyeHealthGrade)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }

            Divider()

            // MARK: Timer Controls

            // Pause/Resume toggle
            pauseResumeButton

            // Restart session
            Button("Restart Session") {
                timerEngine.restartSession()
            }
            .keyboardShortcut("r", modifiers: [.command])

            // Start break now
            Button("Start Break Now") {
                timerEngine.startBreakNow()
            }
            .disabled(appState.timerState == .breakRunning || appState.timerState == .snoozeRunning)

            Divider()

            // MARK: Settings

            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button("Dashboard...") {
                DashboardWindowController.shared.showDashboard()
            }
            .keyboardShortcut("d", modifiers: [.command])

            Divider()

            // MARK: Launch at Login

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setEnabled(newValue)
                }

            Divider()

            // MARK: Quit

            Button("Quit Blink") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear { refreshSummary() }
    }

    // MARK: - Pause/Resume Button

    private var pauseResumeButton: some View {
        let isPaused = appState.timerState == .workPaused
        let isBreak = appState.timerState == .breakRunning || appState.timerState == .snoozeRunning

        return Button(isPaused ? "Resume" : "Pause") {
            timerEngine.togglePause()
        }
        .keyboardShortcut("p", modifiers: [.command])
        .disabled(isBreak)
    }

    // MARK: - Data Loading

    private func refreshSummary() {
        summary = AnalyticsService.shared.todaySummary()
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .frame(width: 200)
}
