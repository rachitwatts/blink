import Foundation
import UserNotifications

/// Production notifier - posts through `UNUserNotificationCenter`.
struct SystemBreakNotifier: BreakNotifying {
    func sendBreakNotification(soundEnabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time for a break"
            content.body = "Look away from the screen. Blink. Breathe."
            content.sound = soundEnabled ? .default : nil
            let request = UNNotificationRequest(
                identifier: "blink-break-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
