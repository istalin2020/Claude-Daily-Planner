import SwiftUI

struct PersonalTodoView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask? = nil
    @State private var taskToDelete: PlannerTask? = nil
    @State private var showPopper = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(section: .personalTodo,
                                  subtitle: "Your personal task list",
                                  completedCount: entry.personalTodo.filter(\.isCompleted).count,
                                  totalCount: entry.personalTodo.count)

                    if entry.personalTodo.isEmpty {
                        EmptySectionView(section: .personalTodo,
                                         message: "Add your personal tasks for the day")
                    } else {
                        let rolledIncomplete = entry.personalTodo.filter { $0.isRolledOver && !$0.isCompleted }
                        let freshIncomplete  = entry.personalTodo.filter { !$0.isRolledOver && !$0.isCompleted }
                        let completed        = entry.personalTodo.filter { $0.isCompleted }

                        // Newly added tasks first, rolled-over ones after.
                        if !freshIncomplete.isEmpty {
                            SectionGroupLabel(title: "Today", color: AppSection.personalTodo.color)
                            ForEach(freshIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.personalTodo.color,
                                    onToggle: { vm.togglePersonalTodo(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task }
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !rolledIncomplete.isEmpty {
                            SectionGroupLabel(title: "Rolled Over", color: .orange)
                            ForEach(rolledIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.personalTodo.color,
                                    onToggle: { vm.togglePersonalTodo(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task }
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !completed.isEmpty {
                            SectionGroupLabel(title: "Completed", color: .secondary)
                            ForEach(completed) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.personalTodo.color,
                                    onToggle: { vm.togglePersonalTodo(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task }
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
                AddItemWithRecurrenceSheet(
                    title: "Add Personal Task",
                    placeholder: "What do you need to do?",
                    accentColor: AppSection.personalTodo.color,
                    icon: AppSection.personalTodo.icon
                ) { text, recurrence, notes, subtasks in
                    vm.addPersonalTodo(text, recurrence: recurrence, notes: notes, subtasks: subtasks)
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    accentColor: AppSection.personalTodo.color,
                    icon: AppSection.personalTodo.icon
                ) { updatedTask in
                    vm.updatePersonalTodo(task, with: updatedTask)
                }
            }
            .alert("Delete Task?", isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        vm.deletePersonalTodo(task)
                    }
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } message: {
                if let task = taskToDelete {
                    Text("\"\(task.title)\" will be permanently removed.")
                }
            }

            // Fixed add bar — stays put while the task list scrolls.
            if !vm.isFuture {
                AddButton(label: "Add Task", color: AppSection.personalTodo.color) {
                    showAddSheet = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            }

            if showPopper {
                PartyPopperOverlay(isVisible: $showPopper)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: vm.personalTodoCompletionPercent) { _, newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}
