import SwiftUI

// MARK: - Home Dashboard
//
// The app's front page: a living, tile-based launcher. Related sections are
// grouped into themed tiles (office-style for tasks, wellness for health,
// money-green for finance…), each with softly animated artwork. Above the
// tiles, "Today's Pulse" tells the user at a glance what's trending up and
// what needs attention today.

// MARK: - Tile groups & themes

enum HomeTileGroup: String, CaseIterable, Identifiable {
    case tasks    = "To-Do List"
    case health   = "Health Tracker"
    case finance  = "Finance Tracker"
    case schedule = "My Schedule"
    case journal  = "Notes & Journal"

    var id: String { rawValue }

    /// The app sections that live inside this tile.
    var sections: [AppSection] {
        switch self {
        case .tasks:    return [.topPriorities, .toDoLists, .callsEmails, .personalTodo]
        case .health:   return [.healthFitness, .waterTracker, .foodTracker,
                                .sleepTracker, .medications, .habits]
        case .finance:  return [.expenseTracker]
        case .schedule: return [.dailySchedule, .appointments]
        case .journal:  return [.notes, .rateYourDay]
        }
    }

    var icon: String {
        switch self {
        case .tasks:    return "checklist"
        case .health:   return "heart.fill"
        case .finance:  return "dollarsign.circle.fill"
        case .schedule: return "calendar"
        case .journal:  return "square.and.pencil"
        }
    }

    var tagline: String {
        switch self {
        case .tasks:    return "Priorities · Lists · Calls"
        case .health:   return "Fitness · Water · Sleep"
        case .finance:  return "Income · Expenses · Savings"
        case .schedule: return "Day Plan · Appointments"
        case .journal:  return "Notes · Rate Your Day"
        }
    }

    /// Theme gradient — office blues for work, warm red for health,
    /// money green for finance, calm violet for schedule, amber for journal.
    var gradient: [Color] {
        switch self {
        case .tasks:    return [Color(red: 0.26, green: 0.36, blue: 0.95),
                                Color(red: 0.12, green: 0.20, blue: 0.62)]
        case .health:   return [Color(red: 0.98, green: 0.35, blue: 0.37),
                                Color(red: 0.72, green: 0.12, blue: 0.30)]
        case .finance:  return [Color(red: 0.10, green: 0.72, blue: 0.42),
                                Color(red: 0.02, green: 0.42, blue: 0.26)]
        case .schedule: return [Color(red: 0.55, green: 0.34, blue: 0.96),
                                Color(red: 0.30, green: 0.14, blue: 0.62)]
        case .journal:  return [Color(red: 0.96, green: 0.62, blue: 0.15),
                                Color(red: 0.72, green: 0.38, blue: 0.05)]
        }
    }

    /// Small decorative symbols that float inside the tile artwork,
    /// matching the group's world (office / wellness / money…).
    var decorSymbols: [String] {
        switch self {
        case .tasks:    return ["briefcase.fill", "paperclip", "doc.text.fill"]
        case .health:   return ["figure.run", "drop.fill", "moon.zzz.fill"]
        case .finance:  return ["banknote.fill", "chart.line.uptrend.xyaxis", "creditcard.fill"]
        case .schedule: return ["clock.fill", "bell.fill", "calendar.badge.clock"]
        case .journal:  return ["pencil", "book.fill", "sparkles"]
        }
    }

    /// The tile group a given section belongs to (for themed backgrounds).
    static func group(for section: AppSection) -> HomeTileGroup? {
        allCases.first { $0.sections.contains(section) }
    }
}

// MARK: - Dashboard

struct HomeDashboardView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Environment(\.isLiquidGlass) private var isGlass
    @State private var expandedGroup: HomeTileGroup? = nil
    @State private var appeared = false

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                pulseCard
                    .padding(.top, 14)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(HomeTileGroup.allCases.enumerated()), id: \.element) { index, group in
                        AnimatedGroupTile(group: group,
                                          headline: headline(for: group),
                                          delay: Double(index) * 0.07) {
                            open(group)
                        }
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.55)
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 30)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { appeared = true }
        }
        .sheet(item: $expandedGroup) { group in
            GroupDetailSheet(group: group)
                .environmentObject(vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func open(_ group: HomeTileGroup) {
        if group.sections.count == 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                vm.selectedSection = group.sections[0]
            }
        } else {
            expandedGroup = group
        }
    }

    // MARK: Tile headlines (live numbers)

    private func headline(for group: HomeTileGroup) -> String {
        let e = vm.currentEntry
        switch group {
        case .tasks:
            let total = e.allTasksCount
            return total == 0 ? "Plan your day" : "\(e.completedTasksCount) of \(total) done"
        case .health:
            let steps = e.fitness.displaySteps
            if steps > 0 { return "\(steps) steps today" }
            return "\(e.waterGlasses)/\(e.waterGoal) water"
        case .finance:
            let spent = e.totalExpenses
            return spent > 0
                ? "\(vm.settings.currency.symbol)\(String(format: "%.0f", spent)) spent today"
                : "No spending yet"
        case .schedule:
            let upcoming = e.appointments.filter { !$0.isCompleted }.count
                         + e.dailySchedule.filter { !$0.isCompleted }.count
            return upcoming == 0 ? "All clear" : "\(upcoming) upcoming"
        case .journal:
            if !e.notes.isEmpty { return "Notes written" }
            return e.rating.mood > 0 ? "Day rated" : "Capture a thought"
        }
    }

    // MARK: - Today's Pulse

    private var pulseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Today's Pulse")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(Date(), format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(spacing: 8) {
                ForEach(insights) { insight in
                    HStack(spacing: 10) {
                        Image(systemName: insight.icon)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 20)
                        Text(insight.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                        Spacer()
                        Text(insight.value)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: insight.isPositive
                              ? "arrow.up.right.circle.fill"
                              : "arrow.down.right.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(insight.isPositive
                                             ? Color(red: 0.45, green: 1.0, blue: 0.60)
                                             : Color(red: 1.0, green: 0.55, blue: 0.50))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.14, blue: 0.30),
                                 Color(red: 0.05, green: 0.06, blue: 0.16)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .padding(.horizontal, 16)
    }

    private struct PulseInsight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let value: String
        let isPositive: Bool
    }

    /// Up to four live signals — what's going well and what's slipping.
    private var insights: [PulseInsight] {
        var list: [PulseInsight] = []
        let cal = Calendar.current
        let today = vm.currentEntry
        let yesterday = vm.entry(for: cal.date(byAdding: .day, value: -1, to: vm.selectedDate) ?? vm.selectedDate)

        // Tasks: completion vs yesterday
        let todayRate = today.taskCompletionRate
        let yesterdayRate = yesterday.taskCompletionRate
        list.append(PulseInsight(
            icon: "checkmark.circle.fill",
            title: "Tasks completed",
            value: "\(Int(todayRate * 100))%",
            isPositive: todayRate >= yesterdayRate
        ))

        // Water progress
        let waterOK = today.waterGoal > 0 &&
                      Double(today.waterGlasses) / Double(today.waterGoal) >= 0.5
        list.append(PulseInsight(
            icon: "drop.fill",
            title: "Water intake",
            value: "\(today.waterGlasses)/\(today.waterGoal)",
            isPositive: waterOK
        ))

        // Steps vs target
        let steps = today.fitness.displaySteps
        list.append(PulseInsight(
            icon: "figure.walk",
            title: "Steps",
            value: "\(steps)",
            isPositive: steps >= vm.settings.stepsTarget / 2
        ))

        // Spending: today vs 7-day average (lower is positive)
        let last7 = (1...7).compactMap { back -> Double? in
            guard let d = cal.date(byAdding: .day, value: -back, to: vm.selectedDate) else { return nil }
            return vm.entry(for: d).totalExpenses
        }
        let avg = last7.isEmpty ? 0 : last7.reduce(0, +) / Double(last7.count)
        let spent = today.totalExpenses
        list.append(PulseInsight(
            icon: "creditcard.fill",
            title: "Spending vs 7-day avg",
            value: "\(vm.settings.currency.symbol)\(String(format: "%.0f", spent))",
            isPositive: spent <= avg || avg == 0
        ))

        return list
    }
}

// MARK: - Animated tile

struct AnimatedGroupTile: View {
    let group: HomeTileGroup
    let headline: String
    let delay: Double
    let action: () -> Void

    @State private var floatPhase = false
    @State private var shown = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Theme gradient canvas
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: group.gradient,
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))

                // Soft glow blob that breathes
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                    .offset(x: 48, y: floatPhase ? -58 : -46)

                // Floating decorative symbols — the "animated picture"
                ForEach(Array(group.decorSymbols.enumerated()), id: \.offset) { i, symbol in
                    Image(systemName: symbol)
                        .font(.system(size: i == 0 ? 30 : 18, weight: .semibold))
                        .foregroundColor(.white.opacity(i == 0 ? 0.22 : 0.16))
                        .offset(
                            x: [42.0, -46.0, 30.0][i % 3],
                            y: [-38.0, -6.0, 34.0][i % 3] + (floatPhase ? -6 : 6) * (i.isMultiple(of: 2) ? 1 : -1)
                        )
                        .rotationEffect(.degrees(floatPhase ? [8.0, -6.0, 5.0][i % 3] : [-4.0, 5.0, -6.0][i % 3]))
                }

                // Foreground content
                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.22))
                            .frame(width: 44, height: 44)
                        Image(systemName: group.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .symbolEffect(.pulse, options: .repeating.speed(0.6))
                    }
                    Spacer(minLength: 0)
                    Text(group.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(group.tagline)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(headline)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.18)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 165)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: group.gradient[0].opacity(0.40), radius: 10, y: 5)
        }
        .buttonStyle(TilePressStyle())
        .scaleEffect(shown ? 1 : 0.85)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(delay)) {
                shown = true
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(delay)) {
                floatPhase = true
            }
        }
    }
}

/// Gentle push-down on touch, like pressing a real key.
struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Group detail sheet

struct GroupDetailSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    let group: HomeTileGroup

    var body: some View {
        VStack(spacing: 0) {
            // Themed hero header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: group.gradient,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack(spacing: 12) {
                    Image(systemName: group.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, options: .repeating.speed(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.rawValue)
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(group.tagline)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(18)
            }
            .frame(height: 96)

            // Section rows
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(group.sections) { section in
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    vm.selectedSection = section
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(section.color.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: section.icon)
                                        .font(.system(size: 17))
                                        .foregroundColor(section.color)
                                }
                                Text(section.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                        .buttonStyle(TilePressStyle())
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Themed section backdrop

/// A soft, animated wash of the group's theme behind a section's content —
/// finance feels green, tasks feel office-blue, health feels warm.
struct ThemedSectionBackdrop: View {
    let section: AppSection

    var body: some View {
        if let group = HomeTileGroup.group(for: section) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: group.gradient.map { $0.opacity(0.10) },
                               startPoint: .top, endPoint: .bottom)
                Image(systemName: group.icon)
                    .font(.system(size: 150, weight: .bold))
                    .foregroundColor(group.gradient[0].opacity(0.06))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 30, y: -20)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
