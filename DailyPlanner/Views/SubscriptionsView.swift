import SwiftUI
import UIKit

// MARK: - Subscriptions

/// Every recurring payment in one place: what renews next, what each service
/// costs, where the money goes by category, and what it all adds up to.
///
/// Entries arrive on their own — App Store plans from Apple's receipts in
/// Gmail, everything else from receipts and from bank charges that keep
/// coming back. Anything missed is added by hand; anything wrong is removed
/// and stays removed.
struct SubscriptionsView: View {
    @EnvironmentObject var vm: PlannerViewModel

    @State private var editing: Subscription? = nil
    @State private var showAdd = false
    @State private var pendingCancel: Subscription? = nil
    @State private var pendingDelete: Subscription? = nil
    @State private var showCancelled = false
    @State private var scanning = false
    @State private var scanResult: String? = nil
    /// A category tapped in the breakdown narrows the list to it.
    @State private var focus: SubscriptionCategory? = nil

    private var sym: String { vm.settings.currency.symbol }

    var body: some View {
        // Read once per redraw. The view model caches the lists, and every
        // section below works from these copies rather than asking again.
        let active = vm.allSubscriptions
        let inactive = vm.cancelledSubscriptions
        let groups = CategoryGroup.build(from: active)

        ScrollView {
            LazyVStack(spacing: 14) {
                if !vm.settings.gmailConnectedEmail.isEmpty { gmailScanRow }

                if let next = active.first {
                    nextUpCard(next)
                    totalsCard(active)
                    if groups.count > 1 { breakdownCard(groups) }
                    listSection(groups)
                } else {
                    emptyState
                }

                if !inactive.isEmpty { cancelledSection(inactive) }

                appleRow

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { addBar }
        .sheet(isPresented: $showAdd) {
            SubscriptionEditSheet(subscription: nil, sym: sym,
                                  onSave: { vm.saveSubscription($0) })
        }
        .sheet(item: $editing) { sub in
            SubscriptionEditSheet(subscription: sub, sym: sym,
                                  onSave: { vm.saveSubscription($0) },
                                  onRemove: { vm.deleteSubscription(sub) })
        }
        .alert("Cancel this subscription?", isPresented: Binding(
            get: { pendingCancel != nil },
            set: { if !$0 { pendingCancel = nil } }
        )) {
            Button("Mark as cancelled") {
                if let s = pendingCancel { vm.cancelSubscription(s) }
                pendingCancel = nil
            }
            Button("Keep it", role: .cancel) { pendingCancel = nil }
        } message: {
            if let s = pendingCancel {
                Text("\(s.name) stops showing a next payment and leaves your monthly total. It stays on record below, and your past expenses aren't touched.")
            }
        }
        .alert("Remove from the list?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let s = pendingDelete { vm.deleteSubscription(s) }
                pendingDelete = nil
            }
            Button("Keep it", role: .cancel) { pendingDelete = nil }
        } message: {
            if let s = pendingDelete {
                Text("\(s.name) disappears from this page and won't come back from your emails or bank charges. You can still add it again yourself. Your expenses aren't touched.")
            }
        }
    }

    // MARK: - Next payment

    private func nextUpCard(_ sub: Subscription) -> some View {
        let days = sub.daysUntilDue
        let when: String = {
            if days <= 0 { return "Due today" }
            if days == 1 { return "Due tomorrow" }
            return "in \(days) days"
        }()
        let brand = sub.brand

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("NEXT PAYMENT")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(when)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.22)))
                    .foregroundColor(.white)
            }

            HStack(spacing: 14) {
                BrandTile(sub: sub, size: 54, onDark: true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sub.name)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(sub.cycle.rawValue) · \(Fmt.weekdayDay.string(from: sub.nextDue))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Text("\(sym)\(amountText(sub.amount))")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [brand.color, brand.color.opacity(0.72)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    // MARK: - Totals

    private func totalsCard(_ active: [Subscription]) -> some View {
        let monthly = active.reduce(0) { $0 + $1.monthlyCost }
        return HStack(spacing: 0) {
            totalPiece("Per month", "\(sym)\(amountText(monthly))")
            Divider().frame(height: 34)
            totalPiece("Per year", "\(sym)\(amountText(monthly * 12))")
            Divider().frame(height: 34)
            totalPiece("Active", "\(active.count)")
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func totalPiece(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category breakdown

    /// Where the money goes: one bar split by category, then each category's
    /// monthly cost, share and number of plans, biggest first.
    private func breakdownCard(_ groups: [CategoryGroup]) -> some View {
        let total = max(groups.reduce(0) { $0 + $1.monthly }, 0.0001)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BY CATEGORY")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundColor(.secondary)
                Spacer()
                Text("per month")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(groups) { g in
                        Rectangle()
                            .fill(g.category.color)
                            .frame(width: max(3, (geo.size.width - CGFloat(groups.count - 1) * 2)
                                                * CGFloat(g.monthly / total)))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())

            VStack(spacing: 2) {
                ForEach(groups) { g in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            focus = focus == g.category ? nil : g.category
                        }
                    } label: {
                        breakdownLine(g, share: g.monthly / total)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func breakdownLine(_ g: CategoryGroup, share: Double) -> some View {
        let selected = focus == g.category
        return HStack(spacing: 10) {
            Image(systemName: g.category.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(g.category.color))

            VStack(alignment: .leading, spacing: 1) {
                Text(g.category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text("\(g.subscriptions.count) plan\(g.subscriptions.count == 1 ? "" : "s") · \(Int((share * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(sym)\(amountText(g.monthly))")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
            Image(systemName: selected ? "line.3.horizontal.decrease.circle.fill" : "chevron.right")
                .font(.system(size: selected ? 15 : 10, weight: .bold))
                .foregroundColor(selected ? g.category.color : .secondary.opacity(0.6))
                .frame(width: 16)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(selected ? g.category.color.opacity(0.10) : Color.clear))
        .contentShape(Rectangle())
    }

    // MARK: - List

    private func listSection(_ groups: [CategoryGroup]) -> some View {
        let shown = focus.map { f in groups.filter { $0.category == f } } ?? groups

        return VStack(alignment: .leading, spacing: 8) {
            if let f = focus {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { focus = nil }
                } label: {
                    Label("Showing \(f.rawValue) · show all", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(f.color)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(f.color.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
            }

            ForEach(shown) { g in
                groupHeader(g)
                ForEach(g.subscriptions) { sub in row(sub) }
            }
        }
    }

    private func groupHeader(_ g: CategoryGroup) -> some View {
        HStack(spacing: 6) {
            Image(systemName: g.category.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(g.category.color)
            Text(g.category.rawValue.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.1)
            Text("\(g.subscriptions.count)")
                .font(.system(size: 11, weight: .heavy))
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Color.secondary.opacity(0.18)))
            Spacer()
            Text("\(sym)\(amountText(g.monthly))/mo")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private func row(_ sub: Subscription) -> some View {
        Button {
            editing = sub
        } label: {
            SubscriptionRow(sub: sub, sym: sym)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button { editing = sub } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button { pendingCancel = sub } label: {
                Label("Cancel subscription", systemImage: "xmark.circle")
            }
            Button(role: .destructive) { pendingDelete = sub } label: {
                Label("Not subscribed — remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Cancelled

    private func cancelledSection(_ cancelled: [Subscription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCancelled.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("CANCELLED & EXPIRED")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.1)
                    Text("\(cancelled.count)")
                        .font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.18)))
                    Spacer()
                    Image(systemName: showCancelled ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showCancelled {
                ForEach(cancelled) { sub in
                    Button { editing = sub } label: {
                        SubscriptionRow(sub: sub, sym: sym)
                            .opacity(0.6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button { vm.resumeSubscription(sub) } label: {
                            Label("Resume", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) { pendingDelete = sub } label: {
                            Label("Remove from list", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No subscriptions yet")
                .font(.system(size: 17, weight: .bold))
            Text("Recurring payments are picked up automatically from the spending you sync from Gmail. You can also add one yourself.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Gmail search

    /// Reads the last 13 months of receipts and cancellation notices. The
    /// regular sync only covers a month or two, so without this a yearly plan
    /// whose one receipt arrived last spring would never appear.
    private var gmailScanRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await scanGmail() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 11)
                            .fill(Color(red: 0.86, green: 0.27, blue: 0.22)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(scanning ? "Searching your Gmail…" : "Find subscriptions in Gmail")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Receipts, renewals and cancellations · last 13 months")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if scanning { ProgressView() }
                    else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground)))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(scanning)

            if let result = scanResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // GmailSyncService is main-actor isolated, and this updates view state.
    @MainActor
    private func scanGmail() async {
        scanning = true
        scanResult = nil
        defer { scanning = false }
        do {
            let events = try await GmailSyncService.shared.scanForSubscriptions(monthsBack: 13)
            guard !events.isEmpty else {
                scanResult = "No subscription emails found in the last 13 months."
                return
            }
            // Rebuild what came from email from scratch, so rows an older
            // reader got wrong ("Pro Monthly Plan", a wallet top-up) are
            // replaced. Plans typed in or edited, and removals, are kept.
            let before = Set(vm.allSubscriptions.map(\.detectionKey))
            vm.prepareSubscriptionRescan()
            vm.applySubscriptionEvents(events)
            let after = Set(vm.allSubscriptions.map(\.detectionKey))
            let added = after.subtracting(before).count
            scanResult = added == 0
                ? "Up to date · \(after.count) active subscription\(after.count == 1 ? "" : "s")."
                : "Found \(added) new · \(after.count) active subscription\(after.count == 1 ? "" : "s")."
        } catch {
            scanResult = "Couldn't search Gmail: \(error.localizedDescription)"
        }
    }

    // MARK: - Apple

    private var appleRow: some View {
        Button {
            // Apple exposes no API for reading subscriptions bought in other
            // apps, so the honest best is to hand the user straight to the
            // system screen that does list them.
            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "applelogo")
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11)
                        .fill(Color.primary.opacity(0.08)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("App Store subscriptions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Opens your Apple subscriptions to cross-check")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Add bar

    private var addBar: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Subscription").fontWeight(.bold)
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(vm.settings.themeColor.primary))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func amountText(_ value: Double) -> String { Fmt.amount(value) }
}

// MARK: - Grouping

/// The active plans in one category, with what they cost a month together.
struct CategoryGroup: Identifiable {
    let category: SubscriptionCategory
    let subscriptions: [Subscription]
    let monthly: Double
    var id: String { category.rawValue }

    /// Biggest spend first; plans keep their soonest-payment order inside.
    static func build(from subs: [Subscription]) -> [CategoryGroup] {
        Dictionary(grouping: subs, by: \.effectiveCategory)
            .map { CategoryGroup(category: $0.key, subscriptions: $0.value,
                                 monthly: $0.value.reduce(0) { $0 + $1.monthlyCost }) }
            .sorted { a, b in
                a.monthly != b.monthly ? a.monthly > b.monthly : a.category.rawValue < b.category.rawValue
            }
    }
}

// MARK: - Formatting

/// Made once. A DateFormatter per row per redraw was part of what made the
/// list stutter while scrolling.
private enum Fmt {
    static let weekdayDay: DateFormatter = make("EEE, d MMM")
    static let dayMonth: DateFormatter = make("d MMM")
    static let monthYear: DateFormatter = make("MMM yyyy")

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter(); f.dateFormat = format; return f
    }

    /// Three decimals only when the currency actually uses them.
    static func amount(_ value: Double) -> String {
        let hasThird = abs(value * 100 - (value * 100).rounded()) > 0.0000001
        return String(format: hasThird ? "%.3f" : "%.2f", value)
    }
}

// MARK: - Brand tile

/// The service's real app icon when one is known — from its App Store receipt,
/// or looked up from Apple's catalogue — otherwise a coloured glyph or
/// monogram of our own.
struct BrandTile: View {
    let brand: SubscriptionBrand
    var size: CGFloat = 44
    var onDark: Bool = false
    var iconURL: String? = nil
    /// Catalogue name to look the icon up under, for plans paid by card.
    var lookupName: String? = nil

    @State private var image: UIImage?

    init(brand: SubscriptionBrand, size: CGFloat = 44, onDark: Bool = false,
         iconURL: String? = nil, lookupName: String? = nil) {
        self.brand = brand
        self.size = size
        self.onDark = onDark
        self.iconURL = iconURL
        self.lookupName = lookupName
        // Straight from memory when it's there, so a row scrolling back into
        // view never flashes the placeholder.
        _image = State(initialValue: SubscriptionIconStore.shared
            .cachedImage(url: iconURL, brand: lookupName))
    }

    init(sub: Subscription, size: CGFloat = 44, onDark: Bool = false) {
        let brand = sub.brand
        let lookup = SubscriptionIconStore.canLookUp(brand.name) ? brand.name : nil
        self.init(brand: brand, size: size, onDark: onDark,
                  iconURL: sub.iconURL, lookupName: lookup)
    }

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            } else {
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(onDark ? AnyShapeStyle(Color.white.opacity(0.22))
                                 : AnyShapeStyle(LinearGradient(
                                        colors: [brand.color, brand.color.opacity(0.78)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)))

                if brand.keywords.isEmpty {
                    Text(brand.monogram)
                        .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: brand.symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: (iconURL ?? "") + "|" + (lookupName ?? "")) {
            guard iconURL != nil || lookupName != nil else { return }
            if let loaded = await SubscriptionIconStore.shared.image(url: iconURL, brand: lookupName) {
                image = loaded
            }
        }
    }
}

// MARK: - Row

private struct SubscriptionRow: View {
    let sub: Subscription
    let sym: String

    var body: some View {
        // Worked out once per row, not once per text that shows it.
        let next = sub.nextDue
        let days = sub.daysUntilDue
        let isSoon = sub.isActive && days <= 3
        let brand = sub.brand

        HStack(spacing: 12) {
            BrandTile(sub: sub, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(sub.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if sub.viaApple {
                        Image(systemName: "applelogo")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Text(sub.cycle.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(brand.color.opacity(0.14)))
                        .foregroundColor(brand.color)
                }

                Text(detailText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(sym)\(Fmt.amount(sub.amount))")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text(dueText(next: next, days: days))
                    .font(.caption2)
                    .foregroundColor(isSoon ? .orange : .secondary)
                    .fontWeight(isSoon ? .semibold : .regular)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemGroupedBackground)))
        .contentShape(Rectangle())
    }

    /// The plan, whose it is, and since when: "SuperGrok · Family · regina ·
    /// since Jan 2026 · billed ₹700.00".
    private var detailText: String {
        var parts: [String] = []
        if let plan = sub.planName, !plan.isEmpty,
           plan.lowercased() != sub.name.lowercased(),
           !["monthly", "yearly", "annual", "weekly"].contains(plan.lowercased()) {
            parts.append(plan)
        }
        if let member = sub.accountEmail, let local = member.split(separator: "@").first {
            parts.append("Family · \(local)")
        }
        parts.append("since \(Fmt.monthYear.string(from: sub.startedOn))")
        // An Indian App Store account bills in rupees; the list shows the
        // converted figure so totals add up, and the real charge here.
        if let original = sub.originalAmount, !sub.currencyCode.isEmpty {
            parts.append("billed \(Self.symbol(for: sub.currencyCode))\(String(format: "%.2f", original))")
        }
        return parts.joined(separator: " · ")
    }

    private static func symbol(for code: String) -> String {
        switch code.uppercased() {
        case "INR": return "₹"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default:    return code.uppercased() + " "
        }
    }

    private func dueText(next: Date, days: Int) -> String {
        // Cancelled but paid up: it still works until then, and won't renew.
        if let ends = sub.endsOn, ends >= Calendar.current.startOfDay(for: Date()) {
            return "Ends \(Fmt.dayMonth.string(from: ends))"
        }
        if let ended = sub.cancelledOn {
            return "Cancelled \(Fmt.dayMonth.string(from: ended))"
        }
        if let ran = sub.lapsedOn {
            return "Expired \(Fmt.dayMonth.string(from: ran))"
        }
        let prefix = days <= 0 ? "Due today" : (days == 1 ? "Tomorrow" : "\(days) days")
        return "\(prefix) · \(Fmt.dayMonth.string(from: next))"
    }
}

// MARK: - Add / edit

struct SubscriptionEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription?
    let sym: String
    let onSave: (Subscription) -> Void
    /// Set when editing an existing plan, so it can be removed from here —
    /// the long-press menu alone was too easy to miss.
    var onRemove: (() -> Void)? = nil

    @State private var confirmRemove = false

    @State private var name: String
    @State private var amount: String
    @State private var cycle: BillingCycle
    @State private var startedOn: Date
    @State private var lastChargedOn: Date
    /// nil follows the automatic guess from the name.
    @State private var category: SubscriptionCategory?

    init(subscription: Subscription?, sym: String,
         onSave: @escaping (Subscription) -> Void,
         onRemove: (() -> Void)? = nil) {
        self.subscription = subscription
        self.sym = sym
        self.onSave = onSave
        self.onRemove = onRemove
        _name    = State(initialValue: subscription?.name ?? "")
        _cycle   = State(initialValue: subscription?.cycle ?? .monthly)
        _startedOn = State(initialValue: subscription?.startedOn ?? Date())
        _lastChargedOn = State(initialValue: subscription?.lastChargedOn ?? Date())
        _category = State(initialValue: subscription?.category)
        if let a = subscription?.amount {
            let hasThird = abs(a * 100 - (a * 100).rounded()) > 0.0000001
            _amount = State(initialValue: String(format: hasThird ? "%.3f" : "%.2f", a))
        } else {
            _amount = State(initialValue: "")
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && (Double(amount) ?? 0) > 0 }
    private var autoCategory: SubscriptionCategory {
        SubscriptionCategory.infer(name: trimmedName, plan: subscription?.planName)
    }
    private var preview: SubscriptionBrand {
        SubscriptionBrand.match(trimmedName)
            ?? SubscriptionBrand.generic(named: trimmedName.isEmpty ? "New" : trimmedName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 14) {
                        BrandTile(brand: preview, size: 52, iconURL: subscription?.iconURL,
                                  lookupName: SubscriptionIconStore.canLookUp(preview.name) ? preview.name : nil)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trimmedName.isEmpty ? "New subscription" : trimmedName)
                                .font(.system(size: 17, weight: .bold))
                                .lineLimit(1)
                            Text(cycle.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section("Details") {
                    TextField("Service, e.g. Netflix", text: $name)
                        .autocorrectionDisabled()

                    HStack {
                        Text(sym).foregroundColor(.secondary)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Billing", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { c in Text(c.rawValue).tag(c) }
                    }

                    Picker("Category", selection: $category) {
                        Text("Automatic · \(autoCategory.rawValue)")
                            .tag(SubscriptionCategory?.none)
                        ForEach(SubscriptionCategory.allCases) { c in
                            Label(c.rawValue, systemImage: c.symbol).tag(Optional(c))
                        }
                    }
                }

                Section {
                    DatePicker("Subscribed on", selection: $startedOn,
                               displayedComponents: .date)

                    // A new plan bills on from the day it started, so there is
                    // nothing else to ask. An existing one may already be part
                    // way through its cycle, so that gets the extra field.
                    if subscription != nil {
                        DatePicker("Last payment", selection: $lastChargedOn,
                                   displayedComponents: .date)
                    }
                } footer: {
                    Text(subscription == nil
                         ? "Payments are scheduled forward from this date, every \(cycle.rawValue.lowercased().replacingOccurrences(of: "ly", with: "")) period, until you cancel."
                         : "The next payment is worked out from the last payment and the billing cycle.")
                }

                if let existing = subscription, !existing.isActive,
                   let ended = existing.cancelledOn {
                    Section {
                        Label("Cancelled on \(ended.formatted(date: .abbreviated, time: .omitted))",
                              systemImage: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let onRemove = onRemove {
                    Button(role: .destructive) {
                        confirmRemove = true
                    } label: {
                        Label("Not subscribed — remove", systemImage: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(Color.red.opacity(0.10)))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .confirmationDialog("Remove \(trimmedName.isEmpty ? "this" : trimmedName)?",
                                        isPresented: $confirmRemove, titleVisibility: .visible) {
                        Button("Remove from list", role: .destructive) {
                            onRemove()
                            dismiss()
                        }
                    } message: {
                        Text("For something you're not subscribed to. It won't come back from your emails or bank charges, and your expenses aren't touched.")
                    }
                }
            }
            .navigationTitle(subscription == nil ? "Add Subscription" : "Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let value = Double(amount), value > 0 else { return }
        let isNew = subscription == nil
        var result = subscription ?? Subscription(name: trimmedName, amount: value,
                                                  startedOn: startedOn,
                                                  lastChargedOn: startedOn)
        result.name = trimmedName
        result.amount = value
        result.cycle = cycle
        result.category = category
        result.startedOn = startedOn
        // A new plan's first payment is the day it started; the schedule runs
        // forward from there on its own.
        result.lastChargedOn = isNew ? startedOn : lastChargedOn
        // Editing a detected entry pins it: the user's figures win from now on.
        result.isDetected = false
        onSave(result)
        dismiss()
    }
}
