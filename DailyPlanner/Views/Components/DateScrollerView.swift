import SwiftUI

struct DateScrollerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var monthOffset: Int = 0
    @State private var showMonthPicker = false

    private let cal = Calendar.current

    private var currentMonthDate: Date {
        cal.date(byAdding: .month, value: monthOffset, to: cal.startOfDay(for: Date()))!
    }

    private var monthYear: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: currentMonthDate)
    }

    private var datesInMonth: [Date] {
        guard let range = cal.range(of: .day, in: .month, for: currentMonthDate),
              let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: currentMonthDate))
        else { return [] }
        let today = cal.startOfDay(for: Date())
        return range.compactMap { day -> Date? in
            var c = cal.dateComponents([.year, .month], from: startOfMonth)
            c.day = day
            guard let d = cal.date(from: c), d <= today else { return nil }
            return d
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month / Year navigator
            HStack {
                Button(action: { withAnimation { monthOffset -= 1 } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { showMonthPicker = true }) {
                    Text(monthYear)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button(action: {
                    if monthOffset < 0 { withAnimation { monthOffset += 1 } }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(monthOffset < 0 ? .secondary : Color.secondary.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            // Date scroll
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(datesInMonth, id: \.self) { date in
                            DateCell(date: date, isSelected: cal.isDate(date, inSameDayAs: vm.selectedDate),
                                     hasEntry: vm.entries[vm.dateKey(for: date)] != nil)
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
                .onChange(of: vm.selectedDate) { newDate in
                    withAnimation {
                        proxy.scrollTo(newDate, anchor: .center)
                    }
                }
                .onChange(of: monthOffset) { _ in
                    if let last = datesInMonth.last {
                        proxy.scrollTo(last, anchor: .trailing)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerView(monthOffset: $monthOffset)
                .presentationDetents([.height(300)])
        }
    }
}

// MARK: - Date Cell
struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let hasEntry: Bool

    private let cal = Calendar.current

    private var dayNum: String {
        let c = cal.component(.day, from: date)
        return "\(c)"
    }
    private var dayName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }
    private var isToday: Bool { cal.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)

            Text(dayNum)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isSelected ? .white : isToday ? Color(red: 0.45, green: 0.25, blue: 0.85) : .primary)

            Circle()
                .fill(hasEntry
                      ? (isSelected ? Color.white.opacity(0.7) : Color(red: 0.45, green: 0.25, blue: 0.85))
                      : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 42, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected
                      ? LinearGradient(colors: [Color(red: 0.45, green: 0.25, blue: 0.85),
                                                Color(red: 0.6, green: 0.3, blue: 0.95)],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Color.clear, Color.clear],
                                       startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday && !isSelected ? Color(red: 0.45, green: 0.25, blue: 0.85).opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Month Year Picker
struct MonthYearPickerView: View {
    @Binding var monthOffset: Int
    @Environment(\.dismiss) var dismiss

    private let months = Calendar.current.monthSymbols
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let currentMonth = Calendar.current.component(.month, from: Date()) - 1

    @State private var selectedMonthIdx: Int = 0
    @State private var selectedYear: Int = 0

    init(monthOffset: Binding<Int>) {
        self._monthOffset = monthOffset
        let cal = Calendar.current
        let target = cal.date(byAdding: .month, value: monthOffset.wrappedValue, to: Date())!
        _selectedMonthIdx = State(initialValue: cal.component(.month, from: target) - 1)
        _selectedYear = State(initialValue: cal.component(.year, from: target))
    }

    private var years: [Int] { Array((currentYear - 5)...currentYear) }

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
                comps.year = selectedYear
                comps.month = selectedMonthIdx + 1
                comps.day = 1
                if let target = cal.date(from: comps) {
                    let now = cal.startOfDay(for: Date())
                    let diff = cal.dateComponents([.month], from: now, to: target)
                    monthOffset = min(0, diff.month ?? 0)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.45, green: 0.25, blue: 0.85))
            .padding(.bottom)
        }
        .padding(.horizontal)
    }
}
