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
                // Handle dailyplanner://accept-share?data=<base64payload> deep links.
                // Register the "dailyplanner" URL scheme in Xcode → Target → Info → URL Types.
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "dailyplanner",
                          url.host?.lowercased() == "accept-share",
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let dataParam  = components.queryItems?.first(where: { $0.name == "data" }),
                          let encoded    = dataParam.value else { return }
                    viewModel.acceptSharedList(fromData: encoded)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.checkRolloverIfNeeded()
                viewModel.syncHealthKitForToday()
            case .background, .inactive:
                viewModel.saveDataNow()
                viewModel.saveSettings()
            default:
                break
            }
        }
    }
}
