import SwiftUI

struct CallsEmailsView: View {
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
                    if entry.callsEmails.isEmpty {
                        EmptySectionView(section: .callsEmails,
                                         message: "Add calls and emails you need to make today")
                    } else {
                        let rolledIncomplete = entry.callsEmails.filter { $0.isRolledOver && !$0.isCompleted }
                        let freshIncomplete  = entry.callsEmails.filter { !$0.isRolledOver && !$0.isCompleted }
                        let completed        = entry.callsEmails.filter { $0.isCompleted }

                        // Newly added tasks first, rolled-over ones after.
                        if !freshIncomplete.isEmpty {
                            SectionGroupLabel(title: "Today's Calls & Emails", color: AppSection.callsEmails.color)
                            ForEach(freshIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.callsEmails.color,
                                    onToggle: { vm.toggleCallEmail(task) },
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
                                    color: AppSection.callsEmails.color,
                                    onToggle: { vm.toggleCallEmail(task) },
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
                                    color: AppSection.callsEmails.color,
                                    onToggle: { vm.toggleCallEmail(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: vm.isFuture ? nil : { taskToDelete = task }
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }
                    }

                    if !entry.callsEmails.isEmpty {
                        ProgressSection(completed: entry.callsEmails.filter(\.isCompleted).count,
                                        total: entry.callsEmails.count,
                                        color: AppSection.callsEmails.color)
                            .padding(.horizontal, 16).padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    accentColor: AppSection.callsEmails.color,
                    icon: AppSection.callsEmails.icon
                ) { updatedTask in
                    vm.updateCallEmail(task, with: updatedTask)
                }
            }
            .alert("Delete Entry?", isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        vm.deleteCallEmail(task)
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
                InlineAddBar(placeholder: "Who to call or email?",
                             color: AppSection.callsEmails.color) { text in
                    vm.addCallEmail(text)
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
        .onChange(of: vm.callsEmailsCompletionPercent) { _, newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}
