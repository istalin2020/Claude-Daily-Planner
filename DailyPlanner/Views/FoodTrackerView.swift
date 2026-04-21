import SwiftUI

// MARK: - Food Tracker

struct FoodTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet  = false
    @State private var selectedMeal  = "breakfast"
    @State private var editingItem: MealItem? = nil
    @State private var editingMealKey: String = ""

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .foodTracker,
                              subtitle: "Log your meals and nutrition",
                              completedCount: totalItems,
                              totalCount: totalItems)

                // ── Calorie banner (auto-calculated) ────────────────────────
                CalorieBanner(total: entry.meals.totalCalories)
                    .padding(.horizontal, 16).padding(.top, 8)

                // ── Meal sections ────────────────────────────────────────────
                ForEach(mealSections, id: \.key) { meal in
                    MealSection(
                        meal:    meal,
                        items:   meal.items(entry),
                        canEdit: !vm.isFuture
                    ) {
                        selectedMeal = meal.key
                        showAddSheet = true
                    } onDelete: { item in
                        vm.removeMealItem(item, from: meal.key)
                    } onEdit: { item in
                        editingItem = item
                        editingMealKey = meal.key
                    }
                    .padding(.horizontal, 16).padding(.top, 10)
                }

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            let mealName = mealSections.first(where: { $0.key == selectedMeal })?.name ?? "Meal"
            AddMealItemSheet(mealName: mealName) { item in
                vm.addMealItem(item, to: selectedMeal)
            }
        }
        .sheet(item: $editingItem) { item in
            let mealName = mealSections.first(where: { $0.key == editingMealKey })?.name ?? "Meal"
            EditMealItemSheet(item: item, mealName: mealName) { updatedItem in
                vm.updateMealItem(item, with: updatedItem, in: editingMealKey)
            }
        }
    }

    private var totalItems: Int {
        entry.meals.breakfastItems.count + entry.meals.lunchItems.count +
        entry.meals.dinnerItems.count   + entry.meals.snackItems.count
    }

    private var mealSections: [MealSectionModel] {
        [
            MealSectionModel(key: "breakfast", name: "Breakfast", icon: "sunrise.fill",  color: .orange,
                             items: { $0.meals.breakfastItems }),
            MealSectionModel(key: "lunch",     name: "Lunch",     icon: "sun.max.fill",  color: .yellow,
                             items: { $0.meals.lunchItems }),
            MealSectionModel(key: "dinner",    name: "Dinner",    icon: "moon.fill",     color: .indigo,
                             items: { $0.meals.dinnerItems }),
            MealSectionModel(key: "snacks",    name: "Snacks",    icon: "leaf.fill",     color: .green,
                             items: { $0.meals.snackItems })
        ]
    }
}

// MARK: - Calorie Banner

private struct CalorieBanner: View {
    let total: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Calories")
                    .font(.caption).foregroundColor(.secondary)
                Text(total > 0 ? "\(total) cal" : "Add foods to calculate")
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(total > 0 ? .primary : .secondary)
            }

            Spacer()

            if total > 0 {
                // Simple donut-style ring for visual feedback
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(total) / 2000.0, 1.0))
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 44, height: 44)
                .animation(.easeOut, value: total)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Meal Section Model

struct MealSectionModel {
    let key   : String
    let name  : String
    let icon  : String
    let color : Color
    let items : (DailyEntry) -> [MealItem]
}

// MARK: - Meal Section

struct MealSection: View {
    let meal    : MealSectionModel
    let items   : [MealItem]
    let canEdit : Bool
    let onAdd   : () -> Void
    let onDelete: (MealItem) -> Void
    let onEdit  : (MealItem) -> Void

    private var sectionCalories: Int { items.reduce(0) { $0 + $1.calories } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: meal.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(meal.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(meal.name)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                if sectionCalories > 0 {
                    Text("\(sectionCalories) cal")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(meal.color)
                }
                if canEdit {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(meal.color)
                            .font(.system(size: 22))
                    }
                    .padding(.leading, 4)
                }
            }

            if items.isEmpty {
                Text("Nothing logged yet")
                    .font(.caption).foregroundColor(.secondary).italic()
                    .padding(.leading, 4)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(meal.color.opacity(0.6))
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.subheadline)
                            if !item.portion.isEmpty {
                                Text(item.portion)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if item.calories > 0 {
                            Text("\(item.calories) cal")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        if canEdit {
                            // Edit button
                            Button(action: { onEdit(item) }) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(meal.color.opacity(0.7))
                            }
                            // Delete button
                            Button(action: { onDelete(item) }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Add Meal Item Sheet
// Three-phase flow:
//   1. idle          – user types a food name
//   2. clarifying    – system asks follow-up questions
//   3. unknown       – food not in database; user enters calories manually

struct AddMealItemSheet: View {
    @Environment(\.dismiss) var dismiss

    let mealName: String
    let onSave: (MealItem) -> Void

    // Phase 1
    @State private var foodName      = ""
    @FocusState private var focused : Bool

    // Phase 2 – clarification
    @State private var questions     : [ClarifyQuestion] = []
    @State private var selections    : [UUID: ClarifyOption] = [:]

    // Phase 3 – manual entry
    @State private var manualCalText = ""

    // Which phase we're in
    private enum Phase { case idle, clarifying, unknown }
    @State private var phase: Phase = .idle

    // ── Computed helpers ────────────────────────────────────────────────────

    private var estimatedCalories: Int {
        selections.values.reduce(0) { $0 + $1.calories }
    }

    private var selectedPortion: String {
        selections.values.first.map { $0.label } ?? ""
    }

    private var canSave: Bool {
        switch phase {
        case .idle:       return false
        case .clarifying: return selections.count == questions.count
        case .unknown:    return true   // save with 0 cal if blank
        }
    }

    // ── Body ────────────────────────────────────────────────────────────────

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Phase 1: Food name entry ─────────────────────────────
                    foodNameSection

                    // ── Phase 2: Clarification questions ────────────────────
                    if phase == .clarifying {
                        clarifySection
                    }

                    // ── Phase 3: Unknown food – manual calorie entry ─────────
                    if phase == .unknown {
                        unknownSection
                    }
                }
                .padding(20)
            }
            .navigationTitle("Add to \(mealName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveItem() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
    }

    // MARK: – Sub-views

    private var foodNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What did you eat?")
                .font(.headline)

            HStack(spacing: 10) {
                TextField("e.g. Banana, Grilled chicken…", text: $foodName)
                    .focused($focused)
                    .autocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit { analyzeFood() }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                Button(action: analyzeFood) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(AppSection.foodTracker.color)
                        .cornerRadius(12)
                }
                .disabled(foodName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("Tap \(Image(systemName: "sparkle.magnifyingglass")) to auto-estimate calories, or answer the questions below.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var clarifySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Divider()

            ForEach(questions) { question in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(AppSection.foodTracker.color)
                        Text(question.prompt)
                            .font(.subheadline).fontWeight(.semibold)
                    }

                    VStack(spacing: 8) {
                        ForEach(question.options) { option in
                            let isSelected = selections[question.id]?.id == option.id
                            Button {
                                selections[question.id] = option
                            } label: {
                                HStack {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isSelected ? AppSection.foodTracker.color : .secondary)
                                    Text(option.label)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(option.calories) cal")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isSelected
                                              ? AppSection.foodTracker.color.opacity(0.12)
                                              : Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? AppSection.foodTracker.color : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if selections.count == questions.count {
                HStack {
                    Image(systemName: "flame.fill").foregroundColor(.orange)
                    Text("Estimated total: **\(estimatedCalories) cal**")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private var unknownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.secondary)
                Text("\"\(foodName)\" isn't in our database.")
                    .font(.subheadline).foregroundColor(.secondary)
            }

            Text("Enter calories manually (optional)")
                .font(.subheadline).fontWeight(.semibold)

            HStack {
                TextField("0", text: $manualCalText)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .onChange(of: manualCalText) { _, v in
                        manualCalText = v.filter(\.isNumber)
                    }
                Text("cal")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: – Actions

    private func analyzeFood() {
        let name = foodName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        focused = false

        switch CalorieEstimator.shared.estimate(for: name) {

        case .known(let calories, let portion):
            // Save immediately – no questions needed
            onSave(MealItem(name: name, calories: calories, portion: portion))
            dismiss()

        case .needsClarification(let qs):
            questions  = qs
            selections = [:]
            phase      = .clarifying

        case .unknown:
            phase = .unknown
        }
    }

    private func saveItem() {
        let name = foodName.trimmingCharacters(in: .whitespaces)
        switch phase {
        case .idle:
            break

        case .clarifying:
            let cal     = estimatedCalories
            let portion = selectedPortion
            onSave(MealItem(name: name, calories: cal, portion: portion))
            dismiss()

        case .unknown:
            let cal = Int(manualCalText) ?? 0
            onSave(MealItem(name: name, calories: cal, portion: ""))
            dismiss()
        }
    }
}

// MARK: - Edit Meal Item Sheet

struct EditMealItemSheet: View {
    @Environment(\.dismiss) var dismiss

    let item    : MealItem
    let mealName: String
    let onSave  : (MealItem) -> Void

    @State private var nameText   : String
    @State private var portionText: String
    @State private var calText    : String

    init(item: MealItem, mealName: String, onSave: @escaping (MealItem) -> Void) {
        self.item     = item
        self.mealName = mealName
        self.onSave   = onSave
        _nameText    = State(initialValue: item.name)
        _portionText = State(initialValue: item.portion)
        _calText     = State(initialValue: item.calories > 0 ? "\(item.calories)" : "")
    }

    private var canSave: Bool {
        !nameText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Food") {
                    TextField("Food name", text: $nameText)
                        .autocapitalization(.sentences)
                }

                Section("Portion") {
                    TextField("e.g. 1 cup, 2 eggs", text: $portionText)
                        .autocapitalization(.sentences)
                }

                Section("Calories") {
                    HStack {
                        TextField("0", text: $calText)
                            .keyboardType(.numberPad)
                            .onChange(of: calText) { _, v in
                                calText = v.filter(\.isNumber)
                            }
                        Text("cal")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = nameText.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        let cal = Int(calText) ?? item.calories
                        let portion = portionText.trimmingCharacters(in: .whitespaces)
                        var updated = item
                        updated.name = name
                        updated.calories = cal
                        updated.portion = portion
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}
