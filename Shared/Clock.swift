import Foundation

/// Abstraction over "the current time" so time-dependent logic (sync
/// staleness, deferral durations, payload timestamps) can be driven
/// deterministically in tests instead of reading the wall clock.
protocol NowProviding {
    var now: Date { get }
}

/// Production clock — reads the real system time.
struct SystemClock: NowProviding {
    var now: Date { Date() }
}

#if DEBUG
/// Test clock with a fixed, advanceable time. Shared by the macOS and
/// watchOS test targets (both build `Shared`).
final class MutableClock: NowProviding {
    var now: Date

    /// Defaults to a fixed reference instant so tests are reproducible.
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        now = start
    }

    /// Move time forward (or backward with a negative value).
    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
#endif
