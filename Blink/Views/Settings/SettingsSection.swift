import SwiftUI

/// All settings sections with their display metadata
enum SettingsSection: String, CaseIterable, Identifiable {
    case timer
    case general
    case nudges
    case advanced
    case shortcuts
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .general: "General"
        case .nudges: "Nudges"
        case .advanced: "Advanced"
        case .shortcuts: "Shortcuts"
        case .analytics: "Analytics"
        }
    }

    var icon: String {
        switch self {
        case .timer: "timer"
        case .general: "gearshape"
        case .nudges: "bell.badge"
        case .advanced: "slider.horizontal.3"
        case .shortcuts: "keyboard"
        case .analytics: "chart.bar"
        }
    }
}
