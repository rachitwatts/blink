import XCTest
@testable import Blink

final class TimerPresetTests: BlinkTestCase {

    // MARK: - Preset Values

    func testClassicPreset() {
        let preset = TimerPreset.classic
        XCTAssertEqual(preset.workMinutes, 20)
        XCTAssertEqual(preset.breakMinutes, 5)
        // Assert the durations (the contract), not the display copy — coupling
        // to the exact name string is what broke this test in #46.
        XCTAssertFalse(preset.displayName.isEmpty)
    }

    func testPomodoroPreset() {
        let preset = TimerPreset.pomodoro
        XCTAssertEqual(preset.workMinutes, 25)
        XCTAssertEqual(preset.breakMinutes, 5)
        XCTAssertFalse(preset.displayName.isEmpty)
    }

    func testDeskTimePreset() {
        let preset = TimerPreset.deskTime
        XCTAssertEqual(preset.workMinutes, 52)
        XCTAssertEqual(preset.breakMinutes, 17)
        XCTAssertFalse(preset.displayName.isEmpty)
    }

    func testUltradianPreset() {
        let preset = TimerPreset.ultradian
        XCTAssertEqual(preset.workMinutes, 90)
        XCTAssertEqual(preset.breakMinutes, 20)
        XCTAssertFalse(preset.displayName.isEmpty)
    }

    // MARK: - Matching

    func testMatchingFindsPomodoro() {
        XCTAssertEqual(TimerPreset.matching(work: 25, breakMins: 5), .pomodoro)
    }

    func testMatchingFindsDeskTime() {
        XCTAssertEqual(TimerPreset.matching(work: 52, breakMins: 17), .deskTime)
    }

    func testMatchingReturnsCustomForUnknown() {
        XCTAssertEqual(TimerPreset.matching(work: 33, breakMins: 7), .custom)
    }

    func testMatchingPartialMatchIsCustom() {
        // Work matches pomodoro but break doesn't
        XCTAssertEqual(TimerPreset.matching(work: 25, breakMins: 10), .custom)
    }

    // MARK: - Settings Integration

    func testDefaultPresetIsPomodoro() {
        XCTAssertEqual(Settings.shared.timerPreset, .pomodoro)
    }

    func testPresetRoundTrip() {
        Settings.shared.timerPreset = .ultradian
        XCTAssertEqual(Settings.shared.timerPreset, .ultradian)
    }

    func testResetRestoresDefaultPreset() {
        Settings.shared.timerPreset = .deskTime
        Settings.shared.resetToDefaults()
        XCTAssertEqual(Settings.shared.timerPreset, .pomodoro)
    }
}
