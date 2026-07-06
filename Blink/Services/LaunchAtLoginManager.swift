#if os(macOS)
import Foundation
import ServiceManagement

/// Manages Launch at Login functionality using SMAppService
///
/// Uses the modern SMAppService API (macOS 13+) to register/unregister
/// the app as a login item.
///
/// Usage:
/// - `LaunchAtLoginManager.shared.setEnabled(true)` to enable
/// - `LaunchAtLoginManager.shared.isEnabled` to check status
final class LaunchAtLoginManager {

    // MARK: - Singleton

    static let shared = LaunchAtLoginManager()

    // MARK: - Properties

    /// The app service for the main app
    private let appService = SMAppService.mainApp

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Whether launch at login is currently enabled
    var isEnabled: Bool {
        appService.status == .enabled
    }

    /// Enable or disable launch at login
    /// - Parameter enabled: True to enable, false to disable
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                // Register to launch at login
                if appService.status == .notRegistered || appService.status == .notFound {
                    try appService.register()
                    print("[LaunchAtLogin] Registered successfully")
                } else {
                    print("[LaunchAtLogin] Already registered, status: \(appService.status)")
                }
            } else {
                // Unregister from launch at login
                if appService.status == .enabled {
                    try appService.unregister()
                    print("[LaunchAtLogin] Unregistered successfully")
                } else {
                    print("[LaunchAtLogin] Already unregistered, status: \(appService.status)")
                }
            }
        } catch {
            print("[LaunchAtLogin] Error: \(error.localizedDescription)")
        }
    }

    /// Sync the manager state with Settings
    /// Call this at app launch to ensure consistency
    func syncWithSettings() {
        let shouldBeEnabled = Settings.shared.launchAtLogin
        let currentlyEnabled = isEnabled

        if shouldBeEnabled != currentlyEnabled {
            print("[LaunchAtLogin] Syncing: Settings=\(shouldBeEnabled), Actual=\(currentlyEnabled)")
            setEnabled(shouldBeEnabled)
        }
    }
}

#endif
