import Foundation
import SwiftUI

/// Display mode for the menu bar timer
enum DisplayMode: String, CaseIterable, Identifiable {
    case elapsed = "elapsed"
    case remaining = "remaining"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .elapsed: return "Elapsed"
        case .remaining: return "Remaining"
        }
    }
}

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
        launchAtLogin = true
        hasCompletedOnboarding = false
    }
}
