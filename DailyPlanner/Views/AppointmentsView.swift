import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingAppt: Appointment? = nil

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .appointments,
                              subtitle: "Manage your appointments for the day",
                              completedCount: entry.appointments.filter(\.isCompleted).count,
                              totalCount: entry.appointments.count)

                if !vm.isFuture {
                    AddButton(label: "Add Appointment", color: AppSection.appointments.color) {
                        showAddSheet = true
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }

                if entry.appointments.isEmpty {
                    EmptySectionView(section: .appointments,
                                     message: "Add appointments, meetings, and events")
                } else {
                    VStack(spacing: 8) {
                        ForEach(entry.appointments) { appt in
                            AppointmentCard(appointment: appt,
                                onToggle: { vm.toggleAppointment(appt) },
                                onEdit:   { editingAppt = appt },
                                onDelete: { vm.deleteAppointment(appt) }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 10)
                }

                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAppointmentSheet { appt in
                vm.addAppointment(appt)
            }
        }
        .sheet(item: $editingAppt) { appt in
            EditAppointmentSheet(appointment: appt) { updated in
                vm.updateAppointment(updated)
            }
        }
    }
}

// MARK: - Appointment Card
struct AppointmentCard: View {
    let appointment: Appointment
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: appointment.time)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Time badge
            VStack(spacing: 2) {
                Text(timeString)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppSection.appointments.color)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 60)
            .padding(.vertical, 10)
            .background(AppSection.appointments.color.opacity(0.1))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.system(size: 14, weight: .semibold))
                    .strikethrough(appointment.isCompleted)
                    .foregroundColor(appointment.isCompleted ? .secondary : .primary)

                if !appointment.location.isEmpty {
                    Label(appointment.location, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !appointment.notes.isEmpty {
                    Text(appointment.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if appointment.reminderOffset != .none {
                    Label(appointment.reminderOffset.rawValue, systemImage: "bell.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            VStack(spacing: 10) {
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
                    Image(systemName: appointment.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(appointment.isCompleted ? AppSection.appointments.color : .secondary.opacity(0.3))
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(appointment.isCompleted ? AppSection.appointments.color.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Add Appointment Sheet
struct AddAppointmentSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var time = Date()
    @State private var reminderOffset: ReminderOffset = .none

    let onSave: (Appointment) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Appointment Details") {
                    TextField("Title (e.g. Doctor Appointment)", text: $title)
                        .autocapitalization(.words)
                    TextField("Location (optional)", text: $location)
                        .autocapitalization(.words)
                }
                Section("Time") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .frame(maxHeight: 150)
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
                        Text("You will receive a notification \(reminderOffset.rawValue.lowercased()) the appointment time.")
                    }
                }
                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Add Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !title.isEmpty else { return }
                        onSave(Appointment(time: time, title: title, location: location,
                                           notes: notes, reminderOffset: reminderOffset))
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Appointment Sheet
struct EditAppointmentSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var location: String
    @State private var notes: String
    @State private var time: Date
    @State private var reminderOffset: ReminderOffset

    let appointment: Appointment
    let onSave: (Appointment) -> Void

    init(appointment: Appointment, onSave: @escaping (Appointment) -> Void) {
        self.appointment = appointment
        self.onSave = onSave
        _title = State(initialValue: appointment.title)
        _location = State(initialValue: appointment.location)
        _notes = State(initialValue: appointment.notes)
        _time = State(initialValue: appointment.time)
        _reminderOffset = State(initialValue: appointment.reminderOffset)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Appointment Details") {
                    TextField("Title (e.g. Doctor Appointment)", text: $title)
                        .autocapitalization(.words)
                    TextField("Location (optional)", text: $location)
                        .autocapitalization(.words)
                }
                Section("Time") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .frame(maxHeight: 150)
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
                        Text("You will receive a notification \(reminderOffset.rawValue.lowercased()) the appointment time.")
                    }
                }
                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Edit Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !title.isEmpty else { return }
                        var updated = appointment
                        updated.title = title
                        updated.location = location
                        updated.notes = notes
                        updated.time = time
                        updated.reminderOffset = reminderOffset
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
