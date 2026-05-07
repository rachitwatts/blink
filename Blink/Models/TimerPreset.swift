import Foundation

enum TimerPreset: String, CaseIterable, Identifiable {
    case classic
    case pomodoro
    case deskTime
    case ultradian
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Classic (20-20-20)"
        case .pomodoro: "Pomodoro"
        case .deskTime: "DeskTime"
        case .ultradian: "Ultradian"
        case .custom: "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: "Eye doctor recommended"
        case .pomodoro: "The original focus technique"
        case .deskTime: "Highest-productivity ratio"
        case .ultradian: "Matches your natural energy cycle"
        case .custom: "Your own rhythm"
        }
    }

    var workMinutes: Int {
        switch self {
        case .classic: 20
        case .pomodoro: 25
        case .deskTime: 52
        case .ultradian: 90
        case .custom: 25
        }
    }

    var breakMinutes: Int {
        switch self {
        case .classic: 5
        case .pomodoro: 5
        case .deskTime: 17
        case .ultradian: 20
        case .custom: 5
        }
    }

    static func matching(work: Int, breakMins: Int) -> TimerPreset {
        for preset in allCases where preset != .custom {
            if preset.workMinutes == work && preset.breakMinutes == breakMins {
                return preset
            }
        }
        return .custom
    }
}
