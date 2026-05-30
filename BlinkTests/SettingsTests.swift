import XCTest
@testable import Blink

/// Tests for Settings persistence.
///
/// Inherits `BlinkTestCase`, which gives each test an isolated, ephemeral
/// `UserDefaults` suite — so these tests no longer mutate the real app domain
/// and start from default values automatically (no manual reset needed).
final class SettingsTests: BlinkTestCase {

    // MARK: - Default Values Tests

    func testDefaultValues() {
        let settings = Settings.shared

        XCTAssertEqual(settings.workDurationMinutes, 25)
        XCTAssertEqual(settings.breakDurationMinutes, 5)
        XCTAssertEqual(settings.snoozeDurationMinutes, 5)
        XCTAssertEqual(settings.idleIgnoreThreshold, 60)
        XCTAssertEqual(settings.idleResetThreshold, 300)
        XCTAssertEqual(settings.displayMode, .elapsed)
        XCTAssertFalse(settings.soundEnabled)
        XCTAssertTrue(settings.launchAtLogin)
    }

    // MARK: - Computed Properties Tests

    func testWorkDurationSeconds() {
        let settings = Settings.shared

        settings.workDurationMinutes = 30

        XCTAssertEqual(settings.workDurationSeconds, 1800)
    }

    func testBreakDurationSeconds() {
        let settings = Settings.shared

        settings.breakDurationMinutes = 10

        XCTAssertEqual(settings.breakDurationSeconds, 600)
    }

    func testSnoozeDurationSeconds() {
        let settings = Settings.shared

        settings.snoozeDurationMinutes = 8

        XCTAssertEqual(settings.snoozeDurationSeconds, 480)
    }

    func testDisplayModeRoundTrip() {
        let settings = Settings.shared

        settings.displayMode = .remaining
        XCTAssertEqual(settings.displayMode, .remaining)

        settings.displayMode = .elapsed
        XCTAssertEqual(settings.displayMode, .elapsed)
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        let settings = Settings.shared

        // Change some values
        settings.workDurationMinutes = 50
        settings.soundEnabled = true
        settings.displayMode = .remaining

        // Reset
        settings.resetToDefaults()

        // Verify defaults restored
        XCTAssertEqual(settings.workDurationMinutes, 25)
        XCTAssertFalse(settings.soundEnabled)
        XCTAssertEqual(settings.displayMode, .elapsed)
    }
}
