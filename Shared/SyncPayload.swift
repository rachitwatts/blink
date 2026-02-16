import Foundation

/// Represents the synced timer state between Mac and Watch.
/// Sent via iCloud Key-Value Store on every state transition.
struct SyncPayload: Codable, Equatable {
    /// Current timer state
    let timerState: TimerState

    /// Timestamp when this state change occurred (timeIntervalSince1970)
    let stateChangedAt: TimeInterval

    /// Work seconds elapsed at the moment of state change
    let workElapsedAtChange: Int

    /// Break seconds remaining at the moment of state change
    let breakRemainingAtChange: Int

    /// Snooze seconds remaining at the moment of state change
    let snoozeRemainingAtChange: Int

    /// Which device produced this state ("mac" or "watch")
    let sourceDevice: String
}
