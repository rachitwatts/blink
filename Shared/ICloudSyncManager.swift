import Foundation

/// Syncs timer state and settings via iCloud Key-Value Store.
/// Works on both macOS and watchOS — no WatchConnectivity needed.
final class ICloudSyncManager: SyncManagerProtocol {

    private let store = NSUbiquitousKeyValueStore.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var onTimerStateReceived: ((SyncPayload) -> Void)?
    var onSettingsReceived: ((SyncSettings) -> Void)?
    var onWatchActionReceived: ((SyncAction) -> Void)?

    /// Timestamp of the last watch action we processed (to deduplicate)
    private var lastProcessedActionTimestamp: TimeInterval = 0

    func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        // Force initial sync
        store.synchronize()
    }

    func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }

    func publishTimerState(_ payload: SyncPayload) {
        guard let data = try? encoder.encode(payload) else { return }
        store.set(data, forKey: SyncKeys.timerPayload)
        store.synchronize()
    }

    func publishSettings(_ settings: SyncSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        store.set(data, forKey: SyncKeys.settings)
        store.synchronize()
    }

    /// Watch-only: publish an action for Mac to process
    func publishWatchAction(_ action: SyncAction) {
        guard let data = try? encoder.encode(action) else { return }
        store.set(data, forKey: SyncKeys.watchAction)
        store.synchronize()
    }

    @objc private func kvStoreDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        for key in changedKeys {
            switch key {
            case SyncKeys.timerPayload:
                if let data = store.data(forKey: key),
                   let payload = try? decoder.decode(SyncPayload.self, from: data) {
                    onTimerStateReceived?(payload)
                }
            case SyncKeys.settings:
                if let data = store.data(forKey: key),
                   let settings = try? decoder.decode(SyncSettings.self, from: data) {
                    onSettingsReceived?(settings)
                }
            case SyncKeys.watchAction:
                if let data = store.data(forKey: key),
                   let action = try? decoder.decode(SyncAction.self, from: data),
                   action.timestamp > lastProcessedActionTimestamp {
                    lastProcessedActionTimestamp = action.timestamp
                    onWatchActionReceived?(action)
                }
            default:
                break
            }
        }
    }
}
