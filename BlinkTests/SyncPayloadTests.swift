import XCTest
@testable import Blink

/// Tests for the shared sync data models: SyncPayload, SyncSettings, SyncAction.
/// Verifies Codable round-trips and timestamp-based counter computation.
final class SyncPayloadTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - SyncPayload Round-Trip

    func testSyncPayloadRoundTrip() throws {
        let original = SyncPayload(
            timerState: .breakRunning,
            stateChangedAt: 1700000000.0,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 300,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncPayload.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testSyncPayloadRoundTripAllStates() throws {
        let states: [TimerState] = [.workRunning, .workPaused, .breakRunning, .snoozeRunning]

        for state in states {
            let original = SyncPayload(
                timerState: state,
                stateChangedAt: Date().timeIntervalSince1970,
                workElapsedAtChange: 600,
                breakRemainingAtChange: 120,
                snoozeRemainingAtChange: 60,
                sourceDevice: "watch"
            )

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SyncPayload.self, from: data)

            XCTAssertEqual(decoded, original, "Round-trip failed for state: \(state)")
        }
    }

    func testSyncPayloadPreservesAllFields() throws {
        let original = SyncPayload(
            timerState: .snoozeRunning,
            stateChangedAt: 1700000000.5,
            workElapsedAtChange: 999,
            breakRemainingAtChange: 42,
            snoozeRemainingAtChange: 180,
            sourceDevice: "mac"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncPayload.self, from: data)

        XCTAssertEqual(decoded.timerState, .snoozeRunning)
        XCTAssertEqual(decoded.stateChangedAt, 1700000000.5, accuracy: 0.001)
        XCTAssertEqual(decoded.workElapsedAtChange, 999)
        XCTAssertEqual(decoded.breakRemainingAtChange, 42)
        XCTAssertEqual(decoded.snoozeRemainingAtChange, 180)
        XCTAssertEqual(decoded.sourceDevice, "mac")
    }

    // MARK: - SyncSettings Round-Trip

    func testSyncSettingsRoundTrip() throws {
        let original = SyncSettings(
            workDurationMinutes: 30,
            breakDurationMinutes: 10,
            snoozeDurationMinutes: 3,
            displayMode: "remaining",
            changedAt: 1700000000.0
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testSyncSettingsPreservesAllFields() throws {
        let original = SyncSettings(
            workDurationMinutes: 45,
            breakDurationMinutes: 15,
            snoozeDurationMinutes: 7,
            displayMode: "elapsed",
            changedAt: 1700000001.123
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncSettings.self, from: data)

        XCTAssertEqual(decoded.workDurationMinutes, 45)
        XCTAssertEqual(decoded.breakDurationMinutes, 15)
        XCTAssertEqual(decoded.snoozeDurationMinutes, 7)
        XCTAssertEqual(decoded.displayMode, "elapsed")
        XCTAssertEqual(decoded.changedAt, 1700000001.123, accuracy: 0.001)
    }

    // MARK: - SyncAction Round-Trip

    func testSyncActionSnoozeRoundTrip() throws {
        let original = SyncAction(
            action: .snooze,
            timestamp: 1700000000.0
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncAction.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testSyncActionSkipBreakRoundTrip() throws {
        let original = SyncAction(
            action: .skipBreak,
            timestamp: 1700000000.0
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncAction.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testSyncActionPreservesFields() throws {
        let original = SyncAction(
            action: .snooze,
            timestamp: 1700000005.789
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SyncAction.self, from: data)

        XCTAssertEqual(decoded.action, .snooze)
        XCTAssertEqual(decoded.timestamp, 1700000005.789, accuracy: 0.001)
    }

    // MARK: - Timestamp-Based Counter Computation

    func testWorkRunningCounterComputation() {
        // Given: Mac entered workRunning 10 seconds ago with 600 seconds elapsed
        let stateChangedAt = Date().timeIntervalSince1970 - 10
        let payload = SyncPayload(
            timerState: .workRunning,
            stateChangedAt: stateChangedAt,
            workElapsedAtChange: 600,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        // When: we compute current values
        let elapsed = Date().timeIntervalSince1970 - payload.stateChangedAt
        let currentWorkElapsed = payload.workElapsedAtChange + Int(elapsed)

        // Then: work elapsed should be ~610 (600 + 10 seconds)
        assertApproxEqual(currentWorkElapsed, 610, accuracy: 1)
    }

    func testBreakRunningCounterComputation() {
        // Given: Mac entered breakRunning 10 seconds ago with 300 seconds remaining
        let stateChangedAt = Date().timeIntervalSince1970 - 10
        let payload = SyncPayload(
            timerState: .breakRunning,
            stateChangedAt: stateChangedAt,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 300,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        // When: we compute current values
        let elapsed = Date().timeIntervalSince1970 - payload.stateChangedAt
        let currentBreakRemaining = max(0, payload.breakRemainingAtChange - Int(elapsed))

        // Then: break remaining should be ~290 (300 - 10 seconds)
        assertApproxEqual(currentBreakRemaining, 290, accuracy: 1)
    }

    func testSnoozeRunningCounterComputation() {
        // Given: Mac entered snoozeRunning 5 seconds ago with 120 seconds remaining
        let stateChangedAt = Date().timeIntervalSince1970 - 5
        let payload = SyncPayload(
            timerState: .snoozeRunning,
            stateChangedAt: stateChangedAt,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 120,
            sourceDevice: "mac"
        )

        // When: we compute current values
        let elapsed = Date().timeIntervalSince1970 - payload.stateChangedAt
        let currentSnoozeRemaining = max(0, payload.snoozeRemainingAtChange - Int(elapsed))

        // Then: snooze remaining should be ~115 (120 - 5 seconds)
        assertApproxEqual(currentSnoozeRemaining, 115, accuracy: 1)
    }

    func testWorkPausedCounterDoesNotAdvance() {
        // Given: Mac entered workPaused 100 seconds ago with 600 seconds elapsed
        let stateChangedAt = Date().timeIntervalSince1970 - 100
        let payload = SyncPayload(
            timerState: .workPaused,
            stateChangedAt: stateChangedAt,
            workElapsedAtChange: 600,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        // When: paused, we use the value at change directly (no time advance)
        let currentWorkElapsed = payload.workElapsedAtChange

        // Then: work elapsed should still be exactly 600
        XCTAssertEqual(currentWorkElapsed, 600)
    }

    func testBreakRemainingDoesNotGoBelowZero() {
        // Given: Mac entered breakRunning 1000 seconds ago with 300 seconds remaining
        let stateChangedAt = Date().timeIntervalSince1970 - 1000
        let payload = SyncPayload(
            timerState: .breakRunning,
            stateChangedAt: stateChangedAt,
            workElapsedAtChange: 1500,
            breakRemainingAtChange: 300,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        // When: we compute current values (elapsed far exceeds remaining)
        let elapsed = Date().timeIntervalSince1970 - payload.stateChangedAt
        let currentBreakRemaining = max(0, payload.breakRemainingAtChange - Int(elapsed))

        // Then: break remaining should be clamped to 0, not negative
        XCTAssertEqual(currentBreakRemaining, 0)
    }

    // MARK: - Equatable

    func testSyncPayloadEquality() {
        let a = SyncPayload(
            timerState: .workRunning,
            stateChangedAt: 1700000000.0,
            workElapsedAtChange: 100,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )
        let b = SyncPayload(
            timerState: .workRunning,
            stateChangedAt: 1700000000.0,
            workElapsedAtChange: 100,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )
        let c = SyncPayload(
            timerState: .breakRunning,
            stateChangedAt: 1700000000.0,
            workElapsedAtChange: 100,
            breakRemainingAtChange: 0,
            snoozeRemainingAtChange: 0,
            sourceDevice: "mac"
        )

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - Accuracy Helper

/// Assert two integers are within an accuracy range.
/// Free function to avoid shadowing XCTest's built-in XCTAssertEqual.
private func assertApproxEqual(_ a: Int, _ b: Int, accuracy: Int, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(abs(a - b) <= accuracy,
        "\(a) is not within \(accuracy) of \(b)",
        file: file, line: line)
}
