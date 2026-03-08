import SwiftUI

@main
struct DailyPlannerApp: App {
    @StateObject private var viewModel = PlannerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.settings.isDarkMode ? .dark : .light)
        }
        // Sync HealthKit whenever the app enters the foreground so data is
        // always up-to-date regardless of which tab the user is viewing.
        // Also flush data to disk on every background/inactive transition.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
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
