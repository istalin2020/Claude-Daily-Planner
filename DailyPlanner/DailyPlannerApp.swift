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
        // Guarantee a synchronous flush whenever the app leaves the foreground.
        // This catches the window between a Xcode "Run" kill and the next launch,
        // as well as any normal home-button / app-switcher backgrounding.
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                viewModel.saveDataNow()
                viewModel.saveSettings()
            }
        }
    }
}
