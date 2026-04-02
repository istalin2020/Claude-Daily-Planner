import SwiftUI

struct TopPrioritiesView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask? = nil
    @State private var taskToDelete: PlannerTask? = nil
    @State private var showPopper = false
    @State private var recurrence: Recurrence = .none

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
                        let rolledIncomplete = entry.topPriorities.filter { $0.isRolledOver && !$0.isCompleted }
                        let freshIncomplete  = entry.topPriorities.filter { !$0.isRolledOver && !$0.isCompleted }
                        let completed        = entry.topPriorities.filter { $0.isCompleted }

                        if !rolledIncomplete.isEmpty {
                            SectionGroupLabel(title: "Rolled Over", color: .orange)
                            ForEach(rolledIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.topPriorities.color,
                                    onToggle: { vm.toggleTopPriority(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task },
                                    sectionLabel: AppSection.topPriorities.rawValue
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !freshIncomplete.isEmpty {
                            if !rolledIncomplete.isEmpty {
                                SectionGroupLabel(title: "Today's Priorities", color: AppSection.topPriorities.color)
                            }
                            ForEach(freshIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.topPriorities.color,
                                    onToggle: { vm.toggleTopPriority(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task },
                                    sectionLabel: AppSection.topPriorities.rawValue
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !completed.isEmpty {
                            SectionGroupLabel(title: "Completed", color: .secondary)
                            ForEach(completed) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.topPriorities.color,
                                    onToggle: { vm.toggleTopPriority(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task },
                                    sectionLabel: AppSection.topPriorities.rawValue
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }
                    }

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
                AddItemWithRecurrenceSheet(
                    title: "Add Top Priority",
                    placeholder: "What's your top priority?",
                    accentColor: AppSection.topPriorities.color,
                    icon: AppSection.topPriorities.icon
                ) { text, recurrence, notes, subtasks in
                    vm.addTopPriority(text, recurrence: recurrence, notes: notes, subtasks: subtasks)
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    accentColor: AppSection.topPriorities.color,
                    icon: AppSection.topPriorities.icon
                ) { updatedTask in
                    vm.updateTopPriority(task, with: updatedTask)
                }
            }
            .alert("Delete Priority?", isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        vm.deleteTopPriority(task)
                    }
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) { taskToDelete = nil }
            } message: {
                if let task = taskToDelete {
                    Text("\"\(task.title)\" will be permanently removed.")
                }
            }

            if showPopper {
                PartyPopperOverlay(isVisible: $showPopper)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: vm.topPrioritiesCompletionPercent) { _, newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}
