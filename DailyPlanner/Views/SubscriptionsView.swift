import SwiftUI
import UIKit

// MARK: - Subscriptions

/// Every recurring payment in one place: what renews next, what each service
/// costs, and what it all adds up to over a month and a year.
///
/// Most entries arrive on their own — a subscription is a merchant that keeps
/// charging, and the app already imports those charges from the bank alerts in
/// Gmail. Anything the detector misses is added by hand, which is also how App
/// Store subscriptions get here: Apple gives an app no way to read the ones
/// bought through other apps, so there is a shortcut to iOS Settings instead.
struct SubscriptionsView: View {
    @EnvironmentObject var vm: PlannerViewModel

    @State private var editing: Subscription? = nil
    @State private var showAdd = false
    @State private var pendingCancel: Subscription? = nil
    @State private var pendingDelete: Subscription? = nil
    @State private var showCancelled = false

    private var sym: String { vm.settings.currency.symbol }

    private var subscriptions: [Subscription] { vm.allSubscriptions }
    private var cancelled: [Subscription] { vm.cancelledSubscriptions }

    private var next: Subscription? { subscriptions.first }

    private var monthlyTotal: Double { subscriptions.reduce(0) { $0 + $1.monthlyCost } }
    private var yearlyTotal : Double { subscriptions.reduce(0) { $0 + $1.yearlyCost } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let next = next {
                    nextUpCard(next)
                    totalsCard
                    listSection
                } else {
                    emptyState
                }

                if !cancelled.isEmpty { cancelledSection }

                appleRow

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { addBar }
        .sheet(isPresented: $showAdd) {
            SubscriptionEditSheet(subscription: nil, sym: sym) { vm.saveSubscription($0) }
        }
        .sheet(item: $editing) { sub in
            SubscriptionEditSheet(subscription: sub, sym: sym) { vm.saveSubscription($0) }
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
                Text("\(s.name) disappears from this page entirely. Your expenses aren't touched.")
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
                BrandTile(brand: sub.brand, size: 54, onDark: true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sub.name)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(dueLine(sub))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Text("\(sym)\(amountText(sub.amount))")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [sub.brand.color,
                                              sub.brand.color.opacity(0.72)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: sub.brand.color.opacity(0.35), radius: 14, y: 6)
    }

    private func dueLine(_ sub: Subscription) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
        return "\(sub.cycle.rawValue) · \(f.string(from: sub.nextDue))"
    }

    // MARK: - Totals

    private var totalsCard: some View {
        HStack(spacing: 0) {
            totalPiece("Per month", monthlyTotal)
            Divider().frame(height: 34)
            totalPiece("Per year", yearlyTotal)
            Divider().frame(height: 34)
            totalPiece("Active", Double(subscriptions.count), isCount: true)
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func totalPiece(_ title: String, _ value: Double, isCount: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(isCount ? "\(Int(value))" : "\(sym)\(amountText(value))")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALL SUBSCRIPTIONS")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.1)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                .padding(.top, 4)

            ForEach(subscriptions) { sub in
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
                        Label("Remove from list", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Cancelled

    private var cancelledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { showCancelled.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("CANCELLED")
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
                    SubscriptionRow(sub: sub, sym: sym)
                        .opacity(0.6)
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
                    Text("Opens iOS Settings · add them here to track")
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

    private func amountText(_ value: Double) -> String {
        // Three decimals only when the currency actually uses them.
        let hasThird = abs(value * 100 - (value * 100).rounded()) > 0.0000001
        return String(format: hasThird ? "%.3f" : "%.2f", value)
    }
}

// MARK: - Brand tile

/// A coloured monogram standing in for the service's logo — our own artwork,
/// so nothing third-party ships inside the app.
struct BrandTile: View {
    let brand: SubscriptionBrand
    var size: CGFloat = 44
    var onDark: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(onDark ? AnyShapeStyle(Color.white.opacity(0.22))
                             : AnyShapeStyle(LinearGradient(
                                    colors: [brand.color, brand.color.opacity(0.78)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)))

            Text(brand.monogram)
                .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Row

private struct SubscriptionRow: View {
    let sub: Subscription
    let sym: String

    private var sinceText: String {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return "Since \(f.string(from: sub.startedOn))"
    }

    private var dueText: String {
        let f = DateFormatter(); f.dateFormat = "d MMM"
        if let ended = sub.cancelledOn {
            return "Cancelled \(f.string(from: ended))"
        }
        let days = sub.daysUntilDue
        let prefix = days <= 0 ? "Due today" : (days == 1 ? "Tomorrow" : "\(days) days")
        return "\(prefix) · \(f.string(from: sub.nextDue))"
    }

    private var isSoon: Bool { sub.isActive && sub.daysUntilDue <= 3 }

    var body: some View {
        HStack(spacing: 12) {
            BrandTile(brand: sub.brand, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(sub.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(sub.cycle.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(sub.brand.color.opacity(0.14)))
                        .foregroundColor(sub.brand.color)
                }

                Text(sinceText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(sym)\(amountText(sub.amount))")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text(dueText)
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

    private func amountText(_ value: Double) -> String {
        let hasThird = abs(value * 100 - (value * 100).rounded()) > 0.0000001
        return String(format: hasThird ? "%.3f" : "%.2f", value)
    }
}

// MARK: - Add / edit

struct SubscriptionEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription?
    let sym: String
    let onSave: (Subscription) -> Void

    @State private var name: String
    @State private var amount: String
    @State private var cycle: BillingCycle
    @State private var startedOn: Date
    @State private var lastChargedOn: Date

    init(subscription: Subscription?, sym: String, onSave: @escaping (Subscription) -> Void) {
        self.subscription = subscription
        self.sym = sym
        self.onSave = onSave
        _name    = State(initialValue: subscription?.name ?? "")
        _cycle   = State(initialValue: subscription?.cycle ?? .monthly)
        _startedOn = State(initialValue: subscription?.startedOn ?? Date())
        _lastChargedOn = State(initialValue: subscription?.lastChargedOn ?? Date())
        if let a = subscription?.amount {
            let hasThird = abs(a * 100 - (a * 100).rounded()) > 0.0000001
            _amount = State(initialValue: String(format: hasThird ? "%.3f" : "%.2f", a))
        } else {
            _amount = State(initialValue: "")
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && (Double(amount) ?? 0) > 0 }
    private var preview: SubscriptionBrand {
        SubscriptionBrand.match(trimmedName)
            ?? SubscriptionBrand.generic(named: trimmedName.isEmpty ? "New" : trimmedName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 14) {
                        BrandTile(brand: preview, size: 52)
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
