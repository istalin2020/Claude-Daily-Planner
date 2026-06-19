import SwiftUI

// MARK: - Gmail Expense Sync
//
// Connect a Gmail account once, then sync bank-transaction emails into the
// expense tracker. Credits become income; debits become categorized expenses.
// Transactions whose category can't be detected are queued for a quick,
// one-at-a-time review. Each sync continues from where the last one stopped.

struct GmailSyncView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var gmail = GmailSyncService.shared

    let sym: String

    enum Phase { case home, working, review, summary }
    @State private var phase: Phase = .home
    @State private var statusText = ""
    @State private var errorText: String? = nil

    // Sync results
    @State private var reviewQueue: [GmailCandidate] = []
    @State private var reviewIndex = 0
    @State private var handledIDs: [String] = []
    @State private var newestEpoch: Double = 0
    @State private var addedIncome = 0
    @State private var addedExpenses = 0

    // Per-item review state
    @State private var editDescription = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var selectedCustomLabel = ""
    @State private var showNewCategoryField = false
    @State private var newCategoryName = ""

    private let accent = Color(red: 0.85, green: 0.2, blue: 0.2)   // Gmail-ish red

    var body: some View {
        NavigationView {
            Group {
                switch phase {
                case .home:    homeView
                case .working: workingView
                case .review:  reviewView
                case .summary: summaryView
                }
            }
            .navigationTitle("Gmail Expense Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .summary ? "Done" : "Close") { finishAndDismiss() }
                }
            }
        }
    }

    // MARK: - Home

    private var homeView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 84, height: 84)
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 36)).foregroundColor(accent)
                }
                .padding(.top, 24)

                if !GmailConfig.isConfigured {
                    setupRequiredCard
                } else if vm.settings.gmailConnectedEmail.isEmpty {
                    notConnectedCard
                } else {
                    connectedCard
                }

                if let errorText = errorText {
                    Text(errorText)
                        .font(.caption).foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                infoCard
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
        }
    }

    private var setupRequiredCard: some View {
        VStack(spacing: 10) {
            Text("Setup Required")
                .font(.headline)
            Text("Gmail sync needs a one-time Google Cloud setup. Add your OAuth Client ID in GmailSyncService.swift, then register its URL scheme in Info.plist. Step-by-step instructions are in the comments at the top of that file.")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var notConnectedCard: some View {
        VStack(spacing: 14) {
            Text("Connect your Gmail")
                .font(.headline)
            Text("Sign in once with Google. We only request read-only access to find bank transaction emails — nothing is ever sent or modified.")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: connect) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Connect Gmail Account").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(accent).foregroundColor(.white).cornerRadius(14)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var connectedCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected").font(.system(size: 13, weight: .semibold))
                    Text(vm.settings.gmailConnectedEmail)
                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
            }

            if vm.settings.gmailLastSyncEpoch > 0 {
                Text("Last synced \(lastSyncLabel). Next sync continues from here.")
                    .font(.caption2).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            reconnectReminder

            Button(action: sync) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(accent).foregroundColor(.white).cornerRadius(14)
            }

            Button(action: connect) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Reconnect Gmail")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(accent)
            }

            Button(role: .destructive, action: disconnect) {
                Text("Disconnect").font(.system(size: 13, weight: .medium))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    /// A gentle heads-up that the Google "Testing" mode connection expires
    /// weekly, so the periodic re-login isn't a surprise.
    @ViewBuilder
    private var reconnectReminder: some View {
        if let days = vm.gmailDaysUntilReconnect {
            if days <= 0 {
                reminderBanner(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "Reconnect needed",
                    message: "Google signs you out weekly while the app is in test mode. Tap “Reconnect Gmail” below to sign in again, then sync."
                )
            } else if days <= 2 {
                reminderBanner(
                    icon: "clock.badge.exclamationmark.fill",
                    color: .orange,
                    title: days == 1 ? "Reconnect in ~1 day" : "Reconnect in ~\(days) days",
                    message: "Google signs you out weekly in test mode. You can reconnect anytime to reset the timer."
                )
            }
        }
    }

    private func reminderBanner(icon: String, color: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(message).font(.caption2).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Credits are added as income", systemImage: "arrow.down.circle.fill")
                .foregroundColor(Color(red: 0.1, green: 0.65, blue: 0.35))
            Label("Debits are added as categorized expenses", systemImage: "arrow.up.circle.fill")
                .foregroundColor(.red)
            Label("Unknown categories are asked one by one", systemImage: "questionmark.circle.fill")
                .foregroundColor(.orange)
        }
        .font(.system(size: 12, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .cornerRadius(14)
    }

    // MARK: - Working (spinner)

    private var workingView: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().scaleEffect(1.4)
            Text(statusText.isEmpty ? "Working…" : statusText)
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Review wizard

    private var reviewView: some View {
        VStack(spacing: 0) {
            // Progress
            VStack(spacing: 6) {
                HStack {
                    Text("Review \(reviewIndex + 1) of \(reviewQueue.count)")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("Unknown category")
                        .font(.caption2).foregroundColor(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15)).cornerRadius(8)
                }
                ProgressView(value: Double(reviewIndex), total: Double(max(reviewQueue.count, 1)))
                    .tint(accent)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            if reviewIndex < reviewQueue.count {
                let candidate = reviewQueue[reviewIndex]
                ScrollView {
                    VStack(spacing: 16) {
                        transactionSummaryCard(candidate)
                        descriptionEditor
                        categoryPicker
                    }
                    .padding(.horizontal, 16).padding(.top, 4)
                }

                // Actions
                VStack(spacing: 8) {
                    Button(action: { saveReviewItem(candidate) }) {
                        Text(reviewIndex == reviewQueue.count - 1 ? "Save & Finish" : "Save & Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(accent).foregroundColor(.white).cornerRadius(14)
                    }
                    Button(action: { skipReviewItem(candidate) }) {
                        Text("Skip this one").font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            }
        }
    }

    private func transactionSummaryCard(_ c: GmailCandidate) -> some View {
        let p = c.parsed
        let localCurrency = vm.settings.currency.rawValue
        let needsConv = CurrencyConverter.needsConversion(detected: p.currencyDetected, local: localCurrency)
        let converted = needsConv
            ? CurrencyConverter.convert(amount: p.amount, from: p.currencyDetected, to: localCurrency)
            : nil

        return VStack(spacing: 10) {
            HStack {
                Image(systemName: "building.columns.fill").foregroundColor(.secondary)
                Text(p.bankName).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(c.date, style: .date).font(.caption).foregroundColor(.secondary)
            }
            Divider()
            HStack {
                Text("Amount").font(.caption).foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(sym)\(String(format: "%.2f", converted ?? p.amount))")
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.red)
                    if let converted = converted {
                        Text("\(p.currencyDetected) \(String(format: "%.2f", p.amount)) → \(sym)\(String(format: "%.2f", converted))")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var descriptionEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DESCRIPTION").font(.caption2).foregroundColor(.secondary)
            TextField("e.g. Grocery store", text: $editDescription)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHOOSE A CATEGORY").font(.caption2).foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    categoryChip(
                        title: cat.rawValue, icon: cat.icon, color: cat.color,
                        isSelected: selectedCustomLabel.isEmpty && selectedCategory == cat
                    ) {
                        selectedCategory = cat
                        selectedCustomLabel = ""
                    }
                }
                ForEach(vm.settings.customExpenseCategories, id: \.self) { label in
                    categoryChip(
                        title: label, icon: "tag.fill", color: .indigo,
                        isSelected: selectedCustomLabel == label
                    ) {
                        selectedCustomLabel = label
                    }
                }
                categoryChip(title: "New", icon: "plus", color: .secondary, isSelected: false) {
                    showNewCategoryField = true
                }
            }

            if showNewCategoryField {
                HStack {
                    TextField("New category name", text: $newCategoryName)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    Button("Add") { addCustomCategory() }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func categoryChip(title: String, icon: String, color: Color,
                              isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.18) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Summary

    private var summaryView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 84, height: 84)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40)).foregroundColor(.green)
            }
            Text("Sync Complete").font(.title3).fontWeight(.bold)

            VStack(spacing: 10) {
                summaryRow(icon: "arrow.down.circle.fill",
                           color: Color(red: 0.1, green: 0.65, blue: 0.35),
                           label: "Income added", value: "\(addedIncome)")
                summaryRow(icon: "arrow.up.circle.fill", color: .red,
                           label: "Expenses added", value: "\(addedExpenses)")
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 24)

            Text("Next sync will continue from the most recent email.")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Spacer()

            Button(action: finishAndDismiss) {
                Text("Done").fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(accent).foregroundColor(.white).cornerRadius(14)
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(label).font(.system(size: 14, weight: .medium))
            Spacer()
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color)
        }
    }

    // MARK: - Actions

    private func connect() {
        errorText = nil
        statusText = "Connecting to Google…"
        phase = .working
        Task {
            do {
                let email = try await gmail.connect()
                vm.setGmailConnected(email: email)
                phase = .home
            } catch {
                errorText = (error as? GmailSyncError)?.errorDescription ?? error.localizedDescription
                phase = .home
            }
        }
    }

    private func disconnect() {
        vm.gmailDisconnect()
        errorText = nil
    }

    private func sync() {
        errorText = nil
        statusText = "Reading bank emails…"
        phase = .working
        addedIncome = 0
        addedExpenses = 0
        handledIDs = []
        newestEpoch = vm.settings.gmailLastSyncEpoch

        Task {
            do {
                let candidates = try await gmail.fetchTransactions(
                    sinceEpoch: vm.settings.gmailLastSyncEpoch,
                    alreadyProcessed: vm.settings.gmailProcessedMessageIDs
                )

                var queue: [GmailCandidate] = []
                for c in candidates {
                    newestEpoch = max(newestEpoch, c.date.timeIntervalSince1970)
                    if vm.gmailCanAutoAdd(c) {
                        let expense = vm.expense(from: c)
                        vm.addExpense(expense, on: c.date)
                        handledIDs.append(c.id)
                        if expense.isIncome { addedIncome += 1 } else { addedExpenses += 1 }
                    } else {
                        queue.append(c)
                    }
                }

                if queue.isEmpty {
                    vm.finalizeGmailSync(handledIDs: handledIDs, advanceCursorTo: newestEpoch)
                    phase = .summary
                } else {
                    reviewQueue = queue
                    reviewIndex = 0
                    loadReviewItem()
                    phase = .review
                }
            } catch {
                errorText = (error as? GmailSyncError)?.errorDescription ?? error.localizedDescription
                phase = .home
            }
        }
    }

    private func loadReviewItem() {
        guard reviewIndex < reviewQueue.count else { return }
        let p = reviewQueue[reviewIndex].parsed
        editDescription = p.merchant.isEmpty ? "\(p.bankName) Transaction" : p.merchant
        selectedCategory = .other
        selectedCustomLabel = ""
        showNewCategoryField = false
        newCategoryName = ""
    }

    private func saveReviewItem(_ c: GmailCandidate) {
        var expense = selectedCustomLabel.isEmpty
            ? vm.expense(from: c, overrideCategory: selectedCategory)
            : vm.expense(from: c, customCategoryLabel: selectedCustomLabel)
        let trimmed = editDescription.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { expense.description = trimmed }

        vm.addExpense(expense, on: c.date)
        handledIDs.append(c.id)
        addedExpenses += 1
        advanceReview()
    }

    private func skipReviewItem(_ c: GmailCandidate) {
        // Mark processed so it isn't offered again, but don't add it.
        handledIDs.append(c.id)
        advanceReview()
    }

    private func advanceReview() {
        if reviewIndex < reviewQueue.count - 1 {
            reviewIndex += 1
            loadReviewItem()
        } else {
            vm.finalizeGmailSync(handledIDs: handledIDs, advanceCursorTo: newestEpoch)
            phase = .summary
        }
    }

    private func addCustomCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !vm.settings.customExpenseCategories.contains(name) {
            vm.settings.customExpenseCategories.append(name)
            vm.saveSettings()
        }
        selectedCustomLabel = name
        newCategoryName = ""
        showNewCategoryField = false
    }

    private func finishAndDismiss() {
        // If the user closes mid-review, persist what they've handled so far
        // without advancing the cursor — pending items return next sync.
        if phase == .review && !handledIDs.isEmpty {
            vm.finalizeGmailSync(handledIDs: handledIDs, advanceCursorTo: nil)
        }
        dismiss()
    }

    private var lastSyncLabel: String {
        let date = Date(timeIntervalSince1970: vm.settings.gmailLastSyncEpoch)
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
