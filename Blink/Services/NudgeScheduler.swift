import Foundation

/// Manages micro nudge timing during work sessions
///
/// Responsibilities:
/// - Tracks elapsed active work time since last nudge
/// - Selects next nudge type using weighted random selection
/// - Respects suppression conditions (break, snooze, paused, nudges paused)
/// - Driven by TimerEngine's tick (no independent timer)
///
/// Usage: Call `NudgeScheduler.shared.tick()` from TimerEngine during active work
@MainActor
final class NudgeScheduler: ObservableObject {

    // MARK: - Singleton

    static let shared = NudgeScheduler()

    // MARK: - Dependencies

    private let appState = AppState.shared
    private let settings = Settings.shared

    // MARK: - State

    /// Seconds of active work since last nudge was shown
    private var elapsedActiveSeconds: Int = 0

    /// Index tracking for weighted rotation (for deterministic testing)
    /// In production, we use random selection from weighted pool
    private var lastShownType: NudgeType? = nil

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Called by TimerEngine on each active-work tick (1Hz)
    /// Only call when user is actively working (not idle, not paused, not on break)
    func tick() {
        // Don't count if nudges are globally disabled
        guard settings.nudgesEnabled else { return }

        // Don't count if session-paused
        guard !appState.nudgesPausedForSession else { return }

        // Don't count if a nudge is already showing
        guard !appState.isNudgeVisible else { return }

        // Increment elapsed time
        elapsedActiveSeconds += 1

        // Check if interval reached
        if elapsedActiveSeconds >= settings.nudgeIntervalSeconds {
            tryShowNudge()
        }
    }

    /// Reset elapsed time (called on break complete, skip, or session restart)
    func resetTimer() {
        elapsedActiveSeconds = 0
    }

    /// Un-pause nudges (called when a break completes)
    func resumeNudges() {
        appState.nudgesPausedForSession = false
    }

    /// Pause nudges for this session (called from nudge right-click)
    func pauseNudgesForSession() {
        appState.nudgesPausedForSession = true
        // If a nudge is showing, dismiss it
        if appState.isNudgeVisible {
            dismissNudge()
        }
    }

    /// Dismiss the current nudge
    func dismissNudge() {
        appState.isNudgeVisible = false
        appState.activeNudgeType = nil
    }

    // MARK: - Private

    /// Attempt to show a nudge (checks for enabled types)
    private func tryShowNudge() {
        guard let nudgeType = selectNextNudgeType() else {
            // No enabled nudge types — reset timer anyway to prevent buildup
            elapsedActiveSeconds = 0
            return
        }

        showNudge(nudgeType)
        elapsedActiveSeconds = 0
    }

    /// Select next nudge type using weighted random selection
    /// Returns nil if no types are enabled
    private func selectNextNudgeType() -> NudgeType? {
        // Build weighted pool of enabled types
        var pool: [NudgeType] = []

        if settings.nudgeBlinkEnabled {
            // Blink has 2x weight
            pool.append(.blink)
            pool.append(.blink)
        }
        if settings.nudgePostureEnabled {
            pool.append(.posture)
        }
        if settings.nudgeStretchEnabled {
            pool.append(.neckStretch)
        }

        guard !pool.isEmpty else { return nil }

        // Random selection from weighted pool
        return pool.randomElement()
    }

    /// Show the nudge by updating AppState
    private func showNudge(_ type: NudgeType) {
        appState.activeNudgeType = type
        appState.isNudgeVisible = true

        // Record analytics
        AnalyticsService.shared.recordNudgeShown(type: type)
    }

    // MARK: - Testing Support

    #if DEBUG
    /// Reset all state for testing
    func reset() {
        elapsedActiveSeconds = 0
        lastShownType = nil
        appState.isNudgeVisible = false
        appState.activeNudgeType = nil
        appState.nudgesPausedForSession = false
    }

    /// Get elapsed seconds for testing
    var testElapsedSeconds: Int { elapsedActiveSeconds }

    /// Inject a specific nudge type for deterministic testing
    func testShowNudge(_ type: NudgeType) {
        showNudge(type)
        elapsedActiveSeconds = 0
    }
    #endif
}
