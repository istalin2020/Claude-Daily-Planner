import WidgetKit
import SwiftUI

// MARK: - Shared data model for widget
struct WidgetEntry: TimelineEntry {
    let date: Date
    let tasksDone: Int
    let tasksTotal: Int
    let topPriorities: [String]
    let spending: Double
    let currencySymbol: String
    let steps: Int
    let waterGlasses: Int
    let waterGoal: Int
    let completionPercent: Int
}

// MARK: - Timeline Provider
struct DailyPlannerProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), tasksDone: 3, tasksTotal: 5,
                    topPriorities: ["Morning workout", "Review emails"],
                    spending: 0, currencySymbol: "$", steps: 4500,
                    waterGlasses: 5, waterGoal: 8, completionPercent: 60)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh at midnight and every 30 min
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let halfHour = Date().addingTimeInterval(1800)
        let nextRefresh = min(midnight, halfHour)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> WidgetEntry {
        let suiteName = "group.com.istalin.DailyPlanner"
        let defaults = UserDefaults(suiteName: suiteName)
        let today = Calendar.current.startOfDay(for: Date())
        let key = {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: today)
        }()

        var tasksDone = 0, tasksTotal = 0, steps = 0, waterGlasses = 0, waterGoal = 8
        var spending = 0.0, completionPercent = 0
        var topPriorities: [String] = []
        var currencySymbol = "$"

        if let data = defaults?.data(forKey: "widget_data"),
           let dict = try? JSONDecoder().decode(WidgetSharedData.self, from: data),
           dict.dateKey == key {
            tasksDone = dict.tasksDone
            tasksTotal = dict.tasksTotal
            topPriorities = dict.topPriorities
            spending = dict.spending
            currencySymbol = dict.currencySymbol
            steps = dict.steps
            waterGlasses = dict.waterGlasses
            waterGoal = dict.waterGoal
            completionPercent = tasksTotal > 0 ? Int(Double(tasksDone) / Double(tasksTotal) * 100) : 0
        }

        return WidgetEntry(date: today, tasksDone: tasksDone, tasksTotal: tasksTotal,
                           topPriorities: topPriorities, spending: spending,
                           currencySymbol: currencySymbol, steps: steps,
                           waterGlasses: waterGlasses, waterGoal: waterGoal,
                           completionPercent: completionPercent)
    }
}

// MARK: - Shared Data Model
struct WidgetSharedData: Codable {
    var dateKey: String
    var tasksDone: Int
    var tasksTotal: Int
    var topPriorities: [String]
    var spending: Double
    var currencySymbol: String
    var steps: Int
    var waterGlasses: Int
    var waterGoal: Int
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: WidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color(red: 0.45, green: 0.25, blue: 0.85))
                    .cornerRadius(6)
                Text("Planner")
                    .font(.system(size: 11, weight: .bold))
            }
            Spacer()
            Text("\(entry.completionPercent)%")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
            Text("\(entry.tasksDone)/\(entry.tasksTotal) tasks")
                .font(.caption2).foregroundColor(.secondary)
            HStack(spacing: 8) {
                Label("\(entry.steps < 1000 ? "\(entry.steps)" : String(format: "%.1fk", Double(entry.steps)/1000))", systemImage: "shoeprints.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                Label("\(entry.waterGlasses)/\(entry.waterGoal)", systemImage: "drop.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.cyan)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: WidgetEntry
    var body: some View {
        HStack(spacing: 0) {
            // Left: completion ring
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(entry.completionPercent) / 100)
                        .stroke(Color(red: 0.45, green: 0.25, blue: 0.85),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.completionPercent)%")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(width: 60, height: 60)
                Text("\(entry.tasksDone)/\(entry.tasksTotal) tasks")
                    .font(.system(size: 9)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().padding(.vertical, 8)

            // Right: top priorities
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.85))
                if entry.topPriorities.isEmpty {
                    Text("No priorities set")
                        .font(.caption2).foregroundColor(.secondary).italic()
                } else {
                    ForEach(entry.topPriorities.prefix(3), id: \.self) { p in
                        HStack(spacing: 4) {
                            Circle().fill(Color(red: 0.45, green: 0.25, blue: 0.85))
                                .frame(width: 4, height: 4)
                            Text(p).font(.system(size: 10)).lineLimit(1)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    Label(entry.currencySymbol + String(format: "%.0f", entry.spending), systemImage: "dollarsign.circle.fill")
                        .font(.system(size: 9)).foregroundColor(.green)
                    Label("\(entry.waterGlasses)/\(entry.waterGoal)", systemImage: "drop.fill")
                        .font(.system(size: 9)).foregroundColor(.cyan)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 8)
        }
        .padding(14)
        .background(Color(.systemBackground))
    }
}

// MARK: - Widget Configuration
struct DailyPlannerWidget: Widget {
    let kind = "DailyPlannerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPlannerProvider()) { entry in
            DailyPlannerWidgetEntryView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("Daily Planner")
        .description("See today's task progress and priorities at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyPlannerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry
    var body: some View {
        switch family {
        case .systemSmall: SmallWidgetView(entry: entry)
        default:           MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle
@main
struct DailyPlannerWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyPlannerWidget()
    }
}
