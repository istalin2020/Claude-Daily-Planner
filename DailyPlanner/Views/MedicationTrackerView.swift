import SwiftUI
import UserNotifications

// MARK: - Medication Tracker View
struct MedicationTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false

    private var medications: [Medication] { vm.settings.medications }
    private var activeMeds: [Medication] { medications.filter(\.isActive) }
    private var todayLogs: Set<UUID> { vm.medicationLogsForToday() }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary banner
                summaryBanner

                // Today's schedule
                if !activeMeds.isEmpty {
                    todayScheduleSection
                }

                // All medications list
                allMedicationsSection

                // Add button
                if !vm.isFuture {
                    Button(action: { showAddSheet = true }) {
                        Label("Add Medication", systemImage: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.1, green: 0.6, blue: 0.65))
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showAddSheet) {
            MedicationEditSheet(medication: nil) { med in
                vm.addMedication(med)
            }
        }
    }

    // MARK: - Summary Banner
    private var summaryBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.6, blue: 0.65),
                             Color(red: 0.1, green: 0.45, blue: 0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .cornerRadius(16)
                VStack(spacing: 6) {
                    Image(systemName: "pill.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    Text("\(todayLogs.count)/\(activeMeds.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Taken Today")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 20)
            }

            VStack(spacing: 10) {
                statPill(icon: "checkmark.circle.fill",
                         text: "\(todayLogs.count) taken",
                         color: Color(red: 0.1, green: 0.75, blue: 0.4))
                statPill(icon: "circle",
                         text: "\(activeMeds.count - todayLogs.count) remaining",
                         color: .orange)
                statPill(icon: "pills.fill",
                         text: "\(medications.count) total",
                         color: Color(red: 0.1, green: 0.6, blue: 0.65))
            }
        }
        .padding(.horizontal)
    }

    private func statPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            Text(text).font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Today's Schedule
    private var todayScheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Schedule")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(activeMeds) { med in
                    MedicationRow(
                        medication: med,
                        isTaken: todayLogs.contains(med.id),
                        onToggle: { vm.toggleMedicationTaken(med) },
                        onEdit: {
                            // inline edit not shown here, use allMedications section
                        },
                        onDelete: { vm.deleteMedication(med) }
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - All Medications
    private var allMedicationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All Medications").font(.headline)
                Spacer()
                if !medications.isEmpty {
                    Text("\(activeMeds.count) active").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if medications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.65).opacity(0.4))
                    Text("No medications added yet")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text("Tap 'Add Medication' to start tracking.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 8) {
                    ForEach(medications) { med in
                        MedicationListRow(
                            medication: med,
                            onToggleActive: { vm.toggleMedicationActive(med) },
                            onDelete: { vm.deleteMedication(med) }
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - Medication Row (today schedule)
struct MedicationRow: View {
    let medication: Medication
    let isTaken: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isTaken ? medication.swiftUIColor : Color(.systemGray5))
                        .frame(width: 42, height: 42)
                    Image(systemName: isTaken ? "checkmark" : "pill.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isTaken ? .white : medication.swiftUIColor)
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(medication.name)
                    .font(.system(size: 15, weight: .semibold))
                    .strikethrough(isTaken, color: .secondary)
                    .foregroundColor(isTaken ? .secondary : .primary)
                if !medication.dosage.isEmpty {
                    Text(medication.dosage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !medication.times.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(medication.times.prefix(3), id: \.self) { time in
                            Text(timeString(time))
                                .font(.system(size: 10))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(medication.swiftUIColor.opacity(0.12))
                                .foregroundColor(medication.swiftUIColor)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            Spacer()

            if isTaken {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(medication.swiftUIColor)
                    .font(.system(size: 20))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isTaken ? medication.swiftUIColor.opacity(0.05) : Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.2), value: isTaken)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Medication List Row (all meds management)
struct MedicationListRow: View {
    let medication: Medication
    let onToggleActive: () -> Void
    let onDelete: () -> Void
    @State private var showEdit = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(medication.swiftUIColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "pill.fill")
                    .foregroundColor(medication.swiftUIColor)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(medication.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(medication.isActive ? .primary : .secondary)
                    if !medication.isActive {
                        Text("Inactive")
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .foregroundColor(.secondary)
                            .cornerRadius(5)
                    }
                }
                if !medication.dosage.isEmpty {
                    Text(medication.dosage).font(.caption).foregroundColor(.secondary)
                }
                if !medication.times.isEmpty {
                    Text("\(medication.times.count) reminder\(medication.times.count == 1 ? "" : "s") daily")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Menu {
                Button(action: { showEdit = true }) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(action: onToggleActive) {
                    Label(medication.isActive ? "Deactivate" : "Activate",
                          systemImage: medication.isActive ? "pause.circle" : "play.circle")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showEdit) {
            MedicationEditSheetWrapper(medication: medication)
        }
    }
}

// MARK: - Edit wrapper for existing medication (routes save through vm)
struct MedicationEditSheetWrapper: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    let medication: Medication

    var body: some View {
        MedicationEditSheet(medication: medication) { updated in
            vm.deleteMedication(medication)
            vm.addMedication(updated)
        }
        .environmentObject(vm)
    }
}

// MARK: - Medication Edit Sheet
struct MedicationEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vm: PlannerViewModel

    let existing: Medication?
    let onSave: (Medication) -> Void

    @State private var name: String
    @State private var dosage: String
    @State private var notes: String
    @State private var color: String
    @State private var times: [Date]
    @State private var newTime = Date()
    @State private var showTimePicker = false

    private let colors = ["blue", "purple", "green", "orange", "red", "pink", "teal"]

    init(medication: Medication?, onSave: @escaping (Medication) -> Void) {
        self.existing = medication
        self.onSave = onSave
        _name   = State(initialValue: medication?.name   ?? "")
        _dosage = State(initialValue: medication?.dosage ?? "")
        _notes  = State(initialValue: medication?.notes  ?? "")
        _color  = State(initialValue: medication?.color  ?? "blue")
        _times  = State(initialValue: medication?.times  ?? [])
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Medication Details") {
                    TextField("Name (e.g. Vitamin D)", text: $name)
                    TextField("Dosage (e.g. 1000 IU)", text: $dosage)
                }
                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { c in
                            let col = Medication(name: "", color: c).swiftUIColor
                            Button(action: { color = c }) {
                                ZStack {
                                    Circle().fill(col).frame(width: 32, height: 32)
                                    if color == c {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    ForEach(times, id: \.self) { t in
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(Medication(name: "", color: color).swiftUIColor)
                            Text(timeStr(t))
                            Spacer()
                        }
                    }
                    .onDelete { times.remove(atOffsets: $0) }

                    Button(action: { showTimePicker = true }) {
                        Label("Add Reminder Time", systemImage: "plus.circle")
                            .foregroundColor(Medication(name: "", color: color).swiftUIColor)
                    }
                } header: {
                    Text("Daily Reminders")
                } footer: {
                    Text("You'll receive a notification at each time to take this medication.")
                        .font(.caption)
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .navigationTitle(existing == nil ? "Add Medication" : "Edit Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let med = Medication(
                            id: existing?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            dosage: dosage,
                            times: times,
                            isActive: existing?.isActive ?? true,
                            notes: notes,
                            color: color
                        )
                        onSave(med)
                        scheduleMedicationNotifications(med)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(time: $newTime) {
                    times.append(newTime)
                }
            }
        }
    }

    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
    }

    private func scheduleMedicationNotifications(_ med: Medication) {
        let center = UNUserNotificationCenter.current()
        // Remove old notifications for this med
        center.removePendingNotificationRequests(withIdentifiers: med.times.indices.map { "\(med.id)_\($0)" })

        for (i, time) in med.times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Medication Reminder"
            content.body = "\(med.name)\(med.dosage.isEmpty ? "" : " · \(med.dosage)")"
            content.sound = .default

            var comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            comps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(
                identifier: "\(med.id)_\(i)",
                content: content,
                trigger: trigger
            )
            center.add(req)
        }
    }
}
