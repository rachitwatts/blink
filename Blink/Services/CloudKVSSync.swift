import Foundation
import Combine

@MainActor
final class CloudKVSSync {

    static let shared = CloudKVSSync()

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromCloud = false

    private static let syncedKeys: [String: Any.Type] = [
        "timerPreset": String.self,
        "workDurationMinutes": Int.self,
        "breakDurationMinutes": Int.self,
        "snoozeDurationMinutes": Int.self,
        "idleIgnoreThreshold": Int.self,
        "idleResetThreshold": Int.self,
        "displayMode": String.self,
        "soundEnabled": Bool.self,
        "lockScreenAfterBreak": Bool.self,
        "nudgesEnabled": Bool.self,
        "nudgeIntervalMinutes": Int.self,
        "nudgeBlinkEnabled": Bool.self,
        "nudgePostureEnabled": Bool.self,
        "nudgeStretchEnabled": Bool.self,
        "breakStyle": String.self,
        "callDetectionEnabled": Bool.self,
        "calendarIntegrationEnabled": Bool.self,
        "watchedCalendarIdentifiers": String.self,
        "calendarLeadTimeMinutes": Int.self,
        "weeklySummaryEnabled": Bool.self,
        "weeklySummaryDay": Int.self,
        "weeklySummaryHour": Int.self,
        "weeklySummaryMinute": Int.self,
        "breakContentMode": String.self,
    ]

    private init(defaults: UserDefaults = .init(suiteName: Bundle.main.bundleIdentifier ?? "com.watts.blink") ?? .init()) {
        self.defaults = defaults
    }

    func start() {
        #if os(visionOS)
        // KVS requires iCloud entitlement; skip on visionOS until paid team signing
        print("[CloudKVSSync] Skipped on visionOS (no iCloud entitlement)")
        return
        #endif

        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kvs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCloudChange(notification)
            }
            .store(in: &cancellables)

        kvs.synchronize()
        pullFromCloud()
        observeLocalChanges()
        print("[CloudKVSSync] Started")
    }

    // MARK: - Cloud -> Local

    private func handleCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            pullFromCloud()
        case NSUbiquitousKeyValueStoreAccountChange:
            pullFromCloud()
        default:
            break
        }
    }

    private func pullFromCloud() {
        isSyncingFromCloud = true
        defer { isSyncingFromCloud = false }

        let defaults = self.defaults
        for key in Self.syncedKeys.keys {
            guard let cloudValue = kvs.object(forKey: key) else { continue }
            let localValue = defaults.object(forKey: key)

            if !valuesEqual(cloudValue, localValue) {
                defaults.set(cloudValue, forKey: key)
                print("[CloudKVSSync] Pulled \(key) from cloud")
            }
        }

        Settings.shared.objectWillChange.send()
    }

    // MARK: - Local -> Cloud

    private func observeLocalChanges() {
        Settings.shared.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushToCloud()
            }
            .store(in: &cancellables)
    }

    private func pushToCloud() {
        guard !isSyncingFromCloud else { return }

        let defaults = self.defaults
        var changed = false
        for key in Self.syncedKeys.keys {
            let localValue = defaults.object(forKey: key)
            let cloudValue = kvs.object(forKey: key)

            if let local = localValue, !valuesEqual(local, cloudValue) {
                kvs.set(local, forKey: key)
                changed = true
            }
        }

        if changed {
            kvs.synchronize()
            print("[CloudKVSSync] Pushed changes to cloud")
        }
    }

    // MARK: - Helpers

    private func valuesEqual(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (a as Int, b as Int): return a == b
        case let (a as Bool, b as Bool): return a == b
        case let (a as String, b as String): return a == b
        case let (a as Double, b as Double): return a == b
        default: return false
        }
    }
}
