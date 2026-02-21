import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var vm: PlannerViewModel

    private var entry: DailyEntry { vm.currentEntry }

    private var dateTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d, yyyy"
        return fmt.string(from: vm.selectedDate)
    }

    var body: some View {
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
                            .stroke(Color(red: 0.45, green: 0.25, blue: 0.85),
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
                    QuickStatCard(icon: "drop.fill", label: "Water",
                                  value: "\(entry.waterGlasses)/\(entry.waterGoal)",
                                  color: AppSection.waterTracker.color)
                    QuickStatCard(icon: "dollarsign.circle.fill", label: "Spent",
                                  value: String(format: "$%.0f", entry.totalExpenses),
                                  color: AppSection.expenseTracker.color)
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

                // Health & Fitness Card
                OverviewCard(section: .healthFitness, action: { vm.selectedSection = .healthFitness }) {
                    HStack(spacing: 16) {
                        HealthMiniStat(icon: "figure.run", label: "Workouts",
                                       value: "\(entry.fitness.activities.filter(\.isCompleted).count)")
                        HealthMiniStat(icon: "timer", label: "Minutes",
                                       value: "\(entry.fitness.totalMinutes)")
                        HealthMiniStat(icon: "flame.fill", label: "Calories",
                                       value: "\(entry.fitness.totalCaloriesBurned)")
                        HealthMiniStat(icon: "figure.walk", label: "Steps",
                                       value: "\(entry.fitness.steps)")
                    }
                    .frame(maxWidth: .infinity)
                }

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

                // Food Tracker Card
                OverviewCard(section: .foodTracker, action: { vm.selectedSection = .foodTracker }) {
                    HStack(spacing: 12) {
                        MealMiniStat(meal: "Breakfast", items: entry.meals.breakfastItems.count, icon: "sunrise.fill")
                        MealMiniStat(meal: "Lunch", items: entry.meals.lunchItems.count, icon: "sun.max.fill")
                        MealMiniStat(meal: "Dinner", items: entry.meals.dinnerItems.count, icon: "moon.fill")
                    }
                    .frame(maxWidth: .infinity)
                    if entry.meals.totalCalories > 0 {
                        Text("Total: \(entry.meals.totalCalories) cal")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

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

                // Notes for Tomorrow
                OverviewCard(section: .notesForTomorrow, action: { vm.selectedSection = .notesForTomorrow }) {
                    if entry.notesForTomorrow.isEmpty {
                        EmptyOverviewRow(text: "No notes for tomorrow")
                    } else {
                        Text(entry.notesForTomorrow)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Expense Tracker Card
                OverviewCard(section: .expenseTracker, action: { vm.selectedSection = .expenseTracker }) {
                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text(String(format: "$%.2f", entry.totalExpenses))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.red)
                            Text("Spent")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        VStack(spacing: 2) {
                            Text(String(format: "$%.2f", entry.totalDeposits))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                            Text("Saved")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        VStack(spacing: 2) {
                            Text(String(format: "$%.2f", entry.savings))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Future Fund")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Rate Your Day Card
                OverviewCard(section: .rateYourDay, action: { vm.selectedSection = .rateYourDay }) {
                    HStack(spacing: 20) {
                        RatingMiniStat(label: "Productivity", value: entry.rating.productivity, color: .orange)
                        RatingMiniStat(label: "Mood", value: entry.rating.mood, color: .pink)
                        RatingMiniStat(label: "Health", value: entry.rating.health, color: .red)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 24)
            }
        }
    }
}

// MARK: - Overview Card
struct OverviewCard<Content: View>: View {
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
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
