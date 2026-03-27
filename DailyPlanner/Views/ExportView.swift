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

    private func generateExpensesCSV() -> String {
        var csv = "Date,Description,Category,Amount,Type\n"
        let entries = vm.monthlyEntries(for: exportMonth)
            .sorted { $0.date < $1.date }
        let sym = vm.settings.currency.symbol
        for entry in entries {
            let fmt = DateFormatter(); fmt.dateStyle = .short
            let dateStr = fmt.string(from: entry.date)
            for e in entry.expenses {
                let type = e.isIncome ? "Income" : (e.isDeposit ? "Savings" : "Expense")
                let sign = e.isIncome || e.isDeposit ? "+" : "-"
                csv += "\(dateStr),\"\(e.description)\",\(e.category.rawValue),\(sign)\(sym)\(String(format: "%.2f", e.amount)),\(type)\n"
            }
        }
        return csv
    }

    private func generateTasksCSV() -> String {
        var csv = "Date,Title,Section,Status,Notes\n"
        let entries = vm.monthlyEntries(for: exportMonth).sorted { $0.date < $1.date }
        let fmt = DateFormatter(); fmt.dateStyle = .short
        for entry in entries {
            let d = fmt.string(from: entry.date)
            for t in entry.topPriorities { csv += "\(d),\"\(t.title)\",Top Priorities,\(t.isCompleted ? "Done" : "Pending"),\"\(t.notes)\"\n" }
            for t in entry.toDoLists    { csv += "\(d),\"\(t.title)\",To-Do,\(t.isCompleted ? "Done" : "Pending"),\"\(t.notes)\"\n" }
            for t in entry.callsEmails  { csv += "\(d),\"\(t.title)\",Calls & Emails,\(t.isCompleted ? "Done" : "Pending"),\"\(t.notes)\"\n" }
            for t in entry.personalTodo { csv += "\(d),\"\(t.title)\",Personal,\(t.isCompleted ? "Done" : "Pending"),\"\(t.notes)\"\n" }
        }
        return csv
    }

    private func generateMonthlyReport() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        let monthStr = fmt.string(from: exportMonth)
        let entries = vm.monthlyEntries(for: exportMonth).sorted { $0.date < $1.date }
        let sym = vm.settings.currency.symbol

        var report = "=== DAILY PLANNER — \(monthStr.uppercased()) REPORT ===\n\n"

        let totalTasks = entries.flatMap { $0.topPriorities + $0.toDoLists + $0.callsEmails + $0.personalTodo }
        let doneTasks = totalTasks.filter { $0.isCompleted }
        report += "TASK SUMMARY\n"
        report += "Total tasks: \(totalTasks.count)\n"
        report += "Completed:   \(doneTasks.count) (\(totalTasks.isEmpty ? 0 : Int(Double(doneTasks.count)/Double(totalTasks.count)*100))%)\n\n"

        report += "FINANCE SUMMARY\n"
        report += "Total Income:  \(sym)\(String(format: "%.2f", vm.monthlyTotalIncome(for: exportMonth)))\n"
        report += "Total Expenses:\(sym)\(String(format: "%.2f", vm.monthlyTotalExpenses(for: exportMonth)))\n"
        report += "Balance:       \(sym)\(String(format: "%.2f", vm.monthlyBalance(for: exportMonth)))\n\n"

        report += "EXPENSE BY CATEGORY\n"
        for (cat, amt) in vm.monthlyExpensesByCategory(for: exportMonth) {
            report += "  \(cat.rawValue): \(sym)\(String(format: "%.2f", amt))\n"
        }
        report += "\nDAILY BREAKDOWN\n"
        let dfmt = DateFormatter(); dfmt.dateStyle = .medium
        for entry in entries where !entry.expenses.isEmpty || !entry.topPriorities.isEmpty {
            report += "\n\(dfmt.string(from: entry.date))\n"
            if !entry.topPriorities.isEmpty {
                report += "  Priorities: \(entry.topPriorities.filter(\.isCompleted).count)/\(entry.topPriorities.count) done\n"
            }
        }
        return report
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
