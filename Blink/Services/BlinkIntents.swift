import AppIntents

/// Shortcuts intent: Start a break immediately
struct TakeBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Take Break"
    static var description = IntentDescription("Start an eye break immediately.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let result = BlinkActions.execute(.takeBreak)
        return .result(value: result.message)
    }
}

/// Shortcuts intent: Snooze the current break
struct SnoozeBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Break"
    static var description = IntentDescription("Snooze the current break.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let result = BlinkActions.execute(.snooze)
        return .result(value: result.message)
    }
}

/// Shortcuts intent: Restart the work session
struct RestartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Restart Timer"
    static var description = IntentDescription("Restart the work session from zero.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let result = BlinkActions.execute(.restart)
        return .result(value: result.message)
    }
}

/// Shortcuts intent: Get current timer status
struct GetStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Blink Status"
    static var description = IntentDescription("Get the current timer state and remaining time.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let result = BlinkActions.execute(.status)
        return .result(value: result.message)
    }
}

/// Provides Blink shortcuts to the Shortcuts app
struct BlinkShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TakeBreakIntent(),
            phrases: [
                "Take a break with \(.applicationName)",
                "Start a break in \(.applicationName)"
            ],
            shortTitle: "Take Break",
            systemImageName: "eye"
        )
        AppShortcut(
            intent: SnoozeBreakIntent(),
            phrases: [
                "Snooze \(.applicationName) break",
                "Snooze break in \(.applicationName)"
            ],
            shortTitle: "Snooze Break",
            systemImageName: "moon.zzz"
        )
        AppShortcut(
            intent: RestartTimerIntent(),
            phrases: [
                "Restart \(.applicationName) timer",
                "Reset \(.applicationName) timer"
            ],
            shortTitle: "Restart Timer",
            systemImageName: "arrow.counterclockwise"
        )
        AppShortcut(
            intent: GetStatusIntent(),
            phrases: [
                "Get \(.applicationName) status",
                "How much time left in \(.applicationName)"
            ],
            shortTitle: "Get Status",
            systemImageName: "clock"
        )
    }
}
