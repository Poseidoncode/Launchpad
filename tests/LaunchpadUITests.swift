import XCTest

/// UI tests require a running app instance. These tests validate
/// basic window behavior, keyboard shortcuts, and folder interactions.
///
/// NOTE: UI tests are excluded from `swift test` (see Package.swift). This repository
/// does not include an Xcode UI-testing target, so these tests require separate target
/// configuration before they can be run.
final class LaunchpadUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Basic Tests
    
    func testAppLaunches() throws {
        XCTAssertTrue(app.waitForExistence(timeout: 5), "App should launch within 5 seconds")
        XCTAssertEqual(app.windows.count, 1, "Should have exactly one window")
    }
    
    func testWindowExists() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should appear")
        XCTAssertTrue(window.isHittable, "Window should be interactive")
    }
    
    // MARK: - Toolbar Tests
    
    func testToolbarHasMinimumButtons() throws {
        XCTAssertTrue(app.buttons["Toggle Edit Mode"].exists)
        XCTAssertTrue(app.buttons["New Folder"].exists)
        XCTAssertTrue(app.buttons["Refresh Apps"].exists)
    }
    
    func testSearchFieldExists() throws {
        let searchField = app.textFields["Search apps"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
    }
    
    // MARK: - Keyboard Tests
    
    func testEscapeKeyClearsSearch() throws {
        let searchField = app.textFields["Search apps"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
        guard searchField.exists else { return }
        
        searchField.click()
        searchField.typeText("test")
        
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        
        // After ESC, search field should be empty
        let fieldValue = searchField.value as? String ?? ""
        XCTAssertTrue(fieldValue.isEmpty, "ESC should clear search field")
    }
    
    func testCmdFFocusesSearch() throws {
        let searchField = app.textFields["Search apps"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
        guard searchField.exists else { return }
        
        app.typeKey("f", modifierFlags: .command)
        
        XCTAssertTrue(searchField.hasFocus, "Cmd+F should focus the search field")
    }
    
    // MARK: - Folder Tests
    
    func testCreateFolderViaToolbar() throws {
        let folderButton = app.buttons["New Folder"]
        XCTAssertTrue(folderButton.waitForExistence(timeout: 2), "New Folder button should exist")
        guard folderButton.exists else { return }

        let emptyFolderPredicate = NSPredicate(format: "label CONTAINS ', 0 apps'")
        let initialEmptyFolderCount = app.buttons.matching(emptyFolderPredicate).count
        folderButton.click()

        let createdFolder = app.buttons.matching(emptyFolderPredicate).firstMatch
        XCTAssertTrue(createdFolder.waitForExistence(timeout: 3), "Creating a folder should show an empty folder")
        XCTAssertEqual(app.buttons.matching(emptyFolderPredicate).count, initialEmptyFolderCount + 1)
    }
    
    func testDismissFolderWithEscape() throws {
        // Create a folder first
        let folderButton = app.buttons["New Folder"]
        XCTAssertTrue(folderButton.waitForExistence(timeout: 2), "New Folder button should exist")
        guard folderButton.exists else { return }
        folderButton.click()

        // Open the newly created empty folder
        let folder = app.buttons.matching(NSPredicate(format: "label CONTAINS ', 0 apps'")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 3), "An empty folder should be visible")
        guard folder.exists else { return }
        folder.click()
        
        // Press ESC to dismiss
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        sleep(1)
        
        // Close button should no longer exist after dismissal
        let closeButton = app.buttons["Close folder"]
        XCTAssertFalse(closeButton.exists, "ESC should dismiss folder modal")
    }
    
    func testCloseButtonDismissesFolder() throws {
        // Create and open a folder
        let folderButton = app.buttons["New Folder"]
        XCTAssertTrue(folderButton.waitForExistence(timeout: 2), "New Folder button should exist")
        guard folderButton.exists else { return }
        folderButton.click()

        let folder = app.buttons.matching(NSPredicate(format: "label CONTAINS ', 0 apps'")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 3), "An empty folder should be visible")
        guard folder.exists else { return }
        folder.click()

        let closeButton = app.buttons["Close folder"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button should be available in the folder")
        guard closeButton.exists else { return }
        closeButton.click()
        sleep(1)
        
        XCTAssertFalse(closeButton.exists, "Close button should dismiss folder modal")
    }
}
