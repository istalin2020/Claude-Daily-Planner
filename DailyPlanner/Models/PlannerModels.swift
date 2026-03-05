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

// MARK: - App Settings
struct AppSettings: Codable {
    var isDarkMode: Bool = false
    var autoRollover: Bool = true
    var notificationsEnabled: Bool = false
    var notificationTimes: [Date] = []
    var notificationTone: NotificationTone = .defaultTone
    var currency: Currency = .usd

    // MARK: - Health & Fitness daily targets
    var workoutTarget: Int  = 30    // minutes
    var walkingTarget: Int  = 30    // minutes
    var stepsTarget: Int    = 5000
    var caloriesTarget: Int = 500

    init(isDarkMode: Bool = false,
         autoRollover: Bool = true,
         notificationsEnabled: Bool = false,
         notificationTimes: [Date] = [],
         notificationTone: NotificationTone = .defaultTone,
         currency: Currency = .usd,
         workoutTarget: Int = 30,
         walkingTarget: Int = 30,
         stepsTarget: Int = 5000,
         caloriesTarget: Int = 500) {
        self.isDarkMode = isDarkMode
        self.autoRollover = autoRollover
        self.notificationsEnabled = notificationsEnabled
        self.notificationTimes = notificationTimes
        self.notificationTone = notificationTone
        self.currency = currency
        self.workoutTarget = workoutTarget
        self.walkingTarget = walkingTarget
        self.stepsTarget = stepsTarget
        self.caloriesTarget = caloriesTarget
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isDarkMode           = try c.decodeIfPresent(Bool.self,             forKey: .isDarkMode)           ?? false
        autoRollover         = try c.decodeIfPresent(Bool.self,             forKey: .autoRollover)         ?? true
        notificationsEnabled = try c.decodeIfPresent(Bool.self,             forKey: .notificationsEnabled) ?? false
        notificationTimes    = try c.decodeIfPresent([Date].self,           forKey: .notificationTimes)    ?? []
        notificationTone     = try c.decodeIfPresent(NotificationTone.self, forKey: .notificationTone)     ?? .defaultTone
        currency             = try c.decodeIfPresent(Currency.self,         forKey: .currency)             ?? .usd
        workoutTarget        = try c.decodeIfPresent(Int.self,              forKey: .workoutTarget)        ?? 30
        walkingTarget        = try c.decodeIfPresent(Int.self,              forKey: .walkingTarget)        ?? 30
        stepsTarget          = try c.decodeIfPresent(Int.self,              forKey: .stepsTarget)          ?? 5000
        caloriesTarget       = try c.decodeIfPresent(Int.self,              forKey: .caloriesTarget)       ?? 500
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
