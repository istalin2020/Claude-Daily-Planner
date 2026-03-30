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
