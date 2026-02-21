import SwiftUI

struct NotesView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var text: String = ""
    @State private var isEditing = false
    @FocusState private var focused: Bool

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionHeader(section: .notes,
                              subtitle: "Capture your thoughts and ideas",
                              completedCount: entry.notes.isEmpty ? 0 : 1,
                              totalCount: 1)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(AppSection.notes.color)
                        Text("Today's Notes")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        if !vm.isFuture {
                            Button(isEditing ? "Done" : "Edit") {
                                if isEditing {
                                    vm.updateNotes(text)
                                    focused = false
                                } else {
                                    text = entry.notes
                                    focused = true
                                }
                                isEditing.toggle()
                            }
                            .font(.subheadline)
                            .foregroundColor(AppSection.notes.color)
                        }
                    }

                    if isEditing {
                        TextEditor(text: $text)
                            .focused($focused)
                            .frame(minHeight: 300)
                            .font(.body)
                            .padding(4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .onChange(of: text) { _ in
                                vm.updateNotes(text)
                            }
                    } else {
                        if entry.notes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.3))
                                Text("Tap 'Edit' to write your notes")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 200)
                        } else {
                            Text(entry.notes)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }

                    if !entry.notes.isEmpty {
                        HStack {
                            Spacer()
                            Text("\(entry.notes.split(separator: " ").count) words · \(entry.notes.count) chars")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Writing prompts
                if entry.notes.isEmpty && !isEditing {
                    WritingPromptsCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                Spacer(minLength: 40)
            }
        }
        .onAppear { text = entry.notes }
    }
}

struct WritingPromptsCard: View {
    private let prompts = [
        "What went well today?",
        "What challenged me today?",
        "What am I grateful for?",
        "What did I learn today?",
        "How can I improve tomorrow?"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                Text("Writing Prompts").font(.system(size: 14, weight: .bold))
            }
            ForEach(prompts, id: \.self) { prompt in
                HStack(spacing: 8) {
                    Circle().fill(Color.yellow.opacity(0.5)).frame(width: 6, height: 6)
                    Text(prompt).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
