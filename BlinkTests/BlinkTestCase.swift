import XCTest
@testable import Blink

/// Base class for Blink unit tests that touch shared state.
///
/// Guarantees test isolation:
/// - Each test gets a fresh, ephemeral `UserDefaults` suite, so `Settings`
///   never reads or writes the real app domain (`UserDefaults.standard`).
/// - `AppState`, `Settings` sync bookkeeping, and `TimerEngine` internal
///   state are fully reset per test, killing order-dependence.
/// - Static test flags (e.g. `InCallNudgeWindowController.suppressForTesting`)
///   are set in `setUp` and restored in `tearDown` so they don't leak into
///   later suites.
///
/// Subclasses get `mockIdle` pre-injected; override `setUp`/`tearDown` only
/// if you call `super`.
@MainActor
class BlinkTestCase: XCTestCase {

    /// Idle provider injected into `TimerEngine` — mutate `.idleTime` per test.
    private(set) var mockIdle: MockIdleTimeProvider!

    /// The per-test ephemeral defaults suite (wiped in tearDown).
    private(set) var testDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()

        // Fresh isolated defaults suite for this test.
        suiteName = "com.rachitwatts.blink.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)
        Settings.shared.useStoreForTesting(testDefaults)

        // Reset shared observable state.
        AppState.shared.reset()

        // Inject deterministic dependencies into the timer engine.
        mockIdle = MockIdleTimeProvider()
        TimerEngine.shared.setIdleDetector(mockIdle)
        TimerEngine.shared.setCallDetector(MockCallDetector())
        TimerEngine.shared.setCalendarMonitor(MockCalendarMonitor())
        TimerEngine.shared.setSyncManager(nil)
        InCallNudgeWindowController.suppressForTesting = true

        // Clear engine internal state (e.g. shouldResetOnNextActivity) without
        // leaving a live timer running.
        TimerEngine.shared.restartSession()
        TimerEngine.shared.stop()
    }

    override func tearDown() async throws {
        TimerEngine.shared.stop()
        AppState.shared.reset()
        InCallNudgeWindowController.suppressForTesting = false

        // Wipe and detach the ephemeral suite so nothing persists.
        if let suiteName {
            testDefaults?.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        suiteName = nil

        // Restore Settings to the real store for any non-isolated code.
        Settings.shared.useStoreForTesting(.standard)

        try await super.tearDown()
    }
}
