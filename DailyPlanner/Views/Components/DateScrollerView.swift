import SwiftUI

struct DateScrollerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    /// Compact mode: smaller month header and date cells (used on hub pages).
    var compact: Bool = false
    /// Hides the month/year navigator row entirely (used inside sections).
    var showMonthRow: Bool = true
    @State private var monthOffset: Int = 0
    @State private var showMonthPicker = false

    private let cal = Calendar.current
    private let maxFutureMonths = 12

    private var currentMonthDate: Date {
        cal.date(byAdding: .month, value: monthOffset, to: cal.startOfDay(for: Date())) ?? Date()
    }

    private var monthYear: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: currentMonthDate)
    }

    // All days in the selected month — past, today, and future
    private var datesInMonth: [Date] {
        guard let range = cal.range(of: .day, in: .month, for: currentMonthDate),
              let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: currentMonthDate))
        else { return [] }
        return range.compactMap { day -> Date? in
            var c = cal.dateComponents([.year, .month], from: startOfMonth)
            c.day = day
            return cal.date(from: c)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month / Year navigator — arrows sit right beside the month name
            // so they never clash with the page's back arrow at the edge.
            HStack(spacing: 22) {
                Button(action: { withAnimation { monthOffset -= 1 } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                Button(action: { showMonthPicker = true }) {
                    Text(monthYear)
                        .font(.system(size: compact ? 12 : 13, weight: .bold))
                        .foregroundColor(.primary)
                }
                Button(action: {
                    if monthOffset < maxFutureMonths { withAnimation { monthOffset += 1 } }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(monthOffset < maxFutureMonths ? .secondary : Color.secondary.opacity(0.3))
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 3 : 6)

            // Date scroll
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: compact ? 6 : 8) {
                        ForEach(datesInMonth, id: \.self) { date in
                            DateCell(
                                date: date,
                                isSelected: cal.isDate(date, inSameDayAs: vm.selectedDate),
                                hasEntry: vm.entries[vm.dateKey(for: date)]?.hasData ?? false,
                                compact: compact
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    vm.select(date: date)
                                }
                            }
                            .id(date)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .onAppear {
                    proxy.scrollTo(vm.selectedDate, anchor: .center)
                }
                .onChange(of: vm.selectedDate) { _, newDate in
                    let targetMonth = cal.dateComponents([.year, .month], from: newDate)
                    let currentMonth = cal.dateComponents([.year, .month], from: currentMonthDate)
                    if targetMonth.year != currentMonth.year || targetMonth.month != currentMonth.month {
                        let now = cal.startOfDay(for: Date())
                        let diff = cal.dateComponents([.month], from: now, to: newDate)
                        monthOffset = diff.month ?? 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo(newDate, anchor: .center) }
                    }
                }
                .onChange(of: monthOffset) { _, _ in
                    let today = cal.startOfDay(for: Date())
                    if cal.isDate(today, equalTo: currentMonthDate, toGranularity: .month),
                       let todayCell = datesInMonth.first(where: { cal.isDateInToday($0) }) {
                        proxy.scrollTo(todayCell, anchor: .center)
                    } else if let first = datesInMonth.first {
                        proxy.scrollTo(first, anchor: .leading)
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerView(monthOffset: $monthOffset, maxFuture: maxFutureMonths)
                .presentationDetents([.height(300)])
        }
    }
}

// MARK: - Date Cell
struct DateCell: View {
    @Environment(\.themeAccent) private var accent
    let date: Date
    let isSelected: Bool
    let hasEntry: Bool
    var compact: Bool = false

    private let cal = Calendar.current

    private var dayNum: String { "\(cal.component(.day, from: date))" }
    private var dayName: String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }
    private var isToday: Bool  { cal.isDateInToday(date) }
    private var isFuture: Bool { date > cal.startOfDay(for: Date()) }

    var body: some View {
        VStack(spacing: compact ? 2 : 3) {
            Text(dayName)
                .font(.system(size: compact ? 8 : 10, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)

            Text(dayNum)
                .font(.system(size: compact ? 13 : 16, weight: .bold))
                .foregroundColor(
                    isSelected ? .white :
                    isToday    ? accent :
                    isFuture   ? accent.opacity(0.55) :
                                 .primary
                )

            Circle()
                .fill(hasEntry
                      ? (isSelected ? Color.white.opacity(0.7) : accent)
                      : Color.clear)
                .frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
        }
        .frame(width: compact ? 34 : 42, height: compact ? 46 : 60)
        .glassDateCell(isSelected: isSelected, isToday: isToday)
    }
}

// MARK: - Month Year Picker
struct MonthYearPickerView: View {
    @Binding var monthOffset: Int
    let maxFuture: Int
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeAccent) private var accent

    private let months = Calendar.current.monthSymbols
    private let currentYear = Calendar.current.component(.year, from: Date())

    @State private var selectedMonthIdx: Int = 0
    @State private var selectedYear: Int = 0

    init(monthOffset: Binding<Int>, maxFuture: Int) {
        self._monthOffset = monthOffset
        self.maxFuture    = maxFuture
        let cal    = Calendar.current
        let target = cal.date(byAdding: .month, value: monthOffset.wrappedValue, to: Date()) ?? Date()
        _selectedMonthIdx = State(initialValue: cal.component(.month, from: target) - 1)
        _selectedYear     = State(initialValue: cal.component(.year,  from: target))
    }

    private var years: [Int] {
        let cy = Calendar.current.component(.year, from: Date())
        return Array((cy - 5)...(cy + 1))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Month & Year")
                .font(.headline)
                .padding(.top)

            HStack {
                Picker("Month", selection: $selectedMonthIdx) {
                    ForEach(months.indices, id: \.self) { i in
                        Text(months[i]).tag(i)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { y in
                        Text("\(y)").tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
            }
            .frame(height: 150)

            Button("Done") {
                let cal = Calendar.current
                var comps = DateComponents()
                comps.year  = selectedYear
                comps.month = selectedMonthIdx + 1
                comps.day   = 1
                if let target = cal.date(from: comps) {
                    let now  = cal.startOfDay(for: Date())
                    let diff = cal.dateComponents([.month], from: now, to: target)
                    monthOffset = max(-60, min(maxFuture, diff.month ?? 0))
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .padding(.bottom)
        }
        .padding(.horizontal)
    }
}
