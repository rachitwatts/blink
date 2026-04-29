# Eye Health Deep Dive Dashboard

## Overview

Add a dedicated Eye Health deep dive view to the dashboard that explains *why* the score is what it is, surfaces behavioral patterns that hurt eye health, and provides actionable suggestions. Users can dismiss insights they consider irrelevant ("not an issue"), and dismissed insights are remembered across sessions.

Currently the Eye Health grade appears as a single letter in a `StatCardView` across all dashboard tabs — no breakdown, no explanations, no actionable guidance beyond a single tip line shown only at grade C or below.

## Desired End State

Clicking the Eye Health stat card (or a dedicated "Eye Health" tab/link) opens a deep dive view that shows:

1. **Score Breakdown** — the two factors (break compliance, snooze rate) with visual gauges and their individual contribution to the grade
2. **Pattern Detection** — automatically identified behavioral issues (e.g., "You skip breaks most in the afternoon", "You snooze 3+ times before every completed break", "Mondays have lowest compliance")
3. **Suggestions** — specific, actionable recommendations computed from the data (e.g., "Try a shorter break duration", "Your longest skip streak is in the 2–4 PM window — set a reminder")
4. **Dismissible Insights** — each pattern/suggestion can be marked "Not an issue" and won't reappear unless the user resets dismissals

After this plan is complete:

- Tapping the Eye Health stat card navigates to the deep dive view
- The view recomputes patterns and suggestions every time it opens (fresh analysis)
- Dismissed insights persist via UserDefaults and are filtered out
- A "Reset dismissed" button lets users start fresh
- Works for all time scopes (today, week, month, all time) — the deep dive inherits the scope from whichever tab the user was on

### Verification

- [ ] Clicking Eye Health card opens the deep dive view
- [ ] Score breakdown shows break compliance and snooze rate with visual bars
- [ ] At least 5 pattern detectors produce relevant insights from real data
- [ ] Suggestions are contextual (not generic — they reference actual numbers)
- [ ] Dismissing an insight hides it immediately and on next open
- [ ] "Reset dismissed" brings everything back
- [ ] Empty state when no patterns detected ("Your eye health is great!")
- [ ] Back navigation returns to the dashboard tab
- [ ] All 87 existing tests still pass

## What We're NOT Doing

- Changing the grade calculation algorithm itself
- Adding new event types or modifying `SessionEvent`
- Push notifications or reminders from suggestions
- Historical trend charts of the grade over time (that's a separate feature)
- Machine learning or external API calls — all analysis is local, deterministic

## Architecture

### New Files

```
Blink/Services/EyeHealthAnalyzer.swift        — Pattern detection + suggestion engine
Blink/Models/EyeHealthInsight.swift            — Data model for insights
Blink/Views/Dashboard/EyeHealthDeepDiveView.swift — The deep dive UI
```

### Modified Files

```
Blink/Services/EyeHealthCalculator.swift       — Expose raw counts as public properties on EyeHealthMetrics
Blink/Views/Dashboard/TodayView.swift          — Make Eye Health card tappable → navigate to deep dive
Blink/Views/Dashboard/WeekView.swift           — Same
Blink/Views/Dashboard/MonthView.swift          — Same
Blink/Views/Dashboard/AllTimeView.swift        — Same
Blink/Views/Dashboard/StatCardView.swift       — Add optional tap handler variant
```

### Data Model: `EyeHealthInsight`

```swift
struct EyeHealthInsight: Identifiable, Codable {
    let id: String              // Stable key for dismissal (e.g., "afternoon_skip_pattern")
    let category: Category      // .pattern or .suggestion
    let severity: Severity      // .high, .medium, .low
    let title: String           // "Afternoon skip streak"
    let description: String     // "You skipped 80% of breaks between 2–5 PM this week"
    let icon: String            // SF Symbol name

    enum Category: String, Codable { case pattern, suggestion }
    enum Severity: String, Codable { case high, medium, low }
}
```

### Pattern Detectors (in `EyeHealthAnalyzer`)

Each detector is a pure function: `(events: [SessionEvent], settings: Settings) -> EyeHealthInsight?`

| # | Detector | ID | Fires When |
|---|----------|----|------------|
| 1 | **Skip-heavy period** | `time_of_day_skips` | >60% of skips cluster in a 3-hour window |
| 2 | **Consecutive skip streak** | `consecutive_skips` | 3+ breaks skipped in a row (current or historical max) |
| 3 | **Snooze-before-complete** | `snooze_then_complete` | >50% of completed breaks had 2+ snoozes first |
| 4 | **Sessions without breaks** | `long_no_break_run` | 3+ sessions completed without any break taken |
| 5 | **Day-of-week pattern** | `worst_day_compliance` | One weekday has compliance 20+ points below average |
| 6 | **Break duration mismatch** | `break_too_long` | Snooze rate >40% AND break duration is above default (suggests break is too long) |
| 7 | **Early-day abandonment** | `morning_skip_pattern` | First 2+ breaks of the day are always skipped |
| 8 | **Declining trend** | `declining_compliance` | This week's compliance is 15+ points below last week's (week/month/allTime scopes only) |

### Suggestion Generator

Maps detected patterns to actionable suggestions:

| Pattern | Suggestion |
|---------|------------|
| `time_of_day_skips` | "Try scheduling deep work outside your 2–5 PM skip window" |
| `consecutive_skips` | "Even a 30-second break helps — try completing just the next one" |
| `snooze_then_complete` | "You eventually take breaks after snoozing. Consider a shorter snooze (currently Xm)" |
| `long_no_break_run` | "You went N sessions without a break. Consider a shorter work duration" |
| `worst_day_compliance` | "Mondays are your toughest day. Plan lighter work to allow breaks" |
| `break_too_long` | "Your X-minute break might feel too long. Try reducing to Y minutes" |
| `morning_skip_pattern` | "You tend to skip early breaks. Try starting Blink after your first coffee" |
| `declining_compliance` | "Your compliance dropped from X% to Y% this week. What changed?" |

### Dismissal Storage

```swift
// In UserDefaults via @AppStorage
@AppStorage("dismissedEyeHealthInsights") var dismissedInsightIDs: String = ""
// Stored as comma-separated IDs: "break_too_long,morning_skip_pattern"
```

Simple, no new SwiftData model needed. A `Set<String>` in memory, serialized to/from the comma-separated string.

---

## Implementation Phases

### Phase 1: Data Model & Analyzer Engine

**Files:** `EyeHealthInsight.swift`, `EyeHealthAnalyzer.swift`, modify `EyeHealthCalculator.swift`

1. Create `EyeHealthInsight` model with `id`, `category`, `severity`, `title`, `description`, `icon`
2. Expand `EyeHealthMetrics` to include raw counts (`breaksCompleted`, `breaksSkipped`, `breaksSnoozed`, `breaksStarted`) so the deep dive view can display them without recounting
3. Create `EyeHealthAnalyzer` with:
   - `static func analyze(events: [SessionEvent], settings: Settings, scope: AnalysisScope) -> [EyeHealthInsight]`
   - `enum AnalysisScope { case today, week, month, allTime }`
   - Implement all 8 pattern detectors as private methods
   - Each returns `EyeHealthInsight?` — nil means pattern not detected
4. Add suggestion generation: for each detected pattern, produce a companion suggestion insight
5. Add unit tests for each detector with synthetic event data

### Phase 2: Dismissal Persistence

**Files:** `EyeHealthAnalyzer.swift` (add filtering), `Settings.swift` or standalone

1. Add `dismissedEyeHealthInsights` to `Settings` (or a standalone `@AppStorage` in the analyzer)
2. Add `func filterDismissed(_ insights: [EyeHealthInsight], dismissed: Set<String>) -> [EyeHealthInsight]`
3. Add `func dismiss(_ insightID: String)` and `func resetDismissals()`
4. Add unit tests: dismiss, filter, reset

### Phase 3: Deep Dive View

**Files:** `EyeHealthDeepDiveView.swift`, modify `StatCardView.swift`

1. Create `EyeHealthDeepDiveView` that takes `events: [SessionEvent]`, `scope: AnalysisScope`
2. Layout:
   - **Header:** Large grade display with color (green A+ → red D), scope label
   - **Score Breakdown section:** Two horizontal bars — break compliance % and snooze rate % — with color coding (green/yellow/red based on grade thresholds)
   - **Raw numbers row:** "12 completed · 3 skipped · 2 snoozed" in a compact row
   - **Patterns section:** List of detected pattern insights, each with icon, title, description, and a "×" dismiss button
   - **Suggestions section:** List of suggestion insights with lightbulb icon, same dismiss capability
   - **Empty state:** When all patterns dismissed or none detected: "Your eye health habits look solid. Keep it up!"
   - **Footer:** "Reset dismissed insights" link (only shown when ≥1 insight is dismissed)
3. Add `onTapGesture` or `Button` wrapper to the Eye Health `StatCardView` in all 4 dashboard tabs
4. Navigation: Use a sheet or push navigation within the dashboard (sheet is simpler given the tab structure)

### Phase 4: Integration & Polish

**Files:** `TodayView.swift`, `WeekView.swift`, `MonthView.swift`, `AllTimeView.swift`

1. In each view, add `@State private var showEyeHealthDeepDive = false`
2. Replace the Eye Health `StatCardView` with a tappable version that sets `showEyeHealthDeepDive = true`
3. Add `.sheet(isPresented: $showEyeHealthDeepDive)` presenting `EyeHealthDeepDiveView` with the correct scope and events
4. Verify all 4 tabs work correctly
5. Build and run — test with real data
6. Run full test suite — ensure all 87 tests pass

---

## Design Notes

- **Recompute on every open:** The analyzer runs from scratch each time the sheet appears. No caching. The event set is small enough (hundreds per day) that this is instant.
- **Stable insight IDs:** Detector IDs are string constants (not generated from data), so dismissals survive even when the specific numbers change. E.g., dismissing "break_too_long" means "I know my breaks are long, stop telling me."
- **Severity ordering:** High severity insights sort first. Within same severity, patterns before suggestions.
- **Color language:** Reuse the heatmap color scheme from `HeatmapView` for the grade display (green → red gradient).
- **Scope-appropriate detectors:** `worst_day_compliance` and `declining_compliance` only run for week/month/allTime scopes (need multi-day data). `time_of_day_skips` runs for all scopes.
