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
            LinearGradient(
                colors: [section.color, section.color.opacity(0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 80)
            .overlay(
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
            )
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
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Task Row Card
struct TaskRowCard: View {
    let task: PlannerTask
    let color: Color
    let onToggle: () -> Void
    /// When non-nil, tapping the task text opens the edit flow.
    /// Pass nil for read-only contexts (e.g. future dates).
    var onEdit: (() -> Void)? = nil
    /// When non-nil, a trash button is shown and calls this on tap.
    var onDelete: (() -> Void)? = nil

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

                    if task.isRolledOver, let originalDate = task.originalDate {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.right").font(.system(size: 9))
                            Text("Rolled from \(shortDate(originalDate))")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.orange)
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
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(task.isCompleted ? color.opacity(0.05) : Color(.systemBackground))
        )
        .shadow(color: .black.opacity(task.isCompleted ? 0.03 : 0.07), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}

// MARK: - Edit Task Sheet
struct EditTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    let task: PlannerTask
    let accentColor: Color
    let icon: String
    let onSave: (String) -> Void

    init(task: PlannerTask, accentColor: Color, icon: String, onSave: @escaping (String) -> Void) {
        self._text = State(initialValue: task.title)
        self.task = task
        self.accentColor = accentColor
        self.icon = icon
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(accentColor)
                    Text("Edit Task")
                        .font(.title3).fontWeight(.bold)
                }
                .padding(.top, 20)

                // Text field — pre-filled with current title
                TextField("Task title", text: $text, axis: .vertical)
                    .focused($focused)
                    .font(.body)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                    .lineLimit(3...6)
                    .padding(.horizontal, 20)

                // Save button
                Button(action: {
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    dismiss()
                }) {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            text.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.secondary.opacity(0.3)
                                : accentColor
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
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
                    .onChange(of: text) { onSave($0) }
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
