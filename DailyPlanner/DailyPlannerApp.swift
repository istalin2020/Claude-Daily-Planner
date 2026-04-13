import SwiftUI

@main
struct DailyPlannerApp: App {
    @StateObject private var viewModel = PlannerViewModel()
    @StateObject private var proManager = ProManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(proManager)
                .preferredColorScheme(viewModel.settings.isDarkMode ? .dark : .light)
                .tint(viewModel.settings.themeColor.primary)
                // Handle deep links for accepting shared task lists.
                // Two formats are supported:
                //   New (CloudKit live sync): dailyplanner://accept-share?token=X&name=Y&section=Z
                //   Legacy (base64 payload):  dailyplanner://accept-share?data=<base64>
                // Register the "dailyplanner" URL scheme in Xcode → Target → Info → URL Types.
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "dailyplanner",
                          url.host?.lowercased() == "accept-share",
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    else { return }

                    let items = components.queryItems ?? []

                    if let tokenItem = items.first(where: { $0.name == "token" }),
                       let token = tokenItem.value, !token.isEmpty {
                        // New format — fetch live data from CloudKit
                        let name    = items.first(where: { $0.name == "name"    })?.value ?? ""
                        let section = items.first(where: { $0.name == "section" })?.value ?? ""
                        viewModel.acceptSharedListFromToken(
                            shareToken : token,
                            senderName : name,
                            sectionRaw : section
                        )
                    } else if let dataParam = items.first(where: { $0.name == "data" }),
                              let encoded   = dataParam.value {
                        // Legacy format — decode base64 payload directly
                        viewModel.acceptSharedList(fromData: encoded)
                    }
                }
                // Monthly carry-forward prompt — shown once at the start of each new month.
                .sheet(isPresented: $viewModel.showCarryForwardPrompt) {
                    if let amounts = viewModel.pendingCarryForwardAmounts {
                        CarryForwardSheet(
                            monthLabel  : amounts.monthLabel,
                            balance     : amounts.balance,
                            savings     : amounts.savings,
                            currencySymbol: viewModel.settings.currency.symbol
                        ) { carryBalance, carrySavings in
                            viewModel.applyCarryForward(carryBalance: carryBalance, carrySavings: carrySavings)
                        } onSkip: {
                            viewModel.applyCarryForward(carryBalance: false, carrySavings: false)
                        }
                        .environmentObject(viewModel)
                    }
                }
                // In-app banner for accepted shared lists
                .overlay(alignment: .top) {
                    if let info = viewModel.lastAcceptedShareInfo {
                        ShareAcceptedBanner(info: info) {
                            viewModel.lastAcceptedShareInfo = nil
                        }
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.35), value: viewModel.lastAcceptedShareInfo != nil)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                viewModel.lastAcceptedShareInfo = nil
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: viewModel.lastAcceptedShareInfo != nil)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.checkRolloverIfNeeded()
                viewModel.syncHealthKitForToday()
                viewModel.checkMonthlyCarryForward()
                // Refresh received shared lists from CloudKit every time the app
                // comes to the foreground so recipients always see the latest tasks.
                viewModel.refreshReceivedSharedLists()
                // Process any tasks/water-glass actions queued by Siri Shortcuts.
                viewModel.processPendingShortcutActions()
            case .background, .inactive:
                viewModel.saveDataNow()
                viewModel.saveSettings()
            default:
                break
            }
        }
    }
}

// MARK: - Carry Forward Sheet

struct CarryForwardSheet: View {
    @Environment(\.dismiss) private var dismiss

    let monthLabel     : String
    let balance        : Double
    let savings        : Double
    let currencySymbol : String
    let onConfirm      : (Bool, Bool) -> Void
    let onSkip         : () -> Void

    @State private var carryBalance = true
    @State private var carrySavings = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header banner
                VStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                    Text("New Month Started!")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Would you like to carry forward from \(monthLabel)?")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.65, blue: 0.35), Color(red: 0.0, green: 0.45, blue: 0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

                Form {
                    // Balance carry-forward
                    Section {
                        Toggle(isOn: $carryBalance) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(balance >= 0
                                              ? Color(red: 0.1, green: 0.65, blue: 0.35).opacity(0.12)
                                              : Color.red.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: balance >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                                        .foregroundColor(balance >= 0 ? Color(red: 0.1, green: 0.65, blue: 0.35) : .red)
                                        .font(.system(size: 18))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Carry Forward Balance")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("\(balance >= 0 ? "+" : "")\(currencySymbol)\(String(format: "%.2f", balance))")
                                        .font(.system(size: 13))
                                        .foregroundColor(balance >= 0
                                                         ? Color(red: 0.1, green: 0.65, blue: 0.35) : .red)
                                }
                            }
                        }
                        .tint(Color(red: 0.1, green: 0.65, blue: 0.35))
                    } footer: {
                        Text("Adds the previous month's net balance as an income entry for today.")
                            .font(.caption)
                    }

                    // Savings carry-forward
                    if savings > 0 {
                        Section {
                            Toggle(isOn: $carrySavings) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.3, green: 0.5, blue: 0.95).opacity(0.12))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "banknote.fill")
                                            .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.95))
                                            .font(.system(size: 18))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Carry Forward Savings")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("+\(currencySymbol)\(String(format: "%.2f", savings))")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.95))
                                    }
                                }
                            }
                            .tint(Color(red: 0.3, green: 0.5, blue: 0.95))
                        } footer: {
                            Text("Adds the previous month's saved amount as a savings entry for today.")
                                .font(.caption)
                        }
                    }

                    // Action buttons
                    Section {
                        Button {
                            onConfirm(carryBalance, carrySavings && savings > 0)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Carry Forward")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(red: 0.1, green: 0.65, blue: 0.35))

                        Button(role: .destructive) {
                            onSkip()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Start Fresh — Don't Carry Forward")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Later") {
                        // Dismiss without recording — will re-appear next launch.
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Share Accepted Banner

struct ShareAcceptedBanner: View {
    let info    : PlannerViewModel.ShareAcceptedInfo
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: info.isUpdate ? "arrow.triangle.2.circlepath.circle.fill" : "square.and.arrow.down.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.isUpdate ? "Shared List Updated" : "New Shared Tasks!")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("\(info.senderName) shared \(info.taskCount) task\(info.taskCount == 1 ? "" : "s") in \(info.sectionName)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.45, green: 0.25, blue: 0.85))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        )
        .padding(.horizontal, 16)
    }
}
