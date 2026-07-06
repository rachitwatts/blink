#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class InCallNudgeWindowController {

    static let shared = InCallNudgeWindowController()

    #if DEBUG
    static var suppressForTesting = false
    #endif

    private var window: NSWindow?
    private var dismissTimer: DispatchWorkItem?

    private init() {}

    func show(duration: TimeInterval = 4) {
        #if DEBUG
        guard !Self.suppressForTesting else { return }
        #endif
        hide()

        guard NSApp != nil, let screen = NSScreen.main else { return }

        let hostingView = NSHostingView(rootView: InCallNudgeView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 44)
        let fittingSize = hostingView.fittingSize
        let windowWidth = max(fittingSize.width + 32, 280)
        let windowHeight = max(fittingSize.height + 16, 44)

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.minY + 60

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1
        }

        self.window = panel

        let dismiss = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        dismissTimer = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismiss)
    }

    func hide() {
        dismissTimer?.cancel()
        dismissTimer = nil
        window?.orderOut(nil)
        window = nil
    }

    private func fadeOut() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
        })
    }
}

#endif
