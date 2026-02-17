import Foundation

/// Settings synced between Mac and Watch via iCloud KVS.
struct SyncSettings: Codable, Equatable {
    let workDurationMinutes: Int
    let breakDurationMinutes: Int
    let snoozeDurationMinutes: Int
    let displayMode: String // DisplayMode.rawValue
    let changedAt: TimeInterval
}
