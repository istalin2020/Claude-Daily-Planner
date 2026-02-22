import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showTimePicker   = false
    @State private var pickerTime       = defaultPickerTime()
    @State private var permissionDenied = false

    // Suggested messages shown to the user for awareness
    private let reminderMessages = NotificationManager.reminderMessages

    var body: some View {
        NavigationView {
            Form {

                // ── NOTIFICATIONS ──────────────────────────────────────
                Section {
                    Toggle(isOn: $vm.settings.notificationsEnabled) {
                        Label("Enable Daily Reminders", systemImage: "bell.badge.fill")
                    }
                    .tint(Color(red: 0.45, green: 0.25, blue: 0.85))
                    .onChange(of: vm.settings.notificationsEnabled) { enabled in
                        if enabled {
                            requestNotificationPermission()
                        } else {
                            NotificationManager.shared.cancelAll()
                        }
                    }

                    if vm.settings.notificationsEnabled {
                        if vm.settings.notificationTimes.isEmpty {
                            Text("No reminders set — tap ＋ to add one.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(vm.settings.notificationTimes, id: \.self) { time in
                                HStack {
                                    Image(systemName: "alarm.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    Text(formattedTime(time))
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                }
                            }
                            .onDelete { offsets in
                                vm.settings.notificationTimes.remove(atOffsets: offsets)
                                NotificationManager.shared.scheduleNotifications(
                                    times: vm.settings.notificationTimes,
                                    tone: vm.settings.notificationTone)
                            }
                        }

                        Button {
                            pickerTime = Self.defaultPickerTime()
                            showTimePicker = true
                        } label: {
                            Label("Add Reminder Time", systemImage: "plus.circle.fill")
                                .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                        }
                    }

                    if permissionDenied {
                        Label("Notifications are blocked. Enable them in Settings → Daily Planner.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if vm.settings.notificationsEnabled {
                        Picker(selection: $vm.settings.notificationTone) {
                            ForEach(NotificationTone.allCases) { tone in
                                Text(tone.rawValue).tag(tone)
                            }
                        } label: {
                            Label("Notification Tone", systemImage: "speaker.wave.2.fill")
                        }
                        .onChange(of: vm.settings.notificationTone) { _ in
                            if !vm.settings.notificationTimes.isEmpty {
                                NotificationManager.shared.scheduleNotifications(
                                    times: vm.settings.notificationTimes,
                                    tone: vm.settings.notificationTone)
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if vm.settings.notificationsEnabled {
                        Text("Add up to 7 times. Each reminder carries a unique motivating message. The selected tone applies to daily reminders, schedule blocks, and appointment reminders.")
                    }
                }

                // ── REMINDER MESSAGES (read-only preview) ─────────────
                if vm.settings.notificationsEnabled {
                    Section {
                        ForEach(Array(reminderMessages.enumerated()), id: \.offset) { idx, msg in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    } header: {
                        Text("Reminder Messages (rotate automatically)")
                    }
                }

                // ── APPEARANCE ─────────────────────────────────────────
                Section("Appearance") {
                    Toggle(isOn: $vm.settings.isDarkMode) {
                        Label("Dark Mode", systemImage: vm.settings.isDarkMode ? "moon.fill" : "sun.max.fill")
                    }
                    .tint(Color(red: 0.45, green: 0.25, blue: 0.85))
                }

                // ── TASK MANAGEMENT ────────────────────────────────────
                Section {
                    Toggle(isOn: $vm.settings.autoRollover) {
                        Label("Roll Over Pending Tasks Daily",
                              systemImage: "arrow.uturn.right.circle.fill")
                    }
                    .tint(Color(red: 0.45, green: 0.25, blue: 0.85))

                    if vm.settings.autoRollover {
                        Text("Incomplete tasks from the previous day are automatically carried forward to today.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Incomplete tasks stay on the day they were created and are not carried forward.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Task Management")
                }

                // ── ABOUT ──────────────────────────────────────────────
                Section("About") {
                    HStack {
                        Text("Daily Planner")
                        Spacer()
                        Text("Version 1.0")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    HStack {
                        Text("Data Storage")
                        Spacer()
                        Text("On Device")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(time: $pickerTime) {
                    guard vm.settings.notificationTimes.count < 7 else { return }
                    vm.settings.notificationTimes.append(pickerTime)
                    NotificationManager.shared.scheduleNotifications(
                        times: vm.settings.notificationTimes)
                }
            }
        }
    }

    // MARK: - Helpers
    private func formattedTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private static func defaultPickerTime() -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private func requestNotificationPermission() {
        NotificationManager.shared.requestPermission { granted in
            if granted {
                permissionDenied = false
                if !vm.settings.notificationTimes.isEmpty {
                    NotificationManager.shared.scheduleNotifications(
                        times: vm.settings.notificationTimes,
                        tone: vm.settings.notificationTone)
                }
            } else {
                permissionDenied = true
                vm.settings.notificationsEnabled = false
            }
        }
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    @Binding var time: Date
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))

                Text("Choose Reminder Time")
                    .font(.title3).fontWeight(.bold)

                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Button {
                    onAdd()
                    dismiss()
                } label: {
                    Text("Add Reminder")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.45, green: 0.25, blue: 0.85))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
