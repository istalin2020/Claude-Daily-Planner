import SwiftUI

struct CallsEmailsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask? = nil
    @State private var taskToDelete: PlannerTask? = nil
    @State private var showPopper = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(section: .callsEmails,
                                  subtitle: "Track your calls and emails",
                                  completedCount: entry.callsEmails.filter(\.isCompleted).count,
                                  totalCount: entry.callsEmails.count)

                    if !vm.isFuture {
                        AddButton(label: "Add Call or Email", color: AppSection.callsEmails.color) {
                            showAddSheet = true
                        }
                        .padding(.horizontal, 16).padding(.top, 12)
                    }

                    if entry.callsEmails.isEmpty {
                        EmptySectionView(section: .callsEmails,
                                         message: "Add calls and emails you need to make today")
                    } else {
                        let rolledIncomplete = entry.callsEmails.filter { $0.isRolledOver && !$0.isCompleted }
                        let freshIncomplete  = entry.callsEmails.filter { !$0.isRolledOver && !$0.isCompleted }
                        let completed        = entry.callsEmails.filter { $0.isCompleted }

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

                        if !freshIncomplete.isEmpty {
                            if !rolledIncomplete.isEmpty {
                                SectionGroupLabel(title: "Today's Calls & Emails", color: AppSection.callsEmails.color)
                            }
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
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(
                    title: "Add Call or Email",
                    placeholder: "Who to call or email?",
                    accentColor: AppSection.callsEmails.color,
                    icon: AppSection.callsEmails.icon
                ) { text in
                    vm.addCallEmail(text)
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    accentColor: AppSection.callsEmails.color,
                    icon: AppSection.callsEmails.icon
                ) { newTitle in
                    vm.updateCallEmail(task, newTitle: newTitle)
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
