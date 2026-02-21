import SwiftUI

struct FoodTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var selectedMeal = "breakfast"
    @State private var showCalorieSheet = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .foodTracker,
                              subtitle: "Log your meals and nutrition",
                              completedCount: totalItems,
                              totalCount: totalItems)

                // Calorie banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Calories")
                            .font(.caption).foregroundColor(.secondary)
                        Text(entry.meals.totalCalories > 0 ? "\(entry.meals.totalCalories) cal" : "Not set")
                            .font(.title3).fontWeight(.bold)
                    }
                    Spacer()
                    if !vm.isFuture {
                        Button(action: { showCalorieSheet = true }) {
                            Label("Set Calories", systemImage: "flame.fill")
                                .font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(AppSection.foodTracker.color)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Meal sections
                ForEach(mealSections, id: \.key) { meal in
                    MealSection(
                        meal: meal,
                        items: meal.items(entry),
                        canEdit: !vm.isFuture
                    ) {
                        selectedMeal = meal.key
                        showAddSheet = true
                    } onDelete: { item in
                        vm.removeMealItem(item, from: meal.key)
                    }
                    .padding(.horizontal, 16).padding(.top, 10)
                }

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMealItemSheet(mealName: mealSections.first(where: { $0.key == selectedMeal })?.name ?? "Meal") { item in
                vm.addMealItem(item, to: selectedMeal)
            }
        }
        .sheet(isPresented: $showCalorieSheet) {
            CalorieInputSheet(current: entry.meals.totalCalories) { cal in
                vm.updateCalories(cal)
            }
        }
    }

    private var totalItems: Int {
        entry.meals.breakfastItems.count + entry.meals.lunchItems.count +
        entry.meals.dinnerItems.count + entry.meals.snackItems.count
    }

    private var mealSections: [MealSectionModel] {
        [
            MealSectionModel(key: "breakfast", name: "Breakfast", icon: "sunrise.fill", color: .orange,
                             items: { $0.meals.breakfastItems }),
            MealSectionModel(key: "lunch", name: "Lunch", icon: "sun.max.fill", color: .yellow,
                             items: { $0.meals.lunchItems }),
            MealSectionModel(key: "dinner", name: "Dinner", icon: "moon.fill", color: .indigo,
                             items: { $0.meals.dinnerItems }),
            MealSectionModel(key: "snacks", name: "Snacks", icon: "leaf.fill", color: .green,
                             items: { $0.meals.snackItems })
        ]
    }
}

struct MealSectionModel {
    let key: String
    let name: String
    let icon: String
    let color: Color
    let items: (DailyEntry) -> [String]
}

struct MealSection: View {
    let meal: MealSectionModel
    let items: [String]
    let canEdit: Bool
    let onAdd: () -> Void
    let onDelete: (String) -> Void

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
                if canEdit {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(meal.color)
                            .font(.system(size: 22))
                    }
                }
            }

            if items.isEmpty {
                Text("Nothing logged yet")
                    .font(.caption).foregroundColor(.secondary).italic()
                    .padding(.leading, 4)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Circle()
                            .fill(meal.color.opacity(0.6))
                            .frame(width: 6, height: 6)
                        Text(item)
                            .font(.subheadline)
                        Spacer()
                        if canEdit {
                            Button(action: { onDelete(item) }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                    }
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
struct AddMealItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var item = ""
    let mealName: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Add to \(mealName)") {
                    TextField("e.g. Oatmeal with berries", text: $item)
                        .autocapitalization(.sentences)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !item.isEmpty else { return }
                        onSave(item)
                        dismiss()
                    }
                    .disabled(item.isEmpty)
                }
            }
        }
    }
}

// MARK: - Calorie Input Sheet
struct CalorieInputSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var calories: Int
    let onSave: (Int) -> Void

    init(current: Int, onSave: @escaping (Int) -> Void) {
        self._calories = State(initialValue: current == 0 ? 2000 : current)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Total Calories") {
                    Stepper("\(calories) calories", value: $calories, in: 0...5000, step: 50)
                    HStack {
                        ForEach([1500, 2000, 2500, 3000], id: \.self) { c in
                            Button("\(c)") { calories = c }
                                .font(.caption).fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(calories == c ? AppSection.foodTracker.color : Color(.secondarySystemBackground))
                                .foregroundColor(calories == c ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("Daily Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(calories); dismiss() }
                }
            }
        }
    }
}
