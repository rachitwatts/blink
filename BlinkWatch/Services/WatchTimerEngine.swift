import Foundation
import Combine
import WatchKit

/// Timer engine for the watch app
///
/// Unlike the macOS version, this does not do idle detection (no CGEventSource
/// on watchOS). Instead, it runs a straightforward work/break cycle:
/// - Work timer counts up for the configured duration
/// - Break timer counts down when work duration is reached
/// - Haptic feedback notifies the user when a break starts
///
/// The watch app is designed as a standalone companion — it tracks its own
/// timer independently from the macOS app.
@MainActor
final class WatchTimerEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = WatchTimerEngine()

    // MARK: - Dependencies

    private let appState = WatchAppState.shared
    private let settings = WatchSettings.shared

    // MARK: - Timer

    private var timerCancellable: AnyCancellable?

    // MARK: - Extended Runtime Session

    private var extendedSession: WKExtendedRuntimeSession?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API: Lifecycle

    func start() {
        guard timerCancellable == nil else { return }
        scheduleTimer()
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        endExtendedSession()
    }

    // MARK: - Public API: Actions

    func togglePause() {
        switch appState.timerState {
        case .workRunning:
            appState.timerState = .workPaused
        case .workPaused:
            appState.timerState = .workRunning
        case .breakRunning, .snoozeRunning:
            break
        }
    }

    func restartSession() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        endExtendedSession()
    }

    func startBreakNow() {
        guard appState.timerState == .workRunning || appState.timerState == .workPaused else {
            return
        }
        triggerBreak()
    }

    func snoozeBreak() {
        guard appState.timerState == .breakRunning else { return }
        appState.snoozeRemainingSeconds = settings.snoozeDurationSeconds
        appState.timerState = .snoozeRunning
    }

    func skipBreak() {
        guard appState.timerState == .breakRunning || appState.timerState == .snoozeRunning else {
            return
        }
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        endExtendedSession()
    }

    // MARK: - Private: Timer

    private func scheduleTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func tick() {
        switch appState.timerState {
        case .workRunning:
            handleWorkTick()
        case .workPaused:
            break
        case .breakRunning:
            handleBreakTick()
        case .snoozeRunning:
            handleSnoozeTick()
        }
    }

    // MARK: - Private: Tick Handlers

    private func handleWorkTick() {
        appState.workElapsedSeconds += 1

        if appState.workElapsedSeconds >= settings.workDurationSeconds {
            triggerBreak()
        }
    }

    private func handleBreakTick() {
        if appState.breakRemainingSeconds > 0 {
            appState.breakRemainingSeconds -= 1
        } else {
            completeBreak()
        }
    }

    private func handleSnoozeTick() {
        if appState.snoozeRemainingSeconds > 0 {
            appState.snoozeRemainingSeconds -= 1
        } else {
            triggerBreak()
        }
    }

    // MARK: - Private: State Transitions

    private func triggerBreak() {
        appState.breakRemainingSeconds = settings.breakDurationSeconds
        appState.timerState = .breakRunning

        // Haptic feedback
        if settings.hapticEnabled {
            WKInterfaceDevice.current().play(.notification)
        }

        // Start extended runtime session so the app can run in the background
        startExtendedSession()
    }

    private func completeBreak() {
        appState.workElapsedSeconds = 0
        appState.timerState = .workRunning
        endExtendedSession()

        // Gentle haptic to signal break is over
        if settings.hapticEnabled {
            WKInterfaceDevice.current().play(.success)
        }
    }

    // MARK: - Private: Extended Runtime Session

    private func startExtendedSession() {
        guard extendedSession == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.start()
        extendedSession = session
    }

    private func endExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }
}
