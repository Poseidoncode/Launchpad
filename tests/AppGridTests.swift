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
            $0.appOrder = [app2.id, staleID, app1.id, app3.id]
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

    func testSearchFindsAppsInsideFolders() async {
        let mail = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Mail")
        let safari = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Safari")
        let folder = Folder(name: "Work", appIDs: [mail.id])

        var initialState = AppGridFeature.State()
        initialState.apps = [mail, safari]
        initialState.folders = [folder]
        initialState.appOrder = [mail.id, safari.id]
        initialState.rebuildOrderIndexMap()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.setSearchQuery("mail")) {
            $0.searchQuery = "mail"
            $0.updateDisplayedApps()
        }
        XCTAssertEqual(store.state.displayedApps.map(\.id), [mail.id])
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

    func testAppWasTrashedRemovesAppFromSavedMembership() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        let folder = Folder(name: "Folder", appIDs: [app1.id])
        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2]
        initialState.folders = [folder]
        initialState.appOrder = [app1.id, app2.id]
        initialState.rebuildAppMap()
        initialState.rebuildOrderIndexMap()
        initialState.updateDisplayedApps()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appWasTrashed(app1.id)) {
            $0.apps = [app2]
            $0.rebuildAppMap()
            $0.appOrder = [app2.id]
            $0.rebuildOrderIndexMap()
            // The folder held only the trashed app, so it is dropped too.
            $0.folders = []
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testCreateFolderClearsSearchSoFolderRemainsVisible() async {
        var initialState = AppGridFeature.State()
        initialState.searchQuery = "mail"
        initialState.updateDisplayedApps()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.createFolder(name: "New Folder", appIDs: []))
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()

        XCTAssertEqual(store.state.searchQuery, "")
        XCTAssertEqual(store.state.folders.map(\.name), ["New Folder"])
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

    func testSearchMatchesCustomNames() async {
        let app = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Safari")
        var initialState = AppGridFeature.State()
        initialState.apps = [app]
        initialState.appOrder = [app.id]
        initialState.preferences.customAppNames = [app.bundleIdentifier: "Browser"]
        initialState.rebuildOrderIndexMap()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.setSearchQuery("browser")) {
            $0.searchQuery = "browser"
            $0.updateDisplayedApps()
        }
        XCTAssertEqual(store.state.displayedApps.map(\.name), ["Browser"])
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

    func testAddAppToFolderMovesAppOutOfItsPreviousFolder() async {
        let app = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let source = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Source", appIDs: [app.id])
        let destination = Folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, name: "Destination")

        var initialState = AppGridFeature.State()
        initialState.apps = [app]
        initialState.folders = [source, destination]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.addAppToFolder(appID: app.id, folderID: destination.id)) {
            $0.folders[0].appIDs = []
            $0.folders[1].appIDs = [app.id]
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
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

        // Add again — should not duplicate or trigger an unnecessary disk write.
        await store.send(.addAppToFolder(appID: app1.id, folderID: folder.id))
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
            // Last app out: the folder itself is removed (classic behavior).
            $0.folders = []
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

    func testSuccessfulLaunchDismissesOpenFolder() async {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        var initialState = AppGridFeature.State()
        initialState.folders = [Folder(id: folderID, name: "Test")]
        initialState.openFolderID = folderID

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.launchResult(true, "App1")) {
            $0.openFolderID = nil
        }
    }

    func testMoveAppBeforeInsertsBeforeTarget() async {
        let ids = (1...3).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))! }
        var initialState = AppGridFeature.State()
        initialState.appOrder = ids
        initialState.rebuildOrderIndexMap()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        // Move last before first: [1,2,3] -> [3,1,2].
        await store.send(.moveAppBefore(id: ids[2], before: ids[0]))
        XCTAssertEqual(store.state.appOrder, [ids[2], ids[0], ids[1]])

        // No-op on self and unknown IDs.
        await store.send(.moveAppBefore(id: ids[0], before: ids[0]))
        await store.send(.moveAppBefore(id: UUID(), before: ids[0]))
        XCTAssertEqual(store.state.appOrder, [ids[2], ids[0], ids[1]])
    }

    func testMoveFolderAfterAndBefore() async {
        let f1 = Folder(name: "A")
        let f2 = Folder(name: "B")
        let f3 = Folder(name: "C")
        var initialState = AppGridFeature.State()
        initialState.folders = [f1, f2, f3]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.moveFolderAfter(id: f1.id, after: f3.id))
        XCTAssertEqual(store.state.folders.map(\.id), [f2.id, f3.id, f1.id])
        await store.send(.moveFolderBefore(id: f1.id, before: f2.id))
        XCTAssertEqual(store.state.folders.map(\.id), [f1.id, f2.id, f3.id])

        await store.send(.moveFolderAfter(id: f1.id, after: f1.id))
        await store.send(.moveFolderBefore(id: UUID(), before: f1.id))
        XCTAssertEqual(store.state.folders.map(\.id), [f1.id, f2.id, f3.id])
    }

    func testMoveAppInFolderAfterAndBefore() async {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let ids = (1...3).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))! }
        var initialState = AppGridFeature.State()
        initialState.folders = [Folder(id: folderID, name: "Test", appIDs: ids)]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.moveAppInFolderAfter(id: ids[0], after: ids[2], folderID: folderID))
        XCTAssertEqual(store.state.folders.first?.appIDs, [ids[1], ids[2], ids[0]])
        await store.send(.moveAppInFolderBefore(id: ids[0], before: ids[1], folderID: folderID))
        XCTAssertEqual(store.state.folders.first?.appIDs, [ids[0], ids[1], ids[2]])

        await store.send(.moveAppInFolderAfter(id: ids[0], after: ids[0], folderID: folderID))
        await store.send(.moveAppInFolderBefore(id: ids[0], before: ids[1], folderID: UUID()))
        XCTAssertEqual(store.state.folders.first?.appIDs, [ids[0], ids[1], ids[2]])
    }

    func testSetEditModeIsIdempotent() async {
        let store = TestStore(initialState: AppGridFeature.State()) {
            AppGridFeature()
        }

        await store.send(.setEditMode(true)) { $0.isEditMode = true }
        // No state change closure: already true must be a no-op.
        await store.send(.setEditMode(true))
        await store.send(.setEditMode(false)) { $0.isEditMode = false }
    }

    func testKeyboardSelectionClearsOnSearchAndFolderChanges() async {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let appID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        var initialState = AppGridFeature.State()
        initialState.folders = [Folder(id: folderID, name: "Test")]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.setKeyboardSelectedID(appID)) { $0.keyboardSelectedID = appID }
        await store.send(.setSearchQuery("x")) {
            $0.searchQuery = "x"
            $0.keyboardSelectedID = nil
        }
        await store.send(.setKeyboardSelectedID(appID)) { $0.keyboardSelectedID = appID }
        await store.send(.openFolder(folderID)) {
            $0.openFolderID = folderID
            $0.keyboardSelectedID = nil
        }
    }

    func testRemovingLastAppDeletesFolderAndClosesModal() async {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let appID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        var initialState = AppGridFeature.State()
        initialState.folders = [Folder(id: folderID, name: "Test", appIDs: [appID])]
        initialState.openFolderID = folderID

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.removeAppFromFolder(appID: appID, folderID: folderID))
        XCTAssertTrue(store.state.folders.isEmpty)
        XCTAssertNil(store.state.openFolderID)
    }

    func testTrashEmptyingFolderRemovesFolder() async {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let appID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let app = makeApp(id: appID, name: "App1")
        var initialState = AppGridFeature.State()
        initialState.apps = [app]
        initialState.appOrder = [appID]
        initialState.folders = [Folder(id: folderID, name: "Test", appIDs: [appID])]
        initialState.rebuildAppMap()
        initialState.rebuildOrderIndexMap()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        await store.send(.appWasTrashed(appID))
        XCTAssertTrue(store.state.folders.isEmpty)
        XCTAssertTrue(store.state.apps.isEmpty)
    }

    func testExternalAppsChangedIsSilent() async {
        let store = TestStore(initialState: AppGridFeature.State()) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        // No state-change closure: background directory refresh must not show
        // a spinner. The effect runs a real scan; skipInFlightEffects drains it.
        await store.send(.externalAppsChanged)
        await store.skipInFlightEffects()
        XCTAssertFalse(store.state.isLoading)
    }

    func testFailedLaunchKeepsOpenFolder() async {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        var initialState = AppGridFeature.State()
        initialState.folders = [Folder(id: folderID, name: "Test")]
        initialState.openFolderID = folderID

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        // Modal must stay open so the user can retry; the failure surfaces
        // as an error banner via the sent .setErrorMessage effect.
        await store.send(.launchResult(false, "App1"))
        XCTAssertEqual(store.state.openFolderID, folderID)
    }

    func testAppsLoadedPreservesUnavailableFolderAppIDsAndDeduplicatesMembership() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let staleAppID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

        var initialState = AppGridFeature.State()
        initialState.folders = [
            Folder(name: "Folder", appIDs: [app1.id, staleAppID, app1.id]),
            Folder(name: "Duplicate membership", appIDs: [app1.id])
        ]

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
            // Unavailable IDs are retained; duplicates are removed and the first folder wins.
            $0.folders[0].appIDs = [app1.id, staleAppID]
            $0.folders[1].appIDs = []
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testAppsLoadedPersistsFolderDeduplicationWhenOrderIsAlreadyValid() async {
        let app = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let staleID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        var initialState = AppGridFeature.State()
        initialState.appOrder = [app.id]
        initialState.rebuildOrderIndexMap()
        initialState.folders = [Folder(name: "Folder", appIDs: [app.id, staleID, app.id])]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appsLoaded([app])) {
            $0.isLoading = false
            $0.apps = [app]
            $0.rebuildAppMap()
            $0.folders[0].appIDs = [app.id, staleID]
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testAppsLoadedDeduplicatesCorruptedFolderIDs() async {
        let app = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let first = Folder(id: folderID, name: "First", appIDs: [app.id])
        let duplicate = Folder(id: folderID, name: "Duplicate", appIDs: [app.id])
        var initialState = AppGridFeature.State()
        initialState.appOrder = [app.id]
        initialState.rebuildOrderIndexMap()
        initialState.folders = [first, duplicate]

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appsLoaded([app])) {
            $0.isLoading = false
            $0.apps = [app]
            $0.rebuildAppMap()
            $0.folders = [first]
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testAppsLoadedDeduplicatesCorruptedSavedOrder() async {
        let app = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        var initialState = AppGridFeature.State()
        initialState.appOrder = [app.id, app.id]
        initialState.rebuildOrderIndexMap()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appsLoaded([app])) {
            $0.isLoading = false
            $0.apps = [app]
            $0.rebuildAppMap()
            $0.appOrder = [app.id]
            $0.rebuildOrderIndexMap()
            $0.updateDisplayedApps()
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

    func testMemoryPressureDropsStoredIconsWithoutLosingApps() async {
        var app = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        app.icon = NSImage(size: NSSize(width: 64, height: 64))

        var initialState = AppGridFeature.State()
        initialState.apps = [app]
        initialState.appOrder = [app.id]
        initialState.rebuildAppMap()
        initialState.rebuildOrderIndexMap()
        initialState.updateDisplayedApps()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.memoryPressureReceived)
        XCTAssertNil(store.state.apps.first?.icon)
        XCTAssertNil(store.state.displayedApps.first?.icon)
        XCTAssertNil(store.state.appMap[app.id]?.icon)
        XCTAssertEqual(store.state.apps.first?.id, app.id)
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

    func testAppWasTrashedKeepsUnrelatedEmptyFolder() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        let emptiedFolder = Folder(name: "Emptied", appIDs: [app1.id])
        let toolbarFolder = Folder(name: "Toolbar", appIDs: [])
        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2]
        initialState.folders = [emptiedFolder, toolbarFolder]
        initialState.appOrder = [app1.id, app2.id]
        initialState.rebuildAppMap()
        initialState.rebuildOrderIndexMap()
        initialState.updateDisplayedApps()

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appWasTrashed(app1.id)) {
            $0.apps = [app2]
            $0.rebuildAppMap()
            $0.appOrder = [app2.id]
            $0.rebuildOrderIndexMap()
            // Only the folder emptied by this trash is dropped; an unrelated
            // toolbar-created empty folder must survive.
            $0.folders = [toolbarFolder]
            $0.updateDisplayedApps()
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testAppWasTrashedClearsStaleKeyboardSelection() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2]
        initialState.appOrder = [app1.id, app2.id]
        initialState.rebuildAppMap()
        initialState.rebuildOrderIndexMap()
        initialState.updateDisplayedApps()
        initialState.keyboardSelectedID = app1.id

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }

        await store.send(.appWasTrashed(app1.id)) {
            $0.apps = [app2]
            $0.rebuildAppMap()
            $0.appOrder = [app2.id]
            $0.rebuildOrderIndexMap()
            $0.updateDisplayedApps()
            // The selected app is gone, so the selection is pruned.
            $0.keyboardSelectedID = nil
        }
        await store.receive(\.savePreferences)
        await store.skipInFlightEffects()
    }

    func testFolderSelectionSurvivesGridReorder() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        let folder = Folder(name: "Folder")
        var initialState = AppGridFeature.State()
        initialState.apps = [app1, app2]
        initialState.folders = [folder]
        initialState.appOrder = [app1.id, app2.id]
        initialState.rebuildAppMap()
        initialState.rebuildOrderIndexMap()
        initialState.updateDisplayedApps()
        initialState.keyboardSelectedID = folder.id

        let store = TestStore(initialState: initialState) {
            AppGridFeature()
        }
        store.exhaustivity = .off

        // Reordering apps hides nothing: a folder selection must be kept.
        await store.send(.moveAppBefore(id: app2.id, before: app1.id))
        XCTAssertEqual(store.state.keyboardSelectedID, folder.id)
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
