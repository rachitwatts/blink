import AppKit
import SwiftUI

/// Controls break overlay windows across all monitors
///
/// Responsibilities:
/// - Creates one NSWindow per connected monitor
/// - Positions windows to cover entire screen
/// - Sets window level to appear above full-screen apps
/// - Handles display connect/disconnect events
/// - Manages show/hide with animations
///
/// Usage: `BreakOverlayWindowController.shared.showOverlay()` / `.hideOverlay()`
final class BreakOverlayWindowController {

    // MARK: - Singleton

    static let shared = BreakOverlayWindowController()

    // MARK: - Properties

    /// Array of active overlay windows (one per screen)
    private var windows: [NSWindow] = []

    /// Observer for display configuration changes
    private var displayObserver: Any?

    /// Track which window has key status (for keyboard events)
    private var keyWindow: NSWindow?

    // MARK: - Initialization

    private init() {
        setupDisplayObserver()
    }

    deinit {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Show break overlay on all connected screens
    func showOverlay() {
        print("[OverlayController] Showing overlay on \(NSScreen.screens.count) screen(s)")

        // Clear any existing windows first
        hideOverlay(animated: false)

        // Create a window for each screen
        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            windows.append(window)
        }

        // Show all windows
        for window in windows {
            showWindow(window)
        }

        // Make the first window key for keyboard events
        if let firstWindow = windows.first {
            firstWindow.makeKey()
            keyWindow = firstWindow
        }

        // Bring app to front (so keyboard events work)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hide break overlay from all screens
    /// - Parameter animated: Whether to animate the dismissal (currently disabled for stability)
    func hideOverlay(animated: Bool = true) {
        print("[OverlayController] Hiding overlay - window count: \(windows.count)")

        // Capture and clear our references first
        let windowsToClose = windows
        windows.removeAll()
        keyWindow = nil

        for window in windowsToClose {
            // Just order out and close - let AppKit handle cleanup naturally
            // Don't manually nil contentView as it can cause double-release
            window.orderOut(nil)
        }

        print("[OverlayController] Overlay hidden successfully")
    }

    // MARK: - Private: Window Creation

    /// Create an overlay window for a specific screen
    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        // Create window covering the entire screen
        // Use screen.frame which gives position and size in global coordinates
        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // Configure window properties
        window.level = .screenSaver  // Appears above full-screen apps
        window.collectionBehavior = [
            .canJoinAllSpaces,      // Appears on all Spaces
            .fullScreenAuxiliary,   // Can appear over full-screen apps
            .stationary             // Doesn't move when Spaces switch
        ]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        // Create hosting view with SwiftUI content
        let overlayView = BreakOverlayView()
        let hostingView = KeyableHostingView(rootView: overlayView)

        // Set the window's content view first
        window.contentView = hostingView

        // Now set the frame to match the window's content rect (in window coordinates, origin is 0,0)
        if let contentView = window.contentView {
            hostingView.frame = contentView.bounds
            hostingView.autoresizingMask = [.width, .height]
        }

        // Ensure window is exactly positioned and sized for this screen
        window.setFrame(screen.frame, display: true)

        return window
    }

    /// Show a window with optional fade-in animation
    private func showWindow(_ window: NSWindow) {
        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            // Start invisible
            window.alphaValue = 0

            // Show window
            window.orderFrontRegardless()

            // Fade in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                window.animator().alphaValue = 1
            }
        } else {
            // Instant show
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
    }

    // MARK: - Private: Display Changes

    /// Setup observer for display configuration changes
    private func setupDisplayObserver() {
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDisplayChange()
        }
    }

    /// Handle display connect/disconnect
    private func handleDisplayChange() {
        // Only update if overlay is currently visible
        guard !windows.isEmpty else { return }

        print("[OverlayController] Display configuration changed, updating windows")

        // Rebuild windows for new display configuration
        showOverlay()
    }
}

// MARK: - KeyableWindow

/// Custom NSWindow that can become key window for keyboard events
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - KeyableHostingView

/// Custom NSHostingView that can become first responder for keyboard events
final class KeyableHostingView<Content: View>: NSHostingView<Content> {

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Check for Escape key
        if event.keyCode == 53 { // 53 = Escape
            // Find the BreakOverlayView and handle the Esc
            // Since we can't easily access the SwiftUI view, we'll handle it here
            handleEscapeKey()
        } else {
            super.keyDown(with: event)
        }
    }

    private func handleEscapeKey() {
        // Post notification that will be picked up by BreakOverlayView
        NotificationCenter.default.post(name: .breakOverlayEscPressed, object: nil)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when Esc is pressed in break overlay
    static let breakOverlayEscPressed = Notification.Name("breakOverlayEscPressed")
}
