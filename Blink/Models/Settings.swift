import Foundation
import SwiftUI

/// Centralized settings storage using UserDefaults via @AppStorage
///
/// Usage: Access via `Settings.shared` singleton
/// All properties automatically persist to UserDefaults
final class Settings: ObservableObject {

    // MARK: - Singleton

    static let shared = Settings()

    // MARK: - Timer Durations (in minutes, stored as Int)

    /// Work session duration in minutes (default: 25)
    @AppStorage("workDurationMinutes") var workDurationMinutes: Int = 25

    /// Break duration in minutes (default: 5)
    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5

    /// Snooze duration in minutes (default: 5)
    @AppStorage("snoozeDurationMinutes") var snoozeDurationMinutes: Int = 5

    // MARK: - Idle Thresholds (in seconds)

    /// Idle time below this is treated as "still working" (reading, thinking)
    /// Default: 60 seconds
    @AppStorage("idleIgnoreThreshold") var idleIgnoreThreshold: Int = 60

    /// Idle time at or above this triggers session reset on return
    /// Default: 300 seconds (5 minutes)
    @AppStorage("idleResetThreshold") var idleResetThreshold: Int = 300

    // MARK: - Display Settings

    /// How to display time in menu bar: "elapsed" or "remaining"
    @AppStorage("displayMode") private var displayModeRaw: String = DisplayMode.elapsed.rawValue

    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .elapsed }
        set { displayModeRaw = newValue.rawValue }
    }

    // MARK: - Feature Toggles

    /// Whether to play sound when break starts
    @AppStorage("soundEnabled") var soundEnabled: Bool = false

    /// Whether to lock screen when break completes (requires user to be idle)
    @AppStorage("lockScreenAfterBreak") var lockScreenAfterBreak: Bool = true

    /// Whether to launch app at login
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = true

    /// Whether user has completed first-launch onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // MARK: - Computed Properties (seconds)

    /// Work duration in seconds
    var workDurationSeconds: Int {
        workDurationMinutes * 60
    }

    /// Break duration in seconds
    var breakDurationSeconds: Int {
        breakDurationMinutes * 60
    }

    /// Snooze duration in seconds
    var snoozeDurationSeconds: Int {
        snoozeDurationMinutes * 60
    }

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Sync

    /// Timestamp of the last local settings change that was published.
    /// Used to prevent infinite sync loops: when we receive a remote settings
    /// payload that we ourselves published, we ignore it.
    var lastPublishedAt: TimeInterval = 0

    /// Timestamp of the last applied remote settings.
    /// Used for conflict resolution: only apply if the remote timestamp is newer.
    private(set) var lastAppliedRemoteAt: TimeInterval = 0

    /// Timestamp of the last remote settings apply.
    /// The debounced Combine observer checks this to avoid re-publishing
    /// settings that arrived from sync (isApplyingRemote was insufficient
    /// because defer clears it before the 500ms debounce fires).
    private(set) var lastRemoteApplyAt: TimeInterval = 0

    /// Snapshot of last published synced values. Prevents redundant publishes
    /// when only non-synced properties (soundEnabled, etc.) change.
    private var lastPublishedSnapshot: (Int, Int, Int, String) = (0, 0, 0, "")

    /// Publish current settings to iCloud KVS for the watch to receive.
    /// Skips the publish if synced values haven't changed since last publish.
    func publishToSync(_ syncManager: any SyncManagerProtocol) {
        let current = (workDurationMinutes, breakDurationMinutes, snoozeDurationMinutes, displayMode.rawValue)
        guard current != lastPublishedSnapshot else { return }
        lastPublishedSnapshot = current

        let now = Date().timeIntervalSince1970
        let syncSettings = SyncSettings(
            workDurationMinutes: workDurationMinutes,
            breakDurationMinutes: breakDurationMinutes,
            snoozeDurationMinutes: snoozeDurationMinutes,
            displayMode: displayMode.rawValue,
            changedAt: now
        )
        lastPublishedAt = now
        syncManager.publishSettings(syncSettings)
    }

    /// Apply settings received from the watch (or another device).
    /// Only applies if the remote timestamp is newer than the last applied remote settings.
    /// Returns true if settings were applied, false if they were ignored (stale).
    @discardableResult
    func applyRemoteSettings(_ remote: SyncSettings) -> Bool {
        // Reject if remote is older than what we last applied or last published locally
        guard remote.changedAt > lastAppliedRemoteAt,
              remote.changedAt > lastPublishedAt else { return false }

        lastRemoteApplyAt = Date().timeIntervalSince1970
        lastAppliedRemoteAt = remote.changedAt
        workDurationMinutes = remote.workDurationMinutes
        breakDurationMinutes = remote.breakDurationMinutes
        snoozeDurationMinutes = remote.snoozeDurationMinutes
        displayMode = DisplayMode(rawValue: remote.displayMode) ?? .elapsed
        // Update snapshot so non-synced property changes don't trigger re-publish
        lastPublishedSnapshot = (workDurationMinutes, breakDurationMinutes, snoozeDurationMinutes, displayMode.rawValue)
        return true
    }

    // MARK: - Reset

    /// Reset all settings to defaults (useful for testing)
    func resetToDefaults() {
        workDurationMinutes = 25
        breakDurationMinutes = 5
        snoozeDurationMinutes = 5
        idleIgnoreThreshold = 60
        idleResetThreshold = 300
        displayModeRaw = DisplayMode.elapsed.rawValue
        soundEnabled = false
        lockScreenAfterBreak = true
        launchAtLogin = true
        hasCompletedOnboarding = false
        lastPublishedAt = 0
        lastAppliedRemoteAt = 0
        lastRemoteApplyAt = 0
        lastPublishedSnapshot = (0, 0, 0, "")
    }
}
