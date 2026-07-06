import Foundation
import SwiftUI
import Combine

/// Centralized settings storage using UserDefaults via @AppStorage
///
/// Usage: Access via `Settings.shared` singleton
/// All properties automatically persist to UserDefaults
final class Settings: ObservableObject {

    // @AppStorage doesn't synthesize ObservableObject; provide it explicitly
    let objectWillChange = ObservableObjectPublisher()

    // MARK: - Singleton

    static let shared = Settings()

    // MARK: - Timer Preset

    @AppStorage("timerPreset") private var timerPresetRaw: String = TimerPreset.pomodoro.rawValue

    var timerPreset: TimerPreset {
        get { TimerPreset(rawValue: timerPresetRaw) ?? .pomodoro }
        set { timerPresetRaw = newValue.rawValue }
    }

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

    // MARK: - Nudge Settings

    /// Master toggle for micro nudges (default: on)
    @AppStorage("nudgesEnabled") var nudgesEnabled: Bool = true

    /// Interval between nudges in minutes (default: 8)
    @AppStorage("nudgeIntervalMinutes") var nudgeIntervalMinutes: Int = 8

    /// Individual nudge type toggles (all default: true when nudges enabled)
    @AppStorage("nudgeBlinkEnabled") var nudgeBlinkEnabled: Bool = true
    @AppStorage("nudgePostureEnabled") var nudgePostureEnabled: Bool = true
    @AppStorage("nudgeStretchEnabled") var nudgeStretchEnabled: Bool = true

    // MARK: - Break Style

    @AppStorage("breakStyle") private var breakStyleRaw: String = BreakStyle.gentle.rawValue

    var breakStyle: BreakStyle {
        get { BreakStyle(rawValue: breakStyleRaw) ?? .gentle }
        set { breakStyleRaw = newValue.rawValue }
    }

    // MARK: - Integrations

    /// Whether to detect active calls (mic/camera) and adapt break delivery
    @AppStorage("callDetectionEnabled") var callDetectionEnabled: Bool = true

    /// Whether calendar integration is enabled for early break shifting
    @AppStorage("calendarIntegrationEnabled") var calendarIntegrationEnabled: Bool = false

    /// Comma-separated calendar identifiers to watch (empty = all)
    @AppStorage("watchedCalendarIdentifiers") var watchedCalendarIdentifiers: String = ""

    /// Minutes before a calendar event to shift breaks earlier
    @AppStorage("calendarLeadTimeMinutes") var calendarLeadTimeMinutes: Int = 3

    // MARK: - Weekly Summary

    @AppStorage("weeklySummaryEnabled") var weeklySummaryEnabled: Bool = true

    /// Day of week (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    @AppStorage("weeklySummaryDay") var weeklySummaryDay: Int = 2

    /// Hour of day (0-23) for weekly summary notification
    @AppStorage("weeklySummaryHour") var weeklySummaryHour: Int = 9

    /// Minute of hour for weekly summary notification
    @AppStorage("weeklySummaryMinute") var weeklySummaryMinute: Int = 0

    // MARK: - Break Content

    @AppStorage("breakContentMode") private var breakContentModeRaw: String = BreakContentMode.guided.rawValue

    var breakContentMode: BreakContentMode {
        get { BreakContentMode(rawValue: breakContentModeRaw) ?? .guided }
        set { breakContentModeRaw = newValue.rawValue }
    }

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

    /// Nudge interval in seconds
    var nudgeIntervalSeconds: Int {
        nudgeIntervalMinutes * 60
    }

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern.
        // Wrappers default to UserDefaults.standard via their declarations.
    }

    // MARK: - Backing Store (test isolation)

    /// Re-point every persisted (@AppStorage) property at the given store.
    ///
    /// Production always uses `.standard` (the wrapper declarations bind it).
    /// Tests inject an ephemeral `UserDefaults(suiteName:)` so they never
    /// touch the real app domain and can run independently. Single source of
    /// truth for the persisted-key list — adding a key here is the only place
    /// it needs to be wired.
    private func bindAppStorage(to defaults: UserDefaults) {
        _timerPresetRaw = AppStorage(wrappedValue: TimerPreset.pomodoro.rawValue, "timerPreset", store: defaults)
        _workDurationMinutes = AppStorage(wrappedValue: 25, "workDurationMinutes", store: defaults)
        _breakDurationMinutes = AppStorage(wrappedValue: 5, "breakDurationMinutes", store: defaults)
        _snoozeDurationMinutes = AppStorage(wrappedValue: 5, "snoozeDurationMinutes", store: defaults)
        _idleIgnoreThreshold = AppStorage(wrappedValue: 60, "idleIgnoreThreshold", store: defaults)
        _idleResetThreshold = AppStorage(wrappedValue: 300, "idleResetThreshold", store: defaults)
        _displayModeRaw = AppStorage(wrappedValue: DisplayMode.elapsed.rawValue, "displayMode", store: defaults)
        _soundEnabled = AppStorage(wrappedValue: false, "soundEnabled", store: defaults)
        _lockScreenAfterBreak = AppStorage(wrappedValue: true, "lockScreenAfterBreak", store: defaults)
        _launchAtLogin = AppStorage(wrappedValue: true, "launchAtLogin", store: defaults)
        _hasCompletedOnboarding = AppStorage(wrappedValue: false, "hasCompletedOnboarding", store: defaults)
        _nudgesEnabled = AppStorage(wrappedValue: true, "nudgesEnabled", store: defaults)
        _nudgeIntervalMinutes = AppStorage(wrappedValue: 8, "nudgeIntervalMinutes", store: defaults)
        _nudgeBlinkEnabled = AppStorage(wrappedValue: true, "nudgeBlinkEnabled", store: defaults)
        _nudgePostureEnabled = AppStorage(wrappedValue: true, "nudgePostureEnabled", store: defaults)
        _nudgeStretchEnabled = AppStorage(wrappedValue: true, "nudgeStretchEnabled", store: defaults)
        _breakStyleRaw = AppStorage(wrappedValue: BreakStyle.gentle.rawValue, "breakStyle", store: defaults)
        _callDetectionEnabled = AppStorage(wrappedValue: true, "callDetectionEnabled", store: defaults)
        _calendarIntegrationEnabled = AppStorage(wrappedValue: false, "calendarIntegrationEnabled", store: defaults)
        _watchedCalendarIdentifiers = AppStorage(wrappedValue: "", "watchedCalendarIdentifiers", store: defaults)
        _calendarLeadTimeMinutes = AppStorage(wrappedValue: 3, "calendarLeadTimeMinutes", store: defaults)
        _weeklySummaryEnabled = AppStorage(wrappedValue: true, "weeklySummaryEnabled", store: defaults)
        _weeklySummaryDay = AppStorage(wrappedValue: 2, "weeklySummaryDay", store: defaults)
        _weeklySummaryHour = AppStorage(wrappedValue: 9, "weeklySummaryHour", store: defaults)
        _weeklySummaryMinute = AppStorage(wrappedValue: 0, "weeklySummaryMinute", store: defaults)
        _breakContentModeRaw = AppStorage(wrappedValue: BreakContentMode.guided.rawValue, "breakContentMode", store: defaults)
    }

    /// Source of the current time for sync timestamps. Production uses the
    /// wall clock; tests inject a `MutableClock` for deterministic loop-guard
    /// and conflict-resolution behavior.
    #if DEBUG
    /// Point all persisted settings at an isolated store for testing.
    /// `BlinkTestCase` calls this in `setUp` with a fresh ephemeral suite,
    /// so each test sees default values and never mutates real user prefs.
    func useStoreForTesting(_ defaults: UserDefaults) {
        bindAppStorage(to: defaults)
    }
    #endif

    // MARK: - Reset

    /// Reset all settings to defaults (useful for testing)
    func resetToDefaults() {
        timerPresetRaw = TimerPreset.pomodoro.rawValue
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
        nudgesEnabled = true
        nudgeIntervalMinutes = 8
        nudgeBlinkEnabled = true
        nudgePostureEnabled = true
        nudgeStretchEnabled = true
        breakStyleRaw = BreakStyle.gentle.rawValue
        breakContentModeRaw = BreakContentMode.guided.rawValue
        weeklySummaryEnabled = true
        weeklySummaryDay = 2
        weeklySummaryHour = 9
        weeklySummaryMinute = 0
        callDetectionEnabled = true
        calendarIntegrationEnabled = false
        watchedCalendarIdentifiers = ""
        calendarLeadTimeMinutes = 3
    }
}
