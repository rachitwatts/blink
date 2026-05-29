import XCTest
import SwiftData
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

    /// Call detector injected into `TimerEngine` — mutate `.callContext` per test.
    private(set) var mockCall: MockCallDetector!

    /// Calendar monitor injected into `TimerEngine` — set `.mockNextEventWithin`.
    private(set) var mockCalendar: MockCalendarMonitor!

    /// Spy screen-locker injected into `TimerEngine` — never locks the real
    /// machine; assert `.lockCount`.
    private(set) var mockScreenLock: SpyScreenLock!

    /// The per-test ephemeral defaults suite (wiped in tearDown).
    private(set) var testDefaults: UserDefaults!
    private var suiteName: String!

    /// In-memory SwiftData container backing AnalyticsService for this test, so
    /// analytics writes never touch the real on-disk store.
    private(set) var testModelContainer: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()

        // Fresh isolated defaults suite for this test.
        suiteName = "com.rachitwatts.blink.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)
        Settings.shared.useStoreForTesting(testDefaults)

        // Route analytics to an ephemeral in-memory store.
        testModelContainer = try ModelContainer(
            for: Schema([SessionEvent.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        AnalyticsService.shared.configure(with: testModelContainer)

        // Reset shared observable state.
        AppState.shared.reset()

        // Inject deterministic dependencies into the timer engine.
        mockIdle = MockIdleTimeProvider()
        mockCall = MockCallDetector()
        mockCalendar = MockCalendarMonitor()
        mockScreenLock = SpyScreenLock()
        TimerEngine.shared.setIdleDetector(mockIdle)
        TimerEngine.shared.setCallDetector(mockCall)
        TimerEngine.shared.setCalendarMonitor(mockCalendar)
        TimerEngine.shared.setScreenLock(mockScreenLock)

        // Suppress ALL real window creation. The unit-test bundle is hosted by
        // the live Blink.app, whose Combine sinks turn AppState flags into real
        // windows — without these, a test that sets isOverlayVisible spawns
        // full-screen, screen-saver-level overlays that grab the display.
        InCallNudgeWindowController.suppressForTesting = true
        BreakOverlayWindowController.suppressForTesting = true
        NudgeWindowController.suppressForTesting = true

        // Clear engine internal state (e.g. shouldResetOnNextActivity) without
        // leaving a live timer running.
        TimerEngine.shared.restartSession()
        TimerEngine.shared.stop()
    }

    override func tearDown() async throws {
        TimerEngine.shared.stop()
        AppState.shared.reset()
        // NOTE: deliberately do NOT reset the *.suppressForTesting flags here.
        // BlinkApp's sinks can deliver on a later main-runloop turn (after this
        // method returns); flipping suppression off would let a queued
        // showOverlay create a real window. The test host runs only tests, so
        // suppression stays on for the whole process.

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
