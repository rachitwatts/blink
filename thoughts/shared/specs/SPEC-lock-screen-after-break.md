# SPEC: Lock Screen After Break

**Issue:** #2
**Status:** Draft
**Date:** 2026-02-09

## Overview

When a break timer finishes, automatically lock the screen so the user can step away without worrying about their system being accessible. The feature is opt-in via a Settings toggle.

## User Flow

1. User enables "Lock screen after break" in Settings (default: off)
2. Work timer expires → break overlay appears (existing behavior)
3. Break countdown reaches 0 → `completeBreak()` fires
4. Before resetting to work state, check:
   - Is `lockScreenAfterBreak` enabled?
   - Is the user currently idle? (reuse existing `IdleDetector` with `idleIgnoreThreshold`)
5. If enabled AND user is idle → lock the screen
6. If enabled AND user is active → skip the lock (user is at their desk)
7. Transition to work state as normal

## Requirements

### Must Have (MVP)

- **Settings toggle:** "Lock screen after break" (Bool, default `false`)
- **Lock mechanism:** `CGSession` via `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`
- **Activity check:** Reuse `IdleDetector.shared.isActive(threshold:)` with `settings.idleIgnoreThreshold` — if user has been active within the threshold, skip the lock
- **No warning:** Lock happens immediately when break ends (no countdown/notification)

### Won't Have (out of scope)

- Menu bar quick toggle
- Pre-lock countdown/warning
- Per-break lock configuration
- watchOS lock support

## Technical Design

### 1. Settings Model (`Settings.swift`)

Add one new property:

```swift
@AppStorage("lockScreenAfterBreak") var lockScreenAfterBreak: Bool = false
```

### 2. Screen Lock Service (`ScreenLockService.swift`)

New file in `Blink/Services/`:

```swift
struct ScreenLockService {
    static func lockScreen() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        task.arguments = ["-suspend"]
        try? task.run()
    }
}
```

### 3. Timer Engine Integration (`TimerEngine.swift`)

In `completeBreak()`, before resetting state:

```swift
if settings.lockScreenAfterBreak {
    let isIdle = !idleDetector.isActive(threshold: TimeInterval(settings.idleIgnoreThreshold))
    if isIdle {
        ScreenLockService.lockScreen()
    }
}
```

### 4. Settings View (`SettingsView.swift`)

Add toggle in the existing settings sections (near "Sound" or in a new "After Break" section):

```swift
Toggle("Lock screen after break", isOn: $settings.lockScreenAfterBreak)
```

Subtitle text: "Locks screen when break ends and you're away from your desk"

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| User skips break (double-Esc) | No lock — `completeBreak()` not called via skip path, goes through `skipBreak()` |
| User snoozes break | No lock — snooze doesn't call `completeBreak()` |
| User is actively typing when break ends | No lock — activity detected, lock skipped |
| Break ends on locked screen (already locked) | CGSession -suspend is idempotent, no harm |
| Setting toggled mid-break | Uses current value at time `completeBreak()` fires |

## Files to Modify

| File | Change |
|------|--------|
| `Blink/Models/Settings.swift` | Add `lockScreenAfterBreak` property |
| `Blink/Services/ScreenLockService.swift` | **New file** — lock screen via CGSession |
| `Blink/Services/TimerEngine.swift` | Call lock in `completeBreak()` |
| `Blink/Views/SettingsView.swift` | Add toggle |
| `BlinkTests/` | Add tests for lock-on-break logic |

## Testing Strategy

### Unit Tests
- `completeBreak()` calls lock when setting enabled + user idle
- `completeBreak()` skips lock when setting enabled + user active
- `completeBreak()` skips lock when setting disabled
- `skipBreak()` never triggers lock
- `snoozeBreak()` never triggers lock
- Setting default is `false`

### Manual Tests
- Enable setting → let break complete while away → screen locks
- Enable setting → let break complete while typing → screen stays unlocked
- Disable setting → break completes → no lock regardless

## Open Questions

None — all decisions resolved during interview.

## References

- Plan: `references/lock-screen-after-break-plan.md`
- Tasks: `references/lock-screen-after-break-tasks.md`
