import Foundation

struct BlinkSyncState: Codable {
    let timerState: String
    let workElapsedSeconds: Int
    let breakRemainingSeconds: Int
    let snoozeRemainingSeconds: Int
    let workDurationSeconds: Int
    let breakDurationSeconds: Int
    let workProgress: Double
    let isOverlayVisible: Bool
    let breakExerciseTitle: String?
    let breakExerciseInstruction: String?
    let timestamp: TimeInterval
}

enum SyncFraming {
    static func frame(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var framed = Data(bytes: &length, count: 4)
        framed.append(data)
        return framed
    }
}

@MainActor
enum SyncMerge {

    static func currentState() -> BlinkSyncState {
        let appState = AppState.shared
        let settings = Settings.shared
        return BlinkSyncState(
            timerState: appState.timerState.rawValue,
            workElapsedSeconds: appState.workElapsedSeconds,
            breakRemainingSeconds: appState.breakRemainingSeconds,
            snoozeRemainingSeconds: appState.snoozeRemainingSeconds,
            workDurationSeconds: settings.workDurationSeconds,
            breakDurationSeconds: settings.breakDurationSeconds,
            workProgress: appState.workProgress,
            isOverlayVisible: appState.isOverlayVisible,
            breakExerciseTitle: appState.activeBreakExercise?.title,
            breakExerciseInstruction: appState.activeBreakExercise?.instruction,
            timestamp: Date().timeIntervalSince1970
        )
    }

    static func shouldApplyRemote(_ remote: BlinkSyncState) -> Bool {
        let local = AppState.shared
        let localState = local.timerState
        guard let remoteState = TimerState(rawValue: remote.timerState) else { return false }

        // State transitions always win — deliberate user actions
        if remoteState != localState {
            return true
        }

        // Same state: higher elapsed wins (started earlier)
        if remoteState == .workRunning || remoteState == .workPaused {
            return remote.workElapsedSeconds > local.workElapsedSeconds
        }

        // During break/snooze: lower remaining wins (further along)
        if remoteState == .breakRunning {
            return remote.breakRemainingSeconds < local.breakRemainingSeconds
        }
        if remoteState == .snoozeRunning {
            return remote.snoozeRemainingSeconds < local.snoozeRemainingSeconds
        }

        return false
    }

    static func apply(_ remote: BlinkSyncState) {
        let appState = AppState.shared
        if let newState = TimerState(rawValue: remote.timerState) {
            appState.timerState = newState
        }
        appState.workElapsedSeconds = remote.workElapsedSeconds
        appState.breakRemainingSeconds = remote.breakRemainingSeconds
        appState.snoozeRemainingSeconds = remote.snoozeRemainingSeconds
        appState.isOverlayVisible = remote.isOverlayVisible
        Settings.shared.workDurationMinutes = remote.workDurationSeconds / 60
        Settings.shared.breakDurationMinutes = remote.breakDurationSeconds / 60
    }
}
