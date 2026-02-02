# Milestone 1: Core Foundation

**Goal:** Working timer in menu bar with idle-aware logic

**Prerequisites:**
- macOS 14+ (Sonoma)
- Xcode 15+
- No existing code (greenfield)

**Estimated Tasks:** 8 tasks

---

## Task 1.1: Create Xcode Project

### Objective
Create a new macOS SwiftUI app project with the correct configuration.

### Instructions

1. **Open Xcode** and select "Create New Project"

2. **Choose template:**
   - Platform: macOS
   - Application: App
   - Click Next

3. **Configure project:**
   - Product Name: `Blink`
   - Team: Your Apple Developer Team (or None for now)
   - Organization Identifier: `com.yourname` (replace with your identifier)
   - Bundle Identifier: Will auto-generate as `com.yourname.Blink`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None
   - Include Tests: YES (check the box)
   - Click Next

4. **Save location:**
   - Navigate to the `blink` repository root directory
   - Save the project there (creates `Blink/` folder with `Blink.xcodeproj`)

5. **Configure deployment target:**
   - In Xcode, select the Blink project in the navigator
   - Select the "Blink" target
   - Go to "General" tab
   - Set "Minimum Deployments" → macOS 14.0

6. **Configure app category:**
   - Still in "General" tab
   - Set "App Category" → Utilities

7. **Remove default window scene:**
   - Open `BlinkApp.swift`
   - Delete ALL existing content
   - Replace with this minimal starter:

```swift
import SwiftUI

@main
struct BlinkApp: App {
    var body: some Scene {
        MenuBarExtra("Blink", systemImage: "clock") {
            Text("Blink is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

8. **Disable main window:**
   - Open `Info.plist` (or go to target → Info tab)
   - Add key: `Application is agent (UIElement)` = `YES`
   - This makes the app a menu bar-only app (no dock icon)

### Verification

1. Build the project: `Cmd+B` - should succeed with no errors
2. Run the project: `Cmd+R`
3. Verify:
   - No app window appears
   - No dock icon appears
   - Menu bar shows a clock icon
   - Clicking it shows "Blink is running" and "Quit"
   - Clicking "Quit" closes the app

### Files Created
- `Blink/Blink.xcodeproj`
- `Blink/BlinkApp.swift`
- `Blink/Assets.xcassets/`
- `Blink/Preview Content/`
- `BlinkTests/BlinkTests.swift`

---

## Task 1.2: Create Directory Structure

### Objective
Create the organized folder structure for the project.

### Instructions

1. **In Xcode's Project Navigator**, right-click on the "Blink" folder (the one containing BlinkApp.swift)

2. **Create Groups** (right-click → New Group) for each of these:
   - `Models`
   - `Services`
   - `Views`
   - `Windows`

3. **Verify structure looks like:**
```
Blink/
├── BlinkApp.swift
├── Models/
├── Services/
├── Views/
├── Windows/
├── Assets.xcassets/
└── Preview Content/
```

4. **Ensure groups are folders on disk:**
   - For each group, right-click → "Convert to Group"
   - Or when creating, ensure "New Group" creates actual folder

### Verification
- In Finder, navigate to `Blink/Blink/` and verify the folders exist
- Project builds successfully: `Cmd+B`

### Files Created
- `Blink/Models/` (empty folder)
- `Blink/Services/` (empty folder)
- `Blink/Views/` (empty folder)
- `Blink/Windows/` (empty folder)

---

## Task 1.3: Create TimerState Model

### Objective
Define the enum representing all possible timer states.

### Instructions

1. **Create new file:**
   - Right-click on `Models` group
   - New File → Swift File
   - Name: `TimerState.swift`
   - Ensure target "Blink" is checked
   - Create

2. **Replace contents with:**

```swift
import Foundation

/// Represents the current state of the Blink timer
enum TimerState: String, Equatable, CaseIterable {
    /// User is working, timer counting up
    case workRunning

    /// User paused the timer manually
    case workPaused

    /// Break overlay is visible, timer counting down
    case breakRunning

    /// Break was snoozed, overlay hidden, timer counting down to re-show
    case snoozeRunning

    /// Human-readable description for debugging
    var description: String {
        switch self {
        case .workRunning: return "Working"
        case .workPaused: return "Paused"
        case .breakRunning: return "Break"
        case .snoozeRunning: return "Snoozed"
        }
    }

    /// Whether the timer should be actively counting
    var isActive: Bool {
        switch self {
        case .workRunning, .breakRunning, .snoozeRunning:
            return true
        case .workPaused:
            return false
        }
    }

    /// Whether the break overlay should be visible
    var shouldShowOverlay: Bool {
        self == .breakRunning
    }
}
```

### Verification
- Build succeeds: `Cmd+B`
- No compiler warnings or errors

### Files Created
- `Blink/Models/TimerState.swift`

---

## Task 1.4: Create Settings Model

### Objective
Create the Settings class that persists user preferences using @AppStorage.

### Instructions

1. **Create new file:**
   - Right-click on `Models` group
   - New File → Swift File
   - Name: `Settings.swift`
   - Create

2. **Replace contents with:**

```swift
import Foundation
import SwiftUI

/// Display mode for the menu bar timer
enum DisplayMode: String, CaseIterable, Identifiable {
    case elapsed = "elapsed"
    case remaining = "remaining"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .elapsed: return "Elapsed"
        case .remaining: return "Remaining"
        }
    }
}

/// Centralized settings storage using UserDefaults via @AppStorage
///
/// Usage: Access via `Settings.shared` singleton
/// All properties automatically persist to UserDefaults
final class Settings: ObservableObject {

    // MARK: - Singleton

    static let shared = Settings()

    // MARK: - Timer Durations (in minutes, stored as Int)

    /// Work session duration in minutes (default: 25)
    @AppStorage("workDurationMinutes") var workDurationMinutes: Int = 25

    /// Break duration in minutes (default: 5)
    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5

    /// Snooze duration in minutes (default: 5)
    @AppStorage("snoozeDurationMinutes") var snoozeDurationMinutes: Int = 5

    // MARK: - Idle Thresholds (in seconds)

    /// Idle time below this is treated as "still working" (reading, thinking)
    /// Default: 60 seconds
    @AppStorage("idleIgnoreThreshold") var idleIgnoreThreshold: Int = 60

    /// Idle time at or above this triggers session reset on return
    /// Default: 300 seconds (5 minutes)
    @AppStorage("idleResetThreshold") var idleResetThreshold: Int = 300

    // MARK: - Display Settings

    /// How to display time in menu bar: "elapsed" or "remaining"
    @AppStorage("displayMode") private var displayModeRaw: String = DisplayMode.elapsed.rawValue

    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .elapsed }
        set { displayModeRaw = newValue.rawValue }
    }

    // MARK: - Feature Toggles

    /// Whether to play sound when break starts
    @AppStorage("soundEnabled") var soundEnabled: Bool = false

    /// Whether to launch app at login
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = true

    /// Whether user has completed first-launch onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // MARK: - Computed Properties (seconds)

    /// Work duration in seconds
    var workDurationSeconds: Int {
        workDurationMinutes * 60
    }

    /// Break duration in seconds
    var breakDurationSeconds: Int {
        breakDurationMinutes * 60
    }

    /// Snooze duration in seconds
    var snoozeDurationSeconds: Int {
        snoozeDurationMinutes * 60
    }

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Reset

    /// Reset all settings to defaults (useful for testing)
    func resetToDefaults() {
        workDurationMinutes = 25
        breakDurationMinutes = 5
        snoozeDurationMinutes = 5
        idleIgnoreThreshold = 60
        idleResetThreshold = 300
        displayModeRaw = DisplayMode.elapsed.rawValue
        soundEnabled = false
        launchAtLogin = true
        hasCompletedOnboarding = false
    }
}
```

### Verification
- Build succeeds: `Cmd+B`
- No compiler warnings or errors

### Files Created
- `Blink/Models/Settings.swift`

---

## Task 1.5: Create AppState Model

### Objective
Create the observable AppState class that holds all runtime state.

### Instructions

1. **Create new file:**
   - Right-click on `Models` group
   - New File → Swift File
   - Name: `AppState.swift`
   - Create

2. **Replace contents with:**

```swift
import Foundation
import SwiftUI
import Combine

/// Central observable state for the entire app
///
/// Usage: Access via `AppState.shared` singleton
/// All @Published properties trigger UI updates automatically
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Timer State

    /// Current state of the timer state machine
    @Published var timerState: TimerState = .workRunning

    /// Seconds elapsed in current work session (0 to workDurationSeconds)
    @Published var workElapsedSeconds: Int = 0

    /// Seconds remaining in current break (breakDurationSeconds to 0)
    @Published var breakRemainingSeconds: Int = 0

    /// Seconds remaining in snooze period (snoozeDurationSeconds to 0)
    @Published var snoozeRemainingSeconds: Int = 0

    // MARK: - UI State

    /// Whether the break overlay windows should be visible
    @Published var isOverlayVisible: Bool = false

    /// Whether the settings window is currently shown
    @Published var isSettingsVisible: Bool = false

    // MARK: - Dependencies

    /// Reference to settings for computing display values
    let settings = Settings.shared

    // MARK: - Computed Properties

    /// The time to display based on current state and display mode
    var displayTime: String {
        switch timerState {
        case .workRunning, .workPaused:
            // During work, show either elapsed or remaining based on settings
            let seconds: Int
            if settings.displayMode == .elapsed {
                seconds = workElapsedSeconds
            } else {
                seconds = max(0, settings.workDurationSeconds - workElapsedSeconds)
            }
            return formatTime(seconds)

        case .breakRunning:
            // During break, always show remaining time
            return formatTime(breakRemainingSeconds)

        case .snoozeRunning:
            // During snooze, show snooze remaining (overlay is hidden)
            return formatTime(snoozeRemainingSeconds)
        }
    }

    /// Full menu bar title including pause indicator
    var menuBarTitle: String {
        switch timerState {
        case .workPaused:
            return "⏸ \(displayTime)"
        default:
            return displayTime
        }
    }

    /// Progress through current work session (0.0 to 1.0)
    var workProgress: Double {
        guard settings.workDurationSeconds > 0 else { return 0 }
        return Double(workElapsedSeconds) / Double(settings.workDurationSeconds)
    }

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Helpers

    /// Format seconds as "mm:ss" string
    /// - Parameter totalSeconds: Total seconds to format
    /// - Returns: Formatted string like "05:32" or "125:00" for > 99 minutes
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes >= 100 {
            // Handle overflow case (> 99:59)
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Reset

    /// Reset all state to initial values (useful for testing)
    func reset() {
        timerState = .workRunning
        workElapsedSeconds = 0
        breakRemainingSeconds = 0
        snoozeRemainingSeconds = 0
        isOverlayVisible = false
        isSettingsVisible = false
    }
}
```

### Verification
- Build succeeds: `Cmd+B`
- No compiler warnings or errors

### Files Created
- `Blink/Models/AppState.swift`

---

## Task 1.6: Create IdleDetector Service

### Objective
Create the service that polls system idle time using CGEventSource.

### Instructions

1. **Create new file:**
   - Right-click on `Services` group
   - New File → Swift File
   - Name: `IdleDetector.swift`
   - Create

2. **Replace contents with:**

```swift
import Foundation
import CoreGraphics

/// Service for detecting system-wide idle time
///
/// Idle time is measured as seconds since last keyboard/mouse/trackpad input.
/// Uses CGEventSource which requires no special permissions.
///
/// Usage: `IdleDetector.shared.getIdleTime()`
final class IdleDetector {

    // MARK: - Singleton

    static let shared = IdleDetector()

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Public API

    /// Get the current system-wide idle time in seconds
    ///
    /// This measures time since last HID (Human Interface Device) event,
    /// which includes keyboard, mouse, and trackpad input.
    ///
    /// - Returns: Seconds since last user input (as TimeInterval/Double)
    func getIdleTime() -> TimeInterval {
        // CGEventType(rawValue: ~0) means "any event type"
        // .hidSystemState gives us system-wide idle time
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .hidSystemState,
            eventType: CGEventType(rawValue: ~0)!
        )
        return idleTime
    }

    /// Check if user is currently considered "active" based on idle threshold
    ///
    /// - Parameter threshold: Seconds of idle time below which user is "active"
    /// - Returns: true if user has had input within the threshold
    func isActive(threshold: TimeInterval) -> Bool {
        return getIdleTime() < threshold
    }

    /// Check if user has been idle long enough to reset session
    ///
    /// - Parameter threshold: Seconds of idle time at which session should reset
    /// - Returns: true if user has been idle at or beyond the threshold
    func shouldResetSession(threshold: TimeInterval) -> Bool {
        return getIdleTime() >= threshold
    }
}
```

### Verification
1. Build succeeds: `Cmd+B`
2. Run the app: `Cmd+R`
3. In Xcode debugger or by adding a temporary print statement:
   - `IdleDetector.shared.getIdleTime()` should return a small number (< 1) right after input
   - Wait a few seconds without touching anything, call again - should return higher number

### Files Created
- `Blink/Services/IdleDetector.swift`

---

## Task 1.7: Create TimerEngine Service

### Objective
Create the core timer engine with idle-aware logic and adaptive polling.

### Instructions

1. **Create new file:**
   - Right-click on `Services` group
   - New File → Swift File
   - Name: `TimerEngine.swift`
   - Create

2. **Replace contents with:**

```swift
import Foundation
import Combine
import AppKit

/// Core timer engine that manages the work/break cycle
///
/// Responsibilities:
/// - Polls system idle time at adaptive intervals (1Hz active, 5s idle)
/// - Implements idle-aware work time tracking
/// - Manages state transitions (work → break → snooze → work)
/// - Updates AppState which triggers UI updates
///
/// Usage: Call `TimerEngine.shared.start()` when app launches
@MainActor
final class TimerEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = TimerEngine()

    // MARK: - Dependencies

    private let appState = AppState.shared
    private let settings = Settings.shared
    private let idleDetector = IdleDetector.shared

    // MARK: - Timer State

    private var timer: Timer?

    /// Flag to reset work elapsed to 0 when user returns from long idle
    private var shouldResetOnNextActivity: Bool = false

    // MARK: - Adaptive Polling

    /// Polling interval when user is active (1 second)
    private let activePollingInterval: TimeInterval = 1.0

    /// Polling interval when user is idle (5 seconds to save battery)
    private let idlePollingInterval: TimeInterval = 5.0

    /// Current polling interval
    private var currentPollingInterval: TimeInterval = 1.0

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Public API: Lifecycle

    /// Start the timer engine
    /// Call this once when the app launches
    func start() {
        guard timer == nil else {
            print("[TimerEngine] Already running, ignoring start()")
            return
        }
        print("[TimerEngine] Starting with \(activePollingInterval)s interval")
        scheduleTimer(interval: activePollingInterval)
    }

    /// Stop the timer engine
    /// Call this when the app is quitting
    func stop() {
        print("[TimerEngine] Stopping")
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Public API: Actions

    /// Toggle between paused and running states
    func togglePause() {
        switch appState.timerState {
        case .workRunning:
            print("[TimerEngine] Pausing")
            appState.timerState = .workPaused

        case .workPaused:
            print("[TimerEngine] Resuming")
            appState.timerState = .workRunning

        case .breakRunning, .snoozeRunning:
            // Cannot pause during break or snooze
            print("[TimerEngine] Cannot toggle pause in state: \(appState.timerState)")
        }
    }

    /// Restart the work session from zero
    func restartSession() {
        print("[TimerEngine] Restarting session")
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    /// Manually trigger a break (Start Break Now)
    func startBreakNow() {
        guard appState.timerState == .workRunning || appState.timerState == .workPaused else {
            print("[TimerEngine] Cannot start break in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Starting break now (manual)")
        triggerBreak()
    }

    /// Snooze the current break
    func snoozeBreak() {
        guard appState.timerState == .breakRunning else {
            print("[TimerEngine] Cannot snooze in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Snoozing break for \(settings.snoozeDurationMinutes) minutes")
        appState.snoozeRemainingSeconds = settings.snoozeDurationSeconds
        appState.timerState = .snoozeRunning
        appState.isOverlayVisible = false
    }

    /// Skip the current break and start a new work session
    func skipBreak() {
        guard appState.timerState == .breakRunning || appState.timerState == .snoozeRunning else {
            print("[TimerEngine] Cannot skip in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Skipping break, starting new session")
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    // MARK: - Private: Timer Management

    /// Schedule the timer with the given interval
    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentPollingInterval = interval

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        // Ensure timer runs even when menu is open
        RunLoop.current.add(timer!, forMode: .common)
    }

    /// Called every tick - the heart of the timer logic
    private func tick() {
        switch appState.timerState {
        case .workRunning:
            handleWorkRunningTick()

        case .workPaused:
            // Do nothing - timer is paused
            // But still check idle for adaptive polling
            updatePollingInterval(forIdleTime: idleDetector.getIdleTime())

        case .breakRunning:
            handleBreakRunningTick()

        case .snoozeRunning:
            handleSnoozeRunningTick()
        }
    }

    // MARK: - Private: State-Specific Tick Handlers

    /// Handle a tick while in WorkRunning state
    private func handleWorkRunningTick() {
        let idleSeconds = idleDetector.getIdleTime()
        let idleIgnore = TimeInterval(settings.idleIgnoreThreshold)
        let idleReset = TimeInterval(settings.idleResetThreshold)

        // Update polling interval based on idle state
        updatePollingInterval(forIdleTime: idleSeconds)

        // Idle handling logic - the core of Blink's intelligence
        if idleSeconds < idleIgnore {
            // ACTIVE or SHORT IDLE (reading/thinking)
            // Treat as active work - count this time

            // Check if returning from long idle
            if shouldResetOnNextActivity {
                print("[TimerEngine] Returning from long idle, resetting session")
                appState.workElapsedSeconds = 0
                shouldResetOnNextActivity = false
            }

            // Increment work time
            // Note: We add the polling interval, not just 1 second
            // This handles the adaptive polling correctly
            appState.workElapsedSeconds += Int(currentPollingInterval)

        } else if idleSeconds < idleReset {
            // MEDIUM IDLE (stepped away temporarily)
            // Don't count this time, but don't reset either
            // The timer effectively "pauses" without changing state
            // No action needed - we just don't increment

        } else {
            // LONG IDLE (away for extended period)
            // Will reset session when user returns
            if !shouldResetOnNextActivity {
                print("[TimerEngine] Long idle detected (\(Int(idleSeconds))s), will reset on return")
                shouldResetOnNextActivity = true
            }
        }

        // Check if work duration reached - trigger break
        if appState.workElapsedSeconds >= settings.workDurationSeconds {
            print("[TimerEngine] Work duration reached (\(appState.workElapsedSeconds)s), triggering break")
            triggerBreak()
        }
    }

    /// Handle a tick while in BreakRunning state
    private func handleBreakRunningTick() {
        if appState.breakRemainingSeconds > 0 {
            appState.breakRemainingSeconds -= 1
        } else {
            // Break complete
            print("[TimerEngine] Break complete, starting new session")
            completeBreak()
        }
    }

    /// Handle a tick while in SnoozeRunning state
    private func handleSnoozeRunningTick() {
        if appState.snoozeRemainingSeconds > 0 {
            appState.snoozeRemainingSeconds -= 1
        } else {
            // Snooze expired - show break overlay again
            print("[TimerEngine] Snooze expired, showing break overlay")
            triggerBreak()
        }
    }

    // MARK: - Private: State Transitions

    /// Trigger a break - show overlay and start countdown
    private func triggerBreak() {
        appState.breakRemainingSeconds = settings.breakDurationSeconds
        appState.timerState = .breakRunning
        appState.isOverlayVisible = true

        // Play sound if enabled
        if settings.soundEnabled {
            playBreakSound()
        }

        // Switch to active polling during break (for countdown accuracy)
        scheduleTimer(interval: activePollingInterval)
    }

    /// Complete a break and start new work session
    private func completeBreak() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    // MARK: - Private: Adaptive Polling

    /// Update polling interval based on current idle time
    private func updatePollingInterval(forIdleTime idleSeconds: TimeInterval) {
        let idleIgnore = TimeInterval(settings.idleIgnoreThreshold)

        // Use slower polling when idle to save battery
        let targetInterval = idleSeconds >= idleIgnore ? idlePollingInterval : activePollingInterval

        if targetInterval != currentPollingInterval {
            print("[TimerEngine] Switching to \(targetInterval)s polling interval")
            scheduleTimer(interval: targetInterval)
        }
    }

    // MARK: - Private: Sound

    /// Play the break notification sound
    private func playBreakSound() {
        // Use system sound "Glass" - a gentle chime
        NSSound(named: "Glass")?.play()
    }
}
```

### Verification
1. Build succeeds: `Cmd+B`
2. No compiler warnings or errors

### Files Created
- `Blink/Services/TimerEngine.swift`

---

## Task 1.8: Update BlinkApp and Create Menu Bar View

### Objective
Wire everything together - start the timer engine and show the timer in the menu bar.

### Instructions

1. **Create MenuBarView:**
   - Right-click on `Views` group
   - New File → Swift File
   - Name: `MenuBarView.swift`
   - Replace contents with:

```swift
import SwiftUI

/// Menu bar dropdown content
/// Shows controls when user clicks the timer in menu bar
struct MenuBarView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared

    var body: some View {
        // For now, just show basic info and quit
        // Full controls will be added in Milestone 2

        Group {
            // Show current state for debugging
            Text("State: \(appState.timerState.description)")
                .foregroundColor(.secondary)

            Text("Work: \(appState.workElapsedSeconds)s")
                .foregroundColor(.secondary)

            Divider()

            Button("Quit Blink") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

#Preview {
    MenuBarView()
}
```

2. **Update BlinkApp.swift:**
   - Open `BlinkApp.swift`
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
        // Start timer engine when app launches
        // Using Task to ensure we're on MainActor
        Task { @MainActor in
            print("[BlinkApp] Starting timer engine")
            TimerEngine.shared.start()
        }
    }
}
```

### Verification

1. **Build and run:** `Cmd+R`

2. **Verify initial state:**
   - Menu bar shows `00:00`
   - Clicking shows dropdown with "State: Working"

3. **Test timer incrementing:**
   - Move your mouse or type on keyboard
   - Watch menu bar timer increment: `00:01`, `00:02`, etc.
   - Timer should update every second

4. **Test idle pause (60s threshold):**
   - Stop all input for 60+ seconds
   - Watch the timer - it should STOP incrementing after 60s of idle
   - Resume input - timer should continue from where it was

5. **Test idle reset (300s threshold):**
   - For quick testing, temporarily change `idleResetThreshold` to 10 seconds in Settings.swift
   - Stop input for 10+ seconds
   - Resume input - timer should reset to `00:00`
   - **IMPORTANT:** Change the threshold back to 300 after testing

6. **Test break trigger:**
   - For quick testing, temporarily change `workDurationMinutes` to 1 in Settings.swift
   - Wait for timer to reach `01:00`
   - Timer should trigger break (state changes to Break)
   - Console should show "[TimerEngine] Work duration reached..."
   - **Note:** Overlay won't show yet - that's Milestone 2
   - **IMPORTANT:** Change the duration back to 25 after testing

7. **Test quit:**
   - Click Quit Blink in menu
   - App should exit cleanly

### Files Modified
- `Blink/BlinkApp.swift`

### Files Created
- `Blink/Views/MenuBarView.swift`

---

## Milestone 1 Complete Checklist

Before moving to Milestone 2, verify ALL of the following:

- [ ] App launches without errors
- [ ] Menu bar shows `00:00` initially
- [ ] Timer increments during activity
- [ ] Timer uses monospaced digits (width doesn't jump)
- [ ] Timer pauses when idle 60-300s
- [ ] Timer resets when idle >= 300s then return
- [ ] Console shows adaptive polling messages
- [ ] Quit menu item works
- [ ] No compiler warnings
- [ ] All files exist in correct locations:
  - `Blink/Models/TimerState.swift`
  - `Blink/Models/Settings.swift`
  - `Blink/Models/AppState.swift`
  - `Blink/Services/IdleDetector.swift`
  - `Blink/Services/TimerEngine.swift`
  - `Blink/Views/MenuBarView.swift`
  - `Blink/BlinkApp.swift`

---

## Next Milestone

Proceed to `references/milestone-2-tasks.md` for Break Overlay and Menu Controls.
