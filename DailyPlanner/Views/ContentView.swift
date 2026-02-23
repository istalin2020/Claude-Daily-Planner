import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showSettings = false

    var body: some View {
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
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

// MARK: - Party Popper

// ── Particle shapes ───────────────────────────────────────────────────────────
private enum PPShape: CaseIterable {
    case dot, square, diamond, ribbon, triangle
}

// ── Data for a single burst particle ─────────────────────────────────────────
private struct PPParticle: Identifiable {
    let id          = UUID()
    let angle:       Double    // launch angle in radians (0=right, -π/2=up)
    let burstDist:   CGFloat   // distance from centre reached during burst
    let fallDrop:    CGFloat   // additional downward travel during fall
    let fallDrift:   CGFloat   // extra horizontal drift during fall
    let color:       Color
    let shape:       PPShape
    let size:        CGFloat
    let spin:        Double    // total rotation over full animation (degrees)
    let fallDuration: Double

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

    /// 90 freshly-randomised particles per burst.
    /// Angles biased toward upper half (-210° … +30°) so most confetti
    /// shoots upward, exactly like a real party popper.
    static func makeAll() -> [PPParticle] {
        (0..<90).map { _ in
            let deg = Double.random(in: -210...30)
            return PPParticle(
                angle:        deg * .pi / 180,
                burstDist:    .random(in: 65...185),
                fallDrop:     .random(in: 480...920),
                fallDrift:    .random(in: -45...45),
                color:        palette.randomElement()!,
                shape:        PPShape.allCases.randomElement()!,
                size:         .random(in: 7...16),
                spin:         .random(in: 200...540) * (Bool.random() ? 1 : -1),
                fallDuration: .random(in: 1.4...2.8)
            )
        }
    }
}

// ── Three-phase animation state ───────────────────────────────────────────────
private enum PPPhase: Equatable { case hidden, bursting, falling }

// ── One animated particle view ────────────────────────────────────────────────
private struct PPParticleView: View {
    let particle: PPParticle
    let centre:   CGPoint
    let phase:    PPPhase

    // Pre-computed burst landing point
    private var bx: CGFloat { CGFloat(cos(particle.angle)) * particle.burstDist }
    private var by: CGFloat { CGFloat(sin(particle.angle)) * particle.burstDist }

    var body: some View {
        particleShape
            .offset(currentOffset)
            .rotationEffect(.degrees(currentRotation))
            .opacity(currentOpacity)
            .position(x: centre.x, y: centre.y)
            // Whole animation driven by a single value change on `phase`
            .animation(currentAnimation, value: phase)
    }

    private var currentOffset: CGSize {
        switch phase {
        case .hidden:   return .zero
        case .bursting: return CGSize(width: bx, height: by)
        case .falling:  return CGSize(width: bx + particle.fallDrift,
                                      height: by + particle.fallDrop)
        }
    }

    private var currentOpacity: Double {
        switch phase {
        case .hidden:   return 0
        case .bursting: return 1
        case .falling:  return 0
        }
    }

    private var currentRotation: Double {
        switch phase {
        case .hidden:   return 0
        case .bursting: return particle.spin * 0.3
        case .falling:  return particle.spin
        }
    }

    private var currentAnimation: Animation? {
        switch phase {
        case .hidden:   return nil
        case .bursting: return .spring(response: 0.44, dampingFraction: 0.62)
        case .falling:  return .easeIn(duration: particle.fallDuration)
        }
    }

    @ViewBuilder
    private var particleShape: some View {
        switch particle.shape {
        case .dot:
            Circle().fill(particle.color)
                .frame(width: particle.size, height: particle.size)
        case .square:
            RoundedRectangle(cornerRadius: 2).fill(particle.color)
                .frame(width: particle.size, height: particle.size * 0.8)
        case .diamond:
            // Inner 45° rotation makes the diamond shape;
            // the outer `spin` adds tumbling on top.
            Rectangle().fill(particle.color)
                .frame(width: particle.size * 0.85, height: particle.size * 0.85)
                .rotationEffect(.degrees(45))
        case .ribbon:
            Capsule().fill(particle.color)
                .frame(width: particle.size * 2.2, height: particle.size * 0.44)
        case .triangle:
            PPTriangle().fill(particle.color)
                .frame(width: particle.size, height: particle.size * 0.88)
        }
    }
}

// ── Triangle shape ────────────────────────────────────────────────────────────
private struct PPTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to:    CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// ── Full-screen overlay: 🎉 flies in → bursts → colourful confetti rains ──────
struct PartyPopperOverlay: View {
    @Binding var isVisible: Bool

    // Fresh random particles generated each time the view is created
    @State private var particles   = PPParticle.makeAll()
    @State private var phase:      PPPhase  = .hidden
    @State private var overlayAlpha: Double = 1

    // Party-popper emoji animation state
    // Starts at (900, 900) offset so it is far off-screen before onAppear fires
    @State private var popperOffset:   CGSize  = CGSize(width: 900, height: 900)
    @State private var popperRotation: Double  = 45
    @State private var popperScale:    CGFloat = 1
    @State private var popperOpacity:  Double  = 1

    // Flash-ring state (expands outward at the moment of the "pop")
    @State private var flashScale:   CGFloat = 0.1
    @State private var flashOpacity: Double  = 0

    var body: some View {
        GeometryReader { geo in
            let sw     = geo.size.width
            let sh     = geo.size.height
            let centre = CGPoint(x: sw / 2, y: sh / 2)

            ZStack {
                // ── 1. Burst particles (behind popper so popper stays on top) ──
                ForEach(particles) { p in
                    PPParticleView(particle: p, centre: centre, phase: phase)
                }

                // ── 2. Expanding flash ring at the pop moment ──────────────────
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 5
                    )
                    .frame(width: 88, height: 88)
                    .scaleEffect(flashScale)
                    .opacity(flashOpacity)
                    .position(centre)

                // ── 3. The 🎉 party-popper emoji ──────────────────────────────
                Text("🎉")
                    .font(.system(size: 76))
                    .scaleEffect(popperScale)
                    .rotationEffect(.degrees(popperRotation))
                    .opacity(popperOpacity)
                    .offset(popperOffset)     // relative to centre below
                    .position(centre)
            }
            .onAppear {
                // ── Phase 0 → 1: reposition off-screen (bottom-right corner) ──
                // Using sw/sh captured here so the start point is just outside
                // the visible area regardless of device size.
                popperOffset = CGSize(width: sw * 0.5 + 70, height: sh * 0.5 + 70)

                // ── Phase 1: spring-fly to centre ──────────────────────────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.spring(response: 0.56, dampingFraction: 0.68)) {
                        popperOffset   = .zero
                        popperRotation = -22   // tilt: opening faces upper-right
                    }
                }

                // ── Phase 2 (t≈0.70s): pop! scale punch + flash ring ───────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
                    withAnimation(.easeOut(duration: 0.14)) { popperScale = 1.55 }
                    flashOpacity = 0.95
                    withAnimation(.easeOut(duration: 0.60)) {
                        flashScale   = 3.4
                        flashOpacity = 0
                    }
                }
                // Popper shrinks to nothing right after the punch peak
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.84) {
                    withAnimation(.easeIn(duration: 0.20)) {
                        popperScale   = 0
                        popperOpacity = 0
                    }
                }

                // ── Phase 3 (t≈0.73s): confetti burst outward ─────────────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.73) {
                    phase = .bursting
                }
                // ── Phase 4 (t≈1.22s): confetti falls with gravity ────────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.22) {
                    phase = .falling
                }

                // ── Fade and dismiss ───────────────────────────────────────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 1.0)) { overlayAlpha = 0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
                    isVisible = false
                }
            }
        }
        .allowsHitTesting(false)   // taps pass straight through to the app
        .opacity(overlayAlpha)
    }
}
