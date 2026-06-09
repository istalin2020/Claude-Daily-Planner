import Foundation
import SwiftUI

// MARK: - Expense Category
enum ExpenseCategory: String, Codable, CaseIterable {
    case food = "Food"
    case grocery = "Grocery"
    case transport = "Transport"
    case health = "Health"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case utilities = "Utilities"
    case other = "Other"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .grocery: return "cart.fill"
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
        case .grocery: return Color(red: 0.2, green: 0.7, blue: 0.3)
        case .transport: return .blue
        case .health: return .red
        case .entertainment: return .purple
        case .shopping: return .pink
        case .utilities: return .yellow
        case .other: return .gray
        }
    }
}

// MARK: - SubTask
struct SubTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id; self.title = title; self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,  forKey: .id)          ?? UUID()
        title       = try c.decode(String.self,          forKey: .title)
        isCompleted = try c.decodeIfPresent(Bool.self,  forKey: .isCompleted) ?? false
    }
}

// MARK: - Recurrence
enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none       = "None"
    case daily      = "Daily"
    case weekdays   = "Weekdays"
    case weekly     = "Weekly"
    case biweekly   = "Every 2 Weeks"
    case monthly    = "Monthly"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .none:      return "slash.circle"
        case .daily:     return "arrow.clockwise"
        case .weekdays:  return "briefcase.fill"
        case .weekly:    return "calendar"
        case .biweekly:  return "calendar.badge.plus"
        case .monthly:   return "calendar.circle.fill"
        }
    }
}

// MARK: - Share Recipient
struct ShareRecipient: Identifiable, Codable, Equatable {
    var id             = UUID()
    var name           : String   = ""
    var email          : String          // Gmail or iCloud email
    /// IDs of PlannerTask items specifically selected to share with this person.
    var sharedTaskIDs  : [UUID]   = []
    /// Categories selected to share with this person (category-level sharing).
    var sharedSections : [SharableSection] = []
    /// Stable token used in the accept deep-link so re-shares update in-place.
    var shareToken     : String   = UUID().uuidString

    enum AccountType {
        case gmail, icloud, other
        var icon: String {
            switch self {
            case .gmail:  return "envelope.circle.fill"
            case .icloud: return "icloud.fill"
            case .other:  return "person.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .gmail:  return .red
            case .icloud: return .blue
            case .other:  return .gray
            }
        }
    }

    var accountType: AccountType {
        let lc = email.lowercased()
        if lc.hasSuffix("@gmail.com") { return .gmail }
        if lc.hasSuffix("@icloud.com") || lc.hasSuffix("@me.com") || lc.hasSuffix("@mac.com") { return .icloud }
        return .other
    }

    init(id: UUID = UUID(), name: String = "", email: String,
         sharedTaskIDs: [UUID] = [], sharedSections: [SharableSection] = [],
         shareToken: String = UUID().uuidString) {
        self.id = id; self.name = name; self.email = email
        self.sharedTaskIDs = sharedTaskIDs; self.sharedSections = sharedSections
        self.shareToken = shareToken
    }

    init(from decoder: Decoder) throws {
        let c             = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decodeIfPresent(UUID.self,              forKey: .id)             ?? UUID()
        name              = try c.decodeIfPresent(String.self,            forKey: .name)           ?? ""
        email             = try c.decode(String.self,                      forKey: .email)
        sharedTaskIDs     = try c.decodeIfPresent([UUID].self,            forKey: .sharedTaskIDs)  ?? []
        sharedSections    = try c.decodeIfPresent([SharableSection].self, forKey: .sharedSections) ?? []
        shareToken        = try c.decodeIfPresent(String.self,            forKey: .shareToken)     ?? UUID().uuidString
    }
}

// MARK: - Sharable Section
enum SharableSection: String, Codable, CaseIterable, Identifiable {
    case entireList    = "Entire To-Do List"
    case topPriorities = "Top Priorities"
    case toDoLists     = "To-Do Lists"
    case personalList  = "Personal List"
    case callsEmails   = "Calls & Emails"
    case foodTracker   = "Food Tracker"
    case waterTracker  = "Water Tracker"
    case medications   = "Medications"
    case habits        = "Habit Tracker"
    case sleepTracker  = "Sleep Tracker"
    case appointments  = "Appointments"
    case expenses      = "Expense Tracker"
    case notes         = "Notes"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .entireList:    return "list.bullet.clipboard.fill"
        case .topPriorities: return "star.fill"
        case .toDoLists:     return "checklist"
        case .personalList:  return "person.circle.fill"
        case .callsEmails:   return "phone.fill"
        case .foodTracker:   return "fork.knife"
        case .waterTracker:  return "drop.fill"
        case .medications:   return "pill.fill"
        case .habits:        return "flame.fill"
        case .sleepTracker:  return "moon.zzz.fill"
        case .appointments:  return "clock.fill"
        case .expenses:      return "dollarsign.circle.fill"
        case .notes:         return "note.text"
        }
    }

    var color: Color {
        switch self {
        case .entireList:    return Color(red: 0.45, green: 0.25, blue: 0.85)
        case .topPriorities: return Color(red: 1.0,  green: 0.75, blue: 0.0)
        case .toDoLists:     return Color(red: 0.0,  green: 0.6,  blue: 0.85)
        case .personalList:  return Color(red: 0.1,  green: 0.65, blue: 0.35)
        case .callsEmails:   return .blue
        case .foodTracker:   return .orange
        case .waterTracker:  return Color(red: 0.0,  green: 0.6,  blue: 1.0)
        case .medications:   return .red
        case .habits:        return Color(red: 0.9,  green: 0.3,  blue: 0.5)
        case .sleepTracker:  return .indigo
        case .appointments:  return .teal
        case .expenses:      return Color(red: 0.1,  green: 0.65, blue: 0.35)
        case .notes:         return Color(red: 0.6,  green: 0.4,  blue: 0.2)
        }
    }
}

// MARK: - Sharing Settings
struct SharingSettings: Codable {
    var isEnabled       : Bool                  = false
    var recipients      : [ShareRecipient]      = []
    var enabledSections : Set<SharableSection>  = []
    /// Display name shown to recipients in invitation emails and shared list headings.
    var ownerName       : String                = ""

    init(isEnabled: Bool = false,
         recipients: [ShareRecipient] = [],
         enabledSections: Set<SharableSection> = [],
         ownerName: String = "") {
        self.isEnabled       = isEnabled
        self.recipients      = recipients
        self.enabledSections = enabledSections
        self.ownerName       = ownerName
    }

    init(from decoder: Decoder) throws {
        let c           = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled       = try c.decodeIfPresent(Bool.self,                 forKey: .isEnabled)       ?? false
        recipients      = try c.decodeIfPresent([ShareRecipient].self,     forKey: .recipients)      ?? []
        enabledSections = try c.decodeIfPresent(Set<SharableSection>.self, forKey: .enabledSections) ?? []
        ownerName       = try c.decodeIfPresent(String.self,               forKey: .ownerName)       ?? ""
    }
}

// MARK: - Shared Task Item (lightweight task representation for cross-user sharing)
struct SharedTaskItem: Identifiable, Codable, Equatable {
    var id          : UUID             = UUID()
    var title       : String
    var isCompleted : Bool             = false
    var notes       : String           = ""
    var subtasks    : [SubTask]        = []
    /// The source section this task belongs to (used when grouping across sections).
    var section     : SharableSection  = .toDoLists

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false,
         notes: String = "", subtasks: [SubTask] = [],
         section: SharableSection = .toDoLists) {
        self.id = id; self.title = title; self.isCompleted = isCompleted
        self.notes = notes; self.subtasks = subtasks; self.section = section
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,             forKey: .id)          ?? UUID()
        title       = try c.decode(String.self,                     forKey: .title)
        isCompleted = try c.decodeIfPresent(Bool.self,             forKey: .isCompleted) ?? false
        notes       = try c.decodeIfPresent(String.self,           forKey: .notes)       ?? ""
        subtasks    = try c.decodeIfPresent([SubTask].self,        forKey: .subtasks)    ?? []
        section     = try c.decodeIfPresent(SharableSection.self,  forKey: .section)     ?? .toDoLists
    }
}

// MARK: - Received Shared List (a list shared to this user by someone else)
struct ReceivedSharedList: Identifiable, Codable {
    var id          : UUID            = UUID()
    var shareToken  : String                    // stable unique ID for update-in-place
    var senderName  : String
    var senderEmail : String
    var section     : SharableSection
    /// Mutable: recipient can toggle completion & edit notes, but not delete.
    var tasks       : [SharedTaskItem]
    var lastUpdated : Date

    init(id: UUID = UUID(), shareToken: String, senderName: String, senderEmail: String,
         section: SharableSection, tasks: [SharedTaskItem], lastUpdated: Date = Date()) {
        self.id = id; self.shareToken = shareToken; self.senderName = senderName
        self.senderEmail = senderEmail; self.section = section
        self.tasks = tasks; self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,             forKey: .id)          ?? UUID()
        shareToken  = try c.decodeIfPresent(String.self,           forKey: .shareToken)  ?? UUID().uuidString
        senderName  = try c.decodeIfPresent(String.self,           forKey: .senderName)  ?? ""
        senderEmail = try c.decodeIfPresent(String.self,           forKey: .senderEmail) ?? ""
        section     = try c.decodeIfPresent(SharableSection.self,  forKey: .section)     ?? .entireList
        tasks       = try c.decodeIfPresent([SharedTaskItem].self,  forKey: .tasks)       ?? []
        lastUpdated = try c.decodeIfPresent(Date.self,             forKey: .lastUpdated) ?? Date()
    }
}

// MARK: - Share Payload (JSON-encoded in the invitation deep link)
struct SharePayload: Codable {
    var token       : String
    var senderName  : String
    var senderEmail : String
    var section     : SharableSection
    var tasks       : [SharedTaskItem]
    var sentAt      : Date
}

// MARK: - Shareable Task (used in per-recipient task selection UI)
struct SelectableTask: Identifiable {
    var id      : UUID
    var title   : String
    var section : SharableSection
    var isSelected: Bool = false
}

// MARK: - Planner Task
struct PlannerTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var isRolledOver: Bool = false
    var originalDate: Date? = nil
    var notes: String = ""
    var recurrence: Recurrence = .none
    var subtasks: [SubTask] = []
    var isShared: Bool = false

    // Robust decoder: any field that might be absent in older saved JSON
    // falls back to its default rather than throwing a keyNotFound error.
    init(id: UUID = UUID(),
         title: String,
         isCompleted: Bool = false,
         isRolledOver: Bool = false,
         originalDate: Date? = nil,
         notes: String = "",
         recurrence: Recurrence = .none,
         subtasks: [SubTask] = [],
         isShared: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isRolledOver = isRolledOver
        self.originalDate = originalDate
        self.notes = notes
        self.recurrence = recurrence
        self.subtasks = subtasks
        self.isShared = isShared
    }

    init(from decoder: Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(UUID.self,       forKey: .id)           ?? UUID()
        title        = try c.decode(String.self,               forKey: .title)
        isCompleted  = try c.decodeIfPresent(Bool.self,       forKey: .isCompleted)  ?? false
        isRolledOver = try c.decodeIfPresent(Bool.self,       forKey: .isRolledOver) ?? false
        originalDate = try c.decodeIfPresent(Date.self,       forKey: .originalDate)
        notes        = try c.decodeIfPresent(String.self,     forKey: .notes)        ?? ""
        recurrence   = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence)   ?? .none
        subtasks     = try c.decodeIfPresent([SubTask].self,  forKey: .subtasks)     ?? []
        isShared     = try c.decodeIfPresent(Bool.self,       forKey: .isShared)     ?? false
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
struct Expense: Identifiable, Codable, Equatable {
    var id = UUID()
    var amount: Double
    var category: ExpenseCategory = .other
    /// Non-empty when the user picked a custom (user-created) category.
    /// In that case `category` is stored as `.other` for backward compat.
    var customCategoryLabel: String = ""
    var description: String
    var isDeposit: Bool = false  // savings
    var isIncome: Bool = false   // income entry
    var isFromSMS: Bool = false  // auto-imported from bank SMS

    /// The human-readable category name to display (custom label takes priority).
    var displayCategory: String {
        customCategoryLabel.isEmpty ? category.rawValue : customCategoryLabel
    }

    init(id: UUID = UUID(),
         amount: Double,
         category: ExpenseCategory = .other,
         customCategoryLabel: String = "",
         description: String,
         isDeposit: Bool = false,
         isIncome: Bool = false,
         isFromSMS: Bool = false) {
        self.id = id
        self.amount = amount
        self.category = category
        self.customCategoryLabel = customCategoryLabel
        self.description = description
        self.isDeposit = isDeposit
        self.isIncome = isIncome
        self.isFromSMS = isFromSMS
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decodeIfPresent(UUID.self,            forKey: .id)                  ?? UUID()
        amount              = try c.decode(Double.self,                    forKey: .amount)
        category            = try c.decodeIfPresent(ExpenseCategory.self, forKey: .category)            ?? .other
        customCategoryLabel = try c.decodeIfPresent(String.self,          forKey: .customCategoryLabel) ?? ""
        description         = try c.decode(String.self,                    forKey: .description)
        isDeposit           = try c.decodeIfPresent(Bool.self,            forKey: .isDeposit)           ?? false
        isIncome            = try c.decodeIfPresent(Bool.self,            forKey: .isIncome)            ?? false
        isFromSMS           = try c.decodeIfPresent(Bool.self,            forKey: .isFromSMS)           ?? false
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

// MARK: - Health Workout (HealthKit-sourced, Codable for persistence)
struct HealthWorkout: Identifiable, Codable {
    var id             = UUID()
    var activityType   : String
    var icon           : String
    var durationMinutes: Int
    var calories       : Int
    var startTime      : Date

    init(id: UUID = UUID(), activityType: String, icon: String,
         durationMinutes: Int, calories: Int, startTime: Date) {
        self.id              = id
        self.activityType    = activityType
        self.icon            = icon
        self.durationMinutes = durationMinutes
        self.calories        = calories
        self.startTime       = startTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(UUID.self,   forKey: .id)              ?? UUID()
        activityType    = try c.decode(String.self,           forKey: .activityType)
        icon            = try c.decodeIfPresent(String.self, forKey: .icon)            ?? "heart.fill"
        durationMinutes = try c.decodeIfPresent(Int.self,    forKey: .durationMinutes) ?? 0
        calories        = try c.decodeIfPresent(Int.self,    forKey: .calories)        ?? 0
        startTime       = try c.decodeIfPresent(Date.self,   forKey: .startTime)       ?? Date()
    }
}

// MARK: - Fitness Entry
struct FitnessEntry: Codable {
    var activities   : [FitnessActivity] = []
    var generalNotes : String = ""
    var steps        : Int = 0

    // ── HealthKit synced data ──────────────────────────────────────────
    var hkSteps          : Int = 0
    var hkCalories       : Int = 0
    var hkWorkoutMinutes : Int = 0
    var hkWalkingMinutes : Int = 0
    var hkWorkouts       : [HealthWorkout] = []
    var hkSyncedAt       : Date? = nil

    // ── Computed from manually-logged activities ───────────────────────
    var totalMinutes       : Int { activities.filter(\.isCompleted).reduce(0) { $0 + $1.duration } }
    var totalCaloriesBurned: Int { activities.filter(\.isCompleted).reduce(0) { $0 + $1.calories } }

    // ── Best available (HealthKit first, manual fallback) ─────────────
    var displaySteps          : Int { hkSteps > 0          ? hkSteps          : steps }
    var displayCalories       : Int { hkCalories > 0       ? hkCalories       : totalCaloriesBurned }
    var displayWorkoutMinutes : Int { hkWorkoutMinutes > 0 ? hkWorkoutMinutes : totalMinutes }
    var displayWalkingMinutes : Int { hkWalkingMinutes }

    init(activities: [FitnessActivity] = [], generalNotes: String = "", steps: Int = 0) {
        self.activities   = activities
        self.generalNotes = generalNotes
        self.steps        = steps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activities       = try c.decodeIfPresent([FitnessActivity].self, forKey: .activities)       ?? []
        generalNotes     = try c.decodeIfPresent(String.self,             forKey: .generalNotes)     ?? ""
        steps            = try c.decodeIfPresent(Int.self,                forKey: .steps)            ?? 0
        hkSteps          = try c.decodeIfPresent(Int.self,                forKey: .hkSteps)          ?? 0
        hkCalories       = try c.decodeIfPresent(Int.self,                forKey: .hkCalories)       ?? 0
        hkWorkoutMinutes = try c.decodeIfPresent(Int.self,                forKey: .hkWorkoutMinutes) ?? 0
        hkWalkingMinutes = try c.decodeIfPresent(Int.self,                forKey: .hkWalkingMinutes) ?? 0
        hkWorkouts       = try c.decodeIfPresent([HealthWorkout].self,    forKey: .hkWorkouts)       ?? []
        hkSyncedAt       = try c.decodeIfPresent(Date.self,               forKey: .hkSyncedAt)
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

// MARK: - Sleep Entry
struct SleepEntry: Codable {
    var bedtime: Date? = nil
    var wakeTime: Date? = nil
    var quality: Int = 0   // 0 = not rated, 1-5 stars
    var notes: String = ""

    init(bedtime: Date? = nil, wakeTime: Date? = nil, quality: Int = 0, notes: String = "") {
        self.bedtime = bedtime; self.wakeTime = wakeTime
        self.quality = quality; self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bedtime  = try c.decodeIfPresent(Date.self,   forKey: .bedtime)
        wakeTime = try c.decodeIfPresent(Date.self,   forKey: .wakeTime)
        quality  = try c.decodeIfPresent(Int.self,    forKey: .quality)  ?? 0
        notes    = try c.decodeIfPresent(String.self, forKey: .notes)    ?? ""
    }

    var durationHours: Double? {
        guard let b = bedtime, let w = wakeTime else { return nil }
        let diff = w.timeIntervalSince(b)
        return diff > 0 ? diff / 3600 : (diff + 86400) / 3600
    }

    var durationString: String {
        guard let h = durationHours else { return "--" }
        let hrs = Int(h); let mins = Int((h - Double(hrs)) * 60)
        return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
    }
}

// MARK: - Medication
struct Medication: Identifiable, Codable {
    var id = UUID()
    var name: String
    var dosage: String = ""
    var times: [Date] = []
    var isActive: Bool = true
    var notes: String = ""
    var color: String = "blue"
    /// "daily" or "weekly"
    var repeatType: String = "daily"
    /// Calendar weekday (1=Sunday, 2=Monday … 7=Saturday). Used only when repeatType == "weekly".
    var weekday: Int = 2

    var swiftUIColor: Color {
        switch color {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return Color(red: 0.1, green: 0.65, blue: 0.35)
        case "purple": return Color(red: 0.45, green: 0.25, blue: 0.85)
        case "pink":   return .pink
        case "teal":   return Color(red: 0.1, green: 0.65, blue: 0.7)
        default:       return .blue
        }
    }

    init(id: UUID = UUID(), name: String, dosage: String = "", times: [Date] = [],
         isActive: Bool = true, notes: String = "", color: String = "blue",
         repeatType: String = "daily", weekday: Int = 2) {
        self.id = id; self.name = name; self.dosage = dosage
        self.times = times; self.isActive = isActive
        self.notes = notes; self.color = color
        self.repeatType = repeatType; self.weekday = weekday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decodeIfPresent(UUID.self,   forKey: .id)         ?? UUID()
        name       = try c.decode(String.self,           forKey: .name)
        dosage     = try c.decodeIfPresent(String.self, forKey: .dosage)     ?? ""
        times      = try c.decodeIfPresent([Date].self,  forKey: .times)      ?? []
        isActive   = try c.decodeIfPresent(Bool.self,   forKey: .isActive)   ?? true
        notes      = try c.decodeIfPresent(String.self, forKey: .notes)      ?? ""
        color      = try c.decodeIfPresent(String.self, forKey: .color)      ?? "blue"
        repeatType = try c.decodeIfPresent(String.self, forKey: .repeatType) ?? "daily"
        weekday    = try c.decodeIfPresent(Int.self,    forKey: .weekday)    ?? 2
    }
}

// MARK: - Theme Color
enum ThemeColor: String, Codable, CaseIterable, Identifiable {
    case purple = "Purple"
    case blue   = "Blue"
    case green  = "Green"
    case orange = "Orange"
    case red    = "Red"
    case teal   = "Teal"
    case pink   = "Pink"
    case indigo = "Indigo"

    var id: String { rawValue }

    var primary: Color {
        switch self {
        case .purple: return Color(red: 0.45, green: 0.25, blue: 0.85)
        case .blue:   return Color(red: 0.15, green: 0.45, blue: 0.95)
        case .green:  return Color(red: 0.10, green: 0.65, blue: 0.35)
        case .orange: return Color(red: 0.95, green: 0.50, blue: 0.10)
        case .red:    return Color(red: 0.88, green: 0.18, blue: 0.22)
        case .teal:   return Color(red: 0.10, green: 0.65, blue: 0.70)
        case .pink:   return Color(red: 0.92, green: 0.25, blue: 0.58)
        case .indigo: return Color(red: 0.30, green: 0.20, blue: 0.80)
        }
    }

    var secondary: Color {
        switch self {
        case .purple: return Color(red: 0.55, green: 0.25, blue: 0.90)
        case .blue:   return Color(red: 0.25, green: 0.60, blue: 1.00)
        case .green:  return Color(red: 0.20, green: 0.80, blue: 0.45)
        case .orange: return Color(red: 1.00, green: 0.65, blue: 0.20)
        case .red:    return Color(red: 1.00, green: 0.35, blue: 0.35)
        case .teal:   return Color(red: 0.20, green: 0.80, blue: 0.85)
        case .pink:   return Color(red: 1.00, green: 0.45, blue: 0.70)
        case .indigo: return Color(red: 0.45, green: 0.35, blue: 0.95)
        }
    }

    var icon: String {
        switch self {
        case .purple: return "circle.fill"
        case .blue:   return "circle.fill"
        case .green:  return "circle.fill"
        case .orange: return "circle.fill"
        case .red:    return "circle.fill"
        case .teal:   return "circle.fill"
        case .pink:   return "circle.fill"
        case .indigo: return "circle.fill"
        }
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

// MARK: - Currency
enum Currency: String, Codable, CaseIterable, Identifiable {
    case usd = "USD"; case eur = "EUR"; case gbp = "GBP"
    case jpy = "JPY"; case cny = "CNY"; case inr = "INR"
    case aud = "AUD"; case cad = "CAD"; case chf = "CHF"
    case krw = "KRW"; case brl = "BRL"; case mxn = "MXN"
    case aed = "AED"; case sar = "SAR"; case sgd = "SGD"
    case hkd = "HKD"; case nzd = "NZD"; case zar = "ZAR"
    case tryLira = "TRY"; case pln = "PLN"; case myr = "MYR"
    case thb = "THB"; case idr = "IDR"; case php = "PHP"
    case vnd = "VND"; case egp = "EGP"; case pkr = "PKR"
    case bdt = "BDT"; case ngn = "NGN"; case qar = "QAR"
    case kwd = "KWD"; case bhd = "BHD"; case omr = "OMR"
    case nok = "NOK"; case sek = "SEK"; case dkk = "DKK"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .cny: return "¥"
        case .inr: return "₹"
        case .aud: return "A$"
        case .cad: return "C$"
        case .chf: return "Fr"
        case .krw: return "₩"
        case .brl: return "R$"
        case .mxn: return "MX$"
        case .aed: return "د.إ"
        case .sar: return "﷼"
        case .sgd: return "S$"
        case .hkd: return "HK$"
        case .nzd: return "NZ$"
        case .zar: return "R"
        case .tryLira: return "₺"
        case .pln: return "zł"
        case .myr: return "RM"
        case .thb: return "฿"
        case .idr: return "Rp"
        case .php: return "₱"
        case .vnd: return "₫"
        case .egp: return "E£"
        case .pkr: return "₨"
        case .bdt: return "৳"
        case .ngn: return "₦"
        case .qar: return "﷼"
        case .kwd: return "KD"
        case .bhd: return "BD"
        case .omr: return "﷼"
        case .nok: return "kr"
        case .sek: return "kr"
        case .dkk: return "kr"
        }
    }

    var displayName: String {
        switch self {
        case .usd: return "US Dollar ($)"
        case .eur: return "Euro (€)"
        case .gbp: return "British Pound (£)"
        case .jpy: return "Japanese Yen (¥)"
        case .cny: return "Chinese Yuan (¥)"
        case .inr: return "Indian Rupee (₹)"
        case .aud: return "Australian Dollar (A$)"
        case .cad: return "Canadian Dollar (C$)"
        case .chf: return "Swiss Franc (Fr)"
        case .krw: return "South Korean Won (₩)"
        case .brl: return "Brazilian Real (R$)"
        case .mxn: return "Mexican Peso (MX$)"
        case .aed: return "UAE Dirham (د.إ)"
        case .sar: return "Saudi Riyal (﷼)"
        case .sgd: return "Singapore Dollar (S$)"
        case .hkd: return "Hong Kong Dollar (HK$)"
        case .nzd: return "New Zealand Dollar (NZ$)"
        case .zar: return "South African Rand (R)"
        case .tryLira: return "Turkish Lira (₺)"
        case .pln: return "Polish Złoty (zł)"
        case .myr: return "Malaysian Ringgit (RM)"
        case .thb: return "Thai Baht (฿)"
        case .idr: return "Indonesian Rupiah (Rp)"
        case .php: return "Philippine Peso (₱)"
        case .vnd: return "Vietnamese Đồng (₫)"
        case .egp: return "Egyptian Pound (E£)"
        case .pkr: return "Pakistani Rupee (₨)"
        case .bdt: return "Bangladeshi Taka (৳)"
        case .ngn: return "Nigerian Naira (₦)"
        case .qar: return "Qatari Riyal (﷼)"
        case .kwd: return "Kuwaiti Dinar (KD)"
        case .bhd: return "Bahraini Dinar (BD)"
        case .omr: return "Omani Rial (﷼)"
        case .nok: return "Norwegian Krone (kr)"
        case .sek: return "Swedish Krona (kr)"
        case .dkk: return "Danish Krone (kr)"
        }
    }
}

// MARK: - Habit
struct Habit: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String = "star.fill"
    var color: String = "purple"  // stored as string for Codable
    var targetDays: [Int] = [1,2,3,4,5,6,7] // weekdays 1=Sun … 7=Sat
    var reminderTime: Date? = nil
    var createdDate: Date = Date()

    var swiftUIColor: Color {
        switch color {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return Color(red: 0.1, green: 0.65, blue: 0.35)
        case "blue":   return .blue
        case "indigo": return .indigo
        case "pink":   return .pink
        default:       return Color(red: 0.45, green: 0.25, blue: 0.85)
        }
    }

    init(id: UUID = UUID(), name: String, icon: String = "star.fill",
         color: String = "purple", targetDays: [Int] = [1,2,3,4,5,6,7],
         reminderTime: Date? = nil, createdDate: Date = Date()) {
        self.id = id; self.name = name; self.icon = icon
        self.color = color; self.targetDays = targetDays
        self.reminderTime = reminderTime; self.createdDate = createdDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,   forKey: .id)          ?? UUID()
        name        = try c.decode(String.self,           forKey: .name)
        icon        = try c.decodeIfPresent(String.self, forKey: .icon)        ?? "star.fill"
        color       = try c.decodeIfPresent(String.self, forKey: .color)       ?? "purple"
        targetDays  = try c.decodeIfPresent([Int].self,  forKey: .targetDays)  ?? [1,2,3,4,5,6,7]
        reminderTime = try c.decodeIfPresent(Date.self,  forKey: .reminderTime)
        createdDate = try c.decodeIfPresent(Date.self,   forKey: .createdDate) ?? Date()
    }
}

// HabitLog: date-keyed set of completed habit IDs
struct HabitLog: Codable {
    var completedIDs: Set<UUID> = []
    init(completedIDs: Set<UUID> = []) { self.completedIDs = completedIDs }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completedIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .completedIDs) ?? []
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var isDarkMode: Bool = false
    var autoRollover: Bool = true
    var notificationsEnabled: Bool = false
    var notificationTimes: [Date] = []
    var notificationTone: NotificationTone = .defaultTone
    var currency: Currency = .usd

    // MARK: - Finance
    var monthlyIncome: Double = 0   // monthly salary / recurring income

    // MARK: - Health & Fitness daily targets
    var workoutTarget: Int  = 30    // minutes
    var walkingTarget: Int  = 30    // minutes
    var stepsTarget: Int    = 5000
    var caloriesTarget: Int = 500

    // MARK: - Habits
    var habits: [Habit] = []
    var habitLogs: [String: HabitLog] = [:]

    // MARK: - Budget
    var categoryBudgets: [String: Double] = [:]

    // MARK: - Theme
    var themeColor: ThemeColor = .purple
    var isLiquidGlass: Bool = false

    // MARK: - Medications
    var medications: [Medication] = []

    // MARK: - Custom expense categories
    var customExpenseCategories: [String] = []

    // MARK: - Sharing
    var sharingSettings      : SharingSettings        = SharingSettings()
    /// Lists shared with this user by others; displayed below own tasks.
    var receivedSharedLists  : [ReceivedSharedList]   = []

    // MARK: - Smart Bank SMS
    var smartBankSMSEnabled: Bool = true
    var dismissedSMSHashes: Set<String> = []

    // MARK: - Gmail Expense Sync (PRO)
    /// The Gmail address the user connected (empty = not connected).
    var gmailConnectedEmail: String = ""
    /// Epoch-seconds of the last successful sync. Next sync only reads
    /// messages received after this point ("continue where it left off").
    var gmailLastSyncEpoch: Double = 0
    /// Gmail message IDs already imported, so re-syncs never duplicate.
    var gmailProcessedMessageIDs: Set<String> = []

    // MARK: - Carry Forward
    /// When true, automatically carries forward the previous month's balance
    /// and savings at the start of each new month (no popup prompt).
    var autoCarryForward: Bool = false
    /// Tracks the last month (format "yyyy-MM") for which we prompted carry-forward.
    /// Empty string means never prompted.
    var lastCarryForwardMonthKey: String = ""

    init(isDarkMode: Bool = false,
         autoRollover: Bool = true,
         notificationsEnabled: Bool = false,
         notificationTimes: [Date] = [],
         notificationTone: NotificationTone = .defaultTone,
         currency: Currency = .usd,
         monthlyIncome: Double = 0,
         workoutTarget: Int = 30,
         walkingTarget: Int = 30,
         stepsTarget: Int = 5000,
         caloriesTarget: Int = 500,
         habits: [Habit] = [],
         habitLogs: [String: HabitLog] = [:],
         categoryBudgets: [String: Double] = [:],
         themeColor: ThemeColor = .purple,
         isLiquidGlass: Bool = false,
         medications: [Medication] = [],
         customExpenseCategories: [String] = [],
         sharingSettings: SharingSettings = SharingSettings(),
         receivedSharedLists: [ReceivedSharedList] = [],
         smartBankSMSEnabled: Bool = true,
         dismissedSMSHashes: Set<String> = [],
         gmailConnectedEmail: String = "",
         gmailLastSyncEpoch: Double = 0,
         gmailProcessedMessageIDs: Set<String> = [],
         autoCarryForward: Bool = false,
         lastCarryForwardMonthKey: String = "") {
        self.isDarkMode = isDarkMode
        self.autoRollover = autoRollover
        self.notificationsEnabled = notificationsEnabled
        self.notificationTimes = notificationTimes
        self.notificationTone = notificationTone
        self.currency = currency
        self.monthlyIncome = monthlyIncome
        self.workoutTarget = workoutTarget
        self.walkingTarget = walkingTarget
        self.stepsTarget = stepsTarget
        self.caloriesTarget = caloriesTarget
        self.habits = habits
        self.habitLogs = habitLogs
        self.categoryBudgets = categoryBudgets
        self.themeColor = themeColor
        self.isLiquidGlass = isLiquidGlass
        self.medications = medications
        self.customExpenseCategories = customExpenseCategories
        self.sharingSettings = sharingSettings
        self.receivedSharedLists = receivedSharedLists
        self.smartBankSMSEnabled = smartBankSMSEnabled
        self.dismissedSMSHashes = dismissedSMSHashes
        self.gmailConnectedEmail = gmailConnectedEmail
        self.gmailLastSyncEpoch = gmailLastSyncEpoch
        self.gmailProcessedMessageIDs = gmailProcessedMessageIDs
        self.autoCarryForward = autoCarryForward
        self.lastCarryForwardMonthKey = lastCarryForwardMonthKey
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isDarkMode           = try c.decodeIfPresent(Bool.self,             forKey: .isDarkMode)           ?? false
        autoRollover         = try c.decodeIfPresent(Bool.self,             forKey: .autoRollover)         ?? true
        notificationsEnabled = try c.decodeIfPresent(Bool.self,             forKey: .notificationsEnabled) ?? false
        notificationTimes    = try c.decodeIfPresent([Date].self,           forKey: .notificationTimes)    ?? []
        notificationTone     = try c.decodeIfPresent(NotificationTone.self, forKey: .notificationTone)     ?? .defaultTone
        currency             = try c.decodeIfPresent(Currency.self,         forKey: .currency)             ?? .usd
        monthlyIncome        = try c.decodeIfPresent(Double.self,           forKey: .monthlyIncome)        ?? 0
        workoutTarget        = try c.decodeIfPresent(Int.self,              forKey: .workoutTarget)        ?? 30
        walkingTarget        = try c.decodeIfPresent(Int.self,              forKey: .walkingTarget)        ?? 30
        stepsTarget          = try c.decodeIfPresent(Int.self,              forKey: .stepsTarget)          ?? 5000
        caloriesTarget       = try c.decodeIfPresent(Int.self,              forKey: .caloriesTarget)       ?? 500
        habits               = try c.decodeIfPresent([Habit].self,                    forKey: .habits)               ?? []
        habitLogs            = try c.decodeIfPresent([String: HabitLog].self,         forKey: .habitLogs)            ?? [:]
        categoryBudgets      = try c.decodeIfPresent([String: Double].self,           forKey: .categoryBudgets)      ?? [:]
        themeColor                = try c.decodeIfPresent(ThemeColor.self,             forKey: .themeColor)                ?? .purple
        isLiquidGlass             = try c.decodeIfPresent(Bool.self,                  forKey: .isLiquidGlass)             ?? false
        medications               = try c.decodeIfPresent([Medication].self,           forKey: .medications)               ?? []
        customExpenseCategories   = try c.decodeIfPresent([String].self,              forKey: .customExpenseCategories)    ?? []
        sharingSettings           = try c.decodeIfPresent(SharingSettings.self,       forKey: .sharingSettings)            ?? SharingSettings()
        receivedSharedLists       = try c.decodeIfPresent([ReceivedSharedList].self,  forKey: .receivedSharedLists)        ?? []
        smartBankSMSEnabled       = try c.decodeIfPresent(Bool.self,                 forKey: .smartBankSMSEnabled)        ?? true
        dismissedSMSHashes        = try c.decodeIfPresent(Set<String>.self,          forKey: .dismissedSMSHashes)         ?? []
        gmailConnectedEmail       = try c.decodeIfPresent(String.self,               forKey: .gmailConnectedEmail)        ?? ""
        gmailLastSyncEpoch        = try c.decodeIfPresent(Double.self,               forKey: .gmailLastSyncEpoch)         ?? 0
        gmailProcessedMessageIDs  = try c.decodeIfPresent(Set<String>.self,          forKey: .gmailProcessedMessageIDs)   ?? []
        autoCarryForward          = try c.decodeIfPresent(Bool.self,                 forKey: .autoCarryForward)           ?? false
        lastCarryForwardMonthKey  = try c.decodeIfPresent(String.self,               forKey: .lastCarryForwardMonthKey)   ?? ""
    }
}

// MARK: - Daily Entry
struct DailyEntry: Codable {
    var date: Date = Date()

    var topPriorities: [PlannerTask] = []
    var toDoLists: [PlannerTask] = []
    var callsEmails: [PlannerTask] = []
    var personalTodo: [PlannerTask] = []

    /// Persistent set of task UUIDs that the user has explicitly deleted.
    /// Survives disk serialisation and iCloud sync so the merge engine never
    /// re-adds a deleted task from an older snapshot.
    var deletedTaskIDs: Set<UUID> = []

    var fitness: FitnessEntry = FitnessEntry()
    var waterGlasses: Int = 0
    var waterGoal: Int = 8
    var meals: MealEntry = MealEntry()

    var dailySchedule: [ScheduleBlock] = []
    var appointments: [Appointment] = []

    /// Persistent sets of UUIDs that have been explicitly deleted by the user.
    /// Prevents the merge engine from resurrecting them from an older disk/iCloud snapshot.
    var deletedScheduleBlockIDs: Set<UUID> = []
    var deletedAppointmentIDs: Set<UUID> = []

    var notes: String = ""

    var expenses: [Expense] = []
    var savings: Double = 0.0

    /// Persistent set of expense UUIDs that the user has explicitly deleted.
    /// Survives disk serialisation and iCloud sync so the merge engine never
    /// re-adds a deleted expense from an older snapshot.
    var deletedExpenseIDs: Set<UUID> = []

    var rating: DayRating = DayRating()
    var sleep: SleepEntry = SleepEntry()

    /// Returns true only when the entry contains at least one piece of
    /// user-entered data.  An entry created solely by the recurrence
    /// scheduler (which populates only task lists) still counts, but an
    /// otherwise-empty entry that was auto-created when the user tapped
    /// a future date will NOT show a calendar indicator dot.
    var hasData: Bool {
        !topPriorities.isEmpty || !toDoLists.isEmpty ||
        !callsEmails.isEmpty || !personalTodo.isEmpty ||
        !meals.breakfastItems.isEmpty || !meals.lunchItems.isEmpty ||
        !meals.dinnerItems.isEmpty || !meals.snackItems.isEmpty ||
        !expenses.isEmpty || waterGlasses > 0 || !notes.isEmpty ||
        sleep.bedtime != nil || !dailySchedule.isEmpty ||
        !appointments.isEmpty || fitness.steps > 0 ||
        !fitness.activities.isEmpty || rating.productivity > 0 ||
        rating.mood > 0 || rating.health > 0
    }

    init(date: Date = Date()) {
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date           = try c.decodeIfPresent(Date.self,            forKey: .date)           ?? Date()
        topPriorities  = try c.decodeIfPresent([PlannerTask].self,   forKey: .topPriorities)  ?? []
        toDoLists      = try c.decodeIfPresent([PlannerTask].self,   forKey: .toDoLists)      ?? []
        callsEmails    = try c.decodeIfPresent([PlannerTask].self,   forKey: .callsEmails)    ?? []
        personalTodo   = try c.decodeIfPresent([PlannerTask].self,   forKey: .personalTodo)   ?? []
        deletedTaskIDs = try c.decodeIfPresent(Set<UUID>.self,       forKey: .deletedTaskIDs) ?? []
        fitness        = try c.decodeIfPresent(FitnessEntry.self,    forKey: .fitness)        ?? FitnessEntry()
        waterGlasses   = try c.decodeIfPresent(Int.self,             forKey: .waterGlasses)   ?? 0
        waterGoal      = try c.decodeIfPresent(Int.self,             forKey: .waterGoal)      ?? 8
        meals          = try c.decodeIfPresent(MealEntry.self,       forKey: .meals)          ?? MealEntry()
        dailySchedule           = try c.decodeIfPresent([ScheduleBlock].self, forKey: .dailySchedule)           ?? []
        appointments            = try c.decodeIfPresent([Appointment].self,   forKey: .appointments)            ?? []
        deletedScheduleBlockIDs = try c.decodeIfPresent(Set<UUID>.self,       forKey: .deletedScheduleBlockIDs) ?? []
        deletedAppointmentIDs   = try c.decodeIfPresent(Set<UUID>.self,       forKey: .deletedAppointmentIDs)   ?? []
        notes          = try c.decodeIfPresent(String.self,          forKey: .notes)          ?? ""
        expenses           = try c.decodeIfPresent([Expense].self,    forKey: .expenses)           ?? []
        savings            = try c.decodeIfPresent(Double.self,      forKey: .savings)            ?? 0.0
        deletedExpenseIDs  = try c.decodeIfPresent(Set<UUID>.self,   forKey: .deletedExpenseIDs)  ?? []
        rating         = try c.decodeIfPresent(DayRating.self,       forKey: .rating)         ?? DayRating()
        sleep          = try c.decodeIfPresent(SleepEntry.self,      forKey: .sleep)          ?? SleepEntry()
    }

    var totalExpenses: Double { expenses.filter { !$0.isDeposit && !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    var totalDeposits: Double { expenses.filter { $0.isDeposit }.reduce(0) { $0 + $1.amount } }
    var totalIncome: Double   { expenses.filter { $0.isIncome }.reduce(0) { $0 + $1.amount } }
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
    case habits = "Habit Tracker"
    case sleepTracker = "Sleep Tracker"
    case medications = "Medications"

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
        case .habits: return "checkmark.circle.fill"
        case .sleepTracker: return "moon.zzz.fill"
        case .medications: return "pill.fill"
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
        case .habits: return Color(red: 0.45, green: 0.25, blue: 0.85)
        case .sleepTracker: return Color(red: 0.25, green: 0.15, blue: 0.65)
        case .medications: return Color(red: 0.1, green: 0.6, blue: 0.65)
        }
    }
}
