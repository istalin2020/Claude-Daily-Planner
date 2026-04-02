import SwiftUI
import MessageUI

// MARK: - Sharing View (Settings Screen)
struct SharingView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showAddRecipient  = false
    @State private var recipientName     = ""
    @State private var recipientEmail    = ""
    @State private var emailError        = ""
    @State private var showShareSheet    = false
    @State private var shareContent      = ""
    @State private var selectedSection   : SharableSection? = nil

    private var sharing: SharingSettings {
        get { vm.settings.sharingSettings }
    }

    var body: some View {
        NavigationView {
            Form {

                // ── ENABLE SHARING ──────────────────────────────────────────
                Section {
                    Toggle(isOn: Binding(
                        get: { vm.settings.sharingSettings.isEnabled },
                        set: { vm.settings.sharingSettings.isEnabled = $0; vm.saveSettings() }
                    )) {
                        Label("Enable Task Sharing", systemImage: "square.and.arrow.up.fill")
                    }
                    .tint(Color(red: 0.45, green: 0.25, blue: 0.85))
                } header: {
                    Text("Sharing")
                } footer: {
                    Text("Share your tasks and trackers with family members or friends via Gmail or iCloud.")
                }

                if vm.settings.sharingSettings.isEnabled {

                    // ── RECIPIENTS ──────────────────────────────────────────
                    Section {
                        ForEach(vm.settings.sharingSettings.recipients) { recipient in
                            RecipientRow(recipient: recipient) {
                                vm.settings.sharingSettings.recipients.removeAll { $0.id == recipient.id }
                                vm.saveSettings()
                            }
                        }
                        Button {
                            recipientName  = ""
                            recipientEmail = ""
                            emailError     = ""
                            showAddRecipient = true
                        } label: {
                            Label("Add Person to Share With", systemImage: "plus.circle.fill")
                                .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                        }
                    } header: {
                        Text("Share With")
                    } footer: {
                        Text("Add Gmail or iCloud email addresses of people you want to share with.")
                    }

                    // ── WHICH SECTIONS TO SHARE ─────────────────────────────
                    Section {
                        ForEach(SharableSection.allCases) { section in
                            SectionToggleRow(
                                section: section,
                                isOn: Binding(
                                    get: { vm.settings.sharingSettings.enabledSections.contains(section) },
                                    set: { enabled in
                                        if enabled {
                                            vm.settings.sharingSettings.enabledSections.insert(section)
                                        } else {
                                            vm.settings.sharingSettings.enabledSections.remove(section)
                                        }
                                        vm.saveSettings()
                                    }
                                )
                            )
                        }
                    } header: {
                        Text("What to Share")
                    } footer: {
                        Text("Choose which sections to share with your recipients. You can also share individual tasks from inside each list.")
                    }

                    // ── SHARE NOW BUTTONS ───────────────────────────────────
                    if !vm.settings.sharingSettings.recipients.isEmpty &&
                       !vm.settings.sharingSettings.enabledSections.isEmpty {
                        Section {
                            ForEach(SharableSection.allCases.filter {
                                vm.settings.sharingSettings.enabledSections.contains($0)
                            }) { section in
                                Button {
                                    shareContent    = vm.generateShareText(for: section)
                                    selectedSection = section
                                    showShareSheet  = true
                                } label: {
                                    HStack {
                                        Image(systemName: section.icon)
                                            .foregroundColor(section.color)
                                            .frame(width: 28)
                                        Text("Share \(section.rawValue)")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("Share Now")
                        } footer: {
                            Text("Tap any item above to share that section via email, Messages, or any other app.")
                        }
                    }
                }
            }
            .navigationTitle("Share Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddRecipient) {
                AddRecipientSheet(
                    name: $recipientName,
                    email: $recipientEmail,
                    errorMessage: $emailError
                ) {
                    let trimmed = recipientEmail.trimmingCharacters(in: .whitespaces)
                    guard isValidEmail(trimmed) else {
                        emailError = "Please enter a valid Gmail or iCloud email address."
                        return
                    }
                    let recipient = ShareRecipient(name: recipientName.trimmingCharacters(in: .whitespaces),
                                                  email: trimmed)
                    vm.settings.sharingSettings.recipients.append(recipient)
                    vm.saveSettings()
                    showAddRecipient = false
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityShareSheet(text: shareContent)
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Recipient Row
private struct RecipientRow: View {
    let recipient : ShareRecipient
    let onDelete  : () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recipient.accountType.icon)
                .font(.system(size: 22))
                .foregroundColor(recipient.accountType.color)
            VStack(alignment: .leading, spacing: 2) {
                if !recipient.name.isEmpty {
                    Text(recipient.name)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(recipient.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Section Toggle Row
private struct SectionToggleRow: View {
    let section : SharableSection
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(section.color.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: section.icon)
                        .font(.system(size: 14))
                        .foregroundColor(section.color)
                }
                Text(section.rawValue)
                    .font(.system(size: 14))
            }
        }
        .tint(section.color)
    }
}

// MARK: - Add Recipient Sheet
struct AddRecipientSheet: View {
    @Binding var name          : String
    @Binding var email         : String
    @Binding var errorMessage  : String
    let onAdd                  : () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var emailFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                        TextField("Name (optional)", text: $name)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: emailIcon)
                            .foregroundColor(emailColor)
                        TextField("Gmail or iCloud email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .focused($emailFocused)
                    }
                } header: {
                    Text("Recipient Details")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accepted: @gmail.com · @icloud.com · @me.com · @mac.com")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(action: onAdd) {
                        HStack {
                            Spacer()
                            Label("Add Recipient", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color(red: 0.45, green: 0.25, blue: 0.85))
                }
            }
            .navigationTitle("Add Recipient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { emailFocused = false }
        }
        .presentationDetents([.medium])
    }

    private var emailIcon: String {
        let lc = email.lowercased()
        if lc.hasSuffix("@gmail.com") { return "envelope.circle.fill" }
        if lc.hasSuffix("@icloud.com") || lc.hasSuffix("@me.com") || lc.hasSuffix("@mac.com") { return "icloud.fill" }
        return "at.circle.fill"
    }

    private var emailColor: Color {
        let lc = email.lowercased()
        if lc.hasSuffix("@gmail.com")  { return .red }
        if lc.hasSuffix("@icloud.com") || lc.hasSuffix("@me.com") || lc.hasSuffix("@mac.com") { return .blue }
        return .secondary
    }
}

// MARK: - iOS Share Sheet Wrapper
struct ActivityShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Individual Task Share Sheet
struct TaskShareSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    let task    : PlannerTask
    let section : String
    @Environment(\.dismiss) var dismiss

    @State private var showActivitySheet = false

    var shareText: String {
        var lines = ["📋 Daily Planner — \(section)", ""]
        lines.append(task.isCompleted ? "✅ \(task.title)" : "⬜ \(task.title)")
        if !task.notes.isEmpty { lines.append("   Note: \(task.notes)") }
        if !task.subtasks.isEmpty {
            lines.append("   Subtasks:")
            for sub in task.subtasks {
                lines.append("   \(sub.isCompleted ? "✅" : "⬜") \(sub.title)")
            }
        }
        lines.append("")
        lines.append("Shared from Daily Planner")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.45, green: 0.25, blue: 0.85).opacity(0.1))
                    VStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                        Text("Share Task")
                            .font(.title3).fontWeight(.bold)
                        Text(task.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
                .padding(.horizontal, 20)

                // Recipients preview
                if !vm.settings.sharingSettings.recipients.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Recipients")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(vm.settings.sharingSettings.recipients) { r in
                                    HStack(spacing: 6) {
                                        Image(systemName: r.accountType.icon)
                                            .font(.system(size: 13))
                                            .foregroundColor(r.accountType.color)
                                        Text(r.name.isEmpty ? r.email : r.name)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                Spacer()

                // Share button
                Button {
                    showActivitySheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share via Email / Messages")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(red: 0.45, green: 0.25, blue: 0.85))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.top, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivityShareSheet(text: shareText)
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - ViewModel Extension: Share Text Generation
extension PlannerViewModel {

    func generateShareText(for section: SharableSection) -> String {
        let entry     = currentEntry
        let dateStr   = formattedShareDate(selectedDate)
        var lines     : [String] = []

        lines.append("📋 Daily Planner — \(section.rawValue)")
        lines.append("📅 \(dateStr)")
        lines.append(String(repeating: "─", count: 40))

        switch section {

        case .entireList:
            lines.append("")
            lines.append("⭐ Top Priorities")
            appendTasks(entry.topPriorities, to: &lines)
            lines.append("")
            lines.append("📝 To-Do List")
            appendTasks(entry.toDoLists, to: &lines)
            lines.append("")
            lines.append("📞 Calls & Emails")
            appendTasks(entry.callsEmails, to: &lines)
            lines.append("")
            lines.append("👤 Personal To-Do")
            appendTasks(entry.personalTodo, to: &lines)

        case .topPriorities:
            lines.append("")
            appendTasks(entry.topPriorities, to: &lines)

        case .personalList:
            lines.append("")
            appendTasks(entry.personalTodo, to: &lines)

        case .callsEmails:
            lines.append("")
            appendTasks(entry.callsEmails, to: &lines)

        case .foodTracker:
            lines.append("")
            let meals = entry.meals
            lines.append("🌅 Breakfast")
            appendMealItems(meals.breakfastItems, to: &lines)
            lines.append("☀️ Lunch")
            appendMealItems(meals.lunchItems, to: &lines)
            lines.append("🌆 Dinner")
            appendMealItems(meals.dinnerItems, to: &lines)
            lines.append("🍎 Snacks")
            appendMealItems(meals.snackItems, to: &lines)
            lines.append("")
            lines.append("Total Calories: \(meals.totalCalories) kcal")

        case .waterTracker:
            lines.append("")
            let pct = entry.waterGoal > 0
                ? Int(Double(entry.waterGlasses) / Double(entry.waterGoal) * 100)
                : 0
            lines.append("💧 Water Intake: \(entry.waterGlasses) / \(entry.waterGoal) glasses (\(pct)%)")
            let bar = String(repeating: "█", count: min(entry.waterGlasses, entry.waterGoal))
                    + String(repeating: "░", count: max(0, entry.waterGoal - entry.waterGlasses))
            lines.append("   [\(bar)]")

        case .medications:
            lines.append("")
            let meds = settings.medications
            if meds.isEmpty {
                lines.append("No medications added.")
            } else {
                for med in meds {
                    let times = med.times.map { formattedTime($0) }.joined(separator: ", ")
                    lines.append("💊 \(med.name) — \(med.dosage) @ \(times)")
                }
            }

        case .habits:
            lines.append("")
            let todayKey = dateKey(for: selectedDate)
            let log      = settings.habitLogs[todayKey]?.completedIDs ?? []
            for habit in settings.habits {
                let done = log.contains(habit.id)
                lines.append("\(done ? "✅" : "⬜") \(habit.name)")
            }
            if settings.habits.isEmpty { lines.append("No habits configured.") }

        case .sleepTracker:
            lines.append("")
            let sleep = entry.sleep
            if let bed = sleep.bedtime, let wake = sleep.wakeTime {
                lines.append("🌙 Bedtime : \(formattedTime(bed))")
                lines.append("☀️ Wake Up : \(formattedTime(wake))")
                if let hrs = sleep.durationHours {
                    let h = Int(hrs)
                    let m = Int((hrs - Double(h)) * 60)
                    lines.append("⏱ Duration: \(h)h \(m)m")
                }
                lines.append("⭐ Quality : \(sleep.quality)/5")
            } else {
                lines.append("No sleep data logged.")
            }

        case .appointments:
            lines.append("")
            for appt in entry.appointments {
                lines.append("\(appt.isCompleted ? "✅" : "🕐") \(formattedTime(appt.time)) — \(appt.title)")
                if !appt.location.isEmpty { lines.append("   📍 \(appt.location)") }
            }
            if entry.appointments.isEmpty { lines.append("No appointments.") }

        case .expenses:
            lines.append("")
            lines.append("💰 Income  : \(settings.currency.symbol)\(String(format: "%.2f", entry.totalIncome))")
            lines.append("💸 Expenses: \(settings.currency.symbol)\(String(format: "%.2f", entry.totalExpenses))")
            lines.append("🏦 Savings : \(settings.currency.symbol)\(String(format: "%.2f", entry.totalDeposits))")
            lines.append("")
            for exp in entry.expenses where !exp.isDeposit && !exp.isIncome {
                lines.append("  \(exp.displayCategory): \(settings.currency.symbol)\(String(format: "%.2f", exp.amount)) — \(exp.description)")
            }

        case .notes:
            lines.append("")
            lines.append(entry.notes.isEmpty ? "No notes for today." : entry.notes)
        }

        lines.append("")
        lines.append(String(repeating: "─", count: 40))
        lines.append("Shared from Daily Planner")
        return lines.joined(separator: "\n")
    }

    // MARK: Private helpers
    private func appendTasks(_ tasks: [PlannerTask], to lines: inout [String]) {
        if tasks.isEmpty {
            lines.append("  (none)")
        } else {
            for t in tasks {
                lines.append("  \(t.isCompleted ? "✅" : "⬜") \(t.title)")
                if !t.notes.isEmpty { lines.append("     Note: \(t.notes)") }
                for sub in t.subtasks {
                    lines.append("     \(sub.isCompleted ? "✅" : "⬜") \(sub.title)")
                }
            }
        }
    }

    private func appendMealItems(_ items: [MealItem], to lines: inout [String]) {
        if items.isEmpty {
            lines.append("  (none)")
        } else {
            for item in items {
                let cal = item.calories > 0 ? " (\(item.calories) kcal)" : ""
                lines.append("  • \(item.name)\(cal)")
            }
        }
    }

    private func formattedShareDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        return fmt.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
