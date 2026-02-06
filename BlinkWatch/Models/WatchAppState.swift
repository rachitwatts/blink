import Foundation
import SwiftUI
import Combine

/// Observable state for the watch app
///
/// Simplified version of the macOS AppState, tailored for watchOS.
/// No overlay management needed — the watch uses view navigation instead.
@MainActor
final class WatchAppState: ObservableObject {

    // MARK: - Singleton

    static let shared = WatchAppState()

    // MARK: - Timer State

    @Published var timerState: TimerState = .workRunning
    @Published var workElapsedSeconds: Int = 0
    @Published var breakRemainingSeconds: Int = 0
    @Published var snoozeRemainingSeconds: Int = 0

    // MARK: - Dependencies

    let settings = WatchSettings.shared

    // MARK: - Computed Properties

    /// The time to display based on current state and display mode
    var displayTime: String {
        switch timerState {
        case .workRunning, .workPaused:
            let seconds: Int
            if settings.displayMode == .elapsed {
                seconds = workElapsedSeconds
            } else {
                seconds = max(0, settings.workDurationSeconds - workElapsedSeconds)
            }
            return TimeFormatting.formatTime(seconds)

        case .breakRunning:
            return TimeFormatting.formatTime(breakRemainingSeconds)

        case .snoozeRunning:
            return TimeFormatting.formatTime(snoozeRemainingSeconds)
        }
    }

    /// Progress through current work session (0.0 to 1.0)
    var workProgress: Double {
        guard settings.workDurationSeconds > 0 else { return 0 }
        return min(1.0, Double(workElapsedSeconds) / Double(settings.workDurationSeconds))
    }

    /// Progress through current break (0.0 to 1.0)
    var breakProgress: Double {
        guard settings.breakDurationSeconds > 0 else { return 0 }
        let elapsed = settings.breakDurationSeconds - breakRemainingSeconds
        return min(1.0, Double(elapsed) / Double(settings.breakDurationSeconds))
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Reset

    func reset() {
        timerState = .workRunning
        workElapsedSeconds = 0
        breakRemainingSeconds = 0
        snoozeRemainingSeconds = 0
    }
}
