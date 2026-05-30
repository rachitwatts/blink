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

/// Records lock-screen calls instead of locking the real machine.
final class SpyScreenLock: ScreenLocking {
    private(set) var lockCount = 0
    func lockScreen() { lockCount += 1 }
}

/// Records break-notification requests instead of posting real OS notifications.
final class SpyBreakNotifier: BreakNotifying {
    private(set) var sendCount = 0
    private(set) var lastSoundEnabled: Bool?
    func sendBreakNotification(soundEnabled: Bool) {
        sendCount += 1
        lastSoundEnabled = soundEnabled
    }
}
