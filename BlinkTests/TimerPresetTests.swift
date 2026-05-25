import XCTest
@testable import Blink

final class TimerPresetTests: XCTestCase {

    override func setUp() {
        Settings.shared.resetToDefaults()
    }

    // MARK: - Preset Values

    func testClassicPreset() {
        let preset = TimerPreset.classic
        XCTAssertEqual(preset.workMinutes, 20)
        XCTAssertEqual(preset.breakMinutes, 5)
        XCTAssertEqual(preset.displayName, "Classic")
    }

    func testPomodoroPreset() {
        let preset = TimerPreset.pomodoro
        XCTAssertEqual(preset.workMinutes, 25)
        XCTAssertEqual(preset.breakMinutes, 5)
        XCTAssertEqual(preset.displayName, "Pomodoro")
    }

    func testDeskTimePreset() {
        let preset = TimerPreset.deskTime
        XCTAssertEqual(preset.workMinutes, 52)
        XCTAssertEqual(preset.breakMinutes, 17)
        XCTAssertEqual(preset.displayName, "DeskTime")
    }

    func testUltradianPreset() {
        let preset = TimerPreset.ultradian
        XCTAssertEqual(preset.workMinutes, 90)
        XCTAssertEqual(preset.breakMinutes, 20)
        XCTAssertEqual(preset.displayName, "Ultradian")
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
