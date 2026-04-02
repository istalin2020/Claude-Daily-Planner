import SwiftUI

struct ToDoListsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask? = nil
    @State private var showPopper = false

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
                        let rolledIncomplete = entry.toDoLists.filter { $0.isRolledOver && !$0.isCompleted }
                        let freshIncomplete  = entry.toDoLists.filter { !$0.isRolledOver && !$0.isCompleted }
                        let completed        = entry.toDoLists.filter { $0.isCompleted }

                        if !rolledIncomplete.isEmpty {
                            SectionGroupLabel(title: "Rolled Over", color: .orange)
                            ForEach(rolledIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.toDoLists.color,
                                    onToggle: { vm.toggleToDoListItem(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: { vm.deleteToDoListItem(task) },
                                    sectionLabel: AppSection.toDoLists.rawValue
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !freshIncomplete.isEmpty {
                            if !rolledIncomplete.isEmpty {
                                SectionGroupLabel(title: "Today's To-Dos", color: AppSection.toDoLists.color)
                            }
                            ForEach(freshIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.toDoLists.color,
                                    onToggle: { vm.toggleToDoListItem(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: { vm.deleteToDoListItem(task) },
                                    sectionLabel: AppSection.toDoLists.rawValue
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !completed.isEmpty {
                            SectionGroupLabel(title: "Completed", color: .secondary)
                            ForEach(completed) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.toDoLists.color,
                                    onToggle: { vm.toggleToDoListItem(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: { vm.deleteToDoListItem(task) },
                                    sectionLabel: AppSection.toDoLists.rawValue
                                )
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
                AddItemWithRecurrenceSheet(
                    title: "Add To-Do",
                    placeholder: "What do you need to do?",
                    accentColor: AppSection.toDoLists.color,
                    icon: AppSection.toDoLists.icon
                ) { text, recurrence, notes, subtasks in
                    vm.addToDoListItem(text, recurrence: recurrence, notes: notes, subtasks: subtasks)
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    accentColor: AppSection.toDoLists.color,
                    icon: AppSection.toDoLists.icon
                ) { updatedTask in
                    vm.updateToDoListItem(task, with: updatedTask)
                }
            }

            if showPopper {
                PartyPopperOverlay(isVisible: $showPopper)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: vm.toDoListsCompletionPercent) { _, newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}
