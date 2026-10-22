import SwiftUI

// MARK: - My Schedule page
//
// Three cards, each usable right here:
//   • Today's Schedule — a timeline of the day's blocks with empty 9 AM /
//     12 PM / 3 PM / 6 PM slots; tap a slot to plan it, tick a block done.
//   • Appointments — today's appointments, or an Add button when there are
//     none.
//   • Subscriptions — the next payments with logo, amount and due date.
// The card headers open the full pages.

private func sc(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r / 255, green: g / 255, blue: b / 255)
}

private enum ScheduleStyle {
    static let blocks   = sc(112, 84, 232)
    static let appts    = sc(20, 170, 165)
    static let subs     = sc(98, 72, 225)
    static let card     = Color.adaptive(light: .white, dark: UIColor(white: 0.13, alpha: 1))
    static let inner    = Color.adaptive(light: UIColor(white: 1, alpha: 0.9),
                                         dark: UIColor(white: 1, alpha: 0.06))
}

struct ScheduleHubView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager

    /// The block form, opened at this start time.
    @State private var newBlockAt: BlockSlot? = nil
    @State private var showAddAppointment = false

    struct BlockSlot: Identifiable {
        let time: String
        var id: String { time }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                TodayScheduleCard(onAdd: { newBlockAt = BlockSlot(time: $0) },
                                  onOpen: { open(.dailySchedule) })
                AppointmentsCard(onAdd: { showAddAppointment = true },
                                 onOpen: { open(.appointments) })
                SubscriptionsCard(onOpen: { open(.subscriptions) })
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .sheet(item: $newBlockAt) { slot in
            AddScheduleBlockSheet(startTime: slot.time) { vm.addScheduleBlock($0) }
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentSheet { vm.addAppointment($0) }
        }
    }

    private func open(_ section: AppSection) {
        withAnimation(.easeInOut(duration: 0.25)) { vm.selectedSection = section }
    }
}

// MARK: - Card chrome

/// Soft tinted card with an icon tile, title, a status line, an optional
/// trailing button, and a white inner panel.
private struct ScheduleCard<Trailing: View, Content: View>: View {
    let color: Color
    let icon: String
    let title: String
    let status: String
    let detail: String
    let onOpen: () -> Void
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(color)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            (Text(status).fontWeight(.semibold)
                             + Text(detail.isEmpty ? "" : "  ·  \(detail)"))
                                .font(.system(size: 13.5))
                                .foregroundColor(.secondary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                trailing

                Button(action: onOpen) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 20, height: 36)
                }
                .buttonStyle(PlainButtonStyle())
            }

            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18).fill(ScheduleStyle.inner))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [color.opacity(0.08), color.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .background(RoundedRectangle(cornerRadius: 24).fill(ScheduleStyle.card))
        )
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(color.opacity(0.16), lineWidth: 1))
        .shadow(color: color.opacity(0.06), radius: 10, y: 4)
    }
}

/// A tinted "+ Add …" capsule.
private struct AddPill: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(Capsule().fill(color.opacity(0.13)))
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Today's Schedule

private struct TodayScheduleCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    let onAdd: (String) -> Void
    let onOpen: () -> Void

    /// The empty slots offered when the day has room.
    private static let defaultSlots = ["9:00 AM", "12:00 PM", "3:00 PM", "6:00 PM"]

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    private static func minutes(_ t: String) -> Int {
        guard let d = parser.date(from: t) else { return 0 }
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private enum Row: Identifiable {
        case block(ScheduleBlock)
        case empty(String)
        var id: String {
            switch self {
            case .block(let b): return b.id.uuidString
            case .empty(let t): return "slot-" + t
            }
        }
        var time: String {
            switch self {
            case .block(let b): return b.startTime
            case .empty(let t): return t
            }
        }
    }

    /// The day's blocks in time order, with the default slots filling any
    /// hour that's still free, so there's always somewhere to tap.
    private var rows: [Row] {
        let blocks = vm.currentEntry.dailySchedule
        let taken = Set(blocks.map { Self.minutes($0.startTime) / 60 })
        var rows = blocks.map { Row.block($0) }
        for slot in Self.defaultSlots where !taken.contains(Self.minutes(slot) / 60) {
            rows.append(.empty(slot))
        }
        return rows.sorted { Self.minutes($0.time) < Self.minutes($1.time) }
    }

    /// The next free half hour today, or 9 AM on other days.
    private var nextSlot: String {
        guard vm.isToday else { return "9:00 AM" }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let mins = (now.hour ?? 9) * 60 + (now.minute ?? 0)
        return AddScheduleBlockSheet.slots.first { Self.minutes($0) > mins } ?? "9:00 AM"
    }

    var body: some View {
        let color = ScheduleStyle.blocks
        let blocks = vm.currentEntry.dailySchedule
        let open = blocks.filter { !$0.isCompleted }.count
        let all = rows
        let shown = Array(all.prefix(6))

        ScheduleCard(color: color, icon: "calendar.badge.clock",
                     title: vm.isToday ? "Today's Schedule" : "Day's Schedule",
                     status: blocks.isEmpty ? "No blocks yet" : "\(blocks.count) block\(blocks.count == 1 ? "" : "s")",
                     detail: blocks.isEmpty ? "Plan your day" : (open == 0 ? "All done" : "\(open) to go"),
                     onOpen: onOpen) {
            AddPill(title: "Add Block", color: color) { onAdd(nextSlot) }
        } content: {
            VStack(spacing: 8) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, row in
                    HStack(spacing: 10) {
                        // Timeline dot and rail.
                        VStack(spacing: 0) {
                            Circle()
                                .fill(rowIsDone(row) ? color : color.opacity(0.25))
                                .frame(width: 9, height: 9)
                            if i < shown.count - 1 {
                                Rectangle()
                                    .fill(color.opacity(0.15))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 10)

                        Text(row.time)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)

                        switch row {
                        case .block(let b): blockRow(b, color: color)
                        case .empty(let t): emptyRow(t)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                if all.count > shown.count {
                    Button(action: onOpen) {
                        Text("+\(all.count - shown.count) more")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(color)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func rowIsDone(_ row: Row) -> Bool {
        if case .block(let b) = row { return b.isCompleted }
        return false
    }

    private func blockRow(_ b: ScheduleBlock, color: Color) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(b.activity)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(b.isCompleted ? .secondary : .primary)
                    .strikethrough(b.isCompleted, color: .secondary)
                    .lineLimit(1)
                Text("until \(b.endTime)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.snappy) { vm.toggleScheduleBlock(b) }
            } label: {
                Image(systemName: b.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(b.isCompleted ? color : .secondary.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
    }

    private func emptyRow(_ time: String) -> some View {
        Button { onAdd(time) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                Text("Add a block").font(.system(size: 14))
                Spacer()
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Appointments

private struct AppointmentsCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    let onAdd: () -> Void
    let onOpen: () -> Void

    private static let time: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    var body: some View {
        let color = ScheduleStyle.appts
        let appts = vm.currentEntry.appointments.sorted { $0.time < $1.time }
        let next = appts.first { !$0.isCompleted }
        let when = vm.isToday ? "today" : "this day"

        ScheduleCard(color: color, icon: "clock.fill", title: "Appointments",
                     status: appts.isEmpty ? "None \(when)" : "\(appts.count) \(when)",
                     detail: appts.isEmpty ? "Tap to add"
                        : (next.map { "Next \(Self.time.string(from: $0.time))" } ?? "All done"),
                     onOpen: onOpen) {
            if !appts.isEmpty { AddPill(title: "Add", color: color, action: onAdd) }
        } content: {
            if appts.isEmpty {
                HStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(color.opacity(0.45))
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white, color)
                            .offset(x: 6, y: 4)
                    }
                    .frame(width: 56, height: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No appointments \(when)")
                            .font(.system(size: 15, weight: .bold))
                        Text("Keep your day organized")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 4)
                    AddPill(title: "Add", color: color, action: onAdd)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(appts.prefix(3)) { a in
                        HStack(spacing: 10) {
                            Text(Self.time.string(from: a.time))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(color)
                                .frame(width: 70, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(a.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(a.isCompleted ? .secondary : .primary)
                                    .strikethrough(a.isCompleted, color: .secondary)
                                    .lineLimit(1)
                                if !a.location.isEmpty {
                                    Label(a.location, systemImage: "mappin")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 4)
                            Button {
                                withAnimation(.snappy) { vm.toggleAppointment(a) }
                            } label: {
                                Image(systemName: a.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(a.isCompleted ? color : .secondary.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    if appts.count > 3 {
                        Button(action: onOpen) {
                            Text("+\(appts.count - 3) more")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(color)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Subscriptions

private struct SubscriptionsCard: View {
    @EnvironmentObject var vm: PlannerViewModel
    @EnvironmentObject var pro: ProManager
    let onOpen: () -> Void

    private static let date: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    var body: some View {
        let color = ScheduleStyle.subs
        let subs = pro.isPro ? vm.allSubscriptions : []
        // Payments due within the next month count as upcoming.
        let upcoming = subs.filter { $0.daysUntilDue <= 31 }
        let shown = Array((upcoming.isEmpty ? subs : upcoming).prefix(2))

        ScheduleCard(color: color, icon: "arrow.triangle.2.circlepath", title: "Subscriptions",
                     status: !pro.isPro ? "Every renewal from Gmail"
                        : (upcoming.isEmpty ? (subs.isEmpty ? "None tracked yet" : "Nothing due this month")
                           : "\(upcoming.count) upcoming payment\(upcoming.count == 1 ? "" : "s")"),
                     detail: "",
                     onOpen: onOpen) {
            if !pro.isPro { ProInlineBadge() }
        } content: {
            if !pro.isPro {
                Button(action: onOpen) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 20))
                            .foregroundColor(color)
                        Text("See every subscription and its next payment, found from your Gmail.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else if shown.isEmpty {
                Button(action: onOpen) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(color)
                        Text("Connect Gmail or add a subscription to see its next payment.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                VStack(spacing: 10) {
                    ForEach(shown) { sub in
                        Button(action: onOpen) { row(sub, color: color) }
                            .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func row(_ sub: Subscription, color: Color) -> some View {
        let days = sub.daysUntilDue
        let due: String = days <= 0 ? "Due today" : (days == 1 ? "Due tomorrow" : "Due in \(days) days")

        return HStack(spacing: 10) {
            BrandTile(sub: sub, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(sub.planName ?? "\(sub.cycle.rawValue) plan")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vm.settings.currency.symbol)\(String(format: "%.2f", sub.amount))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(due)
                    .font(.system(size: 11.5))
                    .foregroundColor(days <= 2 ? .orange : .secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                Text(Self.date.string(from: sub.nextDue))
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.12)))
        }
    }
}
