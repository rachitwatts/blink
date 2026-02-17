import Foundation

/// AppleScript command: `tell application "Blink" to take break`
class TakeBreakCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            BlinkActions.execute(.takeBreak).message
        }
    }
}

/// AppleScript command: `tell application "Blink" to snooze`
class SnoozeBreakCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            BlinkActions.execute(.snooze).message
        }
    }
}

/// AppleScript command: `tell application "Blink" to restart timer`
class RestartTimerCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            BlinkActions.execute(.restart).message
        }
    }
}

/// AppleScript command: `tell application "Blink" to get status`
class GetStatusCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        MainActor.assumeIsolated {
            BlinkActions.execute(.status).message
        }
    }
}
