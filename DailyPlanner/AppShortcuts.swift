import AppIntents
import SwiftUI

// MARK: - Add Task Intent
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task to Daily Planner"
    static var description = IntentDescription("Adds a task to your Daily Planner top priorities.")

    @Parameter(title: "Task Title")
    var taskTitle: String

    @Parameter(title: "Section", default: TaskSectionOption.topPriorities)
    var section: TaskSectionOption

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) to \(\.$section)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // AppIntents run out-of-process; we write to shared UserDefaults so the app picks it up
        let pendingKey = "shortcut_pending_task"
        let sectionValue = section.rawValue
        let payload: [String: String] = ["title": taskTitle, "section": sectionValue]
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults(suiteName: "group.com.istalin.DailyPlanner")?.set(data, forKey: pendingKey)
        }
        return .result(dialog: "Added '\(taskTitle)' to \(sectionValue).")
    }
}

enum TaskSectionOption: String, AppEnum {
    case topPriorities = "Top Priorities"
    case toDoLists     = "To-Do Lists"
    case personalTodo  = "Personal To-Do"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task Section")
    static var caseDisplayRepresentations: [TaskSectionOption: DisplayRepresentation] = [
        .topPriorities: "Top Priorities",
        .toDoLists:     "To-Do Lists",
        .personalTodo:  "Personal To-Do"
    ]
}

// MARK: - Log Water Intent
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water Glass"
    static var description = IntentDescription("Adds a glass of water to today's water tracker.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let key = "shortcut_log_water"
        UserDefaults(suiteName: "group.com.istalin.DailyPlanner")?.set(true, forKey: key)
        return .result(dialog: "Logged a glass of water!")
    }
}

// MARK: - Check Habits Intent
struct CheckTodayHabitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Today's Habits"
    static var description = IntentDescription("Returns how many habits you've completed today.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let data = UserDefaults(suiteName: "group.com.istalin.DailyPlanner")?.data(forKey: "widget_data"),
              let widgetData = try? JSONDecoder().decode(WidgetSharedData.self, from: data) else {
            return .result(dialog: "Open Daily Planner to sync habit data.")
        }
        let pct = Int(widgetData.completionRate * 100)
        return .result(dialog: "You've completed \(pct)% of today's tasks (\(widgetData.tasksDone)/\(widgetData.tasksTotal)). Keep it up!")
    }
}

// MARK: - App Shortcuts Provider  (iOS 16.4+)
struct DailyPlannerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add task to \(.applicationName)",
                "Add a priority to \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add water glass to \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: CheckTodayHabitsIntent(),
            phrases: [
                "Check habits in \(.applicationName)",
                "How are my habits in \(.applicationName)"
            ],
            shortTitle: "Check Habits",
            systemImageName: "checkmark.circle.fill"
        )
    }
}

// Codable mirror of WidgetSharedData — must match PlannerViewModel.updateWidgetData()
private struct WidgetSharedData: Codable {
    var dateKey: String
    var tasksDone: Int
    var tasksTotal: Int
    var topPriorities: [String]
    var spending: Double
    var currencySymbol: String
    var steps: Int
    var waterGlasses: Int
    var waterGoal: Int

    var completionRate: Double {
        guard tasksTotal > 0 else { return 0 }
        return Double(tasksDone) / Double(tasksTotal)
    }
}
