import SwiftUI

struct TopPrioritiesView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var editingTask: PlannerTask? = nil
    @State private var taskToDelete: PlannerTask? = nil
    @State private var showPopper = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    if entry.topPriorities.isEmpty {
                        EmptySectionView(section: .topPriorities,
                                         message: "Add your top priorities to stay focused")
                    } else {
                        let rolledIncomplete = entry.topPriorities.filter { $0.isRolledOver && !$0.isCompleted }
                        let freshIncomplete  = entry.topPriorities.filter { !$0.isRolledOver && !$0.isCompleted }
                        let completed        = entry.topPriorities.filter { $0.isCompleted }

                        // Newly added tasks first, rolled-over ones after.
                        if !freshIncomplete.isEmpty {
                            SectionGroupLabel(title: "Today's Priorities", color: AppSection.topPriorities.color)
                            ForEach(freshIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.topPriorities.color,
                                    onToggle: { vm.toggleTopPriority(task) },
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
                                    color: AppSection.topPriorities.color,
                                    onToggle: { vm.toggleTopPriority(task) },
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
                                    color: AppSection.topPriorities.color,
                                    onToggle: { vm.toggleTopPriority(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task }
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

            // Fixed add bar — type and press Add, no sheet needed.
            if !vm.isFuture {
                InlineAddBar(placeholder: "What's your top priority?",
                             color: AppSection.topPriorities.color) { text in
                    vm.addTopPriority(text)
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
        .onChange(of: vm.topPrioritiesCompletionPercent) { _, newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}
