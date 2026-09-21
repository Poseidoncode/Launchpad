import XCTest
import ComposableArchitecture
@testable import Launchpad

@MainActor
final class AppGridTests: XCTestCase {
    func testSwapAppsUpdatesOrderAndSaves() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2]
        initialState.folders = []
        initialState.appOrder = [app1.id, app2.id]
        initialState.rebuildOrderIndexMap()

        let store = TestStore(
            initialState: initialState
        ) {
            AppGridFeature()
        }

        await store.send(AppGridFeature.Action.swapApps(id: app1.id, with: app2.id)) {
            $0.appOrder = [app2.id, app1.id]
            $0.rebuildOrderIndexMap()
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testMoveAppInsertsAfterTargetWhenMovingForward() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        let app3 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "App3")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2, app3]
        initialState.folders = []
        initialState.appOrder = [app1.id, app2.id, app3.id]
        initialState.rebuildOrderIndexMap()

        let store = TestStore(
            initialState: initialState
        ) {
            AppGridFeature()
        }

        await store.send(AppGridFeature.Action.moveApp(id: app1.id, after: app2.id)) {
            $0.appOrder = [app2.id, app1.id, app3.id]
            $0.rebuildOrderIndexMap()
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testMoveAppInsertsAfterTargetWhenMovingBackward() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        let app3 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "App3")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2, app3]
        initialState.folders = []
        initialState.appOrder = [app1.id, app2.id, app3.id]
        initialState.rebuildOrderIndexMap()

        let store = TestStore(
            initialState: initialState
        ) {
            AppGridFeature()
        }

        await store.send(AppGridFeature.Action.moveApp(id: app3.id, after: app1.id)) {
            $0.appOrder = [app1.id, app3.id, app2.id]
            $0.rebuildOrderIndexMap()
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }
    
    func testAppsLoadedNormalizesSavedOrder() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        let app3 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "App3")
        let staleID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        
        var initialState = AppGridFeature.State()
        initialState.appOrder = [app2.id, staleID]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(AppGridFeature.Action.appsLoaded([app1, app2, app3])) {
            $0.isLoading = false
            $0.apps = [app1, app2, app3]
            $0.rebuildAppMap()
            $0.appOrder = [app2.id, app1.id, app3.id]
            $0.rebuildOrderIndexMap()
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }
    
    func testSearchFiltersApps() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Mail")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Safari")
        let app3 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Messages")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2, app3]
        initialState.folders = []
        initialState.appOrder = [app1.id, app2.id, app3.id]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        // When
        await store.send(.setSearchQuery("mail")) {
            $0.searchQuery = "mail"
            $0.updateDisplayedApps()
        }

        // Then
        let displayed = store.state.displayedApps
        XCTAssertEqual(displayed.count, 1)
        XCTAssertEqual(displayed.first?.name, "Mail")
    }

    func testSearchClears() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Mail")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.appOrder = [app1.id]
        initialState.searchQuery = "mail"

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.setSearchQuery("")) {
            $0.searchQuery = ""
            $0.updateDisplayedApps()
        }

        XCTAssertEqual(store.state.displayedApps.count, 1)
    }

    func testCreateFolder() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.appOrder = [app1.id]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.createFolder(name: "Games", appIDs: [app1.id]))
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()

        XCTAssertEqual(store.state.folders.count, 1)
        XCTAssertEqual(store.state.folders[0].name, "Games")
        XCTAssertEqual(store.state.folders[0].appIDs, [app1.id])
    }

    func testDeleteFolder() async {
        let folder = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Games")

        var initialState = AppGridFeature.State()
        initialState.folders = [folder]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.deleteFolder(id: folder.id)) {
            $0.folders = []
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testRenameFolderUniquifiesOnCollision() async {
        let folder1 = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Games")
        let folder2 = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, name: "Work")

        var initialState = AppGridFeature.State()
        initialState.folders = [folder1, folder2]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.renameFolder(id: folder2.id, name: "Games")) {
            $0.folders[1].name = "Games 2"
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testRenameApp() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Zoo")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.appOrder = [app1.id]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.renameApp(bundleIdentifier: "com.test.zoo", newName: "My Zoo")) {
            $0.preferences.customAppNames["com.test.zoo"] = "My Zoo"
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testCustomNameAppearsInDisplay() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Zoo")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.folders = []
        initialState.appOrder = [app1.id]
        initialState.preferences.customAppNames = ["com.test.zoo": "My Zoo"]
        initialState.rebuildAppMap()
        initialState.updateDisplayedApps()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        XCTAssertEqual(store.state.displayedApps.first?.name, "My Zoo")
    }

    func testAddAppToFolder() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let folder = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Folder")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.folders = [folder]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.addAppToFolder(appID: app1.id, folderID: folder.id)) {
            $0.folders[0].appIDs = [app1.id]
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testRemoveAppToFolderDoesNotDuplicate() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let folder = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Folder", appIDs: [app1.id])

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.folders = [folder]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        // Add again — should not duplicate
        await store.send(.addAppToFolder(appID: app1.id, folderID: folder.id))
        // No state change expected since contains check prevents duplicate
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testRemoveAppFromFolder() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let folder = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Folder", appIDs: [app1.id])

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.folders = [folder]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.removeAppFromFolder(appID: app1.id, folderID: folder.id)) {
            $0.folders[0].appIDs = []
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testErrorBannerDismissAfterSet() async {
        let store = TestStore(initialState: AppGridFeature.State()) {
            AppGridFeature()
        }

        await store.send(.setErrorMessage("Test error")) {
            $0.errorMessage = "Test error"
        }

        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }

    func testToggleEditMode() async {
        let store = TestStore(initialState: AppGridFeature.State()) {
            AppGridFeature()
        }

        await store.send(.toggleEditMode) {
            $0.isEditMode = true
        }

        await store.send(.toggleEditMode) {
            $0.isEditMode = false
        }
    }

    func testOpenCloseFolder() async {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        var initialState = AppGridFeature.State()
        initialState.apps = []
        initialState.folders = [Folder(id: folderID, name: "Test")]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.openFolder(folderID)) {
            $0.openFolderID = folderID
        }

        await store.send(.closeFolder) {
            $0.openFolderID = nil
        }
    }

    func testAppsLoadedCleansStaleFolderAppIDs() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let staleAppID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

        var initialState = AppGridFeature.State()
        initialState.folders = [Folder(name: "Folder", appIDs: [app1.id, staleAppID])]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appsLoaded([app1])) {
            $0.isLoading = false
            $0.apps = [app1]
            $0.rebuildAppMap()
            $0.appOrder = [app1.id]
            $0.rebuildOrderIndexMap()
            $0.updateDisplayedApps()
            // staleAppID removed from folder
            $0.folders[0].appIDs = [app1.id]
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testCreateFolderAutoUniquifies() async {
        let folder1 = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "New Folder")

        var initialState = AppGridFeature.State()
        initialState.folders = [folder1]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.createFolder(name: "New Folder", appIDs: []))
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()

        XCTAssertEqual(store.state.folders.count, 2)
        XCTAssertEqual(store.state.folders[1].name, "New Folder 2")
    }

    func testCreateFolderUniquifiesWithGap() async {
        // "New Folder" and "New Folder 3" exist (no "New Folder 2").
        // Creating "New Folder" should produce "New Folder 2", not "New Folder 3".
        let folder1 = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "New Folder")
        let folder2 = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, name: "New Folder 3")

        var initialState = AppGridFeature.State()
        initialState.folders = [folder1, folder2]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.createFolder(name: "New Folder", appIDs: []))
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()

        XCTAssertEqual(store.state.folders.count, 3)
        XCTAssertEqual(store.state.folders[2].name, "New Folder 2")
    }

    func testRenameToEmptyIgnored() async {
        let folder = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Work")

        var initialState = AppGridFeature.State()
        initialState.folders = [folder]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        // Empty rename should be ignored
        await store.send(.renameFolder(id: folder.id, name: "   "))
        // No state change expected
        XCTAssertEqual(store.state.folders[0].name, "Work")
    }

    func testRenameAppTruncatesLongName() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Zoo")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.appOrder = [app1.id]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        let longName = String(repeating: "A", count: 300)
        await store.send(.renameApp(bundleIdentifier: "com.test.zoo", newName: longName))
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()

        let saved = store.state.preferences.customAppNames["com.test.zoo"] ?? ""
        XCTAssertEqual(saved.count, 256, "Custom name should be truncated to 256 characters")
    }

    func testFlushPendingSave() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")

        var initialState = AppGridFeature.State()
        initialState.apps = [app1]
        initialState.appOrder = [app1.id]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.flushPendingSave)
        // flushPendingSave cancels the "prefs-save" cancellation ID
        // No .savePreferences effect is expected since flush writes directly
    }

    func testAppsLoadedClearsLoadingByDefault() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")

        var initialState = AppGridFeature.State()
        initialState.isLoading = true
        initialState.appOrder = [app1.id]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appsLoaded([app1])) {
            $0.isLoading = false
            $0.apps = [app1]
            $0.rebuildAppMap()
            $0.updateDisplayedApps()
        }
    }

    func testSilentAppsLoadedPreservesLoading() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")

        var initialState = AppGridFeature.State()
        initialState.isLoading = true
        initialState.appOrder = [app1.id]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        // isLoading deliberately absent from the expected mutation: a background
        // scan must not end a concurrent reload's spinner.
        await store.send(.appsLoaded([app1], clearsLoading: false)) {
            $0.apps = [app1]
            $0.rebuildAppMap()
            $0.updateDisplayedApps()
        }
    }

    func testRefreshIconsAfterScreenChangeIsSilent() async {
        let store = TestStore(initialState: AppGridFeature.State()) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        // No state-change closure: asserts the send itself mutates nothing —
        // in particular it must not set isLoading (no spinner for display changes).
        // The effect runs a real scan; skipInFlightEffects drains it.
        await store.send(.refreshIconsAfterScreenChange)
        await store.skipInFlightEffects()
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
