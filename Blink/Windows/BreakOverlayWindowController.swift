import AppKit
import SwiftUI
import Combine

final class BreakOverlayWindowController {

    // MARK: - Singleton

    static let shared = BreakOverlayWindowController()

    // MARK: - Properties

    /// Full-screen overlay windows (enforced mode, or gentle fullscreen phase)
    private var windows: [NSWindow] = []

    /// Semi-transparent dim windows for gentle mode (one per screen, pass-through)
    private var dimWindows: [NSWindow] = []

    /// Compact floating window for gentle mode phases 1-2
    private var floatingWindow: NSWindow?

    private var displayObserver: Any?
    private var phaseObserver: AnyCancellable?
    private var keyWindow: NSWindow?

    /// Tracks whether we're currently in gentle mode overlay
    private var isGentleMode: Bool = false

    // MARK: - Initialization

    private init() {
        setupDisplayObserver()
        setupPhaseObserver()
    }

    deinit {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Show break overlay — dispatches to enforced or gentle based on current settings
    func showOverlay(initialPhase: BreakPhase = .floating) {
        let style = Settings.shared.breakStyle
        print("[OverlayController] Showing overlay (style: \(style.rawValue), phase: \(initialPhase)) on \(NSScreen.screens.count) screen(s)")

        hideOverlay(animated: false)

        if style == .gentle && initialPhase != .fullscreen {
            isGentleMode = true
            showGentleOverlay(phase: initialPhase)
        } else {
            isGentleMode = false
            showFullscreenOverlay()
        }
    }

    /// Hide all overlay windows
    func hideOverlay(animated: Bool = true) {
        print("[OverlayController] Hiding overlay")

        let allWindows = windows + dimWindows + [floatingWindow].compactMap { $0 }
        windows.removeAll()
        dimWindows.removeAll()
        floatingWindow = nil
        keyWindow = nil
        isGentleMode = false

        for window in allWindows {
            window.orderOut(nil)
        }
    }

    // MARK: - Private: Enforced Mode (existing behavior)

    private func showFullscreenOverlay() {
        for screen in NSScreen.screens {
            let window = createFullscreenWindow(for: screen)
            windows.append(window)
        }

        for window in windows {
            showWindow(window)
        }

        if let firstWindow = windows.first {
            firstWindow.makeKey()
            keyWindow = firstWindow
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func createFullscreenWindow(for screen: NSScreen) -> NSWindow {
        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        let overlayView = BreakOverlayView()
        let hostingView = KeyableHostingView(rootView: overlayView)
        window.contentView = hostingView

        if let contentView = window.contentView {
            hostingView.frame = contentView.bounds
            hostingView.autoresizingMask = [.width, .height]
        }

        window.setFrame(screen.frame, display: true)
        return window
    }

    // MARK: - Private: Gentle Mode

    private func showGentleOverlay(phase: BreakPhase) {
        switch phase {
        case .floating:
            showDimOverlays(opacity: 0.2)
            showFloatingWindow(size: NSSize(width: 400, height: 300))

        case .dimmed:
            // Animate the existing windows during a normal phase transition, but
            // create them at the dimmed state if none exist — e.g. when re-showing
            // after a display-change teardown (issue #54).
            if dimWindows.isEmpty {
                showDimOverlays(opacity: 0.5)
            } else {
                animateDimOpacity(to: 0.5)
            }
            if floatingWindow == nil {
                showFloatingWindow(size: NSSize(width: 500, height: 380))
            } else {
                animateFloatingWindowGrow()
            }

        case .fullscreen:
            tearDownGentleWindows()
            showFullscreenOverlay()
        }
    }

    private func showDimOverlays(opacity: CGFloat) {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
            window.hasShadow = false
            window.ignoresMouseEvents = true

            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            dimWindows.append(window)
        }
    }

    private func showFloatingWindow(size: NSSize) {
        guard let primaryScreen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = primaryScreen.visibleFrame
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 20,
            y: screenFrame.minY + 20
        )
        let frame = NSRect(origin: origin, size: size)

        let window = KeyableWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: primaryScreen
        )

        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        let floatingView = GentleBreakFloatingView()
        let hostingView = KeyableHostingView(rootView: floatingView)
        window.contentView = hostingView

        if let contentView = window.contentView {
            hostingView.frame = contentView.bounds
            hostingView.autoresizingMask = [.width, .height]
        }

        window.setFrame(frame, display: true)
        showWindow(window)
        window.makeKey()
        keyWindow = window

        NSApp.activate(ignoringOtherApps: true)
        floatingWindow = window
    }

    private func animateDimOpacity(to opacity: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            for window in dimWindows {
                window.animator().backgroundColor = NSColor.black.withAlphaComponent(opacity)
            }
        }
    }

    private func animateFloatingWindowGrow() {
        guard let window = floatingWindow,
              let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let newSize = NSSize(width: 500, height: 380)
        let screenFrame = screen.visibleFrame
        let newOrigin = NSPoint(
            x: screenFrame.maxX - newSize.width - 20,
            y: screenFrame.minY + 20
        )
        let newFrame = NSRect(origin: newOrigin, size: newSize)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            window.animator().setFrame(newFrame, display: true)
        }
    }

    private func tearDownGentleWindows() {
        for window in dimWindows {
            window.orderOut(nil)
        }
        dimWindows.removeAll()

        floatingWindow?.orderOut(nil)
        floatingWindow = nil
        keyWindow = nil
    }

    // MARK: - Private: Phase Observer

    private func setupPhaseObserver() {
        Task { @MainActor in
            phaseObserver = AppState.shared.$breakPhase
                .removeDuplicates()
                .sink { [weak self] phase in
                    guard let self, self.isGentleMode else { return }
                    self.showGentleOverlay(phase: phase)
                }
        }
    }

    // MARK: - Private: Animation

    private func showWindow(_ window: NSWindow) {
        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                window.animator().alphaValue = 1
            }
        } else {
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
    }

    // MARK: - Private: Display Changes

    private func setupDisplayObserver() {
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDisplayChange()
        }
    }

    private func handleDisplayChange() {
        let hasAnyWindows = !windows.isEmpty || !dimWindows.isEmpty || floatingWindow != nil
        guard hasAnyWindows else { return }
        print("[OverlayController] Display configuration changed, updating windows")

        // The notification fires on the main queue (the main-actor executor),
        // so it's safe to read the @MainActor-isolated AppState synchronously.
        let (isVisible, phase) = MainActor.assumeIsolated {
            (AppState.shared.isOverlayVisible, AppState.shared.breakPhase)
        }

        // If the break already ended, tear down any leftover windows rather than
        // recreating a stale overlay (prevents the stuck 0:00 popup, issue #54).
        guard isVisible else {
            hideOverlay(animated: false)
            return
        }

        // Re-show using the CURRENT phase so an active fullscreen break stays
        // fullscreen on the remaining display instead of collapsing back to the
        // floating popup (issue #54).
        showOverlay(initialPhase: phase)
    }
}

// MARK: - KeyableWindow

final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - KeyableHostingView

final class KeyableHostingView<Content: View>: NSHostingView<Content> {

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            NotificationCenter.default.post(name: .breakOverlayEscPressed, object: nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let breakOverlayEscPressed = Notification.Name("breakOverlayEscPressed")
}
