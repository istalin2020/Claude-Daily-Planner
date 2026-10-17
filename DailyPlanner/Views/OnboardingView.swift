import SwiftUI

// MARK: - First-launch tour

/// Three swipeable highlights shown the first time the app opens — To-Do,
/// Finance and Health — with Skip on every page. The Finance page can link
/// Gmail right there, since that is what fills the finance and subscription
/// trackers on their own.
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
             subtitle: "Link Gmail and your bank alerts fill the tracker on their own.",
             symbol: "chart.bar.fill",
             accent: Color(red: 0.18, green: 0.83, blue: 0.48),
             accentDeep: Color(red: 0.07, green: 0.66, blue: 0.35),
             wash: Color(red: 0.87, green: 0.97, blue: 0.91),
             points: [("envelope.open.fill", "Card and bank alerts become expenses, by category"),
                      ("repeat.circle.fill", "Every subscription and its next renewal"),
                      ("lock.fill", "Read-only access, processed on your iPhone")]),
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
        .background(
            LinearGradient(colors: [current.wash.opacity(0.9), Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .animation(.easeInOut, value: page)
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

                if p.id == 1 {
                    ConnectGmailCard(compact: true)
                        .padding(.horizontal, 24)
                }
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
                Text("Read-only: the app reads bank alerts and receipts to fill your trackers. It never sends, changes or deletes email, and what it reads is processed on your iPhone.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
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
