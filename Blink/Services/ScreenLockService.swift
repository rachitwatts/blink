#if os(macOS)
import Foundation
import Darwin

/// Production implementation backed by `ScreenLockService`.
struct SystemScreenLock: ScreenLocking {
    func lockScreen() { ScreenLockService.lockScreen() }
}

/// Service for locking the macOS screen
///
/// Uses `SACLockScreenImmediate()` from the login private framework,
/// which is the equivalent of ⌃⌘Q and works across macOS versions.
struct ScreenLockService {

    /// Lock the screen immediately
    ///
    /// Uses `SACLockScreenImmediate` from `/System/Library/PrivateFrameworks/login.framework`.
    /// This is idempotent - calling on an already-locked screen is safe.
    static func lockScreen() {
        guard let lib = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY) else {
            print("[ScreenLockService] Failed to load login framework")
            return
        }
        defer { dlclose(lib) }

        guard let sym = dlsym(lib, "SACLockScreenImmediate") else {
            print("[ScreenLockService] SACLockScreenImmediate not found")
            return
        }

        typealias LockFunc = @convention(c) () -> Void
        let lock = unsafeBitCast(sym, to: LockFunc.self)
        lock()
    }
}

#endif
