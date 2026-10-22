import SwiftUI
import HealthKit

// MARK: - Main View

struct HealthFitnessView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddActivity = false
    @State private var isSyncing = false
    @State private var showHKUnavailable = false
    @State private var showSettingsAlert = false
    @State private var showTargetsSheet = false

    var entry: DailyEntry { vm.currentEntry }
    var fitness: FitnessEntry { entry.fitness }

    private var goalsMet: Int {
        let s = vm.settings
        return [(fitness.displayWorkoutMinutes, s.workoutTarget),
                (fitness.displayWalkingMinutes, s.walkingTarget),
                (fitness.displaySteps, s.stepsTarget),
                (fitness.displayCalories, s.caloriesTarget)]
            .filter { $0.1 > 0 && $0.0 >= $0.1 }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Apple Health Sync Banner
                AppleHealthSyncBanner(
                    syncedAt: fitness.hkSyncedAt,
                    isSyncing: isSyncing,
                    onSync: { syncFromAppleHealth() }
                )
                .padding(.horizontal, 16).padding(.top, 12)

                // Today's Progress — the four goals, with Set Target
                FitnessCard(color: AppSection.healthFitness.color, icon: "figure.run",
                            title: vm.isToday ? "Today's Progress" : "Day's Progress",
                            subtitle: "\(goalsMet) of 4 goals reached") {
                    FitnessPill(title: "Set Target", icon: "target", color: AppSection.healthFitness.color) {
                        showTargetsSheet = true
                    }
                } content: {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        HealthRingCard(title: "Workout", icon: "figure.run",
                                       value: fitness.displayWorkoutMinutes,
                                       target: vm.settings.workoutTarget, unit: "min", color: .orange)
                        HealthRingCard(title: "Walking", icon: "figure.walk",
                                       value: fitness.displayWalkingMinutes,
                                       target: vm.settings.walkingTarget, unit: "min", color: .green)
                        HealthRingCard(title: "Steps", icon: "shoeprints.fill",
                                       value: fitness.displaySteps,
                                       target: vm.settings.stepsTarget, unit: "steps", color: .blue)
                        HealthRingCard(title: "Calories", icon: "flame.fill",
                                       value: fitness.displayCalories,
                                       target: vm.settings.caloriesTarget, unit: "kcal", color: .red)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14)

                // From Apple Health — Workouts
                if !fitness.hkWorkouts.isEmpty {
                    FitnessCard(color: .red, icon: "heart.fill", title: "From Apple Health",
                                subtitle: "\(fitness.hkWorkouts.count) workout\(fitness.hkWorkouts.count == 1 ? "" : "s") recorded") {
                        EmptyView()
                    } content: {
                        VStack(spacing: 6) {
                            ForEach(fitness.hkWorkouts) { workout in
                                HKWorkoutRow(workout: workout)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                }

                // My Activities — the user's own log
                FitnessCard(color: .purple, icon: "figure.strengthtraining.traditional",
                            title: "My Activities",
                            subtitle: fitness.activities.isEmpty
                                ? "Log your own workouts"
                                : "\(fitness.activities.filter(\.isCompleted).count) of \(fitness.activities.count) done") {
                    if !vm.isFuture {
                        FitnessPill(title: "Add", icon: "plus", color: .purple) { showAddActivity = true }
                    }
                } content: {
                    if fitness.activities.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.mixed.cardio")
                                .font(.system(size: 30))
                                .foregroundColor(.purple.opacity(0.45))
                                .frame(width: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No activities yet")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Yoga, gym, cycling, a walk with friends — add anything you did.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    } else {
                        VStack(spacing: 6) {
                            ForEach(fitness.activities) { activity in
                                ActivityRowCard(activity: activity) {
                                    vm.toggleFitnessActivity(activity)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14)

                // Notes
                NotesCard(title: "Fitness Notes", text: fitness.generalNotes,
                          placeholder: "How did the workout feel?",
                          color: AppSection.healthFitness.color) { notes in
                    vm.updateFitnessNotes(notes)
                }
                .padding(.horizontal, 16).padding(.top, 16)

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddActivity) {
            AddActivitySheet { activity in
                vm.addFitnessActivity(activity)
            }
        }
        .sheet(isPresented: $showTargetsSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    VStack(spacing: 1) {
                        TargetStepperRow(icon: "figure.run",     title: "Workout Time",  unit: "min",   step: 5,    range: 5...300,   color: .orange,   value: $vm.settings.workoutTarget)
                        TargetStepperRow(icon: "figure.walk",    title: "Walking Time",  unit: "min",   step: 5,    range: 5...300,   color: .green,    value: $vm.settings.walkingTarget)
                        TargetStepperRow(icon: "shoeprints.fill",title: "Steps",         unit: "steps", step: 500,  range: 500...50000, color: .blue,   value: $vm.settings.stepsTarget)
                        TargetStepperRow(icon: "flame.fill",     title: "Calories",      unit: "kcal",  step: 50,   range: 50...5000, color: .red,      value: $vm.settings.caloriesTarget)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()
                }
                .navigationTitle("Daily Targets")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showTargetsSheet = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("HealthKit Not Available", isPresented: $showHKUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple Health is not available on this device or simulator.")
        }
        .alert("Health Access Required", isPresented: $showSettingsAlert) {
            Button("Open Health App") {
                // iOS offers no public deep link to Settings → Privacy &
                // Security → Health → <app>, so open the Health app where
                // the same permissions live (Profile → Privacy → Apps).
                if let url = URL(string: "x-apple-health://") {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if !success, let settings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settings)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("In the Health app, tap your profile picture → Privacy → Apps → Daily Planner and turn on all categories.\n\n(Alternatively: Settings → Privacy & Security → Health → Daily Planner.)")
        }
        .onAppear { autoSync() }
        .onChange(of: vm.selectedDate) { _, _ in autoSync() }
    }

    // MARK: - Sync Logic

    private func autoSync() {
        guard HealthKitManager.shared.isAvailable else { return }
        // Opening the page never asks for Health access; Connect does.
        guard HealthKitManager.shared.isLinkedByUser else { return }
        guard !isSyncing else { return }
        performSync()
    }

    private func syncFromAppleHealth() {
        guard HealthKitManager.shared.isAvailable else {
            showHKUnavailable = true
            return
        }

        if HealthKitManager.shared.isStepCountAuthDenied {
            showSettingsAlert = true
        }

        HealthKitManager.shared.isLinkedByUser = true
        performSync()
        // From now on keep today fresh in the background too.
        vm.syncHealthKitForToday()
    }

    private func performSync() {
        guard !isSyncing else { return }
        isSyncing = true
        let dateToSync = vm.selectedDate
        HealthKitManager.shared.requestAuthorization {
            HealthKitManager.shared.fetchAllHealthData(for: dateToSync) { data in
                vm.syncHealthKitData(
                    for: dateToSync,
                    steps: data.steps,
                    calories: data.calories,
                    workoutMins: data.workoutMinutes,
                    walkingMins: data.walkingMinutes,
                    workouts: data.workouts
                )
                isSyncing = false
            }
        }
    }
}

// MARK: - Apple Health Sync Banner

struct AppleHealthSyncBanner: View {
    let syncedAt: Date?
    let isSyncing: Bool
    let onSync: () -> Void

    private var syncLabel: String {
        guard HealthKitManager.shared.isLinkedByUser else {
            return "Tap Connect to bring in steps and workouts"
        }
        guard let date = syncedAt else { return "Not synced yet" }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return "Synced \(fmt.localizedString(for: date, relativeTo: Date()))"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 19))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health")
                    .font(.system(size: 17, weight: .semibold))
                Text(syncLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2).minimumScaleFactor(0.85)
            }
            Spacer()
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.85)
                    .padding(.trailing, 4)
            } else {
                Button(action: onSync) {
                    Text(syncedAt == nil || !HealthKitManager.shared.isLinkedByUser ? "Connect" : "Sync")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(20)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.red.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - Section card (same style as the other redesigned pages)

private struct FitnessCard<Trailing: View, Content: View>: View {
    let color: Color
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13).fill(color.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 13.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [color.opacity(0.08), color.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        )
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(color.opacity(0.15), lineWidth: 1))
        .shadow(color: color.opacity(0.06), radius: 10, y: 4)
    }
}

private struct FitnessPill: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            }
            .foregroundColor(color)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(color.opacity(0.13)))
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Health Ring Card

struct HealthRingCard: View {
    let title: String
    let icon: String
    let value: Int
    let target: Int
    let unit: String
    let color: Color

    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(value) / CGFloat(target), 1.0)
    }

    private var ringColor: Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return .orange }
        return color
    }

    private var displayValue: String { value.formatted() }

    /// A smaller ring beside large, easy-to-read figures, so the four cards
    /// take half the height they used to.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayValue)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("of \(target.formatted()) \(unit)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: animatedProgress)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(ringColor)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 56, height: 56)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(color.opacity(0.15), lineWidth: 1))
        .shadow(color: color.opacity(0.06), radius: 8, y: 3)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animatedProgress = progress
            }
        }
        .onChange(of: value) { _, _ in
            animatedProgress = progress
        }
    }
}

// MARK: - Target Stepper Row

struct TargetStepperRow: View {
    let icon: String
    let title: String
    let unit: String
    let step: Int
    let range: ClosedRange<Int>
    let color: Color
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text("\(value) \(unit)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// MARK: - HealthKit Workout Row

struct HKWorkoutRow: View {
    let workout: HealthWorkout

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: workout.startTime)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppSection.healthFitness.color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: workout.icon)
                    .font(.system(size: 17))
                    .foregroundColor(AppSection.healthFitness.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityType)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 8) {
                    Label("\(workout.durationMinutes) min", systemImage: "timer")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    if workout.calories > 0 {
                        Label("\(workout.calories) kcal", systemImage: "flame")
                            .font(.system(size: 12)).foregroundColor(.orange)
                    }
                }
            }
            Spacer()
            Text(timeString)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - Activity Row Card (manual activities)

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
                    .font(.system(size: 16, weight: .semibold))
                    .strikethrough(activity.isCompleted)
                HStack(spacing: 10) {
                    Label("\(activity.duration) min", systemImage: "timer")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                    if activity.calories > 0 {
                        Label("\(activity.calories) cal", systemImage: "flame")
                            .font(.system(size: 13)).foregroundColor(.orange)
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

// MARK: - Fitness Stat Box (kept for overview / summary use)

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
