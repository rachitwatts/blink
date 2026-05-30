import XCTest
@testable import Blink

/// Tests for BreakContentProvider exercise selection.
final class BreakContentProviderTests: BlinkTestCase {

    private var provider: BreakContentProvider { BreakContentProvider.shared }

    override func setUp() async throws {
        try await super.setUp()
        provider.reset()
    }

    func testReturnsNilWhenContentModeNotGuided() {
        Settings.shared.breakContentMode = .none
        XCTAssertNil(provider.selectExercise())

        Settings.shared.breakContentMode = .staticMessage
        XCTAssertNil(provider.selectExercise())
    }

    func testReturnsExerciseWhenGuided() {
        Settings.shared.breakContentMode = .guided
        XCTAssertNotNil(provider.selectExercise())
    }

    /// The no-repeat rule (pool excludes the last-shown exercise) guarantees
    /// consecutive selections differ — independent of the RNG.
    func testNeverRepeatsTheSameExerciseConsecutively() {
        Settings.shared.breakContentMode = .guided
        var previous = provider.selectExercise()
        XCTAssertNotNil(previous)
        for _ in 0..<60 {
            let next = provider.selectExercise()
            XCTAssertNotNil(next)
            XCTAssertNotEqual(next, previous, "Same exercise selected twice in a row")
            previous = next
        }
    }

    func testSwitchingAwayFromGuidedClearsAndReturnsNil() {
        Settings.shared.breakContentMode = .guided
        XCTAssertNotNil(provider.selectExercise())
        Settings.shared.breakContentMode = .none
        XCTAssertNil(provider.selectExercise())
    }
}
