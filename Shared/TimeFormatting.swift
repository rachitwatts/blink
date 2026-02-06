import Foundation

/// Shared time formatting utility
/// Used by both macOS and watchOS targets
enum TimeFormatting {
    /// Format seconds as "mm:ss" string
    /// - Parameter totalSeconds: Total seconds to format
    /// - Returns: Formatted string like "05:32" or "125:00" for > 99 minutes
    static func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes >= 100 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
