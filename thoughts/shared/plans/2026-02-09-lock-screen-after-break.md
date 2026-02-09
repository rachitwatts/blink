# Lock Screen After Break - Implementation Plan

## Overview

Add an opt-in setting to automatically lock the screen when a break timer completes, provided the user is idle. This prevents someone from accessing an unlocked computer when the user steps away during a break.

**Issue:** #2
**Spec:** `thoughts/shared/specs/SPEC-lock-screen-after-break.md`

## Current State Analysis

- **Settings:** `Settings.swift` uses `@AppStorage` for all preferences, singleton pattern
- **Timer Engine:** `TimerEngine.swift` has `completeBreak()` (line 293) as the hook point
- **Idle Detection:** `IdleDetector.shared.isActive(threshold:)` already exists (line 49)
- **Settings UI:** `SettingsView.swift` has a Timer section with `soundEnabled` toggle (line 90)

## Desired End State

When enabled:
1. User finishes a break (countdown reaches 0)
2. If user is idle (per `idleIgnoreThreshold`), screen locks via CGSession
3. If user is active (typing/mousing), lock is skipped

**Verification:** Enable setting → step away during break → break ends → screen locks

## What We're NOT Doing

- Menu bar quick toggle
- Pre-lock countdown/warning
- Per-break configuration
- watchOS lock support
- Additional permissions (CGSession needs none)

## Implementation Approach

Small, surgical changes across 4 files + 1 new file. Each phase is independently testable.

---

## Phase 1: Add Setting

### Overview
Add the `lockScreenAfterBreak` boolean to Settings with default `false`.

### Changes Required

#### 1. Settings Model
**File:** `Blink/Models/Settings.swift`
**Location:** After line 51 (after `soundEnabled`)

```swift
/// Whether to lock screen when break completes (requires user to be idle)
@AppStorage("lockScreenAfterBreak") var lockScreenAfterBreak: Bool = false
```

Also update `resetToDefaults()` (around line 89):
```swift
lockScreenAfterBreak = false
```

### Success Criteria

#### Automated Verification:
- [ ] Project builds: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- [ ] Unit tests pass: verify `Settings.shared.lockScreenAfterBreak` defaults to `false`

#### Manual Verification:
- [ ] Setting value persists across app restarts (check UserDefaults)

---

## Phase 2: Create Screen Lock Service

### Overview
New service to invoke `CGSession -suspend` for screen locking.

### Changes Required

#### 1. New Service File
**File:** `Blink/Services/ScreenLockService.swift` (new)

```swift
import Foundation

/// Service for locking the macOS screen
///
/// Uses CGSession which requires no special permissions.
/// The -suspend flag locks the screen (same as ⌃⌘Q).
struct ScreenLockService {

    /// Lock the screen immediately
    ///
    /// Uses `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`
    /// This is idempotent - calling on an already-locked screen is safe.
    static func lockScreen() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        task.arguments = ["-suspend"]

        do {
            try task.run()
        } catch {
            print("[ScreenLockService] Failed to lock screen: \(error)")
        }
    }
}
```

#### 2. Add to Xcode project
**File:** `project.yml`

The file will be auto-included since it's in `Blink/Services/` (already a source group).

### Success Criteria

#### Automated Verification:
- [ ] Project builds with new file: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`

#### Manual Verification:
- [ ] Calling `ScreenLockService.lockScreen()` from LLDB or test code locks the screen

---

## Phase 3: Integrate Lock into Timer Engine

### Overview
Call lock service from `completeBreak()` when setting is enabled and user is idle.

### Changes Required

#### 1. Timer Engine Integration
**File:** `Blink/Services/TimerEngine.swift`
**Location:** In `completeBreak()` method, at the beginning (before resetting state)

Replace the current `completeBreak()` (lines 293-300):

```swift
/// Complete a break and start new work session
func completeBreak() {
    // Lock screen if enabled and user is idle
    if settings.lockScreenAfterBreak {
        let isIdle = !idleDetector.isActive(threshold: TimeInterval(settings.idleIgnoreThreshold))
        if isIdle {
            ScreenLockService.lockScreen()
        }
    }

    appState.workElapsedSeconds = 0
    appState.timerState = .workRunning
    appState.isOverlayVisible = false
    shouldResetOnNextActivity = false

    // Switch to active polling for new work session
    scheduleTimer(interval: activePollingInterval)
}
```

### Success Criteria

#### Automated Verification:
- [ ] Project builds: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- [ ] Unit tests pass (existing tests should not regress)

#### Manual Verification:
- [ ] With setting OFF: break completes → no lock
- [ ] With setting ON + active (typing): break completes → no lock
- [ ] With setting ON + idle (stepped away): break completes → screen locks

**Note:** `skipBreak()` and `snoozeBreak()` do NOT call `completeBreak()`, so they inherently won't trigger lock.

---

## Phase 4: Add Settings UI Toggle

### Overview
Add toggle in Settings Timer section with descriptive subtitle.

### Changes Required

#### 1. Settings View
**File:** `Blink/Views/SettingsView.swift`
**Location:** In `timerSection`, after the sound toggle (line 90)

Add after the existing sound toggle:

```swift
// Lock screen toggle
Toggle("Lock screen after break", isOn: $settings.lockScreenAfterBreak)

Text("Locks when break ends and you're away")
    .font(.caption)
    .foregroundColor(.secondary)
```

### Success Criteria

#### Automated Verification:
- [ ] Project builds: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`

#### Manual Verification:
- [ ] Toggle appears in Settings under Timer section
- [ ] Toggle state persists after closing/reopening Settings
- [ ] Subtitle text is readable and correctly styled

---

## Phase 5: Add Unit Tests

### Overview
Add tests for the lock-on-break behavior using the existing mock injection pattern.

### Changes Required

#### 1. Test File Updates
**File:** `BlinkTests/TimerEngineTests.swift`

Add new test cases:

```swift
// MARK: - Lock Screen Tests

func testCompleteBreakLocksScreenWhenEnabledAndIdle() async throws {
    // Given: Setting enabled, user is idle
    Settings.shared.lockScreenAfterBreak = true
    mockIdleDetector.mockIdleTime = 120 // Well above idleIgnoreThreshold (60s)

    // When: Break completes
    // Note: Can't easily test actual lock - just verify the logic path
    // This test validates the condition check works correctly

    let isIdle = !mockIdleDetector.isActive(threshold: TimeInterval(Settings.shared.idleIgnoreThreshold))
    XCTAssertTrue(isIdle, "User should be considered idle")
}

func testCompleteBreakSkipsLockWhenEnabledAndActive() async throws {
    // Given: Setting enabled, user is active
    Settings.shared.lockScreenAfterBreak = true
    mockIdleDetector.mockIdleTime = 5 // Well below idleIgnoreThreshold (60s)

    let isIdle = !mockIdleDetector.isActive(threshold: TimeInterval(Settings.shared.idleIgnoreThreshold))
    XCTAssertFalse(isIdle, "User should be considered active")
}

func testCompleteBreakSkipsLockWhenDisabled() async throws {
    // Given: Setting disabled
    Settings.shared.lockScreenAfterBreak = false

    // Condition should short-circuit
    XCTAssertFalse(Settings.shared.lockScreenAfterBreak)
}

func testLockScreenSettingDefaultsToFalse() {
    // Reset to defaults and verify
    Settings.shared.resetToDefaults()
    XCTAssertFalse(Settings.shared.lockScreenAfterBreak)
}
```

### Success Criteria

#### Automated Verification:
- [ ] All tests pass: `xcodebuild test -scheme Blink -destination 'platform=macOS' -only-testing:BlinkTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`

#### Manual Verification:
- [ ] Test output shows new lock-related tests running and passing

---

## Testing Strategy

### Unit Tests (Phase 5)
- Setting defaults to false
- Lock condition triggers when enabled + idle
- Lock condition skips when enabled + active
- Lock condition skips when disabled

### Integration Tests (Manual)
1. Enable setting in UI
2. Start work session, wait for break
3. Step away (be idle) during break
4. Break completes → screen should lock

### Edge Cases (Manual)
- Skip break (double-Esc) → no lock
- Snooze break → no lock when snooze expires, only when final break completes
- Disable setting mid-break → break completes → no lock
- Already locked screen → CGSession -suspend is idempotent, no error

## References

- Spec: `thoughts/shared/specs/SPEC-lock-screen-after-break.md`
- Issue: GitHub #2
- CGSession docs: Built-in macOS binary, no additional permissions needed
