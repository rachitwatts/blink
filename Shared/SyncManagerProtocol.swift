import Foundation

/// Keys used in NSUbiquitousKeyValueStore
enum SyncKeys {
    static let timerPayload = "blink.sync.timerPayload"
    static let watchAction = "blink.sync.watchAction"
    static let settings = "blink.sync.settings"
}

/// Protocol for platform-specific sync managers
protocol SyncManagerProtocol: AnyObject {
    /// Publish current timer state to iCloud KVS
    func publishTimerState(_ payload: SyncPayload)

    /// Publish settings to iCloud KVS
    func publishSettings(_ settings: SyncSettings)

    /// Called when remote timer state is received
    var onTimerStateReceived: ((SyncPayload) -> Void)? { get set }

    /// Called when remote settings are received
    var onSettingsReceived: ((SyncSettings) -> Void)? { get set }

    /// Called when a watch action is received (Mac-side only)
    var onWatchActionReceived: ((SyncAction) -> Void)? { get set }

    /// Publish a watch action (snooze/skip) for Mac to process
    func publishWatchAction(_ action: SyncAction)

    /// Start observing iCloud KVS changes
    func startObserving()

    /// Stop observing
    func stopObserving()
}
