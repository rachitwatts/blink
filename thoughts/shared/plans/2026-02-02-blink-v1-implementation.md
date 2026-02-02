# Blink v1 Implementation Plan

## Overview

Implement Blink, a macOS menu bar eye-break app that enforces 25-minute work / 5-minute break cycles with intelligent idle detection and full-screen break overlays across all monitors.

## Current State Analysis

**Starting Point:** Greenfield project - no existing code.

**Target Platform:** macOS 14+ (Sonoma), SwiftUI, direct distribution (notarized)

**Key Technical Decisions (from interview):**
- Adaptive polling: 1Hz when active, 5s when idle (battery optimization)
- Menu bar: Time only display (icon in dropdown menu)
- Settings: Popover from menu bar, changes apply immediately
- Overlay: Dark with soft glow, grabs focus immediately, subtle fade animation
- Permissions: Lazy request (only when shortcuts are used)
- Break during sleep: Auto-complete if elapsed time >= break duration
- VoiceOver: Deferred to later version, chime suffices for v1
- Dependencies: Minimal SPM allowed (for hotkey handling if needed)
- Onboarding: Single welcome window on first launch
- Auto-update: Deferred to v1.1

## Desired End State

A fully functional macOS menu bar app that:
1. Displays elapsed work time in the menu bar
2. Tracks activity via system idle time with intelligent thresholds
3. Shows full-screen break overlay on ALL monitors when 25 minutes of work is reached
4. Supports Snooze (single Esc) and Skip (double Esc within 500ms)
5. Provides Settings popover for work/break duration customization
6. Launches at login by default
7. Offers global shortcuts for pause/resume and restart (with lazy permission request)

**Verification:**
- App launches and appears in menu bar
- Timer increments during activity, pauses during 60-300s idle, resets after 300s idle
- Break overlay covers all connected monitors, appears above full-screen apps
- Snooze hides overlay for 5 minutes, Skip starts new session
- Settings persist across launches
- Launch at login works correctly

## What We're NOT Doing

- No VoiceOver accessibility beyond basic labels (deferred)
- No auto-update (Sparkle deferred to v1.1)
- No micro-nudges (v2 feature)
- No suppression during calls/recording (v2/v3 feature)
- No camera-based posture detection (v3 feature)
- No analytics or crash reporting
- No state persistence across quits (fresh start on launch)

## Implementation Approach

**Phased approach:** Build core functionality first, then UI layers, then polish.

1. **Phase 1:** Project setup and core models
2. **Phase 2:** Timer engine with idle detection
3. **Phase 3:** Menu bar UI
4. **Phase 4:** Break overlay (multi-monitor)
5. **Phase 5:** Settings popover
6. **Phase 6:** Global shortcuts and launch at login
7. **Phase 7:** Onboarding and polish
8. **Phase 8:** Testing and notarization

---

## Phase 1: Project Setup and Core Models

### Overview
Create Xcode project structure, define core data models and state management.

### Changes Required:

#### 1. Create Xcode Project

Create a new macOS App project with SwiftUI:
- **Product Name:** Blink
- **Bundle Identifier:** com.yourname.blink (replace with actual)
- **Deployment Target:** macOS 14.0
- **Include Tests:** Yes (BlinkTests target)

#### 2. Project Structure

Create the following directory structure:
```
Blink/
├── BlinkApp.swift
├── Models/
│   ├── TimerState.swift
│   ├── AppState.swift
│   └── Settings.swift
├── Services/
│   ├── TimerEngine.swift
│   ├── IdleDetector.swift
│   ├── SuppressionProvider.swift
│   └── HotkeyManager.swift
├── Views/
│   ├── MenuBarView.swift
│   ├── BreakOverlayView.swift
│   ├── SettingsView.swift
│   └── OnboardingView.swift
├── Windows/
│   └── BreakOverlayWindowController.swift
├── Resources/
│   └── Assets.xcassets
└── BlinkTests/
    ├── TimerEngineTests.swift
    └── IdleDetectorTests.swift
```

#### 3. TimerState.swift

**File:** `Blink/Models/TimerState.swift`

```swift
import Foundation

enum TimerState: Equatable {
    case workRunning
    case workPaused
    case breakRunning
    case snoozeRunning
}
```

#### 4. Settings.swift

**File:** `Blink/Models/Settings.swift`

```swift
import Foundation
import SwiftUI

enum DisplayMode: String, CaseIterable {
    case elapsed
    case remaining
}

final class Settings: ObservableObject {
    static let shared = Settings()

    @AppStorage("workDurationMinutes") var workDurationMinutes: Int = 25
    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5
    @AppStorage("snoozeDurationMinutes") var snoozeDurationMinutes: Int = 5
    @AppStorage("idleIgnoreThreshold") var idleIgnoreThreshold: Int = 60
    @AppStorage("idleResetThreshold") var idleResetThreshold: Int = 300
    @AppStorage("displayMode") var displayModeRaw: String = DisplayMode.elapsed.rawValue
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .elapsed }
        set { displayModeRaw = newValue.rawValue }
    }

    var workDurationSeconds: Int { workDurationMinutes * 60 }
    var breakDurationSeconds: Int { breakDurationMinutes * 60 }
    var snoozeDurationSeconds: Int { snoozeDurationMinutes * 60 }

    private init() {}
}
```

#### 5. AppState.swift

**File:** `Blink/Models/AppState.swift`

```swift
import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var timerState: TimerState = .workRunning
    @Published var workElapsedSeconds: Int = 0
    @Published var breakRemainingSeconds: Int = 0
    @Published var snoozeRemainingSeconds: Int = 0

    @Published var isOverlayVisible: Bool = false
    @Published var isSettingsVisible: Bool = false

    let settings = Settings.shared

    var displayTime: String {
        switch timerState {
        case .workRunning, .workPaused:
            let seconds = settings.displayMode == .elapsed
                ? workElapsedSeconds
                : max(0, settings.workDurationSeconds - workElapsedSeconds)
            return formatTime(seconds)
        case .breakRunning:
            return formatTime(breakRemainingSeconds)
        case .snoozeRunning:
            return formatTime(snoozeRemainingSeconds)
        }
    }

    var menuBarTitle: String {
        switch timerState {
        case .workPaused:
            return "⏸ \(displayTime)"
        default:
            return displayTime
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private init() {}
}
```

#### 6. BlinkApp.swift (Initial)

**File:** `Blink/BlinkApp.swift`

```swift
import SwiftUI

@main
struct BlinkApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Text(appState.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.menu)
    }
}
```

### Success Criteria:

#### Automated Verification:
- [ ] Project builds without errors: `xcodebuild -scheme Blink build`
- [ ] All files exist in correct locations
- [ ] No compiler warnings

#### Manual Verification:
- [ ] App launches and shows "00:00" in menu bar
- [ ] Menu bar text uses monospaced digits

**Implementation Note:** After completing this phase, pause for manual verification before proceeding.

---

## Phase 2: Timer Engine with Idle Detection

### Overview
Implement the core timer logic with idle-aware behavior and adaptive polling.

### Changes Required:

#### 1. IdleDetector.swift

**File:** `Blink/Services/IdleDetector.swift`

```swift
import Foundation
import CoreGraphics

final class IdleDetector {
    static let shared = IdleDetector()

    /// Returns system-wide idle time in seconds
    func getIdleTime() -> TimeInterval {
        // Get time since last HID event (keyboard/mouse/trackpad)
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .hidSystemState,
            eventType: CGEventType(rawValue: ~0)!
        )
        return idleTime
    }

    private init() {}
}
```

#### 2. SuppressionProvider.swift

**File:** `Blink/Services/SuppressionProvider.swift`

```swift
import Foundation

/// Interface for detecting suppression conditions (calls, screen sharing, etc.)
/// v1: Always returns false. Implement actual detection in v2/v3.
protocol SuppressionProviding {
    func shouldSuppress() -> Bool
    func suppressionReason() -> String?
}

final class SuppressionProvider: SuppressionProviding {
    static let shared = SuppressionProvider()

    func shouldSuppress() -> Bool {
        // v1: No suppression logic
        return false
    }

    func suppressionReason() -> String? {
        return nil
    }

    private init() {}
}
```

#### 3. TimerEngine.swift

**File:** `Blink/Services/TimerEngine.swift`

```swift
import Foundation
import Combine

@MainActor
final class TimerEngine: ObservableObject {
    static let shared = TimerEngine()

    private var timer: Timer?
    private var shouldResetOnNextActivity: Bool = false
    private var lastIdleTime: TimeInterval = 0

    private let appState = AppState.shared
    private let settings = Settings.shared
    private let idleDetector = IdleDetector.shared
    private let suppressionProvider = SuppressionProvider.shared

    // Adaptive polling intervals
    private let activePollingInterval: TimeInterval = 1.0
    private let idlePollingInterval: TimeInterval = 5.0
    private var currentPollingInterval: TimeInterval = 1.0

    private init() {}

    func start() {
        guard timer == nil else { return }
        scheduleTimer(interval: activePollingInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentPollingInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        // Check suppression
        if suppressionProvider.shouldSuppress() {
            return
        }

        let idleSeconds = idleDetector.getIdleTime()

        switch appState.timerState {
        case .workRunning:
            handleWorkRunningTick(idleSeconds: idleSeconds)

        case .workPaused:
            // Do nothing - timer is paused
            break

        case .breakRunning:
            handleBreakRunningTick()

        case .snoozeRunning:
            handleSnoozeRunningTick()
        }

        lastIdleTime = idleSeconds
    }

    private func handleWorkRunningTick(idleSeconds: TimeInterval) {
        let idleIgnore = TimeInterval(settings.idleIgnoreThreshold)
        let idleReset = TimeInterval(settings.idleResetThreshold)

        // Adaptive polling: switch to slower polling when idle
        let targetInterval = idleSeconds >= idleIgnore ? idlePollingInterval : activePollingInterval
        if targetInterval != currentPollingInterval {
            scheduleTimer(interval: targetInterval)
        }

        switch true {
        case idleSeconds < idleIgnore:
            // Active or short idle (reading/thinking) - count toward session
            if shouldResetOnNextActivity {
                // Returning from long idle - reset
                appState.workElapsedSeconds = 0
                shouldResetOnNextActivity = false
            }
            appState.workElapsedSeconds += Int(currentPollingInterval)

        case idleSeconds < idleReset:
            // Medium idle - don't count (effective pause)
            // No increment, keep shouldResetOnNextActivity as-is
            break

        default:
            // Long idle - will reset on return
            shouldResetOnNextActivity = true
        }

        // Check if break is due
        if appState.workElapsedSeconds >= settings.workDurationSeconds {
            triggerBreak()
        }
    }

    private func handleBreakRunningTick() {
        if appState.breakRemainingSeconds > 0 {
            appState.breakRemainingSeconds -= 1
        } else {
            completeBreak()
        }
    }

    private func handleSnoozeRunningTick() {
        if appState.snoozeRemainingSeconds > 0 {
            appState.snoozeRemainingSeconds -= 1
        } else {
            // Snooze expired - show overlay again
            triggerBreak()
        }
    }

    // MARK: - Actions

    func triggerBreak() {
        appState.breakRemainingSeconds = settings.breakDurationSeconds
        appState.timerState = .breakRunning
        appState.isOverlayVisible = true

        // Play sound if enabled
        if settings.soundEnabled {
            playBreakSound()
        }

        // Switch to active polling during break
        scheduleTimer(interval: activePollingInterval)
    }

    func snoozeBreak() {
        appState.snoozeRemainingSeconds = settings.snoozeDurationSeconds
        appState.timerState = .snoozeRunning
        appState.isOverlayVisible = false
    }

    func skipBreak() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    func completeBreak() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    func togglePause() {
        switch appState.timerState {
        case .workRunning:
            appState.timerState = .workPaused
        case .workPaused:
            appState.timerState = .workRunning
        default:
            break
        }
    }

    func restartSession() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    func startBreakNow() {
        triggerBreak()
    }

    private func playBreakSound() {
        NSSound(named: "Glass")?.play()
    }
}
```

#### 4. Update BlinkApp.swift

**File:** `Blink/BlinkApp.swift`

```swift
import SwiftUI

@main
struct BlinkApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var timerEngine = TimerEngine.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Text(appState.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.menu)
    }

    init() {
        // Start timer engine when app launches
        Task { @MainActor in
            TimerEngine.shared.start()
        }
    }
}
```

### Success Criteria:

#### Automated Verification:
- [ ] Project builds without errors
- [ ] Unit tests pass for TimerEngine (to be written in Phase 8)

#### Manual Verification:
- [ ] Timer increments in menu bar during active use
- [ ] Timer pauses display when idle for 60+ seconds
- [ ] Timer resets to 00:00 after 5+ minutes of idle

**Implementation Note:** For quick testing, temporarily set `workDurationMinutes = 1` to trigger break faster.

---

## Phase 3: Menu Bar UI

### Overview
Implement the menu bar dropdown with all controls.

### Changes Required:

#### 1. MenuBarView.swift

**File:** `Blink/Views/MenuBarView.swift`

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        Group {
            // Pause/Resume toggle
            Button(appState.timerState == .workPaused ? "Resume" : "Pause") {
                timerEngine.togglePause()
            }
            .disabled(appState.timerState == .breakRunning || appState.timerState == .snoozeRunning)

            Button("Restart Session") {
                timerEngine.restartSession()
            }

            Button("Start Break Now") {
                timerEngine.startBreakNow()
            }
            .disabled(appState.timerState == .breakRunning)

            Divider()

            Button("Settings...") {
                appState.isSettingsVisible = true
            }

            Divider()

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setEnabled(newValue)
                }

            Divider()

            Button("Quit Blink") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
```

#### 2. LaunchAtLoginManager (helper)

**File:** `Blink/Services/LaunchAtLoginManager.swift`

```swift
import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private init() {}

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
```

### Success Criteria:

#### Automated Verification:
- [ ] Project builds without errors

#### Manual Verification:
- [ ] Clicking menu bar shows dropdown menu
- [ ] Pause/Resume toggles correctly
- [ ] Restart Session resets timer to 00:00
- [ ] Start Break Now triggers break overlay
- [ ] Launch at Login toggle persists across app restart

---

## Phase 4: Break Overlay (Multi-Monitor)

### Overview
Implement full-screen break overlay that appears on all connected monitors.

### Changes Required:

#### 1. BreakOverlayView.swift

**File:** `Blink/Views/BreakOverlayView.swift`

```swift
import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared

    @State private var lastEscTime: Date?
    private let doubleEscWindow: TimeInterval = 0.5

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Dark gradient background with soft glow
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Soft glow effect
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Large countdown timer
                Text(formatTime(appState.breakRemainingSeconds))
                    .font(.system(size: 72, weight: .light, design: .monospaced))
                    .foregroundColor(.white)

                // Message
                Text("Look away. Blink. Breathe.")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                // Buttons
                HStack(spacing: 30) {
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                            timerEngine.snoozeBreak()
                        }
                    }) {
                        Text("Snooze 5 min")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)

                    Button(action: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                            timerEngine.skipBreak()
                        }
                    }) {
                        Text("Skip")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Hint text
                Text("Esc = Snooze 5 min  \u{2022}  Esc Esc = Skip")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
                    .frame(height: 60)
            }
        }
        .onKeyPress(.escape) {
            handleEsc()
            return .handled
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func handleEsc() {
        let now = Date()
        if let lastTime = lastEscTime,
           now.timeIntervalSince(lastTime) < doubleEscWindow {
            // Double Esc - Skip
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                timerEngine.skipBreak()
            }
            lastEscTime = nil
        } else {
            // First Esc - wait for potential second
            lastEscTime = now
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleEscWindow) { [self] in
                if lastEscTime != nil {
                    // No second Esc - Snooze
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        timerEngine.snoozeBreak()
                    }
                    lastEscTime = nil
                }
            }
        }
    }
}
```

#### 2. BreakOverlayWindowController.swift

**File:** `Blink/Windows/BreakOverlayWindowController.swift`

```swift
import AppKit
import SwiftUI

final class BreakOverlayWindowController {
    static let shared = BreakOverlayWindowController()

    private var windows: [NSWindow] = []
    private var displayObserver: Any?

    private init() {
        // Observe display configuration changes
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if AppState.shared.isOverlayVisible {
                self?.updateWindows()
            }
        }
    }

    deinit {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func showOverlay() {
        hideOverlay() // Clear any existing windows

        for screen in NSScreen.screens {
            let window = createWindow(for: screen)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        // Ensure at least one window has focus for keyboard events
        windows.first?.makeKey()
    }

    func hideOverlay() {
        for window in windows {
            if let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
               reduceMotion {
                window.close()
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    window.animator().alphaValue = 0
                } completionHandler: {
                    window.close()
                }
            }
        }
        windows.removeAll()
    }

    private func updateWindows() {
        // Refresh windows when display configuration changes
        showOverlay()
    }

    private func createWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        // Set SwiftUI content
        let hostingView = NSHostingView(rootView: BreakOverlayView())
        hostingView.frame = screen.frame
        window.contentView = hostingView

        // Fade in animation (respect reduce motion)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            window.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                window.animator().alphaValue = 1
            }
        }

        return window
    }
}
```

#### 3. Update BlinkApp.swift for Overlay

**File:** `Blink/BlinkApp.swift`

```swift
import SwiftUI
import Combine

@main
struct BlinkApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var timerEngine = TimerEngine.shared

    private var overlayController = BreakOverlayWindowController.shared
    private var cancellables = Set<AnyCancellable>()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Text(appState.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.menu)
    }

    init() {
        // Start timer engine when app launches
        Task { @MainActor in
            TimerEngine.shared.start()

            // Observe overlay visibility changes
            AppState.shared.$isOverlayVisible
                .receive(on: DispatchQueue.main)
                .sink { isVisible in
                    if isVisible {
                        BreakOverlayWindowController.shared.showOverlay()
                    } else {
                        BreakOverlayWindowController.shared.hideOverlay()
                    }
                }
                .store(in: &Self.cancellables)
        }
    }

    private static var cancellables = Set<AnyCancellable>()
}
```

### Success Criteria:

#### Automated Verification:
- [ ] Project builds without errors

#### Manual Verification:
- [ ] Break overlay appears on ALL connected monitors when break triggers
- [ ] Overlay appears above full-screen applications
- [ ] Single Esc snoozes (after 500ms delay)
- [ ] Double Esc skips immediately
- [ ] Snooze/Skip buttons work
- [ ] Overlay fades in/out (unless Reduce Motion enabled)
- [ ] Countdown timer decrements correctly
- [ ] Overlay auto-dismisses when countdown reaches 0

**Implementation Note:** Test with multiple monitors if available. Test with a full-screen app running.

---

## Phase 5: Settings Popover

### Overview
Implement Settings popover accessible from menu bar.

### Changes Required:

#### 1. SettingsView.swift

**File:** `Blink/Views/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)

            Divider()

            // General Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Timer")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Work duration")
                    Spacer()
                    Stepper(
                        "\(settings.workDurationMinutes) min",
                        value: $settings.workDurationMinutes,
                        in: 1...60
                    )
                }

                HStack {
                    Text("Break duration")
                    Spacer()
                    Stepper(
                        "\(settings.breakDurationMinutes) min",
                        value: $settings.breakDurationMinutes,
                        in: 1...30
                    )
                }

                HStack {
                    Text("Display mode")
                    Spacer()
                    Picker("", selection: $settings.displayModeRaw) {
                        Text("Elapsed").tag(DisplayMode.elapsed.rawValue)
                        Text("Remaining").tag(DisplayMode.remaining.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Toggle("Sound on break", isOn: $settings.soundEnabled)
            }

            Divider()

            // Advanced Settings
            DisclosureGroup("Advanced") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Idle ignore threshold")
                        Spacer()
                        Stepper(
                            "\(settings.idleIgnoreThreshold)s",
                            value: $settings.idleIgnoreThreshold,
                            in: 30...120
                        )
                    }

                    HStack {
                        Text("Idle reset threshold")
                        Spacer()
                        Stepper(
                            "\(settings.idleResetThreshold)s",
                            value: $settings.idleResetThreshold,
                            in: 120...600,
                            step: 30
                        )
                    }

                    Text("Idle under \(settings.idleIgnoreThreshold)s counts as active. Idle over \(settings.idleResetThreshold)s resets the session.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .frame(width: 320, height: 340)
    }
}
```

#### 2. Update MenuBarView for Settings Popover

We need to use a different approach since MenuBarExtra doesn't support popovers well. We'll use NSPopover.

**File:** `Blink/Views/SettingsPopoverController.swift`

```swift
import AppKit
import SwiftUI

final class SettingsPopoverController {
    static let shared = SettingsPopoverController()

    private var popover: NSPopover?

    private init() {}

    func show(relativeTo positioningRect: NSRect? = nil) {
        if popover == nil {
            let popover = NSPopover()
            popover.contentViewController = NSHostingController(rootView: SettingsView())
            popover.behavior = .transient
            self.popover = popover
        }

        guard let popover = popover else { return }

        if popover.isShown {
            popover.close()
        } else {
            // Find the menu bar item's view to anchor the popover
            if let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength).button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    func close() {
        popover?.close()
    }
}
```

Actually, let's simplify this. Since we're using MenuBarExtra with `.menu` style, we can open a separate window for settings.

**File:** `Blink/Windows/SettingsWindowController.swift`

```swift
import AppKit
import SwiftUI

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func showSettings() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Blink Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 320, height: 340))
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

#### 3. Update MenuBarView

**File:** `Blink/Views/MenuBarView.swift`

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var timerEngine = TimerEngine.shared
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        Group {
            // Pause/Resume toggle
            Button(appState.timerState == .workPaused ? "Resume" : "Pause") {
                timerEngine.togglePause()
            }
            .disabled(appState.timerState == .breakRunning || appState.timerState == .snoozeRunning)

            Button("Restart Session") {
                timerEngine.restartSession()
            }

            Button("Start Break Now") {
                timerEngine.startBreakNow()
            }
            .disabled(appState.timerState == .breakRunning)

            Divider()

            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }

            Divider()

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.shared.setEnabled(newValue)
                }

            Divider()

            Button("Quit Blink") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
```

### Success Criteria:

#### Automated Verification:
- [ ] Project builds without errors

#### Manual Verification:
- [ ] Settings window opens when clicking "Settings..."
- [ ] Work/break duration steppers work
- [ ] Display mode toggle switches correctly
- [ ] Sound toggle works
- [ ] Advanced section expands/collapses
- [ ] Idle threshold steppers work
- [ ] Changes apply immediately (no save button needed)
- [ ] Settings persist after app restart

---

## Phase 6: Global Shortcuts and Launch at Login

### Overview
Implement global keyboard shortcuts for pause/resume and restart, with lazy permission request.

### Changes Required:

#### 1. HotkeyManager.swift

**File:** `Blink/Services/HotkeyManager.swift`

```swift
import AppKit
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventMonitor: Any?
    private var hasRequestedPermission = false

    // Fixed shortcuts for v1
    // Cmd+Shift+B = Toggle Pause/Resume
    // Cmd+Shift+R = Restart Session

    private init() {}

    func startListening() {
        guard eventMonitor == nil else { return }

        // Check if we have accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted && !hasRequestedPermission {
            // Don't prompt immediately - wait for first shortcut attempt
            return
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    func stopListening() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func requestPermissionIfNeeded() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            startListening()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]

        guard flags == requiredFlags else { return }

        Task { @MainActor in
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "b":
                // Cmd+Shift+B = Toggle Pause/Resume
                TimerEngine.shared.togglePause()
            case "r":
                // Cmd+Shift+R = Restart Session
                TimerEngine.shared.restartSession()
            default:
                break
            }
        }
    }
}
```

#### 2. Update Settings to show shortcut hints

**File:** `Blink/Views/SettingsView.swift` (add at bottom of view)

Add a section showing keyboard shortcuts:

```swift
// Add after Advanced disclosure group:

Divider()

VStack(alignment: .leading, spacing: 8) {
    Text("Keyboard Shortcuts")
        .font(.subheadline)
        .foregroundColor(.secondary)

    HStack {
        Text("Pause/Resume")
        Spacer()
        Text("⌘⇧B")
            .foregroundColor(.secondary)
    }

    HStack {
        Text("Restart Session")
        Spacer()
        Text("⌘⇧R")
            .foregroundColor(.secondary)
    }

    if !AXIsProcessTrusted() {
        Button("Enable Shortcuts") {
            HotkeyManager.shared.requestPermissionIfNeeded()
        }
        .font(.caption)
    }
}
```

#### 3. Update BlinkApp to initialize HotkeyManager

**File:** `Blink/BlinkApp.swift`

Add to init():

```swift
// Start hotkey manager (lazy permission)
HotkeyManager.shared.startListening()
```

### Success Criteria:

#### Automated Verification:
- [ ] Project builds without errors

#### Manual Verification:
- [ ] Without Accessibility permission: shortcuts don't work (graceful degradation)
- [ ] Settings shows "Enable Shortcuts" button when permission not granted
- [ ] Clicking "Enable Shortcuts" shows system permission dialog
- [ ] After granting permission: Cmd+Shift+B toggles pause
- [ ] After granting permission: Cmd+Shift+R restarts session
- [ ] Launch at Login toggle works (verify in System Settings > Login Items)

---

## Phase 7: Onboarding and Polish

### Overview
Add first-launch onboarding and UI polish.

### Changes Required:

#### 1. OnboardingView.swift

**File:** `Blink/Views/OnboardingView.swift`

```swift
import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var settings = Settings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "eye")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Welcome to Blink")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Blink helps you take regular breaks to reduce eye strain and headaches.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(
                    icon: "clock",
                    title: "25/5 Rhythm",
                    description: "Work for 25 minutes, take a 5-minute break"
                )

                OnboardingFeatureRow(
                    icon: "display",
                    title: "Gentle Reminder",
                    description: "Full-screen overlay reminds you to look away"
                )

                OnboardingFeatureRow(
                    icon: "keyboard",
                    title: "Easy Controls",
                    description: "Press Esc to snooze, double-Esc to skip"
                )
            }
            .padding(.vertical)

            Button(action: {
                settings.hasCompletedOnboarding = true
                dismiss()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(width: 400, height: 500)
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

#### 2. OnboardingWindowController.swift

**File:** `Blink/Windows/OnboardingWindowController.swift`

```swift
import AppKit
import SwiftUI

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private init() {}

    func showIfNeeded() {
        guard !Settings.shared.hasCompletedOnboarding else { return }
        show()
    }

    func show() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Blink"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 500))
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

#### 3. Update BlinkApp for onboarding

**File:** `Blink/BlinkApp.swift`

Add to init():

```swift
// Show onboarding if first launch
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    OnboardingWindowController.shared.showIfNeeded()
}
```

#### 4. Add App Icon

Create simple app icon for menu bar and dock:

**File:** `Blink/Resources/Assets.xcassets/AppIcon.appiconset`

For v1, use SF Symbol "eye" as placeholder. Later, design a proper icon.

#### 5. Polish: Add menu bar icon

Update BlinkApp to show icon instead of (or alongside) time:

Currently we show time only. For polish, we could add a small indicator. This is optional for v1.

### Success Criteria:

#### Automated Verification:
- [ ] Project builds without errors

#### Manual Verification:
- [ ] First launch shows onboarding window
- [ ] Clicking "Get Started" dismisses onboarding
- [ ] Subsequent launches do not show onboarding
- [ ] App icon appears in menu bar

---

## Phase 8: Testing and Notarization

### Overview
Write tests, create notarization workflow.

### Changes Required:

#### 1. TimerEngineTests.swift

**File:** `BlinkTests/TimerEngineTests.swift`

```swift
import XCTest
@testable import Blink

@MainActor
final class TimerEngineTests: XCTestCase {

    var appState: AppState!

    override func setUp() async throws {
        appState = AppState.shared
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
    }

    func testInitialState() {
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
    }

    func testPauseResume() {
        let engine = TimerEngine.shared

        XCTAssertEqual(appState.timerState, .workRunning)

        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workPaused)

        engine.togglePause()
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testRestartSession() {
        let engine = TimerEngine.shared

        appState.workElapsedSeconds = 600
        engine.restartSession()

        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertEqual(appState.timerState, .workRunning)
    }

    func testSkipBreak() {
        let engine = TimerEngine.shared

        engine.triggerBreak()
        XCTAssertEqual(appState.timerState, .breakRunning)
        XCTAssertTrue(appState.isOverlayVisible)

        engine.skipBreak()
        XCTAssertEqual(appState.timerState, .workRunning)
        XCTAssertEqual(appState.workElapsedSeconds, 0)
        XCTAssertFalse(appState.isOverlayVisible)
    }

    func testSnoozeBreak() {
        let engine = TimerEngine.shared

        engine.triggerBreak()
        XCTAssertEqual(appState.timerState, .breakRunning)

        engine.snoozeBreak()
        XCTAssertEqual(appState.timerState, .snoozeRunning)
        XCTAssertFalse(appState.isOverlayVisible)
        XCTAssertEqual(appState.snoozeRemainingSeconds, Settings.shared.snoozeDurationSeconds)
    }
}
```

#### 2. IdleDetectorTests.swift

**File:** `BlinkTests/IdleDetectorTests.swift`

```swift
import XCTest
@testable import Blink

final class IdleDetectorTests: XCTestCase {

    func testIdleTimeReturnsValue() {
        let detector = IdleDetector.shared
        let idleTime = detector.getIdleTime()

        // Idle time should be non-negative
        XCTAssertGreaterThanOrEqual(idleTime, 0)
    }
}
```

#### 3. Notarization Setup

Create a notarization script (manual process):

**File:** `scripts/notarize.sh`

```bash
#!/bin/bash
# Notarization script for Blink
# Prerequisites:
# - Xcode configured with Developer ID certificate
# - Apple ID with app-specific password stored in Keychain

APP_NAME="Blink"
BUNDLE_ID="com.yourname.blink"
TEAM_ID="YOUR_TEAM_ID"

# Build for release
xcodebuild -scheme "$APP_NAME" -configuration Release archive -archivePath "build/$APP_NAME.xcarchive"

# Export notarized app
xcodebuild -exportArchive -archivePath "build/$APP_NAME.xcarchive" -exportOptionsPlist ExportOptions.plist -exportPath "build/export"

# Create DMG (optional)
# hdiutil create -volname "$APP_NAME" -srcfolder "build/export/$APP_NAME.app" -ov -format UDZO "build/$APP_NAME.dmg"

echo "Build complete. App is at build/export/$APP_NAME.app"
```

**File:** `ExportOptions.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

### Success Criteria:

#### Automated Verification:
- [ ] All unit tests pass: `xcodebuild test -scheme Blink -destination 'platform=macOS'`
- [ ] Project builds for release without errors

#### Manual Verification:
- [ ] Run complete manual testing checklist (below)

### Manual Testing Checklist

1. **Basic Timer Flow**
   - [ ] App launches with 00:00 in menu bar
   - [ ] Timer increments while typing/clicking
   - [ ] Timer reaches 25:00 and triggers break overlay

2. **Idle Detection**
   - [ ] Idle < 60s: timer continues
   - [ ] Idle 60-300s: timer pauses (doesn't increment)
   - [ ] Idle > 300s then return: timer resets to 00:00

3. **Break Overlay**
   - [ ] Overlay appears on ALL monitors
   - [ ] Overlay appears above full-screen apps
   - [ ] Countdown timer works correctly
   - [ ] Single Esc snoozes (5 min delay)
   - [ ] Double Esc skips immediately
   - [ ] Snooze/Skip buttons work
   - [ ] Auto-dismiss at countdown end

4. **Menu Bar Controls**
   - [ ] Pause pauses the timer
   - [ ] Resume resumes from paused time
   - [ ] Restart Session resets to 00:00
   - [ ] Start Break Now triggers break

5. **Settings**
   - [ ] Settings window opens
   - [ ] Duration changes take effect immediately
   - [ ] Display mode toggle works
   - [ ] Settings persist after restart

6. **Global Shortcuts**
   - [ ] Cmd+Shift+B toggles pause (after permission)
   - [ ] Cmd+Shift+R restarts session (after permission)

7. **Launch at Login**
   - [ ] Toggle persists
   - [ ] App launches at login when enabled

8. **Edge Cases**
   - [ ] Connect/disconnect external monitor
   - [ ] Sleep/wake during work session
   - [ ] Sleep/wake during break

---

## Testing Strategy

### Unit Tests
- Timer state machine transitions
- Idle detection (mock idle time for boundary testing)
- Settings persistence

### Integration Tests
- Timer + overlay coordination
- Settings changes apply to timer

### Manual Testing
- Multi-monitor overlay
- Full-screen app overlay
- Sleep/wake behavior
- Global shortcuts with permissions

---

## Performance Considerations

- Adaptive polling (1Hz active, 5Hz idle) to reduce battery drain
- Single NSWindow per monitor (not recreated on every tick)
- Combine publishers for reactive state updates
- No unnecessary redraws (SwiftUI handles this well)

---

## References

- Original PRD: `references/prd.md`
- Feature Spec: `thoughts/shared/specs/SPEC-blink-v1.md`
- Apple HIG: Menu Bar Apps, Full-Screen Windows
- SwiftUI Documentation: MenuBarExtra, NSWindow
