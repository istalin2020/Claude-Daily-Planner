import SwiftUI
import Charts

// MARK: - Main View

struct ExpenseTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @State private var showAddSheet     = false
    @State private var addMode: AddMode = .expense
    @State private var summaryMonthOffset = 0
    @State private var showBudgets = false
    @State private var showProUpgrade = false
    @State private var showSpendingTrends = false
    @State private var deleteConfirmItem: Expense? = nil
    @State private var showSMSPasteSheet = false

    var entry: DailyEntry { vm.currentEntry }
    private var sym: String { vm.settings.currency.symbol }

    // Reference month for monthly summary (can navigate independently)
    private var summaryDate: Date {
        Calendar.current.date(byAdding: .month, value: summaryMonthOffset, to: vm.selectedDate) ?? vm.selectedDate
    }
    private var summaryMonthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: summaryDate)
    }

    // True when summaryDate is the same month/year as the calendar's selected date
    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        let a = cal.dateComponents([.year, .month], from: summaryDate)
        let b = cal.dateComponents([.year, .month], from: vm.selectedDate)
        return a.year == b.year && a.month == b.month
    }

    enum AddMode { case income, expense, savings }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .expenseTracker,
                              subtitle: "Track income, spending & savings",
                              completedCount: entry.expenses.count,
                              totalCount: entry.expenses.count)

                // ── Monthly Snapshot Cards ─────────────────────────────
                monthlySnapshotSection
                    .padding(.top, 12)

                // ── Quick Add Buttons ──────────────────────────────────
                if !vm.isFuture {
                    quickAddButtons
                        .padding(.top, 10)
                }

                // ── Monthly Summary Card ───────────────────────────────
                monthlySummaryCard
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                // ── Expense Pie Chart ─────────────────────────────────
                categoryPieChartSection
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // ── SMS Clipboard Banner ──────────────────────────────
                if let parsed = vm.pendingSMSTransaction {
                    SMSClipboardBanner(parsed: parsed, sym: sym) {
                        vm.addExpenseFromSMS(parsed)
                    } onDismiss: {
                        vm.dismissSMSHash(parsed.rawText)
                        vm.pendingSMSTransaction = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // ── Budget Alerts ──────────────────────────────────────
                let alerts = budgetAlerts()
                if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("Budget Alerts").font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        ForEach(alerts, id: \.category.rawValue) { alert in
                            BudgetAlertRow(alert: alert, sym: sym)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                }

                Button {
                    if pro.isPro { showBudgets = true } else { showProUpgrade = true }
                } label: {
                    HStack(spacing: 6) {
                        Label("Manage Budgets", systemImage: "chart.bar.fill")
                            .font(.system(size: 13, weight: .semibold))
                        if !pro.isPro { ProInlineBadge() }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1)).foregroundColor(.orange).cornerRadius(12)
                }
                .padding(.horizontal, 16).padding(.top, 8)
                .sheet(isPresented: $showProUpgrade) {
                    ProUpgradeView().environmentObject(pro)
                }

                // ── Spending Trends (PRO) ──────────────────────────────
                Button {
                    if pro.isPro { showSpendingTrends = true } else { showProUpgrade = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Spending Trends")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if !pro.isPro { ProInlineBadge() }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 14)
                    .background(Color(red: 0.1, green: 0.65, blue: 0.35).opacity(0.1))
                    .foregroundColor(Color(red: 0.1, green: 0.65, blue: 0.35))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16).padding(.top, 8)

                // ── Today's Transactions ───────────────────────────────
                todayTransactionsList
                    .padding(.top, 16)

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showSpendingTrends) {
            SpendingTrendsView().environmentObject(vm)
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionSheet(mode: addMode, currencySymbol: sym) { transaction in
                vm.addExpense(transaction)
            }
            .environmentObject(vm)
        }
        .sheet(isPresented: $showBudgets) {
            BudgetSettingsView().environmentObject(vm)
        }
        .sheet(isPresented: $showSMSPasteSheet) {
            SMSPasteSheet(sym: sym) { expense in
                vm.addExpense(expense)
            }
            .environmentObject(vm)
        }
        .alert("Delete Transaction", isPresented: Binding(
            get: { deleteConfirmItem != nil },
            set: { if !$0 { deleteConfirmItem = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let item = deleteConfirmItem {
                    vm.deleteExpense(byID: item.id)
                }
                deleteConfirmItem = nil
            }
            Button("Cancel", role: .cancel) { deleteConfirmItem = nil }
        } message: {
            if let item = deleteConfirmItem {
                Text("Delete \"\(item.description)\" (\(item.isIncome ? "+" : item.isDeposit ? "+" : "-")\(sym)\(String(format: "%.2f", item.amount)))?")
            }
        }
    }

    // MARK: - Category Pie Chart

    private var categoryPieChartSection: some View {
        let categories = vm.monthlyExpensesByCategory(for: summaryDate)
        let total = categories.reduce(0.0) { $0 + $1.1 }

        return Group {
            if total > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expense Breakdown")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.leading, 4)

                    Chart(categories, id: \.0) { cat, amount in
                        SectorMark(
                            angle: .value(cat.rawValue, amount),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(cat.color)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)

                    VStack(spacing: 6) {
                        ForEach(categories.sorted(by: { $0.1 > $1.1 }), id: \.0) { cat, amount in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(cat.color)
                                    .frame(width: 10, height: 10)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(cat.color)
                                    .frame(width: 16)
                                Text(cat.rawValue.capitalized)
                                    .font(.system(size: 12))
                                Spacer()
                                Text("\(sym)\(String(format: "%.2f", amount))")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("(\(Int(amount / total * 100))%)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
    }

    private func budgetAlerts() -> [BudgetAlert] {
        ExpenseCategory.allCases.compactMap { cat in
            guard let budget = vm.budget(for: cat), budget > 0 else { return nil }
            let spent = vm.monthlySpent(for: cat, date: vm.selectedDate)
            guard spent / budget >= 0.8 else { return nil }
            return BudgetAlert(category: cat, spent: spent, budget: budget)
        }
    }

    // MARK: - Today's Snapshot Cards

    private var todayIncome: Double {
        entry.expenses.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    private var todayExpenses: Double {
        entry.expenses.filter { !$0.isDeposit && !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    private var todaySavings: Double {
        entry.expenses.filter { $0.isDeposit }.reduce(0) { $0 + $1.amount }
    }

    private var monthlySnapshotSection: some View {
        HStack(spacing: 10) {
            TodayFinanceCard(
                title: "Today's\nIncome",
                amount: todayIncome,
                icon: "arrow.down.circle.fill",
                gradient: [Color(red: 0.1, green: 0.75, blue: 0.4), Color(red: 0.0, green: 0.55, blue: 0.3)],
                sym: sym
            )
            TodayFinanceCard(
                title: "Today's\nExpenses",
                amount: todayExpenses,
                icon: "arrow.up.circle.fill",
                gradient: [Color(red: 0.95, green: 0.35, blue: 0.3), Color(red: 0.8, green: 0.15, blue: 0.15)],
                sym: sym
            )
            TodayFinanceCard(
                title: "Today's\nSavings",
                amount: todaySavings,
                icon: "banknote.fill",
                gradient: [Color(red: 0.3, green: 0.5, blue: 0.95), Color(red: 0.15, green: 0.3, blue: 0.8)],
                sym: sym
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Quick Add Buttons

    private var quickAddButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                FinanceAddButton(label: "Add Income", icon: "plus.circle.fill",
                                 bg: Color(red: 0.1, green: 0.75, blue: 0.4).opacity(0.12),
                                 fg: Color(red: 0.1, green: 0.65, blue: 0.35)) {
                    addMode = .income; showAddSheet = true
                }
                FinanceAddButton(label: "Add Expense", icon: "minus.circle.fill",
                                 bg: Color.red.opacity(0.1), fg: .red) {
                    addMode = .expense; showAddSheet = true
                }
            }
            .padding(.horizontal, 16)

            FinanceAddButton(
                label: "Add Saving  \(sym)\(String(format: "%.2f", vm.monthlyTotalSavings(for: vm.selectedDate)))",
                icon: "banknote.fill",
                bg: Color(red: 0.3, green: 0.5, blue: 0.95).opacity(0.1),
                fg: Color(red: 0.3, green: 0.5, blue: 0.95)) {
                addMode = .savings; showAddSheet = true
            }
            .padding(.horizontal, 16)

            if pro.isPro && vm.settings.smartBankSMSEnabled {
                FinanceAddButton(
                    label: "Paste Bank SMS",
                    icon: "doc.on.clipboard.fill",
                    bg: Color.purple.opacity(0.1),
                    fg: .purple) {
                    showSMSPasteSheet = true
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Monthly Summary Card

    private var monthlySummaryCard: some View {
        let totalIncome   = vm.monthlyTotalIncome(for: summaryDate)
        let totalExpenses = vm.monthlyTotalExpenses(for: summaryDate)
        let totalSavings  = vm.monthlyTotalSavings(for: summaryDate)
        // Balance = Income − Expenses (savings are tracked separately and NOT deducted from balance)
        let balance       = vm.monthlyBalance(for: summaryDate)
        let categories    = vm.monthlyExpensesByCategory(for: summaryDate)
        let barRatio: Double = totalIncome > 0 ? min(totalExpenses / totalIncome, 1.0) : 0

        return VStack(alignment: .leading, spacing: 0) {

            // Header with month navigation
            HStack {
                Button { summaryMonthOffset -= 1 } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(summaryMonthLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Monthly Overview")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button { summaryMonthOffset += 1 } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Income/Expense progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red.opacity(0.5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.1, green: 0.85, blue: 0.5))
                        .frame(width: geo.size.width * (1 - barRatio), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // ── Income rows ──
            VStack(spacing: 0) {
                SummaryRow(
                    label: "Income",
                    amount: totalIncome,
                    sym: sym,
                    color: Color(red: 0.1, green: 0.85, blue: 0.5),
                    isHeader: true
                )
                .padding(.horizontal, 16)

                if !categories.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                // Category-wise expense rows
                ForEach(categories, id: \.0) { cat, amount in
                    HStack(spacing: 10) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 12))
                            .foregroundColor(cat.color)
                            .frame(width: 20)
                        Text(cat.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("-\(sym)\(String(format: "%.2f", amount))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.red.opacity(0.9))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                if totalExpenses > 0 {
                    SummaryRow(
                        label: "Expense",
                        amount: totalExpenses,
                        sym: sym,
                        color: Color.red.opacity(0.85),
                        isHeader: true
                    )
                    .padding(.horizontal, 16)
                }

                // Savings row in monthly summary
                if totalSavings > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)

                    SummaryRow(
                        label: "Savings",
                        amount: totalSavings,
                        sym: sym,
                        color: Color(red: 0.3, green: 0.5, blue: 0.95),
                        isHeader: false
                    )
                    .padding(.horizontal, 16)
                }

                // Dashed divider
                DashedDivider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                // Balance (Income − Expenses only; savings are separate)
                HStack {
                    Text("Balance")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(balance >= 0 ? "+" : "")\(sym)\(String(format: "%.2f", balance))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(balance >= 0
                            ? Color(red: 0.1, green: 0.85, blue: 0.5)
                            : Color.red.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.12, blue: 0.18), Color(red: 0.05, green: 0.07, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }

    // MARK: - Today's Transactions List

    private var todayTransactionsList: some View {
        let incomes   = entry.expenses.filter { $0.isIncome }
        let expenses  = entry.expenses.filter { !$0.isDeposit && !$0.isIncome }
        let savings   = entry.expenses.filter { $0.isDeposit }
        let isEmpty   = entry.expenses.isEmpty

        return Group {
            if isEmpty {
                EmptySectionView(section: .expenseTracker,
                                 message: "Tap a button above to log income or expenses")
            } else {
                VStack(spacing: 6) {
                    if !incomes.isEmpty {
                        SectionGroupLabel(title: "Income", color: Color(red: 0.1, green: 0.65, blue: 0.35))
                        ForEach(incomes) { item in
                            TransactionRow(expense: item, sym: sym) {
                                deleteConfirmItem = item
                            }
                            .padding(.horizontal, 16)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    vm.deleteExpense(byID: item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    if !expenses.isEmpty {
                        SectionGroupLabel(title: "Expenses", color: .red)
                        ForEach(expenses) { item in
                            TransactionRow(expense: item, sym: sym) {
                                deleteConfirmItem = item
                            }
                            .padding(.horizontal, 16)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    vm.deleteExpense(byID: item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    if !savings.isEmpty {
                        SectionGroupLabel(title: "Savings", color: Color(red: 0.3, green: 0.5, blue: 0.95))
                        ForEach(savings) { item in
                            TransactionRow(expense: item, sym: sym) {
                                deleteConfirmItem = item
                            }
                            .padding(.horizontal, 16)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    vm.deleteExpense(byID: item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Today Finance Card

struct TodayFinanceCard: View {
    let title: String
    let amount: Double
    let icon: String
    let gradient: [Color]
    let sym: String

    @State private var appear = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text("\(sym)\(String(format: "%.2f", amount))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .shadow(color: gradient[0].opacity(0.4), radius: 8, y: 3)
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { appear = true }
        }
    }
}

// MARK: - Add Button

struct FinanceAddButton: View {
    let label: String
    let icon: String
    let bg: Color
    let fg: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(bg)
                .foregroundColor(fg)
                .cornerRadius(12)
        }
    }
}

// MARK: - Summary Row (Monthly overview)

struct SummaryRow: View {
    let label: String
    let amount: Double
    let sym: String
    let color: Color
    let isHeader: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: isHeader ? 15 : 13, weight: isHeader ? .bold : .regular))
                .foregroundColor(isHeader ? .white : .white.opacity(0.75))
            Spacer()
            Text("\(sym)\(String(format: "%.2f", amount))")
                .font(.system(size: isHeader ? 15 : 13, weight: isHeader ? .bold : .semibold))
                .foregroundColor(color)
        }
        .padding(.vertical, isHeader ? 8 : 5)
    }
}

// MARK: - Dashed Divider

struct DashedDivider: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .init(x: 0, y: 0))
                path.addLine(to: .init(x: geo.size.width, y: 0))
            }
            .stroke(Color.white.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
        .frame(height: 1)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let expense: Expense
    let sym: String
    let onDelete: () -> Void

    private var rowColor: Color {
        if expense.isIncome   { return Color(red: 0.1, green: 0.65, blue: 0.35) }
        if expense.isDeposit  { return Color(red: 0.3, green: 0.5, blue: 0.95) }
        return .red
    }

    private var rowIcon: String {
        if expense.isIncome  { return "arrow.down.circle.fill" }
        if expense.isDeposit { return "banknote.fill" }
        if !expense.customCategoryLabel.isEmpty { return "tag.fill" }
        return expense.category.icon
    }

    private var sign: String {
        expense.isIncome || expense.isDeposit ? "+" : "-"
    }

    private var typeLabel: String {
        if expense.isIncome  { return "Income" }
        if expense.isDeposit { return "Savings" }
        return expense.displayCategory
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(rowColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: rowIcon)
                    .font(.system(size: 15))
                    .foregroundColor(rowColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(expense.description)
                        .font(.system(size: 13, weight: .medium))
                    if expense.isFromSMS {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.purple.opacity(0.7))
                    }
                }
                Text(typeLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(sign)\(sym)\(String(format: "%.2f", expense.amount))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(rowColor)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - Add Transaction Sheet

struct AddTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: PlannerViewModel
    @State private var amount              = ""
    @State private var description         = ""
    @State private var category            = ExpenseCategory.other
    @State private var customCategoryLabel = ""
    @State private var isCustomCategory    = false
    @State private var showAddCategory     = false
    @State private var newCategoryName     = ""
    @FocusState private var amountFocused: Bool

    let mode: ExpenseTrackerView.AddMode
    let currencySymbol: String
    let onSave: (Expense) -> Void

    private var title: String {
        switch mode {
        case .income:  return "Add Income"
        case .expense: return "Add Expense"
        case .savings: return "Add Saving"
        }
    }

    private var accentColor: Color {
        switch mode {
        case .income:  return Color(red: 0.1, green: 0.65, blue: 0.35)
        case .expense: return .red
        case .savings: return Color(red: 0.3, green: 0.5, blue: 0.95)
        }
    }

    private var iconName: String {
        switch mode {
        case .income:  return "arrow.down.circle.fill"
        case .expense: return "minus.circle.fill"
        case .savings: return "banknote.fill"
        }
    }

    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amount) != nil &&
        (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Colorful header banner
                VStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(
                    LinearGradient(colors: [accentColor, accentColor.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

                Form {
                    Section("Details") {
                        HStack(spacing: 8) {
                            Image(systemName: iconName)
                                .foregroundColor(accentColor)
                                .frame(width: 24)
                            TextField(mode == .income ? "Source (e.g. Salary, Freelance)" : "Description",
                                      text: $description)
                                .autocapitalization(.sentences)
                        }

                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            Text(currencySymbol)
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .focused($amountFocused)
                            // Clear button — lets the user wipe a mis-typed value
                            if !amount.isEmpty {
                                Button {
                                    amount = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        if mode == .expense {
                            // ── Category picker with custom support ──────────────
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Picker("Category", selection: Binding(
                                    get: { isCustomCategory ? "custom:\(customCategoryLabel)" : category.rawValue },
                                    set: { newVal in
                                        if newVal.hasPrefix("custom:") {
                                            isCustomCategory = true
                                            customCategoryLabel = String(newVal.dropFirst(7))
                                        } else {
                                            isCustomCategory = false
                                            customCategoryLabel = ""
                                            category = ExpenseCategory(rawValue: newVal) ?? .other
                                        }
                                    }
                                )) {
                                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                        Label(cat.rawValue, systemImage: cat.icon).tag(cat.rawValue)
                                    }
                                    if !vm.settings.customExpenseCategories.isEmpty {
                                        Divider()
                                        ForEach(vm.settings.customExpenseCategories, id: \.self) { name in
                                            Label(name, systemImage: "tag.fill")
                                                .tag("custom:\(name)")
                                        }
                                    }
                                }
                                .pickerStyle(.menu)

                                Button(action: { showAddCategory = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(accentColor)
                                        Text("Add Category")
                                            .font(.subheadline)
                                            .foregroundColor(accentColor)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }
                    }

                    Section {
                        Button {
                            guard canSave, let amt = Double(amount) else { return }
                            let expense = Expense(
                                amount: amt,
                                category: mode == .expense ? (isCustomCategory ? .other : category) : .other,
                                customCategoryLabel: mode == .expense && isCustomCategory ? customCategoryLabel : "",
                                description: description.trimmingCharacters(in: .whitespaces),
                                isDeposit: mode == .savings,
                                isIncome:  mode == .income
                            )
                            onSave(expense)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save \(title)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(canSave ? accentColor : Color.secondary.opacity(0.3))
                        .disabled(!canSave)
                    }
                }
                // Keyboard toolbar with Done and Clear buttons for decimal pad
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Clear") {
                            amount = ""
                        }
                        .foregroundColor(.secondary)
                        Button("Done") {
                            amountFocused = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Add Category", isPresented: $showAddCategory) {
                TextField("Category name", text: $newCategoryName)
                    .autocapitalization(.words)
                Button("Add") {
                    let name = newCategoryName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty && !vm.settings.customExpenseCategories.contains(name) {
                        vm.settings.customExpenseCategories.append(name)
                        vm.saveSettings()
                        isCustomCategory = true
                        customCategoryLabel = name
                    }
                    newCategoryName = ""
                }
                Button("Cancel", role: .cancel) { newCategoryName = "" }
            } message: {
                Text("Enter a name for your new category.")
            }
        }
    }
}

// MARK: - Budget Alert

struct BudgetAlert {
    let category: ExpenseCategory
    let spent: Double
    let budget: Double
    var percent: Double { spent / budget }
}

struct BudgetAlertRow: View {
    let alert: BudgetAlert
    let sym: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: alert.category.icon)
                .font(.system(size: 13)).foregroundColor(alert.category.color).frame(width: 20)
            Text(alert.category.rawValue).font(.system(size: 12))
            Spacer()
            ProgressView(value: alert.percent)
                .tint(alert.percent >= 1.0 ? .red : .orange).frame(width: 60)
            Text("\(Int(alert.percent * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(alert.percent >= 1.0 ? .red : .orange)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - Finance Summary Card (kept for backward compat in Overview)

struct FinanceSummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    let currencySymbol: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text("\(currencySymbol)\(String(format: "%.2f", amount))")
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

// MARK: - SMS Clipboard Banner

struct SMSClipboardBanner: View {
    let parsed: ParsedTransaction
    let sym: String
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bank SMS Detected")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(parsed.isCredit ? "Credit" : "Debit") of \(sym)\(String(format: "%.2f", parsed.amount))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if !parsed.merchant.isEmpty {
                        Text(parsed.merchant)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                }
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                        Text(parsed.isCredit ? "Add Income" : "Add Expense")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(parsed.isCredit ? Color(red: 0.1, green: 0.65, blue: 0.35) : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.purple.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

// MARK: - SMS Paste Sheet

struct SMSPasteSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: PlannerViewModel
    @State private var smsText = ""
    @State private var parsed: ParsedTransaction? = nil
    @State private var parseError = false
    let sym: String
    let onSave: (Expense) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text("Import Bank SMS")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Paste a bank transaction SMS below")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(colors: [.purple, .purple.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

                if let parsed = parsed {
                    parsedResultView(parsed)
                        .padding(16)
                } else {
                    VStack(spacing: 12) {
                        TextEditor(text: $smsText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                Group {
                                    if smsText.isEmpty {
                                        Text("Paste your bank SMS here...\n\nExample: Rs.500.00 debited from A/c XX1234 at SWIGGY. Avl Bal: Rs.25,000.00")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary.opacity(0.6))
                                            .padding(16)
                                            .allowsHitTesting(false)
                                    }
                                }, alignment: .topLeading
                            )

                        if parseError {
                            Text("Could not detect a bank transaction. Please paste a valid bank SMS.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            if let result = BankSMSParser.parse(smsText) {
                                parsed = result
                                parseError = false
                            } else {
                                parseError = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Parse SMS")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(smsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.secondary.opacity(0.3) : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(smsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            if let clip = UIPasteboard.general.string, !clip.isEmpty {
                                smsText = clip
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 13))
                                Text("Paste from Clipboard")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.purple)
                        }
                    }
                    .padding(16)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func parsedResultView(_ p: ParsedTransaction) -> some View {
        VStack(spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(p.isCredit ? Color(red: 0.1, green: 0.65, blue: 0.35).opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: p.isCredit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(p.isCredit ? Color(red: 0.1, green: 0.65, blue: 0.35) : .red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.isCredit ? "Income Detected" : "Expense Detected")
                        .font(.system(size: 16, weight: .bold))
                    Text(p.bankName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(p.isCredit ? "+" : "-")\(sym)\(String(format: "%.2f", p.amount))")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(p.isCredit ? Color(red: 0.1, green: 0.65, blue: 0.35) : .red)
            }

            VStack(spacing: 8) {
                detailRow("Merchant", p.merchant)
                detailRow("Category", p.category.rawValue.capitalized)
                detailRow("Type", p.isCredit ? "Credit (Income)" : "Debit (Expense)")
                if !p.accountLast4.isEmpty {
                    detailRow("Account", "••••\(p.accountLast4)")
                }
                if let bal = p.balance {
                    detailRow("Balance After", "\(sym)\(String(format: "%.2f", bal))")
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            HStack(spacing: 10) {
                Button {
                    parsed = nil
                    parseError = false
                } label: {
                    Text("Re-parse")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.secondary)
                        .cornerRadius(12)
                }

                Button {
                    let expense = Expense(
                        amount: p.amount,
                        category: p.category,
                        description: p.merchant,
                        isIncome: p.isCredit,
                        isFromSMS: true
                    )
                    onSave(expense)
                    vm.dismissSMSHash(p.rawText)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(p.isCredit ? "Add Income" : "Add Expense")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(p.isCredit ? Color(red: 0.1, green: 0.65, blue: 0.35) : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
    }
}
