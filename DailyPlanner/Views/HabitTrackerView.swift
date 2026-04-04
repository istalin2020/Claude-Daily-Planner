import SwiftUI

struct HabitTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddHabit = false
    @State private var habitToEdit: Habit? = nil

    private var todayHabits: [Habit] {
        let weekday = Calendar.current.component(.weekday, from: vm.selectedDate)
        return vm.settings.habits.filter { $0.targetDays.contains(weekday) }
    }

    private var completedCount: Int {
        todayHabits.filter { vm.isHabitCompleted($0, for: vm.selectedDate) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .habits,
                              subtitle: "Build powerful daily habits",
                              completedCount: completedCount,
                              totalCount: todayHabits.count)

                // Progress banner
                if !vm.settings.habits.isEmpty {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: todayHabits.isEmpty ? 0
                                      : CGFloat(completedCount) / CGFloat(todayHabits.count))
                                .stroke(vm.settings.themeColor.primary,
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(todayHabits.isEmpty ? 0 : Int(Double(completedCount)/Double(todayHabits.count)*100))%")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(completedCount) of \(todayHabits.count) habits done today")
                                .font(.system(size: 14, weight: .semibold))
                            Text(completedCount == todayHabits.count && !todayHabits.isEmpty
                                 ? "🎉 Perfect day!" : "Keep going!")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // Today's habits
                if todayHabits.isEmpty && vm.settings.habits.isEmpty {
                    EmptySectionView(section: .habits,
                                     message: "Add habits to track daily, like workout, reading, or meditation")
                } else if todayHabits.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 36)).foregroundColor(.secondary.opacity(0.4))
                        Text("No habits scheduled for this day")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(todayHabits) { habit in
                            HabitRow(habit: habit,
                                     isCompleted: vm.isHabitCompleted(habit, for: vm.selectedDate),
                                     streak: vm.habitStreak(habit),
                                     weekProgress: weekProgress(habit),
                                     weekDates: weekDates()) {
                                vm.toggleHabit(habit, for: vm.selectedDate)
                            } onToggleDay: { date in
                                vm.toggleHabit(habit, for: date)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 12)
                }

                // All habits management
                if !vm.settings.habits.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Habits")
                            .font(.system(size: 15, weight: .bold))
                            .padding(.horizontal, 16)

                        ForEach(vm.settings.habits) { habit in
                            AllHabitRow(habit: habit,
                                        onEdit: { habitToEdit = habit },
                                        onDelete: { vm.deleteHabit(habit) })
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 20)

                    // Weekly Statistics Table
                    weeklyStatisticsSection
                        .padding(.top, 20)

                    // Monthly Statistics Table
                    monthlyStatisticsSection
                        .padding(.top, 20)
                }

                if !vm.isFuture {
                    Button { showAddHabit = true } label: {
                        Label("Add New Habit", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(vm.settings.themeColor.primary.opacity(0.1))
                            .foregroundColor(vm.settings.themeColor.primary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddHabit) {
            HabitEditSheet(habit: nil) { habit in vm.addHabit(habit) }
        }
        .sheet(item: $habitToEdit) { habit in
            HabitEditSheet(habit: habit) { updated in vm.updateHabit(updated) }
        }
    }

    private func weekProgress(_ habit: Habit) -> [Bool] {
        weekDates().map { vm.isHabitCompleted(habit, for: $0) }
    }

    private func weekDates() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: vm.selectedDate)
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0..<7).map { offset in
            cal.date(byAdding: .day, value: offset, to: weekStart)!
        }
    }

    // MARK: - Helpers

    private func monthDates() -> [Date] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: vm.selectedDate)
        guard let monthStart = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        return range.compactMap { day -> Date? in
            var dc = comps; dc.day = day
            return cal.date(from: dc)
        }
    }

    // MARK: - Shared Stats Row

    @ViewBuilder
    private func statsRow(habit: Habit, achieved: Int, planned: Int) -> some View {
        let percent = planned > 0 ? Int(Double(achieved) / Double(planned) * 100) : 0
        let rateColor: Color = percent == 100 ? Color(red: 0.1, green: 0.75, blue: 0.4)
            : percent >= 50 ? .orange : .red

        HStack {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(habit.swiftUIColor.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: habit.icon)
                        .font(.system(size: 11))
                        .foregroundColor(habit.swiftUIColor)
                }
                Text(habit.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(achieved)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(habit.swiftUIColor)
                .frame(width: 44, alignment: .center)

            Text("\(planned)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .center)

            Text("\(percent)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(rateColor)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func statsTableHeader() -> some View {
        HStack {
            Text("Habit")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Done")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .center)
            Text("Plan")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .center)
            Text("Rate")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.6))
    }

    // MARK: - Weekly Statistics Table

    private var weeklyStatisticsSection: some View {
        let dates = weekDates()
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let weekLabel = "\(fmt.string(from: dates[0])) – \(fmt.string(from: dates[6]))"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weekly Statistics")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(weekLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            statsTableHeader()

            VStack(spacing: 6) {
                ForEach(vm.settings.habits) { habit in
                    let achieved = dates.filter { date in
                        let wd = cal.component(.weekday, from: date)
                        return habit.targetDays.contains(wd) && vm.isHabitCompleted(habit, for: date)
                    }.count
                    let planned = dates.filter { date in
                        let wd = cal.component(.weekday, from: date)
                        return habit.targetDays.contains(wd)
                    }.count
                    statsRow(habit: habit, achieved: achieved, planned: planned)
                }
            }
        }
    }

    // MARK: - Monthly Statistics Table

    private var monthlyStatisticsSection: some View {
        let dates = monthDates()
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let monthLabel = fmt.string(from: vm.selectedDate)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Monthly Statistics")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(monthLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            statsTableHeader()

            VStack(spacing: 6) {
                ForEach(vm.settings.habits) { habit in
                    let achieved = dates.filter { date in
                        let wd = cal.component(.weekday, from: date)
                        return habit.targetDays.contains(wd) && vm.isHabitCompleted(habit, for: date)
                    }.count
                    let planned = dates.filter { date in
                        let wd = cal.component(.weekday, from: date)
                        return habit.targetDays.contains(wd)
                    }.count
                    statsRow(habit: habit, achieved: achieved, planned: planned)
                }
            }

            // Month summary bar
            let totalAchieved = vm.settings.habits.reduce(0) { sum, habit in
                sum + dates.filter { date in
                    let wd = cal.component(.weekday, from: date)
                    return habit.targetDays.contains(wd) && vm.isHabitCompleted(habit, for: date)
                }.count
            }
            let totalPlanned = vm.settings.habits.reduce(0) { sum, habit in
                sum + dates.filter { date in
                    let wd = cal.component(.weekday, from: date)
                    return habit.targetDays.contains(wd)
                }.count
            }
            let overallRate = totalPlanned > 0 ? Double(totalAchieved) / Double(totalPlanned) : 0

            VStack(spacing: 6) {
                HStack {
                    Text("Overall completion")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(totalAchieved) / \(totalPlanned)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    Text("(\(Int(overallRate * 100))%)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(overallRate == 1 ? Color(red: 0.1, green: 0.75, blue: 0.4)
                                         : overallRate >= 0.5 ? .orange : .red)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(overallRate == 1 ? Color(red: 0.1, green: 0.75, blue: 0.4)
                                  : overallRate >= 0.5 ? Color.orange : Color.red)
                            .frame(width: geo.size.width * overallRate, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let streak: Int
    let weekProgress: [Bool]
    let weekDates: [Date]
    let onToggle: () -> Void
    let onToggleDay: (Date) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? habit.swiftUIColor : habit.swiftUIColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: habit.icon)
                            .font(.system(size: 18))
                            .foregroundColor(isCompleted ? .white : habit.swiftUIColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name).font(.system(size: 14, weight: .semibold))
                    if streak > 0 {
                        Label("\(streak) day streak", systemImage: "flame.fill")
                            .font(.caption2).foregroundColor(.orange)
                    }
                }
                Spacer()
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(habit.swiftUIColor)
                }
            }
            // Week mini-progress (Sun–Sat) — each day is tappable
            HStack(spacing: 4) {
                let days = ["S","M","T","W","T","F","S"]
                ForEach(0..<7) { i in
                    Button(action: { onToggleDay(weekDates[i]) }) {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(weekProgress[i] ? habit.swiftUIColor : Color.secondary.opacity(0.15))
                                .frame(width: 20, height: 20)
                            Text(days[i]).font(.system(size: 8)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct AllHabitRow: View {
    let habit: Habit
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(habit.swiftUIColor.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: habit.icon).font(.system(size: 13)).foregroundColor(habit.swiftUIColor)
            }
            Text(habit.name).font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(BorderlessButtonStyle())
            Button(action: onDelete) {
                Image(systemName: "trash").font(.caption).foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - Unified Add/Edit Habit Sheet

struct HabitEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var color: String
    @State private var targetDays: Set<Int>

    let existingHabit: Habit?
    let onSave: (Habit) -> Void

    let icons = ["star.fill","heart.fill","flame.fill","bolt.fill","drop.fill","figure.run",
                 "book.fill","moon.fill","sun.max.fill","music.note","dumbbell.fill","leaf.fill"]
    let colors = ["purple","red","orange","yellow","green","blue","indigo","pink"]
    let dayNames = ["S","M","T","W","T","F","S"]

    init(habit: Habit?, onSave: @escaping (Habit) -> Void) {
        self.existingHabit = habit
        self.onSave = onSave
        _name       = State(initialValue: habit?.name ?? "")
        _icon       = State(initialValue: habit?.icon ?? "star.fill")
        _color      = State(initialValue: habit?.color ?? "purple")
        _targetDays = State(initialValue: habit.map { Set($0.targetDays) } ?? Set<Int>())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // HABIT NAME
                    Group {
                        Text("HABIT NAME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 6)

                        TextField("e.g. Morning Workout, Read 20 min", text: $name)
                            .autocapitalization(.sentences)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                    }

                    // ICON
                    Group {
                        Text("ICON")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 6)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(icons, id: \.self) { ic in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(icon == ic ? selectedColor : Color(.secondarySystemBackground))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: ic)
                                        .font(.system(size: 20))
                                        .foregroundColor(icon == ic ? .white : .primary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { icon = ic }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }

                    // COLOR
                    Group {
                        Text("COLOR")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 6)

                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { c in
                                let col = Habit(name: "", color: c).swiftUIColor
                                ZStack {
                                    Circle()
                                        .fill(col)
                                        .frame(width: 34, height: 34)
                                    if color == c {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .shadow(color: col.opacity(0.4), radius: 3)
                                .contentShape(Circle())
                                .onTapGesture { color = c }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }

                    // REPEAT (Sunday to Saturday)
                    Group {
                        Text("REPEAT (Sun – Sat)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 6)

                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(targetDays.contains(day) ? selectedColor : Color(.secondarySystemBackground))
                                        .frame(width: 38, height: 38)
                                    Text(dayNames[day - 1])
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(targetDays.contains(day) ? .white : .primary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if targetDays.contains(day) {
                                        targetDays.remove(day)
                                    } else {
                                        targetDays.insert(day)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(existingHabit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingHabit == nil ? "Add" : "Save") {
                        guard !name.isEmpty else { return }
                        let habit = Habit(
                            id: existingHabit?.id ?? UUID(),
                            name: name,
                            icon: icon,
                            color: color,
                            targetDays: Array(targetDays).sorted(),
                            reminderTime: existingHabit?.reminderTime,
                            createdDate: existingHabit?.createdDate ?? Date()
                        )
                        onSave(habit)
                        dismiss()
                    }
                    .disabled(name.isEmpty || targetDays.isEmpty)
                }
            }
        }
    }

    private var selectedColor: Color { Habit(name: "", color: color).swiftUIColor }
}

// Keep AddHabitSheet as a typealias for backward compatibility
typealias AddHabitSheet = HabitEditSheet
