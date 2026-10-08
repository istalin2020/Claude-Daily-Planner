import SwiftUI
import UIKit

// MARK: - Front page
//
// Light, card-based front page: greeting header, a week strip in a date card,
// five summary tiles (To-Do, Health, Finance, Schedule, Journal) with live
// figures for the selected day, and a bottom bar of quick actions.

// MARK: - Palette

extension Color {
    /// A colour that switches with light and dark mode.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    fileprivate static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }
}

/// One tile's colours: a strong pair for its icon, a pastel pair behind it.
struct HomeTileTheme {
    let accent: Color
    let accentDeep: Color
    let washLight: UIColor
    let washLight2: UIColor

    var wash: [Color] {
        [Color.adaptive(light: washLight, dark: washLight.withAlphaComponent(0.16)),
         Color.adaptive(light: washLight2, dark: washLight2.withAlphaComponent(0.10))]
    }

    static let todo = HomeTileTheme(accent: .rgb(61, 139, 255), accentDeep: .rgb(31, 95, 224),
                                    washLight: UIColor(red: 0.89, green: 0.93, blue: 1.0, alpha: 1),
                                    washLight2: UIColor(red: 0.81, green: 0.89, blue: 1.0, alpha: 1))
    static let health = HomeTileTheme(accent: .rgb(255, 92, 122), accentDeep: .rgb(232, 51, 90),
                                      washLight: UIColor(red: 1.0, green: 0.90, blue: 0.92, alpha: 1),
                                      washLight2: UIColor(red: 1.0, green: 0.83, blue: 0.86, alpha: 1))
    static let finance = HomeTileTheme(accent: .rgb(47, 212, 122), accentDeep: .rgb(17, 168, 90),
                                       washLight: UIColor(red: 0.87, green: 0.97, blue: 0.91, alpha: 1),
                                       washLight2: UIColor(red: 0.78, green: 0.94, blue: 0.85, alpha: 1))
    static let schedule = HomeTileTheme(accent: .rgb(142, 108, 245), accentDeep: .rgb(106, 69, 224),
                                        washLight: UIColor(red: 0.94, green: 0.91, blue: 1.0, alpha: 1),
                                        washLight2: UIColor(red: 0.88, green: 0.83, blue: 1.0, alpha: 1))
    static let journal = HomeTileTheme(accent: .rgb(255, 177, 61), accentDeep: .rgb(255, 138, 31),
                                       washLight: UIColor(red: 1.0, green: 0.96, blue: 0.86, alpha: 1),
                                       washLight2: UIColor(red: 1.0, green: 0.91, blue: 0.74, alpha: 1))
}

private enum HomeStyle {
    static let card = Color.adaptive(light: .white, dark: UIColor(white: 0.13, alpha: 1))
    static let innerCard = Color.adaptive(light: UIColor(white: 1, alpha: 0.78),
                                          dark: UIColor(white: 1, alpha: 0.07))
    static let blue = Color.rgb(31, 120, 255)
    static let softBlue = Color.adaptive(light: UIColor(red: 0.90, green: 0.94, blue: 1.0, alpha: 1),
                                         dark: UIColor(red: 0.16, green: 0.22, blue: 0.34, alpha: 1))
}

// MARK: - Page

struct HomeFrontPage: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    let onSearch: () -> Void
    let onSettings: () -> Void

    @State private var showUpgrade = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HomeHeader(onPro: { showUpgrade = true }, onSearch: onSearch, onSettings: onSettings)
                HomeDateCard()

                HStack(alignment: .top, spacing: 14) {
                    TodoTile { open(.tasks) }
                    HealthTile(open: { open(.health) }, openSection: openSection)
                }
                .frame(height: 230)

                HStack(alignment: .top, spacing: 14) {
                    FinanceTile { open(.finance) }
                    ScheduleTile { open(.schedule) }
                }
                .frame(height: 178)

                JournalTile { open(.journal) }
                    .frame(height: 118)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .background(HomeBackground().ignoresSafeArea())
        .sheet(isPresented: $showUpgrade) {
            ProUpgradeView().environmentObject(pro)
        }
    }

    private func open(_ group: HomeTileGroup) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if group.sections.count == 1 {
                vm.selectedSection = group.sections[0]
            } else {
                vm.activeHub = group
            }
        }
    }

    private func openSection(_ section: AppSection) {
        withAnimation(.easeInOut(duration: 0.25)) { vm.selectedSection = section }
    }
}

/// Soft blue wash with a large pale circle, as on the design.
struct HomeBackground: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [
                Color.adaptive(light: UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1),
                               dark: UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1)),
                Color.adaptive(light: UIColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1),
                               dark: UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)),
            ], startPoint: .top, endPoint: .bottom)

            Circle()
                .fill(Color.adaptive(light: UIColor(red: 0.80, green: 0.88, blue: 1.0, alpha: 0.55),
                                     dark: UIColor(red: 0.20, green: 0.30, blue: 0.55, alpha: 0.25)))
                .frame(width: 300, height: 300)
                .blur(radius: 30)
                .offset(x: 110, y: -150)
        }
    }
}

// MARK: - Header

struct HomeHeader: View {
    @EnvironmentObject var pro: ProManager
    let onPro: () -> Void
    let onSearch: () -> Void
    let onSettings: () -> Void

    private var greeting: (String, String) {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return ("Good Morning", "☀️") }
        if h < 17 { return ("Good Afternoon", "🌤️") }
        return ("Good Evening", "🌙")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Planner")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("\(greeting.0) \(greeting.1)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 4)

            Button(action: onPro) {
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(pro.isPro ? "PRO" : "Go PRO")
                        .font(.system(size: 15, weight: .heavy))
                        .lineLimit(1)
                }
                .foregroundColor(Color.rgb(232, 160, 0))
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(Capsule().fill(Color.adaptive(
                    light: UIColor(red: 1.0, green: 0.96, blue: 0.84, alpha: 1),
                    dark: UIColor(red: 0.30, green: 0.24, blue: 0.08, alpha: 1))))
            }
            .buttonStyle(TilePressStyle())

            circleButton("magnifyingglass", action: onSearch)
            circleButton("gearshape.fill", action: onSettings)
        }
        .padding(.top, 4)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 46, height: 46)
                .background(Circle().fill(HomeStyle.card))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Date card

struct HomeDateCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showCalendar = false

    private let cal = Calendar.current

    private static let monthFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private static let weekdayFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()

    /// Every day of the selected date's month.
    private var days: [Date] {
        guard let range = cal.range(of: .day, in: .month, for: vm.selectedDate),
              let start = cal.date(from: cal.dateComponents([.year, .month], from: vm.selectedDate))
        else { return [] }
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button { showCalendar = true } label: {
                    HStack(spacing: 8) {
                        Text(Self.monthFormat.string(from: vm.selectedDate))
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button { withAnimation(.spring(response: 0.3)) { vm.selectToday() } } label: {
                    Text("Today")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(HomeStyle.blue)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HomeStyle.softBlue))
                }
                .buttonStyle(TilePressStyle())

                Button { showCalendar = true } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(HomeStyle.blue)
                        .frame(width: 40, height: 38)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HomeStyle.softBlue))
                }
                .buttonStyle(TilePressStyle())
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(days, id: \.self) { day in
                            dayCell(day)
                                .id(cal.component(.day, from: day))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) { vm.select(date: day) }
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear { scroll(proxy, animated: false) }
                .onChange(of: vm.selectedDate) { _, _ in scroll(proxy, animated: true) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24).fill(HomeStyle.card))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .sheet(isPresented: $showCalendar) {
            HomeCalendarSheet()
                .environmentObject(vm)
                .presentationDetents([.medium, .large])
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        let target = cal.component(.day, from: vm.selectedDate)
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .center) }
        } else {
            DispatchQueue.main.async { proxy.scrollTo(target, anchor: .center) }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = cal.isDate(day, inSameDayAs: vm.selectedDate)
        let today = cal.isDateInToday(day)
        let hasData = vm.entries[vm.dateKey(for: day)]?.hasData ?? false

        return VStack(spacing: 6) {
            Text(Self.weekdayFormat.string(from: day))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selected ? .white.opacity(0.9) : .secondary)
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? .white : .primary)
            Circle()
                .fill(selected ? Color.white : HomeStyle.blue)
                .frame(width: 5, height: 5)
                .opacity(hasData || selected ? 1 : 0)
        }
        .frame(width: 50, height: 82)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selected
                      ? AnyShapeStyle(LinearGradient(colors: [Color.rgb(40, 140, 255), Color.rgb(10, 100, 235)],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(HomeStyle.blue.opacity(today && !selected ? 0.35 : 0), lineWidth: 1.5)
        )
        .shadow(color: selected ? HomeStyle.blue.opacity(0.35) : .clear, radius: 8, y: 4)
        .contentShape(Rectangle())
    }
}

/// Pick any date from a month calendar.
private struct HomeCalendarSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationView {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                .navigationTitle("Go to date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Today") {
                            vm.selectToday()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            vm.select(date: date)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .onAppear { date = vm.selectedDate }
    }
}

// MARK: - Tile chrome

/// The shared tile frame: pastel wash, icon disc, title, subtitle, chevron.
private struct HomeTile<Content: View>: View {
    let theme: HomeTileTheme
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [theme.accent, theme.accentDeep],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 48, height: 48)
                            .shadow(color: theme.accent.opacity(0.4), radius: 6, y: 3)
                        Image(systemName: icon)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundColor(.primary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2).minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(theme.accentDeep.opacity(0.8))
                        .padding(.top, 4)
                }
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: theme.wash, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: theme.accent.opacity(0.16), radius: 12, y: 5)
        }
        .buttonStyle(TilePressStyle())
    }
}

/// A large faint symbol tucked into a tile's corner, as illustration.
private struct TileArt: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 76
    var rotation: Double = -8

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color.opacity(0.22))
            .rotationEffect(.degrees(rotation))
            .allowsHitTesting(false)
    }
}

// MARK: - To-Do tile

private struct TodoTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let action: () -> Void

    var body: some View {
        let e = vm.currentEntry
        let total = e.allTasksCount
        let done = e.completedTasksCount
        let share = total == 0 ? 0 : Double(done) / Double(total)
        let theme = HomeTileTheme.todo

        HomeTile(theme: theme, icon: "checklist", title: "To-Do List",
                 subtitle: "Stay on top of your tasks", action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(total == 0 ? "No tasks yet" : "\(done) of \(total) done")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.accent.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(colors: [theme.accent, theme.accentDeep],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(share > 0 ? 8 : 0, geo.size.width * CGFloat(share)))
                    }
                }
                .frame(height: 8)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(HomeStyle.innerCard))

            Spacer(minLength: 0)
            HStack {
                Spacer()
                TileArt(symbol: "list.clipboard.fill", color: theme.accentDeep, size: 64)
            }
        }
    }
}

// MARK: - Health tile

private struct HealthTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let open: () -> Void
    let openSection: (AppSection) -> Void

    private static let number: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; return f
    }()

    var body: some View {
        let e = vm.currentEntry
        let theme = HomeTileTheme.health
        let steps = e.fitness.displaySteps
        let active = vm.settings.medications.filter(\.isActive).count
        let taken = vm.todayMedicationLogs.count

        HomeTile(theme: theme, icon: "heart.fill", title: "Health Tracker",
                 subtitle: "Build healthier habits", action: open) {
            Button { openSection(.healthFitness) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "shoeprints.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(theme.accent)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Self.number.string(from: NSNumber(value: steps)) ?? "\(steps)")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(theme.accentDeep)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("steps today")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 16).fill(HomeStyle.innerCard))
            }
            .buttonStyle(TilePressStyle())

            HStack(spacing: 0) {
                mini("drop.fill", .rgb(40, 140, 255), "\(e.waterGlasses)/\(e.waterGoal)", "water", .waterTracker)
                mini("fork.knife", .rgb(255, 150, 30), "\(e.meals.totalCalories)", "kcal", .foodTracker)
                mini("moon.fill", .rgb(150, 110, 245),
                     e.sleep.durationHours == nil ? "--" : e.sleep.durationString, "sleep", .sleepTracker)
                mini("pills.fill", .rgb(40, 200, 120),
                     active == 0 ? "0" : "\(taken)/\(active)", "meds", .medications)
            }
        }
    }

    private func mini(_ symbol: String, _ color: Color, _ value: String, _ label: String,
                      _ section: AppSection) -> some View {
        Button { openSection(section) } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(HomeStyle.innerCard))
                Text(value)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Finance tile

private struct FinanceTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let action: () -> Void

    /// Spending in each of the last three weeks, oldest first, for the bars.
    private var weeklySpend: [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: vm.selectedDate)
        return (0..<3).reversed().map { weeksAgo in
            (0..<7).reduce(0.0) { sum, d in
                guard let day = cal.date(byAdding: .day, value: -(weeksAgo * 7 + d), to: today) else { return sum }
                return sum + (vm.entries[vm.dateKey(for: day)]?.totalExpenses ?? 0)
            }
        }
    }

    var body: some View {
        let theme = HomeTileTheme.finance
        let spent = vm.monthlyTotalExpenses(for: vm.selectedDate)
        let weeks = weeklySpend
        let peak = max(weeks.max() ?? 0, 0.0001)
        let sym = vm.settings.currency.symbol

        HomeTile(theme: theme, icon: "dollarsign", title: "Finance Tracker",
                 subtitle: "Track your income and expenses", action: action) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spent > 0 ? "\(sym)\(Self.amount(spent))" : "No spending yet")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.primary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(spent > 0 ? "spent this month" : "This month")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        let h: CGFloat = spent > 0 ? max(10, CGFloat(weeks[i] / peak) * 44) : [20, 32, 44][i]
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [theme.accent, theme.accentDeep],
                                                 startPoint: .top, endPoint: .bottom))
                            .opacity(spent > 0 ? 1 : 0.55)
                            .frame(width: 11, height: h)
                    }
                }
            }
            .padding(12)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .background(RoundedRectangle(cornerRadius: 16).fill(HomeStyle.innerCard))
        }
    }

    private static func amount(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.0f", v) : String(format: v.rounded() == v ? "%.0f" : "%.2f", v)
    }
}

// MARK: - Schedule tile

private struct ScheduleTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let action: () -> Void

    private static let time: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    var body: some View {
        let e = vm.currentEntry
        let theme = HomeTileTheme.schedule
        let appts = e.appointments.filter { !$0.isCompleted }.sorted { $0.time < $1.time }
        let blocks = e.dailySchedule.filter { !$0.isCompleted }
        let count = appts.count + blocks.count
        let next: String = {
            if let a = appts.first { return "\(a.title) · \(Self.time.string(from: a.time))" }
            if let b = blocks.first { return "\(b.activity) · \(b.startTime)" }
            return "No upcoming events"
        }()

        HomeTile(theme: theme, icon: "calendar", title: "My Schedule",
                 subtitle: "Plan your day with ease", action: action) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 0 ? "All clear" : "\(count) upcoming")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.primary)
                    Text(next)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .background(RoundedRectangle(cornerRadius: 16).fill(HomeStyle.innerCard))

                TileArt(symbol: "calendar", color: theme.accentDeep, size: 44, rotation: 8)
                    .padding(8)
            }
        }
    }
}

// MARK: - Journal tile

private struct JournalTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let action: () -> Void

    var body: some View {
        let e = vm.currentEntry
        let theme = HomeTileTheme.journal
        let status: String? = {
            if !e.notes.isEmpty && e.rating.mood > 0 { return "Note written · Day rated" }
            if !e.notes.isEmpty { return "Note written today" }
            if e.rating.mood > 0 { return "Day rated" }
            return nil
        }()

        ZStack(alignment: .trailing) {
            HomeTile(theme: theme, icon: "square.and.pencil", title: "Notes & Journal",
                     subtitle: status ?? "Capture thoughts, ideas and memories", action: action) {
                EmptyView()
            }
            TileArt(symbol: "doc.plaintext.fill", color: theme.accentDeep, size: 70, rotation: 10)
                .padding(.trailing, 44)
                .padding(.top, 20)
        }
    }
}

// MARK: - Bottom bar

enum HomeTab: String, CaseIterable, Identifiable {
    case home = "Home", todo = "To-Do", health = "Health",
         finance = "Finance", schedule = "Schedule", journal = "Journal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .todo:     return "checkmark.square"
        case .health:   return "heart"
        case .finance:  return "chart.bar"
        case .schedule: return "calendar"
        case .journal:  return "doc.text"
        }
    }

    /// The tab that stands for where the user is.
    static func current(section: AppSection, hub: HomeTileGroup?) -> HomeTab {
        if section == .overview, hub == nil { return .home }
        let group = section == .overview ? hub : HomeTileGroup.group(for: section)
        switch group {
        case .tasks:    return .todo
        case .health:   return .health
        case .finance:  return .finance
        case .schedule: return .schedule
        case .journal:  return .journal
        case .none:     return .home
        }
    }
}

struct HomeBottomBar: View {
    let active: HomeTab
    let onSelect: (HomeTab) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HomeTab.allCases) { tab in
                let on = tab == active
                Button { onSelect(tab) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: on ? .bold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: on ? .bold : .medium))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundColor(on ? HomeStyle.blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(on ? HomeStyle.softBlue : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(TilePressStyle())
                .accessibilityLabel(tab == .home ? "Home" : "Add to \(tab.rawValue)")
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 26).fill(HomeStyle.card))
        .shadow(color: .black.opacity(0.10), radius: 14, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

// MARK: - Quick To-Do page

/// Opened from To-Do in the bottom bar: write the task, choose which list it
/// belongs to, add notes or a repeat, and save.
struct QuickTodoSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var recurrence: Recurrence = .none
    @AppStorage("quickTodoList") private var listRaw = AppSection.toDoLists.rawValue
    @State private var showUpgrade = false
    @State private var savedCount = 0
    @FocusState private var titleFocused: Bool

    private struct ListChoice: Identifiable {
        let section: AppSection
        let hint: String
        var id: String { section.rawValue }
    }

    private let lists: [ListChoice] = [
        ListChoice(section: .topPriorities, hint: "Most important today"),
        ListChoice(section: .toDoLists, hint: "General tasks"),
        ListChoice(section: .callsEmails, hint: "Calls to make, emails to send"),
        ListChoice(section: .personalTodo, hint: "Home, family, errands"),
    ]

    private var list: AppSection { AppSection(rawValue: listRaw) ?? .toDoLists }
    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM"; return f
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you need to do?")
                            .font(.system(size: 17, weight: .bold))
                        TextField(placeholder, text: $title, axis: .vertical)
                            .focused($titleFocused)
                            .font(.system(size: 17))
                            .lineLimit(1...4)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                        Text("For \(Self.dateFormat.string(from: vm.selectedDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add to")
                            .font(.system(size: 17, weight: .bold))
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                                  spacing: 10) {
                            ForEach(lists) { choice in
                                listCard(choice.section, hint: choice.hint)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 17, weight: .bold))
                        TextField("Optional details", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                    }

                    HStack {
                        Label("Repeat", systemImage: "repeat")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        if pro.isPro {
                            Picker("Repeat", selection: $recurrence) {
                                ForEach(Recurrence.allCases) { r in Text(r.rawValue).tag(r) }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Button { showUpgrade = true } label: { ProInlineBadge() }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))

                    if savedCount > 0 {
                        Label("\(savedCount) added to \(list.rawValue)", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle("New To-Do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(savedCount > 0 ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Open list") {
                        let target = list
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.25)) { vm.selectedSection = target }
                        }
                    }
                }
            }
            .onAppear { titleFocused = true }
            .sheet(isPresented: $showUpgrade) { ProUpgradeView().environmentObject(pro) }
        }
    }

    private var placeholder: String {
        switch list {
        case .topPriorities: return "e.g. Finish the project report"
        case .callsEmails:   return "e.g. Call the bank about the card"
        case .personalTodo:  return "e.g. Pick up groceries"
        default:             return "e.g. Book the car service"
        }
    }

    private func listCard(_ section: AppSection, hint: String) -> some View {
        let on = section == list
        return Button {
            withAnimation(.snappy) { listRaw = section.rawValue }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: section.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(on ? .white : section.color)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(on ? section.color : section.color.opacity(0.14)))
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(on ? section.color : .secondary.opacity(0.5))
                }
                Text(section.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(on ? section.color : Color.clear, lineWidth: 2))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var saveBar: some View {
        HStack(spacing: 10) {
            Button { save(closing: false) } label: {
                Text("Add another")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(list.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(list.color.opacity(0.14)))
            }
            Button { save(closing: true) } label: {
                Text("Add to \(list.rawValue)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(list.color))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(trimmed.isEmpty)
        .opacity(trimmed.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func save(closing: Bool) {
        guard !trimmed.isEmpty else { return }
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        switch list {
        case .topPriorities: vm.addTopPriority(trimmed, recurrence: recurrence, notes: note)
        case .callsEmails:   vm.addCallEmail(trimmed, recurrence: recurrence, notes: note)
        case .personalTodo:  vm.addPersonalTodo(trimmed, recurrence: recurrence, notes: note)
        default:             vm.addToDoListItem(trimmed, recurrence: recurrence, notes: note)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if closing {
            dismiss()
        } else {
            withAnimation { savedCount += 1 }
            title = ""
            notes = ""
            titleFocused = true
        }
    }
}

// MARK: - Quick actions (Health, Finance, Schedule, Journal)

/// What a quick action does once its card is tapped.
enum QuickAction {
    case open(AppSection)
    case form(QuickForm)
    case addWater
}

/// Forms opened straight from a quick action.
enum QuickForm: String, Identifiable {
    case expense, income, saving, appointment, timeBlock
    var id: String { rawValue }
}

struct QuickActionItem: Identifiable {
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let action: QuickAction
    var id: String { title }
}

extension HomeTab {
    /// The quick actions offered for each area.
    var quickActions: [QuickActionItem] {
        switch self {
        case .health:
            return [
                .init(title: "Add a glass of water", detail: "Counts toward today's goal", icon: "drop.fill",
                      color: .rgb(40, 140, 255), action: .addWater),
                .init(title: "Log a meal", detail: "Breakfast, lunch, dinner or a snack", icon: "fork.knife",
                      color: .rgb(255, 150, 30), action: .open(.foodTracker)),
                .init(title: "Steps & workouts", detail: "Activity and calories burned", icon: "figure.run",
                      color: .rgb(255, 92, 122), action: .open(.healthFitness)),
                .init(title: "Log sleep", detail: "Bedtime, wake-up and quality", icon: "moon.zzz.fill",
                      color: .rgb(150, 110, 245), action: .open(.sleepTracker)),
                .init(title: "Medications", detail: "Mark today's doses taken", icon: "pills.fill",
                      color: .rgb(40, 200, 120), action: .open(.medications)),
                .init(title: "Habits", detail: "Tick off today's habits", icon: "checkmark.seal.fill",
                      color: .rgb(20, 170, 170), action: .open(.habits)),
            ]
        case .finance:
            return [
                .init(title: "Add an expense", detail: "Money spent", icon: "minus.circle.fill",
                      color: .red, action: .form(.expense)),
                .init(title: "Add income", detail: "Salary, refunds, transfers in", icon: "plus.circle.fill",
                      color: .rgb(17, 168, 90), action: .form(.income)),
                .init(title: "Add a saving", detail: "Deposits and investments", icon: "banknote.fill",
                      color: .rgb(60, 110, 240), action: .form(.saving)),
                .init(title: "Open Finance Tracker", detail: "Budgets, trends and Gmail sync", icon: "chart.bar.fill",
                      color: .rgb(47, 180, 110), action: .open(.expenseTracker)),
            ]
        case .schedule:
            return [
                .init(title: "New appointment", detail: "With a time and reminder", icon: "calendar.badge.plus",
                      color: .rgb(142, 108, 245), action: .form(.appointment)),
                .init(title: "Plan a time block", detail: "Add to today's day plan", icon: "clock.fill",
                      color: .rgb(90, 120, 245), action: .form(.timeBlock)),
                .init(title: "Subscriptions", detail: "Upcoming renewals", icon: "repeat.circle.fill",
                      color: .rgb(106, 69, 224), action: .open(.subscriptions)),
                .init(title: "Open My Schedule", detail: "Day plan and appointments", icon: "calendar",
                      color: .rgb(120, 90, 230), action: .open(.dailySchedule)),
            ]
        case .journal:
            return [
                .init(title: "Write a note", detail: "Thoughts, ideas, memories", icon: "square.and.pencil",
                      color: .rgb(255, 138, 31), action: .open(.notes)),
                .init(title: "Rate your day", detail: "How did today go?", icon: "star.fill",
                      color: .rgb(255, 177, 61), action: .open(.rateYourDay)),
            ]
        default:
            return []
        }
    }

    var quickTitle: String {
        switch self {
        case .health:   return "Health"
        case .finance:  return "Finance"
        case .schedule: return "Schedule"
        case .journal:  return "Journal"
        default:        return rawValue
        }
    }
}

/// A half-height page of large action cards for one area.
struct QuickActionsSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    let tab: HomeTab
    /// Runs after the sheet is gone, so a follow-up sheet or page can open.
    let onChoose: (QuickAction) -> Void

    @State private var waterAdded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(tab.quickActions) { item in
                        Button { choose(item) } label: { card(item) }
                            .buttonStyle(TilePressStyle())
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(tab.quickTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func card(_ item: QuickActionItem) -> some View {
        let isWater: Bool = { if case .addWater = item.action { return true }; return false }()
        let e = vm.currentEntry
        return HStack(spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 13).fill(item.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text(isWater ? "\(e.waterGlasses) of \(e.waterGoal) glasses today" : item.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: isWater ? (waterAdded ? "checkmark.circle.fill" : "plus.circle.fill") : "chevron.right")
                .font(.system(size: isWater ? 24 : 14, weight: .bold))
                .foregroundColor(isWater ? item.color : .secondary.opacity(0.6))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func choose(_ item: QuickActionItem) {
        if case .addWater = item.action {
            // Done right here — no page to open.
            vm.incrementWater()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation { waterAdded = true }
            return
        }
        onChoose(item.action)
        dismiss()
    }
}
