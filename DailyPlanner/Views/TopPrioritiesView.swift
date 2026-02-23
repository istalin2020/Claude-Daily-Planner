import SwiftUI

struct TopPrioritiesView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var newTaskText = ""
    @State private var showConfetti = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(section: .topPriorities,
                                  subtitle: "Focus on what matters most today",
                                  completedCount: entry.topPriorities.filter(\.isCompleted).count,
                                  totalCount: entry.topPriorities.count)

                    if !vm.isFuture {
                        AddButton(label: "Add Priority", color: AppSection.topPriorities.color) {
                            showAddSheet = true
                        }
                        .padding(.horizontal, 16).padding(.top, 12)
                    }

                    if entry.topPriorities.isEmpty {
                        EmptySectionView(section: .topPriorities,
                                         message: "Add your top priorities to stay focused")
                    } else {
                        // Rolled over section
                        let rolledOver = entry.topPriorities.filter(\.isRolledOver)
                        let fresh = entry.topPriorities.filter { !$0.isRolledOver }

                        if !rolledOver.isEmpty {
                            SectionGroupLabel(title: "Rolled Over", color: .orange)
                            ForEach(rolledOver) { task in
                                TaskRowCard(task: task, color: AppSection.topPriorities.color) {
                                    vm.toggleTopPriority(task)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !fresh.isEmpty {
                            if !rolledOver.isEmpty {
                                SectionGroupLabel(title: "Today's Priorities", color: AppSection.topPriorities.color)
                            }
                            ForEach(fresh) { task in
                                TaskRowCard(task: task, color: AppSection.topPriorities.color) {
                                    vm.toggleTopPriority(task)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                            .onDelete { offsets in
                                // We need to map back to original indices
                            }
                        }
                    }

                    // Progress
                    if !entry.topPriorities.isEmpty {
                        ProgressSection(completed: entry.topPriorities.filter(\.isCompleted).count,
                                        total: entry.topPriorities.count,
                                        color: AppSection.topPriorities.color)
                            .padding(.horizontal, 16).padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(
                    title: "Add Top Priority",
                    placeholder: "What's your top priority?",
                    accentColor: AppSection.topPriorities.color,
                    icon: AppSection.topPriorities.icon
                ) { text in
                    vm.addTopPriority(text)
                }
            }

            if showConfetti {
                ConfettiOverlay(isVisible: $showConfetti)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: vm.topPrioritiesCompletionPercent) { newVal in
            if newVal == 100 { showConfetti = true }
        }
    }
}
