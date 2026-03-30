import SwiftUI

struct HabitTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddHabit = false
    @State private var selectedHabit: Habit? = nil

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
                                     weekProgress: weekProgress(habit)) {
                                vm.toggleHabit(habit, for: vm.selectedDate)
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
                            AllHabitRow(habit: habit) {
                                vm.deleteHabit(habit)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
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
            AddHabitSheet { habit in vm.addHabit(habit) }
        }
    }

    private func weekProgress(_ habit: Habit) -> [Bool] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: vm.selectedDate)
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        return (0..<7).map { offset in
            let d = cal.date(byAdding: .day, value: offset, to: weekStart)!
            return vm.isHabitCompleted(habit, for: d)
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let streak: Int
    let weekProgress: [Bool]
    let onToggle: () -> Void

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
            // Week mini-progress
            HStack(spacing: 4) {
                let days = ["S","M","T","W","T","F","S"]
                ForEach(0..<7) { i in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(weekProgress[i] ? habit.swiftUIColor : Color.secondary.opacity(0.15))
                            .frame(width: 20, height: 20)
                        Text(days[i]).font(.system(size: 8)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
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
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(habit.swiftUIColor.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: habit.icon).font(.system(size: 13)).foregroundColor(habit.swiftUIColor)
            }
            Text(habit.name).font(.system(size: 13, weight: .medium))
            Spacer()
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

struct AddHabitSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var icon = "star.fill"
    @State private var color = "purple"
    @State private var targetDays = Set<Int>()
    let onSave: (Habit) -> Void

    let icons = ["star.fill","heart.fill","flame.fill","bolt.fill","drop.fill","figure.run",
                 "book.fill","moon.fill","sun.max.fill","music.note","dumbbell.fill","leaf.fill"]
    let colors = ["purple","red","orange","yellow","green","blue","indigo","pink"]
    let dayNames = ["S","M","T","W","T","F","S"]

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

                    // REPEAT
                    Group {
                        Text("REPEAT")
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
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        onSave(Habit(name: name, icon: icon, color: color,
                                     targetDays: Array(targetDays).sorted()))
                        dismiss()
                    }
                    .disabled(name.isEmpty || targetDays.isEmpty)
                }
            }
        }
    }

    private var selectedColor: Color { Habit(name: "", color: color).swiftUIColor }
}
