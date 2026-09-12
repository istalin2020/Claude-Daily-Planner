import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Environment(\.dismiss) var dismiss

    @State private var showTimePicker     = false
    @State private var pickerTime         = defaultPickerTime()
    @State private var permissionDenied   = false
    @State private var showExport         = false
    @State private var showWeeklySummary  = false
    @State private var showPomodoro       = false
    @State private var showProUpgrade     = false
    @State private var showSharing        = false

    // Smart Food Analysis diagnostics
    @State private var smartFoodTesting    = false
    @State private var smartFoodTestResult : String? = nil

    /// True only when a typed dish or a photo will actually reach the service.
    /// Mirrors the same three conditions FoodTrackerView gates on.
    private var smartFoodActive: Bool {
        pro.isPro && vm.settings.cloudFoodAnalysisEnabled && CloudFoodAnalyzer.isConfigured
    }

    /// The specific reason smart analysis isn't running, so the fix is obvious.
    private var smartFoodStatusDetail: String {
        if !CloudFoodAnalyzer.isConfigured {
            return "No analysis service in this build — food is estimated on your device."
        }
        if !vm.settings.cloudFoodAnalysisEnabled {
            return "Switched off above — food is estimated on your device."
        }
        return "Photos and typed dishes are analysed by the service."
    }

    private func testSmartFood() {
        smartFoodTesting = true
        smartFoodTestResult = nil
        CloudFoodAnalyzer.checkHealth { result in
            smartFoodTesting = false
            switch result {
            case .success(let health):
                smartFoodTestResult = health.configured
                    ? "Connected. Running \(health.model)."
                    : "Reached the service, but its API key isn't set. Add the OPENAI_API_KEY secret to the Worker."
            case .failure(let error):
                smartFoodTestResult = (error as? CloudFoodError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {

                // ── 1. ROLL OVER PENDING TASKS ─────────────────────────────
                Section {
                    Toggle(isOn: $vm.settings.autoRollover) {
                        Label("Roll Over Pending Tasks Daily",
                              systemImage: "arrow.uturn.right.circle.fill")
                    }
                    .tint(vm.settings.themeColor.primary)

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
                    Text("Rollover")
                }

                // ── 2. FOCUS TIMER (POMODORO) ──────────────────────────────
                Section("Focus Time") {
                    Button {
                        if pro.isPro { showPomodoro = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Open Focus Timer", systemImage: "timer")
                                .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
                            Spacer()
                            if !pro.isPro {
                                ProInlineBadge()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ── 3. iCLOUD SYNC ────────────────────────────────────────
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
                            Label("Sign in to iCloud", systemImage: "xmark.circle.fill")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .onTapGesture { if !pro.isPro { showProUpgrade = true } }
                } header: {
                    Text("iCloud Sync")
                } footer: {
                    Text(pro.isPro
                         ? (vm.iCloudAvailable ? "Your data syncs across all Apple devices." : "Sign in to iCloud in iOS Settings to enable sync.")
                         : "iCloud Sync is a PRO feature. Upgrade to sync across all your Apple devices.")
                }

                // ── 4. CURRENCY ────────────────────────────────────────────
                Section("Currency") {
                    Picker(selection: $vm.settings.currency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    } label: {
                        Label("Currency", systemImage: "dollarsign.circle.fill")
                    }
                    .pickerStyle(.navigationLink)
                }

                // ── CARRY FORWARD ─────────────────────────────────────────
                Section {
                    Toggle(isOn: Binding(
                        get: { vm.settings.autoCarryForward },
                        set: { vm.settings.autoCarryForward = $0; vm.saveSettings() }
                    )) {
                        Label("Carry Forward Balance", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    }
                    .tint(Color(red: 0.1, green: 0.65, blue: 0.35))
                } footer: {
                    Text("Automatically carries the previous month's balance and savings into the new month as income and savings entries.")
                }

                // ── SMART BANK SMS ───────────────────────────────────────
                Section {
                    if pro.isPro {
                        Toggle(isOn: Binding(
                            get: { vm.settings.smartBankSMSEnabled },
                            set: { vm.settings.smartBankSMSEnabled = $0; vm.saveSettings() }
                        )) {
                            Label("Smart Bank SMS", systemImage: "message.badge.fill")
                        }
                        .tint(.purple)
                    } else {
                        Button {
                            showProUpgrade = true
                        } label: {
                            HStack {
                                Label("Smart Bank SMS", systemImage: "message.badge.fill")
                                Spacer()
                                ProInlineBadge()
                            }
                        }
                    }
                } header: {
                    Text("Bank SMS Tracking")
                } footer: {
                    Text("Copy a bank SMS message, then open the app. We'll auto-detect the transaction and offer to add it as income or expense. You can also paste SMS manually from the Expenses section.")
                }

                // ── SMART FOOD ANALYSIS (photo + typed dish name) ─────────
                Section {
                    if pro.isPro {
                        Toggle(isOn: Binding(
                            get: { vm.settings.cloudFoodAnalysisEnabled },
                            set: { vm.settings.cloudFoodAnalysisEnabled = $0; vm.saveSettings() }
                        )) {
                            Label("Smart Food Analysis", systemImage: "sparkles")
                        }
                        .tint(.orange)
                        .disabled(!CloudFoodAnalyzer.isConfigured)

                        // Says in one line whether smart analysis is actually
                        // running, and why not when it isn't — no guessing.
                        HStack(spacing: 8) {
                            Image(systemName: smartFoodActive
                                  ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(smartFoodActive ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(smartFoodActive ? "Active" : "Not active")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(smartFoodStatusDetail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button {
                            testSmartFood()
                        } label: {
                            HStack {
                                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                                Spacer()
                                if smartFoodTesting { ProgressView() }
                            }
                        }
                        .disabled(!CloudFoodAnalyzer.isConfigured || smartFoodTesting)

                        if let result = smartFoodTestResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Button {
                            showProUpgrade = true
                        } label: {
                            HStack {
                                Label("Smart Food Analysis", systemImage: "sparkles")
                                Spacer()
                                ProInlineBadge()
                            }
                        }
                    }
                } header: {
                    Text("Food Analysis")
                } footer: {
                    if pro.isPro && !CloudFoodAnalyzer.isConfigured {
                        Text("Smart analysis isn't available in this build yet — food is estimated on your device for now.")
                    } else if pro.isPro {
                        Text("When on, a photo of your meal — or a dish name you type — is sent securely for analysis and comes back with every item identified, portion sizes, calories and a full nutrition breakdown. Switch it off to keep everything on your device, where estimates come from a built-in food list and are more limited. Photos and dish names are used only to produce the estimate and are never stored.")
                    } else {
                        Text("PRO identifies everything on your plate — from a photo or just the dish name — and returns calories, protein, carbs, fat, fibre and iron. On the free plan, food is estimated on your device from a built-in list.")
                    }
                }

                // ── 5. ENABLE DAILY REMINDERS + HORIZONTAL TIME BAR ───────
                Section {
                    Toggle(isOn: $vm.settings.notificationsEnabled) {
                        Label("Enable Daily Reminders", systemImage: "bell.badge.fill")
                    }
                    .tint(vm.settings.themeColor.primary)
                    .onChange(of: vm.settings.notificationsEnabled) { _, enabled in
                        if enabled {
                            requestNotificationPermission()
                        } else {
                            NotificationManager.shared.cancelAll()
                        }
                    }

                    if vm.settings.notificationsEnabled {
                        // ── Horizontal scrolling reminder times ──────────────
                        VStack(alignment: .leading, spacing: 8) {
                            if vm.settings.notificationTimes.isEmpty {
                                Text("No reminders set — tap ＋ to add one.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding(.vertical, 4)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(vm.settings.notificationTimes.enumerated()), id: \.element) { idx, time in
                                            HStack(spacing: 6) {
                                                Image(systemName: "alarm.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.orange)
                                                Text(formattedTime(time))
                                                    .font(.system(size: 13, weight: .semibold))
                                                Button {
                                                    vm.settings.notificationTimes.remove(at: idx)
                                                    vm.refreshDailyReminders()
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.secondary.opacity(0.6))
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Color.orange.opacity(0.12))
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }

                            Button {
                                guard vm.settings.notificationTimes.count < 7 else { return }
                                pickerTime = Self.defaultPickerTime()
                                showTimePicker = true
                            } label: {
                                Label(vm.settings.notificationTimes.count >= 7
                                      ? "Maximum 7 reminders reached"
                                      : "Add Reminder Time (\(vm.settings.notificationTimes.count)/7)",
                                      systemImage: "plus.circle.fill")
                                    .foregroundColor(vm.settings.notificationTimes.count >= 7
                                                     ? .secondary
                                                     : vm.settings.themeColor.primary)
                            }
                            .disabled(vm.settings.notificationTimes.count >= 7)
                        }
                    }

                    if permissionDenied {
                        Label("Notifications are blocked. Enable them in Settings → Daily Planner.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("Daily Reminders")
                } footer: {
                    if vm.settings.notificationsEnabled {
                        Text("Add up to 7 times. Each reminder carries a unique motivating message. Tap × on a time chip to remove it.")
                    }
                }

                // ── 6. NOTIFICATION TONE ───────────────────────────────────
                if vm.settings.notificationsEnabled {
                    Section("Notification Tone") {
                        Picker(selection: $vm.settings.notificationTone) {
                            ForEach(NotificationTone.allCases) { tone in
                                Text(tone.rawValue).tag(tone)
                            }
                        } label: {
                            Label("Notification Tone", systemImage: "speaker.wave.2.fill")
                        }
                        .onChange(of: vm.settings.notificationTone) { _, newTone in
                            if !vm.settings.notificationTimes.isEmpty {
                                vm.refreshDailyReminders()
                            }
                            NotificationManager.shared.playPreview(tone: newTone)
                        }
                    }
                }

                // ── 7. SHARING TASKS (PRO) ─────────────────────────────────
                Section {
                    Button {
                        if pro.isPro { showSharing = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Share Tasks", systemImage: "square.and.arrow.up.fill")
                                .foregroundColor(vm.settings.themeColor.primary)
                            Spacer()
                            if !pro.isPro {
                                ProInlineBadge()
                            } else {
                                if vm.settings.sharingSettings.isEnabled {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Text("On")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Sharing")
                } footer: {
                    Text(pro.isPro
                         ? "Share your task categories with family or friends. The entire category will be shared."
                         : "Task Sharing is a PRO feature. Upgrade to share your task lists with others.")
                }

                // ── 9. EXPORT DATA ─────────────────────────────────────────
                Section("Export Data") {
                    Button {
                        if pro.isPro { showExport = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Export Data (CSV / Report)", systemImage: "square.and.arrow.up.fill")
                                .foregroundColor(vm.settings.themeColor.primary)
                            Spacer()
                            if !pro.isPro {
                                ProInlineBadge()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ── 9. WEEKLY / MONTHLY SUMMARY ────────────────────────────
                Section("Reports") {
                    Button {
                        if pro.isPro { showWeeklySummary = true } else { showProUpgrade = true }
                    } label: {
                        HStack {
                            Label("Weekly / Monthly Summary", systemImage: "calendar.badge.clock")
                                .foregroundColor(vm.settings.themeColor.primary)
                            Spacer()
                            if !pro.isPro {
                                ProInlineBadge()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ── 10. DISPLAY ───────────────────────────────────────────
                Section("Display") {
                    Toggle(isOn: $vm.settings.isDarkMode) {
                        Label("Dark Mode", systemImage: vm.settings.isDarkMode ? "moon.fill" : "sun.max.fill")
                    }
                    .tint(vm.settings.themeColor.primary)

                    if pro.isPro {
                        Toggle(isOn: Binding(
                            get: { vm.settings.isLiquidGlass },
                            set: { vm.settings.isLiquidGlass = $0; vm.saveSettings() }
                        )) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.6, green: 0.85, blue: 1.0),
                                                    Color(red: 0.4, green: 0.6, blue: 0.95)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text("Liquid Glass")
                                    .font(.system(size: 15))
                            }
                        }
                        .tint(vm.settings.themeColor.primary)
                    } else {
                        Button(action: { showProUpgrade = true }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.6, green: 0.85, blue: 1.0),
                                                    Color(red: 0.4, green: 0.6, blue: 0.95)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text("Liquid Glass")
                                    .font(.system(size: 15))
                                Spacer()
                                ProInlineBadge()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // ── 11. COLOR THEME ────────────────────────────────────────
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
                    Text("Color Theme")
                }

                // ── PRO UPGRADE BANNER (if not PRO) ───────────────────────
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
                }

                // ── DEVELOPER TESTING (DEBUG builds only) ──────────────────
                // Compiled out of Release builds, so this never ships to the
                // App Store and real users stay gated by their subscription.
                #if DEBUG
                Section {
                    Toggle(isOn: $pro.devProOverride) {
                        HStack(spacing: 8) {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unlock All PRO Features")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Testing only — Debug builds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.orange)
                } header: {
                    Text("Developer")
                } footer: {
                    Text("This switch exists only in Debug builds on your own device. It is removed automatically when the app is archived for App Store Connect, so published users are gated by their real subscription.")
                }
                #endif

                // ── 12. ABOUT DAILY PLANNER ────────────────────────────────
                Section("About Daily Planner") {
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
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1").foregroundColor(.secondary).font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
                    vm.refreshDailyReminders()
                }
            }
            .sheet(isPresented: $showExport) {
                ExportView().environmentObject(vm)
            }
            .sheet(isPresented: $showWeeklySummary) {
                WeeklySummaryView().environmentObject(vm)
            }
            .sheet(isPresented: $showPomodoro) {
                PomodoroTimerView().environmentObject(vm)
            }
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView().environmentObject(pro)
            }
            .sheet(isPresented: $showSharing) {
                SharingView().environmentObject(vm).environmentObject(pro)
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
                    vm.refreshDailyReminders()
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
    @Environment(\.themeAccent) private var accent

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 44))
                    .foregroundColor(accent)

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
                        .background(accent)
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
