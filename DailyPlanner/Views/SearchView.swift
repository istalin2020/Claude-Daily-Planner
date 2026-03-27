import SwiftUI

struct SearchView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var query = ""
    @State private var selectedFilter: SearchFilter = .all
    @Environment(\.dismiss) var dismiss

    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case tasks = "Tasks"
        case notes = "Notes"
        case expenses = "Expenses"
        case health = "Health"
    }

    var results: [SearchResult] {
        guard query.count >= 2 else { return [] }
        let q = query.lowercased()
        var out: [SearchResult] = []
        let fmt = DateFormatter()
        fmt.dateStyle = .medium

        for (key, entry) in vm.entries.sorted(by: { $0.key > $1.key }) {
            let date = entry.date
            let dateStr = fmt.string(from: date)

            if selectedFilter == .all || selectedFilter == .tasks {
                for task in entry.topPriorities + entry.toDoLists + entry.callsEmails + entry.personalTodo {
                    if task.title.lowercased().contains(q) || task.notes.lowercased().contains(q) {
                        out.append(SearchResult(id: task.id.uuidString, date: date, dateStr: dateStr,
                            type: .task, title: task.title, subtitle: task.notes.isEmpty ? nil : task.notes,
                            isCompleted: task.isCompleted, entryKey: key))
                    }
                }
            }
            if selectedFilter == .all || selectedFilter == .notes {
                if !entry.notes.isEmpty && entry.notes.lowercased().contains(q) {
                    out.append(SearchResult(id: key + "notes", date: date, dateStr: dateStr,
                        type: .note, title: entry.notes, subtitle: nil,
                        isCompleted: false, entryKey: key))
                }
            }
            if selectedFilter == .all || selectedFilter == .expenses {
                for expense in entry.expenses {
                    if expense.description.lowercased().contains(q) {
                        out.append(SearchResult(id: expense.id.uuidString, date: date, dateStr: dateStr,
                            type: .expense, title: expense.description,
                            subtitle: "\(expense.isIncome ? "+" : "-")\(vm.settings.currency.symbol)\(String(format: "%.2f", expense.amount))",
                            isCompleted: false, entryKey: key))
                    }
                }
            }
            if selectedFilter == .all || selectedFilter == .health {
                if entry.fitness.hkWorkouts.contains(where: { $0.activityType.lowercased().contains(q) }) {
                    out.append(SearchResult(id: key + "workout", date: date, dateStr: dateStr,
                        type: .health, title: "Workout on \(dateStr)",
                        subtitle: "\(entry.fitness.displayWorkoutMinutes) min · \(entry.fitness.displaySteps) steps",
                        isCompleted: false, entryKey: key))
                }
            }
        }
        return out
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchFilter.allCases, id: \.self) { f in
                            Button(f.rawValue) { selectedFilter = f }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(selectedFilter == f
                                    ? Color(red: 0.45, green: 0.25, blue: 0.85)
                                    : Color(.secondarySystemBackground))
                                .foregroundColor(selectedFilter == f ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }

                if query.count < 2 {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.4))
                        Text("Type at least 2 characters to search")
                            .foregroundColor(.secondary).font(.subheadline)
                    }
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.4))
                        Text("No results for \"\(query)\"")
                            .foregroundColor(.secondary).font(.subheadline)
                    }
                    Spacer()
                } else {
                    List(results) { result in
                        Button { navigateTo(result) } label: {
                            SearchResultRow(result: result)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: "Search tasks, notes, expenses…")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func navigateTo(_ result: SearchResult) {
        // Navigate to the date and section of the result
        vm.select(date: result.date)
        switch result.type {
        case .task:    vm.selectedSection = .topPriorities
        case .note:    vm.selectedSection = .notes
        case .expense: vm.selectedSection = .expenseTracker
        case .health:  vm.selectedSection = .healthFitness
        }
        dismiss()
    }
}

// MARK: - Search Result Model
struct SearchResult: Identifiable {
    let id: String
    let date: Date
    let dateStr: String
    let type: ResultType
    let title: String
    let subtitle: String?
    let isCompleted: Bool
    let entryKey: String

    enum ResultType {
        case task, note, expense, health
        var icon: String {
            switch self {
            case .task:    return "checkmark.circle"
            case .note:    return "note.text"
            case .expense: return "dollarsign.circle.fill"
            case .health:  return "heart.fill"
            }
        }
        var color: Color {
            switch self {
            case .task:    return Color(red: 0.45, green: 0.25, blue: 0.85)
            case .note:    return Color(red: 0.6, green: 0.4, blue: 0.2)
            case .expense: return Color(red: 0.1, green: 0.65, blue: 0.35)
            case .health:  return .red
            }
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchResult
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(result.type.color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: result.type.icon)
                    .font(.system(size: 14)).foregroundColor(result.type.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
                    .strikethrough(result.isCompleted)
                    .lineLimit(2)
                if let sub = result.subtitle {
                    Text(sub).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(result.dateStr)
                .font(.system(size: 10)).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
