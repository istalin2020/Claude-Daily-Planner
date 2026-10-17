import SwiftUI

// MARK: - First-launch tour

/// Three swipeable highlights shown the first time the app opens — To-Do,
/// Finance and Health — with Skip on every page. It only shows what the app
/// does: nothing is connected or asked for here. Gmail is offered when the
/// user first opens the Finance Tracker, Apple Health when they tap Connect.
struct OnboardingView: View {
    @EnvironmentObject var vm: PlannerViewModel
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let symbol: String
        let accent: Color
        let accentDeep: Color
        let wash: Color
        let points: [(String, String)]
    }

    private let pages: [Page] = [
        Page(id: 0,
             title: "Plan your day, your way",
             subtitle: "Every task in one place, sorted the way you think.",
             symbol: "checklist",
             accent: Color(red: 0.24, green: 0.55, blue: 1.0),
             accentDeep: Color(red: 0.12, green: 0.37, blue: 0.88),
             wash: Color(red: 0.89, green: 0.93, blue: 1.0),
             points: [("star.fill", "Top priorities for what matters most today"),
                      ("list.bullet.clipboard.fill", "To-do lists, calls & emails and personal tasks"),
                      ("arrow.uturn.forward", "Unfinished tasks roll over to the next day")]),
        Page(id: 1,
             title: "Your money, tracked for you",
             subtitle: "See where every rupee, riyal or dollar goes — month by month.",
             symbol: "chart.bar.fill",
             accent: Color(red: 0.18, green: 0.83, blue: 0.48),
             accentDeep: Color(red: 0.07, green: 0.66, blue: 0.35),
             wash: Color(red: 0.87, green: 0.97, blue: 0.91),
             points: [("tag.fill", "Income, expenses and savings by category"),
                      ("repeat.circle.fill", "Every subscription and its next renewal"),
                      ("chart.pie.fill", "Budgets and spending trends at a glance")]),
        Page(id: 2,
             title: "Feel your best, every day",
             subtitle: "Steps, food, water, sleep and medicines at a glance.",
             symbol: "heart.fill",
             accent: Color(red: 1.0, green: 0.36, blue: 0.48),
             accentDeep: Color(red: 0.91, green: 0.20, blue: 0.35),
             wash: Color(red: 1.0, green: 0.90, blue: 0.92),
             points: [("figure.walk", "Steps and workouts from Apple Health"),
                      ("camera.fill", "Snap your plate to log calories and nutrition"),
                      ("drop.fill", "Water, sleep and medication reminders")]),
    ]

    var body: some View {
        let current = pages[page]

        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("Skip") { onFinish() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
            }
            .frame(height: 50)

            TabView(selection: $page) {
                ForEach(pages) { p in
                    pageView(p).tag(p.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Dots
            HStack(spacing: 8) {
                ForEach(pages) { p in
                    Capsule()
                        .fill(p.id == page ? current.accent : Color.secondary.opacity(0.25))
                        .frame(width: p.id == page ? 24 : 8, height: 8)
                }
            }
            .animation(.snappy, value: page)
            .padding(.bottom, 20)

            Button {
                if page < pages.count - 1 {
                    withAnimation(.easeInOut) { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get Started")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(LinearGradient(
                        colors: [current.accent, current.accentDeep],
                        startPoint: .leading, endPoint: .trailing)))
                    .shadow(color: current.accent.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(TilePressStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        // Solid: the home screen must not show through behind the tour.
        .background(
            ZStack {
                Color(.systemBackground)
                LinearGradient(colors: [current.wash, Color(.systemBackground)],
                               startPoint: .top, endPoint: .bottom)
                    .animation(.easeInOut, value: page)
            }
            .ignoresSafeArea()
        )
    }

    private func pageView(_ p: Page) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                illustration(p)
                    .padding(.top, 10)

                VStack(spacing: 8) {
                    Text(p.title)
                        .font(.system(size: 28, weight: .heavy))
                        .multilineTextAlignment(.center)
                    Text(p.subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(p.points.enumerated()), id: \.offset) { _, point in
                        HStack(spacing: 14) {
                            Image(systemName: point.0)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(p.accentDeep)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(p.accent.opacity(0.15)))
                            Text(point.1)
                                .font(.system(size: 15, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 32)

            }
            .padding(.bottom, 12)
        }
    }

    private func illustration(_ p: Page) -> some View {
        ZStack {
            Circle()
                .fill(p.accent.opacity(0.12))
                .frame(width: 210, height: 210)
            Circle()
                .fill(p.accent.opacity(0.18))
                .frame(width: 150, height: 150)
            Circle()
                .fill(LinearGradient(colors: [p.accent, p.accentDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 100)
                .shadow(color: p.accent.opacity(0.45), radius: 16, y: 8)
            Image(systemName: p.symbol)
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)

            // Small satellites from the page's own points.
            ForEach(Array(p.points.enumerated()), id: \.offset) { i, point in
                Image(systemName: point.0)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(p.accentDeep)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(.systemBackground)))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    .offset(x: [-92.0, 96.0, 70.0][i % 3], y: [-52.0, -18.0, 78.0][i % 3])
            }
        }
        .frame(height: 230)
    }
}

// MARK: - Gmail privacy note

/// What happens to email data, shown wherever Gmail sync starts. Worded to
/// stay true with iCloud Sync on (the user's own iCloud) and with the
/// Sharing feature (only what the user chooses to share).
struct GmailPrivacyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your data stays with you")
                    .font(.system(size: 13, weight: .bold))
                Text("Emails are read on this iPhone only. The transactions and subscriptions found are stored on this device (and in your own iCloud, if iCloud Sync is on). Nothing is sent to the app developer or shared with other users — unless you choose to share a list yourself.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.green.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Connect Gmail

/// Links the user's Gmail account, read-only. Used on the tour's Finance page
/// and on the Subscriptions page before Gmail is linked — any Google account
/// can sign in here; nothing about it is tied to one person.
struct ConnectGmailCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    var compact: Bool = false
    /// Runs once the account is linked, e.g. to start a scan straight away.
    var onConnected: (() -> Void)? = nil

    @State private var working = false
    @State private var errorText: String? = nil

    private var connected: String { vm.settings.gmailConnectedEmail }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: connect) {
                HStack(spacing: 12) {
                    Image(systemName: connected.isEmpty ? "envelope.fill" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 11)
                            .fill(connected.isEmpty ? Color(red: 0.86, green: 0.27, blue: 0.22) : .green))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connected.isEmpty ? (working ? "Connecting…" : "Connect Gmail") : "Gmail connected")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(connected.isEmpty
                             ? "Bank alerts and receipts fill your finance and subscription trackers"
                             : connected)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    if working {
                        ProgressView()
                    } else if connected.isEmpty {
                        Image(systemName: "arrow.right")
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
            .disabled(working || !connected.isEmpty)

            if let errorText = errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            } else if !compact && connected.isEmpty {
                GmailPrivacyNote()
            }
        }
    }

    private func connect() {
        guard connected.isEmpty, !working else { return }
        errorText = nil
        working = true
        Task { @MainActor in
            do {
                let email = try await GmailSyncService.shared.connect()
                vm.setGmailConnected(email: email)
                onConnected?()
            } catch GmailSyncError.cancelled {
                // Closed the Google page — nothing to report.
            } catch {
                errorText = (error as? GmailSyncError)?.errorDescription ?? error.localizedDescription
            }
            working = false
        }
    }
}

// MARK: - Finance Tracker guides

/// Short guides shown at the moment the user reaches for a feature — never on
/// simply opening the Finance Tracker, where a Gmail prompt felt alarming.
///   • `.gmail`  — the first tap on "Expense Sync from Gmail": what it does
///                  and where the data stays, then on to the sync.
///   • `.adding` — the first tap on Add Income / Add Expense: adding by hand,
///                  and fixing things in Transactions, then on to the form.
struct FinanceGuideOverlay: View {
    enum Guide { case gmail, adding }

    let guide: Guide
    let isPro: Bool
    /// Carries on with what the user tapped — the Gmail sync (or the PRO
    /// page for free users), or the add form.
    let onContinue: () -> Void
    /// Closes without carrying on.
    let onCancel: () -> Void

    @State private var step = 0

    private struct Tip {
        let icon: String
        let color: Color
        let title: String
        let text: String
    }

    private var tips: [Tip] {
        switch guide {
        case .gmail:
            return [Tip(icon: "envelope.badge.fill", color: Color(red: 0.86, green: 0.27, blue: 0.22),
                        title: "Sync expenses from Gmail",
                        text: "Connect Gmail once and the app reads your bank and card alert emails, then turns each one into an expense for you to review before it's added. It also finds your subscriptions and their renewal dates. Access is read-only, and everything it finds is stored only on this device — never shared with other users or the app developer.")]
        case .adding:
            return [Tip(icon: "plus.circle.fill", color: Color(red: 0.1, green: 0.65, blue: 0.35),
                        title: "Add anything yourself",
                        text: "Use Add Income and Add Expense for cash, transfers or anything without a bank alert. Pick a category so your breakdown and budgets stay accurate."),
                    Tip(icon: "list.bullet.rectangle.portrait.fill", color: Color(red: 0.25, green: 0.45, blue: 0.95),
                        title: "Review and fix in one place",
                        text: "Tap Transactions to see every entry for the month. Filter by category, and edit or delete any entry — the totals and the chart update straight away.")]
        }
    }

    var body: some View {
        let all = tips
        let tip = all[min(step, all.count - 1)]
        let isLast = step >= all.count - 1

        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { }   // keep taps off the page behind

            VStack(spacing: 16) {
                if all.count > 1 {
                    HStack {
                        Text("\(step + 1) of \(all.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                Image(systemName: tip.icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Circle().fill(tip.color))
                    .shadow(color: tip.color.opacity(0.35), radius: 10, y: 4)

                Text(tip.title)
                    .font(.system(size: 20, weight: .heavy))
                    .multilineTextAlignment(.center)

                Text(tip.text)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if isLast { onContinue() } else { withAnimation(.easeInOut(duration: 0.2)) { step += 1 } }
                } label: {
                    HStack(spacing: 6) {
                        Text(isLast ? (guide == .gmail ? "Continue to Gmail sync" : "Got it") : "Next")
                        if guide == .gmail && !isPro {
                            Text("PRO")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.3)))
                        }
                        if guide == .gmail { Image(systemName: "arrow.right") }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(tip.color))
                }
                .buttonStyle(TilePressStyle())

                if guide == .gmail {
                    Button { onCancel() } label: {
                        Text("Not now")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(tip.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(tip.color.opacity(0.12)))
                    }
                    .buttonStyle(TilePressStyle())
                }

                if all.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<all.count, id: \.self) { i in
                            Capsule()
                                .fill(i == step ? tip.color : Color.secondary.opacity(0.25))
                                .frame(width: i == step ? 18 : 6, height: 6)
                        }
                    }
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 26).fill(Color(.systemBackground)))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            .padding(.horizontal, 24)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
}
