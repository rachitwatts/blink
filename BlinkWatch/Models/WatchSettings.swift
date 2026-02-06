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

    // MARK: - Reset

    func resetToDefaults() {
        workDurationMinutes = 25
        breakDurationMinutes = 5
        snoozeDurationMinutes = 5
        displayModeRaw = DisplayMode.elapsed.rawValue
        hapticEnabled = true
    }
}
