import Foundation
import SwiftUI
import Combine
import WidgetKit

class PlannerViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var entries: [String: DailyEntry] = [:]
    @Published var selectedSection: AppSection = .overview
    @Published var settings: AppSettings = AppSettings()
    @Published var iCloudAvailable = false

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
    }

    // MARK: - Date Key
    func dateKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
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
    func addTopPriority(_ title: String, recurrence: Recurrence = .none) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces), recurrence: recurrence)
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
        var e = currentEntry
        e.topPriorities.removeAll { $0.id == task.id }
        currentEntry = e
    }

    func deleteTopPriority(at offsets: IndexSet) {
        var e = currentEntry
        e.topPriorities.remove(atOffsets: offsets)
        currentEntry = e
    }

    // MARK: - To-Do Lists
    func addToDoListItem(_ title: String, recurrence: Recurrence = .none) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces), recurrence: recurrence)
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
        var e = currentEntry
        e.toDoLists.removeAll { $0.id == task.id }
        currentEntry = e
    }

    func deleteToDoListItem(at offsets: IndexSet) {
        var e = currentEntry
        e.toDoLists.remove(atOffsets: offsets)
        currentEntry = e
    }

    // MARK: - Calls & Emails
    func addCallEmail(_ title: String, recurrence: Recurrence = .none) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces), recurrence: recurrence)
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
        var e = currentEntry
        e.callsEmails.removeAll { $0.id == task.id }
        currentEntry = e
    }

    func deleteCallEmail(at offsets: IndexSet) {
        var e = currentEntry
        e.callsEmails.remove(atOffsets: offsets)
        currentEntry = e
    }

    // MARK: - Personal To-Do
    func addPersonalTodo(_ title: String, recurrence: Recurrence = .none) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces), recurrence: recurrence)
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
        var e = currentEntry
        e.personalTodo.removeAll { $0.id == task.id }
        currentEntry = e
    }

    func deletePersonalTodo(at offsets: IndexSet) {
        var e = currentEntry
        e.personalTodo.remove(atOffsets: offsets)
        currentEntry = e
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
            NotificationManager.shared.cancelItemReminder(id: e.dailySchedule[idx].id.uuidString)
        }
        e.dailySchedule.remove(atOffsets: offsets)
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
            NotificationManager.shared.cancelItemReminder(id: e.appointments[idx].id.uuidString)
        }
        e.appointments.remove(atOffsets: offsets)
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

    func updateSavings(_ amount: Double) {
        var e = currentEntry
        e.savings = amount
        currentEntry = e
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
    func syncHealthKitForToday() {
        guard HealthKitManager.shared.isAvailable else { return }
        let today = Calendar.current.startOfDay(for: Date())
        HealthKitManager.shared.requestAuthorization { [weak self] in
            guard let self else { return }
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

    func monthlyTotalIncome(for date: Date) -> Double {
        let fromEntries = monthlyEntries(for: date)
            .flatMap { $0.expenses }
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amount }
        return settings.monthlyIncome + fromEntries
    }

    func monthlyExpensesByCategory(for date: Date) -> [(ExpenseCategory, Double)] {
        let all = monthlyEntries(for: date)
            .flatMap { $0.expenses }
            .filter { !$0.isDeposit && !$0.isIncome }
        var totals: [ExpenseCategory: Double] = [:]
        for e in all { totals[e.category, default: 0] += e.amount }
        return totals.sorted { $0.value > $1.value }
    }

    func monthlyTotalExpenses(for date: Date) -> Double {
        monthlyExpensesByCategory(for: date).reduce(0) { $0 + $1.1 }
    }

    func monthlyBalance(for date: Date) -> Double {
        monthlyTotalIncome(for: date) - monthlyTotalExpenses(for: date)
    }

    func monthlyTotalSavings(for date: Date) -> Double {
        monthlyEntries(for: date)
            .flatMap { $0.expenses }
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
        while true {
            if isHabitCompleted(habit, for: date) {
                streak += 1
            } else if streak > 0 {
                break
            }
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
            if streak > 365 { break }
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
        var logs = medicationLogsForToday()
        if logs.contains(med.id) { logs.remove(med.id) } else { logs.insert(med.id) }
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: "\(medLogsKey)_\(key)")
        }
        objectWillChange.send()
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

            // Collect tasks that are still incomplete and not yet in today.
            let missingPriorities = pastEntry.topPriorities.filter {
                !$0.isCompleted && !existingIDs.contains($0.id)
            }
            let missingTodos = pastEntry.toDoLists.filter {
                !$0.isCompleted && !existingIDs.contains($0.id)
            }
            let missingCalls = pastEntry.callsEmails.filter {
                !$0.isCompleted && !existingIDs.contains($0.id)
            }
            let missingPersonal = pastEntry.personalTodo.filter {
                !$0.isCompleted && !existingIDs.contains($0.id)
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
    }

    /// Manual rollover trigger (e.g. from Settings). Delegates to checkForRollover
    /// which already handles deduplication and multi-day lookback.
    func performRollover() {
        checkForRollover()
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
    func saveData() {
        let snapshot = entries
        let url = activeEntriesURL
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Synchronous write — called from scenePhase hook and on explicit demand.
    /// Blocks the calling thread until the file is on disk, guaranteeing the
    /// data survives an imminent SIGKILL from Xcode or the OS.
    func saveDataNow() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: activeEntriesURL, options: .atomic)
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
            // Both sources available — merge, preferring the source with more data.
            // Cloud wins on key conflicts; local-only keys are also preserved.
            if cloud.count >= local.count {
                var merged = local
                for (k, v) in cloud { merged[k] = v }
                entries = merged
            } else {
                var merged = cloud
                for (k, v) in local where merged[k] == nil { merged[k] = v }
                entries = merged
            }
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

        // Settings are small; a short debounce avoids redundant writes when
        // the user rapidly toggles options, while still being fast enough to
        // survive a quick rebuild.
        $settings
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: saveQueue)
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)
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

        // Merge cloud entries with current (locally-loaded) entries.
        // If cloud is empty or not-yet-synced we keep local data intact.
        if let data = try? Data(contentsOf: cloudEntries),
           let cloudDecoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data),
           !cloudDecoded.isEmpty {
            var merged = entries           // start from locally-loaded entries
            for (k, v) in cloudDecoded { merged[k] = v }   // cloud wins on conflict
            entries = merged
        }
        // Always save the merged result back to both locations for consistency
        saveDataNow()
        if let localData = try? JSONEncoder().encode(entries) {
            try? localData.write(to: entriesURL, options: .atomic)
        }

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
            // Use the merge-aware loadData so a transient empty-cloud state
            // never wipes the user's in-memory (or local-file) data.
            let before = self.entries
            self.loadData()
            // If loadData produced fewer entries than we had before
            // (e.g. iCloud file hasn't fully downloaded yet), restore.
            if self.entries.count < before.count {
                var restored = self.entries
                for (k, v) in before where restored[k] == nil { restored[k] = v }
                self.entries = restored
            }
            self.metadataQuery?.enableUpdates()
        }
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
