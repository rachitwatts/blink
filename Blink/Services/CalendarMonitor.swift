import Foundation
import EventKit
import Combine

@MainActor
protocol CalendarMonitorProtocol: AnyObject {
    func nextEventStartsWithin(minutes: Int) -> Bool
}

@MainActor
final class CalendarMonitor: ObservableObject, CalendarMonitorProtocol {

    static let shared = CalendarMonitor()

    private let store = EKEventStore()
    private let settings = Settings.shared
    private var pollTimer: AnyCancellable?

    @Published private(set) var upcomingEvents: [EKEvent] = []
    @Published private(set) var availableCalendars: [EKCalendar] = []

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    private init() {}

    func start() {
        guard pollTimer == nil else { return }
        refreshCalendars()
        pollTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.poll()
            }
        poll()
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("[CalendarMonitor] Permission request failed: \(error)")
            return false
        }
    }

    func nextEventStartsWithin(minutes: Int) -> Bool {
        guard settings.calendarIntegrationEnabled else { return false }
        let cutoff = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return upcomingEvents.contains { $0.startDate <= cutoff && $0.startDate > Date() }
    }

    private func poll() {
        guard settings.calendarIntegrationEnabled,
              authorizationStatus == .fullAccess else {
            if !upcomingEvents.isEmpty { upcomingEvents = [] }
            return
        }

        let now = Date()
        let end = now.addingTimeInterval(30 * 60)
        let watchedIDs = parseWatchedIdentifiers()
        let calendars: [EKCalendar]?

        if watchedIDs.isEmpty {
            calendars = nil
        } else {
            calendars = store.calendars(for: .event).filter { watchedIDs.contains($0.calendarIdentifier) }
        }

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
        upcomingEvents = store.events(matching: predicate)
    }

    func refreshCalendars() {
        guard authorizationStatus == .fullAccess else {
            availableCalendars = []
            return
        }
        availableCalendars = store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    private func parseWatchedIdentifiers() -> Set<String> {
        let raw = settings.watchedCalendarIdentifiers
        guard !raw.isEmpty else { return [] }
        return Set(raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    #if DEBUG
    private var mockNextEventWithin: Int?

    func setMockNextEventWithin(minutes: Int?) {
        mockNextEventWithin = minutes
    }
    #endif
}
