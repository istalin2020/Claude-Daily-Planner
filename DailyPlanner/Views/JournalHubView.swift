import SwiftUI

// MARK: - Notes & Journal page
//
// Three cards, all usable in place:
//   • Today's Notes — write straight into the box (saved as you type,
//     up to 2,000 characters). Edit focuses it; Done puts the keyboard away.
//   • Writing Prompts — five prompts; New Prompts shuffles them, and tapping
//     one adds it to the notes to answer.
//   • Rate Your Day — Productivity, Mood and Health stars with the overall
//     score.

private func jc(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r / 255, green: g / 255, blue: b / 255)
}

private enum JournalStyle {
    static let notes   = jc(205, 130, 50)
    static let prompts = jc(240, 180, 20)
    static let rate    = jc(232, 60, 112)
    static let card    = Color.adaptive(light: .white, dark: UIColor(white: 0.13, alpha: 1))
    static let inner   = Color.adaptive(light: UIColor(white: 1, alpha: 0.9),
                                        dark: UIColor(white: 1, alpha: 0.06))
    static let limit   = 2000
}

struct JournalHubView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var text = ""
    @FocusState private var writing: Bool
    @State private var promptSeed = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    notesCard.id("notes")
                    promptsCard
                    rateCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: writing) { _, on in
                if on { withAnimation { proxy.scrollTo("notes", anchor: .top) } }
            }
        }
        .onAppear { text = vm.currentEntry.notes }
        .onChange(of: vm.selectedDate) { _, _ in
            writing = false
            text = vm.currentEntry.notes
        }
    }

    // MARK: Notes

    private var notesCard: some View {
        JournalCard(color: JournalStyle.notes, icon: "doc.text.fill",
                    title: vm.isToday ? "Today's Notes" : "Notes",
                    subtitle: "Capture your thoughts, ideas, and moments") {
            Button {
                writing.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: writing ? "checkmark" : "pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text(writing ? "Done" : "Edit")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(jc(150, 90, 30))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(JournalStyle.notes.opacity(0.13)))
            }
            .buttonStyle(TilePressStyle())
        } content: {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($writing)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 190)
                    .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 26)
                    .onChange(of: text) { _, new in
                        if new.count > JournalStyle.limit {
                            text = String(new.prefix(JournalStyle.limit))
                            return
                        }
                        if new != vm.currentEntry.notes { vm.updateNotes(new) }
                    }
                if text.isEmpty {
                    Text("Start writing your notes...")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal, 15).padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(text.count)/\(JournalStyle.limit)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(JournalStyle.inner))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
    }

    // MARK: Prompts

    private static let promptPool = [
        "What went well today?", "What challenged me today?", "What am I grateful for?",
        "What did I learn today?", "How can I improve tomorrow?", "What made me smile today?",
        "Who helped me today, and how?", "What drained my energy?", "What am I looking forward to?",
        "What would I do differently?", "What's one small win from today?", "How did I take care of myself?",
        "What's on my mind right now?", "Which moment do I want to remember?", "What did I avoid, and why?",
        "Who should I thank or call?", "What gave me energy today?", "What's one thing I can let go of?",
    ]

    private var prompts: [String] {
        guard promptSeed > 0 else { return Array(Self.promptPool.prefix(5)) }
        var rng = SeededGenerator(seed: UInt64(promptSeed))
        return Array(Self.promptPool.shuffled(using: &rng).prefix(5))
    }

    private var promptsCard: some View {
        let list = prompts
        let left = Array(list.prefix(3))
        let right = Array(list.dropFirst(3))

        return JournalCard(color: JournalStyle.prompts, icon: "lightbulb.fill",
                           title: "Writing Prompts",
                           subtitle: "Need inspiration? Try these prompts:") {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { promptSeed += 1 }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                    Text("New Prompts")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundColor(jc(170, 110, 0))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(JournalStyle.prompts.opacity(0.16)))
            }
            .buttonStyle(TilePressStyle())
        } content: {
            HStack(alignment: .top, spacing: 12) {
                promptColumn(left)
                Rectangle()
                    .fill(JournalStyle.prompts.opacity(0.25))
                    .frame(width: 1)
                promptColumn(right)
            }
            .padding(.vertical, 4)
            .background(alignment: .bottomTrailing) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 46))
                    .foregroundColor(JournalStyle.prompts.opacity(0.18))
                    .rotationEffect(.degrees(-20))
                    .offset(x: 4, y: 6)
            }
        }
    }

    private func promptColumn(_ list: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(list, id: \.self) { p in
                Button { use(p) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(JournalStyle.prompts)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                        Text(p)
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.8))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Adds the prompt to the notes as a heading to answer under.
    private func use(_ prompt: String) {
        let joiner = text.isEmpty ? "" : (text.hasSuffix("\n") ? "\n" : "\n\n")
        text = String((text + joiner + prompt + "\n").prefix(JournalStyle.limit))
        writing = true
    }

    // MARK: Rate Your Day

    private var rateCard: some View {
        let rating = vm.currentEntry.rating

        return JournalCard(color: JournalStyle.rate, icon: "chart.bar.fill",
                           title: "Rate Your Day",
                           subtitle: "Take a moment to reflect on your day") {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Overall Score: \(rating.overallScore)/5")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundColor(JournalStyle.rate)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(JournalStyle.rate.opacity(0.12)))
        } content: {
            VStack(spacing: 10) {
                rateRow("Productivity", "How productive were you today?", "bolt.fill",
                        jc(250, 130, 30), \.productivity)
                rateRow("Mood", "How was your emotional state?", "face.smiling.inverse",
                        jc(240, 60, 110), \.mood)
                rateRow("Health", "How healthy did you feel today?", "heart.fill",
                        jc(235, 50, 60), \.health)
            }
        }
    }

    private func rateRow(_ title: String, _ question: String, _ icon: String, _ color: Color,
                         _ key: WritableKeyPath<DayRating, Int>) -> some View {
        let value = vm.currentEntry.rating[keyPath: key]

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 11).fill(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(question)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineLimit(2).minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        var r = vm.currentEntry.rating
                        // Tapping the current rating again clears it.
                        r[keyPath: key] = (r[keyPath: key] == i) ? 0 : i
                        withAnimation(.spring(response: 0.3)) { vm.updateRating(r) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: i <= value ? "star.fill" : "star")
                            .font(.system(size: 21))
                            .foregroundColor(i <= value ? color : Color.secondary.opacity(0.35))
                            .scaleEffect(i <= value ? 1.08 : 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(JournalStyle.inner))
    }
}

// MARK: - Card chrome

private struct JournalCard<Trailing: View, Content: View>: View {
    let color: Color
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 13).fill(color.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [color.opacity(0.08), color.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .background(RoundedRectangle(cornerRadius: 24).fill(JournalStyle.card))
        )
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(color.opacity(0.15), lineWidth: 1))
        .shadow(color: color.opacity(0.06), radius: 10, y: 4)
    }
}

/// Repeatable shuffles for New Prompts.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
