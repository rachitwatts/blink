import Foundation
import Combine
import WatchKit

/// Timer engine for the watch app
///
/// Supports two modes of operation:
///
/// **Synced mode** (Mac reachable via iCloud KVS):
/// - Receives state transitions from the Mac via `SyncPayload`
/// - Computes current counters locally from synced timestamps
/// - Ticks at 1Hz to keep the display updated
/// - User actions (snooze/skip) apply locally for responsiveness then publish to Mac
///
/// **Local mode** (offline fallback):
/// - Activates when no sync received for 30+ seconds during active state
/// - Runs the original independent work/break cycle
///
/// Call `setupSync()` after `start()` to enable iCloud sync.
/// Without `setupSync()`, the engine runs purely in local mode (backwards-compatible).
@MainActor
final class WatchTimerEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = WatchTimerEngine()

    // MARK: - Dependencies

    private let appState = WatchAppState.shared
    private let settings = WatchSettings.shared

    // MARK: - Timer

    private var timerCancellable: AnyCancellable?
    private var settingsSyncCancellable: AnyCancellable?

    // MARK: - Extended Runtime Session

    private var extendedSession: WKExtendedRuntimeSession?

    // MARK: - Test Support

    /// Set to true to disable WatchKit hardware calls (haptics, extended sessions)
    /// during unit tests where these APIs are unavailable.
    var disableHardwareInteractions: Bool = false

    // MARK: - Sync

    /// Sync manager for receiving Mac state and publishing watch actions.
    /// Nil when sync is not configured (tests, or before setupSync() is called).
    private var syncManager: (any SyncManagerProtocol)?

    /// Timestamp of the last sync payload received from a remote device.
    private(set) var lastSyncReceivedAt: TimeInterval = 0

    /// The most recent sync payload received from a remote device.
    private(set) var lastSyncPayload: SyncPayload?

    /// Whether the watch considers itself offline (no sync in >30 seconds).
    /// When offline, the engine runs its own local timer.
    /// Published so SwiftUI views can react to connection status changes.
    @Published private(set) var isOffline: Bool = true

    /// Whether sync is configured (setupSync() was called).
    private var isSyncConfigured: Bool { syncManager != nil }

    /// Recompute the offline status from `lastSyncReceivedAt`.
    /// Called on every tick and when a remote payload arrives.
    private func updateOfflineStatus() {
        let offline: Bool
        if lastSyncReceivedAt <= 0 {
            offline = true
        } else {
            offline = Date().timeIntervalSince1970 - lastSyncReceivedAt > 30
        }
        if isOffline != offline {
            isOffline = offline
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API: Lifecycle

    func start() {
        guard timerCancellable == nil else { return }
        scheduleTimer()
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        syncManager?.stopObserving()
        endExtendedSession()
    }

    // MARK: - Public API: Sync Setup

    /// Set up iCloud KVS sync for Mac communication.
    /// Call once after start(). Without this call, the engine runs in local-only mode.
    func setupSync() {
        guard syncManager == nil else { return }
        let manager = ICloudSyncManager()
        syncManager = manager
        configureSyncCallbacks()
        observeSettingsChanges()
        manager.startObserving()
    }

    #if DEBUG
    /// Replace the sync manager for testing. Pass nil to disable sync.
    func setSyncManager(_ manager: (any SyncManagerProtocol)?) {
        self.syncManager = manager
        if manager != nil {
            configureSyncCallbacks()
        }
    }

    /// Reset sync state for testing.
    func resetSyncState() {
        lastSyncReceivedAt = 0
        lastSyncPayload = nil
        isOffline = true
    }
    #endif

    // MARK: - Public API: Actions

    func togglePause() {
        switch appState.timerState {
        case .workRunning:
            appState.timerState = .workPaused
        case .workPaused:
            appState.timerState = .workRunning
        case .breakRunning, .snoozeRunning:
            break
        }
    }

    func restartSession() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        endExtendedSession()
    }

    func startBreakNow() {
        guard appState.timerState == .workRunning || appState.timerState == .workPaused else {
            return
        }
        triggerBreak()
    }

    func snoozeBreak() {
        guard appState.timerState == .breakRunning else { return }
        // Apply locally immediately for responsiveness
        appState.snoozeRemainingSeconds = settings.snoozeDurationSeconds
        appState.timerState = .snoozeRunning
        // Clear synced payload so tick() uses local mode until Mac acknowledges
        lastSyncPayload = nil
        // Publish action to Mac via iCloud KVS
        if let syncManager {
            syncManager.publishWatchAction(SyncAction(
                action: .snooze,
                timestamp: Date().timeIntervalSince1970
            ))
        }
    }

    func skipBreak() {
        guard appState.timerState == .breakRunning || appState.timerState == .snoozeRunning else {
            return
        }
        // Apply locally immediately for responsiveness
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        endExtendedSession()
        // Clear synced payload so tick() uses local mode until Mac acknowledges
        lastSyncPayload = nil
        // Publish action to Mac via iCloud KVS
        if let syncManager {
            syncManager.publishWatchAction(SyncAction(
                action: .skipBreak,
                timestamp: Date().timeIntervalSince1970
            ))
        }
    }

    // MARK: - Public API: Remote State

    /// Handle an incoming sync payload from a remote device (Mac).
    /// Ignores echoes from the watch's own published state.
    func handleRemoteState(_ payload: SyncPayload) {
        guard payload.sourceDevice != "watch" else { return } // Ignore our own echoes
        lastSyncReceivedAt = Date().timeIntervalSince1970
        lastSyncPayload = payload
        updateOfflineStatus()
        applyPayload(payload)
    }

    // MARK: - Private: Sync

    /// Wire up callbacks for incoming state and settings from Mac.
    private func configureSyncCallbacks() {
        syncManager?.onTimerStateReceived = { [weak self] payload in
            Task { @MainActor in
                self?.handleRemoteState(payload)
            }
        }

        syncManager?.onSettingsReceived = { [weak self] remote in
            Task { @MainActor in
                self?.settings.applyRemoteSettings(remote)
            }
        }
    }

    /// Observe WatchSettings changes via Combine and publish to iCloud KVS.
    /// Skips publishing when the change originated from a remote sync
    /// (to prevent infinite publish -> receive -> publish loops).
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

    /// Apply a sync payload to update local state from synced timestamps.
    /// Computes current values based on elapsed time since the state change.
    private func applyPayload(_ payload: SyncPayload) {
        let elapsed = Date().timeIntervalSince1970 - payload.stateChangedAt
        let previousState = appState.timerState

        appState.timerState = payload.timerState

        switch payload.timerState {
        case .workRunning:
            // Don't extrapolate work elapsed from wall clock — Mac's idle-aware
            // timing pauses work counting during idle, so wall-clock extrapolation
            // drifts ahead. Just use the last synced value; it updates on every
            // Mac state transition (~1-5s latency).
            appState.workElapsedSeconds = payload.workElapsedAtChange
        case .workPaused:
            appState.workElapsedSeconds = payload.workElapsedAtChange
        case .breakRunning:
            appState.breakRemainingSeconds = max(0, payload.breakRemainingAtChange - Int(elapsed))
        case .snoozeRunning:
            appState.snoozeRemainingSeconds = max(0, payload.snoozeRemainingAtChange - Int(elapsed))
        }

        // Break start detection: when transitioning to breakRunning from a non-break state
        if payload.timerState == .breakRunning && previousState != .breakRunning {
            if !disableHardwareInteractions && settings.hapticEnabled {
                WKInterfaceDevice.current().play(.notification)
            }
            if !disableHardwareInteractions {
                startExtendedSession()
            }
        }

        // Break exit detection: end extended session when leaving breakRunning
        if previousState == .breakRunning && payload.timerState != .breakRunning {
            if !disableHardwareInteractions {
                endExtendedSession()
            }
        }
    }

    // MARK: - Private: Timer

    private func scheduleTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func tick() {
        updateOfflineStatus()
        if isSyncConfigured, !isOffline, let payload = lastSyncPayload {
            // Synced mode: recompute from the last received payload's timestamps
            applyPayload(payload)
        } else {
            // Local/offline mode: original independent tick logic
            switch appState.timerState {
            case .workRunning:
                handleWorkTick()
            case .workPaused:
                break
            case .breakRunning:
                handleBreakTick()
            case .snoozeRunning:
                handleSnoozeTick()
            }
        }
    }

    // MARK: - Private: Tick Handlers

    private func handleWorkTick() {
        appState.workElapsedSeconds += 1

        if appState.workElapsedSeconds >= settings.workDurationSeconds {
            triggerBreak()
        }
    }

    private func handleBreakTick() {
        if appState.breakRemainingSeconds > 0 {
            appState.breakRemainingSeconds -= 1
        }
        // When break reaches zero, do NOT auto-complete. The UI shows
        // BreakEndedView with escalating haptics and the user dismisses
        // manually (which calls skipBreak()). Auto-completing here would
        // race with the SwiftUI onChange observer — the timer state would
        // already be .workRunning before the view could detect break end.
    }

    private func handleSnoozeTick() {
        if appState.snoozeRemainingSeconds > 0 {
            appState.snoozeRemainingSeconds -= 1
        }
        if appState.snoozeRemainingSeconds <= 0 {
            triggerBreak()
        }
    }

    // MARK: - Private: State Transitions

    private func triggerBreak() {
        appState.breakRemainingSeconds = settings.breakDurationSeconds
        appState.timerState = .breakRunning

        guard !disableHardwareInteractions else { return }

        if settings.hapticEnabled {
            WKInterfaceDevice.current().play(.notification)
        }
        startExtendedSession()
    }

    private func completeBreak() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning

        guard !disableHardwareInteractions else { return }

        endExtendedSession()
        if settings.hapticEnabled {
            WKInterfaceDevice.current().play(.success)
        }
    }

    // MARK: - Private: Extended Runtime Session

    private func startExtendedSession() {
        guard !disableHardwareInteractions else { return }
        guard extendedSession == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.start()
        extendedSession = session
    }

    private func endExtendedSession() {
        guard !disableHardwareInteractions else { return }
        extendedSession?.invalidate()
        extendedSession = nil
    }
}
