import SwiftUI
import UIKit

// MARK: - Health Tracker page
//
// The Health group's own page, built from the supplied design: a large
// title header, a date card, and six two-column tiles that show each
// tracker's figures for the selected day, with a quick action on the lower
// four. Tiles keep their colours but use a thin coloured border and a very
// soft shadow instead of a bright glow.

private func hc(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r / 255, green: g / 255, blue: b / 255)
}

/// One tile's colours.
private struct HealthTheme {
    let accent: Color
    let deep: Color

    static let steps  = HealthTheme(accent: hc(242, 72, 112),  deep: hc(222, 40, 88))
    static let water  = HealthTheme(accent: hc(40, 150, 255),  deep: hc(16, 112, 235))
    static let food   = HealthTheme(accent: hc(247, 146, 24),  deep: hc(226, 112, 6))
    static let sleep  = HealthTheme(accent: hc(112, 84, 232),  deep: hc(84, 56, 210))
    static let meds   = HealthTheme(accent: hc(30, 184, 132),  deep: hc(14, 150, 104))
    static let habits = HealthTheme(accent: hc(124, 86, 238),  deep: hc(96, 58, 220))
}

private enum HealthStyle {
    static let card = Color.adaptive(light: .white, dark: UIColor(white: 0.13, alpha: 1))
    static let inner = Color.adaptive(light: UIColor(white: 1, alpha: 0.82),
                                      dark: UIColor(white: 1, alpha: 0.08))
    static let blue = hc(31, 120, 255)
}

struct HealthHubPage: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager

    /// Steps per hour for the chart; empty until Apple Health is linked.
    @State private var hourlySteps: [Double] = []
    /// Bumped by Today so the date strip re-centres.
    @State private var recenter = 0
    /// Add Habit opens the new-habit form here, not the habits list.
    @State private var showAddHabit = false
    @State private var showUpgrade = false

    var body: some View {
        GeometryReader { geo in
            // Everything is sized to the screen so the page sits still, like
            // the front page. Only a phone too short for the minimum tile
            // sizes scrolls, and it doesn't bounce once the content fits.
            let spacing: CGFloat = 8
            let side: CGFloat = 10
            let header: CGFloat = 86
            let dateCard: CGFloat = 100
            let tileWidth = (geo.size.width - side * 2 - spacing) / 2
            let free = geo.size.height - 2 - header - dateCard - spacing * 2 - spacing * 2 - 4
            let rows = max(free, 450)
            let row1 = max(170, rows * 0.38)
            let row2 = (rows - row1) / 2

            ScrollView(showsIndicators: false) {
                VStack(spacing: spacing) {
                    CategoryHeader(title: "Health Tracker",
                                   subtitle: "Small habits. A healthier, happier you",
                                   titleIcon: "heart", color: hc(245, 100, 150), emblem: "heart.fill",
                                   onBack: goHome, onToday: {
                        withAnimation(.spring(response: 0.3)) { vm.selectToday() }
                        recenter += 1
                    })
                    .frame(height: header)
                    .padding(.horizontal, 6)

                    CategoryDateCard(recenter: recenter)
                        .frame(height: dateCard)

                    VStack(spacing: spacing) {
                        row(spacing, height: row1) {
                            StepsTile(hourly: hourlySteps) { open(.healthFitness) }
                            WaterTile { open(.waterTracker) }
                        }
                        row(spacing, height: row2) {
                            FoodTile { open(.foodTracker) }
                            SleepTile { open(.sleepTracker) }
                        }
                        row(spacing, height: row2) {
                            MedsTile { open(.medications) }
                            HabitsTile(action: { open(.habits) }, addHabit: {
                                if pro.isPro { showAddHabit = true } else { showUpgrade = true }
                            })
                        }
                    }
                    .environment(\.healthTitleSize, Self.titleSize(for: tileWidth))
                }
                .padding(.horizontal, side)
                .padding(.top, 2)
                .padding(.bottom, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(HomeBackground().ignoresSafeArea())
        .sheet(isPresented: $showAddHabit) {
            HabitEditSheet(habit: nil) { vm.addHabit($0) }
        }
        .sheet(isPresented: $showUpgrade) {
            ProUpgradeView().environmentObject(pro)
        }
        .onAppear {
            loadHourlySteps()
            vm.syncSleepFromHealth(for: vm.selectedDate)
        }
        .onChange(of: vm.selectedDate) { _, date in
            loadHourlySteps()
            vm.syncSleepFromHealth(for: date)
        }
    }

    /// Two tiles side by side, filling the row.
    private func row<C: View>(_ spacing: CGFloat, height: CGFloat,
                              @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: spacing) { content() }
            .frame(height: height)
    }

    /// One title size for every tile: the largest at which the longest name
    /// still fits beside the icon and chevron.
    private static func titleSize(for tileWidth: CGFloat) -> CGFloat {
        // tile padding 20, icon 34, gaps 8 + 8, chevron 9, a little slack
        let room = tileWidth - 89
        let width = ("Steps & Activity" as NSString)
            .size(withAttributes: [.font: UIFont.systemFont(ofSize: 16, weight: .bold)]).width
        return min(15, max(11, 16 * room / max(width, 1)))
    }

    private func loadHourlySteps() {
        let hk = HealthKitManager.shared
        guard hk.isAvailable, hk.isLinkedByUser else { hourlySteps = []; return }
        let day = vm.selectedDate
        hk.fetchHourlySteps(for: day) { hours in
            if Calendar.current.isDate(day, inSameDayAs: vm.selectedDate) { hourlySteps = hours }
        }
    }

    private func open(_ section: AppSection) {
        withAnimation(.easeInOut(duration: 0.25)) { vm.selectedSection = section }
    }

    private func goHome() {
        withAnimation(.easeInOut(duration: 0.25)) {
            vm.activeHub = nil
            vm.selectedSection = .overview
        }
    }
}

private struct HealthTitleSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 16
}

private extension EnvironmentValues {
    var healthTitleSize: CGFloat {
        get { self[HealthTitleSizeKey.self] }
        set { self[HealthTitleSizeKey.self] = newValue }
    }
}

// MARK: - Header

/// The shared page header of the main category pages, as designed for the
/// Health Tracker: "‹ Daily Planner" back link and Today at the top, the
/// page title large at the top left with a small icon, a one-line subtitle,
/// and leaves with the page's emblem behind Today.
struct CategoryHeader: View {
    let title: String
    let subtitle: String
    /// Small outline icon after the title.
    let titleIcon: String
    /// The page's colour, for the title icon and emblem.
    let color: Color
    /// Filled emblem among the leaves.
    let emblem: String
    let onBack: () -> Void
    let onToday: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Leaves and the page's emblem behind the Today button.
            HeaderArt(emblem: emblem, color: color)
                .scaleEffect(0.8, anchor: .topTrailing)
                .offset(x: 14, y: 30)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Daily Planner")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(HealthStyle.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                    Button(action: onToday) {
                        HStack(spacing: 7) {
                            Image(systemName: "calendar")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(HealthStyle.blue)
                            Text("Today")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 13).padding(.vertical, 6)
                        .background(Capsule().fill(HealthStyle.card))
                        .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
                    }
                    .buttonStyle(TilePressStyle())
                }

                HStack(alignment: .top, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.primary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: titleIcon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                        .padding(.top, 3)
                }
                .padding(.top, 2)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }
}

private struct HeaderArt: View {
    let emblem: String
    let color: Color

    var body: some View {
        ZStack {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40))
                .foregroundColor(hc(120, 190, 140).opacity(0.35))
                .rotationEffect(.degrees(-30))
                .offset(x: -44, y: 18)
            Image(systemName: "leaf.fill")
                .font(.system(size: 52))
                .foregroundColor(hc(110, 180, 200).opacity(0.30))
                .rotationEffect(.degrees(20))
                .offset(x: 6, y: 26)
            Image(systemName: "leaf.fill")
                .font(.system(size: 34))
                .foregroundColor(hc(140, 200, 150).opacity(0.35))
                .rotationEffect(.degrees(60))
                .offset(x: 34, y: -6)
            Image(systemName: emblem)
                .font(.system(size: 34))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.75), color],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: color.opacity(0.25), radius: 6, y: 3)
                .offset(x: -14, y: 6)
        }
        .frame(width: 120, height: 90)
    }
}

// MARK: - Date card

/// The shared date card of the main category pages.
struct CategoryDateCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    let recenter: Int

    init(recenter: Int) { self.recenter = recenter }
    @State private var showMonthWheel = false

    private let cal = Calendar.current

    private static let monthFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private static let weekdayFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()

    private var days: [Date] {
        guard let range = cal.range(of: .day, in: .month, for: vm.selectedDate),
              let start = cal.date(from: cal.dateComponents([.year, .month], from: vm.selectedDate))
        else { return [] }
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 22) {
                monthButton("chevron.left", by: -1)
                Button { showMonthWheel = true } label: {
                    Text(Self.monthFormat.string(from: vm.selectedDate))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                monthButton("chevron.right", by: 1)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(days, id: \.self) { day in
                            dayCell(day)
                                .id(cal.component(.day, from: day))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) { vm.select(date: day) }
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onAppear { scroll(proxy, animated: false) }
                .onChange(of: vm.selectedDate) { _, _ in scroll(proxy, animated: true) }
                .onChange(of: recenter) { _, _ in scroll(proxy, animated: true) }
            }
        }
        .padding(.vertical, 7)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(HealthStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.04), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .sheet(isPresented: $showMonthWheel) {
            MonthYearWheel()
                .environmentObject(vm)
                .presentationDetents([.height(320)])
        }
    }

    private func monthButton(_ symbol: String, by months: Int) -> some View {
        Button {
            if let d = cal.date(byAdding: .month, value: months, to: vm.selectedDate) {
                withAnimation(.spring(response: 0.3)) { vm.select(date: d) }
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 28, height: 26)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        let target = cal.component(.day, from: vm.selectedDate)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target, anchor: .center) }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = cal.isDate(day, inSameDayAs: vm.selectedDate)
        let today = cal.isDateInToday(day)
        let hasData = vm.entries[vm.dateKey(for: day)]?.hasData ?? false

        return VStack(spacing: 3) {
            Text(Self.weekdayFormat.string(from: day))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(selected ? .white.opacity(0.92) : .secondary)
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? .white : .primary)
            Circle()
                .fill(selected ? Color.white : HealthStyle.blue)
                .frame(width: 4, height: 4)
                .opacity(hasData || selected ? 1 : 0)
        }
        .frame(width: 34, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selected
                      ? AnyShapeStyle(LinearGradient(colors: [hc(40, 150, 255), hc(12, 104, 240)],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.clear))
                .shadow(color: selected ? HealthStyle.blue.opacity(0.25) : .clear, radius: 5, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(HealthStyle.blue.opacity(today && !selected ? 0.35 : 0), lineWidth: 1.2)
        )
        .padding(.horizontal, 1)
        .contentShape(Rectangle())
    }
}

// MARK: - Tile chrome

/// Pastel wash, thin coloured border, very soft shadow; icon disc, title,
/// subtitle and chevron on top, `content` below, `art` behind.
private struct HealthTile<Content: View, Art: View>: View {
    @Environment(\.healthTitleSize) private var titleSize
    let theme: HealthTheme
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let art: Art

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                HealthStyle.card
                LinearGradient(colors: [theme.accent.opacity(0.11), theme.accent.opacity(0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                art
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: [theme.accent, theme.deep],
                                                            startPoint: .top, endPoint: .bottom))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(HealthStyle.card))
                            .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: titleSize, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(subtitle)
                                .font(.system(size: max(10, titleSize - 4)))
                                .foregroundColor(.secondary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    content
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22)
                .strokeBorder(theme.accent.opacity(0.18), lineWidth: 1))
            .shadow(color: theme.accent.opacity(0.07), radius: 10, y: 4)
        }
        .buttonStyle(TilePressStyle())
    }
}

/// The big figure and its unit, e.g. "0 kcal".
private struct BigFigure: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

/// The white "+ Add …  >" bar at the foot of the lower tiles.
private struct TileActionBar: View {
    let title: String
    let theme: HealthTheme
    var proLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(LinearGradient(colors: [theme.accent, theme.deep],
                                                             startPoint: .top, endPoint: .bottom)))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.deep)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 2)
                if proLocked {
                    ProInlineBadge()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.leading, 5).padding(.trailing, 10).padding(.vertical, 4)
            .background(Capsule().fill(HealthStyle.inner))
            .overlay(Capsule().strokeBorder(theme.accent.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Steps & Activity

private struct StepsTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let hourly: [Double]
    let action: () -> Void

    /// 6am to midnight, as on the design.
    private let hours = Array(6..<24)

    var body: some View {
        let theme = HealthTheme.steps
        let e = vm.currentEntry
        let steps = e.fitness.displaySteps
        let goal = max(1, vm.settings.stepsTarget)
        let fraction = min(1, Double(steps) / Double(goal))
        let left = max(0, goal - steps)

        HealthTile(theme: theme, icon: "shoeprints.fill", title: "Steps & Activity",
                   subtitle: "Move more, feel better", action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(steps.formatted())
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(theme.deep)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("steps today")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("\(e.fitness.displayCalories) kcal")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.deep)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(Capsule().fill(HealthStyle.inner))
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                }

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [theme.accent, theme.deep],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(fraction > 0 ? 8 : 0, g.size.width * fraction))
                    }
                }
                .frame(height: 7)

                HStack {
                    Text("\(Int((fraction * 100).rounded()))% of \(goal.formatted()) steps")
                    Spacer(minLength: 4)
                    Text(left == 0 ? "Goal reached" : "\(left.formatted()) to go")
                }
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)

                chart(theme)
            }
        } art: {
            EmptyView()
        }
    }

    /// Hourly bars that take whatever height the tile has left, so the
    /// tile has no empty band at the bottom.
    private func chart(_ theme: HealthTheme) -> some View {
        let values = hours.map { hourly.indices.contains($0) ? hourly[$0] : 0 }
        let peak = max(values.max() ?? 0, 1)

        return VStack(spacing: 3) {
            GeometryReader { g in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(values.indices, id: \.self) { i in
                        let v = values[i]
                        Group {
                            if v > 0 {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.75)],
                                                         startPoint: .top, endPoint: .bottom))
                                    .frame(width: 5, height: max(5, CGFloat(v / peak) * (g.size.height - 2)))
                            } else {
                                Circle()
                                    .fill(theme.accent.opacity(0.35))
                                    .frame(width: 3.5, height: 3.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: g.size.width, height: g.size.height, alignment: .bottom)
            }
            .frame(minHeight: 14, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.accent.opacity(0.18))
                    .frame(height: 0.8)
                    .offset(y: 1)
            }

            HStack {
                Text("6am"); Spacer(); Text("12pm"); Spacer(); Text("6pm"); Spacer(); Text("12am")
            }
            .font(.system(size: 9.5))
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Water

private struct WaterTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let action: () -> Void

    var body: some View {
        let theme = HealthTheme.water
        let e = vm.currentEntry
        let glasses = e.waterGlasses
        let goal = max(1, e.waterGoal)
        let shown = min(goal, 10)
        let fraction = min(1, Double(glasses) / Double(goal))

        HealthTile(theme: theme, icon: "drop.fill", title: "Water Tracker",
                   subtitle: "Stay hydrated", action: action) {
            VStack(alignment: .leading, spacing: 8) {
                (Text("\(glasses)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.deep)
                 + Text("  of  ").font(.system(size: 14)).foregroundColor(.secondary)
                 + Text("\(goal)").font(.system(size: 18, weight: .heavy)).foregroundColor(.primary)
                 + Text("  glasses").font(.system(size: 14)).foregroundColor(.secondary))
                    .lineLimit(1).minimumScaleFactor(0.7)

                // Tap a glass to fill up to it; tap the last full one to empty it.
                HStack(spacing: 3) {
                    ForEach(0..<shown, id: \.self) { i in
                        let full = i < glasses
                        GlassShape()
                            .fill(full ? AnyShapeStyle(LinearGradient(colors: [theme.accent.opacity(0.75), theme.deep],
                                                                      startPoint: .top, endPoint: .bottom))
                                       : AnyShapeStyle(Color.clear))
                            .overlay(GlassShape().stroke(theme.accent.opacity(full ? 0.9 : 0.4),
                                                         style: StrokeStyle(lineWidth: 1.4, lineJoin: .round)))
                            .frame(maxWidth: 18)
                            .frame(height: 20)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !vm.isFuture else { action(); return }
                                setGlasses(i + 1 == glasses ? i : i + 1)
                            }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int((fraction * 100).rounded()))% of goal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [theme.accent, theme.deep],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * fraction)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.horizontal, 11).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14).fill(HealthStyle.inner))
            }
        } art: {
            ZStack(alignment: .bottomTrailing) {
                WaterWave()
                    .fill(LinearGradient(colors: [theme.accent.opacity(0.30), theme.accent.opacity(0.55)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 34)
                Image(systemName: "drop.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accent.opacity(0.55))
                    .rotationEffect(.degrees(25))
                    .offset(x: -12, y: -26)
                Image(systemName: "drop.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent.opacity(0.45))
                    .rotationEffect(.degrees(-20))
                    .offset(x: -32, y: -21)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func setGlasses(_ target: Int) {
        var current = vm.currentEntry.waterGlasses
        while current < target { vm.incrementWater(); current += 1 }
        while current > target { vm.decrementWater(); current -= 1 }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct GlassShape: Shape {
    func path(in r: CGRect) -> Path {
        let taper = r.width * 0.14
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - taper, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + taper, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Rolling water along the bottom of the Water tile.
private struct WaterWave: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.45))
        p.addCurve(to: CGPoint(x: r.width * 0.5, y: r.minY + r.height * 0.55),
                   control1: CGPoint(x: r.width * 0.18, y: r.minY - r.height * 0.05),
                   control2: CGPoint(x: r.width * 0.32, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.25),
                   control1: CGPoint(x: r.width * 0.68, y: r.minY + r.height * 0.1),
                   control2: CGPoint(x: r.width * 0.86, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Food

private struct FoodTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    let action: () -> Void

    var body: some View {
        let theme = HealthTheme.food
        let kcal = vm.currentEntry.meals.totalCalories

        HealthTile(theme: theme, icon: "fork.knife", title: "Food Tracker",
                   subtitle: "Eat healthy, stay strong", action: action) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    BigFigure(value: "\(kcal)", unit: "kcal", color: theme.deep)
                    Text(kcal > 0 ? "logged today" : "No meals yet")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                if !vm.isFuture {
                    TileActionBar(title: "Add Meal", theme: theme, action: action)
                }
            }
        } art: {
            Text("🥗")
                .font(.system(size: 44))
                .shadow(color: theme.accent.opacity(0.15), radius: 6, y: 3)
                .padding(.trailing, 8)
                .padding(.bottom, vm.isFuture ? 10 : 46)
        }
    }
}

// MARK: - Sleep

private struct SleepTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    let action: () -> Void

    var body: some View {
        let theme = HealthTheme.sleep
        let sleep = vm.currentEntry.sleep
        let logged = sleep.durationHours != nil

        HealthTile(theme: theme, icon: "moon.fill", title: "Sleep Tracker",
                   subtitle: "Rest for a brighter you", action: action) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    if logged {
                        BigFigure(value: sleep.durationString, unit: "slept", color: theme.deep)
                    } else {
                        Text("Not logged yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.deep)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.vertical, 3)
                    }
                    Text(logged ? "Last night" : "Tap to add your sleep")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                TileActionBar(title: "Log Sleep", theme: theme, proLocked: !pro.isPro, action: action)
            }
        } art: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 44))
                    .foregroundColor(theme.accent.opacity(0.12))
                    .offset(x: -6, y: 2)
                Text("z")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.accent.opacity(0.7))
                    .offset(x: -44, y: -20)
                Text("Z")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.accent.opacity(0.75))
                    .offset(x: -28, y: -32)
                Text("Z")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.accent.opacity(0.85))
                    .offset(x: -8, y: -46)
                Image(systemName: "sparkle")
                    .font(.system(size: 9))
                    .foregroundColor(theme.accent.opacity(0.5))
                    .offset(x: -60, y: -34)
            }
            .padding(.trailing, 10)
            .padding(.bottom, 46)
        }
    }
}

// MARK: - Medications

private struct MedsTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    let action: () -> Void

    var body: some View {
        let theme = HealthTheme.meds
        let active = vm.settings.medications.filter(\.isActive).count
        let taken = vm.todayMedicationLogs.count

        HealthTile(theme: theme, icon: "pills.fill", title: "Medications",
                   subtitle: "Stay on track", action: action) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    BigFigure(value: "\(active)", unit: active == 1 ? "medication" : "medications",
                              color: theme.deep)
                    Text(active == 0 ? "None active" : "\(taken) taken today")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                TileActionBar(title: "Add Medication", theme: theme, proLocked: !pro.isPro, action: action)
            }
        } art: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26))
                    .foregroundColor(theme.accent.opacity(0.20))
                    .rotationEffect(.degrees(-35))
                    .offset(x: -48, y: 0)
                Image(systemName: "pills.fill")
                    .font(.system(size: 46))
                    .foregroundColor(theme.accent.opacity(0.22))
            }
            .padding(.trailing, 12)
            .padding(.bottom, 46)
        }
    }
}

// MARK: - Habits

private struct HabitsTile: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    let action: () -> Void
    let addHabit: () -> Void

    var body: some View {
        let theme = HealthTheme.habits
        let habits = vm.settings.habits
        let done = habits.filter { vm.isHabitCompleted($0, for: vm.selectedDate) }.count

        HealthTile(theme: theme, icon: "scope", title: "Habit Tracker",
                   subtitle: "Build better habits", action: action) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    BigFigure(value: habits.isEmpty ? "0" : "\(done)/\(habits.count)",
                              unit: habits.isEmpty ? "habits" : "done", color: theme.deep)
                    Text(habits.isEmpty ? "None yet" : "habits today")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                TileActionBar(title: "Add Habit", theme: theme, proLocked: !pro.isPro, action: addHabit)
            }
        } art: {
            Image(systemName: "checklist")
                .font(.system(size: 46, weight: .semibold))
                .foregroundColor(theme.accent.opacity(0.20))
                .rotationEffect(.degrees(8))
                .padding(.trailing, 12)
                .padding(.bottom, 46)
        }
    }
}
