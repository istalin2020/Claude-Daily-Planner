import SwiftUI
import StoreKit

// MARK: - Pro Upgrade Paywall
struct ProUpgradeView: View {
    @EnvironmentObject private var pro: ProManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PlanType = .yearly
    @State private var isPurchasing = false
    @State private var isRestoring  = false
    @State private var showSuccessAlert = false
    @State private var purchasedInfo: SubscriptionInfo? = nil

    enum PlanType { case monthly, yearly }

    private var proFeatures: [(icon: String, name: String, desc: String)] { Self.features }

    /// Everything PRO unlocks, most wanted first. Its count is quoted in
    /// Settings and on locked pages, so it stays right when this changes.
    static let features: [(icon: String, name: String, desc: String)] = [
        ("icloud.fill",              "iCloud Sync",            "Sync across all your Apple devices"),
        ("repeat.circle.fill",       "Subscription Schedule",  "Every renewal from Gmail, by category"),
        ("envelope.badge.fill",      "Gmail Expense Sync",     "Bank alerts in Gmail become expenses for you to review"),
        ("fork.knife.circle.fill",   "AI Calorie Calculator (GPT)", "Snap or type a meal for calories & macros"),
        ("chart.bar.fill",           "Spending Trends",        "Visual charts of your expense history"),
        ("paintpalette.fill",        "Color Themes",           "8 beautiful accent colors for the app"),
        ("pill.fill",                "Medication Reminders",   "Never miss a dose with smart reminders"),
        ("checkmark.circle.fill",    "Habit Tracker",          "Build streaks & lasting daily habits"),
        ("mic.fill",                 "Siri Shortcuts",         "Voice commands & Shortcuts app actions"),
        ("arrow.clockwise",          "Recurring Tasks",        "Daily, weekly & monthly auto-scheduling"),
        ("magnifyingglass",          "Global Search",          "Search tasks, notes & expenses instantly"),
        ("square.and.arrow.up.fill", "Task Sharing",           "Share task categories & receive notifications when accepted"),
        ("arrow.up.doc.fill",        "PDF & CSV Export",       "Export your planner data anytime"),
        ("timer",                    "Pomodoro Timer",         "Stay focused with timed work sessions"),
        ("dollarsign.circle.fill",   "Budget Limits",          "Set spending caps per category"),
        ("moon.zzz.fill",            "Sleep Tracker",          "Log sleep & monitor quality over time"),
        ("calendar.badge.clock",     "Weekly/Monthly Summary", "Aggregated insights across any period"),
        ("list.bullet.indent",       "Task Notes & Subtasks",  "Break tasks into actionable steps"),
    ]

    @Environment(\.themeAccent) private var themeAccent

    /// Brand purple for the paywall's own accents.
    private let purple = Color(red: 0.30, green: 0.10, blue: 0.60)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroHeader
                featuresGrid
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        // Price and Start PRO stay on screen; only the features scroll.
        .safeAreaInset(edge: .bottom, spacing: 0) { purchasePanel }
        .background(SoftBackground(theme: pro.isPro ? themeAccent : nil).ignoresSafeArea())
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
        .alert("Welcome to PRO!", isPresented: $showSuccessAlert) {
            Button("Let's Go!") {
                dismiss()
            }
        } message: {
            if let info = purchasedInfo {
                let renewalText: String = {
                    if let expiry = info.expirationDate {
                        return "Renews on: \(ProManager.formattedDate(expiry))"
                    }
                    return ""
                }()
                Text("Your \(info.planName) subscription is now active.\n\nPlan: \(info.planName)\nPrice: \(info.price)\nStarted: \(ProManager.formattedDate(info.purchaseDate))\n\(renewalText)\n\nAll \(Self.features.count) premium features are now unlocked. Enjoy!")
            } else {
                Text("Your PRO subscription is now active. All premium features are unlocked!")
            }
        }
    }

    // MARK: - Hero (slim)
    private var heroHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.85, blue: 0.2),
                                                  Color(red: 1.0, green: 0.55, blue: 0.0)],
                                         center: .center, startRadius: 0, endRadius: 26))
                    .frame(width: 48, height: 48)
                    .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.0).opacity(0.45), radius: 8)
                Image(systemName: "crown.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Planner PRO")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text("Unlock all \(Self.features.count) premium features")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .accessibilityLabel("Close")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.05, blue: 0.30),
                                              Color(red: 0.30, green: 0.10, blue: 0.60)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: purple.opacity(0.25), radius: 10, y: 4)
    }

    // MARK: - Features (two columns)
    private var featuresGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVERYTHING INCLUDED")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(proFeatures.enumerated()), id: \.offset) { idx, feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(featureColor(idx))
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(featureColor(idx).opacity(0.14)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2).minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(feature.desc)
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(Color.adaptive(light: UIColor(white: 1, alpha: 0.9),
                                             dark: UIColor(white: 1, alpha: 0.07))))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(featureColor(idx).opacity(0.12), lineWidth: 1))
                }
            }
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
            Color(red: 0.85, green: 0.25, blue: 0.45),
        ]
        return colors[index % colors.count]
    }

    // MARK: - Pinned purchase panel
    private var purchasePanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                planCard(type: .yearly, badge: "BEST VALUE", title: "Yearly",
                         price: pro.yearlyPriceString,
                         detail: pro.yearlySavings.isEmpty ? yearlyPerMonth
                                 : "\(yearlyPerMonth) · Save \(pro.yearlySavings)")
                planCard(type: .monthly, badge: nil, title: "Monthly",
                         price: pro.monthlyPriceString, detail: "per month")
            }
            purchaseCTA
            footerLinks
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 10, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var yearlyPerMonth: String {
        if let y = pro.yearlyProduct {
            let monthlyEquiv = y.price / 12
            return y.priceFormatStyle.format(monthlyEquiv) + "/mo"
        }
        return "₹83/mo"
    }

    private func planCard(type: PlanType, badge: String?, title: String,
                          price: String, detail: String) -> some View {
        let isSelected = selectedPlan == type
        return Button(action: { selectedPlan = type }) {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(LinearGradient(
                                colors: [Color(red: 1.0, green: 0.65, blue: 0.0), Color(red: 1.0, green: 0.40, blue: 0.0)],
                                startPoint: .leading, endPoint: .trailing)))
                    }
                }
                .foregroundColor(isSelected ? purple : .primary)
                Text(price)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? purple : .primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(detail)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? purple.opacity(0.08)
                      : Color.adaptive(light: UIColor(white: 1, alpha: 0.85), dark: UIColor(white: 1, alpha: 0.07))))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? purple : Color(.separator), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Purchase CTA
    private var purchaseCTA: some View {
        VStack(spacing: 6) {
            Button(action: performPurchase) {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                    }
                    Text(selectedPlan == .yearly
                         ? "Start PRO — \(pro.yearlyPriceString)/year"
                         : "Start PRO — \(pro.monthlyPriceString)/month")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
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
            .disabled(isPurchasing || pro.isLoading)

            if pro.isLoading {
                Text("Connecting to App Store…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !pro.productsLoaded && !pro.isLoading {
                Text("Tap the button to retry connecting to the App Store")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let error = pro.purchaseError {
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
        VStack(spacing: 4) {
            Text("Auto-renews unless cancelled at least 24 hours before renewal. Manage in App Store Settings.")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.85)
                .padding(.horizontal, 10)

            HStack(spacing: 12) {
                Button(action: performRestore) {
                    Text("Restore Purchases")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.30, green: 0.10, blue: 0.60))
                }
                Text("·")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.systemGray3))

                Link("Privacy Policy", destination: URL(string: "https://istalin2020.github.io/Claude-Daily-Planner/privacy-policy.html")!)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.30, green: 0.10, blue: 0.60))

                Text("·")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.systemGray3))

                Link("Terms of Use", destination: URL(string: "https://istalin2020.github.io/Claude-Daily-Planner/terms-of-use.html")!)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.30, green: 0.10, blue: 0.60))
            }
            .padding(.bottom, 2)
        }
    }

    // MARK: - Actions
    private func performPurchase() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            if pro.products.isEmpty {
                await pro.loadProducts()
            }
            let product = selectedPlan == .yearly ? pro.yearlyProduct : pro.monthlyProduct
            guard let product else {
                isPurchasing = false
                pro.purchaseError = "Unable to load subscriptions from the App Store. Please check your internet connection and try again."
                return
            }
            let info = await pro.purchase(product)
            isPurchasing = false
            if let info {
                purchasedInfo = info
                showSuccessAlert = true
            }
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
                    VStack(spacing: 1) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.80, blue: 0.0))
                        Text("PRO")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(Color(red: 1.0, green: 0.80, blue: 0.0))
                    }
                } else {
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
