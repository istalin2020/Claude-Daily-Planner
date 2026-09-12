import AudioToolbox
import Foundation
import UserNotifications

// MARK: - Notification Manager
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        // Register as delegate so reminders can show banner + sound
        // even when the app is already in the foreground.
        UNUserNotificationCenter.current().delegate = self
    }

    // Show banner and play sound for reminders that arrive while the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

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

    /// Titles used when a reminder names a specific pending priority.
    static let taskReminderTitles: [String] = [
        "⭐️ Top Priority",
        "⭐️ Still pending",
        "⭐️ Don't forget",
        "⭐️ Your priority today",
        "⭐️ Quick reminder"
    ]

    /// Short nudges appended under the task name.
    static let taskReminderNudges: [String] = [
        "Tap to open Daily Planner and tick it off.",
        "A few minutes now beats a whole day of waiting.",
        "Small step, big progress — you've got this!",
        "Knock this one out and keep the streak going.",
        "Still on your list — ready when you are."
    ]

    // MARK: - Permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    // MARK: - Sound helper (for scheduled notifications)
    private func sound(for tone: NotificationTone) -> UNNotificationSound {
        guard let file = tone.soundFileName else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: file))
    }

    // MARK: - Tone preview (immediate in-app playback)
    /// Plays the chosen tone immediately using AudioToolbox so the user hears
    /// a truly distinct sound for every option in the picker.
    ///
    /// Strategy:
    ///  1. Try AudioServicesCreateSystemSoundID from the iOS system sound
    ///     directories — AudioToolbox has read access to these paths even
    ///     inside the sandbox, so the exact system sound file is used.
    ///  2. If that fails (file absent / iOS version difference), fall back to
    ///     a hand-picked SystemSoundID that is audibly distinct per tone.
    func playPreview(tone: NotificationTone) {
        if let fileName = tone.soundFileName {
            // iOS stores its alert/notification sounds in these directories.
            let dirs = [
                "/System/Library/Audio/UISounds/",
                "/System/Library/Audio/UISounds/Modern/",
                "/System/Library/Audio/UISounds/New/"
            ]
            for dir in dirs {
                let url = URL(fileURLWithPath: dir + fileName) as CFURL
                var sid: SystemSoundID = 0
                if AudioServicesCreateSystemSoundID(url, &sid) == kAudioServicesNoError {
                    AudioServicesPlaySystemSound(sid)
                    AudioServicesDisposeSystemSoundID(sid)
                    return
                }
            }
        }
        // Fallback: distinct, well-known iOS system alert-sound IDs.
        AudioServicesPlaySystemSound(Self.fallbackSoundID(for: tone))
    }

    /// Maps each tone to a distinct iOS system sound ID used when the
    /// system-path approach cannot locate the named file.
    private static func fallbackSoundID(for tone: NotificationTone) -> SystemSoundID {
        switch tone {
        case .defaultTone: return 1007  // new-mail / tri-tone
        case .triTone:     return 1007  // tri-tone (identical to default by design)
        case .chime:       return 1013  // chime / lock
        case .glass:       return 1009  // crystal ping
        case .beacon:      return 1022  // calendar alert
        case .bulletin:    return 1016  // tweet / bulletin
        case .bamboo:      return 1057  // subtle tap
        case .chord:       return 1008  // mail-sent chord
        }
    }

    // MARK: - Daily Reminders
    /// Cancels ONLY daily-reminder notifications (prefix "dp_reminder_"),
    /// then schedules reminders for each entry in `times`.
    ///
    /// When `pendingPriorities` is non-empty, every reminder names one of the
    /// user's pending Top Priorities, chosen at random and varied across days
    /// so consecutive reminders rarely repeat the same task.
    ///
    /// iOS fixes a notification's text when it is scheduled — there is no way
    /// to compute the body at delivery time — so concrete (non-repeating)
    /// notifications are scheduled for the next `daysAhead` days and refreshed
    /// whenever the task list changes or the app foregrounds. If no tasks are
    /// pending we fall back to the classic repeating motivational reminders.
    func scheduleNotifications(times: [Date],
                               tone: NotificationTone = .defaultTone,
                               pendingPriorities: [String] = []) {
        cancelByPrefix("dp_reminder_")
        guard !times.isEmpty else { return }

        let cal = Calendar.current
        let tasks = pendingPriorities
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // ── No pending tasks: keep the simple repeating reminders ──────────
        guard !tasks.isEmpty else {
            for (idx, time) in times.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Daily Planner"
                content.body  = Self.reminderMessages[idx % Self.reminderMessages.count]
                content.sound = sound(for: tone)

                var comps = cal.dateComponents([.hour, .minute], from: time)
                comps.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let request = UNNotificationRequest(identifier: "dp_reminder_\(idx)",
                                                    content: content,
                                                    trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
            return
        }

        // ── Pending tasks: name one in each reminder ───────────────────────
        // Shuffle once, then walk the list so every task gets surfaced before
        // any repeats — random order, but fair coverage.
        var bag = tasks.shuffled()
        var bagIndex = 0
        func nextTask() -> String {
            if bagIndex >= bag.count {
                bag = tasks.shuffled()
                bagIndex = 0
            }
            defer { bagIndex += 1 }
            return bag[bagIndex]
        }

        let daysAhead = 7
        let now = Date()
        var scheduled = 0

        for dayOffset in 0..<daysAhead {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            for (idx, time) in times.enumerated() {
                let timeComps = cal.dateComponents([.hour, .minute], from: time)
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour   = timeComps.hour
                comps.minute = timeComps.minute
                comps.second = 0

                // Skip slots already past today.
                guard let fireDate = cal.date(from: comps), fireDate > now else { continue }

                let task = nextTask()
                let content = UNMutableNotificationContent()
                content.title = Self.taskReminderTitles[scheduled % Self.taskReminderTitles.count]
                content.body  = "\(task)\n\(Self.taskReminderNudges[scheduled % Self.taskReminderNudges.count])"
                content.sound = sound(for: tone)

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "dp_reminder_d\(dayOffset)_t\(idx)",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                scheduled += 1
            }
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

    // MARK: - Share Received Notification
    /// Schedules an immediate (1-second delay) local notification to confirm
    /// that a shared task list has been accepted on this device.
    func scheduleShareReceivedNotification(
        senderName  : String,
        sectionName : String,
        taskCount   : Int,
        isUpdate    : Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = isUpdate ? "Shared List Updated" : "New Shared List Received"
        let verb = isUpdate ? "updated" : "shared"
        content.body  = "\(senderName) \(verb) \(taskCount) task\(taskCount == 1 ? "" : "s") in \(sectionName) with you."
        content.sound = .default

        // Fire after 1 second so the notification is visible even if the app
        // goes to the foreground immediately after the deep-link is processed.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "dp_share_received_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
