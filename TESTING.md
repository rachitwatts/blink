# Blink Test Strategy

How testing works in Blink, and the rules that keep the suite fast, isolated, and trustworthy.

## Quick start

```bash
# Run the unit tests (macOS)
./scripts/run-tests.sh unit

# Or directly:
xcodebuild test -project Blink.xcodeproj -scheme Blink \
  -destination 'platform=macOS' -only-testing:BlinkTests
```

CI (`.github/workflows/ci.yml`) builds Release, runs the unit tests with code
coverage, enforces a coverage ratchet on the logic layer, and lints against
`UserDefaults.standard` in production code.

## Test isolation — `BlinkTestCase`

Unit tests run **hosted by the real Blink.app**, so naive tests can mutate real
user state or even spawn real windows. Any test that touches `AppState`,
`Settings`, the timer, analytics, or windows MUST inherit **`BlinkTestCase`**
(`BlinkTests/BlinkTestCase.swift`), which per test:

- points `Settings` at an ephemeral `UserDefaults(suiteName:)` (never the real domain);
- configures `AnalyticsService` with an **in-memory** SwiftData container;
- resets `AppState` and `TimerEngine` internal state, and injects mocks
  (`mockIdle`, `mockCall`, `mockCalendar`, `mockScreenLock`);
- **suppresses all real window creation** (`BreakOverlayWindowController`,
  `NudgeWindowController`, `InCallNudgeWindowController`) — without this, setting
  `isOverlayVisible` spawns full-screen overlays that grab the display.

Pure-logic tests with no shared state (e.g. `EyeHealthCalculatorTests`,
`WindowLayoutTests`) can subclass `XCTestCase` directly.

Execution order is randomized (per the test plan in `project.yml`) to surface
any remaining order-dependence.

## Test seams (dependency injection)

Production singletons expose `#if DEBUG` setters so tests stay deterministic:

- `TimerEngine`: `setIdleDetector`, `setCallDetector`, `setCalendarMonitor`,
  `setClock` (`NowProviding`), `setScreenLock` (`ScreenLocking`).
- `Settings.useStoreForTesting(_:)`, `CallDetector.pollForTesting()`,
  `EyeHealthAnalyzer.setStoreForTesting(_:)`.
- Window/nudge controllers: `suppressForTesting`.

## What's covered

| Area | Files |
|------|-------|
| Timer state machine, idle/break/snooze, delivery modes | `TimerEngineTests`, `TimerEngineDeliveryModeTests`, `TimerStateTests` |
| Gentle-break phase machine (`computePhase`) | `GentleBreakPhaseTests` |
| State-machine invariants (seeded fuzz) | `StateMachineInvariantTests` |
| Notification-only delivery | `NotificationOnlyBreakTests` |
| Overlay window-layout decision (multi-monitor / disconnect) | `WindowLayoutTests` |
| Settings persistence / presets | `SettingsTests`, `TimerPresetTests` |
| Eye-health grade + insight detectors | `EyeHealthCalculatorTests`, `EyeHealthAnalyzerTests` |
| Analytics recording/queries | `AnalyticsServiceTests` |
| Weekly summary message selection | `WeeklySummaryServiceTests` |
| Break content selection, nudges, call/calendar detection, actions | `BreakContentProviderTests`, `NudgeSchedulerTests`, `CallDetectorTests`, `CalendarMonitorTests`, `BlinkActionsTests` |

## Conventions

- **Every bug fix gets a regression test** (fails before, passes after).
- New logic in `Blink/Services`, `Blink/Models`, `Shared` needs unit tests — the
  ratchet (`scripts/check-coverage.sh`) gates that layer.
- Don't assert incidental UI copy (display names, emoji) or unseeded-RNG ratios —
  assert behavior/contracts.
- SwiftUI Views are not unit-tested; extract pure presentation logic into testable
  functions rather than image-snapshotting (snapshots are environment-flaky across
  local vs CI macOS).

## Troubleshooting

- **Tests don't appear after adding a file:** `xcodegen generate`.
- **Coverage gate failed:** add tests for new logic, or adjust the floor in
  `scripts/check-coverage.sh` with justification.
