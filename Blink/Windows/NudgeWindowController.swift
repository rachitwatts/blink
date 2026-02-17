import AppKit
import SwiftUI

/// Controls the nudge panel window
///
/// Responsibilities:
/// - Creates NSPanel for non-activating floating window
/// - Positions at top-right of active screen (where cursor is)
/// - Manages slide-in/out animations
/// - Respects reduce motion preference
///
/// Usage: Observe AppState.isNudgeVisible and call show()/hide()
@MainActor
final class NudgeWindowController {

    // MARK: - Singleton

    static let shared = NudgeWindowController()

    // MARK: - Properties

    private var panel: NSPanel?

    /// Offset from screen edge
    private let edgeOffset: CGFloat = 16

    /// Panel width (matches NudgeView)
    private let panelWidth: CGFloat = 300

    /// Panel height (content + progress bar)
    private let panelHeight: CGFloat = 56

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Show nudge panel on the active screen
    func show() {
        // Clean up any existing panel
        hide(animated: false)

        // Find active screen (where cursor is)
        let screen = activeScreen()

        // Create panel
        let panel = createPanel(for: screen)
        self.panel = panel

        // Position at top-right, off-screen initially
        let onScreenFrame = targetFrame(for: screen)
        let offScreenFrame = NSRect(
            x: screen.visibleFrame.maxX + edgeOffset,
            y: onScreenFrame.origin.y,
            width: panelWidth,
            height: panelHeight
        )
        panel.setFrame(offScreenFrame, display: false)

        // Show panel
        panel.orderFrontRegardless()

        // Animate to on-screen position
        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(onScreenFrame, display: true)
            }
        } else {
            panel.setFrame(onScreenFrame, display: true)
        }
    }

    /// Hide nudge panel
    func hide(animated: Bool = true) {
        guard let panel = panel else { return }

        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            // Slide out to right
            let offScreenFrame = NSRect(
                x: panel.frame.origin.x + panelWidth + edgeOffset,
                y: panel.frame.origin.y,
                width: panelWidth,
                height: panelHeight
            )

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(offScreenFrame, display: true)
            }, completionHandler: { [weak self] in
                self?.cleanupPanel()
            })
        } else {
            cleanupPanel()
        }
    }

    // MARK: - Private

    private func createPanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure panel
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // Shadow is in SwiftUI view
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        // Set SwiftUI content — pass the active nudge type from AppState
        let nudgeType = AppState.shared.activeNudgeType ?? .blink
        let hostingView = NSHostingView(rootView: NudgeView(nudgeType: nudgeType))
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hostingView

        return panel
    }

    private func activeScreen() -> NSScreen {
        // Find screen containing the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        // Fallback to main screen
        return NSScreen.main ?? NSScreen.screens.first!
    }

    private func targetFrame(for screen: NSScreen) -> NSRect {
        // Position at top-right of visible frame (below menu bar)
        let visibleFrame = screen.visibleFrame
        return NSRect(
            x: visibleFrame.maxX - panelWidth - edgeOffset,
            y: visibleFrame.maxY - panelHeight - edgeOffset,
            width: panelWidth,
            height: panelHeight
        )
    }

    private func cleanupPanel() {
        panel?.orderOut(nil)
        panel = nil
    }
}
