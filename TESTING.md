# Blink Test Strategy

This document outlines the testing approach for the Blink app.

## Quick Start

```bash
# Run all automated tests
./scripts/run-tests.sh

# Run specific test suites
./scripts/run-tests.sh unit    # Unit tests only
./scripts/run-tests.sh apple   # AppleScript integration tests only
```

## Test Suites

### 1. Unit Tests (BlinkTests)

**Location:** `BlinkTests/`

**Run with:** `./scripts/run-tests.sh unit`

Unit tests verify core logic in isolation without UI interaction.

| Test File | Coverage |
|-----------|----------|
| `SettingsTests.swift` | Default values, duration calculations, reset functionality |
| `TimerEngineTests.swift` | Timer state machine, pause/resume, break triggers, snooze/skip |

**What's tested:**
- Settings model defaults and persistence
- Work/break duration calculations
- Timer state transitions (working → break → working)
- Pause/resume during work periods
- Cannot pause during breaks
- Snooze extends break by configured duration
- Skip ends break immediately
- Restart resets timer to zero
- Menu bar title formatting (elapsed vs remaining)

### 2. AppleScript Integration Tests

**Location:** `scripts/test-helpers/`

**Run with:** `./scripts/run-tests.sh apple`

These tests interact with the running app via AppleScript to verify end-to-end functionality.

**Prerequisites:**
- Blink must be running (script auto-launches if needed)
- Terminal needs Accessibility permission (System Settings → Privacy & Security → Accessibility)

| Test | Verifies |
|------|----------|
| Menu bar shows timer | Timer displays in MM:SS format |
| Pause functionality | Clicking Pause shows ⏸ prefix |
| Resume functionality | Clicking Resume removes ⏸ prefix |
| Restart session | Timer resets to 00:00 |
| Settings window | Settings opens and closes |
| Start break now | Break overlay appears on demand |
| Skip break | Double-Esc dismisses overlay |
| Timer increments | Timer advances over time |

**Helper Scripts:**
- `blink-menu.applescript` — Menu bar interactions (status, pause, resume, restart, settings, start-break)
- `blink-overlay.applescript` — Break overlay interactions (check visibility, skip, snooze)
- `blink-settings.applescript` — Settings window interactions (check, close)
- `check-permissions.sh` — Verify accessibility permissions

### 3. Manual Tests

Some functionality requires manual verification:

#### Menu Bar
- [ ] Timer appears in menu bar after launch
- [ ] Clicking timer opens menu dropdown
- [ ] Menu items are properly enabled/disabled based on state

#### Break Overlay
- [ ] Overlay covers all connected displays
- [ ] Overlay appears above other windows
- [ ] Countdown timer is visible and accurate
- [ ] Sound plays when break starts (if enabled)
- [ ] Single Esc snoozes (overlay dismisses, returns after snooze duration)
- [ ] Double Esc skips (overlay dismisses, work timer restarts)

#### Settings
- [ ] Work duration slider updates timer
- [ ] Break duration slider works
- [ ] Display mode toggle switches between elapsed/remaining
- [ ] Sound toggle enables/disables break sound
- [ ] Launch at Login toggle works
- [ ] Advanced section expands/collapses

#### Global Shortcuts
- [ ] ⌘⇧B pauses/resumes timer from any app
- [ ] ⌘⇧R restarts session from any app
- [ ] Shortcuts work after granting Accessibility permission

#### Idle Detection
- [ ] Timer pauses when system is idle (no input for configured duration)
- [ ] Timer resumes when user returns
- [ ] Idle threshold is configurable in Advanced settings

#### System Integration
- [ ] App launches at login (when enabled)
- [ ] App survives sleep/wake cycles
- [ ] App handles display connect/disconnect during break

## Test Results

Test results are stored in:
- `build/TestResults-Unit.xcresult` — Xcode unit test results

## Adding New Tests

### Unit Tests
1. Add test file to `BlinkTests/`
2. Import XCTest and the module under test
3. Follow existing naming conventions: `test<Feature><Behavior>`

### AppleScript Tests
1. Add helper scripts to `scripts/test-helpers/`
2. Add test cases to `run_apple_tests()` in `scripts/run-tests.sh`
3. Verify accessibility permissions are sufficient

## Troubleshooting

### "osascript is not allowed assistive access"
Grant Terminal (or your terminal app) Accessibility permission:
1. Open System Settings → Privacy & Security → Accessibility
2. Add Terminal.app (or iTerm, VS Code, etc.)
3. Restart the terminal

### Unit tests fail to find BlinkTests target
Regenerate the Xcode project:
```bash
xcodegen generate
```

### AppleScript tests can't find Blink
Ensure Blink is running:
```bash
open build/Build/Products/Debug/Blink.app
```

Or build first:
```bash
xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Debug build
```
