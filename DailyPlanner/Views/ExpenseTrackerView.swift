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
    @State private var editingExpense: Expense? = nil
    @State private var showSMSImport = false
    @State private var detectedSMS: ParsedTransaction? = nil
    @State private var hasCheckedClipboard = false
    @State private var showGmailSync = false
    @State private var showTransactions = false

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
        VStack(spacing: 0) {
        ScrollView {
            VStack(spacing: 0) {
                // 1 ── Income & Expense list table ─────────────────────
                monthlySummaryCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 2 ── Import options (Paste Bank SMS / Gmail sync) ─────
                if !vm.isFuture {
                    importButtons
                        .padding(.top, 16)
                }

                // 3 ── Expense Breakdown (labeled pie) ─────────────────
                categoryPieChartSection
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 4 ── Spending Trends (last) ──────────────────────────
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
                .padding(.horizontal, 16).padding(.top, 12)

                Spacer(minLength: 24)
            }
        }
        .sheet(isPresented: $showSpendingTrends) {
            SpendingTrendsView().environmentObject(vm)
        }
        .sheet(isPresented: $showTransactions) {
            TransactionsListSheet(monthDate: summaryDate, sym: sym,
                                  onEdit: { editingExpense = $0 },
                                  onDelete: { deleteConfirmItem = $0 })
                .environmentObject(vm)
        }
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView().environmentObject(pro)
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
        .sheet(isPresented: $showSMSImport) {
            SMSImportWizard(parsed: detectedSMS, sym: sym) { expense in
                vm.addExpense(expense)
            }
            .environmentObject(vm)
        }
        .sheet(isPresented: $showGmailSync) {
            GmailSyncView(sym: sym).environmentObject(vm)
        }
        .sheet(item: $editingExpense) { expense in
            EditTransactionSheet(expense: expense, currencySymbol: sym) { updated in
                vm.updateExpense(updated)
            }
            .environmentObject(vm)
        }
        .onAppear {
            guard vm.settings.smartBankSMSEnabled else { return }
            hasCheckedClipboard = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
                let hash = String(text.hashValue)
                guard !vm.settings.dismissedSMSHashes.contains(hash) else { return }
                if BankSMSParser.looksLikeBankSMS(text), let result = BankSMSParser.parse(text) {
                    detectedSMS = result
                    showSMSImport = true
                }
            }
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

        // ── Fixed bottom bar: always one tap away ──────────────────────
        if !vm.isFuture {
            bottomAddBar
        }
        }
    }

    // MARK: - Category Pie Chart

    private var categoryPieChartSection: some View {
        let cutoff = isCurrentMonth ? vm.selectedDate : nil
        let categories = vm.monthlyExpensesByDisplayCategory(for: summaryDate, upTo: cutoff)
        let total = categories.reduce(0.0) { $0 + $1.1 }

        return Group {
            if total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expense Breakdown")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.leading, 4)

                    // Self-labeled pie: every slice carries its own callout
                    // line with the category name, amount, and share.
                    LabeledPieChart(slices: pieSlices(from: categories),
                                    total: total, sym: sym)
                        .frame(height: 360)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
    }

    /// Top slices stay individual; the tail is grouped into "Others" so the
    /// in-chart labels never overlap.
    private func pieSlices(from categories: [(PlannerViewModel.DisplayCategory, Double)]) -> [LabeledPieChart.Slice] {
        var slices = categories.prefix(6).map {
            LabeledPieChart.Slice(name: $0.0.name, value: $0.1, color: $0.0.color)
        }
        let rest = categories.dropFirst(6).reduce(0.0) { $0 + $1.1 }
        if rest > 0 {
            slices.append(LabeledPieChart.Slice(name: "Others", value: rest, color: .gray))
        }
        return slices
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

    /// Fixed bar at the bottom of the screen — never scrolls away.
    private var bottomAddBar: some View {
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
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var importButtons: some View {
        VStack(spacing: 8) {
            if vm.settings.smartBankSMSEnabled {
                FinanceAddButton(
                    label: "Paste Bank SMS",
                    icon: "doc.on.clipboard.fill",
                    bg: Color.purple.opacity(0.1),
                    fg: .purple) {
                    detectedSMS = nil
                    showSMSImport = true
                }
                .padding(.horizontal, 16)
            }

            // ── Expense Sync from Gmail (PRO) ──────────────────────
            Button {
                if pro.isPro { showGmailSync = true } else { showProUpgrade = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 16))
                    Text("Expense Sync from Gmail")
                        .font(.system(size: 15, weight: .semibold))
                    if !pro.isPro {
                        ProInlineBadge()
                    } else if pro.isPro && vm.gmailNeedsReconnectSoon {
                        Text("Reconnect")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.1))
                .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))
                .cornerRadius(14)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Monthly Summary Card

    private var monthlySummaryCard: some View {
        let cutoff        = isCurrentMonth ? vm.selectedDate : nil
        let totalIncome   = vm.monthlyTotalIncome(for: summaryDate, upTo: cutoff)
        let totalExpenses = vm.monthlyTotalExpenses(for: summaryDate, upTo: cutoff)
        let totalSavings  = vm.monthlyTotalSavings(for: summaryDate, upTo: cutoff)
        let balance       = vm.monthlyBalance(for: summaryDate, upTo: cutoff)
        let categories    = vm.monthlyExpensesByDisplayCategory(for: summaryDate, upTo: cutoff)
        let barRatio: Double = totalIncome > 0 ? min(totalExpenses / totalIncome, 1.0) : 0

        let incomeGreen = Color(red: 0.1, green: 0.62, blue: 0.35)

        return VStack(alignment: .leading, spacing: 0) {

            // Header with month navigation
            HStack {
                Button { summaryMonthOffset -= 1 } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(summaryMonthLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Monthly Overview")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { summaryMonthOffset += 1 } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
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
                        .fill(Color.red.opacity(0.55))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(incomeGreen)
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
                    color: incomeGreen,
                    isHeader: true
                )
                .padding(.horizontal, 16)

                if !categories.isEmpty {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                // Category-wise expense rows
                ForEach(categories, id: \.0) { dc, amount in
                    HStack(spacing: 10) {
                        Image(systemName: dc.icon)
                            .font(.system(size: 12))
                            .foregroundColor(dc.color)
                            .frame(width: 20)
                        Text(dc.name)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("-\(sym)\(String(format: "%.2f", amount))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                if totalExpenses > 0 {
                    SummaryRow(
                        label: "Expense",
                        amount: totalExpenses,
                        sym: sym,
                        color: Color.red,
                        isHeader: true
                    )
                    .padding(.horizontal, 16)
                }

                // Savings row in monthly summary
                if totalSavings > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)

                    SummaryRow(
                        label: "Savings",
                        amount: totalSavings,
                        sym: sym,
                        color: Color(red: 0.2, green: 0.45, blue: 0.9),
                        isHeader: false
                    )
                    .padding(.horizontal, 16)
                }

                // Dashed divider
                DashedDivider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                // Balance = Income − Expenses − Savings
                HStack {
                    Text("Balance")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(balance >= 0 ? "+" : "")\(sym)\(String(format: "%.2f", balance))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(balance >= 0 ? incomeGreen : Color.red)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // ── View all individual transactions ──
                Button { showTransactions = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Transactions")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppSection.expenseTracker.color.opacity(0.15))
                    .foregroundColor(AppSection.expenseTracker.color)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
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
                            TransactionRow(expense: item, sym: sym,
                                           onEdit: { editingExpense = item }) {
                                deleteConfirmItem = item
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    if !expenses.isEmpty {
                        SectionGroupLabel(title: "Expenses", color: .red)
                        ForEach(expenses) { item in
                            TransactionRow(expense: item, sym: sym,
                                           onEdit: { editingExpense = item }) {
                                deleteConfirmItem = item
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    if !savings.isEmpty {
                        SectionGroupLabel(title: "Savings", color: Color(red: 0.3, green: 0.5, blue: 0.95))
                        ForEach(savings) { item in
                            TransactionRow(expense: item, sym: sym,
                                           onEdit: { editingExpense = item }) {
                                deleteConfirmItem = item
                            }
                            .padding(.horizontal, 16)
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
                .foregroundColor(isHeader ? .primary : .secondary)
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
            .stroke(Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
        .frame(height: 1)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let expense: Expense
    let sym: String
    var onEdit: (() -> Void)? = nil
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
            if onEdit != nil {
                Button { onEdit?() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
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

// MARK: - Edit Transaction Sheet

struct EditTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: PlannerViewModel
    @State private var amount: String
    @State private var description: String
    @State private var category: ExpenseCategory
    @State private var customCategoryLabel: String
    @State private var isCustomCategory: Bool
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @FocusState private var amountFocused: Bool

    let original: Expense
    let currencySymbol: String
    let onSave: (Expense) -> Void

    init(expense: Expense, currencySymbol: String, onSave: @escaping (Expense) -> Void) {
        self.original = expense
        self.currencySymbol = currencySymbol
        self.onSave = onSave
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _description = State(initialValue: expense.description)
        _category = State(initialValue: expense.category)
        _customCategoryLabel = State(initialValue: expense.customCategoryLabel)
        _isCustomCategory = State(initialValue: !expense.customCategoryLabel.isEmpty)
    }

    private var mode: ExpenseTrackerView.AddMode {
        if original.isIncome  { return .income }
        if original.isDeposit { return .savings }
        return .expense
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

    private var title: String {
        switch mode {
        case .income:  return "Edit Income"
        case .expense: return "Edit Expense"
        case .savings: return "Edit Saving"
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
                            TextField("Description", text: $description)
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
                            var updated = original
                            updated.amount = amt
                            updated.description = description.trimmingCharacters(in: .whitespaces)
                            if mode == .expense {
                                updated.category = isCustomCategory ? .other : category
                                updated.customCategoryLabel = isCustomCategory ? customCategoryLabel : ""
                            }
                            onSave(updated)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Changes")
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
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Clear") { amount = "" }
                            .foregroundColor(.secondary)
                        Button("Done") { amountFocused = false }
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

// MARK: - SMS Import Wizard

struct SMSImportWizard: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vm: PlannerViewModel

    @State private var step: WizardStep = .paste
    @State private var smsText = ""
    @State private var parsed: ParsedTransaction? = nil
    @State private var parseError = false

    @State private var transactionType: TransactionType = .expense
    @State private var amount = ""
    @State private var originalAmount = ""
    @State private var originalCurrency = ""
    @State private var wasConverted = false
    @State private var merchant = ""
    @State private var category: ExpenseCategory = .other
    @State private var isCustomCategory = false
    @State private var customCategoryLabel = ""
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showRenameCategory = false
    @State private var renamingCategory = ""
    @State private var renameCategoryNewName = ""
    @FocusState private var amountFocused: Bool

    let parsed0: ParsedTransaction?
    let sym: String
    let onSave: (Expense) -> Void

    init(parsed: ParsedTransaction?, sym: String, onSave: @escaping (Expense) -> Void) {
        self.parsed0 = parsed
        self.sym = sym
        self.onSave = onSave
    }

    enum WizardStep {
        case paste
        case type
        case category
    }

    enum TransactionType: String, CaseIterable {
        case income = "Income"
        case expense = "Expense"
        case savings = "Savings"

        var icon: String {
            switch self {
            case .income:  return "arrow.down.circle.fill"
            case .expense: return "arrow.up.circle.fill"
            case .savings: return "banknote.fill"
            }
        }

        var color: Color {
            switch self {
            case .income:  return Color(red: 0.1, green: 0.65, blue: 0.35)
            case .expense: return .red
            case .savings: return Color(red: 0.3, green: 0.5, blue: 0.95)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                wizardHeader
                ScrollView {
                    VStack(spacing: 16) {
                        switch step {
                        case .paste:  pasteStep
                        case .type:   typeStep
                        case .category: categoryStep
                        }
                    }
                    .padding(16)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { amountFocused = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let p = parsed {
                            vm.dismissSMSHash(p.rawText)
                        }
                        dismiss()
                    }
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
            .alert("Rename Category", isPresented: $showRenameCategory) {
                TextField("New name", text: $renameCategoryNewName)
                    .autocapitalization(.words)
                Button("Rename") {
                    let newName = renameCategoryNewName.trimmingCharacters(in: .whitespaces)
                    let oldName = renamingCategory
                    if !newName.isEmpty && newName != oldName &&
                       !vm.settings.customExpenseCategories.contains(newName) {
                        if let idx = vm.settings.customExpenseCategories.firstIndex(of: oldName) {
                            vm.settings.customExpenseCategories[idx] = newName
                            vm.saveSettings()
                        }
                        if customCategoryLabel == oldName {
                            customCategoryLabel = newName
                        }
                    }
                    renamingCategory = ""
                    renameCategoryNewName = ""
                }
                Button("Cancel", role: .cancel) {
                    renamingCategory = ""
                    renameCategoryNewName = ""
                }
            } message: {
                Text("Enter a new name for \"\(renamingCategory)\".")
            }
            .onAppear {
                if let p = parsed0 {
                    applyParsed(p)
                }
            }
        }
    }

    // MARK: - Header

    private var wizardHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(Array(zip(0..., [("1", "Paste"), ("2", "Type"), ("3", "Category")])), id: \.0) { idx, item in
                    let current = stepIndex
                    HStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(idx <= current ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 22, height: 22)
                            if idx < current {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.purple)
                            } else {
                                Text(item.0)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(idx == current ? .purple : .white.opacity(0.5))
                            }
                        }
                        if idx <= current {
                            Text(item.1)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    if idx < 2 {
                        Rectangle()
                            .fill(idx < current ? Color.white.opacity(0.8) : Color.white.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: 20)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.purple, .purple.opacity(0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private var stepIndex: Int {
        switch step {
        case .paste: return 0
        case .type: return 1
        case .category: return 2
        }
    }

    // MARK: - Step 1: Paste

    private var pasteStep: some View {
        VStack(spacing: 14) {
            if let p = parsed {
                parsedSummaryCard(p)

                Button {
                    withAnimation { step = .type }
                } label: {
                    HStack {
                        Text("Continue")
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }

                Button {
                    parsed = nil
                    smsText = ""
                    parseError = false
                } label: {
                    Text("Paste different SMS")
                        .font(.system(size: 13))
                        .foregroundColor(.purple)
                }
            } else {
                Image(systemName: "message.badge.filled.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.purple.opacity(0.5))
                    .padding(.top, 8)

                Text("Paste your bank SMS")
                    .font(.system(size: 18, weight: .bold))

                TextEditor(text: $smsText)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        Group {
                            if smsText.isEmpty {
                                Text("Paste your bank SMS here...\n\nExample:\nOMR 396.439 is debited from your a/c 0435XXXXXXXX0028")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }, alignment: .topLeading
                    )

                if parseError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        Text("Could not detect a transaction. Check the SMS and try again.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }

                Button {
                    let text = smsText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let result = BankSMSParser.parse(text) {
                        applyParsed(result)
                    } else {
                        parseError = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Detect Transaction")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(smsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.secondary.opacity(0.3) : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(smsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    if let clip = UIPasteboard.general.string, !clip.isEmpty {
                        smsText = clip
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.purple)
                }
            }
        }
    }

    // MARK: - Step 2: Type

    private var typeStep: some View {
        VStack(spacing: 16) {
            if let p = parsed {
                parsedSummaryCard(p)
            }

            VStack(alignment: .leading, spacing: 10) {
                if parsed?.confidenceType == .high {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.system(size: 13))
                        Text("Auto-detected as \(transactionType.rawValue)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.purple)
                    }

                    Text("Is this correct? Tap to change if needed.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("Is this Income or Expense?")
                        .font(.system(size: 16, weight: .bold))
                    Text("We couldn't determine the type automatically. Please select one.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { transactionType = type }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(transactionType == type ? type.color : Color(.systemGray5))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: type.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(transactionType == type ? .white : .secondary)
                                }
                                Text(type.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                if transactionType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(type.color)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(transactionType == type
                                          ? type.color.opacity(0.08)
                                          : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(transactionType == type
                                                  ? type.color : Color.clear,
                                                  lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("Description", text: $merchant)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                HStack {
                    Text(sym).foregroundColor(.secondary)
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation { step = .paste }
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .foregroundColor(.secondary)
                    .cornerRadius(14)
                }

                if transactionType == .expense {
                    Button {
                        withAnimation { step = .category }
                    } label: {
                        HStack {
                            Text("Next: Category")
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                } else {
                    Button(action: saveTransaction) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Add \(transactionType.rawValue)")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? transactionType.color : Color.secondary.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Step 3: Category

    private var categoryStep: some View {
        VStack(spacing: 16) {
            if parsed?.confidenceCategory == .high {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 13))
                    Text("Auto-detected: \(category.rawValue)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.purple)
                }

                Text("Tap a different category if this isn't right.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Select a Category")
                    .font(.system(size: 16, weight: .bold))
                Text("We couldn't determine the category. Please choose one.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    Button {
                        isCustomCategory = false
                        customCategoryLabel = ""
                        withAnimation(.easeInOut(duration: 0.15)) { category = cat }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 14))
                                .foregroundColor(!isCustomCategory && category == cat ? .white : cat.color)
                                .frame(width: 20)
                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(!isCustomCategory && category == cat ? .white : .primary)
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(!isCustomCategory && category == cat
                                      ? cat.color : cat.color.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(!isCustomCategory && category == cat
                                              ? Color.clear : cat.color.opacity(0.2),
                                              lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if !vm.settings.customExpenseCategories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Categories")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    ForEach(vm.settings.customExpenseCategories, id: \.self) { name in
                        let isSelected = isCustomCategory && customCategoryLabel == name
                        HStack(spacing: 0) {
                            Button {
                                isCustomCategory = true
                                customCategoryLabel = name
                                category = .other
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(isSelected ? .white : .purple)
                                    Text(name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(isSelected ? .white : .primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button {
                                renamingCategory = name
                                renameCategoryNewName = name
                                showRenameCategory = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                                    .padding(8)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button {
                                vm.settings.customExpenseCategories.removeAll { $0 == name }
                                vm.saveSettings()
                                if customCategoryLabel == name {
                                    isCustomCategory = false
                                    customCategoryLabel = ""
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(isSelected ? .white.opacity(0.7) : .red.opacity(0.6))
                                    .padding(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.leading, 12)
                        .padding(.vertical, 4)
                        .padding(.trailing, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.purple : Color.purple.opacity(0.08))
                        )
                    }
                }
            }

            Button(action: { showAddCategory = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add New Category")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.purple)
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation { step = .type }
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .foregroundColor(.secondary)
                    .cornerRadius(14)
                }

                Button(action: saveTransaction) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Add Expense")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? Color.red : Color.secondary.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(!canSave)
            }
        }
    }

    // MARK: - Parsed Summary Card

    private func parsedSummaryCard(_ p: ParsedTransaction) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.bankName)
                        .font(.system(size: 14, weight: .bold))
                    HStack(spacing: 8) {
                        if !p.accountLast4.isEmpty {
                            Text("••••\(p.accountLast4)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        if let bal = p.balance {
                            Text("Bal: \(sym)\(String(format: "%.3f", bal))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if wasConverted {
                        Text("\(originalCurrency) \(originalAmount)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }
                    Text("\(sym)\(amount)")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.purple)
                }
            }

            if wasConverted {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("Converted from \(originalCurrency) to \(vm.settings.currency.rawValue) (approximate rate)")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(14)
    }

    // MARK: - Helpers

    private var canSave: Bool {
        let desc = merchant.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty else { return false }
        guard let amt = Double(amount), amt > 0 else { return false }
        return true
    }

    private func applyParsed(_ p: ParsedTransaction) {
        parsed = p
        smsText = p.rawText
        merchant = p.merchant.isEmpty ? "Bank Transaction" : p.merchant
        category = p.category
        transactionType = p.isCredit ? .income : .expense
        isCustomCategory = false
        customCategoryLabel = ""
        parseError = false

        let localCurrency = vm.settings.currency.rawValue
        if CurrencyConverter.needsConversion(detected: p.currencyDetected, local: localCurrency),
           let converted = CurrencyConverter.convert(amount: p.amount, from: p.currencyDetected, to: localCurrency) {
            originalAmount = String(format: "%.3f", p.amount)
            originalCurrency = p.currencyDetected
            wasConverted = true
            amount = String(format: "%.3f", converted)
        } else {
            originalAmount = ""
            originalCurrency = ""
            wasConverted = false
            amount = String(format: "%.3f", p.amount)
        }

        step = .type
    }

    private func saveTransaction() {
        guard canSave, let amt = Double(amount) else { return }
        let expense = Expense(
            amount: amt,
            category: transactionType == .expense ? (isCustomCategory ? .other : category) : .other,
            customCategoryLabel: transactionType == .expense && isCustomCategory ? customCategoryLabel : "",
            description: merchant.trimmingCharacters(in: .whitespaces),
            isDeposit: transactionType == .savings,
            isIncome: transactionType == .income,
            isFromSMS: true
        )
        onSave(expense)
        if let p = parsed {
            vm.dismissSMSHash(p.rawText)
        }
        dismiss()
    }
}

// MARK: - Labeled Pie Chart
/// A donut chart that labels each slice inside the drawing itself:
/// a short leader line points from the slice to its name, amount, and
/// percentage — no separate legend needed.
struct LabeledPieChart: View {
    struct Slice: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let color: Color
    }

    let slices: [Slice]
    let total: Double
    let sym: String

    private struct ComputedSlice: Identifiable {
        let id = UUID()
        let slice: Slice
        let start: Double   // radians
        let end: Double
        let mid: Double
    }

    private var computed: [ComputedSlice] {
        let sum = max(slices.reduce(0) { $0 + $1.value }, 0.0001)
        var angle = -Double.pi / 2
        return slices.map { s in
            let sweep = s.value / sum * 2 * .pi
            defer { angle += sweep }
            return ComputedSlice(slice: s, start: angle, end: angle + sweep, mid: angle + sweep / 2)
        }
    }

    /// A slice paired with the collision-free Y its label was pushed to.
    private struct Placed: Identifiable {
        let id = UUID()
        let c: ComputedSlice
        let isRight: Bool
        let labelY: CGFloat
    }

    /// Places labels so they never overlap: desired Y from each slice's mid
    /// angle, then within each side sorted and spread apart by a min row gap.
    private func placedLabels(center: CGPoint, r: CGFloat, height: CGFloat) -> [Placed] {
        let rowGap: CGFloat = 34
        var right: [(ComputedSlice, CGFloat)] = []
        var left:  [(ComputedSlice, CGFloat)] = []
        for c in computed {
            let y = center.y + (r + 18) * CGFloat(sin(c.mid))
            if cos(c.mid) >= 0 { right.append((c, y)) } else { left.append((c, y)) }
        }

        func spread(_ items: [(ComputedSlice, CGFloat)]) -> [(ComputedSlice, CGFloat)] {
            let sorted = items.sorted { $0.1 < $1.1 }
            var out: [(ComputedSlice, CGFloat)] = []
            var lastY = -CGFloat.greatestFiniteMagnitude
            for (c, y) in sorted {
                let ny = max(y, lastY + rowGap)
                out.append((c, ny)); lastY = ny
            }
            // Nudge back up if the column ran past the bottom edge.
            if let overflow = out.last.map({ $0.1 - (height - 18) }), overflow > 0 {
                out = out.map { ($0.0, $0.1 - overflow) }
            }
            return out
        }

        return (spread(right).map { Placed(c: $0.0, isRight: true,  labelY: $0.1) }
              + spread(left).map  { Placed(c: $0.0, isRight: false, labelY: $0.1) })
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.5)
            let r = min(geo.size.width, geo.size.height) * 0.23
            let placed = placedLabels(center: center, r: r, height: geo.size.height)
            let labelW: CGFloat = 84

            ZStack {
                // Slices
                ForEach(computed) { c in
                    Path { p in
                        p.move(to: center)
                        p.addArc(center: center, radius: r,
                                 startAngle: .radians(c.start),
                                 endAngle: .radians(c.end),
                                 clockwise: false)
                        p.closeSubpath()
                    }
                    .fill(c.slice.color)
                }

                // Leader lines + de-collided labels
                ForEach(placed) { pl in
                    let edge = point(center, r - 1, pl.c.mid)
                    let elbowX = center.x + (pl.isRight ? r + 16 : -(r + 16))
                    let labelX = pl.isRight ? elbowX + 8 : elbowX - 8

                    Path { p in
                        p.move(to: edge)
                        p.addLine(to: CGPoint(x: elbowX, y: pl.labelY))
                        p.addLine(to: CGPoint(x: labelX, y: pl.labelY))
                    }
                    .stroke(pl.c.slice.color, lineWidth: 1.3)

                    VStack(alignment: pl.isRight ? .leading : .trailing, spacing: 1) {
                        Text(pl.c.slice.name)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text("\(sym)\(compact(pl.c.slice.value)) · \(Int(round(pl.c.slice.value / max(total, 0.0001) * 100)))%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(width: labelW, alignment: pl.isRight ? .leading : .trailing)
                    .position(x: labelX + (pl.isRight ? labelW / 2 : -labelW / 2), y: pl.labelY)
                }

                // Donut hole with the total in the middle
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: r * 1.15, height: r * 1.15)
                VStack(spacing: 1) {
                    Text("Total")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(sym)\(compact(total))")
                        .font(.system(size: 15, weight: .bold))
                }
                .position(center)
            }
        }
    }

    private func point(_ c: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: c.x + radius * CGFloat(cos(angle)),
                y: c.y + radius * CGFloat(sin(angle)))
    }

    private func compact(_ v: Double) -> String {
        v >= 10000 ? String(format: "%.1fk", v / 1000) : String(format: "%.0f", v)
    }
}

// MARK: - Transactions List Sheet
/// Every individual income/expense/savings entry for the month, newest
/// first, each with its date and description — opened from the summary card.
struct TransactionsListSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    let monthDate: Date
    let sym: String
    let onEdit: (Expense) -> Void
    let onDelete: (Expense) -> Void

    struct DatedExpense: Identifiable {
        let id: UUID
        let date: Date
        let expense: Expense
    }

    private var items: [DatedExpense] {
        vm.monthlyEntries(for: monthDate)
            .flatMap { entry in
                entry.expenses.map { DatedExpense(id: $0.id, date: entry.date, expense: $0) }
            }
            .sorted { $0.date > $1.date }
    }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: monthDate)
    }

    var body: some View {
        NavigationView {
            Group {
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No transactions this month")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(items) { item in
                                TransactionListRow(dated: item, sym: sym)
                                    .padding(.horizontal, 16)
                                    .onTapGesture { dismiss(); onEdit(item.expense) }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(monthLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

private struct TransactionListRow: View {
    let dated: TransactionsListSheet.DatedExpense
    let sym: String

    private var e: Expense { dated.expense }
    private var color: Color {
        if e.isIncome  { return Color(red: 0.1, green: 0.62, blue: 0.35) }
        if e.isDeposit { return Color(red: 0.2, green: 0.45, blue: 0.9) }
        return .red
    }
    private var icon: String {
        if e.isIncome  { return "arrow.down.circle.fill" }
        if e.isDeposit { return "banknote.fill" }
        if !e.customCategoryLabel.isEmpty { return "tag.fill" }
        return e.category.icon
    }
    private var typeLabel: String {
        if e.isIncome  { return "Income" }
        if e.isDeposit { return "Savings" }
        return e.displayCategory
    }
    private var dateStr: String {
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
        return f.string(from: dated.date)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(e.description.isEmpty ? typeLabel : e.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(typeLabel) · \(dateStr)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(e.isIncome || e.isDeposit ? "+" : "-")\(sym)\(String(format: "%.2f", e.amount))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
