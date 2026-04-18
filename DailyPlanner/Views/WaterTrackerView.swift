import SwiftUI

struct WaterTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showGoalSheet    = false
    @State private var showPopper       = false
    // Track previous glass count so we only fire the popper on the
    // exact moment the user crosses from below-goal to at/above-goal.
    @State private var prevWaterCount: Int = -1

    var entry: DailyEntry { vm.currentEntry }
    var percent: Double { vm.waterPercent }

    var body: some View {
        ZStack {
          ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .waterTracker,
                              subtitle: "Stay hydrated throughout the day",
                              completedCount: min(entry.waterGlasses, entry.waterGoal),
                              totalCount: entry.waterGoal)

                // Big visual tracker
                VStack(spacing: 20) {
                    // Circular progress
                    ZStack {
                        Circle()
                            .stroke(AppSection.waterTracker.color.opacity(0.15), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: percent)
                            .stroke(
                                LinearGradient(colors: [Color(red: 0.05, green: 0.65, blue: 0.95),
                                                        Color(red: 0.2, green: 0.85, blue: 1.0)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5), value: percent)

                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppSection.waterTracker.color)
                            Text("\(entry.waterGlasses)")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(.primary)
                            Text("of \(entry.waterGoal) glasses")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .padding(.top, 20)

                    // Motivational message
                    Text(hydrationMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // +/- buttons
                    if !vm.isFuture {
                        HStack(spacing: 24) {
                            Button(action: { vm.decrementWater() }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(entry.waterGlasses > 0 ? .red.opacity(0.8) : .secondary.opacity(0.3))
                            }
                            .disabled(entry.waterGlasses == 0)

                            Button(action: { vm.incrementWater() }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppSection.waterTracker.color)
                            }
                        }
                    }

                    // Glass indicators
                    WaterGlassGrid(glasses: entry.waterGlasses, goal: entry.waterGoal) { _ in
                        if !vm.isFuture { vm.incrementWater() }
                    }
                    .padding(.horizontal, 24)

                    // Change goal
                    Button(action: { showGoalSheet = true }) {
                        Label("Set Daily Goal (\(entry.waterGoal) glasses)", systemImage: "target")
                            .font(.subheadline)
                            .foregroundColor(AppSection.waterTracker.color)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Tips
                WaterTipsCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                Spacer(minLength: 40)
            }
        }
            .sheet(isPresented: $showGoalSheet) {
                WaterGoalSheet(currentGoal: entry.waterGoal) { goal in
                    vm.setWaterGoal(goal)
                }
            }

            if showPopper {
                PartyPopperOverlay(isVisible: $showPopper)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            // Seed prevWaterCount so a view that appears already-complete
            // does NOT immediately fire the popper.
            prevWaterCount = entry.waterGlasses
        }
        .onChange(of: entry.waterGlasses) { newVal in
            let goal = entry.waterGoal
            // Fire only on the transition that crosses the goal threshold
            // (e.g. 7→8 when goal is 8). Re-adding a glass after already
            // reaching goal will not re-trigger.
            if goal > 0 && newVal >= goal && prevWaterCount < goal {
                showPopper = true
            }
            prevWaterCount = newVal
        }
    }

    private var hydrationMessage: String {
        let pct = percent
        if pct == 0 { return "Start your day with a glass of water! 💧" }
        if pct < 0.25 { return "Great start! Keep drinking to stay hydrated." }
        if pct < 0.5 { return "You're doing well! Halfway to your goal." }
        if pct < 0.75 { return "Excellent! Almost at your goal!" }
        if pct < 1.0 { return "Nearly there! One more glass to go!" }
        return "You've hit your water goal! Amazing! 🎉"
    }
}

// MARK: - Water Glass Grid
struct WaterGlassGrid: View {
    let glasses: Int
    let goal: Int
    let onTap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
            ForEach(0..<goal, id: \.self) { i in
                Button(action: { onTap(i) }) {
                    Image(systemName: i < glasses ? "drop.fill" : "drop")
                        .font(.system(size: 22))
                        .foregroundColor(i < glasses ? AppSection.waterTracker.color : .secondary.opacity(0.2))
                        .scaleEffect(i < glasses ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: glasses)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Water Tips Card
struct WaterTipsCard: View {
    private let tips = [
        ("sunrise.fill", "Drink a glass right after waking up", Color.orange),
        ("fork.knife", "Have a glass before each meal", Color.green),
        ("figure.run", "Drink extra during workouts", Color.blue),
        ("moon.fill", "Avoid large amounts before bed", Color.purple)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hydration Tips")
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14)

            ForEach(tips, id: \.0) { tip in
                HStack(spacing: 10) {
                    Image(systemName: tip.0)
                        .font(.system(size: 13))
                        .foregroundColor(tip.2)
                        .frame(width: 24)
                    Text(tip.1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Water Goal Sheet
struct WaterGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var goal: Int
    let onSave: (Int) -> Void

    init(currentGoal: Int, onSave: @escaping (Int) -> Void) {
        self._goal = State(initialValue: currentGoal)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Daily Water Goal") {
                    Stepper("\(goal) glasses", value: $goal, in: 1...20)
                    HStack {
                        ForEach([6, 8, 10, 12], id: \.self) { g in
                            Button("\(g)") { goal = g }
                                .font(.subheadline).fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(goal == g ? AppSection.waterTracker.color : Color(.secondarySystemBackground))
                                .foregroundColor(goal == g ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }
                Section {
                    Text("Recommended: 8 glasses (2 litres) per day for most adults.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Set Water Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(goal); dismiss() }
                }
            }
        }
    }
}
