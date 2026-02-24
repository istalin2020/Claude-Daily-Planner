import SwiftUI

struct HealthFitnessView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddActivity = false
    @State private var showStepsSheet = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .healthFitness,
                              subtitle: "Track workouts and physical activity",
                              completedCount: entry.fitness.activities.filter(\.isCompleted).count,
                              totalCount: entry.fitness.activities.count)

                // Stats Row
                HStack(spacing: 10) {
                    FitnessStatBox(icon: "timer", value: "\(entry.fitness.totalMinutes)", label: "Minutes", color: .orange)
                    FitnessStatBox(icon: "flame.fill", value: "\(entry.fitness.totalCaloriesBurned)", label: "Calories", color: .red)
                    FitnessStatBox(icon: "figure.walk", value: "\(entry.fitness.steps)", label: "Steps", color: .blue)
                }
                .padding(.horizontal, 16).padding(.top, 12)

                // Steps input
                Button(action: { showStepsSheet = true }) {
                    HStack {
                        Image(systemName: "figure.walk").foregroundColor(.blue)
                        Text("Update Steps").font(.subheadline)
                        Spacer()
                        Text("\(entry.fitness.steps) steps").foregroundColor(.secondary).font(.subheadline)
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16).padding(.top, 8)

                if !vm.isFuture {
                    AddButton(label: "Add Activity", color: AppSection.healthFitness.color) {
                        showAddActivity = true
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }

                if entry.fitness.activities.isEmpty {
                    EmptySectionView(section: .healthFitness,
                                     message: "Log your workouts and physical activities")
                } else {
                    VStack(spacing: 6) {
                        ForEach(entry.fitness.activities) { activity in
                            ActivityRowCard(activity: activity) {
                                vm.toggleFitnessActivity(activity)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 8)
                }

                // Notes
                NotesCard(title: "Fitness Notes", text: entry.fitness.generalNotes,
                          placeholder: "How did the workout feel?",
                          color: AppSection.healthFitness.color) { notes in
                    vm.updateFitnessNotes(notes)
                }
                .padding(.horizontal, 16).padding(.top, 12)

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddActivity) {
            AddActivitySheet { activity in
                vm.addFitnessActivity(activity)
            }
        }
        .sheet(isPresented: $showStepsSheet) {
            StepsInputSheet(currentSteps: entry.fitness.steps) { steps in
                vm.updateSteps(steps)
            }
        }
    }
}

// MARK: - Fitness Stat Box
struct FitnessStatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Activity Row Card
struct ActivityRowCard: View {
    let activity: FitnessActivity
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(activity.isCompleted ? AppSection.healthFitness.color : .secondary.opacity(0.4))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.system(size: 14, weight: .semibold))
                    .strikethrough(activity.isCompleted)
                HStack(spacing: 10) {
                    Label("\(activity.duration) min", systemImage: "timer")
                        .font(.caption).foregroundColor(.secondary)
                    if activity.calories > 0 {
                        Label("\(activity.calories) cal", systemImage: "flame")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

// MARK: - Add Activity Sheet
struct AddActivitySheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var duration = 30
    @State private var calories = 0
    let onSave: (FitnessActivity) -> Void

    private let presets = ["Running", "Walking", "Cycling", "Swimming", "Yoga", "Weight Training",
                           "HIIT", "Pilates", "Stretching", "Dancing"]

    var body: some View {
        NavigationView {
            Form {
                Section("Activity Name") {
                    TextField("e.g. Running, Yoga, Cycling", text: $name)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { p in
                                Button(p) { name = p }
                                    .font(.caption)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(name == p ? AppSection.healthFitness.color : Color(.secondarySystemBackground))
                                    .foregroundColor(name == p ? .white : .primary)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Duration (minutes)") {
                    Stepper("\(duration) minutes", value: $duration, in: 5...300, step: 5)
                }
                Section("Calories Burned (optional)") {
                    Stepper("\(calories) cal", value: $calories, in: 0...2000, step: 10)
                }
            }
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        onSave(FitnessActivity(name: name, duration: duration, calories: calories))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Steps Input Sheet
struct StepsInputSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var stepsText: String
    @State private var steps: Int
    let onSave: (Int) -> Void

    private let presets = [2000, 5000, 8000, 10000]

    init(currentSteps: Int, onSave: @escaping (Int) -> Void) {
        let initial = currentSteps > 0 ? currentSteps : 0
        self._steps = State(initialValue: initial)
        self._stepsText = State(initialValue: initial > 0 ? "\(initial)" : "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.blue)
                        TextField("Type step count", text: $stepsText)
                            .keyboardType(.numberPad)
                            .onChange(of: stepsText) { newValue in
                                let digits = newValue.filter(\.isNumber)
                                if digits != newValue { stepsText = digits }
                                steps = Int(digits) ?? 0
                            }
                        if !stepsText.isEmpty {
                            Button {
                                stepsText = ""
                                steps = 0
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Steps Today")
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                steps = preset
                                stepsText = "\(preset)"
                            } label: {
                                Text("\(preset)")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(steps == preset ? Color.blue : Color(.secondarySystemBackground))
                                    .foregroundColor(steps == preset ? .white : .primary)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Quick Select")
                }
            }
            .navigationTitle("Daily Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(steps); dismiss() }
                }
            }
        }
    }
}
