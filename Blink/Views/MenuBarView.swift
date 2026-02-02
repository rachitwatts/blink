import SwiftUI

/// Menu bar dropdown content
/// Shows controls when user clicks the timer in menu bar
struct MenuBarView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared

    var body: some View {
        // For now, just show basic info and quit
        // Full controls will be added in Milestone 2

        Group {
            // Show current state for debugging
            Text("State: \(appState.timerState.description)")
                .foregroundColor(.secondary)

            Text("Work: \(appState.workElapsedSeconds)s")
                .foregroundColor(.secondary)

            Divider()

            Button("Quit Blink") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

#Preview {
    MenuBarView()
}
