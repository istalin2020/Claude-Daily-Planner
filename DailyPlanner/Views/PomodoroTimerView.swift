import SwiftUI
import UserNotifications

// MARK: - Pomodoro Timer ViewModel
class PomodoroTimer: ObservableObject {
    enum Phase { case work, shortBreak, longBreak, idle }

    @Published var phase: Phase = .idle
    @Published var timeRemaining: Int = 25 * 60
    @Published var currentSession = 0
    @Published var isRunning = false
    @Published var linkedTask = ""

    private var timer: Timer?
    var workDuration   = 25 * 60
    var shortBreak     = 5  * 60
    var longBreak      = 15 * 60
    let sessionsBeforeLong = 4

    var progress: Double {
        let total: Int
        switch phase {
        case .work:       total = workDuration
        case .shortBreak: total = shortBreak
        case .longBreak:  total = longBreak
        case .idle:       return 0
        }
        return 1 - Double(timeRemaining) / Double(total)
    }

    var timeString: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    var phaseLabel: String {
        switch phase {
        case .work:       return "Focus Time"
        case .shortBreak: return "Short Break"
        case .longBreak:  return "Long Break"
        case .idle:       return "Ready to Focus"
        }
    }

    var phaseColor: Color {
        switch phase {
        case .work:       return Color(red: 0.9, green: 0.2, blue: 0.3)
        case .shortBreak: return Color(red: 0.1, green: 0.65, blue: 0.35)
        case .longBreak:  return Color(red: 0.3, green: 0.5, blue: 0.95)
        case .idle:       return Color(red: 0.45, green: 0.25, blue: 0.85)
        }
    }

    func start() {
        if phase == .idle { phase = .work; timeRemaining = workDuration }
        isRunning = true
        scheduleNotification()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func reset() {
        pause()
        phase = .idle
        timeRemaining = workDuration
        currentSession = 0
        linkedTask = ""
    }

    func skip() {
        pause()
        advance()
        start()
    }

    private func tick() {
        guard timeRemaining > 0 else { advance(); return }
        timeRemaining -= 1
    }

    private func advance() {
        switch phase {
        case .work:
            currentSession += 1
            if currentSession % sessionsBeforeLong == 0 {
                phase = .longBreak; timeRemaining = longBreak
            } else {
                phase = .shortBreak; timeRemaining = shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .work; timeRemaining = workDuration
        case .idle:
            phase = .work; timeRemaining = workDuration
        }
        scheduleNotification()
    }

    private func scheduleNotification() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = phaseLabel + " complete!"
        content.body = phase == .work ? "Time for a break." : "Back to focus!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timeRemaining), repeats: false)
        let req = UNNotificationRequest(identifier: "pomodoro", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}

// MARK: - Pomodoro View
struct PomodoroTimerView: View {
    @StateObject private var pomodoro = PomodoroTimer()
    @State private var showSettings = false
    @State private var showIntro = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {

                    // Intro Card
                    if showIntro {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
                                    Text("What is the Pomodoro Technique?")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Spacer()
                                Button {
                                    withAnimation { showIntro = false }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }
                            .padding(.bottom, 10)

                            Text("A proven time-management method that breaks your work into focused 25-minute sessions (called \"Pomodoros\") separated by short breaks. This rhythm trains your brain to focus deeply while preventing mental fatigue.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider().padding(.vertical, 10)

                            Text("How it works")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.bottom, 6)

                            VStack(alignment: .leading, spacing: 6) {
                                IntroStep(number: "1", text: "Pick a task you want to work on")
                                IntroStep(number: "2", text: "Work focused for 25 minutes — no distractions")
                                IntroStep(number: "3", text: "Take a 5-minute short break")
                                IntroStep(number: "4", text: "Repeat. After 4 sessions, take a 15-minute long break")
                            }

                            Divider().padding(.vertical, 10)

                            Text("Example")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.bottom, 6)

                            Text("You need to write a report. Start a Pomodoro, write for 25 minutes without checking your phone, then take a 5-min break to stretch. After 4 rounds (~2 hours), you'll have completed a solid chunk of work with a fresh mind.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider().padding(.vertical, 10)

                            HStack(spacing: 16) {
                                BenefitBadge(icon: "brain.head.profile", text: "Deep Focus")
                                BenefitBadge(icon: "battery.100", text: "Prevents Burnout")
                                BenefitBadge(icon: "chart.line.uptrend.xyaxis", text: "Boosts Output")
                            }
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // Session dots
                    HStack(spacing: 8) {
                        ForEach(0..<4) { i in
                            Circle()
                                .fill(i < pomodoro.currentSession % 4
                                      ? pomodoro.phaseColor : Color.secondary.opacity(0.2))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 8)

                    // Phase label
                    Text(pomodoro.phaseLabel)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(pomodoro.phaseColor)

                    // Ring + time
                    ZStack {
                        Circle()
                            .stroke(pomodoro.phaseColor.opacity(0.15), lineWidth: 16)
                        Circle()
                            .trim(from: 0, to: pomodoro.progress)
                            .stroke(pomodoro.phaseColor,
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: pomodoro.progress)
                        VStack(spacing: 4) {
                            Text(pomodoro.timeString)
                                .font(.system(size: 52, weight: .thin, design: .rounded))
                            Text("Session \(pomodoro.currentSession + 1)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 240, height: 240)

                    // Task link
                    HStack {
                        Image(systemName: "checkmark.circle").foregroundColor(.secondary)
                        TextField("Link to a task (optional)", text: $pomodoro.linkedTask)
                            .font(.system(size: 13))
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, 32)

                    // Controls
                    HStack(spacing: 24) {
                        Button(action: pomodoro.reset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                                .frame(width: 48, height: 48)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                        }

                        Button(action: pomodoro.isRunning ? pomodoro.pause : pomodoro.start) {
                            Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                                .frame(width: 72, height: 72)
                                .background(pomodoro.phaseColor)
                                .clipShape(Circle())
                                .shadow(color: pomodoro.phaseColor.opacity(0.4), radius: 10, y: 4)
                        }

                        Button(action: pomodoro.skip) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                                .frame(width: 48, height: 48)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                    }

                    // Stats bar
                    HStack(spacing: 0) {
                        StatPill(label: "Sessions", value: "\(pomodoro.currentSession)")
                        StatPill(label: "Focus Time", value: "\(pomodoro.currentSession * 25) min")
                        StatPill(label: "Breaks", value: "\(max(0, pomodoro.currentSession - 1))")
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                PomodoroSettingsSheet(pomodoro: pomodoro)
            }
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .bold))
            Text(label).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Intro Helper Views
struct IntroStep: View {
    let number: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.9, green: 0.3, blue: 0.5).opacity(0.15))
                    .frame(width: 22, height: 22)
                Text(number)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct BenefitBadge: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(red: 0.9, green: 0.3, blue: 0.5).opacity(0.07))
        .cornerRadius(8)
    }
}

struct PomodoroSettingsSheet: View {
    @ObservedObject var pomodoro: PomodoroTimer
    @Environment(\.dismiss) var dismiss
    @State private var workMins = 25
    @State private var shortMins = 5
    @State private var longMins = 15

    var body: some View {
        NavigationView {
            Form {
                Section("Durations") {
                    Stepper("Focus: \(workMins) min",  value: $workMins,  in: 5...90, step: 5)
                    Stepper("Short Break: \(shortMins) min", value: $shortMins, in: 1...30, step: 1)
                    Stepper("Long Break: \(longMins) min",  value: $longMins,  in: 5...60, step: 5)
                }
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        pomodoro.workDuration = workMins * 60
                        pomodoro.shortBreak   = shortMins * 60
                        pomodoro.longBreak    = longMins * 60
                        pomodoro.reset()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                workMins  = pomodoro.workDuration / 60
                shortMins = pomodoro.shortBreak   / 60
                longMins  = pomodoro.longBreak    / 60
            }
        }
    }
}
