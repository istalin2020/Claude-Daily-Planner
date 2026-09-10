import SwiftUI

// MARK: - Food Tracker

struct FoodTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @State private var showAddSheet  = false
    @State private var selectedMeal  = "breakfast"
    @State private var editingItem: MealItem? = nil
    @State private var editingMealKey: String = ""
    @State private var showCamera = false
    /// Holds the shot between camera dismissal and the review sheet opening.
    @State private var pendingPhoto: UIImage? = nil
    /// Photo headed for the PRO cloud analysis sheet.
    @State private var capturedPhoto: CapturedFoodPhoto? = nil
    /// Photo headed for the on-device sheet — the free-tier path, and where
    /// the PRO sheet hands off when the service can't be reached.
    @State private var manualPhoto: CapturedFoodPhoto? = nil
    /// Set by the PRO sheet just before it dismisses, so its `onDismiss` can
    /// reopen the on-device sheet with the same shot instead of losing it.
    @State private var fallbackImage: UIImage? = nil

    /// PRO users get cloud analysis unless they've switched it off, or the
    /// build has no service configured.
    private var usesSmartAnalysis: Bool {
        pro.isPro && vm.settings.cloudFoodAnalysisEnabled && CloudFoodAnalyzer.isConfigured
    }

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Calorie banner + nutrients (auto-calculated) ────────────
                CalorieBanner(total: entry.meals.totalCalories)
                    .padding(.horizontal, 16).padding(.top, 8)

                if entry.meals.totalCalories > 0 {
                    NutrientSummaryRow(protein: entry.meals.totalProtein,
                                       fiber:   entry.meals.totalFiber,
                                       iron:    entry.meals.totalIron)
                        .padding(.horizontal, 16).padding(.top, 8)
                }

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
                    } onCamera: {
                        selectedMeal = meal.key
                        showCamera = true
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
        // The camera is dismissed FIRST; the review sheet is only presented
        // afterwards, from onDismiss. Presenting it while the cover was still
        // up crashed the app.
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if let image = pendingPhoto {
                pendingPhoto = nil
                if usesSmartAnalysis {
                    capturedPhoto = CapturedFoodPhoto(image: image)
                } else {
                    manualPhoto = CapturedFoodPhoto(image: image)
                }
            }
        }) {
            FoodCameraPicker { image in
                pendingPhoto = image
                showCamera = false
            }
            .ignoresSafeArea()
        }
        // PRO: full cloud analysis. If it can't run, it stashes the photo and
        // dismisses; onDismiss then opens the on-device sheet with the same shot.
        .sheet(item: $capturedPhoto, onDismiss: {
            if let image = fallbackImage {
                fallbackImage = nil
                manualPhoto = CapturedFoodPhoto(image: image)
            }
        }) { shot in
            let mealName = mealSections.first(where: { $0.key == selectedMeal })?.name ?? "Meal"
            SmartFoodPhotoSheet(photo: shot.image, mealName: mealName) { items in
                for item in items { vm.addMealItem(item, to: selectedMeal) }
            } onFallback: {
                fallbackImage = shot.image
            }
        }
        // Free tier, and the PRO fallback: everything stays on the device.
        .sheet(item: $manualPhoto) { shot in
            let mealName = mealSections.first(where: { $0.key == selectedMeal })?.name ?? "Meal"
            PhotoMealSheet(photo: shot.image, mealName: mealName) { item in
                vm.addMealItem(item, to: selectedMeal)
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

/// A read-only summary strip. Styled as a tinted capsule with a caption
/// label and a big number so it clearly reads as an output, never as a
/// text field waiting for input.
private struct CalorieBanner: View {
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(CGFloat(total) / 2000.0, 1.0))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "flame.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.orange)
            }
            .frame(width: 44, height: 44)
            .animation(.easeOut, value: total)

            VStack(alignment: .leading, spacing: 1) {
                Text("TODAY'S TOTAL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(total)")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.primary)
                    Text("cal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("auto-calculated")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Color.orange.opacity(0.10))
        )
        .overlay(
            Capsule().strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .allowsHitTesting(false)   // purely informational
    }
}

// MARK: - Nutrient Summary Row

/// Read-only strip showing the day's estimated protein, fibre and iron,
/// derived from the foods logged above.
private struct NutrientSummaryRow: View {
    let protein: Double
    let fiber: Double
    let iron: Double

    var body: some View {
        HStack(spacing: 8) {
            NutrientPill(icon: "bolt.heart.fill", label: "Protein",
                         value: format(protein), unit: "g",
                         color: Color(red: 0.85, green: 0.30, blue: 0.45))
            NutrientPill(icon: "leaf.fill", label: "Fiber",
                         value: format(fiber), unit: "g",
                         color: Color(red: 0.15, green: 0.65, blue: 0.40))
            NutrientPill(icon: "drop.triangle.fill", label: "Iron",
                         value: format(iron), unit: "mg",
                         color: Color(red: 0.35, green: 0.45, blue: 0.85))
        }
        .allowsHitTesting(false)   // purely informational
    }

    private func format(_ v: Double) -> String {
        v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

private struct NutrientPill: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(color)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    var onCamera: (() -> Void)? = nil

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
                    // Add manually, or snap a photo of the food
                    VStack(spacing: 6) {
                        Button(action: onAdd) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(meal.color)
                                .font(.system(size: 22))
                        }
                        if let onCamera = onCamera {
                            Button(action: onCamera) {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(meal.color)
                                    .font(.system(size: 16))
                                    .padding(4)
                                    .background(meal.color.opacity(0.14))
                                    .clipShape(Circle())
                            }
                        }
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
                            // Edit button — padded so the tap target is big
                            // enough to hit reliably (icon alone is only 16pt).
                            Button(action: { onEdit(item) }) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(meal.color.opacity(0.8))
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Delete button
                            Button(action: { onDelete(item) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 15))
                                    .foregroundColor(.red.opacity(0.75))
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
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

// MARK: - Captured photo wrapper
/// UIImage isn't Identifiable, so wrap it for `.sheet(item:)`.
struct CapturedFoodPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Camera Picker
/// Thin UIKit bridge that opens the camera and hands the captured photo back
/// through `onFinish` (nil when the user cancels).
///
/// The picker never dismisses itself and never presents anything: the parent
/// owns the presentation state. Trying to present the review sheet from here —
/// while this cover was still on screen — is what previously crashed the app.
struct FoodCameraPicker: UIViewControllerRepresentable {
    /// Called once with the photo, or nil if cancelled.
    var onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: FoodCameraPicker
        /// Guards against the delegate firing twice.
        private var finished = false

        init(_ parent: FoodCameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard !finished else { return }
            finished = true
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            parent.onFinish(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard !finished else { return }
            finished = true
            parent.onFinish(nil)
        }
    }
}

// MARK: - Photo Meal Sheet
/// Shown after a food photo is taken. The photo is a visual reference; the
/// user names the dish (or picks a suggestion) and the calorie estimator's
/// follow-up questions pin down the calories.
struct PhotoMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    let photo: UIImage
    let mealName: String
    let onSave: (MealItem) -> Void

    @State private var foodName = ""
    @State private var result: EstimationResult? = nil
    @State private var chosenCalories: Int? = nil
    @State private var manualCalories = ""
    @State private var isDetecting = true
    @State private var detection: FoodDetection? = nil
    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        !foodName.trimmingCharacters(in: .whitespaces).isEmpty && resolvedCalories > 0
    }

    private var knownPortion: String {
        if case .known(_, let portion) = result { return portion }
        return ""
    }

    private var resolvedCalories: Int {
        if let chosen = chosenCalories { return chosen }
        if case .known(let cal, _) = result { return cal }
        return Int(manualCalories) ?? 0
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // ── Detection status ──────────────────────────────
                    if isDetecting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Identifying your food…")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    } else if let d = detection {
                        // Be honest about certainty: a 5% classifier score is a
                        // guess, not a detection, so say so and lead the user
                        // to the alternatives or the text field.
                        HStack(spacing: 10) {
                            Image(systemName: d.fromLabelText ? "text.viewfinder"
                                                              : (d.isConfident ? "sparkles" : "questionmark.circle"))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.fromLabelText
                                     ? "Read from label: \(d.foodName.capitalized)"
                                     : (d.isConfident
                                        ? "Detected: \(d.foodName.capitalized)"
                                        : "Best guess: \(d.foodName.capitalized)"))
                                    .font(.system(size: 15, weight: .bold))
                                Text(d.fromLabelText
                                     ? "Found the name printed on the item"
                                     : (d.isConfident
                                        ? "\(Int(d.confidence * 100))% match · tap below to change"
                                        : "Not certain — pick below or type the name"))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.10))
                        .cornerRadius(12)

                        // Other possibilities the classifier saw
                        if !d.alternatives.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(d.alternatives, id: \.self) { alt in
                                        Button {
                                            foodName = alt
                                            runEstimate()
                                        } label: {
                                            Text(alt.capitalized)
                                                .font(.system(size: 13, weight: .medium))
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(Color(.secondarySystemBackground))
                                                .foregroundColor(.primary)
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Couldn't identify it automatically — type the food name below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(detection == nil ? "What's in the photo?" : "Food name")
                        .font(.system(size: 17, weight: .bold))

                    HStack(spacing: 8) {
                        TextField("e.g. Grilled chicken salad", text: $foodName)
                            .focused($nameFocused)
                            .submitLabel(.search)
                            .onSubmit { runEstimate() }
                            .padding(.horizontal, 12).padding(.vertical, 11)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.orange.opacity(0.45), lineWidth: 1.3))

                        Button(action: runEstimate) {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .padding(9)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }

                    Text("Recognized on your device — nothing is uploaded. Adjust the name or portion if it's not quite right.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Follow-up questions / result from the estimator
                    switch result {
                    case .known(let cal, let portion):
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill").foregroundColor(.orange)
                            Text("\(cal) cal")
                                .font(.system(size: 18, weight: .bold))
                            if !portion.isEmpty {
                                Text("· \(portion)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)

                    case .needsClarification(let questions):
                        ForEach(questions) { q in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(q.prompt)
                                    .font(.system(size: 15, weight: .semibold))
                                ForEach(q.options) { opt in
                                    Button {
                                        chosenCalories = opt.calories
                                    } label: {
                                        HStack {
                                            Image(systemName: chosenCalories == opt.calories
                                                  ? "largecircle.fill.circle" : "circle")
                                                .foregroundColor(chosenCalories == opt.calories ? .orange : .secondary)
                                            Text(opt.label)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("\(opt.calories) cal")
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        .padding(12)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }

                    case .unknown:
                        VStack(alignment: .leading, spacing: 6) {
                            Text("We don't know this one yet — enter the calories:")
                                .font(.system(size: 14, weight: .semibold))
                            HStack {
                                TextField("e.g. 250", text: $manualCalories)
                                    .keyboardType(.numberPad)
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                Text("cal").foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)

                    case .none:
                        EmptyView()
                    }

                    Spacer(minLength: 20)
                }
                .padding(16)
            }
            .navigationTitle("Add to \(mealName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = foodName.trimmingCharacters(in: .whitespaces)
                        onSave(MealItem(name: name,
                                        calories: resolvedCalories,
                                        portion: knownPortion))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear { runDetection() }
        }
    }

    /// Classifies the photo on device, then immediately estimates calories
    /// for whatever was recognized.
    private func runDetection() {
        isDetecting = true
        FoodPhotoRecognizer.detectFood(in: photo) { found in
            isDetecting = false
            detection = found
            if let found = found {
                foodName = found.foodName
                runEstimate()
            } else {
                nameFocused = true
            }
        }
    }

    private func runEstimate() {
        let name = foodName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        chosenCalories = nil
        nameFocused = false
        result = CalorieEstimator.shared.estimate(for: name)
    }
}
