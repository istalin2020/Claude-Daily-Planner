import SwiftUI
import MessageUI
import CloudKit

// MARK: - Sharing View (Share Tasks Screen) — PRO only
struct SharingView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategories: Set<SharableSection> = []
    @State private var shareAsImage = false
    @State private var showProUpgrade = false
    @State private var pendingShareItems: [Any]?

    private static let categories: [SharableSection] = [
        .topPriorities, .toDoLists, .personalList, .callsEmails,
        .appointments, .notes, .foodTracker, .waterTracker,
        .medications, .habits, .sleepTracker, .expenses
    ]

    private let purpleAccent = Color(red: 0.45, green: 0.25, blue: 0.85)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    if !pro.isPro {
                        // ── PRO GATE ──────────────────────────────────────
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
                                            .foregroundColor(.white)
                                            .font(.system(size: 18))
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
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        // ── FORMAT PICKER ─────────────────────────────────
                        Section {
                            Picker("Share as", selection: $shareAsImage) {
                                Text("Text").tag(false)
                                Text("Image Card").tag(true)
                            }
                            .pickerStyle(.segmented)
                        } header: {
                            Text("Format")
                        }

                        // ── CATEGORY CHECKBOXES ───────────────────────────
                        Section {
                            ForEach(Self.categories) { category in
                                Button {
                                    withAnimation(.spring(response: 0.25)) {
                                        if selectedCategories.contains(category) {
                                            selectedCategories.remove(category)
                                        } else {
                                            selectedCategories.insert(category)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(category.color.opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: category.icon)
                                                .font(.system(size: 16))
                                                .foregroundColor(category.color)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(category.rawValue)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text(pendingCountLabel(for: category))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: selectedCategories.contains(category)
                                              ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedCategories.contains(category)
                                                             ? category.color : Color(.systemGray3))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } header: {
                            HStack {
                                Text("Select Categories")
                                Spacer()
                                Button(selectedCategories.count == Self.categories.count
                                       ? "Deselect All" : "Select All") {
                                    withAnimation(.spring(response: 0.25)) {
                                        if selectedCategories.count == Self.categories.count {
                                            selectedCategories.removeAll()
                                        } else {
                                            selectedCategories = Set(Self.categories)
                                        }
                                    }
                                }
                                .font(.caption)
                                .textCase(nil)
                            }
                        } footer: {
                            Text("Only incomplete or pending items from selected categories will be shared.")
                        }
                    }
                }

                // ── SHARE BUTTON (pinned at bottom) ──────────────────────
                if pro.isPro {
                    Button(action: buildAndShare) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Share Selected Tasks")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(selectedCategories.isEmpty ? Color(.systemGray3) : purpleAccent)
                        .cornerRadius(14)
                    }
                    .disabled(selectedCategories.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGroupedBackground))
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
            .background(ActivityPresenterBridge(items: $pendingShareItems))
            .sheet(isPresented: $showProUpgrade) {
                ProUpgradeView().environmentObject(pro)
            }
        }
    }

    // MARK: - Build & Share

    private func buildAndShare() {
        let ordered = Self.categories.filter { selectedCategories.contains($0) }
        var items: [Any] = []
        if shareAsImage {
            let card = ShareCardView(vm: vm, selectedCategories: ordered)
            let renderer = ImageRenderer(content: card)
            renderer.scale = UIScreen.main.scale
            if let image = renderer.uiImage {
                items = [image]
            } else {
                items = [buildShareText(ordered: ordered)]
            }
        } else {
            items = [buildShareText(ordered: ordered)]
        }
        pendingShareItems = items
    }

    // MARK: - Share Text Builder

    private func buildShareText(ordered: [SharableSection]) -> String {
        let entry = vm.currentEntry
        let dateStr = DateFormatter.localizedString(from: vm.selectedDate, dateStyle: .full, timeStyle: .none)
        var lines: [String] = []

        lines.append("📋 Daily Planner — \(dateStr)")
        lines.append(String(repeating: "─", count: 36))

        let timeFmt = DateFormatter()
        timeFmt.timeStyle = .short

        for category in ordered {
            let catLines = categoryTextLines(category, entry: entry, timeFmt: timeFmt)
            if !catLines.isEmpty {
                lines.append("")
                lines.append(contentsOf: catLines)
            }
        }

        if lines.count <= 2 {
            lines.append("")
            lines.append("All tasks completed!")
        }

        lines.append("")
        lines.append(String(repeating: "─", count: 36))
        lines.append("Shared from Daily Planner")
        return lines.joined(separator: "\n")
    }

    private func categoryTextLines(_ category: SharableSection, entry: DailyEntry, timeFmt: DateFormatter) -> [String] {
        var lines: [String] = []

        switch category {
        case .topPriorities:
            let pending = entry.topPriorities.filter { !$0.isCompleted }
            guard !pending.isEmpty else { return [] }
            lines.append("⭐ Top Priorities")
            for t in pending { lines.append("  ⬜ \(t.title)") }

        case .toDoLists:
            let pending = entry.toDoLists.filter { !$0.isCompleted }
            guard !pending.isEmpty else { return [] }
            lines.append("✅ To-Do Lists")
            for t in pending { lines.append("  ⬜ \(t.title)") }

        case .personalList:
            let pending = entry.personalTodo.filter { !$0.isCompleted }
            guard !pending.isEmpty else { return [] }
            lines.append("👤 Personal List")
            for t in pending { lines.append("  ⬜ \(t.title)") }

        case .callsEmails:
            let pending = entry.callsEmails.filter { !$0.isCompleted }
            guard !pending.isEmpty else { return [] }
            lines.append("📞 Calls & Emails")
            for t in pending { lines.append("  ⬜ \(t.title)") }

        case .appointments:
            let pending = entry.appointments.filter { !$0.isCompleted }
            guard !pending.isEmpty else { return [] }
            lines.append("🕐 Appointments")
            for a in pending {
                lines.append("  ⬜ \(timeFmt.string(from: a.time)) — \(a.title)")
                if !a.location.isEmpty { lines.append("     📍 \(a.location)") }
            }

        case .notes:
            guard !entry.notes.isEmpty else { return [] }
            lines.append("📝 Notes")
            lines.append("  \(entry.notes)")

        case .foodTracker:
            let meals = entry.meals
            let hasFood = !meals.breakfastItems.isEmpty || !meals.lunchItems.isEmpty
                || !meals.dinnerItems.isEmpty || !meals.snackItems.isEmpty
            guard hasFood else { return [] }
            lines.append("🍴 Food Tracker")
            func addMeal(_ label: String, _ items: [MealItem]) {
                guard !items.isEmpty else { return }
                lines.append("  \(label)")
                for item in items {
                    let cal = item.calories > 0 ? " (\(item.calories) kcal)" : ""
                    lines.append("    • \(item.name)\(cal)")
                }
            }
            addMeal("🌅 Breakfast", meals.breakfastItems)
            addMeal("☀️ Lunch", meals.lunchItems)
            addMeal("🌆 Dinner", meals.dinnerItems)
            addMeal("🍎 Snacks", meals.snackItems)
            lines.append("  Total: \(meals.totalCalories) kcal")

        case .waterTracker:
            guard entry.waterGlasses > 0 else { return [] }
            let pct = entry.waterGoal > 0
                ? Int(Double(entry.waterGlasses) / Double(entry.waterGoal) * 100) : 0
            lines.append("💧 Water Tracker")
            lines.append("  \(entry.waterGlasses)/\(entry.waterGoal) glasses (\(pct)%)")

        case .medications:
            let active = vm.settings.medications.filter { $0.isActive }
            guard !active.isEmpty else { return [] }
            lines.append("💊 Medications")
            for med in active {
                let times = med.times.map { timeFmt.string(from: $0) }.joined(separator: ", ")
                let dosage = med.dosage.isEmpty ? "" : " — \(med.dosage)"
                let timeStr = times.isEmpty ? "" : " @ \(times)"
                lines.append("  💊 \(med.name)\(dosage)\(timeStr)")
            }

        case .habits:
            let todayKey = vm.dateKey(for: vm.selectedDate)
            let completedIDs = vm.settings.habitLogs[todayKey]?.completedIDs ?? []
            let incomplete = vm.settings.habits.filter { !completedIDs.contains($0.id) }
            guard !incomplete.isEmpty else { return [] }
            lines.append("🔥 Habit Tracker")
            for habit in incomplete { lines.append("  ⬜ \(habit.name)") }

        case .sleepTracker:
            let sleep = entry.sleep
            guard sleep.bedtime != nil || sleep.wakeTime != nil else { return [] }
            lines.append("🌙 Sleep Tracker")
            if let bed = sleep.bedtime { lines.append("  Bedtime: \(timeFmt.string(from: bed))") }
            if let wake = sleep.wakeTime { lines.append("  Wake Up: \(timeFmt.string(from: wake))") }
            lines.append("  Duration: \(sleep.durationString)")
            if sleep.quality > 0 {
                lines.append("  Quality: \(String(repeating: "⭐", count: sleep.quality))")
            }

        case .expenses:
            let items = entry.expenses.filter { !$0.isDeposit && !$0.isIncome }
            guard !items.isEmpty else { return [] }
            lines.append("💰 Expense Tracker")
            lines.append("  Total: \(vm.settings.currency.symbol)\(String(format: "%.2f", entry.totalExpenses))")
            for exp in items {
                lines.append("  • \(exp.displayCategory): \(vm.settings.currency.symbol)\(String(format: "%.2f", exp.amount)) — \(exp.description)")
            }

        case .entireList:
            break
        }

        return lines
    }

    // MARK: - Pending Count Label

    private func pendingCountLabel(for category: SharableSection) -> String {
        let entry = vm.currentEntry
        switch category {
        case .topPriorities:
            let c = entry.topPriorities.filter { !$0.isCompleted }.count
            return c == 0 ? "All done!" : "\(c) pending"
        case .toDoLists:
            let c = entry.toDoLists.filter { !$0.isCompleted }.count
            return c == 0 ? "All done!" : "\(c) pending"
        case .personalList:
            let c = entry.personalTodo.filter { !$0.isCompleted }.count
            return c == 0 ? "All done!" : "\(c) pending"
        case .callsEmails:
            let c = entry.callsEmails.filter { !$0.isCompleted }.count
            return c == 0 ? "All done!" : "\(c) pending"
        case .appointments:
            let c = entry.appointments.filter { !$0.isCompleted }.count
            return c == 0 ? "All done!" : "\(c) pending"
        case .notes:
            return entry.notes.isEmpty ? "Empty" : "Has notes"
        case .foodTracker:
            let m = entry.meals
            let c = m.breakfastItems.count + m.lunchItems.count + m.dinnerItems.count + m.snackItems.count
            return c == 0 ? "No meals logged" : "\(c) items"
        case .waterTracker:
            return "\(entry.waterGlasses)/\(entry.waterGoal) glasses"
        case .medications:
            let c = vm.settings.medications.filter { $0.isActive }.count
            return c == 0 ? "None active" : "\(c) active"
        case .habits:
            let key = vm.dateKey(for: vm.selectedDate)
            let done = vm.settings.habitLogs[key]?.completedIDs ?? []
            let remaining = vm.settings.habits.filter { !done.contains($0.id) }.count
            return remaining == 0 ? "All done!" : "\(remaining) remaining"
        case .sleepTracker:
            return entry.sleep.bedtime != nil ? entry.sleep.durationString : "Not logged"
        case .expenses:
            let c = entry.expenses.filter { !$0.isDeposit && !$0.isIncome }.count
            return c == 0 ? "No expenses" : "\(c) entries"
        case .entireList:
            return ""
        }
    }
}

// MARK: - Share Card View (rendered to UIImage via ImageRenderer)
private struct ShareCardView: View {
    let vm: PlannerViewModel
    let selectedCategories: [SharableSection]

    private let purpleAccent = Color(red: 0.45, green: 0.25, blue: 0.85)
    private let maxItems = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📋 Daily Planner")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text(DateFormatter.localizedString(
                        from: vm.selectedDate, dateStyle: .full, timeStyle: .none))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [purpleAccent, Color(red: 0.6, green: 0.35, blue: 0.95)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )

            VStack(alignment: .leading, spacing: 16) {
                ForEach(selectedCategories) { section in
                    let items = cardItems(for: section)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(section.color)
                                Text(section.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                            }
                            ForEach(Array(items.prefix(maxItems).enumerated()), id: \.offset) { _, item in
                                Text(item)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            if items.count > maxItems {
                                Text("+\(items.count - maxItems) more")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }
                    }
                }
            }
            .padding(20)

            Divider().padding(.horizontal, 20)
            HStack {
                Spacer()
                Text("Shared from Daily Planner")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .frame(width: 360)
        .background(Color.white)
        .cornerRadius(16)
        .padding(16)
    }

    private func cardItems(for section: SharableSection) -> [String] {
        let entry = vm.currentEntry
        let timeFmt = DateFormatter()
        timeFmt.timeStyle = .short

        switch section {
        case .topPriorities:
            return entry.topPriorities.filter { !$0.isCompleted }.map { "⬜ \($0.title)" }
        case .toDoLists:
            return entry.toDoLists.filter { !$0.isCompleted }.map { "⬜ \($0.title)" }
        case .personalList:
            return entry.personalTodo.filter { !$0.isCompleted }.map { "⬜ \($0.title)" }
        case .callsEmails:
            return entry.callsEmails.filter { !$0.isCompleted }.map { "⬜ \($0.title)" }
        case .appointments:
            return entry.appointments.filter { !$0.isCompleted }
                .map { "⬜ \(timeFmt.string(from: $0.time)) — \($0.title)" }
        case .notes:
            return entry.notes.isEmpty ? [] : [entry.notes]
        case .foodTracker:
            var items: [String] = []
            for item in entry.meals.breakfastItems { items.append("🌅 \(item.name)") }
            for item in entry.meals.lunchItems { items.append("☀️ \(item.name)") }
            for item in entry.meals.dinnerItems { items.append("🌆 \(item.name)") }
            for item in entry.meals.snackItems { items.append("🍎 \(item.name)") }
            return items
        case .waterTracker:
            guard entry.waterGlasses > 0 else { return [] }
            let pct = entry.waterGoal > 0
                ? Int(Double(entry.waterGlasses) / Double(entry.waterGoal) * 100) : 0
            return ["\(entry.waterGlasses)/\(entry.waterGoal) glasses (\(pct)%)"]
        case .medications:
            return vm.settings.medications.filter { $0.isActive }.map { med in
                let dosage = med.dosage.isEmpty ? "" : " — \(med.dosage)"
                return "💊 \(med.name)\(dosage)"
            }
        case .habits:
            let key = vm.dateKey(for: vm.selectedDate)
            let done = vm.settings.habitLogs[key]?.completedIDs ?? []
            return vm.settings.habits.filter { !done.contains($0.id) }.map { "⬜ \($0.name)" }
        case .sleepTracker:
            let s = entry.sleep
            guard s.bedtime != nil || s.wakeTime != nil else { return [] }
            var items: [String] = []
            if let bed = s.bedtime { items.append("🌙 Bedtime: \(timeFmt.string(from: bed))") }
            if let wake = s.wakeTime { items.append("☀️ Wake: \(timeFmt.string(from: wake))") }
            items.append("⏱ \(s.durationString)")
            if s.quality > 0 { items.append("Quality: \(s.quality)/5") }
            return items
        case .expenses:
            return entry.expenses.filter { !$0.isDeposit && !$0.isIncome }.map { exp in
                "\(exp.displayCategory): \(vm.settings.currency.symbol)\(String(format: "%.2f", exp.amount))"
            }
        case .entireList:
            return []
        }
    }
}

// MARK: - UIKit Activity Presenter Bridge
// Embeds a hidden UIView in the hierarchy; when `items` is set, it walks the
// responder chain to find the hosting UIViewController and presents
// UIActivityViewController directly — bypassing SwiftUI sheet timing issues
// that can cause a blank share sheet on the first tap.
private struct ActivityPresenterBridge: UIViewRepresentable {
    @Binding var items: [Any]?

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isHidden = true
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let items = items, !items.isEmpty,
              uiView.window != nil else { return }

        DispatchQueue.main.async {
            guard let vc = uiView.nearestViewController,
                  vc.presentedViewController == nil else { return }

            let activity = UIActivityViewController(
                activityItems: items, applicationActivities: nil)
            activity.completionWithItemsHandler = { _, _, _, _ in
                DispatchQueue.main.async { self.items = nil }
            }
            if let pop = activity.popoverPresentationController {
                pop.sourceView = vc.view
                pop.sourceRect = CGRect(
                    x: vc.view.bounds.midX,
                    y: vc.view.bounds.midY,
                    width: 0, height: 0)
                pop.permittedArrowDirections = []
            }
            vc.present(activity, animated: true)
        }
    }
}

private extension UIView {
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}

// MARK: - iOS Share Sheet Wrapper
// Uses UIActivityItemSource (synchronous) so every app — WhatsApp, iMessage,
// Telegram, Gmail — immediately receives the full invitation text.
// (UIActivityItemProvider was async/background-queued and caused blank WhatsApp messages.)
struct ActivityShareSheet: UIViewControllerRepresentable {
    let text    : String
    let subject : String

    init(text: String, subject: String = "You've been invited to a shared task list") {
        self.text    = text
        self.subject = subject
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = ShareTextSource(text: text, subject: subject)
        let vc = UIActivityViewController(activityItems: [source], applicationActivities: nil)
        vc.excludedActivityTypes = [.assignToContact, .saveToCameraRoll, .addToReadingList]
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// UIActivityItemSource provides share data synchronously on the main thread.
/// Unlike UIActivityItemProvider (which runs on a background queue), this guarantees
/// WhatsApp, Telegram, iMessage and all other apps always receive the full text.
private final class ShareTextSource: NSObject, UIActivityItemSource {
    private let shareText : String
    private let subject   : String

    init(text: String, subject: String) {
        self.shareText = text
        self.subject   = subject
    }

    // Placeholder shown while the share sheet loads — must match the real item type.
    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        shareText
    }

    // Actual item delivered to every share target — always the full invitation text.
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        shareText
    }

    // Email subject — only used by Mail.app; ignored by WhatsApp, iMessage, etc.
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        activityType == .mail ? subject : ""
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
