import SwiftUI
import MessageUI

// MARK: - Sharing View (Settings Screen) — PRO only
struct SharingView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Environment(\.dismiss) var dismiss

    @State private var showAddRecipient    = false
    @State private var recipientName       = ""
    @State private var recipientEmail      = ""
    @State private var emailError          = ""
    @State private var showInviteSheet     = false
    @State private var inviteContent       = ""
    @State private var showSentBanner      = false
    @State private var showProUpgrade      = false

    // Category selection after adding / editing a recipient
    @State private var pendingRecipient    : ShareRecipient? = nil
    @State private var showCategorySelect  = false
    @State private var editingRecipient    : ShareRecipient? = nil

    var body: some View {
        NavigationView {
            Form {

                // ── PRO GATE ────────────────────────────────────────────────
                if !pro.isPro {
                    Section {
                        Button(action: { showProUpgrade = true }) {
                            HStack(spacing: 14) {
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
                                    Text("Task Sharing is a PRO Feature")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Upgrade to PRO to share task categories with others.")
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
                } else {
                    // ── ENABLE SHARING ──────────────────────────────────────
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
                        Text("Share your task categories with family members or friends. The entire category list will be shared with the recipient.")
                    }

                    if vm.settings.sharingSettings.isEnabled {

                        // ── YOUR NAME ────────────────────────────────────────
                        Section {
                            HStack(spacing: 10) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                                TextField("Your name (shown to recipients)", text: Binding(
                                    get: { vm.settings.sharingSettings.ownerName },
                                    set: { vm.settings.sharingSettings.ownerName = $0; vm.saveSettings() }
                                ))
                            }
                        } header: {
                            Text("Your Name")
                        } footer: {
                            Text("This name appears as the list heading in recipients' apps, e.g. \"Alice's shared to-do list\".")
                        }

                        // ── RECIPIENTS ──────────────────────────────────────
                        Section {
                            ForEach(vm.settings.sharingSettings.recipients) { recipient in
                                RecipientRow(
                                    recipient: recipient,
                                    onEdit: {
                                        editingRecipient = recipient
                                        showCategorySelect = true
                                    },
                                    onDelete: {
                                        vm.settings.sharingSettings.recipients.removeAll { $0.id == recipient.id }
                                        vm.saveSettings()
                                    }
                                )
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
                            Text("After adding a person, choose which categories to share with them. All tasks in a selected category will be shared.")
                        }

                        // ── RECEIVED SHARES ─────────────────────────────────
                        if !vm.settings.receivedSharedLists.isEmpty {
                            Section {
                                ForEach(vm.settings.receivedSharedLists) { sharedList in
                                    HStack(spacing: 12) {
                                        Image(systemName: sharedList.section.icon)
                                            .foregroundColor(sharedList.section.color)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(sharedList.senderName)'s shared to-do list")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("\(sharedList.tasks.count) tasks · Updated \(sharedList.lastUpdated.formatted(.relative(presentation: .named)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button {
                                            vm.removeReceivedSharedList(sharedList)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13))
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.vertical, 3)
                                }
                            } header: {
                                Text("Shared With Me")
                            } footer: {
                                Text("Shared lists appear below your own tasks in each section view.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Share Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { handleDone() }
                        .fontWeight(.semibold)
                }
            }
            // ── Add Recipient Sheet ──────────────────────────────────────────
            .sheet(isPresented: $showAddRecipient) {
                AddRecipientSheet(
                    name: $recipientName,
                    email: $recipientEmail,
                    errorMessage: $emailError
                ) {
                    let trimmed = recipientEmail.trimmingCharacters(in: .whitespaces)
                    guard isValidEmail(trimmed) else {
                        emailError = "Please enter a valid email address."
                        return
                    }
                    let newRecipient = ShareRecipient(
                        name: recipientName.trimmingCharacters(in: .whitespaces),
                        email: trimmed
                    )
                    pendingRecipient = newRecipient
                    showAddRecipient = false
                }
                .onDisappear {
                    if let pending = pendingRecipient {
                        editingRecipient = pending
                        showCategorySelect = true
                    }
                }
            }
            // ── Category Selection Sheet ─────────────────────────────────────
            .sheet(isPresented: $showCategorySelect, onDismiss: {
                pendingRecipient = nil
                editingRecipient = nil
            }) {
                if let recipient = editingRecipient {
                    CategorySelectionSheet(recipient: recipient) { updatedRecipient in
                        if let idx = vm.settings.sharingSettings.recipients.firstIndex(where: { $0.id == updatedRecipient.id }) {
                            vm.settings.sharingSettings.recipients[idx] = updatedRecipient
                        } else {
                            vm.settings.sharingSettings.recipients.append(updatedRecipient)
                        }
                        vm.saveSettings()
                        pendingRecipient = nil
                        editingRecipient = nil
                    }
                    .environmentObject(vm)
                }
            }
            // ── Invite Share Sheet ───────────────────────────────────────────
            .sheet(isPresented: $showInviteSheet, onDismiss: { dismiss() }) {
                ActivityShareSheet(text: inviteContent)
            }
            .overlay(alignment: .top) {
                if showSentBanner {
                    Text("Invitation sent!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.1, green: 0.65, blue: 0.35))
                        .cornerRadius(20)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSentBanner)
        }
    }

    // MARK: - Done Action
    private func handleDone() {
        let sharing       = vm.settings.sharingSettings
        let hasRecipients = !sharing.recipients.isEmpty
        let anyHasSections = sharing.recipients.contains { !$0.sharedSections.isEmpty }

        if sharing.isEnabled && hasRecipients && anyHasSections {
            inviteContent = vm.buildInvitationEmailBody()
            showInviteSheet = true
        } else {
            dismiss()
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
    let onEdit    : () -> Void
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
                if !recipient.sharedSections.isEmpty {
                    Text(recipient.sharedSections.map { $0.rawValue }.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else {
                    Text("No categories selected yet")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85).opacity(0.8))
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
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

// MARK: - Category Selection Sheet
// Shows shareable categories (not individual tasks). Toggling a category
// shares ALL tasks under that category with the recipient.
struct CategorySelectionSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) var dismiss

    let recipient : ShareRecipient
    let onDone    : (ShareRecipient) -> Void

    // The categories the user can share
    private let shareableCategories: [SharableSection] = [
        .topPriorities, .toDoLists, .personalList, .callsEmails,
        .appointments, .notes
    ]

    @State private var selectedSections: Set<SharableSection> = []

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Select the categories to share with \(recipient.name.isEmpty ? recipient.email : recipient.name). All tasks in each selected category will be shared.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(shareableCategories) { section in
                        CategoryToggleRow(
                            section: section,
                            isSelected: selectedSections.contains(section)
                        ) {
                            if selectedSections.contains(section) {
                                selectedSections.remove(section)
                            } else {
                                selectedSections.insert(section)
                            }
                        }
                    }
                } header: {
                    Text("Categories")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        var updated = recipient
                        updated.sharedSections = Array(selectedSections)
                        onDone(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedSections.isEmpty && recipient.sharedSections.isEmpty)
                }
            }
            .onAppear {
                selectedSections = Set(recipient.sharedSections)
            }
        }
    }
}

// MARK: - Category Toggle Row
private struct CategoryToggleRow: View {
    let section    : SharableSection
    let isSelected : Bool
    let onToggle   : () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(section.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: section.icon)
                        .font(.system(size: 16))
                        .foregroundColor(section.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("All tasks in this category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? section.color : Color(.systemGray3))
                    .animation(.spring(response: 0.25), value: isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
                        TextField("Email address", text: $email)
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
                            Label("Add & Select Categories", systemImage: "square.grid.2x2.fill")
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

// MARK: - ViewModel Extension: Sharing
extension PlannerViewModel {

    // MARK: - Received Shares Management

    func removeReceivedSharedList(_ list: ReceivedSharedList) {
        settings.receivedSharedLists.removeAll { $0.id == list.id }
        saveSettings()
    }

    /// Toggle completion of a task inside a received shared list (recipient can edit but not delete).
    func toggleSharedTaskCompletion(listID: UUID, taskID: UUID) {
        guard let listIdx = settings.receivedSharedLists.firstIndex(where: { $0.id == listID }),
              let taskIdx = settings.receivedSharedLists[listIdx].tasks.firstIndex(where: { $0.id == taskID })
        else { return }
        settings.receivedSharedLists[listIdx].tasks[taskIdx].isCompleted.toggle()
        saveSettings()
    }

    /// Update notes of a shared task (recipient edit).
    func updateSharedTaskNotes(listID: UUID, taskID: UUID, notes: String) {
        guard let listIdx = settings.receivedSharedLists.firstIndex(where: { $0.id == listID }),
              let taskIdx = settings.receivedSharedLists[listIdx].tasks.firstIndex(where: { $0.id == taskID })
        else { return }
        settings.receivedSharedLists[listIdx].tasks[taskIdx].notes = notes
        saveSettings()
    }

    func acceptSharedList(fromData encoded: String) {
        guard let raw    = encoded.removingPercentEncoding ?? Optional(encoded),
              let data   = Data(base64Encoded: raw),
              let payload = try? JSONDecoder().decode(SharePayload.self, from: data) else { return }

        let newList = ReceivedSharedList(
            shareToken  : payload.token,
            senderName  : payload.senderName,
            senderEmail : payload.senderEmail,
            section     : payload.section,
            tasks       : payload.tasks,
            lastUpdated : payload.sentAt
        )

        if let idx = settings.receivedSharedLists.firstIndex(where: { $0.shareToken == payload.token }) {
            settings.receivedSharedLists[idx] = newList
        } else {
            settings.receivedSharedLists.append(newList)
        }
        saveSettings()
    }

    // MARK: - Invitation Email (per-recipient, per-category)

    /// Builds one invitation email body with one accept link per category per recipient.
    func buildInvitationEmailBody() -> String {
        let sharing   = settings.sharingSettings
        let ownerName = sharing.ownerName.isEmpty ? "Someone" : sharing.ownerName
        var lines: [String] = []

        lines.append("Hi,")
        lines.append("")
        lines.append("\(ownerName) has shared task categories from their Daily Planner with you.")
        lines.append("")

        for recipient in sharing.recipients where !recipient.sharedSections.isEmpty {
            lines.append("To: \(recipient.email)")
            lines.append("")

            for section in recipient.sharedSections {
                let tasks = sharedTaskItems(for: section)
                lines.append("• \(section.rawValue)")
                for t in tasks {
                    lines.append("   \(t.isCompleted ? "✅" : "⬜") \(t.title)")
                }
                let payload = buildPerRecipientPayload(
                    tasks: tasks,
                    section: section,
                    ownerName: ownerName,
                    ownerEmail: recipient.email,
                    token: recipient.shareToken
                )
                if let link = encodedShareLink(for: payload) {
                    lines.append("   Accept & sync: \(link)")
                }
                lines.append("")
            }

            lines.append("──────────────────────────────────────")
        }

        lines.append("HOW TO SYNC:")
        lines.append("1. Open Daily Planner on your device.")
        lines.append("2. Tap each \"Accept & sync\" link above.")
        lines.append("3. Shared tasks appear below your own tasks with \"\(ownerName)'s shared to-do list\" heading.")
        lines.append("4. You can mark tasks as complete or add notes. Changes are saved on your device.")
        lines.append("")
        lines.append("Shared from Daily Planner")
        return lines.joined(separator: "\n")
    }

    /// Returns all tasks for a given section (for category-level sharing).
    func recipientTaskGroups(for recipient: ShareRecipient) -> [(section: SharableSection, tasks: [SharedTaskItem])] {
        recipient.sharedSections.map { section in
            (section, sharedTaskItems(for: section))
        }
    }

    // MARK: - Payload Helpers

    func buildPerRecipientPayload(tasks: [SharedTaskItem], section: SharableSection,
                                   ownerName: String, ownerEmail: String, token: String) -> SharePayload {
        SharePayload(token: token, senderName: ownerName, senderEmail: ownerEmail,
                     section: section, tasks: tasks, sentAt: Date())
    }

    // Keep for backward compatibility
    func buildSharePayload(for section: SharableSection, ownerName: String) -> SharePayload {
        let tasks    = sharedTaskItems(for: section)
        let email    = settings.sharingSettings.recipients.first?.email ?? ""
        let token    = settings.sharingSettings.recipients.first?.shareToken ?? UUID().uuidString
        return SharePayload(token: token, senderName: ownerName, senderEmail: email,
                            section: section, tasks: tasks, sentAt: Date())
    }

    func sharedTaskItems(for section: SharableSection) -> [SharedTaskItem] {
        let entry = currentEntry
        func convert(_ tasks: [PlannerTask], sec: SharableSection) -> [SharedTaskItem] {
            tasks.map { t in
                SharedTaskItem(id: t.id, title: t.title, isCompleted: t.isCompleted,
                               notes: t.notes, subtasks: t.subtasks, section: sec)
            }
        }
        switch section {
        case .entireList:
            return convert(entry.topPriorities, sec: .topPriorities) +
                   convert(entry.toDoLists, sec: .toDoLists) +
                   convert(entry.callsEmails, sec: .callsEmails) +
                   convert(entry.personalTodo, sec: .personalList)
        case .topPriorities: return convert(entry.topPriorities, sec: .topPriorities)
        case .toDoLists:     return convert(entry.toDoLists,     sec: .toDoLists)
        case .personalList:  return convert(entry.personalTodo,  sec: .personalList)
        case .callsEmails:   return convert(entry.callsEmails,   sec: .callsEmails)
        case .appointments:
            return entry.appointments.map { a in
                SharedTaskItem(id: a.id, title: a.title, isCompleted: a.isCompleted,
                               notes: a.notes, subtasks: [], section: .appointments)
            }
        case .notes:
            guard !entry.notes.isEmpty else { return [] }
            return [SharedTaskItem(id: UUID(), title: entry.notes, isCompleted: false,
                                   notes: "", subtasks: [], section: .notes)]
        default:             return []
        }
    }

    func encodedShareLink(for payload: SharePayload) -> String? {
        guard let data    = try? JSONEncoder().encode(payload) else { return nil }
        let base64        = data.base64EncodedString()
        guard let encoded = base64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return "dailyplanner://accept-share?data=\(encoded)"
    }

    // MARK: - Share Text Generation (kept for backward compatibility)

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

        case .toDoLists:
            lines.append("")
            appendTasks(entry.toDoLists, to: &lines)

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
