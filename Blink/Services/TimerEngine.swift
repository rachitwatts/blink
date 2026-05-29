import Foundation
import Combine
import AppKit
import UserNotifications

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
    private var idleDetector: IdleTimeProvider = IdleDetector.shared
    private var callDetector: CallDetectorProtocol = CallDetector.shared
    private var calendarMonitor: CalendarMonitorProtocol = CalendarMonitor.shared

    /// Source of the current time. Production uses the wall clock; tests can
    /// inject a `MutableClock` for deterministic deferral timing.
    private var clock: NowProviding = SystemClock()

    /// Nudge scheduler for micro nudges during work
    private let nudgeScheduler = NudgeScheduler.shared

    #if DEBUG
    func setIdleDetector(_ provider: IdleTimeProvider) {
        self.idleDetector = provider
    }

    func setCallDetector(_ detector: CallDetectorProtocol) {
        self.callDetector = detector
    }

    func setCalendarMonitor(_ monitor: CalendarMonitorProtocol) {
        self.calendarMonitor = monitor
    }

    func setClock(_ clock: NowProviding) {
        self.clock = clock
    }
    #endif

    // MARK: - Timer State

    private var timerCancellable: AnyCancellable?

    /// Flag to reset work elapsed to 0 when user returns from long idle
    private var shouldResetOnNextActivity: Bool = false

    /// Identifier for the current break (used to correlate snooze events)
    private var currentBreakId: String = UUID().uuidString

    /// Configured break duration captured when break starts (avoids mid-break settings changes)
    private var configuredBreakDuration: Int = 0

    /// Configured snooze duration captured when snooze starts (avoids mid-snooze settings changes)
    private var configuredSnoozeDuration: Int = 0

    /// Whether a breakDeferred analytics event has been recorded for this deferral cycle
    private var hasDeferralBeenRecorded: Bool = false

    /// Timestamp when deferral started (for tracking total deferred time)
    private var deferralStartTime: Date?

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
        guard timerCancellable == nil else {
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
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Public API: Actions

    /// Toggle between paused and running states
    func togglePause() {
        switch appState.timerState {
        case .workRunning:
            print("[TimerEngine] Pausing")
            appState.timerState = .workPaused
            AnalyticsService.shared.recordPauseToggled(newState: "paused")

        case .workPaused:
            print("[TimerEngine] Resuming")
            appState.timerState = .workRunning
            AnalyticsService.shared.recordPauseToggled(newState: "resumed")

        case .breakRunning, .snoozeRunning:
            // Cannot pause during break or snooze
            print("[TimerEngine] Cannot toggle pause in state: \(appState.timerState)")
        }
    }

    /// Restart the work session from zero
    func restartSession() {
        print("[TimerEngine] Restarting session")
        // If restarting during a break or snooze, record it as a skipped break
        if appState.timerState == .breakRunning || appState.timerState == .snoozeRunning {
            AnalyticsService.shared.recordBreakSkipped(remainingSeconds: appState.breakRemainingSeconds)
        }
        // Only log reset if we're in a work state (not break/snooze where
        // the work duration was already logged as sessionCompleted)
        if appState.workElapsedSeconds > 0 &&
            (appState.timerState == .workRunning || appState.timerState == .workPaused) {
            AnalyticsService.shared.recordSessionReset(
                elapsed: appState.workElapsedSeconds, reason: "manual_restart"
            )
        }
        appState.workElapsedSeconds = 0
        appState.activeBreakExercise = nil
        // Reset nudge timer for new session
        nudgeScheduler.resetTimer()
        // Clear any lingering deferral state from call/screen-share suppression
        appState.breakDeferred = false
        appState.breakDeferralReason = nil
        hasDeferralBeenRecorded = false
        deferralStartTime = nil
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
        scheduleTimer(interval: activePollingInterval)
    }

    /// Manually trigger a break (Start Break Now)
    func startBreakNow() {
        if appState.timerState == .snoozeRunning {
            resumeBreakFromSnooze()
            return
        }

        guard appState.timerState == .workRunning || appState.timerState == .workPaused else {
            print("[TimerEngine] Cannot start break in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Starting break now (manual)")
        // Clear any lingering deferral state — user explicitly requested a break
        appState.breakDeferred = false
        appState.breakDeferralReason = nil
        hasDeferralBeenRecorded = false
        deferralStartTime = nil
        // Record the in-progress work duration before transitioning to break
        if appState.workElapsedSeconds > 0 {
            AnalyticsService.shared.recordSessionCompleted(
                actualDuration: appState.workElapsedSeconds,
                configuredDuration: settings.workDurationSeconds
            )
        }
        triggerBreak(isManual: true)
    }

    /// Snooze the current break
    func snoozeBreak() {
        guard appState.timerState == .breakRunning else {
            print("[TimerEngine] Cannot snooze in state: \(appState.timerState)")
            // Recover from a stuck overlay: dismiss it even if the engine has
            // already left the break state (issue #54).
            appState.isOverlayVisible = false
            return
        }
        print("[TimerEngine] Snoozing break for \(settings.snoozeDurationMinutes) minutes")
        configuredSnoozeDuration = settings.snoozeDurationSeconds
        appState.snoozeRemainingSeconds = configuredSnoozeDuration
        appState.timerState = .snoozeRunning
        appState.isOverlayVisible = false
        AnalyticsService.shared.recordBreakSnoozed(
            snoozeDuration: settings.snoozeDurationSeconds,
            breakId: currentBreakId
        )

        // Switch to active polling for accurate snooze countdown
        scheduleTimer(interval: activePollingInterval)
    }

    /// Resume break immediately from snooze (user clicked "Start Break Now" during snooze)
    private func resumeBreakFromSnooze() {
        let elapsedSnooze = configuredSnoozeDuration - appState.snoozeRemainingSeconds
        print("[TimerEngine] Resuming break from snooze (snoozed for \(elapsedSnooze)s)")

        AnalyticsService.shared.recordSnoozeEndedEarly(
            elapsedSnoozeSeconds: elapsedSnooze,
            breakId: currentBreakId
        )

        appState.snoozeRemainingSeconds = 0
        appState.breakRemainingSeconds = configuredBreakDuration
        appState.breakElapsedSeconds = 0
        if settings.breakStyle == .gentle {
            appState.breakPhase = .floating
        }
        appState.timerState = .breakRunning
        appState.isOverlayVisible = true
    }

    /// Skip the current break and start a new work session
    func skipBreak() {
        guard appState.timerState == .breakRunning || appState.timerState == .snoozeRunning else {
            print("[TimerEngine] Cannot skip in state: \(appState.timerState)")
            // Recover from a stuck overlay: dismiss it even if the engine has
            // already left the break/snooze state (issue #54).
            appState.isOverlayVisible = false
            return
        }
        print("[TimerEngine] Skipping break, starting new session")
        AnalyticsService.shared.recordBreakSkipped(remainingSeconds: appState.breakRemainingSeconds)
        // Reset nudge timer for new session
        nudgeScheduler.resetTimer()
        appState.workElapsedSeconds = 0
        appState.activeBreakExercise = nil
        appState.breakElapsedSeconds = 0
        appState.breakPhase = .floating
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false

        // Switch to active polling for new work session
        scheduleTimer(interval: activePollingInterval)
    }

    // MARK: - Private: Timer Management

    /// Schedule the timer with the given interval
    private func scheduleTimer(interval: TimeInterval) {
        // Cancel existing timer
        timerCancellable?.cancel()
        currentPollingInterval = interval

        // Use Combine's Timer publisher - more robust and SwiftUI-friendly
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    /// Called every tick - the heart of the timer logic
    func tick() {
        logToFile("tick: state=\(appState.timerState), snoozeRemaining=\(appState.snoozeRemainingSeconds)")

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

    /// Debug helper: append a line to a debug log file.
    ///
    /// No-op in release builds. Even in DEBUG it stays off unless the
    /// `BLINK_DEBUG_LOG` environment variable points at a writable path —
    /// this keeps the per-tick file write out of production and prevents
    /// parallel test workers from racing on a shared `/tmp` path.
    private func logToFile(_ message: String) {
        #if DEBUG
        guard let logPath = ProcessInfo.processInfo.environment["BLINK_DEBUG_LOG"] else { return }
        let timestamp = Date().timeIntervalSince1970
        let line = "\(timestamp): \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data, attributes: nil)
        }
        #endif
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
                if appState.workElapsedSeconds > 0 {
                    print("[TimerEngine] Returning from long idle, resetting session")
                    AnalyticsService.shared.recordSessionReset(
                        elapsed: appState.workElapsedSeconds, reason: "idle_timeout"
                    )
                }
                appState.workElapsedSeconds = 0
                nudgeScheduler.resetTimer()
                // Clear any lingering deferral state from the previous session
                appState.breakDeferred = false
                appState.breakDeferralReason = nil
                hasDeferralBeenRecorded = false
                deferralStartTime = nil
                shouldResetOnNextActivity = false
            }

            // Increment work time
            // Note: We add the polling interval, not just 1 second
            // This handles the adaptive polling correctly
            appState.workElapsedSeconds += Int(currentPollingInterval)

            // Micro nudge tick (only during active work, suppressed while deferred)
            if !appState.breakDeferred {
                nudgeScheduler.tick()
            }

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
                AnalyticsService.shared.recordIdleDetected(
                    idleDuration: Int(idleSeconds), action: "will_reset"
                )
                shouldResetOnNextActivity = true
            }
        }

        // Only deliver breaks when user is actively working — not during idle
        guard idleSeconds < idleIgnore else { return }

        // Resolve any deferred break (from screen-sharing suppression) as soon as the condition clears.
        // This runs before the calendar/work-duration checks so early-shifted deferrals are
        // delivered promptly when screen sharing stops, even before the full work timer expires.
        if appState.breakDeferred {
            if !callDetector.isScreenSharing {
                let deferredSeconds = Int(clock.now.timeIntervalSince(deferralStartTime ?? clock.now))
                AnalyticsService.shared.recordBreakDeferralEnded(
                    totalDeferredSeconds: deferredSeconds, breakId: currentBreakId
                )
                appState.breakDeferred = false
                appState.breakDeferralReason = nil
                hasDeferralBeenRecorded = false
                deferralStartTime = nil
                deliverBreak()
            }
            return
        }

        // Calendar early shift: if break is almost due and a meeting starts soon, fire early
        let remainingWork = settings.workDurationSeconds - appState.workElapsedSeconds
        if remainingWork > 0 && remainingWork <= 60
            && calendarMonitor.nextEventStartsWithin(minutes: settings.calendarLeadTimeMinutes) {
            print("[TimerEngine] Early break shift: meeting starts within \(settings.calendarLeadTimeMinutes) min")
            // Note: sessionCompleted is recorded inside deliverBreak() for all paths
            deliverBreak()
            return
        }

        // Check if work duration reached - context-aware break delivery
        if appState.workElapsedSeconds >= settings.workDurationSeconds {
            deliverBreak()
        }
    }

    /// Determine how to deliver a break based on call/screen-share context
    private func deliverBreak() {
        if callDetector.isScreenSharing {
            // Full suppression — defer until screen sharing stops
            if !appState.breakDeferred {
                print("[TimerEngine] Screen sharing detected, deferring break")
                appState.breakDeferred = true
                appState.breakDeferralReason = "Screen sharing"
                deferralStartTime = clock.now
            }
            if !hasDeferralBeenRecorded {
                currentBreakId = UUID().uuidString
                AnalyticsService.shared.recordBreakDeferred(reason: "screen_sharing", breakId: currentBreakId)
                hasDeferralBeenRecorded = true
            }
            return
        }

        if callDetector.isOnCall {
            // In-call nudge — subtle reminder, reset work timer
            print("[TimerEngine] On call, showing in-call nudge")
            currentBreakId = UUID().uuidString
            AnalyticsService.shared.recordSessionCompleted(
                actualDuration: appState.workElapsedSeconds,
                configuredDuration: settings.workDurationSeconds
            )
            AnalyticsService.shared.recordInCallNudgeShown(breakId: currentBreakId)
            InCallNudgeWindowController.shared.show(duration: 4)
            appState.workElapsedSeconds = 0
            nudgeScheduler.resetTimer()
            return
        }

        // Normal break delivery
        print("[TimerEngine] Work duration reached (\(appState.workElapsedSeconds)s), triggering break")
        AnalyticsService.shared.recordSessionCompleted(
            actualDuration: appState.workElapsedSeconds,
            configuredDuration: settings.workDurationSeconds
        )
        triggerBreak()
    }

    /// Handle a tick while in BreakRunning state
    private func handleBreakRunningTick() {
        if appState.breakRemainingSeconds > 0 {
            appState.breakRemainingSeconds -= 1
        } else {
            print("[TimerEngine] Break complete, starting new session")
            completeBreak()
            return
        }

        guard settings.breakStyle == .gentle else { return }

        appState.breakElapsedSeconds += 1
        let newPhase = Self.computePhase(
            elapsed: appState.breakElapsedSeconds,
            current: appState.breakPhase
        )
        if newPhase != appState.breakPhase {
            print("[TimerEngine] Gentle break → \(newPhase) phase")
            appState.breakPhase = newPhase
        }
    }

    // MARK: - Gentle Break Phase Progression

    /// Seconds into a gentle break at which the overlay dims.
    static let gentleDimmedThreshold = 10

    /// Seconds into a gentle break at which the overlay goes fullscreen.
    static let gentleFullscreenThreshold = 20

    /// Pure phase progression for gentle breaks.
    ///
    /// Uses `>=` thresholds (not `==`) so a skipped tick — e.g. timer
    /// coalescing during system sleep — can't strand a phase at its exact
    /// boundary value (the root of issues #48/#50). The current-phase guard
    /// keeps escalation forward-only and one stage per tick:
    /// floating → dimmed (≥10s) → fullscreen (≥20s).
    static func computePhase(elapsed: Int, current: BreakPhase) -> BreakPhase {
        switch current {
        case .floating:
            return elapsed >= gentleDimmedThreshold ? .dimmed : .floating
        case .dimmed:
            return elapsed >= gentleFullscreenThreshold ? .fullscreen : .dimmed
        case .fullscreen:
            return .fullscreen
        }
    }

    /// Handle a tick while in SnoozeRunning state
    private func handleSnoozeRunningTick() {
        if appState.snoozeRemainingSeconds > 0 {
            appState.snoozeRemainingSeconds -= 1
        } else {
            // Snooze expired - show break overlay again (same break, not a new one)
            print("[TimerEngine] Snooze expired, showing break overlay")
            AnalyticsService.shared.recordSnoozeExpired(breakId: currentBreakId)
            // Resume the existing break without recording a new breakStarted
            appState.breakRemainingSeconds = configuredBreakDuration
            appState.activeBreakExercise = BreakContentProvider.shared.selectExercise()
            appState.breakElapsedSeconds = 0
            if settings.breakStyle == .gentle {
                appState.breakPhase = .floating
            }
            appState.timerState = .breakRunning
            appState.isOverlayVisible = true
        }
    }

    // MARK: - Private: State Transitions

    /// Trigger a break - show overlay and start countdown
    /// - Parameter isManual: true if triggered by user via "Start Break Now"
    private func triggerBreak(isManual: Bool = false) {
        currentBreakId = UUID().uuidString
        configuredBreakDuration = settings.breakDurationSeconds

        // Notification-only: send notification and reset, no overlay
        if settings.breakStyle == .notificationOnly {
            AnalyticsService.shared.recordBreakStarted(
                trigger: isManual ? "manual" : "auto",
                configuredDuration: configuredBreakDuration
            )
            sendBreakNotification()
            appState.workElapsedSeconds = 0
            nudgeScheduler.resetTimer()
            appState.timerState = .workRunning
            shouldResetOnNextActivity = false
            scheduleTimer(interval: activePollingInterval)
            return
        }

        AnalyticsService.shared.recordBreakStarted(
            trigger: isManual ? "manual" : "auto",
            configuredDuration: configuredBreakDuration
        )
        appState.breakRemainingSeconds = configuredBreakDuration
        appState.activeBreakExercise = BreakContentProvider.shared.selectExercise()
        appState.breakElapsedSeconds = 0
        appState.timerState = .breakRunning

        if settings.breakStyle == .gentle && !isManual {
            appState.breakPhase = .floating
        } else {
            appState.breakPhase = .fullscreen
        }

        appState.isOverlayVisible = true

        if settings.soundEnabled {
            playBreakSound()
        }

        scheduleTimer(interval: activePollingInterval)
    }

    /// Complete a break and start new work session
    func completeBreak() {
        // Guard against duplicate calls (e.g. stale timer firing after state already changed)
        guard appState.timerState == .breakRunning else {
            print("[TimerEngine] completeBreak() ignored - not in breakRunning state (state: \(appState.timerState))")
            return
        }

        let breakDuration = configuredBreakDuration - appState.breakRemainingSeconds
        AnalyticsService.shared.recordBreakCompleted(actualDuration: breakDuration)

        // Resume nudges and reset timer
        nudgeScheduler.resumeNudges()
        nudgeScheduler.resetTimer()

        // Lock screen if enabled and user is idle
        if settings.lockScreenAfterBreak {
            let isIdle = idleDetector.getIdleTime() >= TimeInterval(settings.idleIgnoreThreshold)
            if isIdle {
                ScreenLockService.lockScreen()
            }
        }

        appState.workElapsedSeconds = 0
        appState.activeBreakExercise = nil
        appState.breakElapsedSeconds = 0
        appState.breakPhase = .floating
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false

        // Switch to active polling for new work session
        scheduleTimer(interval: activePollingInterval)
    }

    // MARK: - Private: Notification-Only Mode

    private func sendBreakNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time for a break"
            content.body = "Look away from the screen. Blink. Breathe."
            content.sound = Settings.shared.soundEnabled ? .default : nil
            let request = UNNotificationRequest(
                identifier: "blink-break-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
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
