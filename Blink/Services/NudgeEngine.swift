import Foundation
import Combine

/// Engine that schedules and triggers micro-nudges (blink, posture, neck stretch)
///
/// Nudges are small, non-modal reminders shown on the right edge of the screen.
/// They auto-dismiss after a few seconds and never appear during breaks or when paused.
///
/// After a snooze, nudge frequency is temporarily increased (1.5x for 10 minutes).
@MainActor
final class NudgeEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = NudgeEngine()

    // MARK: - Published State

    /// The nudge currently being displayed (nil = no nudge visible)
    @Published var activeNudge: NudgeType?

    // MARK: - Dependencies

    private let settings = Settings.shared
    private let appState = AppState.shared

    // MARK: - Internal State

    /// Accumulated active seconds since last nudge of each type
    private var accumulatedSeconds: [NudgeType: Int] = [:]

    /// Timestamp when snooze boost expires (nudges fire faster after a break snooze)
    private var snoozeBoostUntil: Date?

    /// Timer for auto-dismissing the current nudge
    private var dismissTimer: AnyCancellable?

    /// Whether the engine is running
    private var isRunning: Bool = false

    // MARK: - Initialization

    private init() {
        for nudgeType in NudgeType.allCases {
            accumulatedSeconds[nudgeType] = 0
        }
    }

    // MARK: - Public API

    /// Reset all accumulators (called on app start or settings change)
    func reset() {
        for nudgeType in NudgeType.allCases {
            accumulatedSeconds[nudgeType] = 0
        }
        snoozeBoostUntil = nil
        dismissNudge()
        isRunning = false
    }

    /// Start the nudge engine
    func start() {
        isRunning = true
    }

    /// Stop the nudge engine
    func stop() {
        isRunning = false
        dismissNudge()
    }

    /// Called every tick by TimerEngine (1s when active) to accumulate nudge time
    ///
    /// Only accumulates when:
    /// - Nudges are globally enabled
    /// - App is in workRunning state
    /// - User is active (idle < idleIgnoreThreshold)
    func tick(idleSeconds: TimeInterval) {
        guard isRunning else { return }
        guard settings.nudgesEnabled else { return }

        // Don't accumulate during breaks, snooze, or paused states
        guard appState.timerState == .workRunning else { return }

        // Don't accumulate when user is idle
        let idleIgnore = TimeInterval(settings.idleIgnoreThreshold)
        guard idleSeconds < idleIgnore else { return }

        // Don't fire new nudges while one is showing
        guard activeNudge == nil else { return }

        // Accumulate and check each nudge type
        for nudgeType in NudgeType.allCases {
            guard nudgeType.isEnabled(in: settings) else { continue }

            accumulatedSeconds[nudgeType, default: 0] += 1

            let interval = effectiveInterval(for: nudgeType)
            if accumulatedSeconds[nudgeType, default: 0] >= interval {
                showNudge(nudgeType)
                return // Only one nudge at a time
            }
        }
    }

    /// Activate snooze boost — called when user snoozes a break
    /// Increases nudge frequency by 1.5x for 10 minutes
    func activateSnoozeBoost() {
        snoozeBoostUntil = Date().addingTimeInterval(600) // 10 minutes
        print("[NudgeEngine] Snooze boost activated for 10 minutes")
    }

    /// Dismiss the currently visible nudge immediately
    func dismissNudge() {
        dismissTimer?.cancel()
        dismissTimer = nil
        activeNudge = nil
    }

    // MARK: - Testing Support

    #if DEBUG
    /// Expose accumulated seconds for testing
    func getAccumulatedSeconds(for type: NudgeType) -> Int {
        accumulatedSeconds[type, default: 0]
    }

    /// Expose effective interval for testing
    func getEffectiveInterval(for type: NudgeType) -> Int {
        effectiveInterval(for: type)
    }

    /// Check if snooze boost is active
    var isSnoozeBoostActive: Bool {
        guard let until = snoozeBoostUntil else { return false }
        return Date() < until
    }
    #endif

    // MARK: - Private

    /// Get the effective interval for a nudge type, accounting for snooze boost
    private func effectiveInterval(for nudgeType: NudgeType) -> Int {
        let baseInterval = nudgeType.intervalSeconds(in: settings)

        // If snooze boost is active, reduce interval by 1/3 (fire 1.5x faster)
        if let until = snoozeBoostUntil, Date() < until {
            return max(60, baseInterval * 2 / 3) // Minimum 60 seconds
        }

        return baseInterval
    }

    /// Show a nudge and schedule auto-dismiss
    private func showNudge(_ type: NudgeType) {
        print("[NudgeEngine] Showing \(type.rawValue) nudge")
        accumulatedSeconds[type] = 0
        activeNudge = type

        // Schedule auto-dismiss
        let displayDuration = TimeInterval(settings.nudgeDisplayDurationSeconds)
        dismissTimer?.cancel()
        dismissTimer = Timer.publish(every: displayDuration, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.dismissNudge()
            }

        NudgeWindowController.shared.showNudge(type)
    }
}
