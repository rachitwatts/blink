import AppKit
import Carbon

/// Manages global keyboard shortcuts
///
/// Shortcuts:
/// - ⌘⇧B: Toggle Pause/Resume
/// - ⌘⇧R: Restart Session
///
/// Requires Accessibility permission. Uses lazy request - only prompts
/// when user first tries to use shortcuts (not at app launch).
///
/// Usage: Call `HotkeyManager.shared.startListening()` at app launch
final class HotkeyManager {

    // MARK: - Singleton

    static let shared = HotkeyManager()

    // MARK: - Properties

    /// Monitor for global keyboard events
    private var eventMonitor: Any?

    /// Track if we've already requested permission
    private var hasRequestedPermission: Bool = false

    /// Track if permission was granted
    private var isPermissionGranted: Bool = false

    // MARK: - Initialization

    private init() {
        // Check permission status (without prompting)
        isPermissionGranted = checkAccessibilityPermission(prompt: false)
    }

    // MARK: - Public API

    /// Start listening for global keyboard shortcuts
    /// Call this at app launch
    func startListening() {
        // If already listening, do nothing
        guard eventMonitor == nil else {
            print("[HotkeyManager] Already listening")
            return
        }

        // Check permission without prompting
        if checkAccessibilityPermission(prompt: false) {
            print("[HotkeyManager] Permission granted, starting listener")
            setupEventMonitor()
        } else {
            print("[HotkeyManager] Permission not granted, shortcuts disabled")
            // Don't prompt - will prompt on first shortcut attempt
        }
    }

    /// Stop listening for global keyboard shortcuts
    func stopListening() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("[HotkeyManager] Stopped listening")
        }
    }

    /// Request permission if not already granted
    /// Returns true if permission is granted (or was already granted)
    @discardableResult
    func requestPermissionIfNeeded() -> Bool {
        // Check current status
        if checkAccessibilityPermission(prompt: false) {
            isPermissionGranted = true
            return true
        }

        // Only prompt once
        if !hasRequestedPermission {
            hasRequestedPermission = true
            print("[HotkeyManager] Requesting Accessibility permission")

            // Prompt for permission
            let granted = checkAccessibilityPermission(prompt: true)
            isPermissionGranted = granted

            if granted {
                // Start listening now that we have permission
                setupEventMonitor()
            }

            return granted
        }

        return false
    }

    // MARK: - Private: Permission

    /// Check Accessibility permission
    /// - Parameter prompt: If true, shows system dialog if not granted
    /// - Returns: True if permission is granted
    private func checkAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Private: Event Monitoring

    /// Setup the global event monitor
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        print("[HotkeyManager] Event monitor setup complete")
    }

    /// Handle a global key event
    private func handleKeyEvent(_ event: NSEvent) {
        // Check for our modifier combination: Command + Shift
        // Mask out CapsLock and Function keys to avoid false negatives
        let ignoredFlags: NSEvent.ModifierFlags = [.capsLock, .function, .numericPad]
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(ignoredFlags)
        let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]

        guard flags == requiredFlags else { return }

        // Get the character
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return }

        // Handle shortcuts on main thread
        Task { @MainActor in
            switch chars {
            case "b":
                // ⌘⇧B: Toggle Pause/Resume
                print("[HotkeyManager] ⌘⇧B pressed: Toggle Pause")
                TimerEngine.shared.togglePause()

            case "r":
                // ⌘⇧R: Restart Session
                print("[HotkeyManager] ⌘⇧R pressed: Restart Session")
                TimerEngine.shared.restartSession()

            default:
                break
            }
        }
    }
}
