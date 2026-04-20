import SwiftUI
import StoreKit

// MARK: - Pro Upgrade Paywall
struct ProUpgradeView: View {
    @EnvironmentObject private var pro: ProManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PlanType = .yearly
    @State private var isPurchasing = false
    @State private var isRestoring  = false

    enum PlanType { case monthly, yearly }

    private let proFeatures: [(icon: String, name: String, desc: String)] = [
        ("icloud.fill",              "iCloud Sync",           "Sync across all your Apple devices"),
        ("square.and.arrow.up.fill", "Task Sharing",          "Share task categories & receive notifications when accepted"),
        ("rectangle.on.rectangle",  "Home Screen Widgets",    "At-a-glance widgets on your home screen"),
        ("arrow.clockwise",          "Recurring Tasks",        "Daily, weekly & monthly auto-scheduling"),
        ("magnifyingglass",          "Global Search",          "Search tasks, notes & expenses instantly"),
        ("arrow.up.doc.fill",        "PDF & CSV Export",       "Export your planner data anytime"),
        ("timer",                    "Pomodoro Timer",         "Stay focused with timed work sessions"),
        ("checkmark.circle.fill",    "Habit Tracker",          "Build streaks & lasting daily habits"),
        ("dollarsign.circle.fill",   "Budget Limits",          "Set spending caps per category"),
        ("moon.zzz.fill",            "Sleep Tracker",          "Log sleep & monitor quality over time"),
        ("calendar.badge.clock",     "Weekly/Monthly Summary", "Aggregated insights across any period"),
        ("mic.fill",                 "Siri Shortcuts",         "Voice commands & Shortcuts app actions"),
        ("list.bullet.indent",       "Task Notes & Subtasks",  "Break tasks into actionable steps"),
        ("chart.bar.fill",           "Spending Trends",        "Visual charts of your expense history"),
        ("paintpalette.fill",        "Color Themes",           "8 beautiful accent colors for the app"),
        ("pill.fill",                "Medication Reminders",   "Never miss a dose with smart reminders"),
    ]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                    featuresList
                    planSection
                    purchaseCTA
                    footerLinks
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(.systemGray3))
                    }
                }
            }
            .overlay(
                Group {
                    if isPurchasing || isRestoring {
                        ZStack {
                            Color.black.opacity(0.3).ignoresSafeArea()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.4)
                                    .tint(.white)
                                Text(isPurchasing ? "Processing…" : "Restoring…")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding(28)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                    }
                }
            )
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.05, blue: 0.30),
                         Color(red: 0.30, green: 0.10, blue: 0.60)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 14) {
                // Crown badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 1.0, green: 0.85, blue: 0.2),
                                         Color(red: 1.0, green: 0.55, blue: 0.0)],
                                center: .center, startRadius: 0, endRadius: 45
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.0).opacity(0.5), radius: 20)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.white)
                }

                Text("Daily Planner PRO")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Unlock all 15 premium features and\ntake full control of your day.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.vertical, 36)
        }
    }

    // MARK: - Features List
    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EVERYTHING INCLUDED")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(proFeatures.enumerated()), id: \.offset) { idx, feature in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(featureColor(idx).opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: feature.icon)
                                .foregroundColor(featureColor(idx))
                                .font(.system(size: 15))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.name)
                                .font(.system(size: 14, weight: .semibold))
                            Text(feature.desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.1, green: 0.75, blue: 0.4))
                            .font(.system(size: 18))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    if idx < proFeatures.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
    }

    private func featureColor(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.1, green: 0.6, blue: 0.95),
            Color(red: 0.45, green: 0.25, blue: 0.85),
            Color(red: 0.1, green: 0.65, blue: 0.35),
            Color(red: 0.9, green: 0.2, blue: 0.3),
            Color(red: 0.95, green: 0.55, blue: 0.1),
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.45, green: 0.25, blue: 0.85),
            Color(red: 0.1, green: 0.65, blue: 0.35),
            Color(red: 0.25, green: 0.15, blue: 0.65),
            Color(red: 0.4, green: 0.3, blue: 0.85),
            Color(red: 0.05, green: 0.65, blue: 0.95),
            Color(red: 0.0, green: 0.6, blue: 0.85),
            Color(red: 0.1, green: 0.65, blue: 0.35),
            Color(red: 0.9, green: 0.3, blue: 0.5),
            Color(red: 0.1, green: 0.6, blue: 0.65),
        ]
        return colors[index % colors.count]
    }

    // MARK: - Plan Cards
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHOOSE YOUR PLAN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 2)

            HStack(spacing: 12) {
                planCard(
                    type: .yearly,
                    topBadge: "BEST VALUE",
                    title: "Yearly",
                    price: pro.yearlyPriceString,
                    perMonth: yearlyPerMonth,
                    savings: "Save \(pro.yearlySavings)",
                    highlight: true
                )
                planCard(
                    type: .monthly,
                    topBadge: nil,
                    title: "Monthly",
                    price: pro.monthlyPriceString,
                    perMonth: "per month",
                    savings: nil,
                    highlight: false
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private var yearlyPerMonth: String {
        if let y = pro.yearlyProduct {
            let monthlyEquiv = y.price / 12
            return y.priceFormatStyle.format(monthlyEquiv) + "/mo"
        }
        return "₹83.25/mo"
    }

    private func planCard(type: PlanType, topBadge: String?, title: String,
                          price: String, perMonth: String, savings: String?,
                          highlight: Bool) -> some View {
        let isSelected = selectedPlan == type
        return Button(action: { selectedPlan = type }) {
            VStack(spacing: 10) {
                // Badge
                if let badge = topBadge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            LinearGradient(colors: [Color(red: 1.0, green: 0.65, blue: 0.0),
                                                    Color(red: 1.0, green: 0.40, blue: 0.0)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(8)
                } else {
                    Spacer().frame(height: 18)
                }

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? Color(red: 0.30, green: 0.10, blue: 0.60) : .primary)

                Text(price)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? Color(red: 0.30, green: 0.10, blue: 0.60) : .primary)

                Text(perMonth)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let savings = savings {
                    Text(savings)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.1, green: 0.75, blue: 0.4))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(red: 0.1, green: 0.75, blue: 0.4).opacity(0.12))
                        .cornerRadius(8)
                } else {
                    Spacer().frame(height: 22)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                          ? Color(red: 0.30, green: 0.10, blue: 0.60).opacity(0.07)
                          : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected
                            ? Color(red: 0.30, green: 0.10, blue: 0.60)
                            : Color(.separator),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Purchase CTA
    private var purchaseCTA: some View {
        VStack(spacing: 12) {
            Button(action: performPurchase) {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                    Text(selectedPlan == .yearly
                         ? "Start PRO — \(pro.yearlyPriceString)/year"
                         : "Start PRO — \(pro.monthlyPriceString)/month")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.65, blue: 0.0),
                                 Color(red: 1.0, green: 0.35, blue: 0.0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.35), radius: 12, y: 6)
            }
            .disabled(pro.products.isEmpty || pro.isLoading)
            .opacity(pro.products.isEmpty || pro.isLoading ? 0.5 : 1.0)
            .padding(.horizontal, 16)
            .padding(.top, 20)

            if pro.isLoading {
                Text("Loading pricing…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let error = pro.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Footer
    private var footerLinks: some View {
        VStack(spacing: 6) {
            Button(action: performRestore) {
                Text("Restore Purchases")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.30, green: 0.10, blue: 0.60))
            }
            .padding(.top, 8)

            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the renewal date. Manage in App Store Settings.")
                .font(.system(size: 10))
                .foregroundColor(Color(.systemGray3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
        }
    }

    // MARK: - Actions
    private func performPurchase() {
        guard !isPurchasing else { return }
        let product = selectedPlan == .yearly ? pro.yearlyProduct : pro.monthlyProduct
        guard let product else {
            pro.purchaseError = "Unable to connect to the App Store. Please check your internet connection and try again."
            return
        }
        isPurchasing = true
        Task {
            let success = await pro.purchase(product)
            isPurchasing = false
            if success { dismiss() }
        }
    }

    private func performRestore() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            await pro.restorePurchases()
            isRestoring = false
            if pro.isPro { dismiss() }
        }
    }
}

// MARK: - Crown Button (used in App Header)
struct CrownButton: View {
    @EnvironmentObject private var pro: ProManager
    @State private var showUpgrade = false

    var body: some View {
        Button(action: { showUpgrade = true }) {
            ZStack {
                if pro.isPro {
                    // Gold filled crown with PRO label
                    VStack(spacing: 1) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.80, blue: 0.0))
                        Text("PRO")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(Color(red: 1.0, green: 0.80, blue: 0.0))
                    }
                } else {
                    // Outline crown (not yet pro)
                    VStack(spacing: 1) {
                        Image(systemName: "crown")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        Text("PRO")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.leading, 8)
        }
        .sheet(isPresented: $showUpgrade) {
            ProUpgradeView().environmentObject(pro)
        }
    }
}
