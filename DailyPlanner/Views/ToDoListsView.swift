import SwiftUI

struct ToDoListsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask? = nil
    @State private var showPopper = false

    var entry: DailyEntry { vm.currentEntry }

    /// Received lists that belong to the To-Do / Entire-List sections.
    private var receivedToDoLists: [ReceivedSharedList] {
        vm.settings.receivedSharedLists.filter {
            $0.section == .entireList || $0.section == .toDoLists
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(section: .toDoLists,
                                  subtitle: "Keep track of everything you need to do",
                                  completedCount: entry.toDoLists.filter(\.isCompleted).count,
                                  totalCount: entry.toDoLists.count)

                    if entry.toDoLists.isEmpty {
                        EmptySectionView(section: .toDoLists,
                                         message: "Add tasks to your to-do list")
                    } else {
                        let rolledIncomplete = entry.toDoLists.filter { $0.isRolledOver && !$0.isCompleted }
                        let freshIncomplete  = entry.toDoLists.filter { !$0.isRolledOver && !$0.isCompleted }
                        let completed        = entry.toDoLists.filter { $0.isCompleted }

                        // Newly added tasks first, rolled-over ones after.
                        if !freshIncomplete.isEmpty {
                            SectionGroupLabel(title: "Today's To-Dos", color: AppSection.toDoLists.color)
                            ForEach(freshIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.toDoLists.color,
                                    onToggle: { vm.toggleToDoListItem(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: { vm.deleteToDoListItem(task) }
                                )
                                .padding(.horizontal, 16).padding(.vertical, 3)
                            }
                        }

                        if !rolledIncomplete.isEmpty {
                            SectionGroupLabel(title: "Rolled Over", color: .orange)
                            ForEach(rolledIncomplete) { task in
                                TaskRowCard(
                                    task: task,
                                    color: AppSection.toDoLists.color,
                                    onToggle: { vm.toggleToDoListItem(task) },
                                    onEdit: vm.isFuture ? nil : { editingTask = task },
                                    onDelete: { vm.deleteToDoListItem(task) }
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
                                    onDelete: { vm.deleteToDoListItem(task) }
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

                    // ── RECEIVED SHARED LISTS ────────────────────────────────
                    ForEach(receivedToDoLists) { sharedList in
                        SharedToDoListSection(sharedList: sharedList)
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

            // Fixed add bar — stays put while the task list scrolls.
            if !vm.isFuture {
                AddButton(label: "Add To-Do", color: AppSection.toDoLists.color) {
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
        .onChange(of: vm.toDoListsCompletionPercent) { _, newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}

// MARK: - Shared To-Do List Section
/// Section shown below the user's own tasks for each received shared list.
/// Recipients can toggle completion and edit notes, but cannot delete tasks.
private struct SharedToDoListSection: View {
    @EnvironmentObject var vm: PlannerViewModel
    let sharedList: ReceivedSharedList

    @State private var editingTask: SharedTaskItem? = nil

    private var accentColor: Color { Color(red: 0.15, green: 0.45, blue: 0.95) }

    private var heading: String {
        let name = sharedList.senderName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Shared tasks" : "\(name)'s shared tasks"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(heading)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
                Spacer()
                Text("Updated \(sharedList.lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(accentColor.opacity(0.07))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 20)

            if sharedList.tasks.isEmpty {
                Text("No tasks in this shared list yet.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            } else {
                ForEach(sharedList.tasks) { task in
                    SharedTaskRow(
                        task: task,
                        accentColor: accentColor,
                        onToggle: {
                            vm.toggleSharedTaskCompletion(listID: sharedList.id, taskID: task.id)
                        },
                        onEdit: { editingTask = task }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 3)
                }
            }
        }
        .sheet(item: $editingTask) { task in
            SharedTaskEditSheet(task: task, accentColor: accentColor) { updatedNotes in
                vm.updateSharedTaskNotes(listID: sharedList.id, taskID: task.id, notes: updatedNotes)
            }
        }
    }
}

// MARK: - Shared Task Row (interactive: toggle + edit, no delete)
private struct SharedTaskRow: View {
    let task        : SharedTaskItem
    let accentColor : Color
    let onToggle    : () -> Void
    let onEdit      : () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(task.isCompleted ? accentColor : Color(.systemGray3))
                    .animation(.spring(response: 0.3), value: task.isCompleted)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15))
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if !task.subtasks.isEmpty {
                    let doneCount = task.subtasks.filter(\.isCompleted).count
                    Text("\(doneCount)/\(task.subtasks.count) subtasks")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(accentColor.opacity(0.7))
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(task.isCompleted ? 0.65 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }
}

// MARK: - Shared Task Edit Sheet (notes only; recipient cannot delete)
private struct SharedTaskEditSheet: View {
    let task        : SharedTaskItem
    let accentColor : Color
    let onSave      : (String) -> Void

    @State private var notesText: String
    @Environment(\.dismiss) var dismiss
    @FocusState private var notesFocused: Bool

    init(task: SharedTaskItem, accentColor: Color, onSave: @escaping (String) -> Void) {
        self.task = task
        self.accentColor = accentColor
        self.onSave = onSave
        _notesText = State(initialValue: task.notes)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                } header: {
                    Text("Task")
                }

                Section {
                    TextEditor(text: $notesText)
                        .frame(minHeight: 100)
                        .focused($notesFocused)
                } header: {
                    Text("Your Notes")
                } footer: {
                    Text("Add notes about this shared task. You cannot delete shared tasks.")
                }
            }
            .navigationTitle("Edit Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(notesText)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                }
            }
            .onAppear { notesFocused = true }
        }
        .presentationDetents([.medium])
    }
}
