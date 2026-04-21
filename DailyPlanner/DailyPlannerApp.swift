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
