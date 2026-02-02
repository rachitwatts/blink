Blink — PRD (macOS Menu Bar Eye-Break + Nudge App)

1) Overview

Blink is a lightweight, local-first macOS menu bar app that helps reduce eye strain and headaches by enforcing a work/break cadence (default 25 min work / 5 min break) using system input activity (keyboard/mouse/trackpad). When a break is due, Blink shows a full-screen overlay across all monitors with a soothing, futuristic visual.

Planned expansions
	•	v2: “Micro-nudges” (non-obtrusive side nudges) to blink, fix posture, stretch neck.
	•	v3: “Intelligent nudges” that adapt to behavior (e.g., frequent snooze) and optionally use camera-based posture estimation (strict opt-in, local processing).

⸻

2) Problem & motivation

With keratoconus and mini-scleral lenses, long continuous screen time often triggers headaches. The most effective mitigation is a consistent habit: look away every ~25 minutes and take a 5-minute break. In practice, deep work makes it easy to forget.

Blink makes this habit automatic while staying minimal and pleasant.

⸻

3) Goals

v1 (MVP)
	1.	Enforce a reliable 25/5 rhythm based on input activity.
	2.	Handle “stepping away” correctly:
	•	Idle < 1 minute: treat as active (keep timer running).
	•	Idle 1–5 minutes: exclude from the work session (don’t count it).
	•	Idle ≥ 5 minutes: reset session to 0 on return.
	3.	Show a full-screen overlay on all monitors for breaks.
	4.	Provide quick controls: menu bar timer, pause/resume, restart, settings.
	5.	Be fast, stable, and local-first with minimal storage.

v2
	6.	Provide non-obtrusive “nudges” (blink/posture/neck stretch) that can be toggled off.

v3
	7.	Add “intelligent nudges” that adapt based on behavior and optionally (opt-in) detect posture using camera signals locally.

⸻

4) Non-goals (v1)
	•	Detect passive attention (e.g., videos playing) without input.
	•	Meeting/call/screen-recording suppression (planned later; the architecture should allow it).
	•	Cloud sync, accounts, analytics, or content tracking.
	•	Anything that logs keystrokes or captures screen content.

⸻

5) Target user & context
	•	Primary: a heavy laptop user prone to headaches/eye strain, using scleral lenses, needs structured breaks and gentle reminders.
	•	Usage: multiple monitors, long coding/meeting blocks, frequent “micro-aways.”

⸻

6) Product principles
	1.	Friendly but firm: break overlay is hard to miss, but easy to bypass intentionally.
	2.	Minimal UI: lives in menu bar; settings are simple.
	3.	Privacy-first: local processing; explicit opt-in for any camera use (v3).
	4.	Soothing, futuristic, clean: visuals should reduce cognitive load, not add it.
	5.	Predictable behavior: timers behave consistently across sleep/lock/idle.

⸻

7) Key decisions (confirmed requirements)

Activity definition
	•	Activity = system-wide input events (keyboard, mouse, trackpad).
	•	Screen motion/video/animation is not considered activity.

Idle handling thresholds
	•	idleIgnoreThreshold = 60s
Idle below this is treated as reading/thinking → timer continues.
	•	idleResetThreshold = 300s
If idle reaches or exceeds this → reset session on return.
	•	Between 60s and 300s → exclude the entire idle duration from work time.

Break overlay behavior (multi-monitor)
	•	Must cover all displays.
	•	Must appear above full-screen apps.
	•	Visual: soothing gradient + centered timer + minimal controls.
	•	Controls:
	•	Snooze 5 min: single Esc (and optionally a button)
	•	Skip: double Esc (and a button), starts a new 25-min session immediately
	•	During break: user input does not change anything unless user explicitly snoozes/skips.

Menu bar display
	•	Default shows elapsed time (mm:ss). Setting can toggle to show remaining.

Startup
	•	“Launch at login” supported (default ON).

⸻

8) User experience

8.1 Menu bar states
	•	Running: shows elapsed time (default) e.g., 12:34
	•	Paused: shows paused indicator (icon or prefix) e.g., ⏸ 12:34
	•	Break due / in break: (optional) show a distinct icon state
	•	Suppressed (future): show a distinct icon state and reason (v2+/v3)

Clicking opens a menu:
	•	Pause / Resume (toggle)
	•	Restart session
	•	Start break now (optional)
	•	Settings…
	•	Launch at login (toggle)
	•	Quit

8.2 Break overlay
	•	Appears automatically at work threshold.
	•	UI:
	•	Big countdown timer at center
	•	Small line: “Look away. Blink. Breathe.”
	•	Bottom: Snooze / Skip buttons
	•	Hint text: “Esc = Snooze 5 min • Esc Esc = Skip”
	•	On completion: overlay disappears; new work session starts immediately at 0.

8.3 Snooze vs skip
	•	Single Esc: snooze 5 minutes (break still pending; overlay returns after snooze)
	•	Double Esc (within a short window): skip break; start a fresh 25-min session

⸻

9) Functional requirements

9.1 Core timer model (v1)

Defaults
	•	Work duration: 25 minutes
	•	Break duration: 5 minutes
	•	Snooze duration: 5 minutes
	•	Idle ignore threshold: 60 seconds
	•	Idle reset threshold: 300 seconds
	•	Tick interval: 1 second

States
	•	WorkRunning
	•	WorkPaused
	•	BreakRunning (overlay visible)
	•	SnoozeRunning (overlay hidden, break still pending)

Logic (tick-based)
	•	Poll system idle time each tick.
	•	If idleSeconds < 60: count time toward session.
	•	If 60 <= idleSeconds < 300: do not count time toward session.
	•	If idleSeconds >= 300: set shouldResetOnNextActivity = true.
	•	When returning to activity (idleSeconds falls < 60):
	•	If shouldResetOnNextActivity: set workElapsed = 0, clear flag.
	•	Trigger break when workElapsed >= workDurationSeconds.

Sleep/lock
	•	Treat as inactivity.
	•	On wake/unlock, follow the same idle thresholds (reset if away ≥ 5 min, etc.).

9.2 Overlay on all screens (v1)
	•	Must render on every active display.
	•	Must appear above full-screen apps/spaces.
	•	Must be dismissible only by:
	•	countdown completion, or
	•	Snooze/Skip actions.

9.3 Settings (v1)
	•	Work duration (minutes)
	•	Break duration (minutes)
	•	Sound on/off (optional v1; can be included)
	•	Display mode: elapsed vs remaining
	•	Advanced:
	•	idleIgnoreThreshold
	•	idleResetThreshold
	•	Launch at login toggle (default ON)
	•	Shortcuts: at minimum fixed defaults; optional customization later.

9.4 Global shortcuts (v1)
	•	Toggle Pause/Resume
	•	Restart session
Notes:
	•	If macOS permissions are needed, Blink should guide user to enable required permissions.

⸻

10) v2 Feature: Micro-nudges (non-obtrusive side nudges)

10.1 What it is

A small, unobtrusive nudge that slides in from the right side (or appears near right edge) reminding you to:
	•	Blink (keep eyes moist)
	•	Fix posture (sit upright)
	•	Stretch neck (reduce stiffness-related headaches)

10.2 Requirements (v2)
	•	Nudges are optional and can be turned off globally.
	•	Each nudge type can be individually toggled:
	•	Blink nudges
	•	Posture nudges
	•	Neck stretch nudges
	•	Nudge frequency is configurable (defaults TBD; suggested starting point):
	•	Blink: every 8–12 minutes
	•	Posture: every 20–30 minutes
	•	Neck: every 30–45 minutes
	•	Nudges should be:
	•	Small footprint
	•	Auto-dismiss after a few seconds
	•	Not steal focus (no modal)
	•	Not appear during the break overlay
	•	Nudges should respect the app state:
	•	If paused: do not show nudges
	•	If suppressed (future): do not show nudges (or show fewer)

10.3 Basic intelligence (v2)
	•	If user snoozes a break, increase nudge frequency slightly for the next X minutes (configurable) as a gentle compensatory mechanism.

⸻

11) v3 Feature: Intelligent nudges

11.1 Intelligence signals (v3)
	•	Behavioral:
	•	frequent snoozes
	•	long continuous active time (near thresholds)
	•	time-of-day patterns
	•	Optional device signals (strict opt-in):
	•	camera-based posture estimation (no photos stored)
	•	mic/camera usage detection (for suppression)
	•	screen recording/sharing detection (for suppression)

11.2 Camera-based posture detection (v3)

Strict requirements
	•	Fully opt-in and clearly explained.
	•	Local-only processing.
	•	No storage of images.
	•	Transparent UX: obvious when enabled + what it does.
	•	Provide a “Test posture detection” view for calibration (optional).

Outputs
	•	Simple posture classification: upright vs slouched (coarse).
	•	Confidence threshold; if uncertain, do not nag.

11.3 Safety & privacy stance (v3)
	•	Blink should remain useful without camera.
	•	Camera feature must be:
	•	optional
	•	reversible instantly
	•	minimal in scope

⸻

12) Future feature: Suppression during calls/recording/sharing

12.1 Suppression signals (planned)
	•	In a call
	•	Screen recording active
	•	Presentation / screen sharing active
	•	Mic/camera in use

12.2 Behavior when suppressed
	•	App enters Suppressed state:
	•	timers do not advance
	•	overlay does not appear
	•	menu bar icon changes to indicate suppressed + reason (where possible)

12.3 Architecture requirement (v1)

Implement a SuppressionProvider interface early (even if it always returns false in v1), so adding detectors later doesn’t require rewriting the timer engine.

⸻

13) Visual design requirements (applies to v1+)

13.1 Design language
	•	Futuristic, soothing, clean, minimal.
	•	Avoid busy textures; prioritize calm gradients and clarity.
	•	Subtle depth is fine (e.g., glassy cards), but keep it restrained.

13.2 Typography
	•	Use a crisp, modern system font stack (or a single bundled font if needed).
	•	Timer should be:
	•	large
	•	highly legible
	•	not overly thin

13.3 Color & motion
	•	Gradients should be soft and low-contrast.
	•	Motion (nudges) should be subtle and not distracting.
	•	Offer “Reduce motion” respect (macOS accessibility).

13.4 Logo / icon
	•	Simple glyph that reads well at menu bar size.
	•	“Blink” concept without being cartoonish:
	•	abstract eye / eyelid arc / minimal dot-line motif
	•	Must work in monochrome (menu bar) and full color (app icon).

⸻

14) Accessibility
	•	Large text on break overlay (scalable).
	•	VoiceOver labels for overlay controls.
	•	Respect macOS “Reduce motion”.
	•	Keep contrast sufficient for readability.

⸻

15) Privacy & data handling
	•	Local-only in v1 and v2.
	•	Store only preferences + minimal state (timestamps/state).
	•	No keystroke logging or content capture.
	•	Any camera usage (v3) is opt-in, local, and non-persistent.

⸻

16) Performance & reliability
	•	Poll idle time at 1Hz; CPU usage should remain low.
	•	Overlay must be robust across:
	•	multiple monitors
	•	display connect/disconnect
	•	sleep/wake
	•	full-screen spaces

⸻

17) Acceptance criteria

v1
	•	Correct idle logic (60s ignore, 300s reset) validated on boundary cases.
	•	Overlay appears on all monitors at 25 minutes of active time.
	•	Snooze and skip behavior works reliably (single vs double Esc).
	•	Menu bar shows elapsed time by default; toggle for remaining works.
	•	Pause/resume + restart via menu and shortcuts.
	•	Launch at login works.

v2
	•	Nudges show on the right edge without stealing focus.
	•	Nudges are configurable and can be disabled.
	•	Nudges do not appear during break overlay or when paused.

v3
	•	Intelligent nudges adapt based on snoozes and usage.
	•	Camera posture detection is opt-in, local, non-persistent, and easy to disable.

⸻

18) Milestones
	1.	v1
	•	Timer engine + idle logic
	•	Menu bar UI + settings
	•	Multi-monitor break overlay + snooze/skip
	•	Launch at login
	•	Hotkeys (toggle + restart)
	2.	v2
	•	Nudge system UI + preferences
	•	Basic adaptive logic (e.g., after snooze)
	•	Suppression-provider scaffolding (if not already)
	3.	v3
	•	Intelligent nudges engine
	•	Optional camera posture detection (opt-in) + calibration
	•	Suppression detectors (calls/recording/sharing) + UI indication
