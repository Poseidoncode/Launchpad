import AppKit
import XCTest
@testable import Launchpad

final class AppItemStoreTests: XCTestCase {
    func testIsAppStoreAppDefaultsFalseAndExcludedFromCoding() throws {
        let app = AppItem(
            id: UUID(),
            name: "App",
            bundleIdentifier: "com.test.app",
            path: URL(fileURLWithPath: "/Applications/App.app")
        )
        XCTAssertFalse(app.isAppStoreApp)

        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(AppItem.self, from: data)
        XCTAssertFalse(decoded.isAppStoreApp)
        XCTAssertEqual(decoded, app)
    }
}

final class IconCacheTests: XCTestCase {
    func testAppBundleIconFingerprintChangesWhenIconResourceChanges() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchpadIconFingerprint-\(UUID().uuidString).app", isDirectory: true)
        let resourcesURL = bundleURL
            .appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let info = ["CFBundleIconFile": "AppIcon.icns"]
        let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try infoData.write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))

        let iconURL = resourcesURL.appendingPathComponent("AppIcon.icns")
        try Data([0x01, 0x02, 0x03]).write(to: iconURL)
        let initialFingerprint = appBundleIconFingerprint(path: bundleURL.path)

        try Data([0x01, 0x02, 0x03, 0x04, 0x05]).write(to: iconURL)
        let updatedFingerprint = appBundleIconFingerprint(path: bundleURL.path)

        XCTAssertNotEqual(initialFingerprint, updatedFingerprint)
    }

    func testScreenChangeObserverStopIsIdempotent() async {
        let observer = ScreenChangeObserver()
        var fireCount = 0
        observer.handler = { fireCount += 1 }
        observer.start()
        observer.stop()
        observer.stop()
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // Delivery targets the main queue, so flush it before asserting.
        await MainActor.run {}
        XCTAssertEqual(fireCount, 0, "A stopped observer must not fire")
        // Re-enabling (e.g. production init after a test disabled the shared
        // observer) must restore exactly one delivery, not duplicates.
        observer.start()
        observer.start()
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        await MainActor.run {}
        XCTAssertEqual(fireCount, 1, "Re-starting must deliver exactly once")
        observer.stop()
    }
}
