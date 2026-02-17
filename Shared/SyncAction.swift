import Foundation

/// An action sent from Watch to Mac (snooze/skip break).
struct SyncAction: Codable, Equatable {
    enum ActionType: String, Codable {
        case snooze
        case skipBreak
    }

    let action: ActionType
    let timestamp: TimeInterval
}
