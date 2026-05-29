import Foundation
import AVFoundation
import CoreAudio
import Combine

enum CallContext {
    case none
    case onCall
    case screenSharing
}

@MainActor
protocol CallDetectorProtocol: AnyObject {
    var callContext: CallContext { get }
    var isOnCall: Bool { get }
    var isScreenSharing: Bool { get }
}

@MainActor
final class CallDetector: ObservableObject, CallDetectorProtocol {

    static let shared = CallDetector()

    @Published private(set) var callContext: CallContext = .none

    var isOnCall: Bool {
        callContext == .onCall || callContext == .screenSharing
    }

    var isScreenSharing: Bool {
        callContext == .screenSharing
    }

    private let settings = Settings.shared
    private var pollTimer: AnyCancellable?

    private init() {}

    func start() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.poll()
            }
        poll()
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func poll() {
        guard settings.callDetectionEnabled else {
            if callContext != .none { callContext = .none }
            return
        }

        if checkScreenSharing() {
            if callContext != .screenSharing { callContext = .screenSharing }
        } else if checkMicrophoneInUse() || checkCameraInUse() {
            if callContext != .onCall { callContext = .onCall }
        } else {
            if callContext != .none { callContext = .none }
        }
    }

    // MARK: - Detection Methods

    private func checkMicrophoneInUse() -> Bool {
        var defaultDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultDeviceID
        )
        guard status == noErr, defaultDeviceID != kAudioObjectUnknown else { return false }

        var isRunning: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let runStatus = AudioObjectGetPropertyData(
            defaultDeviceID, &runningAddress, 0, nil, &size, &isRunning
        )
        return runStatus == noErr && isRunning != 0
    }

    private func checkCameraInUse() -> Bool {
        guard let camera = AVCaptureDevice.default(for: .video) else { return false }
        return camera.isInUseByAnotherApplication
    }

    private func checkScreenSharing() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowName = window[kCGWindowName as String] as? String else {
                continue
            }

            if ownerName == "controlcenter" && windowName.lowercased().contains("screen") {
                return true
            }

            if ownerName == "screencaptureui" || ownerName == "screensharingd" {
                return true
            }
        }

        if let dict = CGSessionCopyCurrentDictionary() as? [String: Any],
           let isShared = dict["kCGSSessionScreenIsShared" as String] as? Bool,
           isShared {
            return true
        }

        return false
    }

    #if DEBUG
    func setCallContext(_ context: CallContext) {
        callContext = context
    }

    /// Run one poll cycle synchronously (tests exercise the
    /// callDetectionEnabled gate, which forces `.none` when disabled).
    func pollForTesting() {
        poll()
    }
    #endif
}
