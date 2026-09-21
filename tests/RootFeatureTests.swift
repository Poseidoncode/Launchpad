import XCTest
import ComposableArchitecture
@testable import Launchpad

@MainActor
final class RootFeatureTests: XCTestCase {
    // NOTE: preferences are always set explicitly below. `SettingsFeature.State`
    // initialises from UserDefaults, which the test runner shares across tests
    // in this process — leaked debounced saves from earlier tests may have
    // written junk there. Explicit prefs keep these tests deterministic.
    /// Columns only affect layout, so changing them must save without spawning
    /// a rescan effect. Exhaustivity is on: any extra effect (e.g. an icon
    /// rescan) fails this test.
    func testSettingsColumnsChangeSavesWithoutRescan() async {
        var initialState = RootFeature.State()
        initialState.settings.preferences = UserPreferences()
        initialState.appGrid.preferences = UserPreferences()
        let store = TestStore(initialState: initialState) {
            RootFeature()
        }

        await store.send(.settings(.setColumns(5))) {
            $0.settings.preferences.columns = 5
        }
        await store.receive(\.settings.savePreferences) {
            $0.appGrid.preferences.columns = 5
        }
        await store.receive(\.appGrid.savePreferences)
        await store.skipInFlightEffects()
    }

    /// Shrinking icons never needs higher-resolution bitmaps, so it must save
    /// without spawning a rescan effect.
    func testSettingsIconShrinkSavesWithoutRescan() async {
        var initialState = RootFeature.State()
        initialState.settings.preferences = UserPreferences(iconSize: 72)
        initialState.appGrid.preferences = UserPreferences(iconSize: 72)
        let store = TestStore(initialState: initialState) {
            RootFeature()
        }

        await store.send(.settings(.setIconSize(64))) {
            $0.settings.preferences.iconSize = 64
        }
        await store.receive(\.settings.savePreferences) {
            $0.appGrid.preferences.iconSize = 64
        }
        await store.receive(\.appGrid.savePreferences)
        await store.skipInFlightEffects()
    }

    /// Settings saves sync only layout fields, so a populated, filtered,
    /// custom-named `displayedApps` must pass through untouched. Exhaustivity
    /// is on: any recompute drift fails the receive assertion below.
    func testSettingsSaveLeavesDisplayedAppsUntouched() async {
        let mail = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Mail")
        let safari = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Safari")

        var initialState = RootFeature.State()
        initialState.settings.preferences = UserPreferences()
        initialState.appGrid.preferences = UserPreferences(customAppNames: ["com.test.mail": "My Mail"])
        initialState.appGrid.apps = [mail, safari]
        initialState.appGrid.appOrder = [mail.id, safari.id]
        initialState.appGrid.searchQuery = "mail"
        initialState.appGrid.rebuildOrderIndexMap()
        initialState.appGrid.updateDisplayedApps()
        XCTAssertEqual(initialState.appGrid.displayedApps.map(\.name), ["My Mail"])

        let store = TestStore(initialState: initialState) {
            RootFeature()
        }

        await store.send(.settings(.setColumns(5))) {
            $0.settings.preferences.columns = 5
        }
        await store.receive(\.settings.savePreferences) {
            $0.appGrid.preferences.columns = 5
        }
        await store.receive(\.appGrid.savePreferences)
        await store.skipInFlightEffects()

        XCTAssertEqual(store.state.appGrid.displayedApps.map(\.name), ["My Mail"])
    }

    private func makeApp(id: UUID, name: String) -> AppItem {
        AppItem(
            id: id,
            name: name,
            bundleIdentifier: "com.test.\(name.lowercased())",
            path: URL(fileURLWithPath: "/Applications/\(name).app")
        )
    }
}
