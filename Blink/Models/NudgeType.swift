import Foundation

/// Types of micro-nudges the app can show
enum NudgeType: String, CaseIterable, Identifiable {
    case blink
    case posture
    case neckStretch

    var id: String { rawValue }

    /// Short label for the nudge
    var title: String {
        switch self {
        case .blink: return "Blink"
        case .posture: return "Posture"
        case .neckStretch: return "Neck Stretch"
        }
    }

    /// The message shown in the nudge panel
    var message: String {
        switch self {
        case .blink: return "Blink slowly a few times to keep your eyes moist."
        case .posture: return "Sit up straight — shoulders back, chin level."
        case .neckStretch: return "Gently tilt your head side to side to release tension."
        }
    }

    /// SF Symbol name for the nudge icon
    var iconName: String {
        switch self {
        case .blink: return "eye"
        case .posture: return "figure.stand"
        case .neckStretch: return "figure.cooldown"
        }
    }

    /// Whether this nudge type is enabled in settings
    func isEnabled(in settings: Settings) -> Bool {
        switch self {
        case .blink: return settings.blinkNudgeEnabled
        case .posture: return settings.postureNudgeEnabled
        case .neckStretch: return settings.neckStretchNudgeEnabled
        }
    }

    /// Configured interval in seconds for this nudge type
    func intervalSeconds(in settings: Settings) -> Int {
        switch self {
        case .blink: return settings.blinkNudgeIntervalMinutes * 60
        case .posture: return settings.postureNudgeIntervalMinutes * 60
        case .neckStretch: return settings.neckStretchNudgeIntervalMinutes * 60
        }
    }
}
