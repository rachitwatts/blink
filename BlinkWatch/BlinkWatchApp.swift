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
    }
}

/// Root content view that switches between session and break views
struct ContentView: View {
    @ObservedObject var appState = WatchAppState.shared

    var body: some View {
        Group {
            switch appState.timerState {
            case .workRunning, .workPaused:
                WatchSessionView()
            case .breakRunning:
                WatchBreakView()
            case .snoozeRunning:
                WatchSessionView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: WatchSettingsView()) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
            }
        }
    }
}
