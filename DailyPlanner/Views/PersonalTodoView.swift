import SwiftUI

struct PersonalTodoView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask? = nil
    @State private var showPopper = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(section: .personalTodo,
                                  subtitle: "Your personal task list",
                                  completedCount: entry.personalTodo.filter(\.isCompleted).count,
                                  totalCount: entry.personalTodo.count)

                    if !vm.isFuture {
                        AddButton(label: "Add Task", color: AppSection.personalTodo.color) {
                            showAddSheet = true
                        }
                        .padding(.horizontal, 16).padding(.top, 12)
                    }

                    if entry.personalTodo.isEmpty {
                        EmptySectionView(section: .personalTodo,
                                         message: "Add your personal tasks for the day")
                    } else {
                        let rolledOver = entry.personalTodo.filter(\.isRolledOver)
                        let fresh = entry.personalTodo.filter { !$0.isRolledOver }

                        if !rolledOver.isEmpty {
                            SectionGroupLabel(title: "Rolled Over", color: .orange)
                            ForEach(rolledOver) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.personalTodo.color,
                                    onToggle: { vm.togglePersonalTodo(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task }
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !fresh.isEmpty {
                            if !rolledOver.isEmpty {
                                SectionGroupLabel(title: "Today", color: AppSection.personalTodo.color)
                            }
                            ForEach(fresh) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.personalTodo.color,
                                    onToggle: { vm.togglePersonalTodo(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task }
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }
                    }

                    if !entry.personalTodo.isEmpty {
                        ProgressSection(completed: entry.personalTodo.filter(\.isCompleted).count,
                                        total: entry.personalTodo.count,
                                        color: AppSection.personalTodo.color)
                            .padding(.horizontal, 16).padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(
                    title: "Add Personal Task",
                    placeholder: "What do you need to do?",
                    accentColor: AppSection.personalTodo.color,
                    icon: AppSection.personalTodo.icon
                ) { text in
                    vm.addPersonalTodo(text)
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    accentColor: AppSection.personalTodo.color,
                    icon: AppSection.personalTodo.icon
                ) { newTitle in
                    vm.updatePersonalTodo(task, newTitle: newTitle)
                }
            }

            if showPopper {
                PartyPopperOverlay(isVisible: $showPopper)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: vm.personalTodoCompletionPercent) { newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}
