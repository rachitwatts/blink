#if os(macOS)
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
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = true
        newWindow.setContentSize(NSSize(width: 700, height: 480))
        newWindow.minSize = NSSize(width: 700, height: 480)
        newWindow.isReleasedWhenClosed = false

        newWindow.isOpaque = true

        // Remember window position
        newWindow.setFrameAutosaveName("BlinkSettingsWindow")

        // Center only if no saved position
        if !newWindow.setFrameUsingName("BlinkSettingsWindow") {
            newWindow.center()
        }

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

#endif
