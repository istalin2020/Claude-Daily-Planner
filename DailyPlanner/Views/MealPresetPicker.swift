import SwiftUI

// MARK: - Choose a ready-made dish

/// The "Choose" sheet on each meal: pre-calculated dishes by cuisine. Tap a
/// dish to pick it, set how many, and add several at once.
struct MealPresetPicker: View {
    @Environment(\.dismiss) private var dismiss

    let mealKey: String
    let mealName: String
    let color: Color
    let onAdd: ([MealItem]) -> Void

    @AppStorage("mealPresetCuisine") private var cuisineRaw = MealCuisine.southIndian.rawValue
    @State private var quantities: [String: Int] = [:]
    @State private var search = ""

    private var cuisine: MealCuisine { MealCuisine(rawValue: cuisineRaw) ?? .southIndian }

    private struct Entry: Identifiable {
        let cuisine: MealCuisine
        let preset: MealPreset
        var id: String { cuisine.rawValue + "|" + preset.id }
    }

    /// The dishes on screen: the chosen cuisine, or every cuisine while
    /// searching.
    private var shown: [Entry] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            return MealPresetLibrary.presets(for: mealKey, cuisine: cuisine)
                .map { Entry(cuisine: cuisine, preset: $0) }
        }
        return MealPresetLibrary.allPresets(for: mealKey)
            .map { pair in Entry(cuisine: pair.0, preset: pair.1) }
            .filter { $0.preset.name.lowercased().contains(q) }
    }

    /// Everything picked, across cuisines. A dish listed under two meals or
    /// cuisines is counted once.
    private var picked: [(MealPreset, Int)] {
        var seen = Set<String>()
        var result: [(MealPreset, Int)] = []
        for pair in MealPresetLibrary.allPresets(for: mealKey) {
            let preset = pair.1
            guard let q = quantities[preset.id], q > 0, seen.insert(preset.id).inserted else { continue }
            result.append((preset, q))
        }
        return result
    }

    private var pickedCalories: Int {
        picked.reduce(0) { $0 + Int(($1.0.calories * Double($1.1)).rounded()) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if search.isEmpty { cuisineChips }

                    LazyVStack(spacing: 10) {
                        ForEach(shown) { entry in
                            row(entry.preset, cuisine: entry.cuisine)
                        }
                    }

                    if shown.isEmpty {
                        Text("No ready-made dish matches \"\(search)\". Use + on the meal to look up anything.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    }

                    Text("Figures are per portion shown, from standard nutrition tables — a good everyday guide.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search \(mealName.lowercased()) dishes")
            .safeAreaInset(edge: .bottom) { if !picked.isEmpty { addBar } }
            .navigationTitle("Choose \(mealName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: Cuisine chips

    private var cuisineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MealCuisine.allCases) { c in
                    let on = c == cuisine
                    let count = picked.filter { p in
                        MealPresetLibrary.presets(for: mealKey, cuisine: c).contains(p.0)
                    }.count
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { cuisineRaw = c.rawValue }
                    } label: {
                        HStack(spacing: 5) {
                            Text(c.emoji)
                            Text(c.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .heavy))
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(on ? Color.white.opacity(0.3) : color.opacity(0.2)))
                            }
                        }
                        .foregroundColor(on ? .white : .primary)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(Capsule().fill(on ? color : Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.top, 6)
    }

    // MARK: Row

    private func row(_ preset: MealPreset, cuisine c: MealCuisine) -> some View {
        let qty = quantities[preset.id] ?? 0
        let shownQty = qty > 0 ? qty : preset.defaultQuantity
        let total = Int((preset.calories * Double(shownQty)).rounded())

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Text(search.isEmpty ? preset.portion(shownQty)
                                        : "\(c.emoji) \(c.rawValue) · \(preset.portion(shownQty))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(total)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(qty > 0 ? color : .primary)
                        .contentTransition(.numericText())
                    Text("cal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 6) {
                macro("P", preset.protein * Double(shownQty), .blue)
                macro("C", preset.carbs * Double(shownQty), .green)
                macro("F", preset.fat * Double(shownQty), .pink)
                Spacer()
                if qty > 0 {
                    QuantityStepper(quantity: Binding(
                        get: { quantities[preset.id] ?? 0 },
                        set: { quantities[preset.id] = $0 }
                    ), range: 0...20, color: color)
                } else {
                    Button {
                        withAnimation(.snappy) { quantities[preset.id] = preset.defaultQuantity }
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(color))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(qty > 0 ? color.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }

    private func macro(_ label: String, _ grams: Double, _ tint: Color) -> some View {
        Text("\(label) \(grams < 10 ? String(format: "%.1f", grams) : String(format: "%.0f", grams))g")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.10)))
    }

    // MARK: Add bar

    private var addBar: some View {
        Button {
            onAdd(picked.map { $0.0.item(quantity: $0.1) })
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add \(picked.count) item\(picked.count == 1 ? "" : "s") · \(pickedCalories) cal")
                    .fontWeight(.bold)
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(color))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Quantity stepper

/// A compact − 2 + control. Used in the Choose sheet and beside the dish name
/// in the + sheets.
struct QuantityStepper: View {
    @Binding var quantity: Int
    var range: ClosedRange<Int> = 1...20
    var color: Color = .orange

    var body: some View {
        HStack(spacing: 0) {
            button("minus", enabled: quantity > range.lowerBound) {
                quantity = max(range.lowerBound, quantity - 1)
            }
            Text("\(quantity)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .frame(minWidth: 26)
                .contentTransition(.numericText())
            button("plus", enabled: quantity < range.upperBound) {
                quantity = min(range.upperBound, quantity + 1)
            }
        }
        .padding(.horizontal, 2)
        .background(Capsule().fill(color.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quantity")
        .accessibilityValue("\(quantity)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: quantity = min(range.upperBound, quantity + 1)
            case .decrement: quantity = max(range.lowerBound, quantity - 1)
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? color : .secondary.opacity(0.4))
                .frame(width: 34, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
    }
}
