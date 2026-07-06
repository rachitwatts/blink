#if os(visionOS)
import Foundation
import Combine

/// No-op idle detector for visionOS (no CGEventSource)
final class IdleDetector: IdleTimeProvider {
    static let shared = IdleDetector()
    private init() {}
    func getIdleTime() -> TimeInterval { 0 }
}

/// No-op call detector for visionOS (no CoreAudio HAL)
@MainActor
final class CallDetector: ObservableObject, CallDetectorProtocol {
    static let shared = CallDetector()
    @Published private(set) var callContext: CallContext = .none
    var isOnCall: Bool { false }
    var isScreenSharing: Bool { false }
    func start() {}
}

/// No-op screen lock for visionOS
struct SystemScreenLock: ScreenLocking {
    func lockScreen() {}
}

/// No-op calendar monitor for visionOS (no EventKit access)
@MainActor
final class CalendarMonitor: ObservableObject, CalendarMonitorProtocol {
    static let shared = CalendarMonitor()
    private init() {}
    func start() {}
    func stop() {}
    func nextEventStartsWithin(minutes: Int) -> Bool { false }
}

#endif
