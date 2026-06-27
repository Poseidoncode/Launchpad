import XCTest
@testable import Launchpad

final class AppItemTests: XCTestCase {
    func testStableIDIsDeterministic() {
        let path = URL(fileURLWithPath: "/Applications/Test.app")
        let id1 = AppItem.stableID(bundleIdentifier: "com.test.app", path: path)
        let id2 = AppItem.stableID(bundleIdentifier: "com.test.app", path: path)
        XCTAssertEqual(id1, id2)
    }

    func testStableIDDiffersForDifferentBundleID() {
        let path = URL(fileURLWithPath: "/Applications/Test.app")
        let id1 = AppItem.stableID(bundleIdentifier: "com.test.app", path: path)
        let id2 = AppItem.stableID(bundleIdentifier: "com.other.app", path: path)
        XCTAssertNotEqual(id1, id2)
    }

    func testStableIDDiffersForDifferentPath() {
        let id1 = AppItem.stableID(bundleIdentifier: "com.test.app", path: URL(fileURLWithPath: "/Applications/A.app"))
        let id2 = AppItem.stableID(bundleIdentifier: "com.test.app", path: URL(fileURLWithPath: "/Applications/B.app"))
        XCTAssertNotEqual(id1, id2)
    }

    func testCodableRoundtrip() throws {
        let app = AppItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "TestApp",
            bundleIdentifier: "com.test.app",
            path: URL(fileURLWithPath: "/Applications/Test.app")
        )
        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(AppItem.self, from: data)
        XCTAssertEqual(decoded, app)
        XCTAssertNil(decoded.icon, "Icon should be nil after decode")
    }

    func testEqualityIgnoresIcon() {
        let app1 = AppItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test",
            bundleIdentifier: "com.test",
            path: URL(fileURLWithPath: "/Applications/Test.app")
        )
        let app2 = AppItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test",
            bundleIdentifier: "com.test",
            path: URL(fileURLWithPath: "/Applications/Test.app")
        )
        XCTAssertEqual(app1, app2)
    }
}

final class FolderTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let folder = Folder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test Folder",
            appIDs: [
                UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
            ]
        )
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(Folder.self, from: data)
        XCTAssertEqual(decoded, folder)
        XCTAssertEqual(decoded.name, "Test Folder")
        XCTAssertEqual(decoded.appIDs.count, 2)
    }

    func testEmptyAppIDs() throws {
        let folder = Folder(name: "Empty", appIDs: [])
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(Folder.self, from: data)
        XCTAssertTrue(decoded.appIDs.isEmpty)
    }
}

final class UserPreferencesTests: XCTestCase {
    func testDefaultValues() {
        let prefs = UserPreferences.default
        XCTAssertEqual(prefs.iconSize, 60)
        XCTAssertEqual(prefs.columns, 7)
        XCTAssertFalse(prefs.showHiddenApps)
        XCTAssertTrue(prefs.appOrder.isEmpty)
        XCTAssertTrue(prefs.folders.isEmpty)
        XCTAssertTrue(prefs.customAppNames.isEmpty)
    }

    func testCodableRoundtrip() throws {
        let folder = Folder(name: "Games", appIDs: [UUID()])
        let prefs = UserPreferences(
            appOrder: [UUID(), UUID()],
            folders: [folder],
            showHiddenApps: true,
            iconSize: 80,
            columns: 5,
            customAppNames: ["com.test.app": "Custom Name"]
        )
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)
        XCTAssertEqual(decoded.showHiddenApps, true)
        XCTAssertEqual(decoded.iconSize, 80)
        XCTAssertEqual(decoded.columns, 5)
        XCTAssertEqual(decoded.customAppNames["com.test.app"], "Custom Name")
        XCTAssertEqual(decoded.folders.count, 1)
        XCTAssertEqual(decoded.appOrder.count, 2)
    }

    func testCustomNamesEmptyByDefault() {
        let prefs = UserPreferences()
        XCTAssertTrue(prefs.customAppNames.isEmpty)
    }
}

final class PreferencesStoreTests: XCTestCase {
    private static let prefsKey = "LaunchpadUserPreferences"
    private static let stagingKey = "LaunchpadUserPreferences_staging"
    
    // Save original values so we can restore them after each test
    private var originalPrefs: Any?
    private var originalStaging: Any?

    override func setUp() {
        super.setUp()
        originalPrefs = UserDefaults.standard.object(forKey: Self.prefsKey)
        originalStaging = UserDefaults.standard.object(forKey: Self.stagingKey)
        UserDefaults.standard.removeObject(forKey: Self.prefsKey)
        UserDefaults.standard.removeObject(forKey: Self.stagingKey)
    }

    override func tearDown() {
        // Restore original values to avoid polluting the developer's real preferences
        if let originalPrefs {
            UserDefaults.standard.set(originalPrefs, forKey: Self.prefsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.prefsKey)
        }
        if let originalStaging {
            UserDefaults.standard.set(originalStaging, forKey: Self.stagingKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.stagingKey)
        }
        super.tearDown()
    }

    func testSaveAndLoadRoundtrip() {
        let prefs = UserPreferences(showHiddenApps: true, iconSize: 96, columns: 8)
        PreferencesStore.save(prefs)
        let loaded = PreferencesStore.load()
        XCTAssertEqual(loaded.iconSize, 96)
        XCTAssertEqual(loaded.columns, 8)
        XCTAssertEqual(loaded.showHiddenApps, true)
    }

    func testLoadDefaultsWhenNoData() {
        // Both keys already cleared in setUp
        let loaded = PreferencesStore.load()
        XCTAssertEqual(loaded, UserPreferences.default)
    }

    func testStagingRecovery() {
        let prefs = UserPreferences(iconSize: 128, columns: 4)
        PreferencesStore.save(prefs)

        // Simulate corrupting the real key
        UserDefaults.standard.set(Data(), forKey: Self.prefsKey)

        let loaded = PreferencesStore.load()
        XCTAssertEqual(loaded.iconSize, 128, "Should recover from staging key")
    }

    func testMultipleSaveCycles() {
        for size in stride(from: 48, through: 128, by: 8) {
            let prefs = UserPreferences(iconSize: Double(size))
            PreferencesStore.save(prefs)
            let loaded = PreferencesStore.load()
            XCTAssertEqual(loaded.iconSize, Double(size))
        }
    }
}
