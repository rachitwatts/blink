import AppKit
import SwiftUI

/// Controls the Onboarding window
///
/// Shows a welcome window on first launch only.
/// Once user clicks "Get Started", never shows again.
///
/// Usage: Call `OnboardingWindowController.shared.showIfNeeded()` at app launch
final class OnboardingWindowController {

    // MARK: - Singleton

    static let shared = OnboardingWindowController()

    // MARK: - Properties

    private var window: NSWindow?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Show onboarding only if user hasn't completed it before
    func showIfNeeded() {
        // Check if onboarding was already completed
        guard !Settings.shared.hasCompletedOnboarding else {
            print("[Onboarding] Already completed, skipping")
            return
        }

        show()
    }

    /// Show the onboarding window
    func show() {
        // If window exists and is visible, bring to front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create onboarding view with completion handler
        let onboardingView = OnboardingView(onComplete: { [weak self] in
            self?.close()
        })

        let hostingController = NSHostingController(rootView: onboardingView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Welcome to Blink"
        newWindow.styleMask = [.titled, .closable]
        newWindow.setContentSize(NSSize(width: 380, height: 480))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Make it stand out
        newWindow.level = .floating

        // Store reference
        window = newWindow

        // Show window
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("[Onboarding] Showing onboarding window")
    }

    /// Close the onboarding window
    func close() {
        window?.close()
        window = nil
        print("[Onboarding] Closed onboarding window")
    }
}
