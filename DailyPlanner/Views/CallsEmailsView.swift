import SwiftUI

struct CallsEmailsView: View {
    @EnvironmentObject var vm: PlannerViewModel
    @State private var showAddSheet = false
    @State private var editingTask: PlannerTask? = nil
    @State private var showPopper = false

    var entry: DailyEntry { vm.currentEntry }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(section: .callsEmails,
                                  subtitle: "Track your calls and emails",
                                  completedCount: entry.callsEmails.filter(\.isCompleted).count,
                                  totalCount: entry.callsEmails.count)

                    if !vm.isFuture {
                        AddButton(label: "Add Call or Email", color: AppSection.callsEmails.color) {
                            showAddSheet = true
                        }
                        .padding(.horizontal, 16).padding(.top, 12)
                    }

                    if entry.callsEmails.isEmpty {
                        EmptySectionView(section: .callsEmails,
                                         message: "Add calls and emails you need to make today")
                    } else {
                        ForEach(entry.callsEmails) { task in
                            TaskRowCard(
                                task: task,
                                color: AppSection.callsEmails.color,
                                onToggle: { vm.toggleCallEmail(task) },
                                onEdit: vm.isFuture ? nil : { editingTask = task }
                            )
                            .padding(.horizontal, 16).padding(.vertical, 3)
                        }
                    }

                    if !entry.callsEmails.isEmpty {
                        ProgressSection(completed: entry.callsEmails.filter(\.isCompleted).count,
                                        total: entry.callsEmails.count,
                                        color: AppSection.callsEmails.color)
                            .padding(.horizontal, 16).padding(.top, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(
                    title: "Add Call or Email",
                    placeholder: "Who to call or email?",
                    accentColor: AppSection.callsEmails.color,
                    icon: AppSection.callsEmails.icon
                ) { text in
                    vm.addCallEmail(text)
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    accentColor: AppSection.callsEmails.color,
                    icon: AppSection.callsEmails.icon
                ) { newTitle in
                    vm.updateCallEmail(task, newTitle: newTitle)
                }
            }

            if showPopper {
                PartyPopperOverlay(isVisible: $showPopper)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: vm.callsEmailsCompletionPercent) { newVal in
            if newVal == 100 { showPopper = true }
        }
    }
}
