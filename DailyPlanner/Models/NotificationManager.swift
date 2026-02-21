import Foundation
import UserNotifications

// MARK: - Notification Manager
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // Suggested reminder messages that rotate through scheduled times
    static let reminderMessages: [String] = [
        "🌟 Rise & shine! Open Daily Planner and make today count!",
        "📋 Planning time! Review your tasks and stay on top of your goals.",
        "✅ Mid-day check-in — how many tasks have you ticked off today?",
        "💪 Stay focused! Your Daily Planner is ready for a quick review.",
        "🚀 Goal alert! Don't forget to log your progress in Daily Planner.",
        "🌙 Evening wrap-up — mark completed tasks and plan for tomorrow!",
        "⏰ Friendly nudge: your plans and goals are waiting in Daily Planner!"
    ]

    // MARK: - Permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    // MARK: - Schedule
    /// Cancels all existing reminders then schedules one repeating
    /// notification per entry in `times`, cycling through `reminderMessages`.
    func scheduleNotifications(times: [Date]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard !times.isEmpty else { return }

        let cal = Calendar.current
        for (idx, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Daily Planner"
            content.body  = Self.reminderMessages[idx % Self.reminderMessages.count]
            content.sound = .default

            var comps = cal.dateComponents([.hour, .minute], from: time)
            comps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

            let request = UNNotificationRequest(
                identifier: "dp_reminder_\(idx)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    // MARK: - Cancel
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
