import SwiftUI

struct NotesForTomorrowView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var text: String = ""
    @State private var isEditing = false
    @FocusState private var focused: Bool

    var entry: DailyEntry { vm.currentEntry }

    private var tomorrowDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: vm.selectedDate)!
        return fmt.string(from: tomorrow)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .notesForTomorrow,
                              subtitle: "Prepare and plan for tomorrow",
                              completedCount: entry.notesForTomorrow.isEmpty ? 0 : 1,
                              totalCount: 1)

                // Tomorrow preview banner
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preparing for Tomorrow")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(tomorrowDateString)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.3, green: 0.45, blue: 0.85),
                                 Color(red: 0.2, green: 0.3, blue: 0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Notes editor
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(AppSection.notesForTomorrow.color)
                        Text("Notes for Tomorrow")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        if !vm.isFuture {
                            Button(isEditing ? "Done" : "Edit") {
                                if isEditing {
                                    vm.updateNotesForTomorrow(text)
                                    focused = false
                                } else {
                                    text = entry.notesForTomorrow
                                    focused = true
                                }
                                isEditing.toggle()
                            }
                            .font(.subheadline)
                            .foregroundColor(AppSection.notesForTomorrow.color)
                        }
                    }

                    if isEditing {
                        TextEditor(text: $text)
                            .focused($focused)
                            .frame(minHeight: 250)
                            .font(.body)
                            .padding(4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .onChange(of: text) { _ in
                                vm.updateNotesForTomorrow(text)
                            }
                    } else {
                        if entry.notesForTomorrow.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.3))
                                Text("Plan tomorrow tonight for a better day")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 180)
                        } else {
                            Text(entry.notesForTomorrow)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Prompts
                TomorrowPromptsCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 40)
            }
        }
        .onAppear { text = entry.notesForTomorrow }
    }
}

struct TomorrowPromptsCard: View {
    private let prompts = [
        ("star.fill", "Top 3 priorities for tomorrow", Color.orange),
        ("clock.fill", "Important appointments or deadlines", Color.blue),
        ("heart.fill", "Self-care intention for tomorrow", Color.pink),
        ("target", "One key goal to focus on", Color.green),
        ("bag.fill", "Things to prepare tonight", Color.purple)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                Text("Tomorrow's Planning Prompts")
                    .font(.system(size: 14, weight: .bold))
            }
            ForEach(prompts, id: \.0) { p in
                HStack(spacing: 8) {
                    Image(systemName: p.0)
                        .font(.system(size: 11))
                        .foregroundColor(p.2)
                        .frame(width: 18)
                    Text(p.1).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
