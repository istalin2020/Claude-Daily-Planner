import Foundation
import UserNotifications

// MARK: - Notification Manager
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // Suggested reminder messages that rotate through scheduled times
    static let reminderMessages: [String] = [
        "Rise & shine! Open Daily Planner and make today count!",
        "Planning time! Review your tasks and stay on top of your goals.",
        "Mid-day check-in -- how many tasks have you ticked off today?",
        "Stay focused! Your Daily Planner is ready for a quick review.",
        "Goal alert! Don't forget to log your progress in Daily Planner.",
        "Evening wrap-up -- mark completed tasks and plan for tomorrow!",
        "Friendly nudge: your plans and goals are waiting in Daily Planner!"
    ]

    // MARK: - Permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    // MARK: - Sound helper
    private func sound(for tone: NotificationTone) -> UNNotificationSound {
        // UNNotificationSound(named:) only finds files bundled inside the app.
        // If the file is absent it plays NOTHING – not even the default tone.
        // We therefore verify the resource exists first; if it doesn't we fall
        // back to .default so the user always hears a sound.
        if let file = tone.soundFileName {
            let name = (file as NSString).deletingPathExtension
            let ext  = (file as NSString).pathExtension
            if Bundle.main.url(forResource: name, withExtension: ext) != nil {
                return UNNotificationSound(named: UNNotificationSoundName(rawValue: file))
            }
        }
        return .default
    }

    // MARK: - Daily Reminders
    /// Cancels ONLY daily-reminder notifications (prefix "dp_reminder_"),
    /// then schedules one repeating notification per entry in `times`.
    func scheduleNotifications(times: [Date], tone: NotificationTone = .defaultTone) {
        cancelByPrefix("dp_reminder_")
        guard !times.isEmpty else { return }

        let cal = Calendar.current
        for (idx, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Daily Planner"
            content.body  = Self.reminderMessages[idx % Self.reminderMessages.count]
            content.sound = sound(for: tone)

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

    // MARK: - Item Reminder (Schedule Block / Appointment)
    /// Schedules a one-shot notification for a specific item on a specific date.
    /// - Parameters:
    ///   - id: Unique ID of the item (used as notification identifier prefix)
    ///   - title: Notification title
    ///   - body: Notification body text
    ///   - itemDate: The calendar date the item belongs to
    ///   - itemTime: The exact time of the item on that date
    ///   - offset: How many minutes before `itemTime` to fire
    ///   - tone: The selected notification tone
    func scheduleItemReminder(
        id: String,
        title: String,
        body: String,
        itemDate: Date,
        itemTime: Date,
        offset: ReminderOffset,
        tone: NotificationTone
    ) {
        // Always remove any previous notification for this item first
        cancelByPrefix("dp_item_\(id)")

        guard let minutesBefore = offset.minutesBefore else { return }

        let cal = Calendar.current
        // Combine itemDate (year/month/day) with itemTime (hour/minute)
        let dayComps  = cal.dateComponents([.year, .month, .day], from: itemDate)
        let timeComps = cal.dateComponents([.hour, .minute], from: itemTime)

        var merged = DateComponents()
        merged.year   = dayComps.year
        merged.month  = dayComps.month
        merged.day    = dayComps.day
        merged.hour   = timeComps.hour
        merged.minute = timeComps.minute
        merged.second = 0

        guard let fireBase = cal.date(from: merged),
              let fireDate = cal.date(byAdding: .minute, value: -minutesBefore, to: fireBase),
              fireDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = sound(for: tone)

        let triggerComps = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

        let request = UNNotificationRequest(
            identifier: "dp_item_\(id)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Schedule a reminder for a ScheduleBlock using its string-based startTime
    func scheduleBlockReminder(
        block: ScheduleBlock,
        date: Date,
        tone: NotificationTone
    ) {
        cancelByPrefix("dp_item_\(block.id.uuidString)")
        guard block.reminderOffset != .none,
              let parsedTime = parseTimeString(block.startTime)
        else { return }

        scheduleItemReminder(
            id: block.id.uuidString,
            title: "Schedule Reminder",
            body: "\(block.activity) starts \(block.reminderOffset == .atTime ? "now" : block.reminderOffset.rawValue.lowercased())",
            itemDate: date,
            itemTime: parsedTime,
            offset: block.reminderOffset,
            tone: tone
        )
    }

    /// Schedule a reminder for an Appointment
    func scheduleAppointmentReminder(
        appointment: Appointment,
        date: Date,
        tone: NotificationTone
    ) {
        cancelByPrefix("dp_item_\(appointment.id.uuidString)")
        guard appointment.reminderOffset != .none else { return }

        let label = appointment.reminderOffset == .atTime ? "now" : appointment.reminderOffset.rawValue.lowercased()
        var body = "\(appointment.title) is \(label)"
        if !appointment.location.isEmpty {
            body += " at \(appointment.location)"
        }

        scheduleItemReminder(
            id: appointment.id.uuidString,
            title: "Appointment Reminder",
            body: body,
            itemDate: date,
            itemTime: appointment.time,
            offset: appointment.reminderOffset,
            tone: tone
        )
    }

    // MARK: - Cancel helpers
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancelByPrefix(_ prefix: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }

    func cancelItemReminder(id: String) {
        cancelByPrefix("dp_item_\(id)")
    }

    // MARK: - Time string parser
    /// Converts "9:00 AM" style strings to a Date with the correct hour/minute
    private func parseTimeString(_ timeStr: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.date(from: timeStr)
    }
}
