import Foundation

/// Service for locking the macOS screen
///
/// Uses CGSession which requires no special permissions.
/// The -suspend flag locks the screen (same as ⌃⌘Q).
struct ScreenLockService {

    /// Lock the screen immediately
    ///
    /// Uses `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend`
    /// This is idempotent - calling on an already-locked screen is safe.
    static func lockScreen() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        task.arguments = ["-suspend"]

        do {
            try task.run()
        } catch {
            print("[ScreenLockService] Failed to lock screen: \(error)")
        }
    }
}
