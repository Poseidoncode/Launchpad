import SwiftUI
import ComposableArchitecture

@main
struct LaunchpadApp: App {
    // Single shared store — both WindowGroup and Settings observe
    // slices of the same RootFeature state, so Settings changes
    // propagate to AppGrid via RootFeature's reducer.
    let rootStore = Store(initialState: RootFeature.State()) {
        RootFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppGridView(
                store: rootStore.scope(state: \.appGrid, action: \.appGrid)
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView(
                store: rootStore.scope(state: \.settings, action: \.settings)
            )
        }
    }
}
