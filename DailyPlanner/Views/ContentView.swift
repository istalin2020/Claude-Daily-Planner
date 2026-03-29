import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @State private var showSettings = false
    @State private var showSearch   = false
    @State private var showUpgrade  = false

    var body: some View {
        VStack(spacing: 0) {
            // App Header
            AppHeaderView(showSettings: $showSettings, showSearch: $showSearch)

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
            SettingsView().environmentObject(pro)
        }
        .sheet(isPresented: $showSearch) {
            if pro.isPro {
                SearchView().environmentObject(vm)
            } else {
                ProUpgradeView().environmentObject(pro)
            }
        }
        .sheet(isPresented: $showUpgrade) {
            ProUpgradeView().environmentObject(pro)
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
        case .expenseTracker:  ExpenseTrackerView()
        case .rateYourDay:     RateYourDayView()
        case .habits:
            ProGate(featureName: "Habit Tracker", featureIcon: "checkmark.circle.fill") {
                HabitTrackerView()
            }
        case .sleepTracker:
            ProGate(featureName: "Sleep Tracker", featureIcon: "moon.zzz.fill") {
                SleepTrackerView()
            }
        case .medications:
            ProGate(featureName: "Medication Reminders", featureIcon: "pill.fill") {
                MedicationTrackerView()
            }
        }
    }
}

// MARK: - App Header
struct AppHeaderView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    @Binding var showSettings: Bool
    @Binding var showSearch: Bool

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
            // Crown / PRO button
            CrownButton().environmentObject(pro)

            Button(action: { showSearch = true }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.leading, 4)
            }
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.leading, 4)
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
            .onChange(of: vm.selectedSection) { _, newSection in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newSection.id, anchor: .center)
                }
            }
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
    case dot, square, diamond, ribbon, triangle, star
}

// ── Data for a single burst particle ─────────────────────────────────────────
private struct PPParticle: Identifiable {
    let id           = UUID()
    let angle:        Double    // launch angle in radians (0=right, -π/2=up)
    let burstDist:    CGFloat   // distance from centre reached during burst
    let fallDrop:     CGFloat   // additional downward travel during fall
    let fallDrift:    CGFloat   // extra horizontal drift during fall
    let color:        Color
    let shape:        PPShape
    let size:         CGFloat
    let spin:         Double    // total rotation over full animation (degrees)
    let fallDuration: Double
    let opacity:      Double    // per-particle base opacity for variety

    // 12-colour vivid rainbow palette
    static let palette: [Color] = [
        Color(red: 1.00, green: 0.18, blue: 0.18),  // red
        Color(red: 1.00, green: 0.52, blue: 0.05),  // orange
        Color(red: 1.00, green: 0.90, blue: 0.00),  // yellow
        Color(red: 0.18, green: 0.88, blue: 0.22),  // green
        Color(red: 0.05, green: 0.75, blue: 1.00),  // sky
        Color(red: 0.30, green: 0.15, blue: 1.00),  // indigo
        Color(red: 0.85, green: 0.10, blue: 0.98),  // violet
        Color(red: 1.00, green: 0.20, blue: 0.58),  // hot-pink
        Color(red: 0.08, green: 0.98, blue: 0.82),  // teal
        Color(red: 0.95, green: 1.00, blue: 0.10),  // lime
        Color(red: 1.00, green: 0.78, blue: 0.90),  // blush
        Color(red: 0.55, green: 0.92, blue: 1.00),  // ice-blue
    ]

    /// 120 freshly-randomised particles per burst.
    /// Angles biased toward upper half (-220° … +40°) so confetti
    /// shoots upward and to the sides, just like a real party popper.
    static func makeAll() -> [PPParticle] {
        (0..<120).map { _ in
            let deg = Double.random(in: -220...40)
            return PPParticle(
                angle:        deg * .pi / 180,
                burstDist:    .random(in: 70...220),
                fallDrop:     .random(in: 500...1000),
                fallDrift:    .random(in: -60...60),
                color:        palette.randomElement()!,
                shape:        PPShape.allCases.randomElement()!,
                size:         .random(in: 8...18),
                spin:         .random(in: 240...600) * (Bool.random() ? 1 : -1),
                fallDuration: .random(in: 1.5...3.0),
                opacity:      .random(in: 0.80...1.00)
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
        case .bursting: return particle.opacity
        case .falling:  return 0
        }
    }

    private var currentRotation: Double {
        switch phase {
        case .hidden:   return 0
        case .bursting: return particle.spin * 0.35
        case .falling:  return particle.spin
        }
    }

    private var currentAnimation: Animation? {
        switch phase {
        case .hidden:   return nil
        case .bursting: return .spring(response: 0.42, dampingFraction: 0.58)
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
                .frame(width: particle.size, height: particle.size * 0.75)
        case .diamond:
            Rectangle().fill(particle.color)
                .frame(width: particle.size * 0.85, height: particle.size * 0.85)
                .rotationEffect(.degrees(45))
        case .ribbon:
            Capsule().fill(particle.color)
                .frame(width: particle.size * 2.6, height: particle.size * 0.40)
        case .triangle:
            PPTriangle().fill(particle.color)
                .frame(width: particle.size, height: particle.size * 0.88)
        case .star:
            PPStar().fill(particle.color)
                .frame(width: particle.size, height: particle.size)
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

// ── 4-pointed star shape ──────────────────────────────────────────────────────
private struct PPStar: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var path = Path()
        for i in 0..<8 {
            let angle = (Double(i) * .pi / 4) - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let x = cx + CGFloat(cos(angle)) * r
            let y = cy + CGFloat(sin(angle)) * r
            i == 0 ? path.move(to: CGPoint(x: x, y: y))
                   : path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}

// ── Full-screen overlay: 🎉 rockets in from bottom-right → bursts → confetti rains ──
struct PartyPopperOverlay: View {
    @Binding var isVisible: Bool

    @State private var particles     = PPParticle.makeAll()
    @State private var phase:        PPPhase  = .hidden
    @State private var overlayAlpha: Double   = 1

    // 🎉 emoji travel state — starts far off-screen at bottom-right
    @State private var popperOffset:   CGSize  = CGSize(width: 900, height: 900)
    @State private var popperRotation: Double  = 50   // tilted, opening faces up-right
    @State private var popperScale:    CGFloat = 1
    @State private var popperOpacity:  Double  = 1

    // Flash ring that expands at the "pop" moment
    @State private var flashScale:   CGFloat = 0.1
    @State private var flashOpacity: Double  = 0

    var body: some View {
        GeometryReader { geo in
            let sw     = geo.size.width
            let sh     = geo.size.height
            // Burst centre: upper-centre of screen so confetti has room to fall
            let centre = CGPoint(x: sw / 2, y: sh * 0.42)

            ZStack {
                // ── 1. Colourful burst particles ───────────────────────────────
                ForEach(particles) { p in
                    PPParticleView(particle: p, centre: centre, phase: phase)
                }

                // ── 2. Expanding rainbow flash ring ────────────────────────────
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green,
                                     .cyan, .blue, .purple, .pink, .red],
                            center: .center
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(flashScale)
                    .opacity(flashOpacity)
                    .position(centre)

                // ── 3. 🎉 emoji rockets from bottom-right corner to centre ─────
                Text("🎉")
                    .font(.system(size: 82))
                    .scaleEffect(popperScale)
                    .rotationEffect(.degrees(popperRotation))
                    .opacity(popperOpacity)
                    .offset(popperOffset)   // relative to the .position below
                    .position(centre)
            }
            .onAppear {
                // Place emoji at bottom-right corner, just outside the screen.
                // offset is relative to `centre`, so add half the screen dims.
                popperOffset = CGSize(width: sw * 0.52 + 80, height: sh * 0.58 + 80)

                // ── Phase 1 (t=0.05s): rocket to centre with a spring ──────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.65)) {
                        popperOffset   = .zero
                        popperRotation = -20   // tilt so opening faces upper-right
                    }
                }

                // ── Phase 2 (t=0.68s): POP — scale punch + rainbow flash ───────
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
                    withAnimation(.easeOut(duration: 0.12)) { popperScale = 1.65 }
                    flashOpacity = 1.0
                    withAnimation(.easeOut(duration: 0.65)) {
                        flashScale   = 4.0
                        flashOpacity = 0
                    }
                }

                // Emoji pops then shrinks to nothing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
                    withAnimation(.easeIn(duration: 0.18)) {
                        popperScale   = 0
                        popperOpacity = 0
                    }
                }

                // ── Phase 3 (t=0.72s): confetti bursts outward ────────────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                    phase = .bursting
                }

                // ── Phase 4 (t=1.20s): confetti falls with gravity ─────────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) {
                    phase = .falling
                }

                // ── Fade overlay and dismiss ───────────────────────────────────
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                    withAnimation(.easeOut(duration: 1.1)) { overlayAlpha = 0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
                    isVisible = false
                }
            }
        }
        .allowsHitTesting(false)   // taps pass straight through to the app
        .opacity(overlayAlpha)
    }
}
