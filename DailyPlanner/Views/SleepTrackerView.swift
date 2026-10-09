import SwiftUI

// MARK: - Sleep Tracker View
struct SleepTrackerView: View {
    @EnvironmentObject var vm: PlannerViewModel

    private var entry: DailyEntry { vm.currentEntry }
    private var sleep: SleepEntry { entry.sleep }

    @State private var showEditSheet = false
    @State private var isSyncingHealth = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section header with close button (consistent with other sections)
                VStack(spacing: 16) {
                    // Summary Card
                    sleepSummaryCard

                    // Sync from Health button
                    syncHealthButton

                    // Quality Section
                    sleepQualityCard

                    // Sleep Timeline
                    if sleep.bedtime != nil || sleep.wakeTime != nil {
                        sleepTimelineCard
                    }

                    // Weekly Overview
                    weeklyOverviewCard

                    // Notes
                    if !sleep.notes.isEmpty {
                        notesCard
                    }

                    // Log Button
                    Button(action: { showEditSheet = true }) {
                        Label(sleep.bedtime == nil ? "Log Sleep" : "Edit Sleep",
                              systemImage: sleep.bedtime == nil ? "moon.fill" : "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.25, green: 0.15, blue: 0.65))
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showEditSheet) {
            SleepEditSheet(sleep: sleep) { updated in
                vm.updateSleep(updated)
            }
        }
        .onAppear {
            if sleep.bedtime == nil {
                syncFromHealthKit()
            }
        }
    }

    // MARK: - Sync from Health Button
    private var syncHealthButton: some View {
        Button(action: syncFromHealthKit) {
            HStack(spacing: 8) {
                if isSyncingHealth {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                }
                Text(isSyncingHealth ? "Syncing…" : "Sync from Apple Health")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.9, green: 0.2, blue: 0.3),
                             Color(red: 0.7, green: 0.1, blue: 0.4)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isSyncingHealth)
        .padding(.horizontal)
    }

    private func syncFromHealthKit() {
        guard HealthKitManager.shared.isAvailable else { return }
        isSyncingHealth = true
        HealthKitManager.shared.requestAuthorization {
            HealthKitManager.shared.fetchSleepData(for: vm.selectedDate) { bedtime, wakeTime, duration in
                isSyncingHealth = false
                guard bedtime != nil || wakeTime != nil else { return }
                vm.updateSleep(SleepEntry(
                    bedtime: bedtime ?? sleep.bedtime,
                    wakeTime: wakeTime ?? sleep.wakeTime,
                    quality: sleep.quality,
                    notes: sleep.notes
                ))
            }
        }
    }

    // MARK: - Summary Card
    private var sleepSummaryCard: some View {
        VStack(spacing: 0) {
            // Header gradient
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.07, blue: 0.38),
                             Color(red: 0.25, green: 0.15, blue: 0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color(red: 0.85, green: 0.80, blue: 1.0))
                    Text(sleep.durationString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Total Sleep")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                    if let hours = sleep.durationHours {
                        sleepQualityBadge(hours: hours)
                    }
                }
                .padding(.vertical, 28)
            }
            .cornerRadius(16)

            // Stats row
            HStack(spacing: 0) {
                sleepStatCell(
                    icon: "moon.fill",
                    label: "Bedtime",
                    value: sleep.bedtime.map { timeString($0) } ?? "--",
                    color: Color(red: 0.35, green: 0.20, blue: 0.80)
                )
                Divider().frame(height: 40)
                sleepStatCell(
                    icon: "sun.max.fill",
                    label: "Wake Time",
                    value: sleep.wakeTime.map { timeString($0) } ?? "--",
                    color: .orange
                )
                Divider().frame(height: 40)
                sleepStatCell(
                    icon: "star.fill",
                    label: "Quality",
                    value: sleep.quality > 0 ? String(repeating: "★", count: sleep.quality) : "--",
                    color: .yellow
                )
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }

    private func sleepStatCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            Text(value).font(.system(size: 14, weight: .semibold))
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func sleepQualityBadge(hours: Double) -> some View {
        let (label, color): (String, Color) = {
            switch hours {
            case ..<5:   return ("Insufficient", .red)
            case 5..<6:  return ("Short", .orange)
            case 6..<7:  return ("Fair", .yellow)
            case 7..<9:  return ("Optimal", Color(red: 0.1, green: 0.75, blue: 0.4))
            default:     return ("Long", .blue)
            }
        }()
        Text(label)
            .font(.caption).fontWeight(.semibold)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(color.opacity(0.25))
            .foregroundColor(color)
            .cornerRadius(10)
    }

    // MARK: - Quality Card
    private var sleepQualityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Quality").font(.headline).padding(.horizontal)
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: { vm.updateSleep(SleepEntry(bedtime: sleep.bedtime, wakeTime: sleep.wakeTime, quality: star, notes: sleep.notes)) }) {
                        VStack(spacing: 4) {
                            Image(systemName: star <= sleep.quality ? "star.fill" : "star")
                                .font(.system(size: 24))
                                .foregroundColor(star <= sleep.quality ? .yellow : Color(.systemGray4))
                            Text(qualityLabel(star))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private func qualityLabel(_ stars: Int) -> String {
        switch stars {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Perfect"
        default: return ""
        }
    }

    // MARK: - Timeline Card
    private var sleepTimelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Timeline").font(.headline).padding(.horizontal)
            VStack(spacing: 0) {
                if let bedtime = sleep.bedtime {
                    timelineRow(icon: "moon.fill", color: Color(red: 0.25, green: 0.15, blue: 0.65), label: "Bedtime", time: timeString(bedtime))
                }
                if sleep.bedtime != nil && sleep.wakeTime != nil {
                    Rectangle().fill(Color(.separator)).frame(width: 2, height: 30).padding(.leading, 27)
                }
                if let wakeTime = sleep.wakeTime {
                    timelineRow(icon: "sun.max.fill", color: .orange, label: "Wake Up", time: timeString(wakeTime))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private func timelineRow(icon: String, color: Color, label: String, time: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundColor(color).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline).fontWeight(.medium)
                Text(time).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Weekly Overview
    private var weeklyOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week").font(.headline).padding(.horizontal)
            HStack(spacing: 8) {
                ForEach(last7Days(), id: \.self) { date in
                    weekDayCell(date: date)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private func weekDayCell(date: Date) -> some View {
        let cal = Calendar.current
        let dateKey = vm.dateKey(for: date)
        let sleepData = vm.entries[dateKey]?.sleep
        let hours = sleepData?.durationHours ?? 0
        let isToday = cal.isDateInToday(date)

        return VStack(spacing: 4) {
            Text(dayLetter(date))
                .font(.caption2)
                .foregroundColor(isToday ? Color(red: 0.25, green: 0.15, blue: 0.65) : .secondary)
                .fontWeight(isToday ? .bold : .regular)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 50)
                RoundedRectangle(cornerRadius: 4)
                    .fill(hours > 0 ? Color(red: 0.25, green: 0.15, blue: 0.65) : Color.clear)
                    .frame(width: 24, height: min(50, CGFloat(hours / 10.0) * 50))
            }
            Text(hours > 0 ? String(format: "%.0fh", hours) : "-")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    private func last7Days() -> [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: Date()) }
    }

    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            Text(sleep.notes)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Sleep Edit Sheet
struct SleepEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sleep: SleepEntry
    let onSave: (SleepEntry) -> Void

    @State private var bedtime: Date
    @State private var wakeTime: Date
    @State private var hasBedtime: Bool
    @State private var hasWakeTime: Bool
    @State private var quality: Int
    @State private var notes: String

    init(sleep: SleepEntry, onSave: @escaping (SleepEntry) -> Void) {
        self.sleep = sleep
        self.onSave = onSave
        // Default bedtime: 10 PM, wake: 6 AM
        let cal = Calendar.current
        let now = Date()
        let defaultBed = cal.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
        let defaultWake = cal.date(bySettingHour: 6, minute: 0, second: 0, of: now) ?? now
        _bedtime = State(initialValue: sleep.bedtime ?? defaultBed)
        _wakeTime = State(initialValue: sleep.wakeTime ?? defaultWake)
        _hasBedtime = State(initialValue: sleep.bedtime != nil)
        _hasWakeTime = State(initialValue: sleep.wakeTime != nil)
        _quality = State(initialValue: sleep.quality)
        _notes = State(initialValue: sleep.notes)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Bedtime") {
                    Toggle("Log Bedtime", isOn: $hasBedtime)
                    if hasBedtime {
                        DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
                    }
                }
                Section("Wake Up") {
                    Toggle("Log Wake Time", isOn: $hasWakeTime)
                    if hasWakeTime {
                        DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    }
                }
                Section("Quality") {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button(action: { quality = star }) {
                                Image(systemName: star <= quality ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(star <= quality ? .yellow : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Spacer()
                        if quality > 0 {
                            Button("Clear") { quality = 0 }.font(.caption).foregroundColor(.red)
                        }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(SleepEntry(
                            bedtime: hasBedtime ? bedtime : nil,
                            wakeTime: hasWakeTime ? wakeTime : nil,
                            quality: quality,
                            notes: notes
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
