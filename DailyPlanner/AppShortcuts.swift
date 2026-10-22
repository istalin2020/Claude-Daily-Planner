import AppIntents
import SwiftUI

// MARK: - Siri & Shortcuts
//
// Voice commands that act on the planner straight away:
//   • Add a task (Top Priorities, To-Do Lists or Personal To-Do)
//   • Add an expense
//   • Log a glass of water
//   • Check today's habits
//   • How's my day (tasks done)
//
// Siri only recognises the exact phrases listed in DailyPlannerShortcuts, so
// each command has many everyday wordings — "add a task in Daily Planner"
// used to fall through to Apple's Reminders because it wasn't one of them.
//
// Every action goes into a queue in the shared App Group first, so nothing
// is lost if the app is closed mid-way, and is applied to the planner at
// once — by the running planner when there is one, otherwise by loading the
// saved planner, applying it and saving it again.

// MARK: - Queue

/// One voice action waiting to be applied.
struct ShortcutAction: Codable {
    enum Kind: String, Codable { case task, water, expense }
    var kind: Kind
    var title: String = ""
    var section: String = ""
    var amount: Double = 0
    var category: String = ""
}

enum ShortcutQueue {
    static let suite = UserDefaults(suiteName: "group.com.istalin.DailyPlanner")
    private static let key = "shortcut_queue"

    static func append(_ action: ShortcutAction) {
        var all = load()
        all.append(action)
        if let data = try? JSONEncoder().encode(all) { suite?.set(data, forKey: key) }
    }

    /// Everything waiting, oldest first; the queue is emptied.
    static func drain() -> [ShortcutAction] {
        let all = load()
        suite?.removeObject(forKey: key)
        return all
    }

    private static func load() -> [ShortcutAction] {
        guard let data = suite?.data(forKey: key),
              let list = try? JSONDecoder().decode([ShortcutAction].self, from: data) else { return [] }
        return list
    }
}

/// Applies the queue now and returns the planner it was applied to.
@MainActor
private func applyNow() -> PlannerViewModel {
    if let live = PlannerViewModel.live {
        live.processPendingShortcutActions()
        return live
    }
    // The app isn't running: load the saved planner, apply, save.
    let vm = PlannerViewModel()
    vm.processPendingShortcutActions()
    vm.saveDataNow()
    vm.saveSettings()
    return vm
}

// MARK: - Add Task

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task to Daily Planner"
    static var description = IntentDescription("Adds a task to today's list in Daily Planner.")
    static var openAppWhenRun = false

    @Parameter(title: "Task", requestValueDialog: "What's the task?")
    var taskTitle: String

    @Parameter(title: "List", default: TaskSectionOption.topPriorities)
    var section: TaskSectionOption

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) to \(\.$section)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .result(dialog: "I didn't catch the task.") }
        ShortcutQueue.append(ShortcutAction(kind: .task, title: title, section: section.rawValue))
        _ = applyNow()
        return .result(dialog: "Added “\(title)” to \(section.rawValue) in Daily Planner.")
    }
}

enum TaskSectionOption: String, AppEnum {
    case topPriorities = "Top Priorities"
    case toDoLists     = "To-Do Lists"
    case personalTodo  = "Personal To-Do"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task List")
    static var caseDisplayRepresentations: [TaskSectionOption: DisplayRepresentation] = [
        .topPriorities: DisplayRepresentation(title: "Top Priorities", synonyms: ["priorities", "priority", "top priority"]),
        .toDoLists:     DisplayRepresentation(title: "To-Do Lists", synonyms: ["to-do", "to do list", "todo", "work"]),
        .personalTodo:  DisplayRepresentation(title: "Personal To-Do", synonyms: ["personal", "personal list", "home"]),
    ]
}

// MARK: - Add Expense

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense to Daily Planner"
    static var description = IntentDescription("Records money spent today in Daily Planner's Finance Tracker.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount", requestValueDialog: "How much did you spend?")
    var amount: Double

    @Parameter(title: "For", requestValueDialog: "What was it for?")
    var note: String

    @Parameter(title: "Category", default: ExpenseCategoryOption.other)
    var category: ExpenseCategoryOption

    static var parameterSummary: some ParameterSummary {
        Summary("Add expense of \(\.$amount) for \(\.$note) in \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else { return .result(dialog: "The amount needs to be more than zero.") }
        let what = note.trimmingCharacters(in: .whitespacesAndNewlines)
        ShortcutQueue.append(ShortcutAction(kind: .expense, title: what.isEmpty ? category.rawValue : what,
                                            amount: amount, category: category.rawValue))
        let vm = applyNow()
        let sym = vm.settings.currency.symbol
        let shown = amount.rounded() == amount ? String(format: "%.0f", amount) : String(format: "%.2f", amount)
        return .result(dialog: "Added \(sym)\(shown) for \(what.isEmpty ? category.rawValue : what) to today's expenses.")
    }
}

enum ExpenseCategoryOption: String, AppEnum {
    case food = "Food", grocery = "Grocery", transport = "Transport", health = "Health",
         entertainment = "Entertainment", shopping = "Shopping", utilities = "Utilities", other = "Other"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Expense Category")
    static var caseDisplayRepresentations: [ExpenseCategoryOption: DisplayRepresentation] = [
        .food:          DisplayRepresentation(title: "Food", synonyms: ["lunch", "dinner", "breakfast", "restaurant", "coffee"]),
        .grocery:       DisplayRepresentation(title: "Grocery", synonyms: ["groceries", "supermarket", "vegetables"]),
        .transport:     DisplayRepresentation(title: "Transport", synonyms: ["taxi", "fuel", "petrol", "bus", "uber"]),
        .health:        DisplayRepresentation(title: "Health", synonyms: ["medicine", "doctor", "pharmacy"]),
        .entertainment: DisplayRepresentation(title: "Entertainment", synonyms: ["movie", "cinema", "games"]),
        .shopping:      DisplayRepresentation(title: "Shopping", synonyms: ["clothes", "online shopping"]),
        .utilities:     DisplayRepresentation(title: "Utilities", synonyms: ["bill", "bills", "electricity", "internet", "phone bill"]),
        .other:         DisplayRepresentation(title: "Other", synonyms: ["misc", "something else"]),
    ]

    var category: ExpenseCategory { ExpenseCategory(rawValue: rawValue) ?? .other }
}

// MARK: - Log Water

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water Glass"
    static var description = IntentDescription("Adds a glass of water to today's water tracker.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        ShortcutQueue.append(ShortcutAction(kind: .water))
        let vm = applyNow()
        let e = vm.entry(for: Date())
        return .result(dialog: "Logged a glass of water — \(e.waterGlasses) of \(e.waterGoal) today.")
    }
}

// MARK: - Check Habits

struct CheckTodayHabitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Today's Habits"
    static var description = IntentDescription("Tells you how many of today's habits are done.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let vm = applyNow()
        let habits = vm.settings.habits
        guard !habits.isEmpty else {
            return .result(dialog: "You haven't set up any habits yet. Add one in Daily Planner's Habit Tracker.")
        }
        let today = Date()
        let left = habits.filter { !vm.isHabitCompleted($0, for: today) }
        let done = habits.count - left.count
        if left.isEmpty {
            return .result(dialog: "All \(habits.count) habits done today. Great work!")
        }
        let names = left.prefix(3).map(\.name).joined(separator: ", ")
        return .result(dialog: "You've done \(done) of \(habits.count) habits today. Still to do: \(names).")
    }
}

// MARK: - How's my day

struct CheckTodayTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "How's My Day"
    static var description = IntentDescription("Tells you how many of today's tasks are done.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let vm = applyNow()
        let e = vm.entry(for: Date())
        let total = e.allTasksCount
        guard total > 0 else { return .result(dialog: "Nothing on your list today yet.") }
        let done = e.completedTasksCount
        let next = e.topPriorities.first { !$0.isCompleted }?.title
        var reply = "You've done \(done) of \(total) tasks today."
        if let next = next { reply += " Next priority: \(next)." }
        return .result(dialog: "\(reply)")
    }
}

// MARK: - Phrases Siri listens for (iOS 16.4+)

struct DailyPlannerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Add a task to \(.applicationName)",
                "Add task in \(.applicationName)",
                "Add task to \(.applicationName)",
                "Add a new task in \(.applicationName)",
                "Add a new task to \(.applicationName)",
                "New task in \(.applicationName)",
                "Create a task in \(.applicationName)",
                "Make a task in \(.applicationName)",
                "Add a to-do in \(.applicationName)",
                "Add a to-do to \(.applicationName)",
                "Add to my list in \(.applicationName)",
                "Add a priority to \(.applicationName)",
                "Add a priority in \(.applicationName)",
                "Add a task to \(\.$section) in \(.applicationName)",
                "Add to \(\.$section) in \(.applicationName)",
                "\(.applicationName) add a task",
                "\(.applicationName) new task",
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)",
                "Add expense in \(.applicationName)",
                "Add expense to \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Log expense in \(.applicationName)",
                "Record an expense in \(.applicationName)",
                "I spent money in \(.applicationName)",
                "Add spending in \(.applicationName)",
                "Add a \(\.$category) expense in \(.applicationName)",
                "\(.applicationName) add expense",
            ],
            shortTitle: "Add Expense",
            systemImageName: "minus.circle.fill"
        )
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add water in \(.applicationName)",
                "Add a glass of water in \(.applicationName)",
                "Add water glass to \(.applicationName)",
                "I drank water in \(.applicationName)",
                "\(.applicationName) log water",
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: CheckTodayHabitsIntent(),
            phrases: [
                "Check habits in \(.applicationName)",
                "Check my habits in \(.applicationName)",
                "How are my habits in \(.applicationName)",
                "\(.applicationName) habits",
            ],
            shortTitle: "Check Habits",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: CheckTodayTasksIntent(),
            phrases: [
                "How's my day in \(.applicationName)",
                "How is my day in \(.applicationName)",
                "What's left today in \(.applicationName)",
                "Check my tasks in \(.applicationName)",
            ],
            shortTitle: "How's My Day",
            systemImageName: "list.bullet.circle.fill"
        )
    }
}
