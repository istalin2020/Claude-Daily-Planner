import SwiftUI

// MARK: - Weekly / Monthly Summary View
struct WeeklySummaryView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: SummaryMode = .weekly
    @State private var weekOffset: Int = 0
    @State private var monthOffset: Int = 0

    enum SummaryMode: String, CaseIterable {
        case weekly = "Week"
        case monthly = "Month"
    }

    private var dateRange: [Date] {
        let cal = Calendar.current
        if mode == .weekly {
            let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
            let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: base)) ?? base
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
        } else {
            let base = cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
            let comps = cal.dateComponents([.year, .month], from: base)
            let startOfMonth = cal.date(from: comps) ?? base
            let range = cal.range(of: .day, in: .month, for: startOfMonth)!
            return (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: startOfMonth) }
        }
    }

    private var entries: [DailyEntry] {
        dateRange.compactMap { vm.entries[vm.dateKey(for: $0)] }
    }

    // Aggregate stats
    private var totalTasks: Int { entries.reduce(0) { $0 + $1.allTasksCount } }
    private var completedTasks: Int { entries.reduce(0) { $0 + $1.completedTasksCount } }
    private var completionRate: Double { totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0 }
    private var totalExpenses: Double { entries.reduce(0) { $0 + $1.totalExpenses } }
    private var totalSteps: Int { entries.reduce(0) { $0 + $1.fitness.displaySteps } }
    private var avgSteps: Int { entries.isEmpty ? 0 : totalSteps / entries.count }
    private var totalWater: Int { entries.reduce(0) { $0 + $1.waterGlasses } }
    private var avgWater: Double { entries.isEmpty ? 0 : Double(totalWater) / Double(entries.count) }
    private var avgSleep: Double {
        let sleepDays = entries.compactMap { $0.sleep.durationHours }
        guard !sleepDays.isEmpty else { return 0 }
        return sleepDays.reduce(0, +) / Double(sleepDays.count)
    }
    private var avgMood: Double {
        let rated = entries.filter { $0.rating.mood > 0 }
        guard !rated.isEmpty else { return 0 }
        return Double(rated.reduce(0) { $0 + $1.rating.mood }) / Double(rated.count)
    }
    private var totalCalories: Int { entries.reduce(0) { $0 + $1.meals.totalCalories } }
    private var bestDay: Date? {
        dateRange.max { a, b in
            let ea = vm.entries[vm.dateKey(for: a)]
            let eb = vm.entries[vm.dateKey(for: b)]
            return (ea?.taskCompletionRate ?? 0) < (eb?.taskCompletionRate ?? 0)
        }
    }

    private var periodLabel: String {
        let cal = Calendar.current
        if mode == .weekly {
            guard let first = dateRange.first, let last = dateRange.last else { return "" }
            let f = DateFormatter(); f.dateFormat = "MMM d"
            let f2 = DateFormatter(); f2.dateFormat = "MMM d, yyyy"
            return "\(f.string(from: first)) – \(f2.string(from: last))"
        } else {
            let base = cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
            return f.string(from: base)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Mode + Navigator
                    modeAndNavigator

                    // Headline Stats
                    headlineStats

                    // Completion Bar Chart
                    taskCompletionSection

                    // Category Grid
                    statsGrid

                    // Day-by-day breakdown
                    dayBreakdownSection
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Mode & Navigator
    private var modeAndNavigator: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(SummaryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack {
                Button(action: { if mode == .weekly { weekOffset -= 1 } else { monthOffset -= 1 } }) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.65))
                }
                Spacer()
                Text(periodLabel)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button(action: { if mode == .weekly { weekOffset += 1 } else { monthOffset += 1 } }) {
                    Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold))
                        .foregroundColor((mode == .weekly ? weekOffset : monthOffset) >= 0
                                         ? Color(.systemGray3)
                                         : Color(red: 0.25, green: 0.15, blue: 0.65))
                }
                .disabled((mode == .weekly ? weekOffset : monthOffset) >= 0)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Headline Stats
    private var headlineStats: some View {
        HStack(spacing: 12) {
            headlineStat(value: "\(completedTasks)/\(totalTasks)", label: "Tasks Done",
                         icon: "checkmark.circle.fill", color: Color(red: 0.1, green: 0.65, blue: 0.35))
            headlineStat(value: String(format: "%.0f%%", completionRate * 100), label: "Completion",
                         icon: "percent", color: Color(red: 0.45, green: 0.25, blue: 0.85))
            headlineStat(value: vm.settings.currency.symbol + String(format: "%.0f", totalExpenses),
                         label: "Spent", icon: "dollarsign.circle.fill",
                         color: Color(red: 0.9, green: 0.3, blue: 0.5))
        }
        .padding(.horizontal)
    }

    private func headlineStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: - Task Completion Section
    private var taskCompletionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Task Completion").font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(dateRange, id: \.self) { date in
                        let key = vm.dateKey(for: date)
                        let e = vm.entries[key]
                        let rate = e?.taskCompletionRate ?? 0
                        let total = e?.allTasksCount ?? 0
                        VStack(spacing: 4) {
                            if total > 0 {
                                Text("\(Int(rate * 100))%")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 32, height: 80)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(total == 0 ? Color.clear :
                                          rate >= 1.0 ? Color(red: 0.1, green: 0.75, blue: 0.4) :
                                          rate >= 0.5 ? Color(red: 0.45, green: 0.25, blue: 0.85) :
                                          Color(red: 0.95, green: 0.5, blue: 0.1))
                                    .frame(width: 32, height: CGFloat(rate) * 80)
                            }
                            Text(dayAbbr(date))
                                .font(.system(size: 10))
                                .foregroundColor(Calendar.current.isDateInToday(date) ? Color(red: 0.25, green: 0.15, blue: 0.65) : .secondary)
                                .fontWeight(Calendar.current.isDateInToday(date) ? .bold : .regular)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Health & Wellness").font(.headline).padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(icon: "figure.walk", title: "Avg Steps",
                         value: avgSteps > 0 ? "\(avgSteps.formatted())" : "--",
                         color: .blue)
                statCard(icon: "drop.fill", title: "Avg Water",
                         value: avgWater > 0 ? String(format: "%.1f glasses", avgWater) : "--",
                         color: Color(red: 0.05, green: 0.65, blue: 0.95))
                statCard(icon: "moon.zzz.fill", title: "Avg Sleep",
                         value: avgSleep > 0 ? String(format: "%.1f hrs", avgSleep) : "--",
                         color: Color(red: 0.25, green: 0.15, blue: 0.65))
                statCard(icon: "face.smiling", title: "Avg Mood",
                         value: avgMood > 0 ? String(format: "%.1f / 5", avgMood) : "--",
                         color: .orange)
                statCard(icon: "flame.fill", title: "Total Calories",
                         value: totalCalories > 0 ? "\(totalCalories) kcal" : "--",
                         color: .red)
                if let best = bestDay {
                    statCard(icon: "trophy.fill", title: "Best Day",
                             value: dayAbbr(best),
                             color: .yellow)
                }
            }
            .padding(.horizontal)
        }
    }

    private func statCard(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon).foregroundColor(color).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.system(size: 14, weight: .semibold))
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: - Day Breakdown
    private var dayBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Day Breakdown").font(.headline).padding(.horizontal)
            VStack(spacing: 8) {
                ForEach(dateRange.filter { vm.entries[vm.dateKey(for: $0)] != nil }, id: \.self) { date in
                    let key = vm.dateKey(for: date)
                    if let e = vm.entries[key] {
                        dayBreakdownRow(date: date, entry: e)
                    }
                }
                if dateRange.allSatisfy({ vm.entries[vm.dateKey(for: $0)] == nil }) {
                    Text("No entries for this period")
                        .font(.subheadline).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
    }

    private func dayBreakdownRow(date: Date, entry: DailyEntry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(dayAbbr(date)).font(.caption).foregroundColor(.secondary)
                Text(dayNum(date)).font(.system(size: 16, weight: .bold))
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                // Task bar
                if entry.allTasksCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.1, green: 0.65, blue: 0.35))
                        Text("\(entry.completedTasksCount)/\(entry.allTasksCount) tasks")
                            .font(.caption)
                    }
                }
                // Stats pills
                HStack(spacing: 6) {
                    if entry.fitness.displaySteps > 0 {
                        miniPill(icon: "figure.walk", text: "\(entry.fitness.displaySteps.formatted())", color: .blue)
                    }
                    if entry.waterGlasses > 0 {
                        miniPill(icon: "drop.fill", text: "\(entry.waterGlasses)", color: Color(red: 0.05, green: 0.65, blue: 0.95))
                    }
                    if entry.totalExpenses > 0 {
                        miniPill(icon: "dollarsign", text: String(format: "%.0f", entry.totalExpenses), color: Color(red: 0.9, green: 0.3, blue: 0.5))
                    }
                    if let sleepH = entry.sleep.durationHours {
                        miniPill(icon: "moon.fill", text: String(format: "%.0fh", sleepH), color: Color(red: 0.25, green: 0.15, blue: 0.65))
                    }
                }
            }

            Spacer()

            // Mood
            if entry.rating.mood > 0 {
                Text(moodEmoji(entry.rating.mood)).font(.title3)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func miniPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(color)
            Text(text).font(.system(size: 10))
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }

    private func moodEmoji(_ rating: Int) -> String {
        switch rating {
        case 1: return "😞"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😊"
        case 5: return "😄"
        default: return ""
        }
    }

    private func dayAbbr(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayNum(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }
}
