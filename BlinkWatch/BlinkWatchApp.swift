import SwiftUI

/// Entry point for the Blink watchOS app
///
/// The watch app runs as a standalone companion to the macOS app.
/// It maintains its own work/break timer with haptic feedback
/// for break notifications.
@main
struct BlinkWatchApp: App {
    @StateObject private var appState = WatchAppState.shared
    @StateObject private var engine = WatchTimerEngine.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }

    init() {
        WatchTimerEngine.shared.start()
        WatchTimerEngine.shared.setupSync()
    }
}

/// Root content view that switches between session, break, and break-ended views
struct ContentView: View {
    @ObservedObject var appState = WatchAppState.shared
    @ObservedObject var engine = WatchTimerEngine.shared

    /// Tracks whether the break countdown reached zero.
    /// When true, shows `BreakEndedView` with escalating haptics.
    @State private var breakEnded: Bool = false

    /// Manages repeating haptic feedback when break ends.
    @State private var hapticManager = HapticManager()

    var body: some View {
        Group {
            if breakEnded {
                BreakEndedView(onDismiss: dismissBreakEnded)
            } else {
                switch appState.timerState {
                case .workRunning, .workPaused:
                    WatchSessionView()
                case .breakRunning:
                    BreakActiveView(
                        appState: appState,
                        onSnooze: { engine.snoozeBreak() },
                        onSkip: { engine.skipBreak() }
                    )
                case .snoozeRunning:
                    WatchSessionView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // Connection status: only show when offline
                if engine.isOffline {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: WatchSettingsView()) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
            }
        }
        .onChange(of: appState.breakRemainingSeconds) { _, newValue in
            // Detect break countdown reaching zero while in breakRunning state
            if appState.timerState == .breakRunning && newValue <= 0 {
                breakEnded = true
                if WatchSettings.shared.hapticEnabled {
                    hapticManager.startBreakEndAlert()
                }
            }
        }
        .onChange(of: appState.timerState) { _, newValue in
            // If something else moved us out of breakRunning while
            // breakEnded was showing (e.g. sync pushes new state from Mac),
            // clean up the haptics and dismiss the break-ended view.
            if breakEnded && newValue != .breakRunning {
                hapticManager.stopAlert()
                breakEnded = false
            }
        }
    }

    /// Called when user taps "Dismiss" on the BreakEndedView.
    private func dismissBreakEnded() {
        hapticManager.stopAlert()
        breakEnded = false
        engine.skipBreak()
    }
}
