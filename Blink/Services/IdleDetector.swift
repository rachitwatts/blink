#if os(macOS)
import Foundation
import CoreGraphics

/// Service for detecting system-wide idle time
///
/// Idle time is measured as seconds since last keyboard/mouse/trackpad input.
/// Uses CGEventSource which requires no special permissions.
///
/// Usage: `IdleDetector.shared.getIdleTime()`
final class IdleDetector: IdleTimeProvider {

    // MARK: - Singleton

    static let shared = IdleDetector()

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton pattern
    }

    // MARK: - Public API

    /// Get the current system-wide idle time in seconds
    ///
    /// This measures time since last HID (Human Interface Device) event,
    /// which includes keyboard, mouse, and trackpad input.
    ///
    /// - Returns: Seconds since last user input (as TimeInterval/Double)
    func getIdleTime() -> TimeInterval {
        // CGEventType(rawValue: ~0) means "any event type"
        // .hidSystemState gives us system-wide idle time
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .hidSystemState,
            eventType: CGEventType(rawValue: ~0)!
        )
        return idleTime
    }

    /// Check if user is currently considered "active" based on idle threshold
    ///
    /// - Parameter threshold: Seconds of idle time below which user is "active"
    /// - Returns: true if user has had input within the threshold
    func isActive(threshold: TimeInterval) -> Bool {
        return getIdleTime() < threshold
    }

    /// Check if user has been idle long enough to reset session
    ///
    /// - Parameter threshold: Seconds of idle time at which session should reset
    /// - Returns: true if user has been idle at or beyond the threshold
    func shouldResetSession(threshold: TimeInterval) -> Bool {
        return getIdleTime() >= threshold
    }
}

#endif
