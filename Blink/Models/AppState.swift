import Foundation
import SwiftUI
import Combine

/// Central observable state for the entire app
///
/// Usage: Access via `AppState.shared` singleton
/// All @Published properties trigger UI updates automatically
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Timer State

    /// Current state of the timer state machine
    @Published var timerState: TimerState = .workRunning

    /// Seconds elapsed in current work session (0 to workDurationSeconds)
    @Published var workElapsedSeconds: Int = 0

    /// Seconds remaining in current break (breakDurationSeconds to 0)
    @Published var breakRemainingSeconds: Int = 0

    /// Seconds remaining in snooze period (snoozeDurationSeconds to 0)
    @Published var snoozeRemainingSeconds: Int = 0

    // MARK: - UI State

    /// Whether the break overlay windows should be visible
    @Published var isOverlayVisible: Bool = false

    /// Whether the settings window is currently shown
    @Published var isSettingsVisible: Bool = false

    /// Whether the menu bar is flashing the eye health score
    @Published var showingScore: Bool = false

    // MARK: - Dependencies

    /// Reference to settings for computing display values
    let settings = Settings.shared

    // MARK: - Computed Properties

    /// The time to display based on current state and display mode
    var displayTime: String {
        switch timerState {
        case .workRunning, .workPaused:
            // During work, show either elapsed or remaining based on settings
            let seconds: Int
            if settings.displayMode == .elapsed {
                seconds = workElapsedSeconds
            } else {
                seconds = max(0, settings.workDurationSeconds - workElapsedSeconds)
            }
            return formatTime(seconds)

        case .breakRunning:
            // During break, always show remaining time
            return formatTime(breakRemainingSeconds)

        case .snoozeRunning:
            // During snooze, show snooze remaining (overlay is hidden)
            return formatTime(snoozeRemainingSeconds)
        }
    }

    /// Full menu bar title including pause indicator
    var menuBarTitle: String {
        switch timerState {
        case .workPaused:
            return "⏸ \(displayTime)"
        default:
            return displayTime
        }
    }

    /// Progress through current work session (0.0 to 1.0)
    var workProgress: Double {
        guard settings.workDurationSeconds > 0 else { return 0 }
        return Double(workElapsedSeconds) / Double(settings.workDurationSeconds)
    }

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Helpers

    /// Format seconds as "mm:ss" string
    /// - Parameter totalSeconds: Total seconds to format
    /// - Returns: Formatted string like "05:32" or "125:00" for > 99 minutes
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes >= 100 {
            // Handle overflow case (> 99:59)
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Reset

    /// Reset all state to initial values (useful for testing)
    func reset() {
        timerState = .workRunning
        workElapsedSeconds = 0
        breakRemainingSeconds = 0
        snoozeRemainingSeconds = 0
        isOverlayVisible = false
        isSettingsVisible = false
    }
}
