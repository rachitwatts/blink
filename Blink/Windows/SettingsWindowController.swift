import AppKit
import SwiftUI

/// Controls the Settings window
///
/// Shows a standalone window with settings.
/// Window is non-modal (user can interact with menu bar while open).
///
/// Usage: `SettingsWindowController.shared.showSettings()`
final class SettingsWindowController {

    // MARK: - Singleton

    static let shared = SettingsWindowController()

    // MARK: - Properties

    private var window: NSWindow?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Show the settings window, or bring it to front if already open
    func showSettings() {
        // If window exists and is visible, bring to front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new window
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Blink Settings"
        newWindow.styleMask = [.titled, .closable]
        newWindow.setContentSize(NSSize(width: 340, height: 420))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Store reference
        window = newWindow

        // Show window
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Close the settings window if open
    func closeSettings() {
        window?.close()
    }
}
