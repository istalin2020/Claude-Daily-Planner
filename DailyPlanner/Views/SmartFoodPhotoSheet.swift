import SwiftUI

// MARK: - Smart Food Photo Sheet (PRO)
/// Shown after a PRO user photographs a meal. The photo goes to the Daily
/// Planner Worker, which identifies every item on the plate and returns
/// portions and nutrition. When the photo can't settle something — how deep the
/// bowl is, whether the juice had sugar — the model asks, and the user answers
/// with a tap or types their own.
///
/// Free users get `PhotoMealSheet` instead, which does the same job entirely on
/// device. This sheet also falls back to that path if the network is down.
struct SmartFoodPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss

    let photo: UIImage
    let mealName: String
    let onSave: ([MealItem]) -> Void
    /// Called when the cloud path can't run at all, so the caller can open the
    /// on-device sheet instead of leaving the user stranded.
    let onFallback: () -> Void

    private enum Phase: Equatable {
        case analyzing
        case refining          // second pass, after answers
        case results
        case failed(String)
    }

    @State private var phase: Phase = .analyzing
    @State private var analysis: CloudFoodAnalysis? = nil

    /// question.id → the answer the user picked or typed.
    @State private var answers: [UUID: String] = [:]
    /// question.id → free-text entry, kept separate so switching back to a
    /// preset option doesn't wipe what they typed.
    @State private var customText: [UUID: String] = [:]
    /// Items the user unticked because they didn't actually eat them.
    @State private var excluded: Set<UUID> = []

    @State private var scanOffset: CGFloat = -1
    @State private var statusIndex = 0
    /// Held so it can be torn down on disappear — a repeating timer left
    /// running would outlive the sheet and keep firing forever.
    @State private var statusTimer: Timer? = nil

    private let statusLines = [
        "Looking at your plate…",
        "Identifying each item…",
        "Estimating portions…",
        "Working out the nutrition…",
    ]

    private var includedItems: [CloudFoodItem] {
        (analysis?.items ?? []).filter { !excluded.contains($0.id) }
    }

    private var totals: (cal: Int, protein: Double, carbs: Double, fat: Double, fiber: Double, iron: Double) {
        includedItems.reduce(into: (0, 0.0, 0.0, 0.0, 0.0, 0.0)) { acc, item in
            acc.0 += item.calories
            acc.1 += item.protein
            acc.2 += item.carbs
            acc.3 += item.fat
            acc.4 += item.fiber
            acc.5 += item.iron
        }
    }

    private var unansweredCount: Int {
        (analysis?.questions ?? []).filter { answers[$0.id] == nil }.count
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroPhoto

                    switch phase {
                    case .analyzing, .refining:
                        analyzingCard
                    case .failed(let message):
                        failureCard(message)
                    case .results:
                        if let analysis = analysis {
                            resultsBody(analysis)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Add to \(mealName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(includedItems.isEmpty || phase != .results)
                }
            }
        }
        .onAppear {
            startScanAnimation()
            runAnalysis()
        }
        .onDisappear {
            statusTimer?.invalidate()
            statusTimer = nil
        }
    }

    // MARK: - Hero photo

    private var heroPhoto: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: 210)
                    .clipped()
                    .overlay {
                        if phase == .analyzing || phase == .refining {
                            // A soft band sweeping top-to-bottom reads as
                            // "being looked at" without hiding the food.
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.55), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 90)
                            .offset(y: scanOffset * 210)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                        }
                    }
            }
            .frame(height: 210)

            if phase == .results, let analysis = analysis, analysis.recognized {
                dishBadge(analysis)
            }
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }

    private func dishBadge(_ analysis: CloudFoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(analysis.dishName)
                .font(.system(size: 21, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text(confidenceLabel(analysis.confidence))
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.25)))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func confidenceLabel(_ value: Double) -> String {
        switch value {
        case 0.8...:    return "Confident match"
        case 0.55..<0.8: return "Likely match"
        default:         return "Best guess — check below"
        }
    }

    // MARK: - Analysing

    private var analyzingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                Text(phase == .refining ? "Updating with your answers…" : statusLines[statusIndex])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .animation(.easeInOut, value: statusIndex)
                Spacer()
            }

            // Placeholder rows so the sheet doesn't visibly jump when the real
            // content lands.
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 44)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    runAnalysis()
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    dismiss()
                    onFallback()
                } label: {
                    Text("Enter manually")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(.tertiarySystemFill))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsBody(_ analysis: CloudFoodAnalysis) -> some View {
        if !analysis.recognized {
            VStack(alignment: .leading, spacing: 12) {
                Label("No food spotted", systemImage: "questionmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                if !analysis.summary.isEmpty {
                    Text(analysis.summary)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    dismiss()
                    onFallback()
                } label: {
                    Text("Enter it manually")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        } else {
            if !analysis.summary.isEmpty {
                Text(analysis.summary)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            nutritionCard
            itemsCard(analysis)

            if !analysis.questions.isEmpty {
                questionsCard(analysis)
            }

            if !analysis.notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text(analysis.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
            }

            Text("Estimated from your photo by Daily Planner PRO. Figures are a good guide, not lab measurements.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    // ── Calories + macros ──────────────────────────────────────────────────

    private var nutritionCard: some View {
        let t = totals
        let macroTotal = max(t.protein + t.carbs + t.fat, 0.001)

        return VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
                Text("\(t.cal)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("cal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Macro split — one bar so the proportions read at a glance.
            GeometryReader { geo in
                HStack(spacing: 2) {
                    macroSegment(width: geo.size.width * (t.protein / macroTotal), color: .blue)
                    macroSegment(width: geo.size.width * (t.carbs   / macroTotal), color: .green)
                    macroSegment(width: geo.size.width * (t.fat     / macroTotal), color: .pink)
                }
            }
            .frame(height: 10)

            HStack(spacing: 10) {
                macroPill("Protein", value: t.protein, unit: "g", color: .blue)
                macroPill("Carbs",   value: t.carbs,   unit: "g", color: .green)
                macroPill("Fat",     value: t.fat,     unit: "g", color: .pink)
            }

            HStack(spacing: 10) {
                macroPill("Fibre", value: t.fiber, unit: "g",  color: .teal)
                macroPill("Iron",  value: t.iron,  unit: "mg", color: .purple)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        .animation(.snappy, value: excluded)
    }

    private func macroSegment(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(color)
            .frame(width: max(width, 0))
    }

    private func macroPill(_ title: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color.opacity(0.8))
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.10)))
    }

    // ── Detected items ─────────────────────────────────────────────────────

    private func itemsCard(_ analysis: CloudFoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("On your plate")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("Tap to include or skip")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ForEach(analysis.items) { item in
                let isIn = !excluded.contains(item.id)
                Button {
                    withAnimation(.snappy) {
                        if isIn { excluded.insert(item.id) } else { excluded.remove(item.id) }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isIn ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isIn ? .orange : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            if !item.portion.isEmpty {
                                Text(item.portion)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Text("\(item.calories) cal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(isIn ? .orange : .secondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(isIn ? Color.orange.opacity(0.08) : Color(.tertiarySystemFill)))
                    .opacity(isIn ? 1 : 0.55)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    // ── Follow-up questions ────────────────────────────────────────────────

    private func questionsCard(_ analysis: CloudFoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text(unansweredCount == 0 ? "Thanks — update the estimate" : "A couple of quick questions")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            ForEach(analysis.questions) { question in
                VStack(alignment: .leading, spacing: 9) {
                    Text(question.prompt)
                        .font(.system(size: 14, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(question.options) { option in
                        optionRow(question: question, label: option.label, detail: option.detail)
                    }

                    if question.allowCustom {
                        customRow(question: question)
                    }
                }
            }

            Button {
                submitAnswers(analysis)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text(unansweredCount == 0
                         ? "Update the estimate"
                         : "Update with \(analysis.questions.count - unansweredCount) answer\(analysis.questions.count - unansweredCount == 1 ? "" : "s")")
                }
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(answers.isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(answers.isEmpty)

            Text("Or skip these — the numbers above are already a reasonable estimate.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func optionRow(question: CloudFoodQuestion, label: String, detail: String) -> some View {
        let picked = answers[question.id] == label
        return Button {
            withAnimation(.snappy) {
                answers[question.id] = picked ? nil : label
                if !picked { customText[question.id] = "" }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: picked ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(picked ? .orange : .secondary)
                Text(label)
                    .font(.system(size: 14, weight: picked ? .semibold : .regular))
                    .foregroundColor(.primary)
                Spacer()
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 11)
                .fill(picked ? Color.orange.opacity(0.12) : Color(.tertiarySystemFill)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func customRow(question: CloudFoodQuestion) -> some View {
        let text = customText[question.id] ?? ""
        let active = !text.trimmingCharacters(in: .whitespaces).isEmpty
                     && answers[question.id] == text

        return HStack(spacing: 10) {
            Image(systemName: active ? "largecircle.fill.circle" : "square.and.pencil")
                .foregroundColor(active ? .orange : .secondary)

            TextField("Something else…", text: Binding(
                get: { customText[question.id] ?? "" },
                set: { newValue in
                    customText[question.id] = newValue
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    answers[question.id] = trimmed.isEmpty ? nil : newValue
                }
            ))
            .font(.system(size: 14))
            .submitLabel(.done)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 11)
            .fill(active ? Color.orange.opacity(0.12) : Color(.tertiarySystemFill)))
    }

    // MARK: - Actions

    private func runAnalysis() {
        phase = .analyzing
        excluded.removeAll()
        answers.removeAll()
        customText.removeAll()

        CloudFoodAnalyzer.analyze(image: photo, mealName: mealName) { result in
            apply(result)
        }
    }

    private func submitAnswers(_ analysis: CloudFoodAnalysis) {
        let payload: [CloudFoodAnswer] = analysis.questions.compactMap { question in
            guard let answer = answers[question.id],
                  !answer.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return CloudFoodAnswer(prompt: question.prompt, answer: answer)
        }
        guard !payload.isEmpty else { return }

        phase = .refining
        CloudFoodAnalyzer.analyze(image: photo, mealName: mealName, answers: payload) { result in
            // Answers are cleared on the way in so a second round of questions
            // starts fresh rather than showing stale ticks.
            answers.removeAll()
            customText.removeAll()
            excluded.removeAll()
            apply(result)
        }
    }

    private func apply(_ result: Result<CloudFoodAnalysis, Error>) {
        switch result {
        case .success(let value):
            withAnimation(.snappy) {
                analysis = value
                phase = .results
            }
        case .failure(let error):
            let message = (error as? CloudFoodError)?.errorDescription
                ?? error.localizedDescription
            withAnimation { phase = .failed(message) }
        }
    }

    private func save() {
        let items = includedItems.map {
            MealItem(name: $0.name,
                     calories: $0.calories,
                     portion: $0.portion,
                     protein: $0.protein,
                     fiber: $0.fiber,
                     iron: $0.iron)
        }
        guard !items.isEmpty else { return }
        onSave(items)
        dismiss()
    }

    /// Sweeps the highlight band down the photo and rotates the status line.
    private func startScanAnimation() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
            scanOffset = 1
        }
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { timer in
            guard phase == .analyzing || phase == .refining else {
                timer.invalidate()
                return
            }
            statusIndex = (statusIndex + 1) % statusLines.count
        }
    }
}
