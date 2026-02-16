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
    private var idleDetector: IdleTimeProvider = IdleDetector.shared

    /// Sync manager for publishing state to watch via iCloud KVS.
    /// Nil when sync is disabled (e.g., during tests).
    private var syncManager: (any SyncManagerProtocol)?

    #if DEBUG
    func setIdleDetector(_ provider: IdleTimeProvider) {
        self.idleDetector = provider
    }

    /// Replace or disable the sync manager for testing.
    /// Pass nil to disable sync entirely.
    func setSyncManager(_ manager: (any SyncManagerProtocol)?) {
        self.syncManager = manager
    }
    #endif

    // MARK: - Timer State

    private var timerCancellable: AnyCancellable?
    private var settingsSyncCancellable: AnyCancellable?

    /// Flag to reset work elapsed to 0 when user returns from long idle
    private var shouldResetOnNextActivity: Bool = false

    /// Identifier for the current break (used to correlate snooze events)
    private var currentBreakId: String = UUID().uuidString

    /// Configured break duration captured when break starts (avoids mid-break settings changes)
    private var configuredBreakDuration: Int = 0

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

    // MARK: - Sync

    /// Set up iCloud KVS sync for watch communication.
    /// Call once after start(). Skipped automatically when syncManager is nil (tests).
    func setupSync() {
        guard syncManager == nil else { return } // Already configured (e.g., injected in tests)
        let manager = ICloudSyncManager()
        syncManager = manager
        configureSyncCallbacks()
        observeSettingsChanges()
        manager.startObserving()
        // Publish initial state so watch picks up current Mac state
        publishSyncPayload()
        settings.publishToSync(manager)
    }

    /// Wire up callbacks for incoming watch actions and settings.
    private func configureSyncCallbacks() {
        syncManager?.onWatchActionReceived = { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                switch action.action {
                case .snooze:
                    self.snoozeBreak()
                case .skipBreak:
                    self.skipBreak()
                }
            }
        }

        syncManager?.onSettingsReceived = { [weak self] remote in
            Task { @MainActor in
                guard let self else { return }
                self.settings.applyRemoteSettings(remote)
            }
        }
    }

    /// Observe Settings changes via Combine and publish to iCloud KVS.
    /// Skips publishing when the change originated from a remote sync
    /// (to prevent infinite publish → receive → publish loops).
    private func observeSettingsChanges() {
        settingsSyncCancellable = settings.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let syncManager = self.syncManager else { return }
                // Don't re-publish settings that came from a remote device.
                // Check timestamp rather than a flag because the debounce fires
                // after applyRemoteSettings returns (flag would already be cleared).
                let timeSinceRemoteApply = Date().timeIntervalSince1970 - self.settings.lastRemoteApplyAt
                guard timeSinceRemoteApply > 1.0 else { return }
                self.settings.publishToSync(syncManager)
            }
    }

    /// Build and publish the current timer state to iCloud KVS.
    private func publishSyncPayload() {
        guard let syncManager else { return }
        syncManager.publishTimerState(buildSyncPayload())
    }

    /// Build a SyncPayload from the current app state.
    private func buildSyncPayload() -> SyncPayload {
        SyncPayload(
            timerState: appState.timerState,
            stateChangedAt: Date().timeIntervalSince1970,
            workElapsedAtChange: appState.workElapsedSeconds,
            breakRemainingAtChange: appState.breakRemainingSeconds,
            snoozeRemainingAtChange: appState.snoozeRemainingSeconds,
            sourceDevice: "mac"
        )
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
            publishSyncPayload()

        case .workPaused:
            print("[TimerEngine] Resuming")
            appState.timerState = .workRunning
            AnalyticsService.shared.recordPauseToggled(newState: "resumed")
            publishSyncPayload()

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
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
        publishSyncPayload()
    }

    /// Manually trigger a break (Start Break Now)
    func startBreakNow() {
        guard appState.timerState == .workRunning || appState.timerState == .workPaused else {
            print("[TimerEngine] Cannot start break in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Starting break now (manual)")
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
            return
        }
        print("[TimerEngine] Snoozing break for \(settings.snoozeDurationMinutes) minutes")
        appState.snoozeRemainingSeconds = settings.snoozeDurationSeconds
        appState.timerState = .snoozeRunning
        appState.isOverlayVisible = false
        AnalyticsService.shared.recordBreakSnoozed(
            snoozeDuration: settings.snoozeDurationSeconds,
            breakId: currentBreakId
        )
        publishSyncPayload()

        // Switch to active polling for accurate snooze countdown
        scheduleTimer(interval: activePollingInterval)
    }

    /// Skip the current break and start a new work session
    func skipBreak() {
        guard appState.timerState == .breakRunning || appState.timerState == .snoozeRunning else {
            print("[TimerEngine] Cannot skip in state: \(appState.timerState)")
            return
        }
        print("[TimerEngine] Skipping break, starting new session")
        AnalyticsService.shared.recordBreakSkipped(remainingSeconds: appState.breakRemainingSeconds)
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
        publishSyncPayload()

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
        // Debug: log to file
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

    /// Debug helper: log to file
    private func logToFile(_ message: String) {
        let logPath = "/tmp/blink_debug.log"
        let timestamp = Date().timeIntervalSince1970
        let line = "\(timestamp): \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = FileHandle(forWritingAtPath: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logPath, contents: data, attributes: nil)
            }
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
                if appState.workElapsedSeconds > 0 {
                    print("[TimerEngine] Returning from long idle, resetting session")
                    AnalyticsService.shared.recordSessionReset(
                        elapsed: appState.workElapsedSeconds, reason: "idle_timeout"
                    )
                }
                appState.workElapsedSeconds = 0
                shouldResetOnNextActivity = false
            }

            // Increment work time
            // Note: We add the polling interval, not just 1 second
            // This handles the adaptive polling correctly
            appState.workElapsedSeconds += Int(currentPollingInterval)

            // Publish periodic heartbeat for watch sync (every 10 active seconds).
            // Without this, the watch marks the connection as offline after 30s
            // because the Mac only publishes on state transitions.
            if appState.workElapsedSeconds % 10 == 0 {
                publishSyncPayload()
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

        // Check if work duration reached - trigger break
        if appState.workElapsedSeconds >= settings.workDurationSeconds {
            print("[TimerEngine] Work duration reached (\(appState.workElapsedSeconds)s), triggering break")
            AnalyticsService.shared.recordSessionCompleted(
                actualDuration: appState.workElapsedSeconds,
                configuredDuration: settings.workDurationSeconds
            )
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
            // Snooze expired - show break overlay again (same break, not a new one)
            print("[TimerEngine] Snooze expired, showing break overlay")
            AnalyticsService.shared.recordSnoozeExpired(breakId: currentBreakId)
            // Resume the existing break without recording a new breakStarted
            appState.breakRemainingSeconds = configuredBreakDuration
            appState.timerState = .breakRunning
            appState.isOverlayVisible = true
            publishSyncPayload()
        }
    }

    // MARK: - Private: State Transitions

    /// Trigger a break - show overlay and start countdown
    /// - Parameter isManual: true if triggered by user via "Start Break Now"
    private func triggerBreak(isManual: Bool = false) {
        currentBreakId = UUID().uuidString
        configuredBreakDuration = settings.breakDurationSeconds
        AnalyticsService.shared.recordBreakStarted(
            trigger: isManual ? "manual" : "auto",
            configuredDuration: configuredBreakDuration
        )
        appState.breakRemainingSeconds = configuredBreakDuration
        appState.timerState = .breakRunning
        appState.isOverlayVisible = true
        publishSyncPayload()

        // Play sound if enabled
        if settings.soundEnabled {
            playBreakSound()
        }

        // Switch to active polling during break (for countdown accuracy)
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

        // Lock screen if enabled and user is idle
        if settings.lockScreenAfterBreak {
            let isIdle = idleDetector.getIdleTime() >= TimeInterval(settings.idleIgnoreThreshold)
            if isIdle {
                ScreenLockService.lockScreen()
            }
        }

        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        appState.isOverlayVisible = false
        shouldResetOnNextActivity = false
        publishSyncPayload()

        // Switch to active polling for new work session
        scheduleTimer(interval: activePollingInterval)
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
