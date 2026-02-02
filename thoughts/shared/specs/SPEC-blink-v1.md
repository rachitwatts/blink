# SPEC: Blink v1 - macOS Eye-Break App

**Created:** 2026-02-02
**Status:** Draft
**PRD Reference:** references/prd.md

---

## 1. Overview

Blink is a lightweight, local-first macOS menu bar app that enforces work/break rhythms (25 min work / 5 min break) to reduce eye strain and headaches. It monitors system input activity and displays a full-screen overlay when breaks are due.

### Core Problem
Long continuous screen time triggers headaches (especially for keratoconus + scleral lens users). The most effective mitigation is consistent 25-minute work / 5-minute break cycles, but deep work makes this easy to forget.

### Solution
An unobtrusive timer that:
- Tracks active work time (keyboard/mouse/trackpad input)
- Intelligently handles idle periods (reading, thinking, stepping away)
- Enforces breaks with a full-screen overlay that's hard to miss but easy to bypass intentionally

---

## 2. Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Framework** | SwiftUI | Modern, declarative, native macOS integration |
| **macOS Target** | 14+ (Sonoma) | Latest APIs, best SwiftUI features |
| **Distribution** | Direct download (notarized) | More flexibility, no App Store sandboxing constraints |
| **Persistence** | UserDefaults | Simple, built-in, sufficient for preferences |
| **Analytics** | None | Privacy-first approach |
| **Shortcuts** | Fixed defaults | Simpler implementation for v1 |
| **Audio** | Optional (default off) | Include soft chime feature but disable by default |

---

## 3. Users & Actors

### Primary User
- Heavy laptop user prone to headaches/eye strain
- Uses scleral lenses, needs structured breaks
- Multiple monitors, long coding/meeting blocks
- Frequent "micro-aways" (bathroom, coffee, etc.)

### System Actors
- **macOS Input System**: Provides idle time via `CGEventSource`
- **Display System**: NSScreen enumeration for multi-monitor overlay
- **Login Items**: SMAppService for launch-at-login

---

## 4. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Blink App                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Menu Bar UI │  │   Settings  │  │   Break Overlay     │  │
│  │  (SwiftUI)  │  │  (SwiftUI)  │  │ (NSWindow per       │  │
│  │             │  │             │  │  monitor, SwiftUI)  │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┼─────────────────────┘             │
│                          │                                   │
│                    ┌─────▼─────┐                             │
│                    │   App     │                             │
│                    │  State    │                             │
│                    │ (Observable)                            │
│                    └─────┬─────┘                             │
│                          │                                   │
│         ┌────────────────┼────────────────┐                  │
│         │                │                │                  │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐          │
│  │   Timer     │  │    Idle     │  │ Suppression │          │
│  │   Engine    │  │  Detector   │  │  Provider   │          │
│  │             │  │             │  │ (interface) │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                    System Services                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ CGEventSource│ │  NSScreen   │  │   SMAppService      │  │
│  │ (idle time) │  │ (displays)  │  │  (login items)      │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. User Flows

### 5.1 Normal Work Session

```
1. App launches → Menu bar icon appears → Timer shows 00:00
2. User works → Keyboard/mouse activity detected → Timer increments
3. Timer reaches 25:00 → Break overlay appears on all monitors
4. User sees: countdown timer, "Look away. Blink. Breathe.", Snooze/Skip buttons
5. 5-minute countdown completes → Overlay disappears
6. New work session starts → Timer resets to 00:00
```

### 5.2 Idle Handling (Reading/Thinking)

```
1. User stops typing to read code (idle < 60s)
2. Timer continues counting (treated as active work)
3. User resumes typing → Normal flow continues
```

### 5.3 Idle Handling (Short Away)

```
1. User steps away (60s <= idle < 300s)
2. Timer PAUSES (idle time not counted)
3. User returns (activity detected)
4. Timer RESUMES from where it was
```

### 5.4 Idle Handling (Long Away)

```
1. User is away for 5+ minutes (idle >= 300s)
2. Flag set: shouldResetOnNextActivity = true
3. User returns (activity detected)
4. Timer RESETS to 00:00
5. Fresh work session begins
```

### 5.5 Snooze Break

```
1. Break overlay appears
2. User presses Esc once OR clicks "Snooze 5 min"
3. Overlay hides
4. State: SnoozeRunning (5-minute countdown)
5. Snooze expires → Overlay reappears
```

### 5.6 Skip Break

```
1. Break overlay appears
2. User presses Esc twice within 500ms OR clicks "Skip"
3. Overlay disappears immediately
4. New work session starts (timer = 00:00)
```

### 5.7 Pause/Resume via Menu

```
1. User clicks menu bar → selects "Pause"
2. Timer pauses → Menu bar shows ⏸ 12:34
3. User clicks menu bar → selects "Resume"
4. Timer continues from paused value
```

---

## 6. State Machine

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
              ┌──────────┐                                │
   ┌──────────│  Work    │◄────────────────────┐         │
   │          │ Running  │                     │         │
   │          └────┬─────┘                     │         │
   │               │                           │         │
   │ pause         │ workElapsed >= 25min      │         │
   │               ▼                           │         │
   │          ┌──────────┐    snooze      ┌────┴────┐    │
   │          │  Break   │───────────────►│ Snooze  │    │
   │          │ Running  │                │ Running │    │
   │          └────┬─────┘◄───────────────┴────┬────┘    │
   │               │         snooze expires    │         │
   │               │                           │ skip    │
   │               │ break complete            │         │
   │               │      OR skip              │         │
   │               └───────────────────────────┴─────────┘
   │
   ▼
┌──────────┐
│  Work    │
│  Paused  │────────────── resume ──────────────► WorkRunning
└──────────┘
```

### States

| State | Description | Timer Behavior | UI |
|-------|-------------|----------------|-----|
| `WorkRunning` | Active work session | Counts up (with idle logic) | Menu bar: `12:34` |
| `WorkPaused` | User paused | Frozen | Menu bar: `⏸ 12:34` |
| `BreakRunning` | Break in progress | Counts down from 5:00 | Overlay visible |
| `SnoozeRunning` | Break snoozed | Counts down from 5:00 | Overlay hidden |

---

## 7. MVP Features (v1)

### Must Have
- [ ] Timer engine with idle-aware logic (60s ignore, 300s reset)
- [ ] Menu bar icon with elapsed time display
- [ ] Menu with: Pause/Resume, Restart, Settings, Launch at Login, Quit
- [ ] Full-screen break overlay on ALL monitors (above full-screen apps)
- [ ] Break countdown timer display
- [ ] Snooze (single Esc or button) - 5 minutes
- [ ] Skip (double Esc within 500ms or button) - starts new session
- [ ] Settings panel: work/break durations, display mode toggle
- [ ] Launch at login (default ON)
- [ ] Global shortcuts: Toggle Pause/Resume, Restart session
- [ ] Accessibility: VoiceOver labels, keyboard navigation

### Nice to Have (v1)
- [ ] "Start break now" menu option
- [ ] Optional soft chime on break start (default OFF)
- [ ] Settings: idle thresholds (advanced)
- [ ] Reduce motion support

### Deferred (v2+)
- [ ] Micro-nudges (blink, posture, stretch)
- [ ] Suppression during calls/recording
- [ ] Configurable shortcuts
- [ ] Intelligent nudges with behavior adaptation
- [ ] Camera-based posture detection (v3)

---

## 8. UI Specifications

### 8.1 Menu Bar

**Icon States:**
- Running: Simple Blink icon (monochrome)
- Paused: Icon with pause indicator or ⏸ prefix
- Break due: Optional distinct state

**Menu Items:**
```
┌─────────────────────────┐
│ Pause                   │  (toggles to "Resume")
│ Restart Session         │
│ Start Break Now         │  (optional)
│ ─────────────────────── │
│ Settings...             │
│ ─────────────────────── │
│ ✓ Launch at Login       │
│ ─────────────────────── │
│ Quit Blink              │
└─────────────────────────┘
```

**Timer Display:**
- Default: Elapsed time (e.g., `12:34`)
- Optional: Remaining time (e.g., `12:26`)
- Format: `mm:ss` always

### 8.2 Break Overlay

**Visual Design:**
- Subtle gradient blur background (soft colors, calming)
- Semi-transparent (but not dismissible by clicking through)
- Appears above full-screen apps (NSWindow.Level.floating or higher)

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                                                         │
│                                                         │
│                         4:32                            │  ← Large countdown
│                                                         │
│              Look away. Blink. Breathe.                 │  ← Subtle message
│                                                         │
│                                                         │
│                                                         │
│            ┌──────────┐    ┌──────────┐                │
│            │  Snooze  │    │   Skip   │                │
│            │  5 min   │    │          │                │
│            └──────────┘    └──────────┘                │
│                                                         │
│           Esc = Snooze 5 min  •  Esc Esc = Skip        │  ← Hint text
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Countdown Timer:**
- Large (60-80pt), highly legible
- System font or SF Mono for monospace alignment
- Center-aligned on screen

**Controls:**
- Two buttons: "Snooze 5 min" and "Skip"
- Keyboard hints below buttons
- Full keyboard accessibility (Tab to navigate, Space/Enter to activate)

### 8.3 Settings Panel

**Tabs/Sections:**
1. **General**
   - Work duration: Stepper (1-60 min, default 25)
   - Break duration: Stepper (1-30 min, default 5)
   - Display mode: Toggle (Elapsed / Remaining)
   - Sound on break: Toggle (default OFF)

2. **Advanced**
   - Idle ignore threshold: Stepper (30-120s, default 60)
   - Idle reset threshold: Stepper (120-600s, default 300)

---

## 9. Technical Specifications

### 9.1 Idle Detection

**Implementation:**
```swift
// Get system-wide idle time using Quartz Event Services
let idleTime = CGEventSource.secondsSinceLastEventType(
    .hidSystemState,
    eventType: CGEventType(rawValue: ~0)!
)
```

**Tick Logic (1Hz polling):**
```swift
func tick() {
    let idleSeconds = getSystemIdleTime()

    switch true {
    case idleSeconds < idleIgnoreThreshold:
        // Treat as active - count toward session
        workElapsed += 1
        shouldResetOnNextActivity = false

    case idleSeconds < idleResetThreshold:
        // Between thresholds - don't count (effective pause)
        // No increment, no reset flag
        break

    case idleSeconds >= idleResetThreshold:
        // Long idle - will reset on return
        shouldResetOnNextActivity = true
    }

    // Check if break is due
    if workElapsed >= workDurationSeconds && state == .workRunning {
        triggerBreak()
    }
}
```

### 9.2 Multi-Monitor Overlay

**Approach:**
- One NSWindow per screen
- Use `NSScreen.screens` to enumerate all displays
- Set window level to `.screenSaver` or higher to appear above full-screen apps
- Handle display connect/disconnect via NotificationCenter

```swift
func showBreakOverlay() {
    for screen in NSScreen.screens {
        let window = BreakOverlayWindow(screen: screen)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        overlayWindows.append(window)
    }
}
```

### 9.3 Double-Esc Detection

```swift
var lastEscTime: Date?
let doubleEscWindow: TimeInterval = 0.5  // 500ms

func handleEsc() {
    let now = Date()
    if let lastTime = lastEscTime,
       now.timeIntervalSince(lastTime) < doubleEscWindow {
        // Double Esc - Skip
        skipBreak()
        lastEscTime = nil
    } else {
        // First Esc - wait for potential second
        lastEscTime = now
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleEscWindow) {
            if self.lastEscTime != nil {
                // No second Esc - Snooze
                self.snoozeBreak()
                self.lastEscTime = nil
            }
        }
    }
}
```

### 9.4 Global Shortcuts

**Fixed Defaults (v1):**
- `Cmd+Shift+B` - Toggle Pause/Resume
- `Cmd+Shift+R` - Restart Session

**Implementation:**
- Use `NSEvent.addGlobalMonitorForEvents` or Carbon API
- Guide user to enable Accessibility permissions if needed

### 9.5 Launch at Login

```swift
import ServiceManagement

func setLaunchAtLogin(_ enabled: Bool) {
    try? SMAppService.mainApp.register()
    // or .unregister()
}
```

### 9.6 Settings Persistence

```swift
@AppStorage("workDuration") var workDuration: Int = 25
@AppStorage("breakDuration") var breakDuration: Int = 5
@AppStorage("idleIgnoreThreshold") var idleIgnoreThreshold: Int = 60
@AppStorage("idleResetThreshold") var idleResetThreshold: Int = 300
@AppStorage("displayMode") var displayMode: DisplayMode = .elapsed
@AppStorage("launchAtLogin") var launchAtLogin: Bool = true
@AppStorage("soundEnabled") var soundEnabled: Bool = false
```

---

## 10. Edge Cases & Error Handling

| Scenario | Expected Behavior |
|----------|-------------------|
| Monitor connected during work | New monitor included in next overlay |
| Monitor disconnected during overlay | Overlay adjusts (window removed) |
| System sleep during work | Treated as idle; reset if >= 5 min |
| System sleep during break | Break continues on wake (or completes if time passed) |
| App crash during break | On relaunch, start fresh work session |
| User tries to dismiss overlay by clicking | No action (overlay captures clicks) |
| Multiple rapid Esc presses | Only first double-Esc triggers skip |
| Snooze spam (many snoozes in a row) | Allowed - no limit in v1 |
| System preferences deny Accessibility | Show guide to enable permissions |
| Timer overflow (> 99:59) | Display as `99:59+` or continue with hours |

---

## 11. Testing Strategy

### Unit Tests (Core Logic)
- [ ] Timer state machine transitions
- [ ] Idle detection thresholds (boundary cases: 59s, 60s, 61s, 299s, 300s, 301s)
- [ ] Work session completion triggers break
- [ ] Snooze countdown and re-trigger
- [ ] Skip resets session correctly
- [ ] Pause/Resume maintains elapsed time

### UI Tests
- [ ] Menu bar displays correct time format
- [ ] Menu items enable/disable based on state
- [ ] Settings changes persist and apply
- [ ] Break overlay appears on all screens
- [ ] Keyboard shortcuts (Esc, double-Esc) work in overlay
- [ ] Accessibility: VoiceOver can read all elements

### Manual Testing Checklist
- [ ] Multi-monitor: 2+ displays, mixed resolutions
- [ ] Full-screen apps: overlay appears above
- [ ] Sleep/wake: correct idle handling
- [ ] Hot-plug: connect/disconnect monitor during overlay
- [ ] Launch at login: verify registration
- [ ] Long sessions: run for hours, check stability

---

## 12. Open Questions

| Question | Status | Decision |
|----------|--------|----------|
| Should snooze limit exist (e.g., max 3 snoozes)? | Deferred | No limit for v1, consider for v2 based on usage |
| Should we track snooze count for analytics? | Answered | No - privacy first, no analytics |
| What happens if user is watching a video? | Answered | v1 does not detect passive attention; overlay will appear |
| Should overlay have a "Start working" button for manual early-end? | Open | Currently auto-dismisses only at countdown end |

---

## 13. Delegated Decisions

These decisions were delegated ("you decide") and resolved as follows:

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Full-screen app behavior | Overlay appears on top but single Esc snoozes | Balance "friendly but firm" - breaks should be noticed but not punitive |
| Window level for overlay | `.screenSaver` level | High enough to appear above full-screen apps but below certain system UI |

---

## 14. Success Metrics (Qualitative)

Since we have no analytics, success is measured by:
- App runs reliably without crashes
- Breaks trigger at correct 25-minute intervals
- Idle logic handles edge cases correctly
- Overlay appears on all monitors
- Snooze/Skip work as expected
- User adopts consistent break habits (self-reported)

---

## 15. Dependencies

| Dependency | Purpose | Risk |
|------------|---------|------|
| macOS 14+ | Target platform | Low - user controls environment |
| Accessibility permission | Global shortcuts | Medium - requires user action |
| CGEventSource | Idle detection | Low - stable API |
| NSScreen | Multi-monitor support | Low - stable API |
| SMAppService | Launch at login | Low - modern replacement for LSSharedFileList |

---

## 16. File Structure (Proposed)

```
Blink/
├── BlinkApp.swift              # App entry point, menu bar setup
├── Models/
│   ├── AppState.swift          # Observable app state
│   ├── TimerState.swift        # Timer state enum
│   └── Settings.swift          # UserDefaults wrapper
├── Services/
│   ├── TimerEngine.swift       # Core timer logic
│   ├── IdleDetector.swift      # System idle time polling
│   ├── SuppressionProvider.swift # Interface (v1 returns false)
│   └── HotkeyManager.swift     # Global shortcut handling
├── Views/
│   ├── MenuBarView.swift       # Menu bar UI
│   ├── BreakOverlayView.swift  # Break overlay content
│   ├── SettingsView.swift      # Settings window
│   └── Components/
│       ├── TimerDisplay.swift
│       └── BreakButton.swift
├── Windows/
│   └── BreakOverlayWindow.swift # NSWindow subclass for overlay
├── Resources/
│   ├── Assets.xcassets         # Icons, colors
│   └── Sounds/
│       └── chime.aiff          # Optional break sound
└── Tests/
    ├── TimerEngineTests.swift
    ├── IdleDetectorTests.swift
    └── StateTransitionTests.swift
```

---

## 17. Implementation Milestones

The v1 implementation is divided into 3 milestones, each building on the previous:

### Milestone 1: Core Foundation
**Goal:** Working timer in menu bar with idle-aware logic

**Deliverables:**
- Xcode project with correct structure
- Core models (TimerState, Settings, AppState)
- IdleDetector service (system idle time polling)
- TimerEngine with full idle logic (60s ignore, 300s reset)
- Basic menu bar showing timer (time only, no controls yet)

**Success Criteria:**
- App launches and shows `00:00` in menu bar
- Timer increments during keyboard/mouse activity
- Timer pauses (stops incrementing) when idle 60-300s
- Timer resets to `00:00` after idle >= 300s
- Adaptive polling works (1Hz active, 5s idle)

**Task File:** `references/milestone-1-tasks.md`

---

### Milestone 2: Break System
**Goal:** Full-screen break overlay with snooze/skip and menu controls

**Deliverables:**
- BreakOverlayView (SwiftUI view with dark gradient, timer, buttons)
- BreakOverlayWindowController (multi-monitor NSWindow management)
- Double-Esc detection for skip
- Menu bar controls (Pause/Resume, Restart, Start Break Now, Quit)
- State transitions (WorkRunning ↔ WorkPaused, BreakRunning ↔ SnoozeRunning)

**Success Criteria:**
- Break overlay appears on ALL monitors at 25 minutes
- Overlay appears above full-screen applications
- Single Esc snoozes (5 minutes), double Esc skips
- Snooze/Skip buttons work
- Menu controls work correctly
- Overlay auto-dismisses at countdown end
- Reduce motion support

**Task File:** `references/milestone-2-tasks.md`

---

### Milestone 3: Settings, Shortcuts & Polish
**Goal:** Complete v1 feature set with settings, shortcuts, onboarding

**Deliverables:**
- SettingsWindowController and SettingsView
- HotkeyManager (global shortcuts with lazy permission request)
- LaunchAtLoginManager (SMAppService integration)
- OnboardingView and OnboardingWindowController
- Unit tests for core logic
- App icon

**Success Criteria:**
- Settings window opens and changes apply immediately
- Work/break durations configurable
- Display mode toggle (elapsed/remaining) works
- Global shortcuts (Cmd+Shift+B, Cmd+Shift+R) work after permission
- Launch at login toggle works
- First-launch onboarding appears
- All unit tests pass

**Task File:** `references/milestone-3-tasks.md`

---

## 18. Task File References

Each milestone has a detailed task file with step-by-step instructions:

| Milestone | Task File | Description |
|-----------|-----------|-------------|
| 1 | `references/milestone-1-tasks.md` | Core timer + menu bar |
| 2 | `references/milestone-2-tasks.md` | Break overlay + controls |
| 3 | `references/milestone-3-tasks.md` | Settings + shortcuts + polish |

**Important:** Complete milestones in order. Each milestone depends on the previous one.

---

## Next Steps

1. **Complete Milestone 1** - Follow `references/milestone-1-tasks.md`
2. **Complete Milestone 2** - Follow `references/milestone-2-tasks.md`
3. **Complete Milestone 3** - Follow `references/milestone-3-tasks.md`
4. **Manual Testing** - Complete full testing checklist
5. **Notarization** - Sign and notarize for distribution
