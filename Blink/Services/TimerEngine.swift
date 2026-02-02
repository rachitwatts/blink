import Foundation
import Combine
import AppKit

/// Core timer engine that manages the work/break cycle
///
/// Responsibilities:
/// - Polls system idle time at adaptive intervals (1Hz active, 5s idle)
/// - Implements idle-aware work time tracking
/// - Manages state transitions (work → break → snooze → work)
/// - Updates AppState which triggers UI updates
///
/// Usage: Call `TimerEngine.shared.start()` when app launches
@MainActor
final class TimerEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = TimerEngine()

    // MARK: - Dependencies

    private let appState = AppState.shared
    private let settings = Settings.shared
    private let idleDetector = IdleDetector.shared

    // MARK: - Timer State

    private var timer: Timer?

    /// Flag to reset work elapsed to 0 when user returns from long idle
    private var shouldResetOnNextActivity: Bool = false

    // MARK: - Adaptive Polling

    /// Polling interval when user is active (1 second)
    private let activePollingInterval: TimeInterval = 1.0

    /// Polling interval when user is idle (5 seconds to save battery)
    private let idlePollingInterval: TimeInterval = 5.0

    /// Current polling interval
    private var currentPollingInterval: TimeInterval = 1.0

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Public API: Lifecycle

    /// Start the timer engine
    /// Call this once when the app launches
    func start() {
        guard timer == nil else {
            print("[TimerEngine] Already running, ignoring start()")
            return
        }
        print("[TimerEngine] Starting with \(activePollingInterval)s interval")
        scheduleTimer(interval: activePollingInterval)
    }

    /// Stop the timer engine
    /// Call this when the app is quitting
    func stop() {
        print("[TimerEngine] Stopping")
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Public API: Actions

    /// Toggle between paused and running states
    func togglePause() {
        switch appState.timerState {
        case .workRunning:
            print("[TimerEngine] Pausing")
            appState.timerState = .workPaused

        case .workPaused:
            print("[TimerEngine] Resuming")
            appState.timerState = .workRunning

        case .breakRunning, .snoozeRunning:
            // Cannot pause during break or snooze
            print("[TimerEngine] Cannot toggle pause in state: \(appState.timerState)")
        }
    }

    /// Restart the work session from zero
    func restartSession() {
        print("[TimerEngine] Restarting session")
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    /// Manually trigger a break (Start Break Now)
    func startBreakNow() {
        guard appState.timerState == .workRunning || appState.timerState == .workPaused else {
            print("[TimerEngine] Cannot start break in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Starting break now (manual)")
        triggerBreak()
    }

    /// Snooze the current break
    func snoozeBreak() {
        guard appState.timerState == .breakRunning else {
            print("[TimerEngine] Cannot snooze in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Snoozing break for \(settings.snoozeDurationMinutes) minutes")
        appState.snoozeRemainingSeconds = settings.snoozeDurationSeconds
        appState.timerState = .snoozeRunning
        appState.isOverlayVisible = false
    }

    /// Skip the current break and start a new work session
    func skipBreak() {
        guard appState.timerState == .breakRunning || appState.timerState == .snoozeRunning else {
            print("[TimerEngine] Cannot skip in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Skipping break, starting new session")
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    // MARK: - Private: Timer Management

    /// Schedule the timer with the given interval
    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentPollingInterval = interval

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        // Ensure timer runs even when menu is open
        RunLoop.current.add(timer!, forMode: .common)
    }

    /// Called every tick - the heart of the timer logic
    private func tick() {
        switch appState.timerState {
        case .workRunning:
            handleWorkRunningTick()

        case .workPaused:
            // Do nothing - timer is paused
            // But still check idle for adaptive polling
            updatePollingInterval(forIdleTime: idleDetector.getIdleTime())

        case .breakRunning:
            handleBreakRunningTick()

        case .snoozeRunning:
            handleSnoozeRunningTick()
        }
    }

    // MARK: - Private: State-Specific Tick Handlers

    /// Handle a tick while in WorkRunning state
    private func handleWorkRunningTick() {
        let idleSeconds = idleDetector.getIdleTime()
        let idleIgnore = TimeInterval(settings.idleIgnoreThreshold)
        let idleReset = TimeInterval(settings.idleResetThreshold)

        // Update polling interval based on idle state
        updatePollingInterval(forIdleTime: idleSeconds)

        // Idle handling logic - the core of Blink's intelligence
        if idleSeconds < idleIgnore {
            // ACTIVE or SHORT IDLE (reading/thinking)
            // Treat as active work - count this time

            // Check if returning from long idle
            if shouldResetOnNextActivity {
                print("[TimerEngine] Returning from long idle, resetting session")
                appState.workElapsedSeconds = 0
                shouldResetOnNextActivity = false
            }

            // Increment work time
            // Note: We add the polling interval, not just 1 second
            // This handles the adaptive polling correctly
            appState.workElapsedSeconds += Int(currentPollingInterval)

        } else if idleSeconds < idleReset {
            // MEDIUM IDLE (stepped away temporarily)
            // Don't count this time, but don't reset either
            // The timer effectively "pauses" without changing state
            // No action needed - we just don't increment

        } else {
            // LONG IDLE (away for extended period)
            // Will reset session when user returns
            if !shouldResetOnNextActivity {
                print("[TimerEngine] Long idle detected (\(Int(idleSeconds))s), will reset on return")
                shouldResetOnNextActivity = true
            }
        }

        // Check if work duration reached - trigger break
        if appState.workElapsedSeconds >= settings.workDurationSeconds {
            print("[TimerEngine] Work duration reached (\(appState.workElapsedSeconds)s), triggering break")
            triggerBreak()
        }
    }

    /// Handle a tick while in BreakRunning state
    private func handleBreakRunningTick() {
        if appState.breakRemainingSeconds > 0 {
            appState.breakRemainingSeconds -= 1
        } else {
            // Break complete
            print("[TimerEngine] Break complete, starting new session")
            completeBreak()
        }
    }

    /// Handle a tick while in SnoozeRunning state
    private func handleSnoozeRunningTick() {
        if appState.snoozeRemainingSeconds > 0 {
            appState.snoozeRemainingSeconds -= 1
        } else {
            // Snooze expired - show break overlay again
            print("[TimerEngine] Snooze expired, showing break overlay")
            triggerBreak()
        }
    }

    // MARK: - Private: State Transitions

    /// Trigger a break - show overlay and start countdown
    private func triggerBreak() {
        appState.breakRemainingSeconds = settings.breakDurationSeconds
        appState.timerState = .breakRunning
        appState.isOverlayVisible = true

        // Play sound if enabled
        if settings.soundEnabled {
            playBreakSound()
        }

        // Switch to active polling during break (for countdown accuracy)
        scheduleTimer(interval: activePollingInterval)
    }

    /// Complete a break and start new work session
    private func completeBreak() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
    }

    // MARK: - Private: Adaptive Polling

    /// Update polling interval based on current idle time
    private func updatePollingInterval(forIdleTime idleSeconds: TimeInterval) {
        let idleIgnore = TimeInterval(settings.idleIgnoreThreshold)

        // Use slower polling when idle to save battery
        let targetInterval = idleSeconds >= idleIgnore ? idlePollingInterval : activePollingInterval

        if targetInterval != currentPollingInterval {
            print("[TimerEngine] Switching to \(targetInterval)s polling interval")
            scheduleTimer(interval: targetInterval)
        }
    }

    // MARK: - Private: Sound

    /// Play the break notification sound
    private func playBreakSound() {
        // Use system sound "Glass" - a gentle chime
        NSSound(named: "Glass")?.play()
    }
}
