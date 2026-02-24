import Foundation
import SwiftUI

// MARK: - Expense Category
enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "Food"
    case transport = "Transport"
    case health = "Health"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case utilities = "Utilities"
    case other = "Other"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .health: return "heart.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "bag.fill"
        case .utilities: return "bolt.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .orange
        case .transport: return .blue
        case .health: return .red
        case .entertainment: return .purple
        case .shopping: return .pink
        case .utilities: return .yellow
        case .other: return .gray
        }
    }
}

// MARK: - Planner Task
struct PlannerTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var isRolledOver: Bool = false
    var originalDate: Date? = nil
    var notes: String = ""
}

// MARK: - Appointment
struct Appointment: Identifiable, Codable {
    var id = UUID()
    var time: Date = Date()
    var title: String
    var location: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var reminderOffset: ReminderOffset = .none
}

// MARK: - Expense
struct Expense: Identifiable, Codable {
    var id = UUID()
    var amount: Double
    var category: ExpenseCategory = .other
    var description: String
    var isDeposit: Bool = false
}

// MARK: - Meal Item
struct MealItem: Identifiable, Codable {
    var id      = UUID()
    var name    : String
    var calories: Int          // 0 = user didn't enter / not estimable
    var portion : String = ""  // human-readable portion description
}

// MARK: - Meal Entry
struct MealEntry: Codable {
    var breakfastItems: [MealItem] = []
    var lunchItems    : [MealItem] = []
    var dinnerItems   : [MealItem] = []
    var snackItems    : [MealItem] = []

    /// Auto-computed from item calories; no longer stored.
    var totalCalories: Int {
        (breakfastItems + lunchItems + dinnerItems + snackItems)
            .reduce(0) { $0 + $1.calories }
    }
}

// MARK: - Fitness Activity
struct FitnessActivity: Identifiable, Codable {
    var id = UUID()
    var name: String
    var duration: Int = 30
    var calories: Int = 0
    var isCompleted: Bool = false
}

// MARK: - Fitness Entry
struct FitnessEntry: Codable {
    var activities: [FitnessActivity] = []
    var generalNotes: String = ""
    var steps: Int = 0

    var totalMinutes: Int { activities.filter(\.isCompleted).reduce(0) { $0 + $1.duration } }
    var totalCaloriesBurned: Int { activities.filter(\.isCompleted).reduce(0) { $0 + $1.calories } }
}

// MARK: - Day Rating
struct DayRating: Codable {
    var productivity: Int = 0
    var mood: Int = 0
    var health: Int = 0
    var notes: String = ""
}

// MARK: - Reminder Offset
enum ReminderOffset: String, Codable, CaseIterable, Identifiable {
    case none       = "None"
    case atTime     = "At time"
    case min5       = "5 min before"
    case min10      = "10 min before"
    case min15      = "15 min before"
    case min30      = "30 min before"
    case hour1      = "1 hour before"
    case hour2      = "2 hours before"

    var id: String { rawValue }

    /// Negative offset in minutes (0 = at exact time, nil = no reminder)
    var minutesBefore: Int? {
        switch self {
        case .none:   return nil
        case .atTime: return 0
        case .min5:   return 5
        case .min10:  return 10
        case .min15:  return 15
        case .min30:  return 30
        case .hour1:  return 60
        case .hour2:  return 120
        }
    }
}

// MARK: - Notification Tone
enum NotificationTone: String, Codable, CaseIterable, Identifiable {
    case defaultTone = "Default"
    case triTone     = "Tri-tone"
    case chime       = "Chime"
    case glass       = "Glass"
    case beacon      = "Beacon"
    case bulletin    = "Bulletin"
    case bamboo      = "Bamboo"
    case chord       = "Chord"

    var id: String { rawValue }

    /// UNNotificationSound filename or nil for .default
    var soundFileName: String? {
        switch self {
        case .defaultTone: return nil
        case .triTone:     return "tri-tone.caf"
        case .chime:       return "chime.caf"
        case .glass:       return "glass.caf"
        case .beacon:      return "beacon.caf"
        case .bulletin:    return "bulletin.caf"
        case .bamboo:      return "bamboo.caf"
        case .chord:       return "chord.caf"
        }
    }
}

// MARK: - Schedule Block
struct ScheduleBlock: Identifiable, Codable {
    var id = UUID()
    var startTime: String = "9:00 AM"
    var endTime: String = "10:00 AM"
    var activity: String
    var isCompleted: Bool = false
    var reminderOffset: ReminderOffset = .none
}

// MARK: - App Settings
struct AppSettings: Codable {
    var isDarkMode: Bool = false
    var autoRollover: Bool = true
    var notificationsEnabled: Bool = false
    var notificationTimes: [Date] = []
    var notificationTone: NotificationTone = .defaultTone
}

// MARK: - Daily Entry
struct DailyEntry: Codable {
    var date: Date = Date()

    var topPriorities: [PlannerTask] = []
    var toDoLists: [PlannerTask] = []
    var callsEmails: [PlannerTask] = []
    var personalTodo: [PlannerTask] = []

    var fitness: FitnessEntry = FitnessEntry()
    var waterGlasses: Int = 0
    var waterGoal: Int = 8
    var meals: MealEntry = MealEntry()

    var dailySchedule: [ScheduleBlock] = []
    var appointments: [Appointment] = []

    var notes: String = ""

    var expenses: [Expense] = []
    var savings: Double = 0.0

    var rating: DayRating = DayRating()

    var totalExpenses: Double { expenses.filter { !$0.isDeposit }.reduce(0) { $0 + $1.amount } }
    var totalDeposits: Double { expenses.filter { $0.isDeposit }.reduce(0) { $0 + $1.amount } }
    var allTasksCount: Int { topPriorities.count + toDoLists.count + callsEmails.count + personalTodo.count }
    var completedTasksCount: Int {
        topPriorities.filter(\.isCompleted).count +
        toDoLists.filter(\.isCompleted).count +
        callsEmails.filter(\.isCompleted).count +
        personalTodo.filter(\.isCompleted).count
    }
    var taskCompletionRate: Double {
        guard allTasksCount > 0 else { return 0 }
        return Double(completedTasksCount) / Double(allTasksCount)
    }
}

// MARK: - App Section
enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case topPriorities = "Top Priorities"
    case toDoLists = "To-Do Lists"
    case callsEmails = "Calls & Emails"
    case personalTodo = "Personal To-Do"
    case healthFitness = "Health & Fitness"
    case waterTracker = "Water Tracker"
    case foodTracker = "Food Tracker"
    case dailySchedule = "Daily Schedule"
    case appointments = "Appointments"
    case notes = "Notes"
    case expenseTracker = "Expenses"
    case rateYourDay = "Rate Your Day"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .topPriorities: return "star.fill"
        case .toDoLists: return "list.bullet.clipboard.fill"
        case .callsEmails: return "phone.fill"
        case .personalTodo: return "checkmark.circle.fill"
        case .healthFitness: return "figure.run"
        case .waterTracker: return "drop.fill"
        case .foodTracker: return "fork.knife"
        case .dailySchedule: return "calendar.badge.clock"
        case .appointments: return "clock.fill"
        case .notes: return "note.text"
        case .expenseTracker: return "dollarsign.circle.fill"
        case .rateYourDay: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .overview: return Color(red: 0.45, green: 0.25, blue: 0.85)
        case .topPriorities: return Color(red: 1.0, green: 0.55, blue: 0.0)
        case .toDoLists: return Color(red: 0.0, green: 0.6, blue: 0.85)
        case .callsEmails: return Color(red: 0.15, green: 0.7, blue: 0.35)
        case .personalTodo: return Color(red: 0.2, green: 0.5, blue: 0.95)
        case .healthFitness: return Color(red: 0.9, green: 0.2, blue: 0.3)
        case .waterTracker: return Color(red: 0.05, green: 0.65, blue: 0.95)
        case .foodTracker: return Color(red: 0.95, green: 0.65, blue: 0.1)
        case .dailySchedule: return Color(red: 0.4, green: 0.3, blue: 0.85)
        case .appointments: return Color(red: 0.1, green: 0.6, blue: 0.7)
        case .notes: return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .expenseTracker: return Color(red: 0.1, green: 0.65, blue: 0.35)
        case .rateYourDay: return Color(red: 0.9, green: 0.3, blue: 0.5)
        }
    }
}
