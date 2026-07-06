#if os(visionOS)
import Foundation
import UserNotifications

@MainActor
final class BreakNotificationScheduler {

    static let shared = BreakNotificationScheduler()

    private let notificationId = "blink-break-reminder"
    private let appState = AppState.shared
    private let settings = Settings.shared

    private init() {}

    func start() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            if granted == true {
                print("[BreakNotificationScheduler] Notification permission granted")
            } else {
                print("[BreakNotificationScheduler] Notification permission denied")
            }
        }
    }

    func scheduleBreakNotification() {
        let remainingSeconds = settings.workDurationSeconds - appState.workElapsedSeconds
        guard remainingSeconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for a Break"
        let workedMinutes = settings.workDurationMinutes
        content.body = "You've been working for \(workedMinutes) minutes. Rest your eyes."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingSeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error {
                print("[BreakNotificationScheduler] Failed to schedule: \(error)")
            } else {
                print("[BreakNotificationScheduler] Scheduled in \(remainingSeconds)s")
            }
        }
    }

    func cancelPendingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        print("[BreakNotificationScheduler] Cancelled pending notifications")
    }
}
#endif
