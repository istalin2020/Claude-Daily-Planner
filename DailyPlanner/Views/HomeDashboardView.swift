import SwiftUI

// MARK: - Home Dashboard
//
// The app's front page: a living, tile-based launcher. Related sections are
// grouped into themed tiles (office-style for tasks, wellness for health,
// money-green for finance…), each with softly animated artwork. Above the
// tiles, "Today's Pulse" tells the user at a glance what's trending up and
// what needs attention today.

// MARK: - Tile groups & themes

enum HomeTileGroup: String, CaseIterable, Identifiable {
    case tasks    = "To-Do List"
    case health   = "Health Tracker"
    case finance  = "Finance Tracker"
    case schedule = "My Schedule"
    case journal  = "Notes & Journal"

    var id: String { rawValue }

    /// The app sections that live inside this tile.
    var sections: [AppSection] {
        switch self {
        case .tasks:    return [.topPriorities, .toDoLists, .callsEmails, .personalTodo]
        case .health:   return [.healthFitness, .waterTracker, .foodTracker,
                                .sleepTracker, .medications, .habits]
        case .finance:  return [.expenseTracker]
        case .schedule: return [.dailySchedule, .appointments]
        case .journal:  return [.notes, .rateYourDay]
        }
    }

    var icon: String {
        switch self {
        case .tasks:    return "checklist"
        case .health:   return "heart.fill"
        case .finance:  return "dollarsign.circle.fill"
        case .schedule: return "calendar"
        case .journal:  return "square.and.pencil"
        }
    }

    var tagline: String {
        switch self {
        case .tasks:    return "Priorities · Lists · Calls"
        case .health:   return "Fitness · Water · Sleep"
        case .finance:  return "Income · Expenses · Savings"
        case .schedule: return "Day Plan · Appointments"
        case .journal:  return "Notes · Rate Your Day"
        }
    }

    /// Theme gradient — office blues for work, warm red for health,
    /// money green for finance, calm violet for schedule, amber for journal.
    var gradient: [Color] {
        switch self {
        case .tasks:    return [Color(red: 0.26, green: 0.36, blue: 0.95),
                                Color(red: 0.12, green: 0.20, blue: 0.62)]
        case .health:   return [Color(red: 0.98, green: 0.35, blue: 0.37),
                                Color(red: 0.72, green: 0.12, blue: 0.30)]
        case .finance:  return [Color(red: 0.10, green: 0.72, blue: 0.42),
                                Color(red: 0.02, green: 0.42, blue: 0.26)]
        case .schedule: return [Color(red: 0.55, green: 0.34, blue: 0.96),
                                Color(red: 0.30, green: 0.14, blue: 0.62)]
        case .journal:  return [Color(red: 0.96, green: 0.62, blue: 0.15),
                                Color(red: 0.72, green: 0.38, blue: 0.05)]
        }
    }

    /// Small decorative symbols that float inside the tile artwork,
    /// matching the group's world (office / wellness / money…).
    var decorSymbols: [String] {
        switch self {
        case .tasks:    return ["briefcase.fill", "paperclip", "doc.text.fill"]
        case .health:   return ["figure.run", "drop.fill", "moon.zzz.fill"]
        case .finance:  return ["banknote.fill", "chart.line.uptrend.xyaxis", "creditcard.fill"]
        case .schedule: return ["clock.fill", "bell.fill", "calendar.badge.clock"]
        case .journal:  return ["pencil", "book.fill", "sparkles"]
        }
    }

    /// The tile group a given section belongs to (for themed backgrounds).
    static func group(for section: AppSection) -> HomeTileGroup? {
        allCases.first { $0.sections.contains(section) }
    }
}

// MARK: - Dashboard

struct HomeDashboardView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Environment(\.isLiquidGlass) private var isGlass
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            // Three rows fill the whole page: 2×2 grid + full-width bottom tile.
            let spacing: CGFloat = 14
            let hPad: CGFloat = 16
            let vPad: CGFloat = 14
            let rowHeight = max(120, (geo.size.height - vPad * 2 - spacing * 2) / 3)

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    tile(.tasks,  index: 0)
                    tile(.health, index: 1)
                }
                .frame(height: rowHeight)

                HStack(spacing: spacing) {
                    tile(.finance,  index: 2)
                    tile(.schedule, index: 3)
                }
                .frame(height: rowHeight)

                tile(.journal, index: 4)
                    .frame(height: rowHeight)
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private func tile(_ group: HomeTileGroup, index: Int) -> some View {
        AnimatedGroupTile(group: group,
                          headline: headline(for: group),
                          delay: Double(index) * 0.07) {
            open(group)
        }
    }

    private func open(_ group: HomeTileGroup) {
        if group.sections.count == 1 {
            // Single-section groups (Finance) jump straight in.
            withAnimation(.easeInOut(duration: 0.25)) {
                vm.selectedSection = group.sections[0]
            }
        } else {
            // Every other group opens its hub page.
            withAnimation(.easeInOut(duration: 0.25)) {
                vm.activeHub = group
            }
        }
    }

    // MARK: Tile headlines (live numbers)

    private func headline(for group: HomeTileGroup) -> String {
        let e = vm.currentEntry
        switch group {
        case .tasks:
            let total = e.allTasksCount
            return total == 0 ? "Plan your day" : "\(e.completedTasksCount) of \(total) done"
        case .health:
            let steps = e.fitness.displaySteps
            if steps > 0 { return "\(steps) steps today" }
            return "\(e.waterGlasses)/\(e.waterGoal) water"
        case .finance:
            let spent = e.totalExpenses
            return spent > 0
                ? "\(vm.settings.currency.symbol)\(String(format: "%.0f", spent)) spent today"
                : "No spending yet"
        case .schedule:
            let upcoming = e.appointments.filter { !$0.isCompleted }.count
                         + e.dailySchedule.filter { !$0.isCompleted }.count
            return upcoming == 0 ? "All clear" : "\(upcoming) upcoming"
        case .journal:
            if !e.notes.isEmpty { return "Notes written" }
            return e.rating.mood > 0 ? "Day rated" : "Capture a thought"
        }
    }

}

// MARK: - Animated tile

struct AnimatedGroupTile: View {
    let group: HomeTileGroup
    let headline: String
    let delay: Double
    let action: () -> Void

    @State private var floatPhase = false
    @State private var shown = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Theme gradient canvas
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: group.gradient,
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))

                // Soft glow blob that breathes
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                    .offset(x: 48, y: floatPhase ? -58 : -46)

                // Floating decorative symbols — the "animated picture"
                ForEach(Array(group.decorSymbols.enumerated()), id: \.offset) { i, symbol in
                    Image(systemName: symbol)
                        .font(.system(size: i == 0 ? 30 : 18, weight: .semibold))
                        .foregroundColor(.white.opacity(i == 0 ? 0.22 : 0.16))
                        .offset(
                            x: [42.0, -46.0, 30.0][i % 3],
                            y: [-38.0, -6.0, 34.0][i % 3] + (floatPhase ? -6 : 6) * (i.isMultiple(of: 2) ? 1 : -1)
                        )
                        .rotationEffect(.degrees(floatPhase ? [8.0, -6.0, 5.0][i % 3] : [-4.0, 5.0, -6.0][i % 3]))
                }

                // Foreground content — category name centered in the tile
                VStack(spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.22))
                                .frame(width: 44, height: 44)
                            Image(systemName: group.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .symbolEffect(.pulse, options: .repeating.speed(0.6))
                        }
                        Spacer()
                    }
                    Spacer(minLength: 0)
                    Text(group.rawValue)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(headline)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.18)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: group.gradient[0].opacity(0.40), radius: 10, y: 5)
        }
        .buttonStyle(TilePressStyle())
        .scaleEffect(shown ? 1 : 0.85)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(delay)) {
                shown = true
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(delay)) {
                floatPhase = true
            }
        }
    }
}

/// Gentle push-down on touch, like pressing a real key.
struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Group hub page (Health, Schedule, Journal…)

/// Opened by a group tile: the group's sections as light stacked cards,
/// each with a live one-line summary. Tapping a card opens that section;
/// the back bar above returns to the Overview tiles.
struct GroupHubView: View {
    @EnvironmentObject var vm: PlannerViewModel
    let group: HomeTileGroup

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(group.sections) { section in
                    GroupHubCard(section: section, summary: summary(for: section))
                        .padding(.horizontal, 16)
                }
                Spacer(minLength: 30)
            }
            .padding(.top, 12)
        }
    }

    /// A live one-line status for each section, shown under its name.
    private func summary(for section: AppSection) -> String {
        let e = vm.currentEntry
        switch section {
        case .healthFitness:
            return "\(e.fitness.displaySteps) steps · \(e.fitness.displayCalories) cal"
        case .waterTracker:
            return "\(e.waterGlasses)/\(e.waterGoal) glasses"
        case .foodTracker:
            return e.meals.totalCalories > 0 ? "\(e.meals.totalCalories) kcal logged" : "No meals logged"
        case .sleepTracker:
            return e.sleep.durationHours != nil ? "Slept \(e.sleep.durationString)" : "Not logged"
        case .medications:
            let active = vm.settings.medications.filter(\.isActive).count
            return active == 0 ? "No medications" : "\(active) active"
        case .habits:
            let habits = vm.settings.habits
            guard !habits.isEmpty else { return "No habits yet" }
            let done = habits.filter { vm.isHabitCompleted($0, for: vm.selectedDate) }.count
            return "\(done)/\(habits.count) done today"
        case .dailySchedule:
            let pending = e.dailySchedule.filter { !$0.isCompleted }.count
            return pending == 0 ? "All clear" : "\(pending) blocks pending"
        case .appointments:
            let upcoming = e.appointments.filter { !$0.isCompleted }.count
            return upcoming == 0 ? "No appointments" : "\(upcoming) upcoming"
        case .notes:
            return e.notes.isEmpty ? "No notes yet" : String(e.notes.prefix(40))
        case .rateYourDay:
            return e.rating.mood > 0 ? "Rated \(e.rating.mood)/5" : "Not rated yet"
        default:
            return ""
        }
    }
}

struct GroupHubCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    let section: AppSection
    let summary: String

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                vm.selectedSection = section
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(section.color)
                        .frame(width: 40, height: 40)
                    Image(systemName: section.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.rawValue)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - To-Do hub page

/// Opened by the "To-Do List" tile: the four task categories as tiles,
/// two per row, each previewing up to 8 pending tasks. Tapping a tile
/// jumps into that category.
struct TasksHubView: View {
    @EnvironmentObject var vm: PlannerViewModel

    private let sections: [AppSection] = [.topPriorities, .toDoLists,
                                          .callsEmails, .personalTodo]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Light cards, one after another, each previewing 5 pending tasks
                ForEach(sections) { section in
                    TaskHubCard(section: section)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 30)
            }
            .padding(.top, 12)
        }
    }
}

struct TaskHubCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    let section: AppSection

    private var tasks: [PlannerTask] {
        let e = vm.currentEntry
        switch section {
        case .topPriorities: return e.topPriorities
        case .toDoLists:     return e.toDoLists
        case .callsEmails:   return e.callsEmails
        case .personalTodo:  return e.personalTodo
        default:             return []
        }
    }

    private var emptyText: String {
        switch section {
        case .topPriorities: return "No priorities yet"
        case .toDoLists:     return "No to-do items"
        case .callsEmails:   return "No calls or emails"
        case .personalTodo:  return "No personal tasks"
        default:             return "Nothing here"
        }
    }

    var body: some View {
        let pending = tasks.filter { !$0.isCompleted }

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                vm.selectedSection = section
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(section.color)
                            .frame(width: 40, height: 40)
                        Image(systemName: section.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(section.rawValue)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                if pending.isEmpty {
                    Text(tasks.isEmpty ? emptyText : "All done 🎉")
                        .font(.system(size: 15))
                        .italic()
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.leading, 2)
                        .padding(.bottom, 2)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(pending.prefix(5)) { task in
                            HStack(spacing: 10) {
                                Circle()
                                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                                Text(task.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                        if pending.count > 5 {
                            Text("+\(pending.count - 5) more")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.leading, 2)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Themed section backdrop

/// A soft, animated wash of the group's theme behind a section's content —
/// finance feels green, tasks feel office-blue, health feels warm.
struct ThemedSectionBackdrop: View {
    let section: AppSection

    var body: some View {
        if let group = HomeTileGroup.group(for: section) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: group.gradient.map { $0.opacity(0.10) },
                               startPoint: .top, endPoint: .bottom)
                Image(systemName: group.icon)
                    .font(.system(size: 150, weight: .bold))
                    .foregroundColor(group.gradient[0].opacity(0.06))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 30, y: -20)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
