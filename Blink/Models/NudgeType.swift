import Foundation

/// Types of micro nudges shown during work sessions
enum NudgeType: String, CaseIterable, Identifiable {
    case blink
    case posture
    case neckStretch

    var id: String { rawValue }

    var displayMessage: String {
        switch self {
        case .blink: return "Blink slowly a few times"
        case .posture: return "Sit up straight, shoulders back"
        case .neckStretch: return "Gently roll your neck"
        }
    }

    var sfSymbol: String {
        switch self {
        case .blink: return "eye"
        case .posture: return "figure.stand"
        case .neckStretch: return "arrow.triangle.2.circlepath"
        }
    }

    /// Weight in the random selection pool (blink has 2x weight)
    var selectionWeight: Int {
        switch self {
        case .blink: return 2
        case .posture: return 1
        case .neckStretch: return 1
        }
    }
}
