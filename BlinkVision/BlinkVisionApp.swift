import SwiftUI
import Combine

@main
struct BlinkVisionApp: App {

    @State private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup(id: "main-timer") {
            VisionTimerView()
                .environment(appModel)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onReceive(AppState.shared.$timerState) { newState in
                    handleTimerStateChange(newState)
                }
        }
        .defaultSize(width: 420, height: 480)

        WindowGroup(id: "volumetric-timer") {
            VolumetricTimerView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.35, height: 0.4, depth: 0.35, in: .meters)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }

    init() {
        TimerEngine.shared.start()
        BonjourBrowser.shared.start()
        BreakNotificationScheduler.shared.start()
        CloudKVSSync.shared.start()
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        let scheduler = BreakNotificationScheduler.shared
        let appState = AppState.shared
        switch phase {
        case .active:
            scheduler.cancelPendingNotifications()
        case .background, .inactive:
            if appState.timerState == .workRunning {
                scheduler.scheduleBreakNotification()
            }
        @unknown default:
            break
        }
    }

    private func handleTimerStateChange(_ state: TimerState) {
        let scheduler = BreakNotificationScheduler.shared
        switch state {
        case .workPaused, .breakRunning, .snoozeRunning:
            scheduler.cancelPendingNotifications()
        case .workRunning:
            if scenePhase != .active {
                scheduler.scheduleBreakNotification()
            }
        }
    }
}
