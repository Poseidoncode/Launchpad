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

    func testDecodeClampsOutOfRangeValues() throws {
        // Encode preferences with out-of-range values by using a manual JSON
        let json = """
        {"appOrder":[],"folders":[],"showHiddenApps":false,"iconSize":500,"columns":0,"customAppNames":{}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: json)
        XCTAssertEqual(decoded.iconSize, 256, "iconSize should be clamped to max 256")
        XCTAssertEqual(decoded.columns, 1, "columns should be clamped to min 1")
    }

    func testDecodeFallsBackOnMissingFields() throws {
        // JSON missing some fields — decodeIfPresent should use defaults
        let json = """
        {"appOrder":[],"folders":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: json)
        XCTAssertEqual(decoded.iconSize, 60, "Missing iconSize should fall back to default")
        XCTAssertEqual(decoded.columns, 7, "Missing columns should fall back to default")
        XCTAssertFalse(decoded.showHiddenApps, "Missing showHiddenApps should default to false")
        XCTAssertTrue(decoded.customAppNames.isEmpty, "Missing customAppNames should default to empty")
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
        // Simulate a crash between staging write and real key write:
        // Only staging key is written, real key is missing/corrupt.
        let prefs = UserPreferences(iconSize: 128, columns: 4)
        guard let data = try? JSONEncoder().encode(prefs) else {
            XCTFail("Failed to encode preferences")
            return
        }
        UserDefaults.standard.set(data, forKey: Self.stagingKey)
        // Real key is not written (simulates crash mid-save)

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

    func testStagingKeyCleanedUpAfterSave() {
        let prefs = UserPreferences(iconSize: 72, columns: 6)
        PreferencesStore.save(prefs)
        // After a successful save, the staging key should be removed
        XCTAssertNil(
            UserDefaults.standard.data(forKey: Self.stagingKey),
            "Staging key should be cleaned up after successful save"
        )
        // Real key should be present
        XCTAssertNotNil(UserDefaults.standard.data(forKey: Self.prefsKey))
    }
}
