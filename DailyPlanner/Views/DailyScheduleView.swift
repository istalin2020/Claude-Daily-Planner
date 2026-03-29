import SwiftUI

struct DailyScheduleView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingBlock: ScheduleBlock? = nil

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .dailySchedule,
                              subtitle: "Plan and track your day hour by hour",
                              completedCount: entry.dailySchedule.filter(\.isCompleted).count,
                              totalCount: entry.dailySchedule.count)

                if !vm.isFuture {
                    AddButton(label: "Add Schedule Block", color: AppSection.dailySchedule.color) {
                        showAddSheet = true
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }

                if entry.dailySchedule.isEmpty {
                    EmptySectionView(section: .dailySchedule,
                                     message: "Add time blocks to plan your day")
                } else {
                    VStack(spacing: 1) {
                        ForEach(Array(entry.dailySchedule.enumerated()), id: \.element.id) { idx, block in
                            ScheduleBlockRow(block: block, index: idx,
                                onToggle: { vm.toggleScheduleBlock(block) },
                                onEdit:   { editingBlock = block },
                                onDelete: { vm.deleteScheduleBlock(block) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }

                if !entry.dailySchedule.isEmpty {
                    ProgressSection(
                        completed: entry.dailySchedule.filter(\.isCompleted).count,
                        total: entry.dailySchedule.count,
                        color: AppSection.dailySchedule.color
                    )
                    .padding(.horizontal, 16).padding(.top, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddScheduleBlockSheet { block in
                vm.addScheduleBlock(block)
            }
        }
        .sheet(item: $editingBlock) { block in
            EditScheduleBlockSheet(block: block) { updated in
                vm.updateScheduleBlock(updated)
            }
        }
    }
}

// MARK: - Schedule Block Row
struct ScheduleBlockRow: View {
    let block: ScheduleBlock
    let index: Int
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let blockColors: [Color] = [
        Color(red: 0.4, green: 0.3, blue: 0.85),
        Color(red: 0.2, green: 0.6, blue: 0.85),
        Color(red: 0.1, green: 0.7, blue: 0.6),
        Color(red: 0.9, green: 0.5, blue: 0.1),
        Color(red: 0.9, green: 0.2, blue: 0.5)
    ]

    private var blockColor: Color { blockColors[index % blockColors.count] }

    var body: some View {
        HStack(spacing: 0) {
            // Time column
            VStack(alignment: .center, spacing: 2) {
                Text(block.startTime)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(blockColor)
                Rectangle()
                    .fill(blockColor.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                Text(block.endTime)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(blockColor)
            }
            .frame(width: 60)
            .padding(.vertical, 8)

            // Content
            HStack(spacing: 10) {
                Rectangle()
                    .fill(blockColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.activity)
                        .font(.system(size: 14, weight: .semibold))
                        .strikethrough(block.isCompleted)
                        .foregroundColor(block.isCompleted ? .secondary : .primary)

                    if block.reminderOffset != .none {
                        Label(block.reminderOffset.rawValue, systemImage: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                Spacer()

                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }

                // Toggle button
                Button(action: onToggle) {
                    Image(systemName: block.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(block.isCompleted ? blockColor : .secondary.opacity(0.3))
                }
            }
            .padding(.vertical, 10)
            .padding(.trailing, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(block.isCompleted ? blockColor.opacity(0.06) : Color(.systemBackground))
            )
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Add Schedule Block Sheet
struct AddScheduleBlockSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var activity = ""
    @State private var startTime = "9:00 AM"
    @State private var endTime = "10:00 AM"
    @State private var reminderOffset: ReminderOffset = .none

    let onSave: (ScheduleBlock) -> Void

    private let timeSlots = ["6:00 AM", "6:30 AM", "7:00 AM", "7:30 AM", "8:00 AM", "8:30 AM",
                              "9:00 AM", "9:30 AM", "10:00 AM", "10:30 AM", "11:00 AM", "11:30 AM",
                              "12:00 PM", "12:30 PM", "1:00 PM", "1:30 PM", "2:00 PM", "2:30 PM",
                              "3:00 PM", "3:30 PM", "4:00 PM", "4:30 PM", "5:00 PM", "5:30 PM",
                              "6:00 PM", "6:30 PM", "7:00 PM", "7:30 PM", "8:00 PM", "8:30 PM",
                              "9:00 PM", "9:30 PM", "10:00 PM"]

    var body: some View {
        NavigationView {
            Form {
                Section("Activity") {
                    TextField("What will you be doing?", text: $activity)
                        .autocapitalization(.sentences)
                }
                Section("Start Time") {
                    Picker("Start", selection: $startTime) {
                        ForEach(timeSlots, id: \.self) { t in Text(t).tag(t) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                Section("End Time") {
                    Picker("End", selection: $endTime) {
                        ForEach(timeSlots, id: \.self) { t in Text(t).tag(t) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                Section {
                    Picker(selection: $reminderOffset) {
                        ForEach(ReminderOffset.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    } label: {
                        Label("Reminder", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    if reminderOffset != .none {
                        Text("You will receive a notification \(reminderOffset.rawValue.lowercased()) the scheduled start time.")
                    }
                }
            }
            .navigationTitle("Add Schedule Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !activity.isEmpty else { return }
                        onSave(ScheduleBlock(startTime: startTime, endTime: endTime,
                                             activity: activity, reminderOffset: reminderOffset))
                        dismiss()
                    }
                    .disabled(activity.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Schedule Block Sheet
struct EditScheduleBlockSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var activity: String
    @State private var startTime: String
    @State private var endTime: String
    @State private var reminderOffset: ReminderOffset

    let block: ScheduleBlock
    let onSave: (ScheduleBlock) -> Void

    init(block: ScheduleBlock, onSave: @escaping (ScheduleBlock) -> Void) {
        self.block = block
        self.onSave = onSave
        _activity = State(initialValue: block.activity)
        _startTime = State(initialValue: block.startTime)
        _endTime = State(initialValue: block.endTime)
        _reminderOffset = State(initialValue: block.reminderOffset)
    }

    private let timeSlots = ["6:00 AM", "6:30 AM", "7:00 AM", "7:30 AM", "8:00 AM", "8:30 AM",
                              "9:00 AM", "9:30 AM", "10:00 AM", "10:30 AM", "11:00 AM", "11:30 AM",
                              "12:00 PM", "12:30 PM", "1:00 PM", "1:30 PM", "2:00 PM", "2:30 PM",
                              "3:00 PM", "3:30 PM", "4:00 PM", "4:30 PM", "5:00 PM", "5:30 PM",
                              "6:00 PM", "6:30 PM", "7:00 PM", "7:30 PM", "8:00 PM", "8:30 PM",
                              "9:00 PM", "9:30 PM", "10:00 PM"]

    var body: some View {
        NavigationView {
            Form {
                Section("Activity") {
                    TextField("What will you be doing?", text: $activity)
                        .autocapitalization(.sentences)
                }
                Section("Start Time") {
                    Picker("Start", selection: $startTime) {
                        ForEach(timeSlots, id: \.self) { t in Text(t).tag(t) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                Section("End Time") {
                    Picker("End", selection: $endTime) {
                        ForEach(timeSlots, id: \.self) { t in Text(t).tag(t) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                Section {
                    Picker(selection: $reminderOffset) {
                        ForEach(ReminderOffset.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    } label: {
                        Label("Reminder", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    if reminderOffset != .none {
                        Text("You will receive a notification \(reminderOffset.rawValue.lowercased()) the scheduled start time.")
                    }
                }
            }
            .navigationTitle("Edit Schedule Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !activity.isEmpty else { return }
                        var updated = block
                        updated.activity = activity
                        updated.startTime = startTime
                        updated.endTime = endTime
                        updated.reminderOffset = reminderOffset
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(activity.isEmpty)
                }
            }
        }
    }
}
