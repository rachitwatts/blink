# Lock Screen After Break - Tasks

**Goal:** Opt-in screen lock when break timer completes and user is idle
**Spec:** `thoughts/shared/specs/SPEC-lock-screen-after-break.md`
**Plan:** `thoughts/shared/plans/2026-02-09-lock-screen-after-break.md`

**Prerequisites:**
- On branch `claude/create-watch-app-nGCND` (or new feature branch)
- Existing Blink v1 codebase with TimerEngine, Settings, IdleDetector

**Estimated Tasks:** 5 tasks

---

## Task 1: Add lockScreenAfterBreak Setting

### Objective
Add a new `@AppStorage` boolean to `Settings` for opting into screen lock after break.

### Instructions

1. **Edit `Blink/Models/Settings.swift`**

2. **Add property** in the `// MARK: - Feature Toggles` section, after `soundEnabled`:

```swift
/// Whether to lock screen when break completes (requires user to be idle)
@AppStorage("lockScreenAfterBreak") var lockScreenAfterBreak: Bool = false
```

3. **Update `resetToDefaults()`** — add inside the method:

```swift
lockScreenAfterBreak = false
```

### Verification
- Build succeeds: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- `Settings.shared.lockScreenAfterBreak` defaults to `false`
- After `resetToDefaults()`, value is `false`

### Files Modified
- `Blink/Models/Settings.swift`

---

## Task 2: Create ScreenLockService

### Objective
Create a new service that locks the macOS screen using CGSession.

### Instructions

1. **Create new file:** `Blink/Services/ScreenLockService.swift`

2. **Contents:**

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

### Verification
- Build succeeds: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- File is auto-included via XcodeGen (lives in `Blink/Services/`)

### Files Created
- `Blink/Services/ScreenLockService.swift`

---

## Task 3: Integrate Lock into TimerEngine

### Objective
Call `ScreenLockService.lockScreen()` from `completeBreak()` when the setting is enabled and the user is idle.

### Instructions

1. **Edit `Blink/Services/TimerEngine.swift`**

2. **Replace `completeBreak()` method** (currently at line 293) with:

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

### Verification
- Build succeeds: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- Existing unit tests still pass: `xcodebuild test -scheme Blink -destination 'platform=macOS' -only-testing:BlinkTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- Confirm `skipBreak()` and `snoozeBreak()` do NOT call `completeBreak()` (no lock on skip/snooze)

### Files Modified
- `Blink/Services/TimerEngine.swift`

---

## Task 4: Add Settings UI Toggle

### Objective
Add a toggle and subtitle text in the Settings Timer section for the lock screen feature.

### Instructions

1. **Edit `Blink/Views/SettingsView.swift`**

2. **In `timerSection`**, after the sound toggle (`Toggle("Play sound when break starts", ...)`), add:

```swift
// Lock screen toggle
Toggle("Lock screen after break", isOn: $settings.lockScreenAfterBreak)

Text("Locks when break ends and you're away")
    .font(.caption)
    .foregroundColor(.secondary)
```

### Verification
- Build succeeds: `xcodegen generate && xcodebuild build -scheme Blink -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- Run app → open Settings → Toggle appears under "Play sound when break starts"
- Toggle state persists after closing and reopening Settings
- Subtitle text renders correctly below the toggle

### Files Modified
- `Blink/Views/SettingsView.swift`

---

## Task 5: Add Unit Tests

### Objective
Add tests verifying the lock-on-break logic for all combinations of setting state and user activity.

### Instructions

1. **Edit `BlinkTests/TimerEngineTests.swift`**

2. **Add test cases** in a new `// MARK: - Lock Screen Tests` section:

```swift
// MARK: - Lock Screen Tests

func testCompleteBreakLocksScreenWhenEnabledAndIdle() async throws {
    // Given: Setting enabled, user is idle
    Settings.shared.lockScreenAfterBreak = true
    mockIdleDetector.mockIdleTime = 120 // Well above idleIgnoreThreshold (60s)

    // Verify the condition evaluates correctly
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

### Verification
- All tests pass: `xcodebuild test -scheme Blink -destination 'platform=macOS' -only-testing:BlinkTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- New lock-related tests appear in test output
- Existing tests are not broken

### Files Modified
- `BlinkTests/TimerEngineTests.swift`

---

## Completion Checklist

Before marking this feature as done, verify ALL of the following:

- [ ] `lockScreenAfterBreak` setting defaults to `false`
- [ ] `resetToDefaults()` resets the new setting
- [ ] `ScreenLockService.lockScreen()` calls CGSession -suspend
- [ ] `completeBreak()` locks screen when setting ON + user idle
- [ ] `completeBreak()` skips lock when setting ON + user active
- [ ] `completeBreak()` skips lock when setting OFF
- [ ] `skipBreak()` never triggers lock
- [ ] `snoozeBreak()` never triggers lock
- [ ] Settings UI toggle appears in Timer section
- [ ] Toggle persists across Settings open/close
- [ ] All new unit tests pass
- [ ] All existing unit tests still pass
- [ ] App builds with no warnings

### Manual Testing

- [ ] Enable setting → let break complete while away → screen locks
- [ ] Enable setting → let break complete while typing → screen stays unlocked
- [ ] Disable setting → break completes → no lock regardless
