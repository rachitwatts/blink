import Foundation
@testable import Blink

class MockIdleTimeProvider: IdleTimeProvider {
    var idleTime: TimeInterval = 0
    func getIdleTime() -> TimeInterval { idleTime }
}

class MockCallDetector: CallDetectorProtocol {
    var callContext: CallContext = .none
    var isOnCall: Bool { callContext == .onCall || callContext == .screenSharing }
    var isScreenSharing: Bool { callContext == .screenSharing }
}

class MockCalendarMonitor: CalendarMonitorProtocol {
    var mockNextEventWithin: Int?

    func nextEventStartsWithin(minutes: Int) -> Bool {
        guard let mock = mockNextEventWithin else { return false }
        return mock <= minutes
    }
}
