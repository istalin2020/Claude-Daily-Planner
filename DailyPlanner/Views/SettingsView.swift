import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Environment(\.dismiss) var dismiss

    @State private var showTimePicker     = false
    @State private var pickerTime         = defaultPickerTime()
    @State private var permissionDenied   = false
    @State private var monthlyIncomeText  = ""
    @State private var showExport         = false
    @State private var showSpendingTrends = false
    @State private var showWeeklySummary  = false
    @State private var showPomodoro       = false
    @State private var showProUpgrade     = false

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
                    .onChange(of: vm.settings.notificationsEnabled) { _, enabled in
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
                        .onChange(of: vm.settings.notificationTone) { _, newTone in
                            if !vm.settings.notificationTimes.isEmpty {
                                NotificationManager.shared.scheduleNotifications(
                                    times: vm.settings.notificationTimes,
                                    tone: newTone)
                            }
                            // Play a 1-second preview so the user hears the chosen tone
                            NotificationManager.shared.playPreview(tone: newTone)
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

                // ── DISPLAY ─────────────────────────────────────────────
                Section("Display") {
                    Toggle(isOn: $vm.settings.isDarkMode) {
                        Label("Dark Mode", systemImage: vm.settings.isDarkMode ? "moon.fill" : "sun.max.fill")
                    }
                    .tint(Color(red: 0.45, green: 0.25, blue: 0.85))
                }

                // ── FINANCE ────────────────────────────────────────────
                Section {
                    Picker(selection: $vm.settings.currency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    } label: {
                        Label("Currency", systemImage: "dollarsign.circle.fill")
                    }

                    HStack(spacing: 8) {
                        Label("Monthly Salary", systemImage: "banknote.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(vm.settings.currency.symbol)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $monthlyIncomeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: monthlyIncomeText) { _, val in
                                vm.settings.monthlyIncome = Double(val) ?? 0
                            }
                    }
                } header: {
                    Text("Finance")
                } footer: {
                    Text("Monthly salary is used in the monthly income summary in Expense Tracker. The currency symbol applies throughout the app.")
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

                // ── PRO UPGRADE BANNER ─────────────────────────────────
                if !pro.isPro {
                    Section {
                        Button(action: { showProUpgrade = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.78, blue: 0.0),
                                                     Color(red: 1.0, green: 0.45, blue: 0.0)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.white).font(.system(size: 18))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to PRO")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("₹99/month · ₹999/year · Unlock all 15 features")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .sheet(isPresented: $showProUpgrade) {
                        ProUpgradeView().environmentObject(pro)
                    }
                }

                // ── APPEARANCE ─────────────────────────────────────────
                Section {
                    HStack {
                        Label("Color Theme", systemImage: "paintpalette.fill")
                        Spacer()
                        if pro.isPro {
                            Text(vm.settings.themeColor.rawValue)
                                .foregroundColor(.secondary).font(.caption)
                        } else {
                            ProInlineBadge()
                        }
                    }
                    if pro.isPro {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(ThemeColor.allCases) { theme in
                                Button(action: {
                                    vm.settings.themeColor = theme
                                    vm.saveSettings()
                                }) {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: [theme.primary, theme.secondary],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 36, height: 36)
                                            if vm.settings.themeColor == theme {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        Text(theme.rawValue)
                                            .font(.system(size: 10))
                                            .foregroundColor(vm.settings.themeColor == theme ? theme.primary : .secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button(action: { showProUpgrade = true }) {
                            HStack {
                                Text("Unlock 8 color themes with PRO")
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("Upgrade →").font(.caption).foregroundColor(Color(red: 0.30, green: 0.10, blue: 0.60))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    Text("Appearance")
                }

                // ── SYNC ───────────────────────────────────────────────
                Section {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        if !pro.isPro {
                            ProInlineBadge()
                        } else if vm.iCloudAvailable {
                            Label("On", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundColor(.green)
                        } else {
                            Label("Off — Sign in to iCloud", systemImage: "xmark.circle.fill")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .onTapGesture { if !pro.isPro { showProUpgrade = true } }
                } header: {
                    Text("Sync")
                } footer: {
                    Text(pro.isPro
                         ? (vm.iCloudAvailable ? "Your data syncs across all Apple devices." : "Sign in to iCloud in iOS Settings.")
                         : "iCloud Sync is a PRO feature.")
                }

                // ── TOOLS ──────────────────────────────────────────────
                Section("Tools") {
                    Button {
                        if pro.isPro { showPomodoro = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Pomodoro Timer", systemImage: "timer")
                                .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
                            Spacer()
                            if !pro.isPro { ProInlineBadge() }
                        }
                    }
                }

                // ── ABOUT ──────────────────────────────────────────────
                Section("About") {
                    HStack {
                        Text("Daily Planner")
                        Spacer()
                        if pro.isPro {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.0))
                                Text("PRO").font(.caption).foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.0)).fontWeight(.bold)
                            }
                        } else {
                            Text("Free").foregroundColor(.secondary).font(.caption)
                        }
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0").foregroundColor(.secondary).font(.caption)
                    }
                    Button {
                        if pro.isPro { showExport = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Export Data", systemImage: "square.and.arrow.up.fill")
                                .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                            Spacer()
                            if !pro.isPro { ProInlineBadge() }
                        }
                    }
                    Button {
                        if pro.isPro { showSpendingTrends = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Spending Trends", systemImage: "chart.bar.fill")
                                .foregroundColor(Color(red: 0.1, green: 0.65, blue: 0.35))
                            Spacer()
                            if !pro.isPro { ProInlineBadge() }
                        }
                    }
                    Button {
                        if pro.isPro { showWeeklySummary = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Weekly / Monthly Summary", systemImage: "calendar.badge.clock")
                                .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                            Spacer()
                            if !pro.isPro { ProInlineBadge() }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if vm.settings.monthlyIncome > 0 {
                    monthlyIncomeText = String(format: "%.2f", vm.settings.monthlyIncome)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
            .sheet(isPresented: $showExport) {
                ExportView().environmentObject(vm)
            }
            .sheet(isPresented: $showSpendingTrends) {
                SpendingTrendsView().environmentObject(vm)
            }
            .sheet(isPresented: $showWeeklySummary) {
                WeeklySummaryView().environmentObject(vm)
            }
            .sheet(isPresented: $showPomodoro) {
                PomodoroTimerView()
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView().environmentObject(pro)
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
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
