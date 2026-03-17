import SwiftUI
import ComposableArchitecture

@main
struct LaunchpadApp: App {
    var body: some Scene {
        WindowGroup {
            AppGridView(
                store: Store(initialState: AppGridFeature.State()) {
                    AppGridFeature()
                }
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        Settings {
            SettingsView(
                store: Store(initialState: SettingsFeature.State()) {
                    SettingsFeature()
                }
            )
        }
    }
}