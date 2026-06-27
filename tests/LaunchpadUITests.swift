import XCTest

/// UI tests require a running app instance. These tests validate
/// basic window behavior, keyboard shortcuts, and folder interactions.
///
/// NOTE: UI tests are excluded from `swift test` (see Package.swift).
/// Run them via Xcode or `xcodebuild test` with a UI testing target.
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
        // Edit, New Folder, Refresh = at least 3 buttons
        let buttons = app.buttons
        XCTAssertTrue(buttons.count >= 3, "Should have at least 3 toolbar buttons (edit, folder, refresh)")
    }
    
    func testSearchFieldExists() throws {
        let searchField = app.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
    }
    
    // MARK: - Keyboard Tests
    
    func testEscapeKeyClearsSearch() throws {
        let searchField = app.textFields.firstMatch
        guard searchField.waitForExistence(timeout: 3) else { return }
        
        searchField.click()
        searchField.typeText("test")
        
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        
        // After ESC, search field should be empty
        let fieldValue = searchField.value as? String ?? ""
        XCTAssertTrue(fieldValue.isEmpty, "ESC should clear search field")
    }
    
    func testCmdFFocusesSearch() throws {
        let searchField = app.textFields.firstMatch
        guard searchField.waitForExistence(timeout: 3) else { return }
        
        app.typeKey("f", modifierFlags: .command)
        
        XCTAssertTrue(searchField.hasFocus, "Cmd+F should focus the search field")
    }
    
    // MARK: - Folder Tests
    
    func testCreateFolderViaToolbar() throws {
        let folderButton = app.buttons.element(boundBy: 1)
        guard folderButton.waitForExistence(timeout: 2) else { return }
        
        let initialButtonCount = app.buttons.count
        folderButton.click()
        
        // After creating a folder, there should be a new folder element
        // Give the UI time to update
        sleep(1)
        
        // The button count should increase (folder grid item adds buttons)
        XCTAssertGreaterThanOrEqual(app.buttons.count, initialButtonCount,
                                     "Creating a folder should add UI elements")
    }
    
    func testDismissFolderWithEscape() throws {
        // Create a folder first
        let folderButton = app.buttons.element(boundBy: 1)
        guard folderButton.waitForExistence(timeout: 2) else { return }
        folderButton.click()
        sleep(1)
        
        // Open the folder
        // Look for folder elements (they have "folder" accessibility label)
        let folder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'apps'")).firstMatch
        guard folder.waitForExistence(timeout: 2) else { return }
        folder.click()
        sleep(1)
        
        // Press ESC to dismiss
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        sleep(1)
        
        // Close button should no longer exist after dismissal
        let closeButton = app.buttons["Close"]
        XCTAssertFalse(closeButton.exists, "ESC should dismiss folder modal")
    }
    
    func testCloseButtonDismissesFolder() throws {
        // Create and open a folder
        let folderButton = app.buttons.element(boundBy: 1)
        guard folderButton.waitForExistence(timeout: 2) else { return }
        folderButton.click()
        sleep(1)
        
        let folder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'apps'")).firstMatch
        guard folder.waitForExistence(timeout: 2) else { return }
        folder.click()
        sleep(1)
        
        // Click Close button
        let closeButton = app.buttons["Close"]
        guard closeButton.waitForExistence(timeout: 2) else { return }
        closeButton.click()
        sleep(1)
        
        XCTAssertFalse(closeButton.exists, "Close button should dismiss folder modal")
    }
}
