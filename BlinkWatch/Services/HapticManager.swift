import Foundation
import WatchKit

/// Plays repeating haptic alerts when a break ends until dismissed.
///
/// The manager fires a `.notification` haptic immediately on start,
/// then repeats every 3 seconds via a scheduled timer. Call `stopAlert()`
/// to cancel the repeating pattern.
///
/// Set `disableHardwareInteractions = true` in tests to suppress
/// actual WatchKit haptic calls.
@MainActor
final class HapticManager {

    private var hapticTimer: Timer?
    private(set) var isPlaying = false

    /// When true, suppresses WKInterfaceDevice haptic calls.
    /// Used in unit tests where WatchKit hardware APIs are unavailable.
    var disableHardwareInteractions: Bool = false

    /// Start repeating haptic alert. Plays `.notification` immediately,
    /// then every 3 seconds until `stopAlert()` is called.
    /// Guards against double-start: calling while already playing is a no-op.
    func startBreakEndAlert() {
        guard !isPlaying else { return }
        isPlaying = true

        // Immediate first haptic
        if !disableHardwareInteractions {
            WKInterfaceDevice.current().play(.notification)
        }

        // Repeat every 3 seconds
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.disableHardwareInteractions else { return }
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    /// Stop the repeating haptic alert and reset state.
    func stopAlert() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        isPlaying = false
    }
}
