import XCTest
import ComposableArchitecture
@testable import Launchpad

@MainActor
final class AppGridTests: XCTestCase {
    func testSwapAppsUpdatesOrderAndSaves() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        
        let store = TestStore(
            initialState: AppGridFeature.State(
                apps: [app1, app2],
                folders: [],
                appOrder: [app1.id, app2.id]
            )
        ) {
            AppGridFeature()
        }
        
        await store.send(.swapApps(id: app1.id, with: app2.id)) {
            $0.appOrder = [app2.id, app1.id]
        }
        await store.receive(\.savePreferences)
    }
    
    func testAppsLoadedNormalizesSavedOrder() async {
        let app1 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "App1")
        let app2 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "App2")
        let app3 = makeApp(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "App3")
        let staleID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        
        let store = TestStore(
            initialState: AppGridFeature.State(
                appOrder: [app2.id, staleID]
            )
        ) {
            AppGridFeature()
        }
        
        await store.send(.appsLoaded([app1, app2, app3])) {
            $0.isLoading = false
            $0.apps = [app1, app2, app3]
            $0.appOrder = [app2.id, app1.id, app3.id]
        }
        await store.receive(\.savePreferences)
    }
    
    func testStableIDIsDeterministic() {
        let path = URL(fileURLWithPath: "/Applications/Test.app")
        let id1 = AppItem.stableID(bundleIdentifier: "com.test.app", path: path)
        let id2 = AppItem.stableID(bundleIdentifier: "com.test.app", path: path)
        
        XCTAssertEqual(id1, id2)
    }
    
    private func makeApp(id: UUID, name: String) -> AppItem {
        AppItem(
            id: id,
            name: name,
            bundleIdentifier: "com.test.\(name.lowercased())",
            path: URL(fileURLWithPath: "/Applications/\(name).app"),
            isFolder: false
        )
    }
}
