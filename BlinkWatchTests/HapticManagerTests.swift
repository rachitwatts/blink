import XCTest
@testable import BlinkWatch

/// Tests for HapticManager lifecycle.
/// Uses `disableHardwareInteractions = true` to avoid actual WatchKit calls.
@MainActor
final class HapticManagerTests: XCTestCase {

    var hapticManager: HapticManager!

    override func setUp() async throws {
        hapticManager = HapticManager()
        hapticManager.disableHardwareInteractions = true
    }

    override func tearDown() async throws {
        hapticManager.stopAlert()
        hapticManager = nil
    }

    // MARK: - Start/Stop Lifecycle

    func testStartSetsIsPlaying() {
        XCTAssertFalse(hapticManager.isPlaying)

        hapticManager.startBreakEndAlert()

        XCTAssertTrue(hapticManager.isPlaying)
    }

    func testStopClearsIsPlaying() {
        hapticManager.startBreakEndAlert()
        XCTAssertTrue(hapticManager.isPlaying)

        hapticManager.stopAlert()

        XCTAssertFalse(hapticManager.isPlaying)
    }

    func testStopWhenNotPlayingIsNoOp() {
        XCTAssertFalse(hapticManager.isPlaying)

        // Should not crash or change state
        hapticManager.stopAlert()

        XCTAssertFalse(hapticManager.isPlaying)
    }

    // MARK: - Double-Start Guard

    func testDoubleStartDoesNotCreateMultipleTimers() {
        hapticManager.startBreakEndAlert()
        XCTAssertTrue(hapticManager.isPlaying)

        // Second start should be a no-op (guard !isPlaying)
        hapticManager.startBreakEndAlert()

        XCTAssertTrue(hapticManager.isPlaying, "isPlaying should still be true after double-start")

        // Single stop should fully clear the state
        hapticManager.stopAlert()
        XCTAssertFalse(hapticManager.isPlaying, "Single stop should clear isPlaying after double-start")
    }

    // MARK: - Start After Stop (Restart)

    func testCanRestartAfterStop() {
        hapticManager.startBreakEndAlert()
        hapticManager.stopAlert()

        XCTAssertFalse(hapticManager.isPlaying)

        // Should be able to start again
        hapticManager.startBreakEndAlert()
        XCTAssertTrue(hapticManager.isPlaying)
    }
}
