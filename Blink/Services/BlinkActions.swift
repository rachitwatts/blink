import Foundation

/// Actions that can be triggered via URL scheme, AppleScript, or Shortcuts
enum BlinkAction: String {
    case takeBreak = "break"
    case snooze = "snooze"
    case restart = "restart"
    case status = "status"
}

/// Result of executing a BlinkAction
struct BlinkActionResult {
    let success: Bool
    let message: String
}

/// Centralized action handler for external automation
///
/// All external entry points (URL scheme, AppleScript, Shortcuts) funnel
/// through this class so the guard logic lives in one place.
///
/// Usage:
/// ```
/// let result = BlinkActions.execute(.takeBreak)
/// print(result.message) // "Break started"
/// ```
enum BlinkActions {

    /// Execute an action and return a result
    @MainActor
    static func execute(_ action: BlinkAction) -> BlinkActionResult {
        let appState = AppState.shared
        let engine = TimerEngine.shared

        switch action {
        case .takeBreak:
            let state = appState.timerState
            guard state == .workRunning || state == .workPaused || state == .snoozeRunning else {
                return BlinkActionResult(
                    success: false,
                    message: "Cannot start break in state: \(state.description)"
                )
            }
            engine.startBreakNow()
            return BlinkActionResult(success: true, message: "Break started")

        case .snooze:
            guard appState.timerState == .breakRunning else {
                return BlinkActionResult(
                    success: false,
                    message: "Cannot snooze in state: \(appState.timerState.description)"
                )
            }
            engine.snoozeBreak()
            return BlinkActionResult(success: true, message: "Break snoozed")

        case .restart:
            engine.restartSession()
            return BlinkActionResult(success: true, message: "Session restarted")

        case .status:
            let state = appState.timerState
            let time = appState.displayTime
            let message: String

            switch state {
            case .workRunning:
                message = "Working - \(time) elapsed"
            case .workPaused:
                message = "Paused - \(time) elapsed"
            case .breakRunning:
                message = "Break - \(time) remaining"
            case .snoozeRunning:
                message = "Snoozed - \(time) remaining"
            }

            return BlinkActionResult(success: true, message: message)
        }
    }
}
