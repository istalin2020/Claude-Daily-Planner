import SwiftUI

@main
struct DailyPlannerApp: App {
    @StateObject private var viewModel = PlannerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.settings.isDarkMode ? .dark : .light)
        }
    }
}
