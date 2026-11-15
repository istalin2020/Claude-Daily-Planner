import SwiftUI

struct BudgetSettingsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var budgetTexts: [ExpenseCategory: String] = [:]
    private var sym: String { vm.settings.currency.symbol }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Set monthly spending limits per category. You'll see a warning when you approach or exceed your budget.")
                        .font(.caption).foregroundColor(.secondary)
                }
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    let spent = vm.monthlySpent(for: cat, date: Date())
                    let budget = vm.budget(for: cat)
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(cat.color.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(cat.color)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cat.rawValue).font(.system(size: 13, weight: .medium))
                                Text("Spent: \(sym)\(String(format: "%.2f", spent))")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 2) {
                                Text(sym).foregroundColor(.secondary).font(.caption)
                                TextField("No limit", text: Binding(
                                    get: { budgetTexts[cat] ?? (budget.map { String(format: "%.0f", $0) } ?? "") },
                                    set: { budgetTexts[cat] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)
                            }
                        }
                        if let bud = budget, bud > 0 {
                            let pct = min(spent / bud, 1.0)
                            ProgressView(value: pct)
                                .tint(pct > 0.9 ? .red : pct > 0.7 ? .orange : cat.color)
                            Text("\(sym)\(String(format: "%.2f", spent)) / \(sym)\(String(format: "%.2f", bud)) (\(Int(pct*100))%)")
                                .font(.system(size: 10)).foregroundColor(pct > 0.9 ? .red : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Category Budgets")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        for cat in ExpenseCategory.allCases {
                            let txt = budgetTexts[cat] ?? ""
                            vm.setBudget(Double(txt), for: cat)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
