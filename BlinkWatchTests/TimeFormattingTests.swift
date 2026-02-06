import XCTest
@testable import BlinkWatch

/// Tests for shared TimeFormatting utility
final class TimeFormattingTests: XCTestCase {

    func testFormatZero() {
        XCTAssertEqual(TimeFormatting.formatTime(0), "00:00")
    }

    func testFormatOneMinute() {
        XCTAssertEqual(TimeFormatting.formatTime(60), "01:00")
    }

    func testFormatMixedMinutesSeconds() {
        XCTAssertEqual(TimeFormatting.formatTime(125), "02:05")
    }

    func testFormatMaxTwoDigitMinutes() {
        XCTAssertEqual(TimeFormatting.formatTime(5999), "99:59")
    }

    func testFormatOverflowMinutes() {
        XCTAssertEqual(TimeFormatting.formatTime(6000), "100:00")
    }

    func testFormatLargeValue() {
        XCTAssertEqual(TimeFormatting.formatTime(7261), "121:01")
    }

    func testFormatFiveMinutes() {
        XCTAssertEqual(TimeFormatting.formatTime(300), "05:00")
    }

    func testFormatTwentyFiveMinutes() {
        XCTAssertEqual(TimeFormatting.formatTime(1500), "25:00")
    }
}
