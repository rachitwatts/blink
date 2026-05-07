import Foundation
import UserNotifications

@MainActor
final class WeeklySummaryService: NSObject {

    static let shared = WeeklySummaryService()

    private static let notificationIdentifier = "blink-weekly-summary"
    private static let categoryIdentifier = "BLINK_WEEKLY_SUMMARY"
    private static let viewDashboardActionIdentifier = "VIEW_DASHBOARD"

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func start() {
        registerNotificationCategory()
        UNUserNotificationCenter.current().delegate = self
        reschedule()
    }

    // MARK: - Scheduling

    func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        guard Settings.shared.weeklySummaryEnabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                self.scheduleNextNotification()
            }
        }
    }

    private func scheduleNextNotification() {
        let settings = Settings.shared

        var dateComponents = DateComponents()
        dateComponents.weekday = settings.weeklySummaryDay
        dateComponents.hour = settings.weeklySummaryHour
        dateComponents.minute = settings.weeklySummaryMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Blink Weekly Summary"
        content.body = "Your weekly eye health summary is ready. Tap to view your insights."
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[WeeklySummaryService] Failed to schedule: \(error)")
            } else {
                let dayName = Calendar.current.weekdaySymbols[settings.weeklySummaryDay - 1]
                let hour = settings.weeklySummaryHour
                let minute = settings.weeklySummaryMinute
                print("[WeeklySummaryService] Scheduled for \(dayName) at \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    private func registerNotificationCategory() {
        let viewAction = UNNotificationAction(
            identifier: Self.viewDashboardActionIdentifier,
            title: "View Dashboard",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [viewAction],
            intentIdentifiers: []
        )

        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            var updated = existing.filter { $0.identifier != Self.categoryIdentifier }
            updated.insert(category)
            center.setNotificationCategories(updated)
        }
    }

    // MARK: - Insight Composition

    private func composeInsightBody() -> String {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return "Tap to view your weekly eye health summary."
        }

        let events = AnalyticsService.shared.eventsForDateRange(from: weekAgo, to: now)
        let metrics = EyeHealthCalculator.calculate(from: events)

        guard metrics.breaksCompleted + metrics.breaksSkipped > 0 else {
            return "No break data this week. Open Blink and let it run during your work sessions!"
        }

        let compliancePct = Int(metrics.breakCompliance * 100)

        if compliancePct >= 95 {
            return celebrationMessage(metrics: metrics)
        }

        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let previousEvents = AnalyticsService.shared.eventsForDateRange(from: twoWeeksAgo, to: weekAgo)

        let insights = EyeHealthAnalyzer.analyze(
            events: events,
            settings: Settings.shared,
            scope: .week,
            previousPeriodEvents: previousEvents
        )

        if let topInsight = insights.first(where: { $0.category == .pattern }) {
            let suggestion = insights.first(where: { $0.id == topInsight.id + "_suggestion" })
            if let suggestion {
                return "\(topInsight.description) \(suggestion.description)"
            }
            return topInsight.description
        }

        return summaryFallback(metrics: metrics, compliancePct: compliancePct)
    }

    private func celebrationMessage(metrics: EyeHealthMetrics) -> String {
        let pct = Int(metrics.breakCompliance * 100)
        let grade = metrics.grade

        if grade == "A+" {
            return "Perfect week! You completed \(pct)% of breaks with an A+ grade. Keep it up!"
        }
        return "Great week! You completed \(pct)% of breaks — grade: \(grade). Your eyes thank you."
    }

    private func summaryFallback(metrics: EyeHealthMetrics, compliancePct: Int) -> String {
        let grade = metrics.grade
        if compliancePct >= 80 {
            return "Solid week — \(compliancePct)% break compliance (grade: \(grade)). Can you hit 90% next week?"
        }
        if compliancePct >= 50 {
            return "You completed \(compliancePct)% of breaks this week (grade: \(grade)). Try completing one more break each day."
        }
        return "You skipped most breaks this week (\(compliancePct)% compliance). Even a 30-second break helps — try taking the next one."
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension WeeklySummaryService: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier == Self.notificationIdentifier else {
            completionHandler([.banner, .sound])
            return
        }

        Task { @MainActor in
            center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])

            let content = UNMutableNotificationContent()
            content.title = "Blink Weekly Summary"
            content.body = self.composeInsightBody()
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier

            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifier + "-fresh",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }

        completionHandler([])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        guard id == Self.notificationIdentifier || id == Self.notificationIdentifier + "-fresh" else {
            completionHandler()
            return
        }

        let actionId = response.actionIdentifier
        let shouldOpenDashboard = actionId == UNNotificationDefaultActionIdentifier
            || actionId == Self.viewDashboardActionIdentifier

        Task { @MainActor in
            if shouldOpenDashboard {
                let result = BlinkActions.execute(.dashboard)
                print("[WeeklySummaryService] Notification tapped -> \(result.message)")
            }
        }

        completionHandler()
    }
}
