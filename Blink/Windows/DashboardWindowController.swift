import AppKit
import SwiftUI
import SwiftData

/// Controls the Dashboard window
///
/// Shows a standalone window with analytics dashboard.
/// Window is non-modal and resizable.
/// Must be configured with a ModelContainer before showing (see `BlinkApp.init`).
///
/// Usage: `DashboardWindowController.shared.showDashboard()`
@MainActor
final class DashboardWindowController {

    // MARK: - Singleton

    static let shared = DashboardWindowController()

    // MARK: - Properties

    private var window: NSWindow?
    private var modelContainer: ModelContainer?

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Configure with a SwiftData container for analytics queries
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    // MARK: - Public API

    /// Show the dashboard window, or bring it to front if already open
    func showDashboard() {
        // If window exists and is visible, bring to front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let container = modelContainer else {
            print("[DashboardWindowController] ModelContainer not configured")
            return
        }

        // Create new window
        let dashboardView = DashboardView()
            .modelContainer(container)
        let hostingController = NSHostingController(rootView: dashboardView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Blink Dashboard"
        newWindow.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        newWindow.setContentSize(NSSize(width: 700, height: 600))
        newWindow.minSize = NSSize(width: 600, height: 500)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.setFrameAutosaveName("DashboardWindow")

        // Store reference
        window = newWindow

        // Show window
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
