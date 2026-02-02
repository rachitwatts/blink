import XCTest
@testable import Blink

/// Tests for Settings persistence
final class SettingsTests: XCTestCase {

    // MARK: - Setup

    override func setUp() {
        // Reset to defaults before each test
        Settings.shared.resetToDefaults()
    }

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
