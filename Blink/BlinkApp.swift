import SwiftUI
import SwiftData
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
            // Display timer or eye health score flash
            // Score flashes briefly every 5 minutes during work only
            if appState.showingScore && appState.timerState == .workRunning {
                Text(appState.scoreFlashGrade)
                    .monospacedDigit()
            } else {
                Text(appState.menuBarTitle)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.menu)
    }

    // MARK: - Initialization

    init() {
        print("[BlinkApp] Initializing")

        // Start Sparkle updater early so automatic checks begin immediately
        _ = UpdaterService.shared

        // Start timer engine and iCloud KVS sync
        TimerEngine.shared.start()
        TimerEngine.shared.setupSync()

        // Configure SwiftData for analytics
        do {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            let blinkDir = appSupport.appendingPathComponent("Blink", isDirectory: true)

            // Ensure directory exists
            try FileManager.default.createDirectory(at: blinkDir, withIntermediateDirectories: true)

            let schema = Schema([SessionEvent.self])
            let config = ModelConfiguration(url: blinkDir.appendingPathComponent("analytics.store"))
            let container = try ModelContainer(for: schema, configurations: config)
            AnalyticsService.shared.configure(with: container)
            DashboardWindowController.shared.configure(with: container)
            AnalyticsService.shared.recordAppLaunched()
            print("[BlinkApp] SwiftData configured for analytics")
        } catch {
            print("[BlinkApp] Failed to configure SwiftData: \(error)")
        }

        // Register URL scheme handler for blink:// URLs
        URLSchemeHandler.shared.register()

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

        // Observe nudge visibility changes
        AppState.shared.$isNudgeVisible
            .receive(on: DispatchQueue.main)
            .sink { isVisible in
                if isVisible {
                    NudgeWindowController.shared.show()
                } else {
                    NudgeWindowController.shared.hide()
                }
            }
            .store(in: &BlinkAppStorage.shared.cancellables)

        // Show onboarding if first launch (with slight delay for window to be ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            OnboardingWindowController.shared.showIfNeeded()
        }

        // Persist in-progress session when app terminates
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            let appState = AppState.shared
            if appState.workElapsedSeconds > 0 &&
                (appState.timerState == .workRunning || appState.timerState == .workPaused) {
                AnalyticsService.shared.recordSessionReset(
                    elapsed: appState.workElapsedSeconds, reason: "app_quit"
                )
            }
            AnalyticsService.shared.recordAppQuit(totalActiveSeconds: appState.workElapsedSeconds)
        }

        // Score flash timer - show eye health grade every 5 minutes during work
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                // Only flash during work sessions
                guard AppState.shared.timerState == .workRunning else { return }

                // Only flash if there are session/break events today (not just appLaunched)
                let events = AnalyticsService.shared.eventsForToday()
                let hasSessionActivity = events.contains { $0.type == .sessionCompleted || $0.type == .breakCompleted || $0.type == .breakSkipped }
                guard hasSessionActivity else { return }

                AppState.shared.scoreFlashGrade = AnalyticsService.shared.todaySummary().eyeHealthGrade
                AppState.shared.showingScore = true

                // Hide after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    AppState.shared.showingScore = false
                }
            }
        }
    }
}

// MARK: - URL Scheme Handler

/// Handles incoming `blink://` URLs via Apple Events
///
/// Supported URLs: blink://break, blink://snooze, blink://restart, blink://status
final class URLSchemeHandler: NSObject {
    static let shared = URLSchemeHandler()

    /// Register as the handler for GetURL Apple Events
    func register() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        print("[URLSchemeHandler] Registered for blink:// URLs")
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            print("[URLSchemeHandler] Could not parse URL from event")
            return
        }
        print("[URLSchemeHandler] Received URL: \(url)")

        guard let host = url.host else {
            print("[URLSchemeHandler] URL has no host: \(url)")
            return
        }
        guard let action = BlinkAction(rawValue: host) else {
            print("[URLSchemeHandler] Unknown action: \(host)")
            return
        }

        Task { @MainActor in
            let result = BlinkActions.execute(action)
            print("[URLSchemeHandler] Action '\(host)' -> \(result.message)")
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
