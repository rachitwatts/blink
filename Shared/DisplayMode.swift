import Foundation

/// Display mode for the timer
/// Shared between macOS and watchOS targets
enum DisplayMode: String, CaseIterable, Identifiable, Codable {
    case elapsed = "elapsed"
    case remaining = "remaining"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .elapsed: return "Elapsed"
        case .remaining: return "Remaining"
        }
    }
}
