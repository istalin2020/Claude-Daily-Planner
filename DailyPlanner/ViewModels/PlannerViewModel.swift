import Foundation
import SwiftUI
import Combine
import WidgetKit

class PlannerViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var entries: [String: DailyEntry] = [:]
    @Published var selectedSection: AppSection = .overview {
        didSet {
            if selectedSection == .overview && oldValue != .overview {
                lastVisitedSection = oldValue
            }
        }
    }
    var lastVisitedSection: AppSection? = nil
    @Published var settings: AppSettings = AppSettings()
    @Published var iCloudAvailable = false
    @Published var highlightedTaskID: UUID? = nil
    /// Cached medication log for today — updated on toggle and on day change.
    /// Views should read this instead of calling medicationLogsForToday() directly.
    @Published private(set) var todayMedicationLogs: Set<UUID> = []

    // MARK: - Carry Forward State
    /// Set to true when a new-month carry-forward prompt needs to be shown.
    @Published var showCarryForwardPrompt: Bool = false
    /// The previous month's balance and savings amounts available for carry-forward.
    @Published var pendingCarryForwardAmounts: (balance: Double, savings: Double, monthLabel: String)? = nil

    // MARK: - Share Accept State
    /// Published info for the most recently accepted shared list.
    /// Views observe this to show an in-app confirmation banner.
    @Published var lastAcceptedShareInfo: ShareAcceptedInfo? = nil

    struct ShareAcceptedInfo: Equatable {
        var senderName  : String
        var sectionName : String
        var taskCount   : Int
        var isUpdate    : Bool
    }

    // Tracks the calendar day on which we last ran rollover.
    // Stored in UserDefaults so it survives app kills.
    private var lastRolloverDateKey: String {
        UserDefaults.standard.string(forKey: "lastRolloverDate") ?? ""
    }

    // Legacy UserDefaults key kept only for one-time migration
    private let legacyStorageKey = "DailyPlannerEntries_v1"
    private var cancellables = Set<AnyCancellable>()
    private var cloudDocsURL: URL?
    private let iCloudContainerID = "iCloud.com.istalin.DailyPlanner"
    private var metadataQuery: NSMetadataQuery?

    // Shared DateFormatter — DateFormatter init is expensive; reuse a single instance
    private let _dateKeyFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()

    // MARK: - Documents URLs (data survives Xcode rebuilds on device)
    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var entriesURL: URL { docsDir.appendingPathComponent("planner_entries.json") }
    private var settingsURL: URL { docsDir.appendingPathComponent("planner_settings.json") }

    // MARK: - Active URLs (prefer iCloud when available)
    private var activeEntriesURL: URL {
        cloudDocsURL?.appendingPathComponent("planner_entries.json") ?? entriesURL
    }
    private var activeSettingsURL: URL {
        cloudDocsURL?.appendingPathComponent("planner_settings.json") ?? settingsURL
    }

    init() {
        loadSettings()
        loadData()
        setupiCloud()
        checkForRollover()
        // Record today so checkRolloverIfNeeded skips a redundant run
        // when the app first foregrounds after a cold launch.
        UserDefaults.standard.set(
            dateKey(for: Calendar.current.startOfDay(for: Date())),
            forKey: "lastRolloverDate"
        )
        setupAutoSave()
        // Re-apply notifications on launch in case they were cleared
        if settings.notificationsEnabled {
            NotificationManager.shared.scheduleNotifications(
                times: settings.notificationTimes, tone: settings.notificationTone)
        }
        todayMedicationLogs = medicationLogsForToday()
    }

    // MARK: - Date Key
    func dateKey(for date: Date) -> String {
        _dateKeyFormatter.string(from: date)
    }

    var selectedDateKey: String { dateKey(for: selectedDate) }

    // MARK: - Current Entry Access
    var currentEntry: DailyEntry {
        get { entries[selectedDateKey] ?? DailyEntry(date: selectedDate) }
        set {
            entries[selectedDateKey] = newValue
            objectWillChange.send()
        }
    }

    func entry(for date: Date) -> DailyEntry {
        entries[dateKey(for: date)] ?? DailyEntry(date: date)
    }

    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    // All dates are fully editable — users can plan up to 12 months ahead
    var isFuture: Bool { false }

    // MARK: - Date Navigation
    func selectToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    func select(date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    // MARK: - Reorder helper
    /// Stable-sorts an array so incomplete items stay on top and completed
    /// items sink to the bottom, preserving relative order within each group.
    private func sortedByCompletion<T>(_ items: [T], isCompleted: (T) -> Bool) -> [T] {
        let incomplete = items.filter { !isCompleted($0) }
        let completed  = items.filter { isCompleted($0) }
        return incomplete + completed
    }

    // MARK: - Top Priorities
    func addTopPriority(_ title: String, recurrence: Recurrence = .none, notes: String = "", subtasks: [SubTask] = []) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces),
                               notes: notes, recurrence: recurrence, subtasks: subtasks)
        if let idx = e.topPriorities.firstIndex(where: { $0.isCompleted }) {
            e.topPriorities.insert(task, at: idx)
        } else {
            e.topPriorities.append(task)
        }
        currentEntry = e
    }

    func toggleTopPriority(_ task: PlannerTask) {
        var e = currentEntry
        var newState = task.isCompleted
        if let i = e.topPriorities.firstIndex(where: { $0.id == task.id }) {
            e.topPriorities[i].isCompleted.toggle()
            newState = e.topPriorities[i].isCompleted
        }
        e.topPriorities = sortedByCompletion(e.topPriorities) { $0.isCompleted }
        currentEntry = e
        // Propagate completion back to the original past-day entry so the
        // rollover engine never re-picks up an already-handled task.
        syncTaskCompletion(taskId: task.id, isCompleted: newState)
        if let t = e.topPriorities.first(where: { $0.id == task.id }) { scheduleNextRecurrence(task: t, in: \.topPriorities) }
    }

    func updateTopPriority(_ task: PlannerTask, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var e = currentEntry
        if let i = e.topPriorities.firstIndex(where: { $0.id == task.id }) {
            e.topPriorities[i].title = trimmed
        }
        currentEntry = e
    }

    func updateTopPriority(_ original: PlannerTask, with updated: PlannerTask) {
        var e = currentEntry
        if let i = e.topPriorities.firstIndex(where: { $0.id == original.id }) {
            e.topPriorities[i] = updated
        }
        currentEntry = e
    }

    func deleteTopPriority(_ task: PlannerTask) {
        syncTaskDeletion(taskId: task.id)
    }

    func deleteTopPriority(at offsets: IndexSet) {
        let ids = offsets.map { currentEntry.topPriorities[$0].id }
        for id in ids { syncTaskDeletion(taskId: id) }
    }

    // MARK: - To-Do Lists
    func addToDoListItem(_ title: String, recurrence: Recurrence = .none, notes: String = "", subtasks: [SubTask] = []) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces),
                               notes: notes, recurrence: recurrence, subtasks: subtasks)
        // Insert before the first completed fresh (non-rolled-over) task so the
        // new item always lands below open tasks and above completed tasks.
        if let idx = e.toDoLists.firstIndex(where: { $0.isCompleted }) {
            e.toDoLists.insert(task, at: idx)
        } else {
            e.toDoLists.append(task)
        }
        currentEntry = e
    }

    func toggleToDoListItem(_ task: PlannerTask) {
        var e = currentEntry
        var newState = task.isCompleted
        if let i = e.toDoLists.firstIndex(where: { $0.id == task.id }) {
            e.toDoLists[i].isCompleted.toggle()
            newState = e.toDoLists[i].isCompleted
        }
        e.toDoLists = sortedByCompletion(e.toDoLists) { $0.isCompleted }
        currentEntry = e
        syncTaskCompletion(taskId: task.id, isCompleted: newState)
        if let t = e.toDoLists.first(where: { $0.id == task.id }) { scheduleNextRecurrence(task: t, in: \.toDoLists) }
    }

    func updateToDoListItem(_ task: PlannerTask, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var e = currentEntry
        if let i = e.toDoLists.firstIndex(where: { $0.id == task.id }) {
            e.toDoLists[i].title = trimmed
        }
        currentEntry = e
    }

    func updateToDoListItem(_ original: PlannerTask, with updated: PlannerTask) {
        var e = currentEntry
        if let i = e.toDoLists.firstIndex(where: { $0.id == original.id }) {
            e.toDoLists[i] = updated
        }
        currentEntry = e
    }

    func deleteToDoListItem(_ task: PlannerTask) {
        syncTaskDeletion(taskId: task.id)
    }

    func deleteToDoListItem(at offsets: IndexSet) {
        let ids = offsets.map { currentEntry.toDoLists[$0].id }
        for id in ids { syncTaskDeletion(taskId: id) }
    }

    // MARK: - Calls & Emails
    func addCallEmail(_ title: String, recurrence: Recurrence = .none, notes: String = "", subtasks: [SubTask] = []) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces),
                               notes: notes, recurrence: recurrence, subtasks: subtasks)
        if let idx = e.callsEmails.firstIndex(where: { $0.isCompleted }) {
            e.callsEmails.insert(task, at: idx)
        } else {
            e.callsEmails.append(task)
        }
        currentEntry = e
    }

    func toggleCallEmail(_ task: PlannerTask) {
        var e = currentEntry
        var newState = task.isCompleted
        if let i = e.callsEmails.firstIndex(where: { $0.id == task.id }) {
            e.callsEmails[i].isCompleted.toggle()
            newState = e.callsEmails[i].isCompleted
        }
        e.callsEmails = sortedByCompletion(e.callsEmails) { $0.isCompleted }
        currentEntry = e
        syncTaskCompletion(taskId: task.id, isCompleted: newState)
        if let t = e.callsEmails.first(where: { $0.id == task.id }) { scheduleNextRecurrence(task: t, in: \.callsEmails) }
    }

    // MARK: - Recurring Task Helper
    /// When a task with recurrence is completed, create its next occurrence
    /// on the appropriate future date and insert it at the top of the list.
    private func scheduleNextRecurrence(task: PlannerTask, in section: WritableKeyPath<DailyEntry, [PlannerTask]>) {
        guard task.recurrence != .none, task.isCompleted else { return }
        guard let nextDate = nextRecurrenceDate(from: selectedDate, recurrence: task.recurrence) else { return }
        let nextKey = dateKey(for: nextDate)
        var nextEntry = entries[nextKey] ?? DailyEntry(date: nextDate)
        // Don't add if already exists (same UUID)
        guard !nextEntry[keyPath: section].contains(where: { $0.id == task.id }) else { return }
        var newTask = task
        newTask.id = UUID()
        newTask.isCompleted = false
        newTask.isRolledOver = false
        newTask.originalDate = nextDate
        nextEntry[keyPath: section].insert(newTask, at: 0)
        entries[nextKey] = nextEntry
    }

    private func nextRecurrenceDate(from date: Date, recurrence: Recurrence) -> Date? {
        let cal = Calendar.current
        switch recurrence {
        case .none:      return nil
        case .daily:     return cal.date(byAdding: .day, value: 1, to: date)
        case .monthly:   return cal.date(byAdding: .month, value: 1, to: date)
        case .biweekly:  return cal.date(byAdding: .day, value: 14, to: date)
        case .weekly:    return cal.date(byAdding: .day, value: 7, to: date)
        case .weekdays:
            var d = cal.date(byAdding: .day, value: 1, to: date) ?? date
            while cal.isDateInWeekend(d) {
                d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return d
        }
    }

    func updateCallEmail(_ task: PlannerTask, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var e = currentEntry
        if let i = e.callsEmails.firstIndex(where: { $0.id == task.id }) {
            e.callsEmails[i].title = trimmed
        }
        currentEntry = e
    }

    func updateCallEmail(_ original: PlannerTask, with updated: PlannerTask) {
        var e = currentEntry
        if let i = e.callsEmails.firstIndex(where: { $0.id == original.id }) {
            e.callsEmails[i] = updated
        }
        currentEntry = e
    }

    func deleteCallEmail(_ task: PlannerTask) {
        syncTaskDeletion(taskId: task.id)
    }

    func deleteCallEmail(at offsets: IndexSet) {
        let ids = offsets.map { currentEntry.callsEmails[$0].id }
        for id in ids { syncTaskDeletion(taskId: id) }
    }

    // MARK: - Personal To-Do
    func addPersonalTodo(_ title: String, recurrence: Recurrence = .none, notes: String = "", subtasks: [SubTask] = []) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces),
                               notes: notes, recurrence: recurrence, subtasks: subtasks)
        if let idx = e.personalTodo.firstIndex(where: { $0.isCompleted }) {
            e.personalTodo.insert(task, at: idx)
        } else {
            e.personalTodo.append(task)
        }
        currentEntry = e
    }

    func togglePersonalTodo(_ task: PlannerTask) {
        var e = currentEntry
        var newState = task.isCompleted
        if let i = e.personalTodo.firstIndex(where: { $0.id == task.id }) {
            e.personalTodo[i].isCompleted.toggle()
            newState = e.personalTodo[i].isCompleted
        }
        e.personalTodo = sortedByCompletion(e.personalTodo) { $0.isCompleted }
        currentEntry = e
        syncTaskCompletion(taskId: task.id, isCompleted: newState)
        if let t = e.personalTodo.first(where: { $0.id == task.id }) { scheduleNextRecurrence(task: t, in: \.personalTodo) }
    }

    /// Propagates a completion-state change to every other entry that contains
    /// a task with the same UUID.  This is the core fix for rolled-over tasks
    /// re-appearing after the user marks them complete: when a rolled copy on
    /// Day N is toggled, the original record on Day N-1 (or earlier) is updated
    /// to match, so the rollover engine's `!$0.isCompleted` guard sees it as
    /// done and never rolls it forward again.
    private func syncTaskCompletion(taskId: UUID, isCompleted: Bool) {
        let todayKey = selectedDateKey
        for key in entries.keys where key != todayKey {
            guard var entry = entries[key] else { continue }
            var changed = false
            if let i = entry.topPriorities.firstIndex(where: { $0.id == taskId }) {
                entry.topPriorities[i].isCompleted = isCompleted; changed = true
            }
            if let i = entry.toDoLists.firstIndex(where: { $0.id == taskId }) {
                entry.toDoLists[i].isCompleted = isCompleted; changed = true
            }
            if let i = entry.callsEmails.firstIndex(where: { $0.id == taskId }) {
                entry.callsEmails[i].isCompleted = isCompleted; changed = true
            }
            if let i = entry.personalTodo.firstIndex(where: { $0.id == taskId }) {
                entry.personalTodo[i].isCompleted = isCompleted; changed = true
            }
            if changed { entries[key] = entry }
        }
    }

    /// Permanently removes a task from every date entry and records its UUID in
    /// each entry's `deletedTaskIDs` set.  This makes deletions durable across
    /// iCloud syncs: the merge engine will never re-add a task whose UUID
    /// appears in `deletedTaskIDs`, even when an older cloud snapshot still
    /// contains the task.  The rollover engine also honours `deletedTaskIDs`
    /// so deleted tasks are never carried forward to future dates.
    private func syncTaskDeletion(taskId: UUID) {
        var updated = entries
        // Also ensure the deletion is recorded in the current (selected) date
        // entry even if no existing entry matches — this handles the case where
        // the entry hasn't been persisted to the dictionary yet.
        let currentKey = selectedDateKey
        if updated[currentKey] == nil {
            updated[currentKey] = DailyEntry(date: selectedDate)
        }
        for key in updated.keys {
            guard var entry = updated[key] else { continue }
            var changed = false
            if entry.topPriorities.contains(where: { $0.id == taskId }) {
                entry.topPriorities.removeAll { $0.id == taskId }
                changed = true
            }
            if entry.toDoLists.contains(where: { $0.id == taskId }) {
                entry.toDoLists.removeAll { $0.id == taskId }
                changed = true
            }
            if entry.callsEmails.contains(where: { $0.id == taskId }) {
                entry.callsEmails.removeAll { $0.id == taskId }
                changed = true
            }
            if entry.personalTodo.contains(where: { $0.id == taskId }) {
                entry.personalTodo.removeAll { $0.id == taskId }
                changed = true
            }
            if !entry.deletedTaskIDs.contains(taskId) {
                entry.deletedTaskIDs.insert(taskId)
                changed = true
            }
            if changed { updated[key] = entry }
        }
        entries = updated  // Single assignment — triggers auto-save once
    }

    func updatePersonalTodo(_ task: PlannerTask, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var e = currentEntry
        if let i = e.personalTodo.firstIndex(where: { $0.id == task.id }) {
            e.personalTodo[i].title = trimmed
        }
        currentEntry = e
    }

    func updatePersonalTodo(_ original: PlannerTask, with updated: PlannerTask) {
        var e = currentEntry
        if let i = e.personalTodo.firstIndex(where: { $0.id == original.id }) {
            e.personalTodo[i] = updated
        }
        currentEntry = e
    }

    func deletePersonalTodo(_ task: PlannerTask) {
        syncTaskDeletion(taskId: task.id)
    }

    func deletePersonalTodo(at offsets: IndexSet) {
        let ids = offsets.map { currentEntry.personalTodo[$0].id }
        for id in ids { syncTaskDeletion(taskId: id) }
    }

    // MARK: - Water Tracker
    func incrementWater() {
        var e = currentEntry
        if e.waterGlasses < 20 { e.waterGlasses += 1 }
        currentEntry = e
    }

    func decrementWater() {
        var e = currentEntry
        if e.waterGlasses > 0 { e.waterGlasses -= 1 }
        currentEntry = e
    }

    func setWaterGoal(_ goal: Int) {
        var e = currentEntry
        e.waterGoal = max(1, min(20, goal))
        currentEntry = e
    }

    // MARK: - Meals
    func addMealItem(_ item: MealItem, to meal: String) {
        var e = currentEntry
        switch meal {
        case "breakfast": e.meals.breakfastItems.append(item)
        case "lunch":     e.meals.lunchItems.append(item)
        case "dinner":    e.meals.dinnerItems.append(item)
        default:          e.meals.snackItems.append(item)
        }
        currentEntry = e
    }

    func removeMealItem(_ item: MealItem, from meal: String) {
        var e = currentEntry
        switch meal {
        case "breakfast": e.meals.breakfastItems.removeAll { $0.id == item.id }
        case "lunch":     e.meals.lunchItems.removeAll { $0.id == item.id }
        case "dinner":    e.meals.dinnerItems.removeAll { $0.id == item.id }
        default:          e.meals.snackItems.removeAll { $0.id == item.id }
        }
        currentEntry = e
    }

    func updateMealItem(_ original: MealItem, with updated: MealItem, in meal: String) {
        var e = currentEntry
        switch meal {
        case "breakfast":
            if let i = e.meals.breakfastItems.firstIndex(where: { $0.id == original.id }) {
                e.meals.breakfastItems[i] = updated
            }
        case "lunch":
            if let i = e.meals.lunchItems.firstIndex(where: { $0.id == original.id }) {
                e.meals.lunchItems[i] = updated
            }
        case "dinner":
            if let i = e.meals.dinnerItems.firstIndex(where: { $0.id == original.id }) {
                e.meals.dinnerItems[i] = updated
            }
        default:
            if let i = e.meals.snackItems.firstIndex(where: { $0.id == original.id }) {
                e.meals.snackItems[i] = updated
            }
        }
        currentEntry = e
    }

    // MARK: - Fitness
    func addFitnessActivity(_ activity: FitnessActivity) {
        var e = currentEntry
        e.fitness.activities.append(activity)
        currentEntry = e
    }

    func toggleFitnessActivity(_ activity: FitnessActivity) {
        var e = currentEntry
        if let i = e.fitness.activities.firstIndex(where: { $0.id == activity.id }) {
            e.fitness.activities[i].isCompleted.toggle()
        }
        e.fitness.activities = sortedByCompletion(e.fitness.activities) { $0.isCompleted }
        currentEntry = e
    }

    func deleteFitnessActivity(at offsets: IndexSet) {
        var e = currentEntry
        e.fitness.activities.remove(atOffsets: offsets)
        currentEntry = e
    }

    func updateFitnessNotes(_ notes: String) {
        var e = currentEntry
        e.fitness.generalNotes = notes
        currentEntry = e
    }

    func updateSteps(_ steps: Int) {
        var e = currentEntry
        e.fitness.steps = steps
        currentEntry = e
    }

    // MARK: - Daily Schedule
    func addScheduleBlock(_ block: ScheduleBlock) {
        var e = currentEntry
        e.dailySchedule.append(block)
        currentEntry = e
        // Schedule notification if reminder is set
        if block.reminderOffset != .none {
            NotificationManager.shared.scheduleBlockReminder(
                block: block, date: selectedDate, tone: settings.notificationTone)
        }
    }

    func toggleScheduleBlock(_ block: ScheduleBlock) {
        var e = currentEntry
        if let i = e.dailySchedule.firstIndex(where: { $0.id == block.id }) {
            e.dailySchedule[i].isCompleted.toggle()
            // Cancel reminder when completed
            if e.dailySchedule[i].isCompleted {
                NotificationManager.shared.cancelItemReminder(id: block.id.uuidString)
            }
        }
        e.dailySchedule = sortedByCompletion(e.dailySchedule) { $0.isCompleted }
        currentEntry = e
    }

    func deleteScheduleBlock(at offsets: IndexSet) {
        var e = currentEntry
        for idx in offsets {
            let id = e.dailySchedule[idx].id
            NotificationManager.shared.cancelItemReminder(id: id.uuidString)
            e.deletedScheduleBlockIDs.insert(id)
        }
        e.dailySchedule.remove(atOffsets: offsets)
        currentEntry = e
    }

    func deleteScheduleBlock(_ block: ScheduleBlock) {
        var e = currentEntry
        NotificationManager.shared.cancelItemReminder(id: block.id.uuidString)
        e.deletedScheduleBlockIDs.insert(block.id)
        e.dailySchedule.removeAll { $0.id == block.id }
        currentEntry = e
    }

    func updateScheduleBlock(_ block: ScheduleBlock) {
        var e = currentEntry
        if let i = e.dailySchedule.firstIndex(where: { $0.id == block.id }) {
            NotificationManager.shared.cancelItemReminder(id: block.id.uuidString)
            e.dailySchedule[i] = block
            if block.reminderOffset != .none {
                NotificationManager.shared.scheduleBlockReminder(
                    block: block, date: selectedDate, tone: settings.notificationTone)
            }
        }
        currentEntry = e
    }

    // MARK: - Appointments
    func addAppointment(_ appointment: Appointment) {
        var e = currentEntry
        e.appointments.append(appointment)
        e.appointments.sort { $0.time < $1.time }
        currentEntry = e
        // Schedule notification if reminder is set
        if appointment.reminderOffset != .none {
            NotificationManager.shared.scheduleAppointmentReminder(
                appointment: appointment, date: selectedDate, tone: settings.notificationTone)
        }
    }

    func toggleAppointment(_ appointment: Appointment) {
        var e = currentEntry
        if let i = e.appointments.firstIndex(where: { $0.id == appointment.id }) {
            e.appointments[i].isCompleted.toggle()
            // Cancel reminder when completed
            if e.appointments[i].isCompleted {
                NotificationManager.shared.cancelItemReminder(id: appointment.id.uuidString)
            }
        }
        e.appointments = sortedByCompletion(e.appointments) { $0.isCompleted }
        currentEntry = e
    }

    func deleteAppointment(at offsets: IndexSet) {
        var e = currentEntry
        for idx in offsets {
            let id = e.appointments[idx].id
            NotificationManager.shared.cancelItemReminder(id: id.uuidString)
            e.deletedAppointmentIDs.insert(id)
        }
        e.appointments.remove(atOffsets: offsets)
        currentEntry = e
    }

    func deleteAppointment(_ appointment: Appointment) {
        var e = currentEntry
        NotificationManager.shared.cancelItemReminder(id: appointment.id.uuidString)
        e.deletedAppointmentIDs.insert(appointment.id)
        e.appointments.removeAll { $0.id == appointment.id }
        currentEntry = e
    }

    func updateAppointment(_ appointment: Appointment) {
        var e = currentEntry
        if let i = e.appointments.firstIndex(where: { $0.id == appointment.id }) {
            NotificationManager.shared.cancelItemReminder(id: appointment.id.uuidString)
            e.appointments[i] = appointment
            if appointment.reminderOffset != .none {
                NotificationManager.shared.scheduleAppointmentReminder(
                    appointment: appointment, date: selectedDate, tone: settings.notificationTone)
            }
        }
        e.appointments.sort { $0.time < $1.time }
        currentEntry = e
    }

    // MARK: - Notes
    func updateNotes(_ notes: String) {
        var e = currentEntry
        e.notes = notes
        currentEntry = e
    }

    // MARK: - Expenses
    func addExpense(_ expense: Expense) {
        var e = currentEntry
        e.expenses.append(expense)
        currentEntry = e
    }

    func deleteExpense(at offsets: IndexSet) {
        var e = currentEntry
        e.expenses.remove(atOffsets: offsets)
        currentEntry = e
    }

    /// Safe ID-based delete that works regardless of list reordering.
    func deleteExpense(byID id: UUID) {
        var e = currentEntry
        e.expenses.removeAll { $0.id == id }
        e.deletedExpenseIDs.insert(id)
        currentEntry = e
    }

    func updateExpense(_ updated: Expense) {
        var e = currentEntry
        if let idx = e.expenses.firstIndex(where: { $0.id == updated.id }) {
            e.expenses[idx] = updated
            currentEntry = e
        }
    }

    // MARK: - Gmail Expense Sync

    /// Adds an imported expense to the calendar day it actually occurred,
    /// rather than the currently-selected date.
    func addExpense(_ expense: Expense, on date: Date) {
        let key = dateKey(for: date)
        var e = entries[key] ?? DailyEntry(date: date)
        e.expenses.append(expense)
        entries[key] = e
        objectWillChange.send()
    }

    /// Builds an Expense from a parsed Gmail transaction, converting foreign
    /// currency to the user's local currency when needed.
    func expense(from candidate: GmailCandidate,
                 customCategoryLabel: String = "",
                 overrideCategory: ExpenseCategory? = nil) -> Expense {
        let p = candidate.parsed
        let localCurrency = settings.currency.rawValue
        var amount = p.amount
        if CurrencyConverter.needsConversion(detected: p.currencyDetected, local: localCurrency),
           let converted = CurrencyConverter.convert(amount: p.amount, from: p.currencyDetected, to: localCurrency) {
            amount = converted
        }
        let desc = p.merchant.isEmpty ? "\(p.bankName) Transaction" : p.merchant

        if p.isCredit {
            return Expense(amount: amount, category: .other, description: desc,
                           isIncome: true, isFromSMS: true)
        } else {
            let useCustom = !customCategoryLabel.isEmpty
            return Expense(amount: amount,
                           category: useCustom ? .other : (overrideCategory ?? p.category),
                           customCategoryLabel: useCustom ? customCategoryLabel : "",
                           description: desc,
                           isFromSMS: true)
        }
    }

    /// True when a candidate can be added automatically without asking the user:
    /// all credits (income) and debits whose category was confidently detected.
    func gmailCanAutoAdd(_ candidate: GmailCandidate) -> Bool {
        let p = candidate.parsed
        if p.isCredit { return true }
        return p.confidenceCategory == .high && p.category != .other
    }

    /// Records handled Gmail message IDs and advances the incremental cursor.
    /// Pass `advanceCursorTo: nil` to leave the cursor untouched (e.g. when the
    /// user cancels mid-review, so pending items are re-offered next sync).
    func finalizeGmailSync(handledIDs: [String], advanceCursorTo newestEpoch: Double?) {
        settings.gmailProcessedMessageIDs.formUnion(handledIDs)
        if settings.gmailProcessedMessageIDs.count > 1000 {
            settings.gmailProcessedMessageIDs = Set(Array(settings.gmailProcessedMessageIDs).suffix(500))
        }
        if let e = newestEpoch, e > settings.gmailLastSyncEpoch {
            settings.gmailLastSyncEpoch = e
        }
        saveSettings()
    }

    func setGmailConnected(email: String) {
        settings.gmailConnectedEmail = email
        saveSettings()
    }

    func gmailDisconnect() {
        GmailSyncService.shared.disconnect()
        settings.gmailConnectedEmail = ""
        settings.gmailLastSyncEpoch = 0
        settings.gmailProcessedMessageIDs = []
        saveSettings()
    }

    func updateSavings(_ amount: Double) {
        var e = currentEntry
        e.savings = amount
        currentEntry = e
    }

    // MARK: - Bank SMS Import

    func dismissSMSHash(_ text: String) {
        let hash = String(text.hashValue)
        settings.dismissedSMSHashes.insert(hash)
        if settings.dismissedSMSHashes.count > 200 {
            let keep = Array(settings.dismissedSMSHashes.suffix(100))
            settings.dismissedSMSHashes = Set(keep)
        }
        saveSettings()
    }

    // MARK: - HealthKit sync

    /// Saves HealthKit data into a specific date's entry (not selectedDate).
    /// Used by both the app-level foreground sync and the per-view sync.
    func syncHealthKitData(for date: Date, steps: Int, calories: Int,
                           workoutMins: Int, walkingMins: Int, workouts: [HealthWorkout]) {
        let key = dateKey(for: date)
        var e = entries[key] ?? DailyEntry(date: date)
        e.fitness.hkSteps          = steps
        e.fitness.hkCalories       = calories
        e.fitness.hkWorkoutMinutes = workoutMins
        e.fitness.hkWalkingMinutes = walkingMins
        e.fitness.hkWorkouts       = workouts
        e.fitness.hkSyncedAt       = Date()
        if steps > 0 { e.fitness.steps = steps }
        entries[key] = e
        objectWillChange.send()
    }

    /// Backward-compatible overload used by HealthFitnessView (saves to selectedDate).
    func syncHealthKitData(steps: Int, calories: Int, workoutMins: Int,
                           walkingMins: Int, workouts: [HealthWorkout]) {
        syncHealthKitData(for: selectedDate, steps: steps, calories: calories,
                          workoutMins: workoutMins, walkingMins: walkingMins, workouts: workouts)
    }

    /// Silently syncs HealthKit data for today. Called on every app foreground
    /// so data is always fresh regardless of which tab the user is on.
    /// Always targets today's actual calendar date — never selectedDate.
    /// On the first call it also registers HKObserverQuery + enables background
    /// delivery so future Apple Health changes trigger an automatic re-sync.
    func syncHealthKitForToday() {
        guard HealthKitManager.shared.isAvailable else { return }
        let today = Calendar.current.startOfDay(for: Date())
        HealthKitManager.shared.requestAuthorization { [weak self] in
            guard let self else { return }

            // Start live observer queries once after the first successful auth.
            // startObservingHealthData() is idempotent — safe to call every time.
            HealthKitManager.shared.startObservingHealthData { [weak self] in
                guard let self else { return }
                let liveToday = Calendar.current.startOfDay(for: Date())
                HealthKitManager.shared.fetchAllHealthData(for: liveToday) { [weak self] data in
                    guard let self else { return }
                    self.syncHealthKitData(
                        for: liveToday,
                        steps: data.steps,
                        calories: data.calories,
                        workoutMins: data.workoutMinutes,
                        walkingMins: data.walkingMinutes,
                        workouts: data.workouts
                    )
                }
            }

            // Immediate fetch so today's data is current right now.
            HealthKitManager.shared.fetchAllHealthData(for: today) { [weak self] data in
                guard let self else { return }
                self.syncHealthKitData(
                    for: today,
                    steps: data.steps,
                    calories: data.calories,
                    workoutMins: data.workoutMinutes,
                    walkingMins: data.walkingMinutes,
                    workouts: data.workouts
                )
            }
        }
    }

    // MARK: - Monthly Finance Aggregation

    func monthlyEntries(for date: Date) -> [DailyEntry] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return entries.values.filter {
            let ec = cal.dateComponents([.year, .month], from: $0.date)
            return ec.year == comps.year && ec.month == comps.month
        }
    }

    func monthlyEntries(for date: Date, upTo cutoff: Date) -> [DailyEntry] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        let cutoffDay = cal.startOfDay(for: cutoff)
        return entries.values.filter {
            let ec = cal.dateComponents([.year, .month], from: $0.date)
            return ec.year == comps.year && ec.month == comps.month
                && cal.startOfDay(for: $0.date) <= cutoffDay
        }
    }

    func monthlyTotalIncome(for date: Date, upTo cutoff: Date? = nil) -> Double {
        let e = cutoff.map { monthlyEntries(for: date, upTo: $0) } ?? monthlyEntries(for: date)
        return e.flatMap { $0.expenses }
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amount }
    }

    func monthlyExpensesByCategory(for date: Date, upTo cutoff: Date? = nil) -> [(ExpenseCategory, Double)] {
        let e = cutoff.map { monthlyEntries(for: date, upTo: $0) } ?? monthlyEntries(for: date)
        let all = e.flatMap { $0.expenses }
            .filter { !$0.isDeposit && !$0.isIncome }
        var totals: [ExpenseCategory: Double] = [:]
        for exp in all { totals[exp.category, default: 0] += exp.amount }
        return totals.sorted { $0.value > $1.value }
    }

    struct DisplayCategory: Identifiable, Hashable {
        let name: String
        let icon: String
        let color: Color
        var id: String { name }

        static func from(_ expense: Expense) -> DisplayCategory {
            if !expense.customCategoryLabel.isEmpty {
                return DisplayCategory(name: expense.customCategoryLabel, icon: "tag.fill", color: .purple)
            }
            return DisplayCategory(name: expense.category.rawValue, icon: expense.category.icon, color: expense.category.color)
        }
    }

    func monthlyExpensesByDisplayCategory(for date: Date, upTo cutoff: Date? = nil) -> [(DisplayCategory, Double)] {
        let e = cutoff.map { monthlyEntries(for: date, upTo: $0) } ?? monthlyEntries(for: date)
        let all = e.flatMap { $0.expenses }
            .filter { !$0.isDeposit && !$0.isIncome }
        var totals: [String: (DisplayCategory, Double)] = [:]
        for exp in all {
            let dc = DisplayCategory.from(exp)
            totals[dc.name, default: (dc, 0)].1 += exp.amount
        }
        return totals.values.sorted { $0.1 > $1.1 }
    }

    func monthlyTotalExpenses(for date: Date, upTo cutoff: Date? = nil) -> Double {
        monthlyExpensesByCategory(for: date, upTo: cutoff).reduce(0) { $0 + $1.1 }
    }

    func monthlyBalance(for date: Date, upTo cutoff: Date? = nil) -> Double {
        monthlyTotalIncome(for: date, upTo: cutoff) - monthlyTotalExpenses(for: date, upTo: cutoff) - monthlyTotalSavings(for: date, upTo: cutoff)
    }

    func monthlyTotalSavings(for date: Date, upTo cutoff: Date? = nil) -> Double {
        let e = cutoff.map { monthlyEntries(for: date, upTo: $0) } ?? monthlyEntries(for: date)
        return e.flatMap { $0.expenses }
            .filter { $0.isDeposit }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Habits
    func addHabit(_ habit: Habit) {
        settings.habits.append(habit)
    }
    func deleteHabit(_ habit: Habit) {
        settings.habits.removeAll { $0.id == habit.id }
    }
    func updateHabit(_ habit: Habit) {
        if let i = settings.habits.firstIndex(where: { $0.id == habit.id }) {
            settings.habits[i] = habit
        }
    }
    func toggleHabit(_ habit: Habit, for date: Date) {
        let key = dateKey(for: date)
        var log = settings.habitLogs[key] ?? HabitLog()
        if log.completedIDs.contains(habit.id) {
            log.completedIDs.remove(habit.id)
        } else {
            log.completedIDs.insert(habit.id)
        }
        settings.habitLogs[key] = log
        objectWillChange.send()
    }
    func isHabitCompleted(_ habit: Habit, for date: Date) -> Bool {
        settings.habitLogs[dateKey(for: date)]?.completedIDs.contains(habit.id) ?? false
    }
    func habitStreak(_ habit: Habit) -> Int {
        var streak = 0
        var date = Calendar.current.startOfDay(for: Date())
        let cal = Calendar.current
        for daysBack in 0...365 {
            if isHabitCompleted(habit, for: date) {
                streak += 1
            } else if streak > 0 {
                // Streak broken — stop looking further back
                break
            } else if daysBack > 0 {
                // Neither today nor any consecutive prior day was completed — no active streak
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    // MARK: - Sleep
    func updateSleep(_ sleep: SleepEntry) {
        var e = currentEntry
        e.sleep = sleep
        currentEntry = e
    }

    // MARK: - Medications
    private let medLogsKey = "medication_logs"

    func medicationLogsForToday() -> Set<UUID> {
        let key = dateKey(for: Date())
        guard let data = UserDefaults.standard.data(forKey: "\(medLogsKey)_\(key)"),
              let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else { return [] }
        return ids
    }

    func toggleMedicationTaken(_ med: Medication) {
        let key = dateKey(for: Date())
        // Use the in-memory state to avoid stale reads on rapid taps
        var logs = todayMedicationLogs
        if logs.contains(med.id) { logs.remove(med.id) } else { logs.insert(med.id) }
        // Update in-memory state immediately so rapid taps see the correct state
        todayMedicationLogs = logs
        // Persist to UserDefaults asynchronously
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: "\(medLogsKey)_\(key)")
        }
    }

    func addMedication(_ med: Medication) {
        settings.medications.append(med)
        saveSettings()
    }

    func deleteMedication(_ med: Medication) {
        settings.medications.removeAll { $0.id == med.id }
        saveSettings()
    }

    func toggleMedicationActive(_ med: Medication) {
        if let i = settings.medications.firstIndex(where: { $0.id == med.id }) {
            settings.medications[i].isActive.toggle()
            saveSettings()
        }
    }

    // MARK: - Budget
    func budget(for category: ExpenseCategory) -> Double? {
        settings.categoryBudgets[category.rawValue]
    }
    func setBudget(_ amount: Double?, for category: ExpenseCategory) {
        if let amount = amount, amount > 0 {
            settings.categoryBudgets[category.rawValue] = amount
        } else {
            settings.categoryBudgets.removeValue(forKey: category.rawValue)
        }
    }
    func monthlySpent(for category: ExpenseCategory, date: Date) -> Double {
        monthlyEntries(for: date)
            .flatMap { $0.expenses }
            .filter { !$0.isDeposit && !$0.isIncome && $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Rating
    func updateRating(_ rating: DayRating) {
        var e = currentEntry
        e.rating = rating
        currentEntry = e
    }

    // MARK: - Siri Shortcut Pending Actions
    /// Reads any tasks or water-log actions queued by Siri Shortcuts / AppIntents
    /// and applies them to today's entry. Called every time the app foregrounds.
    func processPendingShortcutActions() {
        let suite = UserDefaults(suiteName: "group.com.istalin.DailyPlanner")

        // ── Add Task ─────────────────────────────────────────────────────────
        let pendingTaskKey = "shortcut_pending_task"
        if let data = suite?.data(forKey: pendingTaskKey),
           let payload = try? JSONDecoder().decode([String: String].self, from: data),
           let title = payload["title"], !title.isEmpty {
            let section = payload["section"] ?? "Top Priorities"
            switch section {
            case "To-Do Lists":    addToDoListItem(title)
            case "Personal To-Do": addPersonalTodo(title)
            default:               addTopPriority(title)
            }
            suite?.removeObject(forKey: pendingTaskKey)
        }

        // ── Log Water ─────────────────────────────────────────────────────────
        let waterKey = "shortcut_log_water"
        if suite?.bool(forKey: waterKey) == true {
            incrementWater()
            suite?.removeObject(forKey: waterKey)
        }
    }

    // MARK: - Rollover
    /// Automatically rolls over incomplete tasks from any missed past days
    /// (up to 30 days back) into today's entry. Uses task-ID deduplication so
    /// the same task is never added twice, and works even when today's entry
    /// already exists (e.g. user opened the app earlier today).
    func checkForRollover() {
        guard settings.autoRollover else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let tKey  = dateKey(for: today)
        var te    = entries[tKey] ?? DailyEntry(date: today)

        // Accumulate every deleted task UUID from all stored entries so that a
        // task deleted from any day is permanently suppressed from rollover —
        // even when today's entry is brand-new (e.g. first open of a new day).
        var allDeletedIDs: Set<UUID> = te.deletedTaskIDs
        for (_, entry) in entries { allDeletedIDs.formUnion(entry.deletedTaskIDs) }
        te.deletedTaskIDs = allDeletedIDs

        // Build a set of task IDs already present in today's entry so we never
        // add the same task twice, even across multiple rollover passes.
        var existingIDs: Set<UUID> = Set(
            te.topPriorities.map(\.id) +
            te.toDoLists.map(\.id) +
            te.callsEmails.map(\.id) +
            te.personalTodo.map(\.id)
        )

        var updatedEntries = entries
        var didChange = false

        // Walk backwards through the last 30 days to catch any missed days.
        for daysBack in 1...30 {
            guard let pastDate = Calendar.current.date(
                byAdding: .day, value: -daysBack, to: today
            ) else { continue }
            let pastKey = dateKey(for: pastDate)

            guard var pastEntry = updatedEntries[pastKey] else { continue }

            // Collect tasks that are still incomplete, not yet in today,
            // and have NOT been explicitly deleted by the user.
            let missingPriorities = pastEntry.topPriorities.filter {
                !$0.isCompleted && !existingIDs.contains($0.id) && !allDeletedIDs.contains($0.id)
            }
            let missingTodos = pastEntry.toDoLists.filter {
                !$0.isCompleted && !existingIDs.contains($0.id) && !allDeletedIDs.contains($0.id)
            }
            let missingCalls = pastEntry.callsEmails.filter {
                !$0.isCompleted && !existingIDs.contains($0.id) && !allDeletedIDs.contains($0.id)
            }
            let missingPersonal = pastEntry.personalTodo.filter {
                !$0.isCompleted && !existingIDs.contains($0.id) && !allDeletedIDs.contains($0.id)
            }

            guard !missingPriorities.isEmpty || !missingTodos.isEmpty
                    || !missingCalls.isEmpty || !missingPersonal.isEmpty
            else { continue }

            // Insert rolled-over tasks at the top of today's lists.
            for var task in missingPriorities {
                task.isRolledOver = true
                task.originalDate = pastDate
                te.topPriorities.insert(task, at: 0)
                existingIDs.insert(task.id)
            }
            for var task in missingTodos {
                task.isRolledOver = true
                task.originalDate = pastDate
                te.toDoLists.insert(task, at: 0)
                existingIDs.insert(task.id)
            }
            for var task in missingCalls {
                task.isRolledOver = true
                task.originalDate = pastDate
                te.callsEmails.insert(task, at: 0)
                existingIDs.insert(task.id)
            }
            for var task in missingPersonal {
                task.isRolledOver = true
                task.originalDate = pastDate
                te.personalTodo.insert(task, at: 0)
                existingIDs.insert(task.id)
            }

            // Mark the source entry's tasks as rolled over so they won't be
            // picked up again on the next app launch.
            for i in pastEntry.topPriorities.indices where !pastEntry.topPriorities[i].isCompleted {
                pastEntry.topPriorities[i].isRolledOver = true
            }
            for i in pastEntry.toDoLists.indices where !pastEntry.toDoLists[i].isCompleted {
                pastEntry.toDoLists[i].isRolledOver = true
            }
            for i in pastEntry.callsEmails.indices where !pastEntry.callsEmails[i].isCompleted {
                pastEntry.callsEmails[i].isRolledOver = true
            }
            for i in pastEntry.personalTodo.indices where !pastEntry.personalTodo[i].isCompleted {
                pastEntry.personalTodo[i].isRolledOver = true
            }

            updatedEntries[pastKey] = pastEntry
            didChange = true
        }

        if didChange {
            updatedEntries[tKey] = te
            entries = updatedEntries
            saveData()
        }
    }

    /// Called every time the app enters the foreground. Runs rollover only when
    /// the calendar day has advanced since the last run — works regardless of
    /// network, WiFi, or cellular state because everything is local.
    func checkRolloverIfNeeded() {
        let todayKey = dateKey(for: Calendar.current.startOfDay(for: Date()))
        guard todayKey != lastRolloverDateKey else { return }
        checkForRollover()
        UserDefaults.standard.set(todayKey, forKey: "lastRolloverDate")
        // Refresh medication log cache since the calendar day has advanced
        todayMedicationLogs = medicationLogsForToday()
    }

    /// Manual rollover trigger (e.g. from Settings). Delegates to checkForRollover
    /// which already handles deduplication and multi-day lookback.
    func performRollover() {
        checkForRollover()
    }

    // MARK: - Monthly Carry Forward

    /// Checks whether we've entered a new calendar month that has not yet been
    /// prompted for carry-forward.  Safe to call every time the app foregrounds.
    func checkMonthlyCarryForward() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Only prompt on the first day of a new month (or first open in a new month).
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let thisMonthKey = fmt.string(from: today)

        // Already prompted this month — nothing to do.
        guard settings.lastCarryForwardMonthKey != thisMonthKey else { return }

        // Compute the previous month.
        guard let prevMonthDate = cal.date(byAdding: .month, value: -1, to: today) else { return }

        let prevBalance = monthlyBalance(for: prevMonthDate)
        let prevSavings = monthlyTotalSavings(for: prevMonthDate)

        // Nothing meaningful to carry forward — silently record that we checked.
        guard prevBalance != 0 || prevSavings != 0 else {
            settings.lastCarryForwardMonthKey = thisMonthKey
            saveSettings()
            return
        }

        let prevLabelFmt = DateFormatter()
        prevLabelFmt.dateFormat = "MMMM yyyy"
        let prevLabel = prevLabelFmt.string(from: prevMonthDate)

        if settings.autoCarryForward {
            // Auto-apply without showing any popup.
            pendingCarryForwardAmounts = (balance: prevBalance, savings: prevSavings, monthLabel: prevLabel)
            applyCarryForward(carryBalance: true, carrySavings: prevSavings > 0)
        } else {
            // Setting is off — silently mark as done (no popup).
            settings.lastCarryForwardMonthKey = thisMonthKey
            saveSettings()
        }
    }

    /// Called after the user responds to the carry-forward prompt.
    /// - Parameters:
    ///   - carryBalance: Add previous month's balance as an income entry today.
    ///   - carrySavings: Add previous month's savings as a savings entry today.
    func applyCarryForward(carryBalance: Bool, carrySavings: Bool) {
        guard let amounts = pendingCarryForwardAmounts else {
            markCarryForwardDone()
            return
        }

        var e = entries[dateKey(for: Calendar.current.startOfDay(for: Date()))]
            ?? DailyEntry(date: Calendar.current.startOfDay(for: Date()))
        let today = Calendar.current.startOfDay(for: Date())
        let key = dateKey(for: today)

        if carryBalance && amounts.balance != 0 {
            let sign = amounts.balance > 0 ? "Balance" : "Deficit"
            let entry = Expense(
                amount: abs(amounts.balance),
                category: .other,
                customCategoryLabel: "",
                description: "Carry Forward (\(sign) from \(amounts.monthLabel))",
                isDeposit: false,
                isIncome: amounts.balance > 0
            )
            e.expenses.append(entry)
        }

        if carrySavings && amounts.savings > 0 {
            let entry = Expense(
                amount: amounts.savings,
                category: .other,
                customCategoryLabel: "",
                description: "Carry Forward (Savings from \(amounts.monthLabel))",
                isDeposit: true,
                isIncome: false
            )
            e.expenses.append(entry)
        }

        entries[key] = e
        markCarryForwardDone()
    }

    private func markCarryForwardDone() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        settings.lastCarryForwardMonthKey = fmt.string(from: Date())
        saveSettings()
        DispatchQueue.main.async {
            self.pendingCarryForwardAmounts = nil
            self.showCarryForwardPrompt = false
        }
    }

    // MARK: - Persistence (Documents Directory)
    //
    // Data lives in the app's Documents folder, which iOS preserves across
    // Xcode "Run" (update-install) sessions on a real device.  Data is only
    // removed when the user explicitly deletes the app.
    //
    // Saves are performed on a dedicated serial background queue so the main
    // thread is never blocked, while still guaranteeing write order.  Every
    // mutation to `entries` triggers an immediate async write — no debounce —
    // so even a rapid Xcode kill cannot race past an in-flight save.
    // Additionally, DailyPlannerApp observes scenePhase and calls
    // saveDataNow() / saveSettings() synchronously on .background / .inactive
    // as a final safety net.

    private let saveQueue = DispatchQueue(label: "com.dailyplanner.save", qos: .utility)

    /// Asynchronous write — called automatically on every `entries` change.
    /// Always writes to both the active URL (iCloud when available) AND the
    /// local Documents file so the local copy never becomes stale.  This
    /// prevents scalar fields (water, rating, etc.) from being overwritten
    /// by a stale local snapshot on the next launch merge.
    func saveData() {
        let snapshot  = entries
        let activeUrl = activeEntriesURL
        let localUrl  = entriesURL
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: activeUrl, options: .atomic)
            if activeUrl != localUrl {
                try? data.write(to: localUrl, options: .atomic)
            }
        }
    }

    /// Synchronous write — called from scenePhase hook and on explicit demand.
    /// Blocks the calling thread until the file is on disk, guaranteeing the
    /// data survives an imminent SIGKILL from Xcode or the OS.
    func saveDataNow() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: activeEntriesURL, options: .atomic)
        if activeEntriesURL != entriesURL {
            try? data.write(to: entriesURL, options: .atomic)
        }
    }

    func loadData() {
        // Try to load from every source and pick the richest data set.
        // This prevents an empty or not-yet-downloaded iCloud file from
        // silently wiping valid local data on first launch after reinstall.

        var cloudDecoded: [String: DailyEntry]?
        var localDecoded: [String: DailyEntry]?

        // Cloud (only attempted when cloudDocsURL is set)
        if cloudDocsURL != nil,
           let data = try? Data(contentsOf: activeEntriesURL),
           let decoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data) {
            cloudDecoded = decoded
        }

        // Local Documents directory
        if let data = try? Data(contentsOf: entriesURL),
           let decoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data) {
            localDecoded = decoded
        }

        switch (cloudDecoded, localDecoded) {
        case (.some(let cloud), .some(let local)):
            // Both sources available: perform a task-level merge for every date.
            // Cloud is treated as "memory" (most recently written — all saves go
            // to activeEntriesURL which is the cloud file when iCloud is enabled).
            // Local is treated as "disk" (may be a slightly older mirror).
            // mergeEntries unions deletedTaskIDs from both sides so nothing is
            // accidentally resurrected, and task-only-in-local entries are still
            // preserved via the union append path.
            var merged: [String: DailyEntry] = [:]
            let allKeys = Set(cloud.keys).union(Set(local.keys))
            for key in allKeys {
                switch (cloud[key], local[key]) {
                case (.some(let c), .some(let l)):
                    merged[key] = Self.mergeEntries(disk: l, memory: c)
                case (.some(let c), .none):
                    merged[key] = c
                case (.none, .some(let l)):
                    merged[key] = l
                default:
                    break
                }
            }
            entries = merged
        case (.some(let cloud), .none):
            entries = cloud
        case (.none, .some(let local)):
            entries = local
        case (.none, .none):
            // Fallback: one-time migration from UserDefaults (legacy)
            if let data = UserDefaults.standard.data(forKey: legacyStorageKey),
               let decoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data) {
                entries = decoded
                saveDataNow()
                UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            }
        }
    }

    func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: activeSettingsURL, options: .atomic)
        // Sync notifications
        if settings.notificationsEnabled {
            NotificationManager.shared.scheduleNotifications(
                times: settings.notificationTimes, tone: settings.notificationTone)
        } else {
            NotificationManager.shared.cancelAll()
        }
    }

    func loadSettings() {
        guard let data = try? Data(contentsOf: activeSettingsURL),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return }
        settings = decoded
    }

    private func setupAutoSave() {
        // Write entries to disk immediately on every change.
        // .dropFirst() skips the initial publisher emission at subscription
        // time (which would just re-save the data we just loaded).
        $entries
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveData()
                self?.updateWidgetData()
            }
            .store(in: &cancellables)

        // Push shared task lists to CloudKit 3 seconds after any task change.
        // The debounce avoids flooding CloudKit on rapid edits.
        $entries
            .dropFirst()
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.pushSharedListsToCloud() }
            .store(in: &cancellables)

        // Settings are small; a short debounce avoids redundant writes when
        // the user rapidly toggles options, while still being fast enough to
        // survive a quick rebuild.
        $settings
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: saveQueue)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)
    }

    // MARK: - CloudKit Live Sync (Sender side)

    /// Pushes all currently-shared task categories to CloudKit Public Database.
    /// Called automatically 3 seconds after any task change (debounced).
    /// Called explicitly when a new invitation is built.
    func pushSharedListsToCloud() {
        let sharing   = settings.sharingSettings
        guard sharing.isEnabled, !sharing.recipients.isEmpty else { return }

        let ownerName = sharing.ownerName.isEmpty ? "Someone" : sharing.ownerName

        for recipient in sharing.recipients where !recipient.sharedSections.isEmpty {
            for section in recipient.sharedSections {
                let tasks = sharedTaskItems(for: section)
                CloudKitSharingService.shared.uploadSharedList(
                    shareToken     : recipient.shareToken,
                    senderName     : ownerName,
                    senderEmail    : recipient.email,
                    recipientEmail : recipient.email,
                    section        : section,
                    tasks          : tasks
                )
            }
        }
    }

    // MARK: - iCloud Sync

    private func setupiCloud() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: self.iCloudContainerID) else {
                DispatchQueue.main.async { self.iCloudAvailable = false }
                return
            }
            let docsURL = containerURL.appendingPathComponent("Documents")
            try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
            DispatchQueue.main.async {
                self.cloudDocsURL = docsURL
                self.iCloudAvailable = true
                self.migrateLocalToCloudIfNeeded()
                self.setupMetadataQuery()
            }
        }
    }

    private func migrateLocalToCloudIfNeeded() {
        guard let cloudDocs = cloudDocsURL else { return }
        let cloudEntries = cloudDocs.appendingPathComponent("planner_entries.json")
        let cloudSettings = cloudDocs.appendingPathComponent("planner_settings.json")

        // Copy local → cloud only if cloud file doesn't exist yet
        if !FileManager.default.fileExists(atPath: cloudEntries.path),
           FileManager.default.fileExists(atPath: entriesURL.path) {
            try? FileManager.default.copyItem(at: entriesURL, to: cloudEntries)
        }
        if !FileManager.default.fileExists(atPath: cloudSettings.path),
           FileManager.default.fileExists(atPath: settingsURL.path) {
            try? FileManager.default.copyItem(at: settingsURL, to: cloudSettings)
        }

        // Merge cloud entries with current (locally-loaded + any just-added) entries.
        // If cloud is empty or not-yet-synced we keep local data intact.
        // mergeEntries handles deletedTaskIDs so neither source can restore a
        // task the user has already permanently deleted.
        //
        // IMPORTANT: cloud is treated as "memory" (most-recently-written source)
        // because all saves go to activeEntriesURL (the cloud file) when iCloud
        // is available.  The local file loaded at init time can be stale for
        // non-task scalar fields (waterGlasses, rating, etc.).  Treating cloud
        // as "memory" ensures those fields are not silently reset to stale values.
        // Tasks added only in local (shouldn't normally exist at this point, but
        // handled safely) are still preserved via the union logic in mergeEntries.
        if let data = try? Data(contentsOf: cloudEntries),
           let cloudDecoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data),
           !cloudDecoded.isEmpty {
            var merged = entries           // start from locally-loaded entries
            for (k, cloudEntry) in cloudDecoded {
                if let localEntry = merged[k] {
                    // Cloud = "memory" (most recently saved), local = "disk".
                    merged[k] = Self.mergeEntries(disk: localEntry, memory: cloudEntry)
                } else {
                    merged[k] = cloudEntry // date only in cloud — take it as-is
                }
            }
            entries = merged
        }
        // Always save the merged result back to both locations for consistency.
        // saveDataNow already writes to both via the dual-write path.
        saveDataNow()

        // Settings: prefer cloud when available
        if let data = try? Data(contentsOf: cloudSettings),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }

    private func setupMetadataQuery() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.json'", NSMetadataItemFSNameKey)
        NotificationCenter.default.addObserver(
            self, selector: #selector(cloudFilesChanged),
            name: .NSMetadataQueryDidUpdate, object: query)
        NotificationCenter.default.addObserver(
            self, selector: #selector(cloudFilesChanged),
            name: .NSMetadataQueryDidFinishGathering, object: query)
        query.start()
        metadataQuery = query
    }

    @objc private func cloudFilesChanged(_ notification: Notification) {
        metadataQuery?.disableUpdates()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            // Snapshot current in-memory state BEFORE touching disk.
            // This captures any data (appointments, schedule blocks, meals, etc.)
            // the user has entered since the last completed save.
            let before = self.entries
            // Flush any in-flight async saveData() writes so loadData() always
            // reads the freshest possible on-disk state.  saveQueue is serial so
            // a no-op sync{} call drains every pending block before continuing.
            self.saveQueue.sync { }
            self.loadData()
            var merged = self.entries
            for (key, beforeEntry) in before {
                if merged[key] == nil {
                    // Date entry exists in memory but not on disk yet — keep it.
                    merged[key] = beforeEntry
                } else {
                    // Date entry exists in both — merge so that anything the
                    // user entered on this device (appointments, schedule blocks,
                    // meals, tasks, etc.) is never overwritten by a stale
                    // cloud/disk snapshot.
                    merged[key] = Self.mergeEntries(disk: merged[key]!, memory: beforeEntry)
                }
            }
            self.entries = merged
            self.metadataQuery?.enableUpdates()
        }
    }

    /// Merges two snapshots of the same DailyEntry, guaranteeing that:
    ///
    /// 1. **Deletions are permanent** — any task UUID present in either source's
    ///    `deletedTaskIDs` is stripped from the result and recorded in the
    ///    combined `deletedTaskIDs`.  An older cloud/disk snapshot can never
    ///    resurrect a task the user already deleted.
    ///
    /// 2. **In-memory state wins for existing tasks** — when a task UUID exists
    ///    in both sources, the `memory` version's mutable fields (title, notes,
    ///    subtasks, isCompleted, isRolledOver) are applied to the `disk` base.
    ///    This ensures that marking a task complete, editing its title, etc. is
    ///    not overwritten by an older cloud snapshot before the async save
    ///    has finished flushing to disk.
    ///
    /// 3. **New tasks from either source are preserved** — tasks that exist only
    ///    in `memory` (pending async save) or only in `disk` (added on another
    ///    device) are both included, as long as they are not deleted.
    private static func mergeEntries(disk: DailyEntry, memory: DailyEntry) -> DailyEntry {
        // Union deleted IDs from both sides — deletions are permanent.
        let allDeletedIDs = disk.deletedTaskIDs.union(memory.deletedTaskIDs)

        // Start from disk; strip any task that was deleted in either source.
        var result = disk
        result.deletedTaskIDs = allDeletedIDs
        result.topPriorities.removeAll  { allDeletedIDs.contains($0.id) }
        result.toDoLists.removeAll      { allDeletedIDs.contains($0.id) }
        result.callsEmails.removeAll    { allDeletedIDs.contains($0.id) }
        result.personalTodo.removeAll   { allDeletedIDs.contains($0.id) }

        // For tasks present in both, apply memory's mutable state (the most
        // recent user-side mutations: completion, title edits, notes, subtasks).
        func applyMemory(to list: inout [PlannerTask], from memList: [PlannerTask]) {
            let memById = Dictionary(uniqueKeysWithValues: memList.map { ($0.id, $0) })
            for i in list.indices {
                guard let mem = memById[list[i].id] else { continue }
                list[i].isCompleted  = mem.isCompleted
                list[i].isRolledOver = mem.isRolledOver
                list[i].title        = mem.title
                list[i].notes        = mem.notes
                list[i].subtasks     = mem.subtasks
            }
        }
        applyMemory(to: &result.topPriorities, from: memory.topPriorities)
        applyMemory(to: &result.toDoLists,     from: memory.toDoLists)
        applyMemory(to: &result.callsEmails,   from: memory.callsEmails)
        applyMemory(to: &result.personalTodo,  from: memory.personalTodo)

        // Append tasks that exist only in memory (e.g. added since the last
        // async save) and haven't been deleted.
        let resultTopIDs      = Set(result.topPriorities.map(\.id))
        let resultTodoIDs     = Set(result.toDoLists.map(\.id))
        let resultCallsIDs    = Set(result.callsEmails.map(\.id))
        let resultPersonalIDs = Set(result.personalTodo.map(\.id))

        for task in memory.topPriorities  where !resultTopIDs.contains(task.id)      && !allDeletedIDs.contains(task.id) { result.topPriorities.append(task) }
        for task in memory.toDoLists      where !resultTodoIDs.contains(task.id)     && !allDeletedIDs.contains(task.id) { result.toDoLists.append(task) }
        for task in memory.callsEmails    where !resultCallsIDs.contains(task.id)    && !allDeletedIDs.contains(task.id) { result.callsEmails.append(task) }
        for task in memory.personalTodo   where !resultPersonalIDs.contains(task.id) && !allDeletedIDs.contains(task.id) { result.personalTodo.append(task) }

        // ── Non-task fields ────────────────────────────────────────────────────
        // `result` was seeded from `disk`; for every field that isn't a
        // PlannerTask list we must explicitly bring in the in-memory state,
        // otherwise any change the user made on this device (meal logged, glass
        // of water tapped, etc.) that hasn't been flushed to disk yet by the
        // async saveData() will be silently discarded when iCloud fires a merge.

        // Helper: union two Identifiable arrays. Memory items are always kept;
        // disk-only items (added on another device) are appended so cross-device
        // data is not lost. Items the user deleted on this device are naturally
        // absent from `memory` and will not be resurrected.
        func union<T: Identifiable>(_ disk: [T], _ memory: [T]) -> [T] where T.ID: Hashable {
            let memIds = Set(memory.map(\.id))
            var merged = memory
            for item in disk where !memIds.contains(item.id) { merged.append(item) }
            return merged
        }

        // Meals — union all four meal lists so items entered before the async
        // save completes are never dropped.
        result.meals.breakfastItems = union(result.meals.breakfastItems, memory.meals.breakfastItems)
        result.meals.lunchItems     = union(result.meals.lunchItems,     memory.meals.lunchItems)
        result.meals.dinnerItems    = union(result.meals.dinnerItems,    memory.meals.dinnerItems)
        result.meals.snackItems     = union(result.meals.snackItems,     memory.meals.snackItems)

        // Water — memory wins (last tap on this device is authoritative).
        result.waterGlasses = memory.waterGlasses
        result.waterGoal    = memory.waterGoal

        // Fitness — union manual activities; scalar/notes from memory.
        result.fitness.activities   = union(result.fitness.activities, memory.fitness.activities)
        result.fitness.generalNotes = memory.fitness.generalNotes
        result.fitness.steps        = memory.fitness.steps
        // HealthKit data: keep whichever sync is more recent.
        let diskHKDate = result.fitness.hkSyncedAt ?? .distantPast
        let memHKDate  = memory.fitness.hkSyncedAt ?? .distantPast
        if memHKDate >= diskHKDate {
            result.fitness.hkSteps          = memory.fitness.hkSteps
            result.fitness.hkCalories       = memory.fitness.hkCalories
            result.fitness.hkWorkoutMinutes = memory.fitness.hkWorkoutMinutes
            result.fitness.hkWalkingMinutes = memory.fitness.hkWalkingMinutes
            result.fitness.hkWorkouts       = memory.fitness.hkWorkouts
            result.fitness.hkSyncedAt       = memory.fitness.hkSyncedAt
        }

        // Sleep — memory wins (most recent log on this device).
        result.sleep = memory.sleep

        // Notes — prefer non-empty memory over empty disk.
        if !memory.notes.isEmpty { result.notes = memory.notes }

        // Expenses — union deleted-ID sets first so that items explicitly
        // removed on this device are never resurrected from an older disk/iCloud
        // snapshot.  Then union the live lists and filter out any deleted IDs.
        let allDeletedExpenseIDs = disk.deletedExpenseIDs.union(memory.deletedExpenseIDs)
        result.deletedExpenseIDs = allDeletedExpenseIDs
        result.expenses = union(result.expenses, memory.expenses)
            .filter { !allDeletedExpenseIDs.contains($0.id) }
        if memory.savings != 0 { result.savings = memory.savings }

        // Day rating — memory wins.
        result.rating = memory.rating

        // Daily schedule & appointments — union deleted-ID sets first so that
        // items explicitly removed on this device are never resurrected from an
        // older disk/iCloud snapshot.
        let allDeletedBlockIDs = disk.deletedScheduleBlockIDs.union(memory.deletedScheduleBlockIDs)
        let allDeletedApptIDs  = disk.deletedAppointmentIDs.union(memory.deletedAppointmentIDs)
        result.deletedScheduleBlockIDs = allDeletedBlockIDs
        result.deletedAppointmentIDs   = allDeletedApptIDs

        result.dailySchedule = union(result.dailySchedule, memory.dailySchedule)
            .filter { !allDeletedBlockIDs.contains($0.id) }
        result.appointments  = union(result.appointments, memory.appointments)
            .filter { !allDeletedApptIDs.contains($0.id) }

        return result
    }

    // MARK: - Widget Shared Data Model (mirrors WidgetSharedData in the widget extension)

    struct WidgetSharedData: Codable {
        var dateKey: String
        var tasksDone: Int
        var tasksTotal: Int
        var topPriorities: [String]
        var spending: Double
        var currencySymbol: String
        var steps: Int
        var waterGlasses: Int
        var waterGoal: Int
    }

    // MARK: - Widget Data

    func updateWidgetData() {
        let suiteName = "group.com.istalin.DailyPlanner"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let key = dateKey(for: today)
        let entry = entries[key] ?? DailyEntry(date: today)
        let priorities = entry.topPriorities.filter { !$0.isCompleted }.prefix(3).map { $0.title }
        let shared = WidgetSharedData(
            dateKey: key,
            tasksDone: entry.completedTasksCount,
            tasksTotal: entry.allTasksCount,
            topPriorities: Array(priorities),
            spending: entry.totalExpenses,
            currencySymbol: settings.currency.symbol,
            steps: entry.fitness.displaySteps,
            waterGlasses: entry.waterGlasses,
            waterGoal: entry.waterGoal
        )
        if let data = try? JSONEncoder().encode(shared) {
            defaults.set(data, forKey: "widget_data")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Summary helpers
    var completionPercent: Int { Int(currentEntry.taskCompletionRate * 100) }

    // Per-section completion percentages (0–100).
    // Return 0 when the section has no tasks so confetti never fires on empty lists.
    var topPrioritiesCompletionPercent: Int {
        let t = currentEntry.topPriorities
        guard !t.isEmpty else { return 0 }
        return Int(Double(t.filter(\.isCompleted).count) / Double(t.count) * 100)
    }
    var toDoListsCompletionPercent: Int {
        let t = currentEntry.toDoLists
        guard !t.isEmpty else { return 0 }
        return Int(Double(t.filter(\.isCompleted).count) / Double(t.count) * 100)
    }
    var callsEmailsCompletionPercent: Int {
        let t = currentEntry.callsEmails
        guard !t.isEmpty else { return 0 }
        return Int(Double(t.filter(\.isCompleted).count) / Double(t.count) * 100)
    }
    var personalTodoCompletionPercent: Int {
        let t = currentEntry.personalTodo
        guard !t.isEmpty else { return 0 }
        return Int(Double(t.filter(\.isCompleted).count) / Double(t.count) * 100)
    }

    var waterPercent: Double {
        let e = currentEntry
        guard e.waterGoal > 0 else { return 0 }
        return min(1.0, Double(e.waterGlasses) / Double(e.waterGoal))
    }

    var totalDaysTracked: Int { entries.count }

    func availableDates(monthOffset: Int) -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let offsetDate = cal.date(byAdding: .month, value: monthOffset, to: today),
              let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: offsetDate)),
              let range = cal.range(of: .day, in: .month, for: startOfMonth)
        else { return [] }
        return range.compactMap { day -> Date? in
            var comps = cal.dateComponents([.year, .month], from: startOfMonth)
            comps.day = day
            return cal.date(from: comps)
        }
    }
}
