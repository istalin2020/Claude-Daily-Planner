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

    // Robust decoder: any field that might be absent in older saved JSON
    // falls back to its default rather than throwing a keyNotFound error.
    init(id: UUID = UUID(),
         title: String,
         isCompleted: Bool = false,
         isRolledOver: Bool = false,
         originalDate: Date? = nil,
         notes: String = "") {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isRolledOver = isRolledOver
        self.originalDate = originalDate
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(UUID.self,   forKey: .id)           ?? UUID()
        title        = try c.decode(String.self,           forKey: .title)
        isCompleted  = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted)  ?? false
        isRolledOver = try c.decodeIfPresent(Bool.self,   forKey: .isRolledOver) ?? false
        originalDate = try c.decodeIfPresent(Date.self,   forKey: .originalDate)
        notes        = try c.decodeIfPresent(String.self, forKey: .notes)        ?? ""
    }
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

    init(id: UUID = UUID(),
         time: Date = Date(),
         title: String,
         location: String = "",
         notes: String = "",
         isCompleted: Bool = false,
         reminderOffset: ReminderOffset = .none) {
        self.id = id
        self.time = time
        self.title = title
        self.location = location
        self.notes = notes
        self.isCompleted = isCompleted
        self.reminderOffset = reminderOffset
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decodeIfPresent(UUID.self,           forKey: .id)             ?? UUID()
        time           = try c.decodeIfPresent(Date.self,           forKey: .time)           ?? Date()
        title          = try c.decode(String.self,                   forKey: .title)
        location       = try c.decodeIfPresent(String.self,         forKey: .location)       ?? ""
        notes          = try c.decodeIfPresent(String.self,         forKey: .notes)          ?? ""
        isCompleted    = try c.decodeIfPresent(Bool.self,           forKey: .isCompleted)    ?? false
        reminderOffset = try c.decodeIfPresent(ReminderOffset.self, forKey: .reminderOffset) ?? .none
    }
}

// MARK: - Expense
struct Expense: Identifiable, Codable {
    var id = UUID()
    var amount: Double
    var category: ExpenseCategory = .other
    var description: String
    var isDeposit: Bool = false

    init(id: UUID = UUID(),
         amount: Double,
         category: ExpenseCategory = .other,
         description: String,
         isDeposit: Bool = false) {
        self.id = id
        self.amount = amount
        self.category = category
        self.description = description
        self.isDeposit = isDeposit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,            forKey: .id)          ?? UUID()
        amount      = try c.decode(Double.self,                    forKey: .amount)
        category    = try c.decodeIfPresent(ExpenseCategory.self, forKey: .category)    ?? .other
        description = try c.decode(String.self,                    forKey: .description)
        isDeposit   = try c.decodeIfPresent(Bool.self,            forKey: .isDeposit)   ?? false
    }
}

// MARK: - Meal Item
struct MealItem: Identifiable, Codable {
    var id      = UUID()
    var name    : String
    var calories: Int          // 0 = user didn't enter / not estimable
    var portion : String = ""  // human-readable portion description

    init(id: UUID = UUID(),
         name: String,
         calories: Int,
         portion: String = "") {
        self.id = id
        self.name = name
        self.calories = calories
        self.portion = portion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decodeIfPresent(UUID.self,   forKey: .id)       ?? UUID()
        name     = try c.decode(String.self,           forKey: .name)
        calories = try c.decodeIfPresent(Int.self,    forKey: .calories) ?? 0
        portion  = try c.decodeIfPresent(String.self, forKey: .portion)  ?? ""
    }
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

    init(breakfastItems: [MealItem] = [],
         lunchItems: [MealItem] = [],
         dinnerItems: [MealItem] = [],
         snackItems: [MealItem] = []) {
        self.breakfastItems = breakfastItems
        self.lunchItems = lunchItems
        self.dinnerItems = dinnerItems
        self.snackItems = snackItems
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        breakfastItems = try c.decodeIfPresent([MealItem].self, forKey: .breakfastItems) ?? []
        lunchItems     = try c.decodeIfPresent([MealItem].self, forKey: .lunchItems)     ?? []
        dinnerItems    = try c.decodeIfPresent([MealItem].self, forKey: .dinnerItems)    ?? []
        snackItems     = try c.decodeIfPresent([MealItem].self, forKey: .snackItems)     ?? []
    }
}

// MARK: - Fitness Activity
struct FitnessActivity: Identifiable, Codable {
    var id = UUID()
    var name: String
    var duration: Int = 30
    var calories: Int = 0
    var isCompleted: Bool = false

    init(id: UUID = UUID(),
         name: String,
         duration: Int = 30,
         calories: Int = 0,
         isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.duration = duration
        self.calories = calories
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,   forKey: .id)          ?? UUID()
        name        = try c.decode(String.self,           forKey: .name)
        duration    = try c.decodeIfPresent(Int.self,    forKey: .duration)    ?? 30
        calories    = try c.decodeIfPresent(Int.self,    forKey: .calories)    ?? 0
        isCompleted = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted) ?? false
    }
}

// MARK: - Fitness Entry
struct FitnessEntry: Codable {
    var activities: [FitnessActivity] = []
    var generalNotes: String = ""
    var steps: Int = 0

    var totalMinutes: Int { activities.filter(\.isCompleted).reduce(0) { $0 + $1.duration } }
    var totalCaloriesBurned: Int { activities.filter(\.isCompleted).reduce(0) { $0 + $1.calories } }

    init(activities: [FitnessActivity] = [],
         generalNotes: String = "",
         steps: Int = 0) {
        self.activities = activities
        self.generalNotes = generalNotes
        self.steps = steps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activities   = try c.decodeIfPresent([FitnessActivity].self, forKey: .activities)   ?? []
        generalNotes = try c.decodeIfPresent(String.self,             forKey: .generalNotes) ?? ""
        steps        = try c.decodeIfPresent(Int.self,                forKey: .steps)        ?? 0
    }
}

// MARK: - Day Rating
struct DayRating: Codable {
    var productivity: Int = 0
    var mood: Int = 0
    var health: Int = 0
    var notes: String = ""

    init(productivity: Int = 0,
         mood: Int = 0,
         health: Int = 0,
         notes: String = "") {
        self.productivity = productivity
        self.mood = mood
        self.health = health
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        productivity = try c.decodeIfPresent(Int.self,    forKey: .productivity) ?? 0
        mood         = try c.decodeIfPresent(Int.self,    forKey: .mood)         ?? 0
        health       = try c.decodeIfPresent(Int.self,    forKey: .health)       ?? 0
        notes        = try c.decodeIfPresent(String.self, forKey: .notes)        ?? ""
    }
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

    init(id: UUID = UUID(),
         startTime: String = "9:00 AM",
         endTime: String = "10:00 AM",
         activity: String,
         isCompleted: Bool = false,
         reminderOffset: ReminderOffset = .none) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.activity = activity
        self.isCompleted = isCompleted
        self.reminderOffset = reminderOffset
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decodeIfPresent(UUID.self,           forKey: .id)             ?? UUID()
        startTime      = try c.decodeIfPresent(String.self,         forKey: .startTime)      ?? "9:00 AM"
        endTime        = try c.decodeIfPresent(String.self,         forKey: .endTime)        ?? "10:00 AM"
        activity       = try c.decode(String.self,                   forKey: .activity)
        isCompleted    = try c.decodeIfPresent(Bool.self,           forKey: .isCompleted)    ?? false
        reminderOffset = try c.decodeIfPresent(ReminderOffset.self, forKey: .reminderOffset) ?? .none
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var isDarkMode: Bool = false
    var autoRollover: Bool = true
    var notificationsEnabled: Bool = false
    var notificationTimes: [Date] = []
    var notificationTone: NotificationTone = .defaultTone

    init(isDarkMode: Bool = false,
         autoRollover: Bool = true,
         notificationsEnabled: Bool = false,
         notificationTimes: [Date] = [],
         notificationTone: NotificationTone = .defaultTone) {
        self.isDarkMode = isDarkMode
        self.autoRollover = autoRollover
        self.notificationsEnabled = notificationsEnabled
        self.notificationTimes = notificationTimes
        self.notificationTone = notificationTone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isDarkMode           = try c.decodeIfPresent(Bool.self,             forKey: .isDarkMode)           ?? false
        autoRollover         = try c.decodeIfPresent(Bool.self,             forKey: .autoRollover)         ?? true
        notificationsEnabled = try c.decodeIfPresent(Bool.self,             forKey: .notificationsEnabled) ?? false
        notificationTimes    = try c.decodeIfPresent([Date].self,           forKey: .notificationTimes)    ?? []
        notificationTone     = try c.decodeIfPresent(NotificationTone.self, forKey: .notificationTone)     ?? .defaultTone
    }
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

    init(date: Date = Date()) {
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date          = try c.decodeIfPresent(Date.self,            forKey: .date)          ?? Date()
        topPriorities = try c.decodeIfPresent([PlannerTask].self,   forKey: .topPriorities) ?? []
        toDoLists     = try c.decodeIfPresent([PlannerTask].self,   forKey: .toDoLists)     ?? []
        callsEmails   = try c.decodeIfPresent([PlannerTask].self,   forKey: .callsEmails)   ?? []
        personalTodo  = try c.decodeIfPresent([PlannerTask].self,   forKey: .personalTodo)  ?? []
        fitness       = try c.decodeIfPresent(FitnessEntry.self,    forKey: .fitness)       ?? FitnessEntry()
        waterGlasses  = try c.decodeIfPresent(Int.self,             forKey: .waterGlasses)  ?? 0
        waterGoal     = try c.decodeIfPresent(Int.self,             forKey: .waterGoal)     ?? 8
        meals         = try c.decodeIfPresent(MealEntry.self,       forKey: .meals)         ?? MealEntry()
        dailySchedule = try c.decodeIfPresent([ScheduleBlock].self, forKey: .dailySchedule) ?? []
        appointments  = try c.decodeIfPresent([Appointment].self,   forKey: .appointments)  ?? []
        notes         = try c.decodeIfPresent(String.self,          forKey: .notes)         ?? ""
        expenses      = try c.decodeIfPresent([Expense].self,       forKey: .expenses)      ?? []
        savings       = try c.decodeIfPresent(Double.self,          forKey: .savings)       ?? 0.0
        rating        = try c.decodeIfPresent(DayRating.self,       forKey: .rating)        ?? DayRating()
    }

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
