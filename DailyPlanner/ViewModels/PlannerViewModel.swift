import Foundation
import SwiftUI
import Combine

class PlannerViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var entries: [String: DailyEntry] = [:]
    @Published var selectedSection: AppSection = .overview
    @Published var settings: AppSettings = AppSettings()

    // Legacy UserDefaults key kept only for one-time migration
    private let legacyStorageKey = "DailyPlannerEntries_v1"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Documents URLs (data survives Xcode rebuilds on device)
    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var entriesURL: URL { docsDir.appendingPathComponent("planner_entries.json") }
    private var settingsURL: URL { docsDir.appendingPathComponent("planner_settings.json") }

    init() {
        loadSettings()
        loadData()
        checkForRollover()
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
    func addTopPriority(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces))
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
    func addToDoListItem(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces))
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
    func addCallEmail(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces))
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
    func addPersonalTodo(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let task = PlannerTask(title: title.trimmingCharacters(in: .whitespaces))
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
        let url = entriesURL
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
        try? data.write(to: entriesURL, options: .atomic)
    }

    func loadData() {
        // Primary: Documents directory
        if let data = try? Data(contentsOf: entriesURL),
           let decoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data) {
            entries = decoded
            return
        }
        // Fallback: one-time migration from UserDefaults (legacy)
        if let data = UserDefaults.standard.data(forKey: legacyStorageKey),
           let decoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data) {
            entries = decoded
            saveDataNow()
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
    }

    func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
        // Sync notifications
        if settings.notificationsEnabled {
            NotificationManager.shared.scheduleNotifications(
                times: settings.notificationTimes, tone: settings.notificationTone)
        } else {
            NotificationManager.shared.cancelAll()
        }
    }

    func loadSettings() {
        guard let data = try? Data(contentsOf: settingsURL),
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
            .sink { [weak self] _ in self?.saveData() }
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
        guard let startOfMonth = cal.date(from: cal.dateComponents(
            [.year, .month],
            from: cal.date(byAdding: .month, value: monthOffset, to: today)!
        )) else { return [] }
        let range = cal.range(of: .day, in: .month, for: startOfMonth)!
        return range.compactMap { day -> Date? in
            var comps = cal.dateComponents([.year, .month], from: startOfMonth)
            comps.day = day
            return cal.date(from: comps)
        }
    }
}
