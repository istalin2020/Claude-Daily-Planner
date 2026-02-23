import SwiftUI

struct ToDoListsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var showConfetti = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(section: .toDoLists,
                                  subtitle: "Keep track of everything you need to do",
                                  completedCount: entry.toDoLists.filter(\.isCompleted).count,
                                  totalCount: entry.toDoLists.count)

                    if !vm.isFuture {
                        AddButton(label: "Add To-Do", color: AppSection.toDoLists.color) {
                            showAddSheet = true
                        }
                        .padding(.horizontal, 16).padding(.top, 12)
                    }

                    if entry.toDoLists.isEmpty {
                        EmptySectionView(section: .toDoLists,
                                         message: "Add tasks to your to-do list")
                    } else {
                        // Rolled over section
                        let rolledOver = entry.toDoLists.filter(\.isRolledOver)
                        let fresh = entry.toDoLists.filter { !$0.isRolledOver }

                        if !rolledOver.isEmpty {
                            SectionGroupLabel(title: "Rolled Over", color: .orange)
                            ForEach(rolledOver) { task in
                                TaskRowCard(task: task, color: AppSection.toDoLists.color) {
                                    vm.toggleToDoListItem(task)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !fresh.isEmpty {
                            if !rolledOver.isEmpty {
                                SectionGroupLabel(title: "Today's To-Dos", color: AppSection.toDoLists.color)
                            }
                            ForEach(fresh) { task in
                                TaskRowCard(task: task, color: AppSection.toDoLists.color) {
                                    vm.toggleToDoListItem(task)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }
                    }

                    // Progress
                    if !entry.toDoLists.isEmpty {
                        ProgressSection(completed: entry.toDoLists.filter(\.isCompleted).count,
                                        total: entry.toDoLists.count,
                                        color: AppSection.toDoLists.color)
                            .padding(.horizontal, 16).padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(
                    title: "Add To-Do",
                    placeholder: "What do you need to do?",
                    accentColor: AppSection.toDoLists.color,
                    icon: AppSection.toDoLists.icon
                ) { text in
                    vm.addToDoListItem(text)
                }
            }

            if showConfetti {
                PartyPopperOverlay(isVisible: $showConfetti)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: vm.toDoListsCompletionPercent) { newVal in
            if newVal == 100 { showConfetti = true }
        }
    }
}
