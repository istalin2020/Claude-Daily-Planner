import SwiftUI
import Charts

// MARK: - Spending Trends View
struct SpendingTrendsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRange: TrendRange = .threeMonths

    enum TrendRange: String, CaseIterable {
        case oneMonth   = "1M"
        case threeMonths = "3M"
        case sixMonths  = "6M"
        case oneYear    = "1Y"

        var months: Int {
            switch self { case .oneMonth: return 1; case .threeMonths: return 3
            case .sixMonths: return 6; case .oneYear: return 12 }
        }
    }

    struct MonthlySpend: Identifiable {
        let id = UUID()
        let month: Date
        let amount: Double
    }

    struct DisplayCategorySpend: Identifiable {
        let id: String
        let dc: PlannerViewModel.DisplayCategory
        let amount: Double
    }

    private var months: [Date] {
        let cal = Calendar.current
        return (0..<selectedRange.months).compactMap {
            cal.date(byAdding: .month, value: -($0), to: Date())
        }.reversed()
    }

    private func monthlyTotal(for month: Date) -> Double {
        let cal = Calendar.current
        return vm.entries.values
            .filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalExpenses }
    }

    private func monthlySpend(for month: Date, dcName: String) -> Double {
        let cal = Calendar.current
        return vm.entries.values
            .filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .flatMap { $0.expenses }
            .filter { !$0.isDeposit && !$0.isIncome && PlannerViewModel.DisplayCategory.from($0).name == dcName }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlyTotals: [MonthlySpend] {
        months.map { MonthlySpend(month: $0, amount: monthlyTotal(for: $0)) }
    }

    private var categoryBreakdown: [DisplayCategorySpend] {
        let startDate = months.first ?? Date()
        let cal = Calendar.current
        let allExpenses = vm.entries.values
            .filter { cal.compare($0.date, to: startDate, toGranularity: .month) != .orderedAscending }
            .flatMap { $0.expenses }
            .filter { !$0.isDeposit && !$0.isIncome }

        var totals: [String: (PlannerViewModel.DisplayCategory, Double)] = [:]
        for exp in allExpenses {
            let dc = PlannerViewModel.DisplayCategory.from(exp)
            totals[dc.name, default: (dc, 0)].1 += exp.amount
        }

        return totals.values
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { DisplayCategorySpend(id: $0.0.name, dc: $0.0, amount: $0.1) }
    }

    private var totalSpend: Double { monthlyTotals.reduce(0) { $0 + $1.amount } }
    private var avgMonthlySpend: Double { monthlyTotals.isEmpty ? 0 : totalSpend / Double(monthlyTotals.count) }
    private var maxMonth: MonthlySpend? { monthlyTotals.max { $0.amount < $1.amount } }

    private var sym: String { vm.settings.currency.symbol }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Range Picker
                    rangePicker

                    // Summary Chips
                    summaryChips

                    // Bar Chart
                    monthlyBarChart

                    // Category Breakdown
                    categoryBreakdownSection

                    // Stacked monthly by category (top 3)
                    if !categoryBreakdown.isEmpty {
                        stackedCategoryChart
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Spending Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Range Picker
    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TrendRange.allCases, id: \.self) { range in
                Button(action: { selectedRange = range }) {
                    Text(range.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selectedRange == range
                                    ? Color(red: 0.1, green: 0.65, blue: 0.35)
                                    : Color(.secondarySystemBackground))
                        .foregroundColor(selectedRange == range ? .white : .secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Summary Chips
    private var summaryChips: some View {
        HStack(spacing: 12) {
            summaryChip(title: "Total", value: sym + String(format: "%.0f", totalSpend), color: Color(red: 0.9, green: 0.3, blue: 0.5))
            summaryChip(title: "Monthly Avg", value: sym + String(format: "%.0f", avgMonthlySpend), color: Color(red: 0.45, green: 0.25, blue: 0.85))
            if let max = maxMonth {
                summaryChip(title: "Peak Month", value: monthLabel(max.month, short: true), color: .orange)
            }
        }
        .padding(.horizontal)
    }

    private func summaryChip(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Bar Chart
    private var monthlyBarChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Spending").font(.headline).padding(.horizontal)
            Chart(monthlyTotals) { item in
                BarMark(
                    x: .value("Month", monthLabel(item.month, short: true)),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.65, blue: 0.35),
                                 Color(red: 0.1, green: 0.65, blue: 0.35).opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(6)
                if avgMonthlySpend > 0 {
                    RuleMark(y: .value("Average", avgMonthlySpend))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(Color.orange.opacity(0.8))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { val in
                    AxisValueLabel {
                        if let d = val.as(Double.self) {
                            Text(sym + abbreviate(d)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    // MARK: - Category Breakdown
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By Category").font(.headline).padding(.horizontal)
            VStack(spacing: 8) {
                ForEach(categoryBreakdown) { item in
                    categoryRow(item)
                }
                if categoryBreakdown.isEmpty {
                    Text("No expenses in this period")
                        .font(.subheadline).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity).padding()
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryRow(_ item: DisplayCategorySpend) -> some View {
        let pct = totalSpend > 0 ? item.amount / totalSpend : 0
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(item.dc.color.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: item.dc.icon).foregroundColor(item.dc.color).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.dc.name).font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Text(sym + String(format: "%.2f", item.amount)).font(.subheadline).fontWeight(.semibold)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(item.dc.color)
                            .frame(width: geo.size.width * pct, height: 6)
                    }
                }
                .frame(height: 6)
                Text(String(format: "%.0f%%", pct * 100)).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Stacked Category Chart (top 3)
    private var stackedCategoryChart: some View {
        let top3 = Array(categoryBreakdown.prefix(3))
        return VStack(alignment: .leading, spacing: 8) {
            Text("Top Categories Over Time").font(.headline).padding(.horizontal)
            Chart {
                ForEach(top3) { catSpend in
                    ForEach(months, id: \.self) { month in
                        let amount = monthlySpend(for: month, dcName: catSpend.dc.name)
                        LineMark(
                            x: .value("Month", monthLabel(month, short: true)),
                            y: .value("Amount", amount)
                        )
                        .foregroundStyle(catSpend.dc.color)
                        .symbol(by: .value("Category", catSpend.dc.name))
                    }
                }
            }
            .frame(height: 180)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers
    private func monthLabel(_ date: Date, short: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = short ? "MMM" : "MMMM yyyy"
        return f.string(from: date)
    }

    private func abbreviate(_ value: Double) -> String {
        if value >= 1000 { return String(format: "%.0fK", value / 1000) }
        return String(format: "%.0f", value)
    }
}
