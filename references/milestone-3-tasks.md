# Milestone 3: Settings, Shortcuts & Polish

**Goal:** Complete v1 feature set with settings, shortcuts, onboarding

**Prerequisites:**
- Milestone 1 completed (timer engine, menu bar)
- Milestone 2 completed (break overlay, menu controls)

**Estimated Tasks:** 8 tasks

---

## Task 3.1: Create Settings View

### Objective
Create the SwiftUI settings view with all configuration options.

### Instructions

1. **Create new file:**
   - Right-click on `Views` group
   - New File → Swift File
   - Name: `SettingsView.swift`
   - Create

2. **Replace contents with:**

```swift
import SwiftUI

/// Settings view shown in a separate window
///
/// Contains configuration for:
/// - Work/break durations
/// - Display mode (elapsed/remaining)
/// - Sound toggle
/// - Advanced: idle thresholds
/// - Keyboard shortcuts info
struct SettingsView: View {

    // MARK: - State

    @ObservedObject private var settings = Settings.shared

    /// Track if advanced section is expanded
    @State private var isAdvancedExpanded: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("Settings")
                .font(.headline)

            Divider()

            // Timer Settings
            timerSection

            Divider()

            // Display Settings
            displaySection

            Divider()

            // Advanced Settings (collapsible)
            advancedSection

            Divider()

            // Keyboard Shortcuts Info
            shortcutsSection

            Spacer()
        }
        .padding(20)
        .frame(width: 340, height: 420)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timer")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Work duration
            HStack {
                Text("Work duration")
                Spacer()
                Stepper(
                    "\(settings.workDurationMinutes) min",
                    value: $settings.workDurationMinutes,
                    in: 1...60,
                    step: 1
                )
                .frame(width: 120)
            }

            // Break duration
            HStack {
                Text("Break duration")
                Spacer()
                Stepper(
                    "\(settings.breakDurationMinutes) min",
                    value: $settings.breakDurationMinutes,
                    in: 1...30,
                    step: 1
                )
                .frame(width: 120)
            }

            // Sound toggle
            Toggle("Play sound when break starts", isOn: $settings.soundEnabled)
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text("Menu bar shows")
                Spacer()
                Picker("", selection: $settings.displayMode) {
                    Text("Elapsed time").tag(DisplayMode.elapsed)
                    Text("Remaining time").tag(DisplayMode.remaining)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        DisclosureGroup(
            isExpanded: $isAdvancedExpanded,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    // Idle ignore threshold
                    HStack {
                        Text("Idle ignore")
                        Spacer()
                        Stepper(
                            "\(settings.idleIgnoreThreshold)s",
                            value: $settings.idleIgnoreThreshold,
                            in: 30...120,
                            step: 10
                        )
                        .frame(width: 100)
                    }

                    // Idle reset threshold
                    HStack {
                        Text("Idle reset")
                        Spacer()
                        Stepper(
                            "\(settings.idleResetThreshold)s",
                            value: $settings.idleResetThreshold,
                            in: 120...600,
                            step: 30
                        )
                        .frame(width: 100)
                    }

                    // Explanation
                    Text("Idle under \(settings.idleIgnoreThreshold)s counts as active (reading/thinking). Idle over \(settings.idleResetThreshold)s resets the session when you return.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            },
            label: {
                Text("Advanced")
            }
        )
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Pause/Resume")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘⇧B")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }

                GridRow {
                    Text("Restart Session")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘⇧R")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }

            // Permission note
            if !isAccessibilityEnabled() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Enable Accessibility to use global shortcuts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)

                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Helpers

    /// Check if Accessibility permission is granted
    private func isAccessibilityEnabled() -> Bool {
        // Check without prompting
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to Accessibility pane
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Settings Binding Extension

extension Settings {
    /// Binding for displayMode that works with Picker
    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .elapsed }
        set { displayModeRaw = newValue.rawValue }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
```

### Verification
1. Build succeeds: `Cmd+B`
2. Open Preview canvas for SettingsView
3. Verify:
   - Timer section with work/break duration steppers
   - Display section with elapsed/remaining picker
   - Sound toggle
   - Advanced section (click to expand)
   - Keyboard shortcuts section

### Files Created
- `Blink/Views/SettingsView.swift`

---

## Task 3.2: Create Settings Window Controller

### Objective
Create the controller that shows the settings window.

### Instructions

1. **Create new file:**
   - Right-click on `Windows` group
   - New File → Swift File
   - Name: `SettingsWindowController.swift`
   - Create

2. **Replace contents with:**

```swift
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
```

3. **Update MenuBarView to open settings:**
   - Open `Blink/Views/MenuBarView.swift`
   - Find the Settings button and update it:

```swift
Button("Settings...") {
    SettingsWindowController.shared.showSettings()
}
.keyboardShortcut(",", modifiers: [.command])
```

### Verification
1. Build and run: `Cmd+R`
2. Click menu bar timer → Settings...
3. Settings window should open
4. Verify:
   - Window title is "Blink Settings"
   - Window is closable (X button works)
   - Can still interact with menu bar while settings is open
   - Changes take effect immediately (e.g., change display mode → menu bar updates)

### Files Created
- `Blink/Windows/SettingsWindowController.swift`

### Files Modified
- `Blink/Views/MenuBarView.swift` (updated Settings button)

---

## Task 3.3: Create HotkeyManager for Global Shortcuts

### Objective
Implement global keyboard shortcuts with lazy permission request.

### Instructions

1. **Create new file:**
   - Right-click on `Services` group
   - New File → Swift File
   - Name: `HotkeyManager.swift`
   - Create

2. **Replace contents with:**

```swift
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
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
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
```

3. **Update BlinkApp.swift to start HotkeyManager:**
   - Open `Blink/BlinkApp.swift`
   - In the `init()` method, add after TimerEngine.shared.start():

```swift
// Start hotkey manager (lazy permission)
HotkeyManager.shared.startListening()
```

The init should look like:

```swift
init() {
    // Start timer engine and setup overlay observation
    Task { @MainActor in
        print("[BlinkApp] Initializing")

        // Start timer engine
        TimerEngine.shared.start()

        // Start hotkey manager (lazy permission)
        HotkeyManager.shared.startListening()

        // Observe overlay visibility changes
        setupOverlayObserver()
    }
}
```

### Verification

1. Build and run: `Cmd+R`

2. **If Accessibility permission NOT yet granted:**
   - Press ⌘⇧B - nothing should happen (no prompt yet)
   - Open Settings → see "Enable Accessibility" message
   - Click "Open System Settings"
   - In System Settings > Privacy & Security > Accessibility
   - Add and enable "Blink" app
   - Restart the app

3. **After Accessibility permission granted:**
   - Press ⌘⇧B - timer should pause, menu bar shows ⏸
   - Press ⌘⇧B again - timer should resume
   - Press ⌘⇧R - timer should restart to 00:00

4. **Test shortcuts work globally:**
   - Focus a different app (Safari, Terminal, etc.)
   - Press ⌘⇧B - Blink timer should still toggle

### Files Created
- `Blink/Services/HotkeyManager.swift`

### Files Modified
- `Blink/BlinkApp.swift` (added HotkeyManager start)

---

## Task 3.4: Create LaunchAtLoginManager

### Objective
Implement launch at login using SMAppService.

### Instructions

1. **Create new file:**
   - Right-click on `Services` group
   - New File → Swift File
   - Name: `LaunchAtLoginManager.swift`
   - Create

2. **Replace contents with:**

```swift
import Foundation
import ServiceManagement

/// Manages Launch at Login functionality using SMAppService
///
/// Uses the modern SMAppService API (macOS 13+) to register/unregister
/// the app as a login item.
///
/// Usage:
/// - `LaunchAtLoginManager.shared.setEnabled(true)` to enable
/// - `LaunchAtLoginManager.shared.isEnabled` to check status
final class LaunchAtLoginManager {

    // MARK: - Singleton

    static let shared = LaunchAtLoginManager()

    // MARK: - Properties

    /// The app service for the main app
    private let appService = SMAppService.mainApp

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Whether launch at login is currently enabled
    var isEnabled: Bool {
        appService.status == .enabled
    }

    /// Enable or disable launch at login
    /// - Parameter enabled: True to enable, false to disable
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                // Register to launch at login
                if appService.status == .notRegistered || appService.status == .notFound {
                    try appService.register()
                    print("[LaunchAtLogin] Registered successfully")
                } else {
                    print("[LaunchAtLogin] Already registered, status: \(appService.status)")
                }
            } else {
                // Unregister from launch at login
                if appService.status == .enabled {
                    try appService.unregister()
                    print("[LaunchAtLogin] Unregistered successfully")
                } else {
                    print("[LaunchAtLogin] Already unregistered, status: \(appService.status)")
                }
            }
        } catch {
            print("[LaunchAtLogin] Error: \(error.localizedDescription)")
        }
    }

    /// Sync the manager state with Settings
    /// Call this at app launch to ensure consistency
    func syncWithSettings() {
        let shouldBeEnabled = Settings.shared.launchAtLogin
        let currentlyEnabled = isEnabled

        if shouldBeEnabled != currentlyEnabled {
            print("[LaunchAtLogin] Syncing: Settings=\(shouldBeEnabled), Actual=\(currentlyEnabled)")
            setEnabled(shouldBeEnabled)
        }
    }
}
```

3. **Update MenuBarView to use LaunchAtLoginManager:**
   - Open `Blink/Views/MenuBarView.swift`
   - Find the Launch at Login toggle and update it:

```swift
Toggle("Launch at Login", isOn: $settings.launchAtLogin)
    .onChange(of: settings.launchAtLogin) { _, newValue in
        LaunchAtLoginManager.shared.setEnabled(newValue)
    }
```

4. **Update BlinkApp.swift to sync at launch:**
   - Open `Blink/BlinkApp.swift`
   - In the init() method, add after HotkeyManager:

```swift
// Sync launch at login with settings
LaunchAtLoginManager.shared.syncWithSettings()
```

### Verification

1. Build and run: `Cmd+R`

2. **Test enabling:**
   - Open menu → check "Launch at Login" toggle is ON (default)
   - Open System Settings → General → Login Items
   - "Blink" should appear in the list

3. **Test disabling:**
   - Open menu → uncheck "Launch at Login"
   - Check System Settings → Login Items
   - "Blink" should be removed from the list

4. **Test actual launch at login:**
   - Enable Launch at Login
   - Log out and log back in (or restart)
   - Blink should automatically start
   - Timer should be running in menu bar

### Files Created
- `Blink/Services/LaunchAtLoginManager.swift`

### Files Modified
- `Blink/Views/MenuBarView.swift` (updated toggle handler)
- `Blink/BlinkApp.swift` (added sync call)

---

## Task 3.5: Create Onboarding View

### Objective
Create a welcome window shown on first launch.

### Instructions

1. **Create new file:**
   - Right-click on `Views` group
   - New File → Swift File
   - Name: `OnboardingView.swift`
   - Create

2. **Replace contents with:**

```swift
import SwiftUI

/// First-launch onboarding view
///
/// Shows a welcome message with key feature highlights.
/// Displayed once on first launch, then never again.
struct OnboardingView: View {

    // MARK: - State

    @ObservedObject private var settings = Settings.shared

    /// Callback when onboarding is completed
    var onComplete: () -> Void = {}

    // MARK: - Body

    var body: some View {
        VStack(spacing: 28) {
            // App icon/logo area
            Image(systemName: "eye")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .padding(.top, 20)

            // Welcome text
            VStack(spacing: 8) {
                Text("Welcome to Blink")
                    .font(.system(size: 28, weight: .semibold))

                Text("Reduce eye strain with regular breaks")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "clock.fill",
                    title: "25/5 Rhythm",
                    description: "Work for 25 minutes, then take a 5-minute break"
                )

                FeatureRow(
                    icon: "display",
                    title: "Gentle Reminders",
                    description: "Full-screen overlay reminds you to look away"
                )

                FeatureRow(
                    icon: "keyboard",
                    title: "Easy Controls",
                    description: "Press Esc to snooze, double-Esc to skip"
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            // Get Started button
            Button(action: {
                settings.hasCompletedOnboarding = true
                onComplete()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
        .frame(width: 380, height: 480)
    }
}

// MARK: - Feature Row

/// A single feature highlight row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
```

### Verification
1. Build succeeds: `Cmd+B`
2. Open Preview canvas for OnboardingView
3. Verify:
   - Eye icon at top
   - "Welcome to Blink" title
   - Three feature rows with icons
   - Blue "Get Started" button at bottom

### Files Created
- `Blink/Views/OnboardingView.swift`

---

## Task 3.6: Create Onboarding Window Controller

### Objective
Create the controller that shows the onboarding window on first launch.

### Instructions

1. **Create new file:**
   - Right-click on `Windows` group
   - New File → Swift File
   - Name: `OnboardingWindowController.swift`
   - Create

2. **Replace contents with:**

```swift
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
```

3. **Update BlinkApp.swift to show onboarding:**
   - Open `Blink/BlinkApp.swift`
   - In the init() method, add at the end (after all other initialization):

```swift
// Show onboarding if first launch (with slight delay for window to be ready)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    OnboardingWindowController.shared.showIfNeeded()
}
```

The complete init() should look like:

```swift
init() {
    // Start timer engine and setup overlay observation
    Task { @MainActor in
        print("[BlinkApp] Initializing")

        // Start timer engine
        TimerEngine.shared.start()

        // Start hotkey manager (lazy permission)
        HotkeyManager.shared.startListening()

        // Sync launch at login with settings
        LaunchAtLoginManager.shared.syncWithSettings()

        // Observe overlay visibility changes
        setupOverlayObserver()

        // Show onboarding if first launch (with slight delay for window to be ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            OnboardingWindowController.shared.showIfNeeded()
        }
    }
}
```

### Verification

1. **Test first launch:**
   - Delete app preferences: In Terminal, run:
     ```bash
     defaults delete com.yourname.Blink
     ```
     (Replace `com.yourname.Blink` with your actual bundle identifier)
   - Build and run: `Cmd+R`
   - Onboarding window should appear
   - Click "Get Started"
   - Window should close

2. **Test subsequent launch:**
   - Stop and re-run the app: `Cmd+R`
   - Onboarding should NOT appear (already completed)

3. **Test window behavior:**
   - Reset preferences again (delete defaults)
   - Run app
   - Onboarding appears
   - Click the X button to close without clicking "Get Started"
   - Re-run app
   - Onboarding should appear again (wasn't completed)

### Files Created
- `Blink/Windows/OnboardingWindowController.swift`

### Files Modified
- `Blink/BlinkApp.swift` (added onboarding show)

---

## Task 3.7: Add Unit Tests

### Objective
Add unit tests for core logic.

### Instructions

1. **Open BlinkTests target:**
   - In Xcode's Project Navigator, expand "BlinkTests" group
   - Delete the auto-generated `BlinkTests.swift` file

2. **Create TimerEngineTests.swift:**
   - Right-click on "BlinkTests" group
   - New File → Swift File
   - Name: `TimerEngineTests.swift`
   - Ensure "BlinkTests" target is checked
   - Create

3. **Replace contents with:**

```swift
import XCTest
@testable import Blink

/// Tests for TimerEngine core logic
@MainActor
final class TimerEngineTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        // Reset state before each test
        AppState.shared.reset()
        Settings.shared.resetToDefaults()
    }

    override func tearDown() async throws {
        // Clean up after each test
        AppState.shared.reset()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        let appState = AppState.shared

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.breakRemainingSeconds, 0)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Pause/Resume Tests

    func testTogglePause() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Initial state: running
        XCTAssertEqual(appState.timerState, .workRunning)

        // Toggle to paused
        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workPaused)

        // Toggle back to running
        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testCannotPauseDuringBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Trigger break
        engine.startBreakNow()
        XCTAssertEqual(appState.timerState, .breakRunning)

        // Try to pause - should not change state
        engine.togglePause()
        XCTAssertEqual(appState.timerState, .breakRunning)
    }

    // MARK: - Restart Tests

    func testRestartSession() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Set some elapsed time
        appState.workElapsedSeconds = 600

        // Restart
        engine.restartSession()

        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testRestartDuringBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Start break
        engine.startBreakNow()
        XCTAssertTrue(appState.isOverlayVisible)

        // Restart
        engine.restartSession()

        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Break Tests

    func testStartBreakNow() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        engine.startBreakNow()

        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertEqual(appState.breakRemainingSeconds, settings.breakDurationSeconds)
        XCTAssertTrue(appState.isOverlayVisible)
    }

    func testSnoozeBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared
        let settings = Settings.shared

        // Start break
        engine.startBreakNow()
        XCTAssertTrue(appState.isOverlayVisible)

        // Snooze
        engine.snoozeBreak()

        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertEqual(appState.snoozeRemainingSeconds, settings.snoozeDurationSeconds)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    func testSkipBreak() {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        // Start break
        engine.startBreakNow()

        // Skip
        engine.skipBreak()

        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    // MARK: - Display Tests

    func testDisplayTimeElapsed() {
        let appState = AppState.shared
        let settings = Settings.shared

        settings.displayMode = .elapsed
        appState.workElapsedSeconds = 125  // 2:05

        XCTAssertEqual(appState.displayTime, "02:05")
    }

    func testDisplayTimeRemaining() {
        let appState = AppState.shared
        let settings = Settings.shared

        settings.displayMode = .remaining
        settings.workDurationMinutes = 25
        appState.workElapsedSeconds = 125  // 2:05 elapsed, 22:55 remaining

        XCTAssertEqual(appState.displayTime, "22:55")
    }

    func testMenuBarTitlePaused() {
        let appState = AppState.shared

        appState.workElapsedSeconds = 125
        appState.timerState = .workPaused

        XCTAssertTrue(appState.menuBarTitle.hasPrefix("⏸"))
    }
}
```

4. **Create SettingsTests.swift:**
   - Right-click on "BlinkTests" group
   - New File → Swift File
   - Name: `SettingsTests.swift`
   - Create

5. **Replace contents with:**

```swift
import XCTest
@testable import Blink

/// Tests for Settings persistence
final class SettingsTests: XCTestCase {

    // MARK: - Setup

    override func setUp() {
        // Reset to defaults before each test
        Settings.shared.resetToDefaults()
    }

    // MARK: - Default Values Tests

    func testDefaultValues() {
        let settings = Settings.shared

        XCTAssertEqual(settings.workDurationMinutes, 25)
        XCTAssertEqual(settings.breakDurationMinutes, 5)
        XCTAssertEqual(settings.snoozeDurationMinutes, 5)
        XCTAssertEqual(settings.idleIgnoreThreshold, 60)
        XCTAssertEqual(settings.idleResetThreshold, 300)
        XCTAssertEqual(settings.displayMode, .elapsed)
        XCTAssertFalse(settings.soundEnabled)
        XCTAssertTrue(settings.launchAtLogin)
    }

    // MARK: - Computed Properties Tests

    func testWorkDurationSeconds() {
        let settings = Settings.shared

        settings.workDurationMinutes = 30

        XCTAssertEqual(settings.workDurationSeconds, 1800)
    }

    func testBreakDurationSeconds() {
        let settings = Settings.shared

        settings.breakDurationMinutes = 10

        XCTAssertEqual(settings.breakDurationSeconds, 600)
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        let settings = Settings.shared

        // Change some values
        settings.workDurationMinutes = 50
        settings.soundEnabled = true
        settings.displayMode = .remaining

        // Reset
        settings.resetToDefaults()

        // Verify defaults restored
        XCTAssertEqual(settings.workDurationMinutes, 25)
        XCTAssertFalse(settings.soundEnabled)
        XCTAssertEqual(settings.displayMode, .elapsed)
    }
}
```

### Verification

1. **Run tests:**
   - Product → Test (or `Cmd+U`)
   - All tests should pass

2. **Verify test coverage:**
   - TimerEngineTests: 8 tests
   - SettingsTests: 4 tests
   - Total: 12 tests

### Files Created
- `BlinkTests/TimerEngineTests.swift`
- `BlinkTests/SettingsTests.swift`

### Files Deleted
- `BlinkTests/BlinkTests.swift` (auto-generated)

---

## Task 3.8: Final Polish and Verification

### Objective
Final cleanup, verification, and preparation for use.

### Instructions

1. **Add app icon:**
   - Open `Blink/Assets.xcassets`
   - Click on "AppIcon"
   - For now, leave it empty (will use default icon)
   - **Optional:** Create a custom icon using SF Symbols:
     - Open Image Capture or Preview
     - Create a simple 1024x1024 image with an eye symbol
     - Drag into the 1024pt slot

2. **Clean up any debug prints:**
   - Search for `print(` in the project
   - Ensure all prints have `[ClassName]` prefix for easy filtering
   - Consider wrapping in `#if DEBUG` for release builds (optional for v1)

3. **Verify Info.plist settings:**
   - Open Info.plist (or target → Info tab)
   - Verify these keys exist:
     - `Application is agent (UIElement)` = YES
     - `Bundle display name` = Blink
     - `Bundle name` = Blink

4. **Run complete test suite:**
   - `Cmd+U` to run all tests
   - All 12 tests should pass

5. **Manual testing checklist:**
   Complete all items in the checklist below.

### Final Testing Checklist

#### App Launch
- [ ] App appears in menu bar (no dock icon)
- [ ] Shows `00:00` initially
- [ ] Onboarding appears on first launch
- [ ] Onboarding does NOT appear on subsequent launches

#### Timer Core
- [ ] Timer increments during activity
- [ ] Timer uses monospaced digits (no width jumping)
- [ ] Timer pauses when idle 60-300s
- [ ] Timer resets after idle >= 300s then return

#### Menu Controls
- [ ] Menu opens when clicking timer
- [ ] Pause pauses timer, shows ⏸
- [ ] Resume continues timer
- [ ] Restart resets to 00:00
- [ ] Start Break Now triggers overlay
- [ ] Settings opens settings window
- [ ] Launch at Login toggle persists
- [ ] Quit exits the app

#### Break Overlay
- [ ] Overlay appears on all monitors
- [ ] Overlay appears above full-screen apps
- [ ] Dark gradient with purple glow
- [ ] Countdown timer visible and counting
- [ ] "Look away..." message visible
- [ ] Snooze/Skip buttons work
- [ ] Single Esc snoozes
- [ ] Double Esc skips
- [ ] Overlay fades (or instant if Reduce Motion)
- [ ] Auto-dismisses at countdown end

#### Settings
- [ ] Settings window opens
- [ ] Work duration stepper works
- [ ] Break duration stepper works
- [ ] Sound toggle works
- [ ] Display mode picker works
- [ ] Advanced section expands
- [ ] Idle thresholds adjustable
- [ ] Changes apply immediately
- [ ] Settings persist after restart

#### Global Shortcuts
- [ ] ⌘⇧B toggles pause (after permission)
- [ ] ⌘⇧R restarts session (after permission)
- [ ] Settings shows permission warning if not granted

#### Launch at Login
- [ ] Toggle enables/disables in System Settings
- [ ] App launches at login when enabled

### Files Verified
All files should exist and be working:
- `Blink/BlinkApp.swift`
- `Blink/Models/TimerState.swift`
- `Blink/Models/Settings.swift`
- `Blink/Models/AppState.swift`
- `Blink/Services/IdleDetector.swift`
- `Blink/Services/TimerEngine.swift`
- `Blink/Services/HotkeyManager.swift`
- `Blink/Services/LaunchAtLoginManager.swift`
- `Blink/Views/MenuBarView.swift`
- `Blink/Views/BreakOverlayView.swift`
- `Blink/Views/SettingsView.swift`
- `Blink/Views/OnboardingView.swift`
- `Blink/Windows/BreakOverlayWindowController.swift`
- `Blink/Windows/SettingsWindowController.swift`
- `Blink/Windows/OnboardingWindowController.swift`
- `BlinkTests/TimerEngineTests.swift`
- `BlinkTests/SettingsTests.swift`

---

## Milestone 3 Complete!

Congratulations! You have completed Blink v1.

### What You've Built
- Menu bar app with timer display
- Idle-aware work time tracking (60s ignore, 300s reset)
- Full-screen break overlay on all monitors
- Snooze and skip functionality
- Settings window with all configurations
- Global keyboard shortcuts
- Launch at login
- First-launch onboarding
- Unit tests for core logic

### Next Steps (Optional)

1. **Notarization:**
   - Sign the app with your Developer ID
   - Notarize using `notarytool`
   - Create a DMG for distribution

2. **App Icon:**
   - Design a custom icon
   - Add to Assets.xcassets

3. **Marketing:**
   - Create screenshots
   - Write app description
   - Prepare for distribution

### Future Versions

See `references/prd.md` for planned features:
- **v2:** Micro-nudges (blink, posture, stretch)
- **v3:** Intelligent nudges, camera-based posture detection
