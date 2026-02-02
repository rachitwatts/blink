import SwiftUI
import Combine

/// Main entry point for the Blink app
///
/// Blink runs as a menu bar-only app (no dock icon, no main window).
/// The MenuBarExtra displays the current timer and provides controls.
@main
struct BlinkApp: App {

    // MARK: - State Objects

    /// Observable app state - triggers UI updates
    @StateObject private var appState = AppState.shared

    /// Timer engine - must be retained to keep running
    @StateObject private var timerEngine = TimerEngine.shared

    // MARK: - App Body

    var body: some Scene {
        // Menu bar extra shows timer in menu bar
        MenuBarExtra {
            MenuBarView()
        } label: {
            // Display the timer as text
            // Uses monospaced digits for stable width
            Text(appState.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.menu)
    }

    // MARK: - Initialization

    init() {
        // Start timer engine when app launches
        // Using Task to ensure we're on MainActor
        Task { @MainActor in
            print("[BlinkApp] Starting timer engine")
            TimerEngine.shared.start()
        }
    }
}
