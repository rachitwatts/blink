import Foundation
import SwiftData

/// Types of analytics events tracked by Blink
enum EventType: String, Codable, CaseIterable {
    case sessionCompleted
    case sessionReset
    case breakStarted
    case breakCompleted
    case breakSkipped
    case breakSnoozed
    case snoozeExpired
    case snoozeEndedEarly  // User manually resumed break during snooze
    case pauseToggled
    case appLaunched
    case appQuit
    case idleDetected
    case settingsChanged
    case nudgeShown
    case nudgeDismissed
}

/// A single analytics event persisted via SwiftData
///
/// Each user action or timer transition creates one SessionEvent.
/// Events are queried by AnalyticsService for the dashboard.
@Model
final class SessionEvent {
    var id: UUID
    var timestamp: Date
    var eventType: String  // Store as String for SwiftData compatibility
    var durationSeconds: Int?
    var configuredDurationSeconds: Int?
    var reason: String?
    var metadata: [String: String]?

    init(
        eventType: EventType,
        timestamp: Date = Date(),
        durationSeconds: Int? = nil,
        configuredDurationSeconds: Int? = nil,
        reason: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.eventType = eventType.rawValue
        self.configuredDurationSeconds = configuredDurationSeconds
        self.durationSeconds = durationSeconds
        self.reason = reason
        self.metadata = metadata
    }

    /// Typed accessor for the event type
    var type: EventType? {
        EventType(rawValue: eventType)
    }
}
