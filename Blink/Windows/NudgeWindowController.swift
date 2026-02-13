import AppKit
import SwiftUI

/// Controls the nudge panel window that slides in from the right edge
///
/// The nudge appears as a small floating panel near the top-right of the main screen.
/// It does not steal focus, is non-modal, and auto-dismisses after a few seconds.
final class NudgeWindowController {

    // MARK: - Singleton

    static let shared = NudgeWindowController()

    // MARK: - Properties

    private var window: NSWindow?

    /// Width of the nudge panel
    private let panelWidth: CGFloat = 280

    /// Height of the nudge panel
    private let panelHeight: CGFloat = 90

    /// Margin from screen edge
    private let edgeMargin: CGFloat = 16

    /// Margin from top of screen
    private let topMargin: CGFloat = 48

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Show a nudge panel for the given type, sliding in from the right
    func showNudge(_ type: NudgeType) {
        // Dismiss existing nudge first
        hideNudge(animated: false)

        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame

        // Final position: top-right corner with margins
        let finalX = screenFrame.maxX - panelWidth - edgeMargin
        let finalY = screenFrame.maxY - panelHeight - topMargin

        // Start position: offscreen to the right
        let startX = screenFrame.maxX + 10

        let window = NSPanel(
            contentRect: NSRect(x: startX, y: finalY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false

        let nudgeView = NudgeView(nudgeType: type) {
            NudgeEngine.shared.dismissNudge()
        }
        let hostingView = NSHostingView(rootView: nudgeView)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        window.contentView = hostingView

        self.window = window

        // Show and slide in
        window.orderFrontRegardless()

        let shouldAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(
                    NSRect(x: finalX, y: finalY, width: panelWidth, height: panelHeight),
                    display: true
                )
            }
        } else {
            window.setFrame(
                NSRect(x: finalX, y: finalY, width: panelWidth, height: panelHeight),
                display: true
            )
        }
    }

    /// Hide the nudge panel
    func hideNudge(animated: Bool = true) {
        guard let window = self.window else { return }

        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            guard let screen = NSScreen.main else {
                window.orderOut(nil)
                self.window = nil
                return
            }

            let offscreenX = screen.visibleFrame.maxX + 10

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                var frame = window.frame
                frame.origin.x = offscreenX
                window.animator().setFrame(frame, display: true)
            }, completionHandler: { [weak self] in
                window.orderOut(nil)
                self?.window = nil
            })
        } else {
            window.orderOut(nil)
            self.window = nil
        }
    }
}
