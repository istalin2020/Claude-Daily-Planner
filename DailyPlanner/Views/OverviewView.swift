import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.themeAccent) private var accent

    private var entry: DailyEntry { vm.currentEntry }

    private var dateTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d, yyyy"
        return fmt.string(from: vm.selectedDate)
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 14) {
                // Date heading
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.isToday ? "Today" : dateTitle)
                            .font(.title3).fontWeight(.bold)
                        if !vm.isToday {
                            Text(dateTitle)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    // Overall completion ring
                    ZStack {
                        Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: entry.taskCompletionRate)
                            .stroke(accent,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(vm.completionPercent)%")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(width: 52, height: 52)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Quick Stats Row
                HStack(spacing: 10) {
                    QuickStatCard(icon: "star.fill", label: "Priorities",
                                  value: "\(entry.topPriorities.filter(\.isCompleted).count)/\(entry.topPriorities.count)",
                                  color: AppSection.topPriorities.color)
                    QuickStatCard(icon: "list.bullet.clipboard.fill", label: "To-Do",
                                  value: "\(entry.toDoLists.filter(\.isCompleted).count)/\(entry.toDoLists.count)",
                                  color: AppSection.toDoLists.color)
                    QuickStatCard(icon: "drop.fill", label: "Water",
                                  value: "\(entry.waterGlasses)/\(entry.waterGoal)",
                                  color: AppSection.waterTracker.color)
                    QuickStatCard(icon: "dollarsign.circle.fill", label: "Spent",
                                  value: String(format: "%@%.0f", vm.settings.currency.symbol, entry.totalExpenses),
                                  color: .red)
                }
                .padding(.horizontal, 12)

                // Top Priorities Card
                OverviewCard(section: .topPriorities, action: { vm.selectedSection = .topPriorities }) {
                    if entry.topPriorities.isEmpty {
                        EmptyOverviewRow(text: "No priorities set")
                    } else {
                        ForEach(entry.topPriorities.prefix(3)) { task in
                            OverviewTaskRow(task: task)
                        }
                        if entry.topPriorities.count > 3 {
                            Text("+\(entry.topPriorities.count - 3) more")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .id(AppSection.topPriorities.id)

                // To-Do Lists Card
                OverviewCard(section: .toDoLists, action: { vm.selectedSection = .toDoLists }) {
                    if entry.toDoLists.isEmpty {
                        EmptyOverviewRow(text: "No to-do items")
                    } else {
                        ForEach(entry.toDoLists.prefix(3)) { task in
                            OverviewTaskRow(task: task)
                        }
                        if entry.toDoLists.count > 3 {
                            Text("+\(entry.toDoLists.count - 3) more")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .id(AppSection.toDoLists.id)

                // Calls & Emails Card
                OverviewCard(section: .callsEmails, action: { vm.selectedSection = .callsEmails }) {
                    if entry.callsEmails.isEmpty {
                        EmptyOverviewRow(text: "No calls or emails")
                    } else {
                        ForEach(entry.callsEmails.prefix(3)) { task in
                            OverviewTaskRow(task: task)
                        }
                        if entry.callsEmails.count > 3 {
                            Text("+\(entry.callsEmails.count - 3) more")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .id(AppSection.callsEmails.id)

                // Personal To-Do Card
                OverviewCard(section: .personalTodo, action: { vm.selectedSection = .personalTodo }) {
                    if entry.personalTodo.isEmpty {
                        EmptyOverviewRow(text: "No personal tasks")
                    } else {
                        ForEach(entry.personalTodo.prefix(3)) { task in
                            OverviewTaskRow(task: task)
                        }
                        if entry.personalTodo.count > 3 {
                            Text("+\(entry.personalTodo.count - 3) more")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .id(AppSection.personalTodo.id)

                // Health & Fitness Card
                OverviewCard(section: .healthFitness, action: { vm.selectedSection = .healthFitness }) {
                    HStack(spacing: 16) {
                        HealthMiniStat(icon: "figure.run", label: "Workout",
                                       value: "\(entry.fitness.displayWorkoutMinutes)")
                        HealthMiniStat(icon: "figure.walk", label: "Walking",
                                       value: "\(entry.fitness.displayWalkingMinutes)")
                        HealthMiniStat(icon: "shoeprints.fill", label: "Steps",
                                       value: entry.fitness.displaySteps >= 1000
                                           ? String(format: "%.1fk", Double(entry.fitness.displaySteps) / 1000)
                                           : "\(entry.fitness.displaySteps)")
                        HealthMiniStat(icon: "flame.fill", label: "Calories",
                                       value: "\(entry.fitness.displayCalories)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .id(AppSection.healthFitness.id)

                // Water Tracker Card
                OverviewCard(section: .waterTracker, action: { vm.selectedSection = .waterTracker }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(0..<min(entry.waterGoal, 10), id: \.self) { i in
                                Image(systemName: i < entry.waterGlasses ? "drop.fill" : "drop")
                                    .font(.system(size: 18))
                                    .foregroundColor(i < entry.waterGlasses
                                                     ? AppSection.waterTracker.color : .secondary.opacity(0.3))
                            }
                        }
                        ProgressView(value: vm.waterPercent)
                            .tint(AppSection.waterTracker.color)
                        Text("\(entry.waterGlasses) of \(entry.waterGoal) glasses")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .id(AppSection.waterTracker.id)

                // Food Tracker Card
                OverviewCard(section: .foodTracker, action: { vm.selectedSection = .foodTracker }) {
                    HStack(spacing: 12) {
                        MealMiniStat(meal: "Breakfast", items: entry.meals.breakfastItems.count, icon: "sunrise.fill")
                        MealMiniStat(meal: "Lunch", items: entry.meals.lunchItems.count, icon: "sun.max.fill")
                        MealMiniStat(meal: "Dinner", items: entry.meals.dinnerItems.count, icon: "moon.fill")
                        CalorieMiniStat(calories: entry.meals.totalCalories)
                    }
                    .frame(maxWidth: .infinity)
                }
                .id(AppSection.foodTracker.id)

                // Daily Schedule Card
                OverviewCard(section: .dailySchedule, action: { vm.selectedSection = .dailySchedule }) {
                    if entry.dailySchedule.isEmpty {
                        EmptyOverviewRow(text: "No schedule blocks added")
                    } else {
                        ForEach(entry.dailySchedule.prefix(3)) { block in
                            HStack(spacing: 8) {
                                Image(systemName: block.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(block.isCompleted ? AppSection.dailySchedule.color : .secondary.opacity(0.4))
                                    .font(.system(size: 14))
                                Text("\(block.startTime) – \(block.endTime)")
                                    .font(.caption).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
                                Text(block.activity)
                                    .font(.caption).fontWeight(.medium)
                                    .strikethrough(block.isCompleted)
                                Spacer()
                            }
                        }
                    }
                }
                .id(AppSection.dailySchedule.id)

                // Appointments Card
                OverviewCard(section: .appointments, action: { vm.selectedSection = .appointments }) {
                    if entry.appointments.isEmpty {
                        EmptyOverviewRow(text: "No appointments")
                    } else {
                        ForEach(entry.appointments.prefix(3)) { appt in
                            HStack(spacing: 8) {
                                Image(systemName: appt.isCompleted ? "checkmark.circle.fill" : "clock")
                                    .foregroundColor(appt.isCompleted ? AppSection.appointments.color : .orange)
                                    .font(.system(size: 14))
                                Text(appt.time, style: .time)
                                    .font(.caption).foregroundColor(.secondary)
                                Text(appt.title)
                                    .font(.caption).fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                }
                .id(AppSection.appointments.id)

                // Notes Card
                OverviewCard(section: .notes, action: { vm.selectedSection = .notes }) {
                    if entry.notes.isEmpty {
                        EmptyOverviewRow(text: "No notes for today")
                    } else {
                        Text(entry.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .id(AppSection.notes.id)

                // Expense Tracker Card
                OverviewCard(section: .expenseTracker, action: { vm.selectedSection = .expenseTracker }) {
                    let sym      = vm.settings.currency.symbol
                    let balance  = vm.monthlyBalance(for: vm.selectedDate)
                    let totInc   = vm.monthlyTotalIncome(for: vm.selectedDate)

                    VStack(spacing: 10) {
                        // Row 1 — today's three figures
                        HStack(spacing: 0) {
                            ExpenseMiniStat(
                                icon: "arrow.down.circle.fill",
                                label: "Earning",
                                value: String(format: "%@%.2f", sym, entry.totalIncome),
                                color: Color(red: 0.1, green: 0.65, blue: 0.35)
                            )
                            Divider().frame(height: 36)
                            ExpenseMiniStat(
                                icon: "arrow.up.circle.fill",
                                label: "Expenses",
                                value: String(format: "%@%.2f", sym, entry.totalExpenses),
                                color: .red
                            )
                            Divider().frame(height: 36)
                            ExpenseMiniStat(
                                icon: "banknote.fill",
                                label: "Saving",
                                value: String(format: "%@%.2f", sym, entry.totalDeposits),
                                color: Color(red: 0.3, green: 0.5, blue: 0.95)
                            )
                        }
                        .frame(maxWidth: .infinity)

                        // Row 2 — monthly totals
                        HStack {
                            // Total Income (left)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Total Income")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%@%.2f", sym, totInc))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 0.1, green: 0.65, blue: 0.35))
                            }
                            Spacer()
                            // Monthly Balance (right)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Month Balance")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(balance >= 0 ? "+" : "")\(sym)\(String(format: "%.2f", balance))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(balance >= 0 ? Color(red: 0.1, green: 0.65, blue: 0.35) : .red)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                }
                .id(AppSection.expenseTracker.id)

                // Rate Your Day Card
                OverviewCard(section: .rateYourDay, action: { vm.selectedSection = .rateYourDay }) {
                    HStack(spacing: 20) {
                        RatingMiniStat(label: "Productivity", value: entry.rating.productivity, color: .orange)
                        RatingMiniStat(label: "Mood", value: entry.rating.mood, color: .pink)
                        RatingMiniStat(label: "Health", value: entry.rating.health, color: .red)
                    }
                    .frame(maxWidth: .infinity)
                }
                .id(AppSection.rateYourDay.id)

                // Habit Tracker Card (PRO)
                ProOverviewCard(
                    section: .habits,
                    action: { vm.selectedSection = .habits }
                ) {
                    let weekday = Calendar.current.component(.weekday, from: vm.selectedDate)
                    let todayHabits = vm.settings.habits.filter { $0.targetDays.contains(weekday) }
                    let completedCount = todayHabits.filter { vm.isHabitCompleted($0, for: vm.selectedDate) }.count
                    if todayHabits.isEmpty {
                        EmptyOverviewRow(text: "No habits for today")
                    } else {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                Circle()
                                    .trim(from: 0, to: todayHabits.count > 0 ? Double(completedCount) / Double(todayHabits.count) : 0)
                                    .stroke(AppSection.habits.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(todayHabits.count > 0 ? Int(Double(completedCount) / Double(todayHabits.count) * 100) : 0)%")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(completedCount) of \(todayHabits.count) habits done")
                                    .font(.caption).fontWeight(.medium)
                                Text(completedCount == todayHabits.count && todayHabits.count > 0 ? "Perfect day!" : "Keep going!")
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .id(AppSection.habits.id)

                // Sleep Tracker Card (PRO)
                ProOverviewCard(
                    section: .sleepTracker,
                    action: { vm.selectedSection = .sleepTracker }
                ) {
                    let sleep = entry.sleep
                    if let hours = sleep.durationHours {
                        HStack(spacing: 12) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppSection.sleepTracker.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.1fh sleep", hours))
                                    .font(.caption).fontWeight(.bold)
                                if sleep.quality > 0 {
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { i in
                                            Image(systemName: i <= sleep.quality ? "star.fill" : "star")
                                                .font(.system(size: 8))
                                                .foregroundColor(i <= sleep.quality ? .yellow : .secondary.opacity(0.3))
                                        }
                                    }
                                } else {
                                    Text("No quality rating").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    } else {
                        EmptyOverviewRow(text: "No sleep logged yet")
                    }
                }
                .id(AppSection.sleepTracker.id)

                // Medication Tracker Card (PRO)
                ProOverviewCard(
                    section: .medications,
                    action: { vm.selectedSection = .medications }
                ) {
                    let activeMeds = vm.settings.medications.filter(\.isActive)
                    let takenCount = vm.medicationLogsForToday().count
                    if activeMeds.isEmpty {
                        EmptyOverviewRow(text: "No medications added")
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "pill.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppSection.medications.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(takenCount) of \(activeMeds.count) taken today")
                                    .font(.caption).fontWeight(.medium)
                                Text(takenCount == activeMeds.count ? "All medications taken!" : "\(activeMeds.count - takenCount) remaining")
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .id(AppSection.medications.id)

                Spacer(minLength: 24)
            }
        }
        .onAppear {
            if let target = vm.lastVisitedSection {
                vm.lastVisitedSection = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(target.id, anchor: .top)
                    }
                }
            }
        }
        } // ScrollViewReader
    }
}

// MARK: - PRO Overview Card (shows PRO lock badge, tappable to navigate)
struct ProOverviewCard<Content: View>: View {
    @EnvironmentObject var pro: ProManager
    @Environment(\.isLiquidGlass) private var isGlass
    let section: AppSection
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(section.color)
                        .clipShape(RoundedRectangle(cornerRadius: isGlass ? 10 : 8, style: .continuous))
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    if !pro.isPro {
                        ProInlineBadge()
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                content
            }
            .padding(isGlass ? 16 : 14)
            .glassCard()
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Overview Card
struct OverviewCard<Content: View>: View {
    @Environment(\.isLiquidGlass) private var isGlass
    let section: AppSection
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(section.color)
                        .clipShape(RoundedRectangle(cornerRadius: isGlass ? 10 : 8, style: .continuous))
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                content
            }
            .padding(isGlass ? 16 : 14)
            .glassCard()
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views
struct OverviewTaskRow: View {
    let task: PlannerTask
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .secondary.opacity(0.4))
                .font(.system(size: 14))
            Text(task.title)
                .font(.caption)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
            if task.isRolledOver {
                Text("↩ Rolled")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
            RecurrenceBadge(recurrence: task.recurrence)
            Spacer()
        }
    }
}

struct EmptyOverviewRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
            .italic()
    }
}

struct QuickStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassQuickStat()
    }
}

struct HealthMiniStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(AppSection.healthFitness.color)
            Text(value).font(.system(size: 13, weight: .bold))
            Text(label).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MealMiniStat: View {
    let meal: String
    let items: Int
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(AppSection.foodTracker.color)
            Text("\(items)").font(.system(size: 13, weight: .bold))
            Text(meal).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CalorieMiniStat: View {
    let calories: Int

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "flame.fill").font(.system(size: 14)).foregroundColor(.red)
            Text(calories > 0 ? "\(calories)" : "0")
                .font(.system(size: 13, weight: .bold))
            Text("cal").font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExpenseMiniStat: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RatingMiniStat: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= value ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundColor(i <= value ? color : .secondary.opacity(0.3))
                }
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
