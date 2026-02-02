# Milestone 2: Break System

**Goal:** Full-screen break overlay with snooze/skip and menu controls

**Prerequisites:**
- Milestone 1 completed
- Timer engine working
- Menu bar showing timer

**Estimated Tasks:** 6 tasks

---

## Task 2.1: Create BreakOverlayView

### Objective
Create the SwiftUI view for the break overlay content (timer, message, buttons).

### Instructions

1. **Create new file:**
   - Right-click on `Views` group
   - New File → Swift File
   - Name: `BreakOverlayView.swift`
   - Create

2. **Replace contents with:**

```swift
import SwiftUI

/// Full-screen break overlay content
///
/// Shows countdown timer, calming message, and snooze/skip buttons.
/// Uses a dark gradient background with soft purple glow.
struct BreakOverlayView: View {

    // MARK: - State

    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared

    /// Track last Esc press time for double-Esc detection
    @State private var lastEscTime: Date? = nil

    /// Window for double-Esc detection (500ms)
    private let doubleEscWindow: TimeInterval = 0.5

    /// Respect user's reduce motion preference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background: Dark gradient
            backgroundGradient

            // Content: Timer, message, buttons
            VStack(spacing: 40) {
                Spacer()

                // Large countdown timer
                countdownTimer

                // Calming message
                messageText

                Spacer()

                // Snooze and Skip buttons
                buttonRow

                // Keyboard hints
                hintText

                Spacer()
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft purple glow in center
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Timer Display

    private var countdownTimer: some View {
        Text(formatTime(appState.breakRemainingSeconds))
            .font(.system(size: 80, weight: .light, design: .monospaced))
            .foregroundColor(.white)
            .accessibilityLabel("Time remaining: \(formatTimeAccessible(appState.breakRemainingSeconds))")
    }

    // MARK: - Message

    private var messageText: some View {
        Text("Look away. Blink. Breathe.")
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.white.opacity(0.7))
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: 30) {
            // Snooze button
            Button(action: {
                performSnooze()
            }) {
                Text("Snooze 5 min")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Snooze for 5 minutes")
            .accessibilityHint("Hides overlay temporarily, will return after 5 minutes")

            // Skip button
            Button(action: {
                performSkip()
            }) {
                Text("Skip")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip break")
            .accessibilityHint("Ends break immediately and starts new work session")
        }
    }

    // MARK: - Hints

    private var hintText: some View {
        Text("Esc = Snooze 5 min  •  Esc Esc = Skip")
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.4))
    }

    // MARK: - Actions

    /// Snooze the break with optional animation
    private func performSnooze() {
        if reduceMotion {
            timerEngine.snoozeBreak()
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                timerEngine.snoozeBreak()
            }
        }
    }

    /// Skip the break with optional animation
    private func performSkip() {
        if reduceMotion {
            timerEngine.skipBreak()
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                timerEngine.skipBreak()
            }
        }
    }

    /// Handle Esc key press - implements double-Esc detection
    func handleEscKey() {
        let now = Date()

        if let lastTime = lastEscTime,
           now.timeIntervalSince(lastTime) < doubleEscWindow {
            // Double Esc detected - Skip
            print("[BreakOverlay] Double Esc detected, skipping")
            lastEscTime = nil
            performSkip()
        } else {
            // First Esc - wait for potential second
            print("[BreakOverlay] First Esc detected, waiting for second...")
            lastEscTime = now

            // After the window passes, if no second Esc, snooze
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleEscWindow) { [self] in
                // Check if lastEscTime is still our time (no second Esc came)
                if let storedTime = lastEscTime, storedTime == now {
                    print("[BreakOverlay] No second Esc, snoozing")
                    lastEscTime = nil
                    performSnooze()
                }
            }
        }
    }

    // MARK: - Helpers

    /// Format seconds as "m:ss" for display
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format seconds for accessibility (spoken)
    private func formatTimeAccessible(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes) minutes and \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }
}

// MARK: - Preview

#Preview {
    BreakOverlayView()
        .frame(width: 800, height: 600)
}
```

### Verification
1. Build succeeds: `Cmd+B`
2. In Xcode, open the Preview (Canvas) for BreakOverlayView
3. Verify:
   - Dark gradient background with purple glow
   - Large timer display at center
   - "Look away. Blink. Breathe." message
   - Two buttons: "Snooze 5 min" and "Skip"
   - Keyboard hints at bottom

### Files Created
- `Blink/Views/BreakOverlayView.swift`

---

## Task 2.2: Create BreakOverlayWindowController

### Objective
Create the controller that manages NSWindow instances for each monitor.

### Instructions

1. **Create new file:**
   - Right-click on `Windows` group
   - New File → Swift File
   - Name: `BreakOverlayWindowController.swift`
   - Create

2. **Replace contents with:**

```swift
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
    /// - Parameter animated: Whether to animate the dismissal
    func hideOverlay(animated: Bool = true) {
        print("[OverlayController] Hiding overlay")

        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        for window in windows {
            if shouldAnimate {
                // Fade out animation
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    window.animator().alphaValue = 0
                } completionHandler: {
                    window.orderOut(nil)
                    window.close()
                }
            } else {
                // Instant hide
                window.orderOut(nil)
                window.close()
            }
        }

        windows.removeAll()
        keyWindow = nil
    }

    // MARK: - Private: Window Creation

    /// Create an overlay window for a specific screen
    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        // Create window covering the entire screen
        let window = NSWindow(
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

        // Allow window to become key for keyboard events
        window.canBecomeKey = true

        // Create hosting view with SwiftUI content
        let overlayView = BreakOverlayView()
        let hostingView = KeyableHostingView(rootView: overlayView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)

        window.contentView = hostingView

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
```

3. **Update BreakOverlayView to handle Esc notification:**
   - Open `Blink/Views/BreakOverlayView.swift`
   - Add the following to the body's ZStack, after the last Spacer:

```swift
.onReceive(NotificationCenter.default.publisher(for: .breakOverlayEscPressed)) { _ in
    handleEscKey()
}
```

The complete body should look like:

```swift
var body: some View {
    ZStack {
        // Background: Dark gradient
        backgroundGradient

        // Content: Timer, message, buttons
        VStack(spacing: 40) {
            Spacer()

            // Large countdown timer
            countdownTimer

            // Calming message
            messageText

            Spacer()

            // Snooze and Skip buttons
            buttonRow

            // Keyboard hints
            hintText

            Spacer()
                .frame(height: 60)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onReceive(NotificationCenter.default.publisher(for: .breakOverlayEscPressed)) { _ in
        handleEscKey()
    }
}
```

### Verification
1. Build succeeds: `Cmd+B`
2. No compiler errors or warnings

### Files Created
- `Blink/Windows/BreakOverlayWindowController.swift`

### Files Modified
- `Blink/Views/BreakOverlayView.swift` (added Esc notification handler)

---

## Task 2.3: Wire Overlay to AppState

### Objective
Connect AppState.isOverlayVisible to show/hide the overlay windows.

### Instructions

1. **Update BlinkApp.swift** to observe isOverlayVisible:
   - Open `Blink/BlinkApp.swift`
   - Replace ALL contents with:

```swift
import SwiftUI
import Combine

/// Main entry point for the Blink app
///
/// Blink runs as a menu bar-only app (no dock icon, no main window).
/// The MenuBarExtra displays the current timer and provides controls.
@main
struct BlinkApp: App {

    // MARK: - State Objects

    /// Observable app state - triggers UI updates
    @StateObject private var appState = AppState.shared

    /// Timer engine - must be retained to keep running
    @StateObject private var timerEngine = TimerEngine.shared

    /// Cancellables for Combine subscriptions
    @State private var cancellables = Set<AnyCancellable>()

    // MARK: - App Body

    var body: some Scene {
        // Menu bar extra shows timer in menu bar
        MenuBarExtra {
            MenuBarView()
        } label: {
            // Display the timer as text
            // Uses monospaced digits for stable width
            Text(appState.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.menu)
    }

    // MARK: - Initialization

    init() {
        // Start timer engine and setup overlay observation
        Task { @MainActor in
            print("[BlinkApp] Initializing")

            // Start timer engine
            TimerEngine.shared.start()

            // Observe overlay visibility changes
            setupOverlayObserver()
        }
    }

    // MARK: - Private

    /// Setup observer for isOverlayVisible changes
    @MainActor
    private func setupOverlayObserver() {
        AppState.shared.$isOverlayVisible
            .receive(on: DispatchQueue.main)
            .sink { isVisible in
                if isVisible {
                    print("[BlinkApp] Showing overlay")
                    BreakOverlayWindowController.shared.showOverlay()
                } else {
                    print("[BlinkApp] Hiding overlay")
                    BreakOverlayWindowController.shared.hideOverlay()
                }
            }
            .store(in: &BlinkAppStorage.shared.cancellables)
    }
}

// MARK: - Storage for Cancellables

/// Helper class to store cancellables (workaround for @State limitations in App)
final class BlinkAppStorage {
    static let shared = BlinkAppStorage()
    var cancellables = Set<AnyCancellable>()
    private init() {}
}
```

### Verification
1. Build succeeds: `Cmd+B`

2. **Test break overlay:**
   - For quick testing, temporarily change `workDurationMinutes` to 1 in Settings.swift
   - Run the app
   - Wait for timer to reach `01:00`
   - Break overlay should appear covering the entire screen
   - **IMPORTANT:** Change duration back to 25 after testing

3. **Test overlay appearance:**
   - Dark gradient background with purple glow
   - Large countdown timer (starts at 5:00 or your configured break duration)
   - "Look away. Blink. Breathe." message
   - Snooze and Skip buttons visible

4. **Test countdown:**
   - Timer should decrement every second
   - When it reaches 0:00, overlay should auto-dismiss
   - New work session should start (timer back to 00:00)

5. **Test Snooze button:**
   - Click "Snooze 5 min"
   - Overlay should fade out
   - After 5 minutes (or configured snooze duration), overlay should return

6. **Test Skip button:**
   - Trigger another break
   - Click "Skip"
   - Overlay should fade out
   - Work session should start (timer at 00:00)

7. **Test Esc key:**
   - Trigger another break
   - Press Esc once
   - Wait 500ms - should snooze

8. **Test double-Esc:**
   - Trigger another break
   - Press Esc twice quickly (within 500ms)
   - Should skip immediately (no wait)

### Files Modified
- `Blink/BlinkApp.swift`

---

## Task 2.4: Add Full Menu Bar Controls

### Objective
Add Pause/Resume, Restart, Start Break Now, and other controls to the menu.

### Instructions

1. **Update MenuBarView.swift:**
   - Open `Blink/Views/MenuBarView.swift`
   - Replace ALL contents with:

```swift
import SwiftUI

/// Menu bar dropdown content
///
/// Provides controls for the timer:
/// - Pause/Resume toggle
/// - Restart Session
/// - Start Break Now
/// - Quit
struct MenuBarView: View {

    // MARK: - State

    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared
    @ObservedObject private var settings = Settings.shared

    // MARK: - Body

    var body: some View {
        Group {
            // MARK: Timer Controls

            // Pause/Resume toggle
            pauseResumeButton

            // Restart session
            Button("Restart Session") {
                timerEngine.restartSession()
            }
            .keyboardShortcut("r", modifiers: [.command])

            // Start break now
            Button("Start Break Now") {
                timerEngine.startBreakNow()
            }
            .disabled(appState.timerState == .breakRunning || appState.timerState == .snoozeRunning)

            Divider()

            // MARK: Settings (placeholder for Milestone 3)

            Button("Settings...") {
                // Will be implemented in Milestone 3
                print("[MenuBarView] Settings clicked (not implemented yet)")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            // MARK: Launch at Login (placeholder for Milestone 3)

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    // Will be implemented in Milestone 3
                    print("[MenuBarView] Launch at Login: \(newValue) (not implemented yet)")
                }

            Divider()

            // MARK: Quit

            Button("Quit Blink") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    // MARK: - Pause/Resume Button

    private var pauseResumeButton: some View {
        let isPaused = appState.timerState == .workPaused
        let isBreak = appState.timerState == .breakRunning || appState.timerState == .snoozeRunning

        return Button(isPaused ? "Resume" : "Pause") {
            timerEngine.togglePause()
        }
        .keyboardShortcut("p", modifiers: [.command])
        .disabled(isBreak)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .frame(width: 200)
}
```

### Verification

1. Build and run: `Cmd+R`

2. **Test menu appearance:**
   - Click on timer in menu bar
   - Should see:
     - Pause (enabled)
     - Restart Session
     - Start Break Now
     - ---
     - Settings...
     - ---
     - Launch at Login toggle
     - ---
     - Quit Blink

3. **Test Pause/Resume:**
   - Click Pause - menu bar should show `⏸ XX:XX`
   - Timer should stop incrementing
   - Click Resume - timer should continue
   - Menu bar should show `XX:XX` (no pause symbol)

4. **Test Restart Session:**
   - Let timer run to 00:15 or so
   - Click Restart Session
   - Timer should reset to 00:00
   - Continue incrementing

5. **Test Start Break Now:**
   - Click Start Break Now
   - Break overlay should appear immediately
   - "Start Break Now" should be disabled during break

6. **Test disabled states:**
   - During break overlay:
     - Pause should be disabled
     - Start Break Now should be disabled
   - After skip/snooze:
     - All controls should re-enable appropriately

### Files Modified
- `Blink/Views/MenuBarView.swift`

---

## Task 2.5: Test Multi-Monitor Support

### Objective
Verify overlay appears correctly on multiple monitors.

### Instructions

This is a manual testing task. No code changes required.

### Testing Steps

If you have multiple monitors:

1. **Connect multiple monitors**

2. **Trigger break:**
   - Run the app
   - Either wait for timer or click "Start Break Now"

3. **Verify overlay on all screens:**
   - Each monitor should have its own overlay window
   - All overlays should show the same countdown
   - Dark gradient should cover entire screen on each monitor

4. **Test keyboard focus:**
   - Press Esc - should work regardless of which screen has mouse cursor

5. **Test display hot-plug:**
   - While overlay is visible, disconnect a monitor
   - Overlay should adjust (one less window)
   - Reconnect monitor
   - Overlay should appear on new monitor

If you only have one monitor:

1. **Trigger break and verify:**
   - Overlay covers entire screen
   - Appears above full-screen apps (test with a full-screen app running)

### Verification Checklist
- [ ] Overlay appears on all connected monitors
- [ ] Countdown is synchronized across all overlays
- [ ] Keyboard events work (Esc snooze/skip)
- [ ] Buttons work on any monitor
- [ ] Hot-plug works (if tested)

---

## Task 2.6: Test Full-Screen App Overlay

### Objective
Verify overlay appears above full-screen applications.

### Instructions

This is a manual testing task. No code changes required.

### Testing Steps

1. **Open a full-screen app:**
   - Open any app (Safari, Terminal, etc.)
   - Enter full-screen mode (green button or Ctrl+Cmd+F)

2. **Trigger break:**
   - Use "Start Break Now" or wait for timer

3. **Verify overlay appears:**
   - Overlay should appear ABOVE the full-screen app
   - Full-screen app should be completely hidden by overlay

4. **Test in different Spaces:**
   - Create multiple Spaces (Mission Control)
   - Have full-screen apps in different Spaces
   - Trigger break
   - Overlay should appear in ALL Spaces

### Troubleshooting

If overlay doesn't appear above full-screen apps:

1. Check window level in BreakOverlayWindowController:
   ```swift
   window.level = .screenSaver
   ```

2. Check collection behavior includes:
   ```swift
   window.collectionBehavior = [
       .canJoinAllSpaces,
       .fullScreenAuxiliary,
       .stationary
   ]
   ```

3. If still not working, try higher window level:
   ```swift
   window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
   ```

### Verification Checklist
- [ ] Overlay appears above full-screen apps
- [ ] Overlay appears in all Spaces
- [ ] Can snooze/skip while full-screen app is behind

---

## Milestone 2 Complete Checklist

Before moving to Milestone 3, verify ALL of the following:

### Break Overlay
- [ ] Overlay appears on all connected monitors
- [ ] Overlay has dark gradient with purple glow
- [ ] Large countdown timer visible and counting down
- [ ] "Look away. Blink. Breathe." message visible
- [ ] Snooze and Skip buttons visible and styled
- [ ] Keyboard hints visible at bottom
- [ ] Overlay appears above full-screen apps

### Snooze/Skip
- [ ] Single Esc snoozes (after 500ms delay)
- [ ] Double Esc skips immediately
- [ ] Snooze button works - overlay hides and returns after 5 min
- [ ] Skip button works - overlay hides and new session starts
- [ ] Fade animation on dismiss (or instant if Reduce Motion)

### Menu Controls
- [ ] Pause pauses the timer, shows ⏸ in menu bar
- [ ] Resume continues timer from paused value
- [ ] Restart Session resets to 00:00
- [ ] Start Break Now triggers overlay immediately
- [ ] Controls disabled appropriately during break
- [ ] Quit works

### Edge Cases
- [ ] Break auto-completes when countdown reaches 0
- [ ] Display connect/disconnect handled gracefully
- [ ] Timer continues after break/snooze correctly

### Files
All these files should exist and be working:
- `Blink/Views/BreakOverlayView.swift`
- `Blink/Windows/BreakOverlayWindowController.swift`
- `Blink/Views/MenuBarView.swift` (updated)
- `Blink/BlinkApp.swift` (updated)

---

## Next Milestone

Proceed to `references/milestone-3-tasks.md` for Settings, Shortcuts, and Polish.
