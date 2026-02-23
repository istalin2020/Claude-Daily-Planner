import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showSettings = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // App Header
                AppHeaderView(showSettings: $showSettings)

                // Date Scroller
                DateScrollerView()

                // Section Tab Bar
                SectionTabBarView()

                // Main Content
                ZStack {
                    currentSectionView
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .animation(.easeInOut(duration: 0.25), value: vm.selectedSection)
            }
            .background(Color(.systemGroupedBackground))

            // Confetti burst when all tasks reach 100%
            if showConfetti {
                ConfettiOverlay(isVisible: $showConfetti)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: vm.completionPercent) { newVal in
            if newVal == 100 { showConfetti = true }
        }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch vm.selectedSection {
        case .overview:         OverviewView()
        case .topPriorities:   TopPrioritiesView()
        case .toDoLists:       ToDoListsView()
        case .callsEmails:     CallsEmailsView()
        case .personalTodo:    PersonalTodoView()
        case .healthFitness:   HealthFitnessView()
        case .waterTracker:    WaterTrackerView()
        case .foodTracker:     FoodTrackerView()
        case .dailySchedule:   DailyScheduleView()
        case .appointments:    AppointmentsView()
        case .notes:           NotesView()
        case .notesForTomorrow: NotesForTomorrowView()
        case .expenseTracker:  ExpenseTrackerView()
        case .rateYourDay:     RateYourDayView()
        }
    }
}

// MARK: - App Header
struct AppHeaderView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Binding var showSettings: Bool

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good Morning" }
        if h < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Planner")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(.white)
                Text(greeting + " ✨")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Button(action: { vm.selectToday() }) {
                Text("Today")
                    .font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.25))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.18, blue: 0.78),
                         Color(red: 0.55, green: 0.25, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Section Tab Bar
struct SectionTabBarView: View {
    @EnvironmentObject var vm: PlannerViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppSection.allCases) { section in
                        SectionTabButton(section: section, isSelected: vm.selectedSection == section) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedSection = section
                                proxy.scrollTo(section.id, anchor: .center)
                            }
                        }
                        .id(section.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }
}

struct SectionTabButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(section.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? section.color : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .secondary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Confetti

// Shapes a confetti piece can take
private enum ConfettiShape: CaseIterable {
    case dot, square, diamond, ribbon
}

// Data for one falling confetti piece
private struct ConfettiPiece: Identifiable {
    let id    = UUID()
    let xFrac:    CGFloat   // 0…1 fraction of screen width (starting x)
    let xDrift:   CGFloat   // horizontal displacement added while falling
    let startY:   CGFloat   // starting y (negative = above screen)
    let color:    Color
    let shape:    ConfettiShape
    let size:     CGFloat   // base dimension; views derive w/h from this
    let duration: Double    // fall animation duration
    let delay:    Double    // fall start delay
    let spin:     Double    // total rotation in degrees over the fall

    // 10-colour rainbow palette
    static let palette: [Color] = [
        Color(red: 1.00, green: 0.22, blue: 0.22),  // red
        Color(red: 1.00, green: 0.55, blue: 0.10),  // orange
        Color(red: 1.00, green: 0.88, blue: 0.05),  // yellow
        Color(red: 0.22, green: 0.85, blue: 0.28),  // green
        Color(red: 0.05, green: 0.72, blue: 1.00),  // sky
        Color(red: 0.35, green: 0.20, blue: 0.98),  // indigo
        Color(red: 0.82, green: 0.12, blue: 0.95),  // violet
        Color(red: 1.00, green: 0.22, blue: 0.60),  // pink
        Color(red: 0.10, green: 0.95, blue: 0.80),  // teal
        Color(red: 0.95, green: 1.00, blue: 0.15),  // lime
    ]

    /// Generate a fresh batch of 95 randomised pieces.
    static func makeAll() -> [ConfettiPiece] {
        (0..<95).map { _ in
            ConfettiPiece(
                xFrac:    .random(in: 0.02...0.98),
                xDrift:   .random(in: -32...32),
                startY:   .random(in: -140 ... -6),
                color:    palette.randomElement()!,
                shape:    ConfettiShape.allCases.randomElement()!,
                size:     .random(in: 7...16),
                duration: .random(in: 2.4...4.8),
                delay:    .random(in: 0...1.6),
                spin:     .random(in: 200...560) * (Bool.random() ? 1 : -1)
            )
        }
    }
}

// One animating confetti piece
private struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let screenW: CGFloat
    let screenH: CGFloat

    @State private var fallen = false

    var body: some View {
        pieceShape
            // Rotation animates simultaneously with the fall
            .rotationEffect(.degrees(fallen ? piece.spin : 0))
            .position(
                x: piece.xFrac * screenW + (fallen ? piece.xDrift : 0),
                y: fallen ? screenH + 80 : piece.startY
            )
            // easeIn mimics gravity: slow at top, fast at bottom
            .animation(
                .easeIn(duration: piece.duration).delay(piece.delay),
                value: fallen
            )
            .onAppear { fallen = true }
    }

    @ViewBuilder
    private var pieceShape: some View {
        switch piece.shape {
        case .dot:
            Circle()
                .fill(piece.color)
                .frame(width: piece.size, height: piece.size)
        case .square:
            RoundedRectangle(cornerRadius: 2)
                .fill(piece.color)
                .frame(width: piece.size, height: piece.size * 0.8)
        case .diamond:
            // A square rotated 45° looks like a diamond;
            // the outer view's spin adds on top, making it tumble.
            Rectangle()
                .fill(piece.color)
                .frame(width: piece.size * 0.85, height: piece.size * 0.85)
                .rotationEffect(.degrees(45))
        case .ribbon:
            Capsule()
                .fill(piece.color)
                .frame(width: piece.size * 2.4, height: piece.size * 0.45)
        }
    }
}

// Full-screen overlay: confetti rain + centred success banner
struct ConfettiOverlay: View {
    @Binding var isVisible: Bool

    // Fresh random pieces every time the overlay is created
    @State private var pieces = ConfettiPiece.makeAll()
    @State private var overlayAlpha: Double = 1
    @State private var bannerScale: CGFloat = 0.1
    @State private var bannerAlpha: Double  = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── 1. Confetti rain ──────────────────────────────────
                ForEach(pieces) { piece in
                    ConfettiPieceView(
                        piece: piece,
                        screenW: geo.size.width,
                        screenH: geo.size.height
                    )
                }

                // ── 2. Centred success banner ─────────────────────────
                VStack(spacing: 10) {
                    Text("🎉")
                        .font(.system(size: 68))
                    Text("All Done!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("100% Complete!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.88))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 46)
                .padding(.vertical, 38)
                .background(
                    ZStack {
                        // Deep purple → violet gradient card
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.13, blue: 0.82),
                                Color(red: 0.78, green: 0.10, blue: 0.94),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        // Subtle glassy highlight blobs
                        Circle()
                            .fill(.white.opacity(0.14))
                            .frame(width: 70, height: 70)
                            .offset(x: -55, y: -42)
                        Circle()
                            .fill(.white.opacity(0.09))
                            .frame(width: 48, height: 48)
                            .offset(x: 62, y: 34)
                        Circle()
                            .fill(.white.opacity(0.07))
                            .frame(width: 90, height: 90)
                            .offset(x: 28, y: -66)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .shadow(color: .black.opacity(0.38), radius: 26, x: 0, y: 14)
                .scaleEffect(bannerScale)
                .opacity(bannerAlpha)
            }
        }
        .allowsHitTesting(false)   // taps pass through to the app underneath
        .opacity(overlayAlpha)
        .onAppear {
            // Spring-pop the banner in
            withAnimation(.spring(response: 0.48, dampingFraction: 0.66)) {
                bannerScale = 1.0
                bannerAlpha = 1.0
            }
            // Fade banner out after 2.4 s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeOut(duration: 0.65)) {
                    bannerAlpha = 0
                    bannerScale = 1.18
                }
            }
            // Fade the whole overlay out
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                withAnimation(.easeOut(duration: 1.0)) {
                    overlayAlpha = 0
                }
            }
            // Remove from the hierarchy
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.9) {
                isVisible = false
            }
        }
    }
}
