import Foundation
import SwiftUI

/// Watch-specific settings storage using UserDefaults via @AppStorage
///
/// Mirrors the macOS Settings with watch-relevant properties only.
/// The watch app runs independently with its own local settings.
final class WatchSettings: ObservableObject {

    // MARK: - Singleton

    static let shared = WatchSettings()

    // MARK: - Timer Durations (in minutes)

    /// Work session duration in minutes (default: 25)
    @AppStorage("workDurationMinutes") var workDurationMinutes: Int = 25

    /// Break duration in minutes (default: 5)
    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5

    /// Snooze duration in minutes (default: 5)
    @AppStorage("snoozeDurationMinutes") var snoozeDurationMinutes: Int = 5

    // MARK: - Display Settings

    /// How to display time: "elapsed" or "remaining"
    @AppStorage("displayMode") private var displayModeRaw: String = DisplayMode.elapsed.rawValue

    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .elapsed }
        set { displayModeRaw = newValue.rawValue }
    }

    // MARK: - Feature Toggles

    /// Whether to use haptic feedback for break notifications
    @AppStorage("hapticEnabled") var hapticEnabled: Bool = true

    // MARK: - Computed Properties (seconds)

    var workDurationSeconds: Int { workDurationMinutes * 60 }
    var breakDurationSeconds: Int { breakDurationMinutes * 60 }
    var snoozeDurationSeconds: Int { snoozeDurationMinutes * 60 }

    // MARK: - Initialization

    private init() {}

    // MARK: - Sync

    /// Timestamp of the last local settings change that was published.
    /// Used to prevent infinite sync loops.
    var lastPublishedAt: TimeInterval = 0

    /// Timestamp of the last applied remote settings.
    /// Used for conflict resolution: only apply if the remote timestamp is newer.
    private(set) var lastAppliedRemoteAt: TimeInterval = 0

    /// Whether we are currently applying remote settings.
    /// Used to suppress re-publishing settings that arrived from sync.
    private(set) var isApplyingRemote: Bool = false

    /// Publish current settings to iCloud KVS for the Mac to receive.
    func publishToSync(_ syncManager: any SyncManagerProtocol) {
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

    /// Apply settings received from the Mac (or another device) via iCloud KVS.
    /// Only applies if the remote timestamp is newer than the last applied remote settings.
    /// Returns true if settings were applied, false if they were ignored (stale).
    @discardableResult
    func applyRemoteSettings(_ remote: SyncSettings) -> Bool {
        // Reject if remote is older than what we last applied or last published locally
        guard remote.changedAt > lastAppliedRemoteAt,
              remote.changedAt > lastPublishedAt else { return false }

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        lastAppliedRemoteAt = remote.changedAt
        workDurationMinutes = remote.workDurationMinutes
        breakDurationMinutes = remote.breakDurationMinutes
        snoozeDurationMinutes = remote.snoozeDurationMinutes
        displayMode = DisplayMode(rawValue: remote.displayMode) ?? .elapsed
        return true
    }

    // MARK: - Reset

    func resetToDefaults() {
        workDurationMinutes = 25
        breakDurationMinutes = 5
        snoozeDurationMinutes = 5
        displayModeRaw = DisplayMode.elapsed.rawValue
        hapticEnabled = true
        lastPublishedAt = 0
        lastAppliedRemoteAt = 0
        isApplyingRemote = false
    }
}
