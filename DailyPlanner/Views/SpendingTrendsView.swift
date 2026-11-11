import SwiftUI
import Charts

// MARK: - Money Trends
//
// Made to be understood at a glance:
//   1. Choose what to look at — Spending (all, or one category), Income,
//      Savings, or what was Left over.
//   2. One plain sentence says where you stand this month and whether it's
//      more or less than last month by the same date.
//   3. A month-by-month line shows the direction, with your average.
//   4. A short list of months with up / down arrows.
//   5. Tips worked out from your own numbers: where the money goes, what
//      jumped, and how much a small cut would save.

struct SpendingTrendsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    enum Metric: String, CaseIterable, Identifiable {
        case spending = "Spending", income = "Income", savings = "Savings", leftOver = "Left over"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .spending: return "cart.fill"
            case .income:   return "arrow.down.circle.fill"
            case .savings:  return "banknote.fill"
            case .leftOver: return "wallet.pass.fill"
            }
        }

        var color: Color {
            switch self {
            case .spending: return Color(red: 0.93, green: 0.30, blue: 0.27)
            case .income:   return Color(red: 0.10, green: 0.65, blue: 0.35)
            case .savings:  return Color(red: 0.20, green: 0.45, blue: 0.95)
            case .leftOver: return Color(red: 0.50, green: 0.35, blue: 0.90)
            }
        }

        /// More is good for everything except spending.
        var moreIsGood: Bool { self != .spending }
    }

    @State private var metric: Metric = .spending
    /// nil = all categories.
    @State private var category: String? = nil
    @State private var months = 6
    @State private var selectedMonth: String? = nil

    private let cal = Calendar.current
    private var sym: String { vm.settings.currency.symbol }

    // MARK: Data

    struct MonthPoint: Identifiable {
        let date: Date
        let label: String
        let amount: Double
        let isCurrent: Bool
        var id: String { label }
    }

    private static let short: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let long: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f
    }()

    private var thisMonth: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private func monthStart(_ back: Int) -> Date {
        cal.date(byAdding: .month, value: -back, to: thisMonth) ?? thisMonth
    }

    /// The same day of the month in an earlier month, so a part-finished
    /// month is compared fairly ("by this date").
    private func sameDay(in month: Date) -> Date {
        let day = cal.component(.day, from: Date())
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 28
        return cal.date(bySetting: .day, value: min(day, count), of: month) ?? month
    }

    private func value(_ m: Metric, _ cat: String?, month: Date, upTo: Date? = nil) -> Double {
        switch m {
        case .spending:
            if let cat = cat {
                return vm.monthlyExpensesByDisplayCategory(for: month, upTo: upTo)
                    .first { $0.0.name == cat }?.1 ?? 0
            }
            return vm.monthlyTotalExpenses(for: month, upTo: upTo)
        case .income:   return vm.monthlyTotalIncome(for: month, upTo: upTo)
        case .savings:  return vm.monthlyTotalSavings(for: month, upTo: upTo)
        case .leftOver: return vm.monthlyBalance(for: month, upTo: upTo)
        }
    }

    private var points: [MonthPoint] {
        (0..<months).reversed().map { back in
            let m = monthStart(back)
            return MonthPoint(date: m, label: Self.short.string(from: m),
                              amount: value(metric, category, month: m), isCurrent: back == 0)
        }
    }

    /// Categories spent on in the chosen period, biggest first.
    private var categories: [PlannerViewModel.DisplayCategory] {
        var totals: [String: (PlannerViewModel.DisplayCategory, Double)] = [:]
        for back in 0..<months {
            for (dc, amount) in vm.monthlyExpensesByDisplayCategory(for: monthStart(back)) {
                totals[dc.name, default: (dc, 0)].1 += amount
            }
        }
        return totals.values.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private var lineColor: Color {
        if metric == .spending, let c = category, let dc = categories.first(where: { $0.name == c }) {
            return dc.color
        }
        return metric.color
    }

    // MARK: Body

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                let data = points
                VStack(alignment: .leading, spacing: 16) {
                    metricPicker
                    if metric == .spending { categoryPicker }
                    headline(data)
                    chartCard(data)
                    monthList(data)
                    tipsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Spending Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Pickers

    private var metricPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What do you want to see?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach(Metric.allCases) { m in
                    let on = m == metric
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            metric = m
                            if m != .spending { category = nil }
                            selectedMonth = nil
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: m.icon)
                                .font(.system(size: 17, weight: .semibold))
                            Text(m.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundColor(on ? .white : m.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(on ? m.color : m.color.opacity(0.10)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Picker("Period", selection: $months) {
                Text("Last 6 months").tag(6)
                Text("Last 12 months").tag(12)
            }
            .pickerStyle(.segmented)
            .padding(.top, 4)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All categories", color: metric.color, on: category == nil) { category = nil }
                ForEach(categories) { dc in
                    chip(dc.name, color: dc.color, icon: dc.icon, on: category == dc.name) {
                        category = dc.name
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ title: String, color: Color, icon: String? = nil, on: Bool,
                      action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { action(); selectedMonth = nil }
        } label: {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(on ? .white : .primary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(on ? color : Color(.secondarySystemGroupedBackground)))
            .overlay(Capsule().strokeBorder(color.opacity(on ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Headline

    private var subject: String {
        switch metric {
        case .spending: return category.map { "on \($0)" } ?? ""
        case .income:   return ""
        case .savings:  return ""
        case .leftOver: return ""
        }
    }

    private var verb: String {
        switch metric {
        case .spending: return "spent"
        case .income:   return "earned"
        case .savings:  return "saved"
        case .leftOver: return "had left"
        }
    }

    private func headline(_ data: [MonthPoint]) -> some View {
        let now = data.last?.amount ?? 0
        let prevMonth = monthStart(1)
        let prevSoFar = value(metric, category, month: prevMonth, upTo: sameDay(in: prevMonth))
        let change = prevSoFar != 0 ? (now - prevSoFar) / abs(prevSoFar) : nil
        let past = data.dropLast().map(\.amount)
        let avg = past.isEmpty ? 0 : past.reduce(0, +) / Double(past.count)
        let good = change.map { metric.moreIsGood ? $0 >= 0 : $0 <= 0 } ?? true
        let monthName = Self.long.string(from: thisMonth)

        return VStack(alignment: .leading, spacing: 10) {
            Text("\(monthName) so far")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(money(now))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(lineColor)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text([verb, subject].filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            if let change = change, abs(change) >= 0.005 {
                HStack(spacing: 6) {
                    Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .heavy))
                    Text("\(Int((abs(change) * 100).rounded()))% \(change > 0 ? "more" : "less") than last month by this date")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(good ? Color(red: 0.10, green: 0.62, blue: 0.33) : Color(red: 0.90, green: 0.30, blue: 0.20))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill((good ? Color.green : Color.red).opacity(0.10)))
            } else if prevSoFar == 0 && now == 0 {
                Text("Nothing recorded yet this month.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            if avg != 0 {
                Text("Your usual month: \(money(avg))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Chart

    private func chartCard(_ data: [MonthPoint]) -> some View {
        let past = data.dropLast().map(\.amount)
        let avg = past.isEmpty ? 0 : past.reduce(0, +) / Double(past.count)
        let picked = data.first { $0.label == selectedMonth }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Month by month")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                if let p = picked {
                    Text("\(Self.long.string(from: p.date)): \(money(p.amount))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(lineColor)
                } else {
                    Text("Tap a month")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Chart {
                ForEach(data) { p in
                    AreaMark(x: .value("Month", p.label), y: .value("Amount", p.amount))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.25), lineColor.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Month", p.label), y: .value("Amount", p.amount))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(lineColor)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    PointMark(x: .value("Month", p.label), y: .value("Amount", p.amount))
                        .foregroundStyle(p.label == selectedMonth ? lineColor : Color(.systemBackground))
                        .symbolSize(p.label == selectedMonth ? 110 : 60)
                        .annotation(position: .overlay) {
                            Circle().strokeBorder(lineColor, lineWidth: 2.5).frame(width: 9, height: 9)
                        }
                }
                if avg != 0 {
                    RuleMark(y: .value("Average", avg))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("usual \(money(avg))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let d = v.as(Double.self) { Text(compact(d)).font(.system(size: 10)) }
                    }
                }
            }
            .frame(height: 210)

            Text(data.last.map { "\($0.label) is still in progress." } ?? "")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Month list

    private func monthList(_ data: [MonthPoint]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(data.reversed().enumerated()), id: \.element.id) { i, p in
                let all = Array(data.reversed())
                let prev = i + 1 < all.count ? all[i + 1].amount : nil
                HStack {
                    Text(Self.long.string(from: p.date) + (p.isCurrent ? " (so far)" : ""))
                        .font(.system(size: 14, weight: p.isCurrent ? .bold : .regular))
                    Spacer()
                    Text(money(p.amount))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    if let prev = prev, !p.isCurrent {
                        arrow(p.amount, prev)
                    } else {
                        Color.clear.frame(width: 18)
                    }
                }
                .padding(.vertical, 10)
                if i < data.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func arrow(_ now: Double, _ before: Double) -> some View {
        let up = now > before
        let same = abs(now - before) < 0.005
        let good = same || (metric.moreIsGood ? up : !up)
        return Image(systemName: same ? "minus" : (up ? "arrow.up" : "arrow.down"))
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(same ? .secondary : (good ? .green : .red))
            .frame(width: 18)
    }

    // MARK: Tips

    private var tipsCard: some View {
        let list = tips
        return VStack(alignment: .leading, spacing: 12) {
            Label("Tips to save money", systemImage: "lightbulb.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 0.95, green: 0.60, blue: 0.05))
            ForEach(Array(list.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Text(tip.emoji).font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tip.title)
                            .font(.system(size: 14, weight: .bold))
                        Text(tip.detail)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(red: 1.0, green: 0.97, blue: 0.88)
            .opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.orange.opacity(0.2), lineWidth: 1))
    }

    struct Tip {
        let emoji: String
        let title: String
        let detail: String
    }

    /// Advice from the user's own numbers, most useful first, at most five.
    private var tips: [Tip] {
        var out: [Tip] = []
        let today = Date()
        let day = cal.component(.day, from: today)
        let daysInMonth = cal.range(of: .day, in: .month, for: today)?.count ?? 30
        let lastMonth = monthStart(1)

        let spentNow = vm.monthlyTotalExpenses(for: thisMonth)
        let usualSpend: Double = {
            let past = (1...3).map { vm.monthlyTotalExpenses(for: monthStart($0)) }.filter { $0 > 0 }
            return past.isEmpty ? 0 : past.reduce(0, +) / Double(past.count)
        }()

        // 1. Where this month is heading.
        if day >= 3, spentNow > 0 {
            let projected = spentNow / Double(day) * Double(daysInMonth)
            if usualSpend > 0, projected > usualSpend * 1.1 {
                out.append(Tip(emoji: "🚦", title: "On track to spend \(money(projected)) this month",
                               detail: "That's \(money(projected - usualSpend)) more than your usual month. Easing off for the rest of the month keeps you on budget."))
            } else if usualSpend > 0, projected < usualSpend * 0.9 {
                out.append(Tip(emoji: "🎉", title: "Spending less than usual",
                               detail: "At this pace you'll spend about \(money(projected)), \(money(usualSpend - projected)) less than a normal month. Move the difference to savings."))
            }
        }

        // 2. Categories that jumped compared with the usual by this date.
        let nowCats = vm.monthlyExpensesByDisplayCategory(for: thisMonth)
        let usualCats: [String: Double] = {
            var sum: [String: Double] = [:]
            for back in 1...3 {
                let m = monthStart(back)
                for (dc, v) in vm.monthlyExpensesByDisplayCategory(for: m, upTo: sameDay(in: m)) {
                    sum[dc.name, default: 0] += v / 3
                }
            }
            return sum
        }()
        let focus = category.map { c in nowCats.filter { $0.0.name == c } } ?? nowCats
        var jumps = 0
        for (dc, v) in focus where jumps < 2 {
            let usual = usualCats[dc.name] ?? 0
            guard usual > 0, v > usual * 1.25, v - usual >= max(1, spentNow * 0.03) else { continue }
            out.append(Tip(emoji: "📈", title: "\(dc.name) is up \(Int(((v / usual - 1) * 100).rounded()))%",
                           detail: "\(money(v)) so far, against \(money(usual)) by this date normally. Getting back to normal saves about \(money(v - usual)). \(Self.advice(for: dc.name))"))
            jumps += 1
        }

        // 3. The biggest cost, and what a small cut is worth.
        let lastCats = vm.monthlyExpensesByDisplayCategory(for: lastMonth)
        let lastTotal = lastCats.reduce(0) { $0 + $1.1 }
        let target = category.flatMap { c in lastCats.first { $0.0.name == c } } ?? lastCats.first
        if let pick = target, pick.1 > 0, lastTotal > 0 {
            let (dc, v) = pick
            let share = Int((v / lastTotal * 100).rounded())
            let cut = v * 0.10
            out.append(Tip(emoji: "✂️", title: category == nil
                               ? "\(dc.name) is your biggest cost (\(share)%)"
                               : "\(dc.name) was \(share)% of last month's spending",
                           detail: "Cutting it by just 10% saves \(money(cut)) a month — \(money(cut * 12)) a year. \(Self.advice(for: dc.name))"))
        }

        // 4. Savings rate.
        let incomeLast = vm.monthlyTotalIncome(for: lastMonth)
        if incomeLast > 0 {
            let kept = vm.monthlyTotalSavings(for: lastMonth) + max(0, vm.monthlyBalance(for: lastMonth))
            let rate = kept / incomeLast
            if rate < 0.2 {
                out.append(Tip(emoji: "🏦", title: "You kept \(Int((rate * 100).rounded()))% of last month's income",
                               detail: "A common goal is 20%. Setting aside \(money(incomeLast * 0.2)) on payday, before spending, makes it automatic."))
            } else {
                out.append(Tip(emoji: "🌟", title: "Great saving: \(Int((rate * 100).rounded()))% of your income",
                               detail: "You kept \(money(kept)) last month. Keep it up, or put part of it towards a goal."))
            }
        } else if metric != .spending {
            out.append(Tip(emoji: "📝", title: "Add your income",
                           detail: "Record your salary with Add Income to see how much of it you keep each month."))
        }

        // 5. Two months down in a row.
        let full = (1...3).map { vm.monthlyTotalExpenses(for: monthStart($0)) }
        if full[0] > 0, full[1] > 0, full[2] > 0, full[0] < full[1], full[1] < full[2] {
            out.append(Tip(emoji: "👏", title: "Spending down two months in a row",
                           detail: "From \(money(full[2])) to \(money(full[0])). Whatever you changed is working."))
        }

        if out.isEmpty {
            out.append(Tip(emoji: "🌱", title: "Tips will appear as you track",
                           detail: "Add your expenses and income for a few weeks and you'll see where your money goes and how to save."))
        }
        return Array(out.prefix(5))
    }

    /// A practical idea for a category, by its name.
    private static func advice(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("food") || n.contains("dining") || n.contains("restaurant") {
            return "Cooking at home two more days a week adds up fast."
        }
        if n.contains("grocer") { return "Shop with a list and plan the week's meals first." }
        if n.contains("shop") { return "Wait 48 hours before non-essential buys — most of the urge passes." }
        if n.contains("transport") || n.contains("fuel") || n.contains("travel") {
            return "Combine errands into one trip, or share rides where you can."
        }
        if n.contains("entertain") { return "Look for free weekend plans and pick one paid outing a week." }
        if n.contains("subscri") { return "Cancel the subscriptions you didn't use last month." }
        if n.contains("utilit") || n.contains("bill") {
            return "Check for a cheaper plan, and switch off lights and AC when not needed."
        }
        if n.contains("health") || n.contains("medical") { return "Ask for generic medicines — same effect, lower price." }
        if n.contains("educat") { return "Look for free courses and second-hand books first." }
        if n.contains("card") { return "Pay the full card balance each month to avoid interest." }
        return "Set a monthly limit for it in Budgets."
    }

    // MARK: Formatting

    private func money(_ v: Double) -> String {
        let sign = v < 0 ? "-" : ""
        let a = abs(v)
        let body = a >= 100 ? Int(a.rounded()).formatted() : String(format: "%.2f", a)
        return "\(sign)\(sym)\(body)"
    }

    private func compact(_ v: Double) -> String {
        let a = abs(v)
        let s: String
        if a >= 1_000_000 { s = String(format: "%.1fM", a / 1_000_000) }
        else if a >= 10_000 { s = String(format: "%.0fK", a / 1_000) }
        else if a >= 1_000 { s = String(format: "%.1fK", a / 1_000) }
        else { s = String(format: "%.0f", a) }
        return v < 0 ? "-" + s : s
    }
}
