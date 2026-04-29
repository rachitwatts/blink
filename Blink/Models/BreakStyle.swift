import Foundation

enum BreakStyle: String, CaseIterable, Identifiable {
    case enforced
    case gentle
    case notificationOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .enforced: "Enforced"
        case .gentle: "Gentle"
        case .notificationOnly: "Notification only"
        }
    }

    var description: String {
        switch self {
        case .enforced: "Full-screen overlay immediately"
        case .gentle: "Progressive — starts with a floating reminder"
        case .notificationOnly: "Just a macOS notification"
        }
    }
}
