import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showRolloverSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // App Header
            AppHeaderView()

            // Date Scroller
            DateScrollerView()

            // Section Tab Bar
            SectionTabBarView()

            // Main Content
            ZStack {
                currentSectionView
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .animation(.easeInOut(duration: 0.25), value: vm.selectedSection)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if vm.showRolloverAlert { showRolloverSheet = true }
        }
        .alert("Roll Over Tasks?", isPresented: $vm.showRolloverAlert) {
            Button("Yes, Roll Over") {
                vm.performRollover()
            }
            Button("No, Keep as Is", role: .cancel) {}
        } message: {
            Text("You have incomplete tasks from yesterday. Would you like to roll them over to today?")
        }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch vm.selectedSection {
        case .overview:         OverviewView()
        case .topPriorities:   TopPrioritiesView()
        case .toDoLists:       ToDoListsView()
        case .callsEmails:     CallsEmailsView()
        case .personalTodo:    PersonalTodoView()
        case .healthFitness:   HealthFitnessView()
        case .waterTracker:    WaterTrackerView()
        case .foodTracker:     FoodTrackerView()
        case .dailySchedule:   DailyScheduleView()
        case .appointments:    AppointmentsView()
        case .notes:           NotesView()
        case .notesForTomorrow: NotesForTomorrowView()
        case .expenseTracker:  ExpenseTrackerView()
        case .rateYourDay:     RateYourDayView()
        }
    }
}

// MARK: - App Header
struct AppHeaderView: View {
    @EnvironmentObject var vm: PlannerViewModel

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good Morning" }
        if h < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Planner")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.white)
                Text(greeting + " ✨")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Button(action: { vm.selectToday() }) {
                Text("Today")
                    .font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.25))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.18, blue: 0.78),
                         Color(red: 0.55, green: 0.25, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Section Tab Bar
struct SectionTabBarView: View {
    @EnvironmentObject var vm: PlannerViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppSection.allCases) { section in
                        SectionTabButton(section: section, isSelected: vm.selectedSection == section) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedSection = section
                                proxy.scrollTo(section.id, anchor: .center)
                            }
                        }
                        .id(section.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }
}

struct SectionTabButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(section.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? section.color : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .secondary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
