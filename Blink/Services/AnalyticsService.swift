import Foundation
import SwiftData

/// Singleton service that records and queries analytics events
///
/// All event recording is fire-and-forget: failures are logged but never
/// surface to the user. The service must be configured with a ModelContainer
/// before any events can be persisted (see `BlinkApp.init`).
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    private init() {}

    /// Configure the service with a SwiftData container
    /// Must be called once at app launch before recording events
    func configure(with container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = ModelContext(container)
    }

    // MARK: - Event Recording

    func recordSessionCompleted(actualDuration: Int, configuredDuration: Int) {
        record(SessionEvent(
            eventType: .sessionCompleted,
            durationSeconds: actualDuration,
            configuredDurationSeconds: configuredDuration
        ))
    }

    func recordSessionReset(elapsed: Int, reason: String) {
        record(SessionEvent(
            eventType: .sessionReset,
            durationSeconds: elapsed,
            reason: reason
        ))
    }

    func recordBreakStarted(trigger: String, configuredDuration: Int) {
        record(SessionEvent(
            eventType: .breakStarted,
            configuredDurationSeconds: configuredDuration,
            reason: trigger
        ))
    }

    func recordBreakCompleted(actualDuration: Int) {
        record(SessionEvent(
            eventType: .breakCompleted,
            durationSeconds: actualDuration
        ))
    }

    func recordBreakSkipped(remainingSeconds: Int) {
        record(SessionEvent(
            eventType: .breakSkipped,
            durationSeconds: remainingSeconds
        ))
    }

    func recordBreakSnoozed(snoozeDuration: Int, breakId: String) {
        record(SessionEvent(
            eventType: .breakSnoozed,
            metadata: ["snoozeDuration": String(snoozeDuration), "breakId": breakId]
        ))
    }

    func recordSnoozeExpired(breakId: String) {
        record(SessionEvent(
            eventType: .snoozeExpired,
            metadata: ["breakId": breakId]
        ))
    }

    func recordPauseToggled(newState: String) {
        record(SessionEvent(
            eventType: .pauseToggled,
            reason: newState
        ))
    }

    func recordAppLaunched() {
        record(SessionEvent(
            eventType: .appLaunched,
            metadata: [
                "appVersion": Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "unknown"
            ]
        ))
    }

    func recordAppQuit(totalActiveSeconds: Int) {
        record(SessionEvent(
            eventType: .appQuit,
            durationSeconds: totalActiveSeconds
        ))
    }

    func recordIdleDetected(idleDuration: Int, action: String) {
        record(SessionEvent(
            eventType: .idleDetected,
            durationSeconds: idleDuration,
            reason: action
        ))
    }

    func recordSettingsChanged(key: String, oldValue: String, newValue: String) {
        record(SessionEvent(
            eventType: .settingsChanged,
            metadata: ["key": key, "oldValue": oldValue, "newValue": newValue]
        ))
    }

    // MARK: - Queries

    /// Fetch all events from today, sorted by timestamp
    func eventsForToday() -> [SessionEvent] {
        guard let context = modelContext else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<SessionEvent> { event in
            event.timestamp >= startOfDay && event.timestamp < endOfDay
        }

        let descriptor = FetchDescriptor<SessionEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("[AnalyticsService] Failed to fetch events: \(error)")
            return []
        }
    }

    /// Fetch events within a date range, sorted by timestamp
    func eventsForDateRange(from startDate: Date, to endDate: Date) -> [SessionEvent] {
        guard let context = modelContext else { return [] }

        let predicate = #Predicate<SessionEvent> { event in
            event.timestamp >= startDate && event.timestamp < endDate
        }

        let descriptor = FetchDescriptor<SessionEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("[AnalyticsService] Failed to fetch events: \(error)")
            return []
        }
    }

    /// Fetch all events ever recorded, sorted by timestamp
    func allEvents() -> [SessionEvent] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<SessionEvent>(
            sortBy: [SortDescriptor(\.timestamp)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("[AnalyticsService] Failed to fetch events: \(error)")
            return []
        }
    }

    /// Return the date of the earliest recorded event, or nil
    func firstEventDate() -> Date? {
        guard let context = modelContext else { return nil }

        var descriptor = FetchDescriptor<SessionEvent>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first?.timestamp
        } catch {
            return nil
        }
    }

    // MARK: - Reset

    /// Delete all analytics data - used for privacy/reset
    func resetAllData() throws {
        guard let context = modelContext else {
            throw NSError(
                domain: "AnalyticsService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "ModelContext not configured"]
            )
        }

        let descriptor = FetchDescriptor<SessionEvent>()
        let allEvents = try context.fetch(descriptor)

        for event in allEvents {
            context.delete(event)
        }

        try context.save()
        print("[AnalyticsService] All analytics data reset")
    }

    // MARK: - Private

    private func record(_ event: SessionEvent) {
        guard let context = modelContext else {
            print("[AnalyticsService] Warning: ModelContext not configured")
            return
        }
        context.insert(event)
        do {
            try context.save()
        } catch {
            print("[AnalyticsService] Failed to save event: \(error)")
        }
    }
}
