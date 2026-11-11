import SwiftUI

struct RecurrencePicker: View {
    @Binding var recurrence: Recurrence

    var body: some View {
        Picker("Repeat", selection: $recurrence) {
            ForEach(Recurrence.allCases) { r in
                Label(r.rawValue, systemImage: r.icon).tag(r)
            }
        }
    }
}

struct RecurrenceBadge: View {
    let recurrence: Recurrence
    var body: some View {
        if recurrence != .none {
            Label(recurrence.rawValue, systemImage: recurrence.icon)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.purple.opacity(0.12))
                .foregroundColor(.purple)
                .cornerRadius(6)
        }
    }
}
