import SwiftUI

struct RateYourDayView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var rating: DayRating = DayRating()
    @State private var notesText = ""
    @State private var showPopper = false
    // Set to true after onAppear so we don't fire the popper when restoring
    // an existing 5-star rating from saved data.
    @State private var isLoaded = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
          ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .rateYourDay,
                              subtitle: "Reflect on your day",
                              completedCount: hasRating ? 1 : 0,
                              totalCount: 1)

                // Header card
                VStack(spacing: 8) {
                    Text(overallEmoji)
                        .font(.system(size: 54))
                    Text(overallMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("Overall Score: \(overallScore)/5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [AppSection.rateYourDay.color.opacity(0.15),
                                 AppSection.rateYourDay.color.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(20)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Rating cards
                VStack(spacing: 10) {
                    RatingCard(
                        title: "Productivity",
                        subtitle: "How productive were you today?",
                        icon: "bolt.fill",
                        color: .orange,
                        value: Binding(
                            get: { rating.productivity },
                            set: { rating.productivity = $0; save() }
                        ),
                        labels: ["Poor", "Below Avg", "Average", "Good", "Excellent"]
                    )

                    RatingCard(
                        title: "Mood",
                        subtitle: "How was your emotional state?",
                        icon: "face.smiling.fill",
                        color: .pink,
                        value: Binding(
                            get: { rating.mood },
                            set: { rating.mood = $0; save() }
                        ),
                        labels: ["Very Low", "Low", "Neutral", "Good", "Great"]
                    )

                    RatingCard(
                        title: "Health",
                        subtitle: "How healthy did you feel today?",
                        icon: "heart.fill",
                        color: .red,
                        value: Binding(
                            get: { rating.health },
                            set: { rating.health = $0; save() }
                        ),
                        labels: ["Poor", "Below Avg", "Average", "Good", "Excellent"]
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Day summary stats
                DaySummaryCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Reflection notes
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "text.quote").foregroundColor(AppSection.rateYourDay.color)
                        Text("Day Reflection").font(.system(size: 14, weight: .bold))
                    }
                    TextEditor(text: $notesText)
                        .frame(minHeight: 100)
                        .font(.subheadline)
                        .padding(4)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .disabled(vm.isFuture)
                        .onChange(of: notesText) { _, _ in
                            rating.notes = notesText
                            save()
                        }
                }
                .padding(14)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer(minLength: 40)
            }
        }
            .onAppear {
                rating    = entry.rating
                notesText = entry.rating.notes
                // Allow a single run-loop tick for the state to settle before
                // we begin watching for user-initiated 5-star changes.
                DispatchQueue.main.async { isLoaded = true }
            }

            if showPopper {
                PartyPopperOverlay(isVisible: $showPopper)
                    .ignoresSafeArea()
            }
        }
        // Fire whenever any individual category reaches 5 stars.
        // Using the max so that tapping 5 on a second category doesn't
        // re-trigger (maxRating stays 5, no change event).
        .onChange(of: maxRating) { _, newMax in
            if newMax == 5 && isLoaded { showPopper = true }
        }
    }

    private func save() {
        vm.updateRating(rating)
    }

    private var hasRating: Bool {
        rating.productivity > 0 || rating.mood > 0 || rating.health > 0
    }

    // Highest single rating across all three categories.
    // Watched by onChange so the popper fires as soon as the user taps any ★★★★★.
    private var maxRating: Int {
        max(rating.productivity, max(rating.mood, rating.health))
    }

    private var overallScore: Int {
        guard hasRating else { return 0 }
        var total = 0, count = 0
        if rating.productivity > 0 { total += rating.productivity; count += 1 }
        if rating.mood > 0 { total += rating.mood; count += 1 }
        if rating.health > 0 { total += rating.health; count += 1 }
        return count > 0 ? Int(round(Double(total) / Double(count))) : 0
    }

    private var overallEmoji: String {
        switch overallScore {
        case 0: return "📊"
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😊"
        case 4: return "😄"
        default: return "🌟"
        }
    }

    private var overallMessage: String {
        switch overallScore {
        case 0: return "Rate your day below"
        case 1: return "Tough day — tomorrow is a new start"
        case 2: return "Could be better — keep going!"
        case 3: return "Decent day — well done!"
        case 4: return "Great day — you did well!"
        default: return "Outstanding day! 🎉"
        }
    }
}

// MARK: - Rating Card
struct RatingCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var value: Int
    let labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 14, weight: .bold))
                    Text(subtitle).font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                if value > 0 {
                    Text(labels[value - 1])
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
            }

            // Star rating row
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Button(action: { withAnimation(.spring(response: 0.3)) { value = i } }) {
                        Image(systemName: i <= value ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundColor(i <= value ? color : Color.secondary.opacity(0.25))
                            .scaleEffect(i <= value ? 1.15 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }
}

// MARK: - Day Summary Card
struct DaySummaryCard: View {
    @EnvironmentObject var vm: PlannerViewModel

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundColor(.purple)
                Text("Today's Summary").font(.system(size: 14, weight: .bold))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                SummaryMetric(icon: "checkmark.circle.fill",
                              label: "Tasks Done",
                              value: "\(entry.completedTasksCount)/\(entry.allTasksCount)",
                              color: .green)
                SummaryMetric(icon: "drop.fill",
                              label: "Water Glasses",
                              value: "\(entry.waterGlasses)/\(entry.waterGoal)",
                              color: .cyan)
                SummaryMetric(icon: "figure.run",
                              label: "Workout Mins",
                              value: "\(entry.fitness.totalMinutes)",
                              color: .orange)
                SummaryMetric(icon: "dollarsign.circle",
                              label: "Spent Today",
                              value: String(format: "$%.0f", entry.totalExpenses),
                              color: .red)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct SummaryMetric: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 14, weight: .bold))
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}
