# Plan: Expand Unit Tests + GitHub Actions CI

## Context

Blink v1.0 shipped with 15 unit tests (4 Settings, 11 TimerEngine) covering ~37% of testable code. The handoff identified expanding test coverage and CI integration as next steps. Currently there's no CI — all testing is manual via `scripts/run-tests.sh`.

**Goal:** Add ~35 new unit tests covering untested pure logic, and a GitHub Actions workflow that builds + runs unit tests on every push/PR.

---

## Phase 1: TimerState Tests (new file)

Create `BlinkTests/TimerStateTests.swift` — pure enum tests, zero dependencies.

**8 tests:**
- `testWorkRunningIsActive` / `testWorkPausedIsNotActive` / `testBreakRunningIsActive` / `testSnoozeRunningIsActive`
- `testBreakRunningShouldShowOverlay` / `testWorkRunningDoesNotShowOverlay` / `testWorkPausedDoesNotShowOverlay` / `testSnoozeDoesNotShowOverlay`

**Files:** `Blink/Models/TimerState.swift` (read), `BlinkTests/TimerStateTests.swift` (create)

---

## Phase 2: Settings Edge Cases (expand existing)

Add 2 tests to `BlinkTests/SettingsTests.swift`:

- `testSnoozeDurationSeconds` — verifies minutes→seconds conversion (work/break already tested, snooze is not)
- `testDisplayModeRoundTrip` — set .remaining, read back, set .elapsed, read back

---

## Phase 3: AppState Display Tests (expand existing)

Add tests to `BlinkTests/TimerEngineTests.swift` in a new `// MARK: - AppState Display Tests` section.

**~8 tests:**
- `testWorkProgressAtZero` / `testWorkProgressAtHalf` / `testWorkProgressAtFull`
- `testDisplayTimeAtZeroElapsed` / `testDisplayTimeAtZeroRemaining`
- `testDisplayTimeOverflowMinutes` (100+ minutes)
- `testDisplayTimeDuringBreak` / `testDisplayTimeDuringSnooze`

**Files:** `Blink/Models/AppState.swift` (read), `BlinkTests/TimerEngineTests.swift` (expand)

---

## Phase 4: IdleTimeProvider Protocol + Tick Handler Tests

The highest-value phase. The core tick logic (`handleWorkRunningTick`, `handleBreakRunningTick`, `handleSnoozeRunningTick`) is completely untested because it depends on `IdleDetector.getIdleTime()` returning real system values.

**Minimal production changes:**

1. **`Blink/Services/IdleDetector.swift`** — Add `IdleTimeProvider` protocol (3 lines), make `IdleDetector` conform
2. **`Blink/Services/TimerEngine.swift`** — Change `private let idleDetector` → `private var idleDetector: IdleTimeProvider`, add `#if DEBUG` setter for test injection, change `private func tick()` → `func tick()`

**~15 tests in `BlinkTests/TimerEngineTests.swift`:**

Work tick (active user):
- `testTickIncrementsWorkElapsedWhenActive`
- `testTickTriggersBreakWhenDurationReached`
- `testTickTriggersBreakSetsOverlayVisible`

Work tick (idle states):
- `testTickDoesNotIncrementWhenMediumIdle`
- `testTickResetsSessionOnReturnFromLongIdle`
- `testTickDoesNotResetWithoutLongIdle`

Break tick:
- `testBreakTickDecrementsRemaining`
- `testBreakTickCompletesAtZero`

Snooze tick:
- `testSnoozeTickDecrementsRemaining`
- `testSnoozeTickTriggersBreakAtZero`

Paused:
- `testTickWhilePausedDoesNotIncrement`

Full cycles:
- `testFullWorkBreakCycle`
- `testSnoozeToBreakCycle`

---

## Phase 5: GitHub Actions CI Workflow

Create `.github/workflows/ci.yml`:

- **Trigger:** push to `main` + PRs targeting `main`
- **Runner:** `macos-15` (ships with Xcode 16.x, supports macOS 14+ SDK)
- **Steps:**
  1. Checkout
  2. Cache Homebrew packages (xcodegen, xcbeautify)
  3. `brew install xcodegen xcbeautify`
  4. `xcodegen generate`
  5. Build (Release, code signing disabled)
  6. Run unit tests (`-only-testing:BlinkTests`, piped through xcbeautify)
  7. Upload `.xcresult` as artifact (14-day retention)
- **Concurrency:** cancel in-progress runs on same branch
- **No:** matrix builds, DerivedData cache, release jobs, AppleScript tests

**Files:** `.github/workflows/ci.yml` (create)

---

## Skipped (not worth the overhead)

- **HotkeyManager tests** — 4 lines of modifier masking logic, heavily coupled to NSEvent/Carbon APIs
- **LaunchAtLoginManager tests** — trivial if/else wrapping SMAppService system calls
- **View/WindowController tests** — require UI testing framework, already covered by AppleScript integration tests

---

## Summary

| Phase | New Tests | Production Changes |
|-------|----------|--------------------|
| 1: TimerState | 8 | None |
| 2: Settings | 2 | None |
| 3: AppState Display | 8 | None |
| 4: Tick Handlers | 15 | IdleTimeProvider protocol + TimerEngine injection seam |
| 5: CI | 0 | `.github/workflows/ci.yml` |
| **Total** | **~33** | **3 files modified, 1 created** |

Current: 15 tests → New total: ~48 tests

## Verification

1. Run `./scripts/run-tests.sh unit` locally — all tests pass
2. Push to a branch, open PR → CI workflow runs, build + tests green
3. Verify `.xcresult` artifact is uploaded
