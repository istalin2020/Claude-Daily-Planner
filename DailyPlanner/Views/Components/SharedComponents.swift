import SwiftUI

// MARK: - Section Header
struct SectionHeader: View {
    @EnvironmentObject var vm: PlannerViewModel
    let section: AppSection
    let subtitle: String
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: section.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.rawValue)
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                if totalCount > 0 {
                    VStack(spacing: 2) {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Done")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.selectedSection = .overview
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .frame(height: 80)
            .glassSectionHeader(color: section.color)
        }
    }
}

// MARK: - Add Button
struct AddButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(color)
            .glassAddButton(color: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Task Row Card
struct TaskRowCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    let task: PlannerTask
    let color: Color
    let onToggle: () -> Void
    /// When non-nil, tapping the task text opens the edit flow.
    /// Pass nil for read-only contexts (e.g. future dates).
    var onEdit: (() -> Void)? = nil
    /// When non-nil, a trash button is shown and calls this on tap.
    var onDelete: (() -> Void)? = nil
    private var isHighlighted: Bool { vm.highlightedTaskID == task.id }

    var body: some View {
        HStack(spacing: 12) {
            // ── Checkbox: toggles completion ──────────────────────────────────
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? color : Color.secondary.opacity(0.35))
                    .animation(.spring(response: 0.3), value: task.isCompleted)
            }
            .buttonStyle(PlainButtonStyle())

            // ── Tappable content area: title + rollover badge + trailing icon ─
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    HStack(spacing: 4) {
                        if task.isRolledOver, let originalDate = task.originalDate {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.right").font(.system(size: 9))
                                Text("Rolled from \(shortDate(originalDate))")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.orange)
                        }
                        RecurrenceBadge(recurrence: task.recurrence)
                        SubtaskBadge(subtasks: task.subtasks, color: color)
                        if !task.notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Trailing indicator: checkmark when done, pencil when editable
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color.opacity(0.7))
                } else if onEdit != nil {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .contentShape(Rectangle())   // makes the Spacer area tappable too
            .onTapGesture { onEdit?() }

            // ── Delete button (outside tappable area so it doesn't trigger edit) ─
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.6))
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassTaskRow(color: color, isHighlighted: isHighlighted, isCompleted: task.isCompleted)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
        .animation(.easeInOut(duration: 0.4), value: isHighlighted)
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}

// MARK: - Edit Task Sheet  (supports title, notes, subtasks)
struct EditTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var pro: ProManager
    @State private var titleText: String
    @State private var notesText: String
    @State private var subtasks: [SubTask]
    @State private var recurrence: Recurrence
    @State private var newSubtask: String = ""
    @State private var showProUpgrade = false
    @FocusState private var titleFocused: Bool

    let task: PlannerTask
    let accentColor: Color
    let icon: String
    let onSave: (PlannerTask) -> Void

    init(task: PlannerTask, accentColor: Color, icon: String, onSave: @escaping (PlannerTask) -> Void) {
        self.task = task
        self.accentColor = accentColor
        self.icon = icon
        self.onSave = onSave
        _titleText  = State(initialValue: task.title)
        _notesText  = State(initialValue: task.notes)
        _subtasks   = State(initialValue: task.subtasks)
        _recurrence = State(initialValue: task.recurrence)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Title") {
                    TextField("Task title", text: $titleText, axis: .vertical)
                        .focused($titleFocused)
                        .lineLimit(2...5)
                }

                Section {
                    if pro.isPro {
                        TextEditor(text: $notesText)
                            .frame(minHeight: 70)
                            .overlay(
                                Group {
                                    if notesText.isEmpty {
                                        Text("Add notes...")
                                            .foregroundColor(.secondary)
                                            .padding(.top, 8).padding(.leading, 4)
                                            .allowsHitTesting(false)
                                    }
                                }, alignment: .topLeading
                            )
                    } else {
                        proLockedRow(label: "Notes require PRO")
                    }
                } header: { Text("Notes") }

                Section {
                    if pro.isPro {
                        ForEach(subtasks.indices, id: \.self) { i in
                            HStack(spacing: 10) {
                                Button(action: { subtasks[i].isCompleted.toggle() }) {
                                    Image(systemName: subtasks[i].isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(subtasks[i].isCompleted ? accentColor : .secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                TextField("Subtask", text: $subtasks[i].title)
                                    .strikethrough(subtasks[i].isCompleted, color: .secondary)
                                    .foregroundColor(subtasks[i].isCompleted ? .secondary : .primary)
                            }
                        }
                        .onDelete { subtasks.remove(atOffsets: $0) }

                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle").foregroundColor(accentColor)
                            TextField("Add subtask…", text: $newSubtask)
                                .onSubmit { addSubtask() }
                        }
                    } else {
                        proLockedRow(label: "Subtasks require PRO")
                    }
                } header: {
                    HStack {
                        Text("Subtasks")
                        if !pro.isPro { ProInlineBadge() }
                        Spacer()
                        if pro.isPro && !subtasks.isEmpty {
                            Text("\(subtasks.filter(\.isCompleted).count)/\(subtasks.count)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    if pro.isPro {
                        Picker("Repeat", selection: $recurrence) {
                            Label("No Repeat", systemImage: "slash.circle").tag(Recurrence.none)
                            ForEach(Recurrence.allCases.filter { $0 != .none }) { r in
                                Label(r.rawValue, systemImage: r.icon).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        proLockedRow(label: "Recurrence requires PRO")
                    }
                } header: {
                    Text("Recurrence")
                }
                .sheet(isPresented: $showProUpgrade) {
                    ProUpgradeView().environmentObject(pro)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = titleText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        var updated = task
                        updated.title      = trimmed
                        updated.notes      = notesText
                        updated.subtasks   = subtasks
                        updated.recurrence = recurrence
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(titleText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func addSubtask() {
        let t = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        subtasks.append(SubTask(title: t))
        newSubtask = ""
    }

    @ViewBuilder
    private func proLockedRow(label: String) -> some View {
        Button(action: { showProUpgrade = true }) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.0))
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                ProInlineBadge()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Subtask Progress Badge (used in task rows)
struct SubtaskBadge: View {
    let subtasks: [SubTask]
    let color: Color

    var completed: Int { subtasks.filter(\.isCompleted).count }

    var body: some View {
        if !subtasks.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet").font(.system(size: 9))
                Text("\(completed)/\(subtasks.count)")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(completed == subtasks.count ? color.opacity(0.15) : Color(.systemGray5))
            .foregroundColor(completed == subtasks.count ? color : .secondary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Progress Section
struct ProgressSection: View {
    let completed: Int
    let total: Int
    let color: Color

    var progress: Double { total > 0 ? Double(completed) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(completed) of \(total) completed")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("· \(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(colors: [color, color.opacity(0.7)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 10)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Empty Section View
struct EmptySectionView: View {
    let section: AppSection
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: section.icon)
                .font(.system(size: 44))
                .foregroundColor(section.color.opacity(0.3))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 40)
    }
}

// MARK: - Section Group Label
struct SectionGroupLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 14)
                .cornerRadius(2)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Add Item Sheet (generic pop-up)
struct AddItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    let title: String
    let placeholder: String
    let accentColor: Color
    let icon: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(accentColor)
                    Text(title)
                        .font(.title3).fontWeight(.bold)
                }
                .padding(.top, 20)

                // Text field
                VStack(alignment: .leading, spacing: 6) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .focused($focused)
                        .font(.body)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(14)
                        .lineLimit(3...6)
                }
                .padding(.horizontal, 20)

                // Save button
                Button(action: {
                    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onSave(text.trimmingCharacters(in: .whitespaces))
                    text = ""
                    dismiss()
                }) {
                    Text("Add")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.3) : accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add Item With Recurrence Sheet
struct AddItemWithRecurrenceSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var pro: ProManager
    @State private var text         = ""
    @State private var notes        = ""
    @State private var recurrence: Recurrence = .none
    @State private var subtasks: [SubTask] = []
    @State private var newSubtask   = ""
    @State private var showProUpgrade = false
    @FocusState private var titleFocused: Bool
    @FocusState private var subtaskFocused: Bool

    let title: String
    let placeholder: String
    let accentColor: Color
    let icon: String
    let onSave: (String, Recurrence, String, [SubTask]) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 36))
                            .foregroundColor(accentColor)
                        Text(title)
                            .font(.title3).fontWeight(.bold)
                    }
                    .padding(.top, 20)

                    // Task title field
                    TextField(placeholder, text: $text, axis: .vertical)
                        .focused($titleFocused)
                        .font(.body)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(14)
                        .lineLimit(3...6)
                        .padding(.horizontal, 20)

                    // Notes field (available to all users)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        TextField("Add notes (optional)", text: $notes, axis: .vertical)
                            .font(.subheadline)
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .lineLimit(2...4)
                            .padding(.horizontal, 20)
                    }

                    // Subtasks section (PRO feature)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Subtasks")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            if !pro.isPro { ProInlineBadge() }
                            Spacer()
                            if pro.isPro && !subtasks.isEmpty {
                                Text("\(subtasks.filter(\.isCompleted).count)/\(subtasks.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)

                        if pro.isPro {
                            // Existing subtask rows
                            if !subtasks.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(subtasks.indices, id: \.self) { i in
                                        HStack(spacing: 10) {
                                            Button(action: { subtasks[i].isCompleted.toggle() }) {
                                                Image(systemName: subtasks[i].isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(subtasks[i].isCompleted ? accentColor : .secondary)
                                            }
                                            .buttonStyle(PlainButtonStyle())

                                            TextField("Subtask", text: $subtasks[i].title)
                                                .strikethrough(subtasks[i].isCompleted, color: .secondary)
                                                .foregroundColor(subtasks[i].isCompleted ? .secondary : .primary)

                                            Spacer()

                                            Button(action: { subtasks.remove(at: i) }) {
                                                Image(systemName: "xmark.circle")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary.opacity(0.5))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)

                                        if i < subtasks.count - 1 {
                                            Divider().padding(.leading, 44)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                                .padding(.horizontal, 20)
                            }

                            // Add subtask input row
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(accentColor)
                                TextField("Add subtask…", text: $newSubtask)
                                    .focused($subtaskFocused)
                                    .onSubmit { addSubtask() }
                                if !newSubtask.trimmingCharacters(in: .whitespaces).isEmpty {
                                    Button(action: addSubtask) {
                                        Text("Add")
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(accentColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .padding(.horizontal, 20)

                        } else {
                            // Locked – show crown button
                            Button(action: { showProUpgrade = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.0))
                                    Text("Subtasks require PRO")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    ProInlineBadge()
                                }
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(14)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)
                        }
                    }

                    // Recurrence picker (PRO feature — "None" excluded from visible options)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Picker("Repeat", selection: $recurrence) {
                                Label("No Repeat", systemImage: "slash.circle").tag(Recurrence.none)
                                ForEach(Recurrence.allCases.filter { $0 != .none }) { r in
                                    Label(r.rawValue, systemImage: r.icon).tag(r)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(!pro.isPro)
                            .opacity(pro.isPro ? 1 : 0.5)
                            if !pro.isPro {
                                ProInlineBadge()
                                Spacer()
                                Button(action: { showProUpgrade = true }) {
                                    Text("Unlock").font(.caption).foregroundColor(Color(red: 0.30, green: 0.10, blue: 0.60))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)

                    // Add / Save button
                    Button(action: saveTask) {
                        Text("Add")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(text.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? Color.secondary.opacity(0.3) : accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView().environmentObject(pro)
            }
        }
        .presentationDetents([.large])
    }

    private func addSubtask() {
        let t = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        subtasks.append(SubTask(title: t))
        newSubtask = ""
    }

    private func saveTask() {
        // If there's a pending subtask in the text field, commit it first
        let pendingSub = newSubtask.trimmingCharacters(in: .whitespaces)
        if !pendingSub.isEmpty {
            subtasks.append(SubTask(title: pendingSub))
            newSubtask = ""
        }
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onSave(text.trimmingCharacters(in: .whitespaces), recurrence,
               notes.trimmingCharacters(in: .whitespaces), subtasks)
        text = ""; notes = ""; subtasks = []
        dismiss()
    }
}

// MARK: - Notes Card (inline text editor)
struct NotesCard: View {
    let title: String
    @State private var text: String
    let placeholder: String
    let color: Color
    let onSave: (String) -> Void

    @State private var isEditing = false
    @FocusState private var focused: Bool

    init(title: String, text: String, placeholder: String, color: Color, onSave: @escaping (String) -> Void) {
        self.title = title
        self._text = State(initialValue: text)
        self.placeholder = placeholder
        self.color = color
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "note.text").foregroundColor(color)
                Text(title).font(.system(size: 14, weight: .bold))
                Spacer()
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { onSave(text); focused = false }
                    else { focused = true }
                    isEditing.toggle()
                }
                .font(.subheadline)
                .foregroundColor(color)
            }

            if isEditing {
                TextEditor(text: $text)
                    .focused($focused)
                    .frame(height: 80)
                    .font(.subheadline)
                    .padding(4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .onChange(of: text) { _, newText in onSave(newText) }
            } else if text.isEmpty {
                Text(placeholder)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            } else {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
