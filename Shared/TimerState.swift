import Foundation

/// Represents the current state of the Blink timer
/// Shared between macOS and watchOS targets
enum TimerState: String, Equatable, CaseIterable, Codable {
    /// User is working, timer counting up
    case workRunning

    /// User paused the timer manually
    case workPaused

    /// Break overlay is visible, timer counting down
    case breakRunning

    /// Break was snoozed, overlay hidden, timer counting down to re-show
    case snoozeRunning

    /// Human-readable description for debugging
    var description: String {
        switch self {
        case .workRunning: return "Working"
        case .workPaused: return "Paused"
        case .breakRunning: return "Break"
        case .snoozeRunning: return "Snoozed"
        }
    }

    /// Whether the timer should be actively counting
    var isActive: Bool {
        switch self {
        case .workRunning, .breakRunning, .snoozeRunning:
            return true
        case .workPaused:
            return false
        }
    }

    /// Whether the break overlay should be visible
    var shouldShowOverlay: Bool {
        self == .breakRunning
    }
}
