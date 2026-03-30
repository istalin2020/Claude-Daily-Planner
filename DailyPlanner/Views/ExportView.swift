import SwiftUI

struct ExportView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var exportType: ExportType = .expensesCSV
    @State private var monthOffset = 0
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false

    enum ExportType: String, CaseIterable {
        case expensesCSV  = "Expenses CSV"
        case tasksCSV     = "Tasks CSV"
        case fullReport   = "Monthly Report (Text)"
    }

    private var exportMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: exportMonth)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Export Type") {
                    Picker("Type", selection: $exportType) {
                        ForEach(ExportType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Month") {
                    HStack {
                        Button { monthOffset -= 1 } label: {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(monthLabel).fontWeight(.semibold)
                        Spacer()
                        Button { monthOffset += 1 } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }

                Section {
                    Button {
                        isExporting = true
                        export()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView().padding(.trailing, 8)
                            }
                            Label("Export \(exportType.rawValue)", systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func export() {
        DispatchQueue.global(qos: .userInitiated).async {
            let content: String
            let filename: String
            switch exportType {
            case .expensesCSV:
                content = generateExpensesCSV()
                filename = "expenses_\(monthLabel.replacingOccurrences(of: " ", with: "_")).csv"
            case .tasksCSV:
                content = generateTasksCSV()
                filename = "tasks_\(monthLabel.replacingOccurrences(of: " ", with: "_")).csv"
            case .fullReport:
                content = generateMonthlyReport()
                filename = "report_\(monthLabel.replacingOccurrences(of: " ", with: "_")).txt"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? content.write(to: url, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                exportURL = url
                isExporting = false
                showShareSheet = true
            }
        }
    }

    // MARK: - CSV / Report Generators

    private func csvEscape(_ str: String) -> String {
        let escaped = str.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func generateExpensesCSV() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        let monthStr = fmt.string(from: exportMonth)
        let sym = vm.settings.currency.symbol
        let entries = vm.monthlyEntries(for: exportMonth).sorted { $0.date < $1.date }

        var lines: [String] = []

        // Document heading block
        lines.append("Daily Planner — Expense Export")
        lines.append("Month: \(monthStr)")
        lines.append("Currency: \(vm.settings.currency.displayName) (\(sym))")
        lines.append("Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))")
        lines.append("") // blank separator

        // Column header
        lines.append("No.,Date,Description,Category,Amount,Type")

        let dfmt = DateFormatter(); dfmt.dateStyle = .medium
        var rowNum = 0
        var totalIncome = 0.0, totalExpense = 0.0, totalSavings = 0.0
        for entry in entries {
            for e in entry.expenses {
                rowNum += 1
                let type = e.isIncome ? "Income" : (e.isDeposit ? "Savings" : "Expense")
                let sign = e.isIncome || e.isDeposit ? "+" : "-"
                let amt = "\(sign)\(sym)\(String(format: "%.2f", e.amount))"
                let cat = e.category.rawValue.capitalized
                lines.append("\(rowNum),\(csvEscape(dfmt.string(from: entry.date))),\(csvEscape(e.description)),\(csvEscape(cat)),\(csvEscape(amt)),\(type)")
                if e.isIncome { totalIncome += e.amount }
                else if e.isDeposit { totalSavings += e.amount }
                else { totalExpense += e.amount }
            }
        }

        // Summary footer
        lines.append("")
        lines.append("SUMMARY")
        lines.append("Total Income,\(sym)\(String(format: "%.2f", totalIncome))")
        lines.append("Total Expenses,\(sym)\(String(format: "%.2f", totalExpense))")
        lines.append("Total Savings,\(sym)\(String(format: "%.2f", totalSavings))")
        lines.append("Net Balance,\(sym)\(String(format: "%.2f", totalIncome - totalExpense))")

        return lines.joined(separator: "\n")
    }

    private func generateTasksCSV() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        let monthStr = fmt.string(from: exportMonth)
        let entries = vm.monthlyEntries(for: exportMonth).sorted { $0.date < $1.date }

        var lines: [String] = []

        // Document heading block
        lines.append("Daily Planner — Task Export")
        lines.append("Month: \(monthStr)")
        lines.append("Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))")
        lines.append("")

        // Column header
        lines.append("No.,Date,Title,Section,Status,Notes")

        let dfmt = DateFormatter(); dfmt.dateStyle = .medium
        var rowNum = 0
        var totalTasks = 0, doneTasks = 0

        for entry in entries {
            let d = csvEscape(dfmt.string(from: entry.date))
            let sections: [(tasks: [PlannerTask], name: String)] = [
                (entry.topPriorities, "Top Priorities"),
                (entry.toDoLists,     "To-Do Lists"),
                (entry.callsEmails,   "Calls & Emails"),
                (entry.personalTodo,  "Personal To-Do")
            ]
            for (tasks, sectionName) in sections {
                for t in tasks {
                    rowNum += 1
                    totalTasks += 1
                    if t.isCompleted { doneTasks += 1 }
                    let status = t.isCompleted ? "Done" : "Pending"
                    lines.append("\(rowNum),\(d),\(csvEscape(t.title)),\(csvEscape(sectionName)),\(status),\(csvEscape(t.notes))")
                }
            }
        }

        // Summary footer
        let pct = totalTasks > 0 ? Int(Double(doneTasks) / Double(totalTasks) * 100) : 0
        lines.append("")
        lines.append("SUMMARY")
        lines.append("Total Tasks,\(totalTasks)")
        lines.append("Completed,\(doneTasks)")
        lines.append("Pending,\(totalTasks - doneTasks)")
        lines.append("Completion Rate,\(pct)%")

        return lines.joined(separator: "\n")
    }

    private func generateMonthlyReport() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        let monthStr = fmt.string(from: exportMonth)
        let entries = vm.monthlyEntries(for: exportMonth).sorted { $0.date < $1.date }
        let sym = vm.settings.currency.symbol
        let divider = String(repeating: "═", count: 50)
        let thinLine = String(repeating: "─", count: 50)

        var lines: [String] = []
        lines.append(divider)
        lines.append("  DAILY PLANNER  —  \(monthStr.uppercased())")
        lines.append("  Monthly Summary Report")
        lines.append("  Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))")
        lines.append(divider)
        lines.append("")

        // Task Summary
        let allTasks = entries.flatMap { $0.topPriorities + $0.toDoLists + $0.callsEmails + $0.personalTodo }
        let done = allTasks.filter(\.isCompleted)
        let pct = allTasks.isEmpty ? 0 : Int(Double(done.count) / Double(allTasks.count) * 100)

        lines.append("  TASK SUMMARY")
        lines.append(thinLine)
        lines.append(String(format: "  %-30s %d", "Total Tasks:", allTasks.count))
        lines.append(String(format: "  %-30s %d  (%d%%)", "Completed:", done.count, pct))
        lines.append(String(format: "  %-30s %d", "Pending:", allTasks.count - done.count))
        lines.append("")

        // Finance Summary
        let totalInc = vm.monthlyTotalIncome(for: exportMonth)
        let totalExp = vm.monthlyTotalExpenses(for: exportMonth)
        let balance  = vm.monthlyBalance(for: exportMonth)
        lines.append("  FINANCE SUMMARY")
        lines.append(thinLine)
        lines.append(String(format: "  %-30s %@%.2f", "Total Income:", sym, totalInc))
        lines.append(String(format: "  %-30s %@%.2f", "Total Expenses:", sym, totalExp))
        lines.append(String(format: "  %-30s %@%.2f", "Net Balance:", sym, balance))
        lines.append("")

        // Expense by Category
        let byCat = vm.monthlyExpensesByCategory(for: exportMonth)
        if !byCat.isEmpty {
            lines.append("  EXPENSES BY CATEGORY")
            lines.append(thinLine)
            for (cat, amt) in byCat.sorted(by: { $0.value > $1.value }) {
                lines.append(String(format: "  %-30s %@%.2f", "\(cat.rawValue.capitalized):", sym, amt))
            }
            lines.append("")
        }

        // Daily Breakdown
        lines.append("  DAILY BREAKDOWN")
        lines.append(thinLine)
        let dfmt = DateFormatter(); dfmt.dateFormat = "EEE, d MMM"
        for entry in entries {
            let hasTasks = !(entry.topPriorities + entry.toDoLists + entry.callsEmails + entry.personalTodo).isEmpty
            let hasExp   = !entry.expenses.isEmpty
            guard hasTasks || hasExp else { continue }

            let totalTasks = entry.topPriorities.count + entry.toDoLists.count + entry.callsEmails.count + entry.personalTodo.count
            let doneTasks  = (entry.topPriorities + entry.toDoLists + entry.callsEmails + entry.personalTodo).filter(\.isCompleted).count
            lines.append("")
            lines.append("  \(dfmt.string(from: entry.date))")
            if hasTasks {
                lines.append(String(format: "    Tasks: %d/%d done", doneTasks, totalTasks))
            }
            if hasExp {
                let dayInc = entry.totalIncome
                let dayExp = entry.totalExpenses
                if dayInc > 0 { lines.append(String(format: "    Income:   %@%.2f", sym, dayInc)) }
                if dayExp > 0 { lines.append(String(format: "    Expenses: %@%.2f", sym, dayExp)) }
            }
        }

        lines.append("")
        lines.append(divider)
        lines.append("  End of Report")
        lines.append(divider)

        return lines.joined(separator: "\n")
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
