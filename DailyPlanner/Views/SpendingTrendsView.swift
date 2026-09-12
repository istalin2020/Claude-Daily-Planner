import SwiftUI
import Charts

// MARK: - Spending Trends
//
// One simple idea: pick a period — Daily, Weekly, Monthly, or Yearly —
// and see your spending as easy bars, with Total / Average / Highest
// summarized above the chart. The highest bar is highlighted orange and
// a dashed line marks your average.

struct SpendingTrendsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeAccent) private var accent

    enum Period: String, CaseIterable, Identifiable {
        case daily   = "Daily"
        case weekly  = "Weekly"
        case monthly = "Monthly"
        case yearly  = "Yearly"
        var id: String { rawValue }
    }
    @State private var period: Period = .daily
    @State private var selectedLabel: String? = nil

    struct Point: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
    }

    private var sym: String { vm.settings.currency.symbol }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .onChange(of: period) { _, _ in selectedLabel = nil }

                    let data = points
                    let total = data.reduce(0) { $0 + $1.amount }
                    let avg = data.isEmpty ? 0 : total / Double(data.count)
                    let maxAmount = data.map(\.amount).max() ?? 0

                    // Summary tiles
                    HStack(spacing: 10) {
                        TrendStat(title: "Total", value: "\(sym)\(compact(total))", color: .red)
                        TrendStat(title: avgTitle, value: "\(sym)\(compact(avg))", color: .blue)
                        TrendStat(title: "Highest", value: "\(sym)\(compact(maxAmount))", color: .orange)
                    }
                    .padding(.horizontal, 16)

                    // Tapped-bar readout
                    if let sel = selectedLabel, let p = data.first(where: { $0.label == sel }) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.orange).frame(width: 8, height: 8)
                            Text(fullLabel(for: p.label))
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("\(sym)\(String(format: "%.2f", p.amount))")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    } else {
                        Text("Tap a bar to see its exact amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Bars — highest highlighted, average as a dashed line,
                    // tap any bar to read its value above.
                    Chart {
                        ForEach(data) { p in
                            BarMark(
                                x: .value("Period", p.label),
                                y: .value("Spent", p.amount)
                            )
                            .foregroundStyle(
                                p.label == selectedLabel ? Color.orange.gradient
                                : (p.amount >= maxAmount && maxAmount > 0
                                   ? Color.orange.opacity(0.55).gradient
                                   : accent.gradient)
                            )
                            .cornerRadius(4)
                        }
                        if avg > 0 {
                            RuleMark(y: .value("Average", avg))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                .foregroundStyle(Color.secondary)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("average")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onTapGesture { location in
                                    if let plot = proxy.plotFrame {
                                        let x = location.x - geo[plot].origin.x
                                        if let label: String = proxy.value(atX: x) {
                                            selectedLabel = (label == selectedLabel) ? nil : label
                                        }
                                    }
                                }
                        }
                    }
                    .frame(height: 240)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    Text(explainer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("Spending Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Data per period

    private var points: [Point] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        switch period {
        case .daily:
            // Last 14 days, one bar per day
            return (0..<14).reversed().compactMap { back in
                guard let d = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
                let fmt = DateFormatter(); fmt.dateFormat = "d"
                return Point(label: fmt.string(from: d),
                             amount: vm.entry(for: d).totalExpenses)
            }
        case .weekly:
            // Last 8 weeks, one bar per week (labeled by its start date)
            guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
            return (0..<8).reversed().compactMap { back in
                guard let start = cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek) else { return nil }
                let fmt = DateFormatter(); fmt.dateFormat = "d MMM"
                return Point(label: fmt.string(from: start),
                             amount: sumExpenses(from: start, days: 7))
            }
        case .monthly:
            // Last 12 months
            guard let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) else { return [] }
            return (0..<12).reversed().compactMap { back in
                guard let start = cal.date(byAdding: .month, value: -back, to: thisMonth) else { return nil }
                let fmt = DateFormatter(); fmt.dateFormat = "MMM"
                return Point(label: fmt.string(from: start),
                             amount: vm.monthlyTotalExpenses(for: start))
            }
        case .yearly:
            // Last 5 years
            let year = cal.component(.year, from: today)
            return ((year - 4)...year).map { y in
                var total = 0.0
                for m in 1...12 {
                    if let d = cal.date(from: DateComponents(year: y, month: m, day: 1)) {
                        total += vm.monthlyTotalExpenses(for: d)
                    }
                }
                return Point(label: "\(y)", amount: total)
            }
        }
    }

    private func sumExpenses(from start: Date, days: Int) -> Double {
        let cal = Calendar.current
        var total = 0.0
        for i in 0..<days {
            if let d = cal.date(byAdding: .day, value: i, to: start) {
                total += vm.entry(for: d).totalExpenses
            }
        }
        return total
    }

    // MARK: - Labels

    private var avgTitle: String {
        switch period {
        case .daily:   return "Avg/Day"
        case .weekly:  return "Avg/Week"
        case .monthly: return "Avg/Month"
        case .yearly:  return "Avg/Year"
        }
    }

    private var explainer: String {
        switch period {
        case .daily:   return "Your day-by-day spending for the last 14 days. Bars are labeled with the day of the month."
        case .weekly:  return "Your weekly totals for the last 8 weeks. Each bar is labeled with the week's start date."
        case .monthly: return "Your monthly totals for the last 12 months."
        case .yearly:  return "Your yearly totals for the last 5 years."
        }
    }

    private func compact(_ v: Double) -> String {
        v >= 10000 ? String(format: "%.1fk", v / 1000) : String(format: "%.0f", v)
    }

    private func fullLabel(for label: String) -> String {
        switch period {
        case .daily:   return "Day \(label)"
        case .weekly:  return "Week of \(label)"
        case .monthly: return "\(label)"
        case .yearly:  return "Year \(label)"
        }
    }
}

// MARK: - Summary tile
private struct TrendStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
