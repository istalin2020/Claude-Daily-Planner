import SwiftUI
import MessageUI
import CloudKit

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

    // Per-recipient share queue (used when there are multiple recipients)
    @State private var shareQueue          : [(recipient: ShareRecipient, text: String)] = []
    @State private var showShareQueue      = false

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

                        // ── HOW SHARING WORKS ───────────────────────────────
                        Section {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                                    .font(.system(size: 16))
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("How Sharing Works")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("1. Add a recipient and choose categories to share.\n2. Tap Done — an invitation email/message is created.\n3. The recipient taps the link to accept.\n4. They receive a notification and the shared tasks appear in their app instantly via iCloud sync.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // ── RECEIVED SHARES ─────────────────────────────────
                        if !vm.settings.receivedSharedLists.isEmpty {
                            Section {
                                ForEach(vm.settings.receivedSharedLists) { sharedList in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(sharedList.section.color.opacity(0.12))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: sharedList.section.icon)
                                                .foregroundColor(sharedList.section.color)
                                                .font(.system(size: 16))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(sharedList.senderName)'s \(sharedList.section.rawValue)")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("\(sharedList.tasks.count) task\(sharedList.tasks.count == 1 ? "" : "s") · Updated \(sharedList.lastUpdated.formatted(.relative(presentation: .named)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        // Accepted badge
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(red: 0.1, green: 0.65, blue: 0.35))
                                                .font(.system(size: 12))
                                            Text("Accepted")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(Color(red: 0.1, green: 0.65, blue: 0.35))
                                        }
                                        Button {
                                            vm.removeReceivedSharedList(sharedList)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13))
                                                .foregroundColor(.red.opacity(0.7))
                                                .padding(4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.vertical, 3)
                                }
                            } header: {
                                Text("Shared With Me")
                            } footer: {
                                Text("Accepted shared lists appear below your own tasks in each section view. You'll receive a notification whenever the sender updates and re-shares.")
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
            // ── Invite Share Sheet (single recipient) ───────────────────────
            .sheet(isPresented: $showInviteSheet, onDismiss: { dismiss() }) {
                ActivityShareSheet(
                    text: inviteContent,
                    subject: "You've been invited to a shared task list on Daily Planner"
                )
            }
            // ── Share Queue Sheet (multiple recipients) ──────────────────────
            .sheet(isPresented: $showShareQueue, onDismiss: { dismiss() }) {
                ShareQueueSheet(invitations: shareQueue)
                    .environmentObject(vm)
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
        let sharing = vm.settings.sharingSettings
        guard sharing.isEnabled,
              !sharing.recipients.isEmpty,
              sharing.recipients.contains(where: { !$0.sharedSections.isEmpty }) else {
            dismiss()
            return
        }

        // Build a compact, per-recipient invitation (short enough for WhatsApp/SMS)
        let queue = sharing.recipients
            .filter { !$0.sharedSections.isEmpty }
            .map { (recipient: $0, text: vm.buildCompactInvitation(for: $0)) }

        if queue.count == 1 {
            // Single recipient → go straight to the share sheet.
            // Assign content first, then set the flag on the next run-loop tick
            // so SwiftUI re-renders with the text before the sheet is created.
            inviteContent = queue[0].text
            DispatchQueue.main.async {
                self.showInviteSheet = true
            }
        } else {
            // Multiple recipients → show the queue so user sends one per person
            shareQueue = queue
            DispatchQueue.main.async {
                self.showShareQueue = true
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
                        Text("Any valid email address is accepted. The recipient must have Daily Planner installed to accept the shared list.")
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
// Uses a custom UIActivityItemSource to provide:
//   • A short URL for email clients (subject + body with link) — fixes Gmail blank compose
//   • Plain text for WhatsApp, iMessage, and other messaging apps
struct ActivityShareSheet: UIViewControllerRepresentable {
    let text    : String
    let subject : String

    init(text: String, subject: String = "You've been invited to a shared task list") {
        self.text    = text
        self.subject = subject
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let provider = ShareTextProvider(text: text, subject: subject)
        let vc = UIActivityViewController(activityItems: [provider], applicationActivities: nil)
        // Exclude activities that don't handle text properly
        vc.excludedActivityTypes = [.assignToContact, .saveToCameraRoll, .addToReadingList]
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// UIActivityItemProvider that returns the correct content type per activity.
/// - Mail apps (Gmail, Outlook, Mail): get subject + body → no blank compose screen
/// - Messaging apps (WhatsApp, iMessage): get plain text → fills message body
private final class ShareTextProvider: UIActivityItemProvider, @unchecked Sendable {
    private let shareText : String
    private let subject   : String

    init(text: String, subject: String) {
        self.shareText = text
        self.subject   = subject
        super.init(placeholderItem: text)
    }

    override var item: Any { shareText }

    // Provide an email subject for mail-type activities
    override func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        guard let type = activityType else { return subject }
        let mailTypes: [UIActivity.ActivityType] = [.mail]
        return mailTypes.contains(type) ? subject : ""
    }
}

// MARK: - Mail Compose View (MFMailComposeViewController wrapper)
// Used as a dedicated "Email" button — guarantees Gmail, Apple Mail, and
// Outlook all receive the subject + body, eliminating blank compose screens.
struct MailComposeView: UIViewControllerRepresentable {
    let subject : String
    let body    : String
    let toEmail : String
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate  = context.coordinator
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if !toEmail.isEmpty { vc.setToRecipients([toEmail]) }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(isPresented: $isPresented) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        init(isPresented: Binding<Bool>) { _isPresented = isPresented }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            isPresented = false
        }
    }
}

// MARK: - Share Queue Sheet (one send button per recipient)
struct ShareQueueSheet: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) var dismiss

    let invitations: [(recipient: ShareRecipient, text: String)]

    @State private var activeRecipientID   : UUID?   = nil
    @State private var copiedRecipientID   : UUID?   = nil
    @State private var mailRecipientID     : UUID?   = nil
    @State private var showMailCompose     : Bool    = false

    private let emailSubject = "You've been invited to a shared task list on Daily Planner"

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "livephoto")
                            .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Live Sync Enabled")
                                .font(.system(size: 13, weight: .bold))
                            Text("When you make changes, they update automatically in the recipient's app.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(invitations, id: \.recipient.id) { item in
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: item.recipient.accountType.icon)
                                .font(.system(size: 22))
                                .foregroundColor(item.recipient.accountType.color)

                            VStack(alignment: .leading, spacing: 3) {
                                if !item.recipient.name.isEmpty {
                                    Text(item.recipient.name)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(item.recipient.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(item.recipient.sharedSections.map { $0.rawValue }.joined(separator: ", "))
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                                    .lineLimit(2)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                // Copy to clipboard
                                Button {
                                    UIPasteboard.general.string = item.text
                                    copiedRecipientID = item.recipient.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        if copiedRecipientID == item.recipient.id {
                                            copiedRecipientID = nil
                                        }
                                    }
                                } label: {
                                    Image(systemName: copiedRecipientID == item.recipient.id
                                          ? "checkmark.circle.fill" : "doc.on.doc")
                                        .font(.system(size: 18))
                                        .foregroundColor(copiedRecipientID == item.recipient.id
                                                         ? .green
                                                         : Color(red: 0.45, green: 0.25, blue: 0.85))
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Email button (MFMailComposeViewController — always pre-fills body)
                                if MFMailComposeViewController.canSendMail() {
                                    Button {
                                        mailRecipientID = item.recipient.id
                                        showMailCompose = true
                                    } label: {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.red)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                // Generic share sheet (WhatsApp, iMessage, etc.)
                                Button {
                                    activeRecipientID = item.recipient.id
                                } label: {
                                    Label("Send", systemImage: "square.and.arrow.up")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.45, green: 0.25, blue: 0.85))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                            .padding(.top, 1)
                        Text("Recipients must have Daily Planner installed. When they tap the accept link, the shared tasks appear in their app and update automatically whenever you make changes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Send Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            // Generic share sheet (WhatsApp, iMessage, Telegram, etc.)
            .sheet(item: Binding<ShareRecipient?>(
                get: { invitations.first(where: { $0.recipient.id == activeRecipientID })?.recipient },
                set: { activeRecipientID = $0?.id }
            )) { recipient in
                if let inv = invitations.first(where: { $0.recipient.id == recipient.id }) {
                    ActivityShareSheet(text: inv.text, subject: emailSubject)
                }
            }
            // Dedicated email composer — pre-fills Gmail/Mail/Outlook body correctly
            .sheet(isPresented: $showMailCompose) {
                if let id = mailRecipientID,
                   let inv = invitations.first(where: { $0.recipient.id == id }) {
                    MailComposeView(
                        subject    : emailSubject,
                        body       : inv.text,
                        toEmail    : inv.recipient.email,
                        isPresented: $showMailCompose
                    )
                }
            }
        }
    }
}

// MARK: - ViewModel Extension: Sharing
extension PlannerViewModel {

    // MARK: - Received Shares Management

    func removeReceivedSharedList(_ list: ReceivedSharedList) {
        // Unsubscribe from CloudKit change notifications before removing
        CloudKitSharingService.shared.unsubscribe(shareToken: list.shareToken)
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

    // MARK: - Accept via legacy base64 deep link (backward compatibility)

    func acceptSharedList(fromData encoded: String) {
        // 1. Percent-decode in case the caller passed a still-encoded string.
        let raw = encoded.removingPercentEncoding ?? encoded
        // 2. Convert URL-safe base64 (- → +, _ → /) back to standard base64,
        //    then restore any stripped = padding so Data(base64Encoded:) works.
        var standard = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = standard.count % 4
        if remainder != 0 { standard += String(repeating: "=", count: 4 - remainder) }
        guard let data    = Data(base64Encoded: standard),
              let payload = try? JSONDecoder().decode(SharePayload.self, from: data) else { return }

        let isUpdate = settings.receivedSharedLists.contains { $0.shareToken == payload.token }

        let newList = ReceivedSharedList(
            shareToken  : payload.token,
            senderName  : payload.senderName,
            senderEmail : payload.senderEmail,
            section     : payload.section,
            tasks       : payload.tasks,
            lastUpdated : payload.sentAt
        )

        applyReceivedList(newList, isUpdate: isUpdate)

        // Also subscribe to future CloudKit updates for this list.
        CloudKitSharingService.shared.subscribeToChanges(shareToken: payload.token)
    }

    // MARK: - Accept via new CloudKit token deep link

    /// Called when recipient taps a token-based share link.
    /// Fetches the current task list from CloudKit and subscribes to live updates.
    func acceptSharedListFromToken(shareToken: String, senderName: String, sectionRaw: String) {
        // Show provisional entry immediately with empty tasks so the UI responds fast.
        let section = SharableSection(rawValue: sectionRaw) ?? .toDoLists
        let isUpdate = settings.receivedSharedLists.contains { $0.shareToken == shareToken }

        if !isUpdate {
            let provisional = ReceivedSharedList(
                shareToken  : shareToken,
                senderName  : senderName.isEmpty ? "Someone" : senderName,
                senderEmail : "",
                section     : section,
                tasks       : [],
                lastUpdated : Date()
            )
            applyReceivedList(provisional, isUpdate: false)
        }

        // Fetch the real data from CloudKit.
        CloudKitSharingService.shared.fetchSharedList(shareToken: shareToken) { [weak self] (result: Result<CKSharedListPayload, Error>) in
            guard let self else { return }
            switch result {
            case .success(let payload):
                let list = ReceivedSharedList(
                    shareToken  : payload.shareToken,
                    senderName  : payload.senderName.isEmpty ? senderName : payload.senderName,
                    senderEmail : payload.senderEmail,
                    section     : payload.section,
                    tasks       : payload.tasks,
                    lastUpdated : payload.updatedAt
                )
                self.applyReceivedList(list, isUpdate: true)
                // Subscribe to future updates (CloudKit sends silent push when sender saves).
                CloudKitSharingService.shared.subscribeToChanges(shareToken: shareToken)
            case .failure:
                // CloudKit unavailable or record not yet uploaded — keep provisional entry,
                // it will be refreshed next time the app foregrounds.
                break
            }
        }
    }

    // MARK: - Refresh all received lists from CloudKit (called on app foreground)

    func refreshReceivedSharedLists() {
        let tokens = settings.receivedSharedLists.map { $0.shareToken }
        guard !tokens.isEmpty else { return }

        CloudKitSharingService.shared.refreshReceivedLists(tokens: tokens) { [weak self] (payloads: [CKSharedListPayload]) in
            guard let self else { return }
            for payload in payloads {
                let list = ReceivedSharedList(
                    shareToken  : payload.shareToken,
                    senderName  : payload.senderName,
                    senderEmail : payload.senderEmail,
                    section     : payload.section,
                    tasks       : payload.tasks,
                    lastUpdated : payload.updatedAt
                )
                // Only update if the cloud version is newer or tasks changed.
                if let idx = self.settings.receivedSharedLists.firstIndex(where: { $0.shareToken == payload.shareToken }) {
                    if payload.updatedAt > self.settings.receivedSharedLists[idx].lastUpdated {
                        self.settings.receivedSharedLists[idx] = list
                    }
                }
            }
            if !payloads.isEmpty { self.saveSettings() }
        }
    }

    // MARK: - Shared helper

    private func applyReceivedList(_ newList: ReceivedSharedList, isUpdate: Bool) {
        if let idx = settings.receivedSharedLists.firstIndex(where: { $0.shareToken == newList.shareToken }) {
            settings.receivedSharedLists[idx] = newList
        } else {
            settings.receivedSharedLists.append(newList)
        }
        saveSettings()

        let senderDisplay = newList.senderName.isEmpty ? newList.senderEmail : newList.senderName
        NotificationManager.shared.scheduleShareReceivedNotification(
            senderName  : senderDisplay,
            sectionName : newList.section.rawValue,
            taskCount   : newList.tasks.count,
            isUpdate    : isUpdate
        )

        DispatchQueue.main.async {
            self.lastAcceptedShareInfo = PlannerViewModel.ShareAcceptedInfo(
                senderName  : senderDisplay,
                sectionName : newList.section.rawValue,
                taskCount   : newList.tasks.count,
                isUpdate    : isUpdate
            )
        }
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

    /// Builds a compact, WhatsApp/SMS/Gmail-friendly invitation for a single recipient.
    /// Uses short token-based URLs (no base64 payload) so messaging apps never truncate
    /// or show blank compose windows. Data is served live from CloudKit.
    func buildCompactInvitation(for recipient: ShareRecipient) -> String {
        let sharing   = settings.sharingSettings
        let ownerName = sharing.ownerName.isEmpty ? "Someone" : sharing.ownerName
        let greeting  = recipient.name.isEmpty ? "Hi!" : "Hi \(recipient.name)!"
        var lines: [String] = []

        lines.append(greeting)
        lines.append("")
        lines.append("\(ownerName) is sharing task lists with you on Daily Planner.")
        lines.append("Changes they make will appear in your app automatically. ✨")
        lines.append("")

        for section in recipient.sharedSections {
            let tasks   = sharedTaskItems(for: section)
            let payload = buildPerRecipientPayload(
                tasks: tasks, section: section,
                ownerName: ownerName, ownerEmail: recipient.email,
                token: recipient.shareToken)

            // Upload to CloudKit so the recipient gets live data when they accept.
            CloudKitSharingService.shared.uploadSharedList(
                shareToken    : recipient.shareToken,
                senderName    : ownerName,
                senderEmail   : settings.sharingSettings.ownerName,
                recipientEmail: recipient.email,
                section       : section,
                tasks         : tasks
            )

            guard let link = encodedShareLink(for: payload) else { continue }
            lines.append("📋 \(section.rawValue)")
            lines.append(link)
            lines.append("")
        }

        lines.append("Tap the link(s) above with Daily Planner installed to accept.")
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

    /// Returns a SHORT token-based share link (CloudKit real-time sync).
    /// Format: https://…/share/?token=<uuid>&name=<ownerName>&section=<rawValue>
    /// This is safe for WhatsApp, iMessage, Gmail and any other messaging app
    /// because the URL is only ~120 chars — no base64 payload embedded.
    func encodedShareLink(for payload: SharePayload) -> String? {
        var comps = URLComponents(string: "https://istalin2020.github.io/Daily-Planner/share/")!
        comps.queryItems = [
            URLQueryItem(name: "token",   value: payload.token),
            URLQueryItem(name: "name",    value: payload.senderName),
            URLQueryItem(name: "section", value: payload.section.rawValue)
        ]
        return comps.url?.absoluteString
    }

    /// Legacy base64 link kept for backward compatibility (old app versions).
    func legacyEncodedShareLink(for payload: SharePayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        let base64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "https://istalin2020.github.io/Daily-Planner/share/?data=\(base64)"
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
