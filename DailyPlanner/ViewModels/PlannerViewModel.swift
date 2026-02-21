import Foundation
import SwiftUI
import Combine

class PlannerViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var entries: [String: DailyEntry] = [:]
    @Published var showRolloverAlert: Bool = false
    @Published var selectedSection: AppSection = .overview

    private let storageKey = "DailyPlannerEntries_v1"
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadData()
        checkForRollover()
        setupAutoSave()
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
    var isFuture: Bool { selectedDate > Calendar.current.startOfDay(for: Date()) }

    // MARK: - Date Navigation
    func selectToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    func select(date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    // MARK: - Top Priorities
    func addTopPriority(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        e.topPriorities.append(PlannerTask(title: title.trimmingCharacters(in: .whitespaces)))
        currentEntry = e
    }

    func toggleTopPriority(_ task: PlannerTask) {
        var e = currentEntry
        if let i = e.topPriorities.firstIndex(where: { $0.id == task.id }) {
            e.topPriorities[i].isCompleted.toggle()
        }
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
        e.toDoLists.append(PlannerTask(title: title.trimmingCharacters(in: .whitespaces)))
        currentEntry = e
    }

    func toggleToDoListItem(_ task: PlannerTask) {
        var e = currentEntry
        if let i = e.toDoLists.firstIndex(where: { $0.id == task.id }) {
            e.toDoLists[i].isCompleted.toggle()
        }
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
        e.callsEmails.append(PlannerTask(title: title.trimmingCharacters(in: .whitespaces)))
        currentEntry = e
    }

    func toggleCallEmail(_ task: PlannerTask) {
        var e = currentEntry
        if let i = e.callsEmails.firstIndex(where: { $0.id == task.id }) {
            e.callsEmails[i].isCompleted.toggle()
        }
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
        e.personalTodo.append(PlannerTask(title: title.trimmingCharacters(in: .whitespaces)))
        currentEntry = e
    }

    func togglePersonalTodo(_ task: PlannerTask) {
        var e = currentEntry
        if let i = e.personalTodo.firstIndex(where: { $0.id == task.id }) {
            e.personalTodo[i].isCompleted.toggle()
        }
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
    func addMealItem(_ item: String, to meal: String) {
        guard !item.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var e = currentEntry
        let trimmed = item.trimmingCharacters(in: .whitespaces)
        switch meal {
        case "breakfast": e.meals.breakfastItems.append(trimmed)
        case "lunch": e.meals.lunchItems.append(trimmed)
        case "dinner": e.meals.dinnerItems.append(trimmed)
        default: e.meals.snackItems.append(trimmed)
        }
        currentEntry = e
    }

    func removeMealItem(_ item: String, from meal: String) {
        var e = currentEntry
        switch meal {
        case "breakfast": e.meals.breakfastItems.removeAll { $0 == item }
        case "lunch": e.meals.lunchItems.removeAll { $0 == item }
        case "dinner": e.meals.dinnerItems.removeAll { $0 == item }
        default: e.meals.snackItems.removeAll { $0 == item }
        }
        currentEntry = e
    }

    func updateCalories(_ calories: Int) {
        var e = currentEntry
        e.meals.totalCalories = calories
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
    }

    func toggleScheduleBlock(_ block: ScheduleBlock) {
        var e = currentEntry
        if let i = e.dailySchedule.firstIndex(where: { $0.id == block.id }) {
            e.dailySchedule[i].isCompleted.toggle()
        }
        currentEntry = e
    }

    func deleteScheduleBlock(at offsets: IndexSet) {
        var e = currentEntry
        e.dailySchedule.remove(atOffsets: offsets)
        currentEntry = e
    }

    // MARK: - Appointments
    func addAppointment(_ appointment: Appointment) {
        var e = currentEntry
        e.appointments.append(appointment)
        e.appointments.sort { $0.time < $1.time }
        currentEntry = e
    }

    func toggleAppointment(_ appointment: Appointment) {
        var e = currentEntry
        if let i = e.appointments.firstIndex(where: { $0.id == appointment.id }) {
            e.appointments[i].isCompleted.toggle()
        }
        currentEntry = e
    }

    func deleteAppointment(at offsets: IndexSet) {
        var e = currentEntry
        e.appointments.remove(atOffsets: offsets)
        currentEntry = e
    }

    // MARK: - Notes
    func updateNotes(_ notes: String) {
        var e = currentEntry
        e.notes = notes
        currentEntry = e
    }

    func updateNotesForTomorrow(_ notes: String) {
        var e = currentEntry
        e.notesForTomorrow = notes
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

    // MARK: - Rating
    func updateRating(_ rating: DayRating) {
        var e = currentEntry
        e.rating = rating
        currentEntry = e
    }

    // MARK: - Rollover
    func checkForRollover() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let yKey = dateKey(for: yesterday)
        let tKey = dateKey(for: today)

        guard let ye = entries[yKey] else { return }
        let hasIncomplete = ye.topPriorities.contains { !$0.isCompleted && !$0.isRolledOver }
            || ye.toDoLists.contains { !$0.isCompleted && !$0.isRolledOver }
            || ye.personalTodo.contains { !$0.isCompleted && !$0.isRolledOver }

        if hasIncomplete && entries[tKey] == nil {
            showRolloverAlert = true
        }
    }

    func performRollover() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let yKey = dateKey(for: yesterday)
        let tKey = dateKey(for: today)

        guard var ye = entries[yKey] else { return }
        var te = entries[tKey] ?? DailyEntry(date: today)

        for var task in ye.topPriorities where !task.isCompleted {
            task.isRolledOver = true
            task.originalDate = yesterday
            te.topPriorities.insert(task, at: 0)
        }
        for var task in ye.toDoLists where !task.isCompleted {
            task.isRolledOver = true
            task.originalDate = yesterday
            te.toDoLists.insert(task, at: 0)
        }
        for var task in ye.personalTodo where !task.isCompleted {
            task.isRolledOver = true
            task.originalDate = yesterday
            te.personalTodo.insert(task, at: 0)
        }

        for i in ye.topPriorities.indices where !ye.topPriorities[i].isCompleted {
            ye.topPriorities[i].isRolledOver = true
        }
        for i in ye.toDoLists.indices where !ye.toDoLists[i].isCompleted {
            ye.toDoLists[i].isRolledOver = true
        }
        for i in ye.personalTodo.indices where !ye.personalTodo[i].isCompleted {
            ye.personalTodo[i].isRolledOver = true
        }

        entries[yKey] = ye
        entries[tKey] = te
        saveData()
    }

    // MARK: - Persistence
    func saveData() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func loadData() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: DailyEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func setupAutoSave() {
        $entries
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveData() }
            .store(in: &cancellables)
    }

    // MARK: - Summary helpers
    var completionPercent: Int { Int(currentEntry.taskCompletionRate * 100) }

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
            guard let d = cal.date(from: comps) else { return nil }
            return d <= today ? d : nil
        }
    }
}
