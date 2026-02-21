import SwiftUI

struct ExpenseTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddExpense = false
    @State private var showSavingsSheet = false
    @State private var addingDeposit = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .expenseTracker,
                              subtitle: "Track spending and savings",
                              completedCount: entry.expenses.count,
                              totalCount: entry.expenses.count)

                // Summary cards
                HStack(spacing: 10) {
                    FinanceSummaryCard(title: "Spent", amount: entry.totalExpenses, color: .red, icon: "arrow.up.circle.fill")
                    FinanceSummaryCard(title: "Saved", amount: entry.totalDeposits, color: .green, icon: "arrow.down.circle.fill")
                    FinanceSummaryCard(title: "Future Fund", amount: entry.savings, color: .blue, icon: "banknote.fill")
                }
                .padding(.horizontal, 16).padding(.top, 12)

                if !vm.isFuture {
                    // Action buttons
                    HStack(spacing: 8) {
                        Button(action: { addingDeposit = false; showAddExpense = true }) {
                            Label("Add Expense", systemImage: "minus.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                        Button(action: { addingDeposit = true; showAddExpense = true }) {
                            Label("Add Saving", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8)

                    Button(action: { showSavingsSheet = true }) {
                        Label("Set Future Fund Target: \(String(format: "$%.2f", entry.savings))",
                              systemImage: "target")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16).padding(.top, 4)
                }

                // Category breakdown
                if !entry.expenses.isEmpty {
                    CategoryBreakdownView(expenses: entry.expenses)
                        .padding(.horizontal, 16).padding(.top, 12)
                }

                // Expense list
                if entry.expenses.isEmpty {
                    EmptySectionView(section: .expenseTracker,
                                     message: "Log your expenses and savings")
                } else {
                    VStack(spacing: 6) {
                        let expenses = entry.expenses.filter { !$0.isDeposit }
                        let deposits = entry.expenses.filter { $0.isDeposit }

                        if !expenses.isEmpty {
                            SectionGroupLabel(title: "Expenses", color: .red)
                            ForEach(expenses) { expense in
                                ExpenseRow(expense: expense) {
                                    if let i = vm.currentEntry.expenses.firstIndex(where: { $0.id == expense.id }) {
                                        vm.deleteExpense(at: IndexSet([i]))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        if !deposits.isEmpty {
                            SectionGroupLabel(title: "Savings", color: .green)
                            ForEach(deposits) { deposit in
                                ExpenseRow(expense: deposit) {
                                    if let i = vm.currentEntry.expenses.firstIndex(where: { $0.id == deposit.id }) {
                                        vm.deleteExpense(at: IndexSet([i]))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(isDeposit: addingDeposit) { expense in
                vm.addExpense(expense)
            }
        }
        .sheet(isPresented: $showSavingsSheet) {
            SavingsTargetSheet(current: entry.savings) { amount in
                vm.updateSavings(amount)
            }
        }
    }
}

// MARK: - Finance Summary Card
struct FinanceSummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(String(format: "$%.2f", amount))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Category Breakdown
struct CategoryBreakdownView: View {
    let expenses: [Expense]

    private var grouped: [(ExpenseCategory, Double)] {
        let spentOnly = expenses.filter { !$0.isDeposit }
        var totals: [ExpenseCategory: Double] = [:]
        for e in spentOnly { totals[e.category, default: 0] += e.amount }
        return totals.sorted { $0.value > $1.value }
    }

    private var totalSpent: Double { grouped.reduce(0) { $0 + $1.1 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spending by Category")
                .font(.system(size: 14, weight: .bold))
            ForEach(grouped, id: \.0) { cat, amount in
                HStack(spacing: 8) {
                    Image(systemName: cat.icon)
                        .font(.system(size: 12))
                        .foregroundColor(cat.color)
                        .frame(width: 20)
                    Text(cat.rawValue).font(.caption)
                    Spacer()
                    ProgressView(value: totalSpent > 0 ? amount / totalSpent : 0)
                        .tint(cat.color)
                        .frame(width: 80)
                    Text(String(format: "$%.2f", amount))
                        .font(.caption).fontWeight(.semibold)
                        .frame(width: 55, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Expense Row
struct ExpenseRow: View {
    let expense: Expense
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: expense.isDeposit ? "arrow.down.circle.fill" : expense.category.icon)
                .font(.system(size: 16))
                .foregroundColor(expense.isDeposit ? .green : expense.category.color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                    .font(.system(size: 13, weight: .medium))
                Text(expense.isDeposit ? "Savings" : expense.category.rawValue)
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "%@$%.2f", expense.isDeposit ? "+" : "-", expense.amount))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(expense.isDeposit ? .green : .red)
            Button(action: onDelete) {
                Image(systemName: "trash").font(.caption).foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - Add Expense Sheet
struct AddExpenseSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var amount = ""
    @State private var description = ""
    @State private var category = ExpenseCategory.other
    let isDeposit: Bool
    let onSave: (Expense) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(isDeposit ? "Savings Details" : "Expense Details") {
                    TextField("Description", text: $description)
                        .autocapitalization(.sentences)
                    HStack {
                        Text("$")
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    if !isDeposit {
                        Picker("Category", selection: $category) {
                            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isDeposit ? "Add Saving" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let amt = Double(amount), amt > 0, !description.isEmpty else { return }
                        onSave(Expense(amount: amt, category: isDeposit ? .other : category,
                                       description: description, isDeposit: isDeposit))
                        dismiss()
                    }
                    .disabled(description.isEmpty || Double(amount) == nil)
                }
            }
        }
    }
}

// MARK: - Savings Target Sheet
struct SavingsTargetSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var amountText: String
    let onSave: (Double) -> Void

    init(current: Double, onSave: @escaping (Double) -> Void) {
        self._amountText = State(initialValue: current > 0 ? String(format: "%.2f", current) : "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Future Fund Amount") {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section {
                    Text("Set aside money for future goals, investments, or emergencies.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Future Fund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let val = Double(amountText) ?? 0
                        onSave(val)
                        dismiss()
                    }
                }
            }
        }
    }
}
