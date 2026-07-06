import Foundation
import SwiftUI

// MARK: - Cross-Platform Colors

extension Color {
    #if os(macOS)
    static let platformWindowBackground = Color(nsColor: .windowBackgroundColor)
    static let platformControlBackground = Color(nsColor: .controlBackgroundColor)
    static let platformSeparator = Color(nsColor: .separatorColor)
    #else
    static let platformWindowBackground = Color(.systemBackground)
    static let platformControlBackground = Color(.secondarySystemBackground)
    static let platformSeparator = Color(.separator)
    #endif
}

// MARK: - Platform Protocols

protocol IdleTimeProvider {
    func getIdleTime() -> TimeInterval
}

enum CallContext {
    case none
    case onCall
    case screenSharing
}

@MainActor
protocol CallDetectorProtocol: AnyObject {
    var callContext: CallContext { get }
    var isOnCall: Bool { get }
    var isScreenSharing: Bool { get }
}

protocol CalendarMonitorProtocol: AnyObject {
    func nextEventStartsWithin(minutes: Int) -> Bool
}

protocol ScreenLocking {
    func lockScreen()
}

protocol BreakNotifying {
    func sendBreakNotification(soundEnabled: Bool)
}
