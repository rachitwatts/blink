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

    /// Cancellables for Combine subscriptions
    @State private var cancellables = Set<AnyCancellable>()

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
        print("[BlinkApp] Initializing")

        // Start timer engine
        TimerEngine.shared.start()

        // Start hotkey manager (lazy permission)
        HotkeyManager.shared.startListening()

        // Sync launch at login with settings
        LaunchAtLoginManager.shared.syncWithSettings()

        // Setup overlay observer
        AppState.shared.$isOverlayVisible
            .receive(on: DispatchQueue.main)
            .sink { isVisible in
                if isVisible {
                    print("[BlinkApp] Showing overlay")
                    BreakOverlayWindowController.shared.showOverlay()
                } else {
                    print("[BlinkApp] Hiding overlay")
                    BreakOverlayWindowController.shared.hideOverlay()
                }
            }
            .store(in: &BlinkAppStorage.shared.cancellables)

        // Show onboarding if first launch (with slight delay for window to be ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            OnboardingWindowController.shared.showIfNeeded()
        }
    }
}

// MARK: - Storage for Cancellables

/// Helper class to store cancellables (workaround for @State limitations in App)
final class BlinkAppStorage {
    static let shared = BlinkAppStorage()
    var cancellables = Set<AnyCancellable>()
    private init() {}
}
