import SwiftUI
import HealthKit

// MARK: - Main View

struct HealthFitnessView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddActivity = false
    @State private var isSyncing = false
    @State private var showHKUnavailable = false
    @State private var showSettingsAlert = false

    var entry: DailyEntry { vm.currentEntry }
    var fitness: FitnessEntry { entry.fitness }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                SectionHeader(section: .healthFitness,
                              subtitle: "Track workouts and physical activity",
                              completedCount: fitness.activities.filter(\.isCompleted).count,
                              totalCount: fitness.activities.count)

                // Apple Health Sync Banner
                AppleHealthSyncBanner(
                    syncedAt: fitness.hkSyncedAt,
                    isSyncing: isSyncing,
                    onSync: { syncFromAppleHealth() }
                )
                .padding(.horizontal, 16).padding(.top, 12)

                // Progress Rings (2×2 grid)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Today's Progress")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        HealthRingCard(
                            title: "Workout",
                            icon: "figure.run",
                            value: fitness.displayWorkoutMinutes,
                            target: vm.settings.workoutTarget,
                            unit: "min",
                            color: .orange
                        )
                        HealthRingCard(
                            title: "Walking",
                            icon: "figure.walk",
                            value: fitness.displayWalkingMinutes,
                            target: vm.settings.walkingTarget,
                            unit: "min",
                            color: .green
                        )
                        HealthRingCard(
                            title: "Steps",
                            icon: "shoeprints.fill",
                            value: fitness.displaySteps,
                            target: vm.settings.stepsTarget,
                            unit: "steps",
                            color: .blue
                        )
                        HealthRingCard(
                            title: "Calories",
                            icon: "flame.fill",
                            value: fitness.displayCalories,
                            target: vm.settings.caloriesTarget,
                            unit: "kcal",
                            color: .red
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)

                // Daily Targets
                VStack(alignment: .leading, spacing: 0) {
                    Text("Daily Targets")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 16).padding(.bottom, 8)

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
                }
                .padding(.top, 20)

                // From Apple Health — Workouts
                if !fitness.hkWorkouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "heart.fill").foregroundColor(.red).font(.caption)
                            Text("From Apple Health")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .padding(.horizontal, 16)

                        VStack(spacing: 6) {
                            ForEach(fitness.hkWorkouts) { workout in
                                HKWorkoutRow(workout: workout)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 20)
                }

                // Manual Activities
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("My Activities")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        if !vm.isFuture {
                            Button(action: { showAddActivity = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppSection.healthFitness.color)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)

                    if fitness.activities.isEmpty {
                        EmptySectionView(section: .healthFitness,
                                         message: "Log your personal workouts and activities")
                    } else {
                        VStack(spacing: 6) {
                            ForEach(fitness.activities) { activity in
                                ActivityRowCard(activity: activity) {
                                    vm.toggleFitnessActivity(activity)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.top, 20)

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
        .alert("HealthKit Not Available", isPresented: $showHKUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple Health is not available on this device or simulator.")
        }
        .alert("Health Access Required", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please go to Settings → Privacy & Security → Health → Daily Planner and enable all health data categories.")
        }
        .onAppear { autoSync() }
    }

    // MARK: - Sync Logic

    private func autoSync() {
        guard HealthKitManager.shared.isAvailable else { return }
        // Only auto-sync if this date has never been synced or hasn't been
        // synced today — the app-level foreground sync handles the common case.
        let lastSync = fitness.hkSyncedAt
        let needsSync = lastSync == nil ||
            !Calendar.current.isDateInToday(lastSync!)
        guard needsSync else { return }
        syncFromAppleHealth()
    }

    private func syncFromAppleHealth() {
        guard HealthKitManager.shared.isAvailable else {
            showHKUnavailable = true
            return
        }

        // Check if user has previously denied all HealthKit access.
        // If so, direct them to Settings instead of silently failing.
        let store = HKHealthStore()
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        if store.authorizationStatus(for: stepType) == .sharingDenied {
            showSettingsAlert = true
            return
        }

        isSyncing = true
        let dateToSync = vm.selectedDate
        HealthKitManager.shared.requestAuthorization {
            // Always fetch regardless of auth result —
            // HealthKit returns 0 for denied types but never hangs.
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
                    .frame(width: 38, height: 38)
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health")
                    .font(.system(size: 13, weight: .semibold))
                Text(syncLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.85)
                    .padding(.trailing, 4)
            } else {
                Button(action: onSync) {
                    Text(syncedAt == nil ? "Connect" : "Sync")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(20)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
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

    private var displayValue: String {
        if value >= 1000 && unit == "steps" {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: 10, lineCap: .round))

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: animatedProgress)

                // Center content
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(ringColor)
                    Text(displayValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text("\(value) / \(target) \(unit)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
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
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text("\(value) \(unit)")
                    .font(.caption2)
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
                    .font(.system(size: 15))
                    .foregroundColor(AppSection.healthFitness.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityType)
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 8) {
                    Label("\(workout.durationMinutes) min", systemImage: "timer")
                        .font(.caption2).foregroundColor(.secondary)
                    if workout.calories > 0 {
                        Label("\(workout.calories) kcal", systemImage: "flame")
                            .font(.caption2).foregroundColor(.orange)
                    }
                }
            }
            Spacer()
            Text(timeString)
                .font(.caption2)
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
