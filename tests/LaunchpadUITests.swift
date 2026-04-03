import XCTest

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
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        XCTAssertEqual(app.windows.count, 1)
    }
    
    func testWindowExists() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.isHittable)
    }
    
    // MARK: - Folder Tests
    
    func testCreateFolder() throws {
        // Find toolbar buttons
        let toolbarButtons = app.buttons
        XCTAssertTrue(toolbarButtons.count >= 3, "Should have at least 3 toolbar buttons")
        
        // Click "New Folder" button (assuming it's the second button)
        let newFolderButton = toolbarButtons.element(boundBy: 1)
        if newFolderButton.waitForExistence(timeout: 2) {
            newFolderButton.click()
            
            // Verify folder was created (check if folders collection increased)
            // Note: This depends on UI structure
            sleep(1)
        }
    }
    
    func testOpenFolder() throws {
        // First, ensure there's a folder to open
        // This test assumes a folder exists from previous test
        
        // Look for folder elements
        // In SwiftUI, folders would be rendered as some kind of element
        // We need to identify them
        
        sleep(2)
        
        // Try to find and click a folder
        // This requires knowing the UI structure
    }
    
    func testDismissFolderModal() throws {
        // This is the key test for the bug
        
        // 1. Open a folder first (if one exists)
        // 2. Try to dismiss by:
        //    a. Clicking background area
        //    b. Pressing Escape key
        //    c. Clicking the "Close" button
        
        // Test Escape key
        let escapeKey = XCUIKeyboardKey.escape
        app.typeKey(escapeKey, modifierFlags: [])
        
        sleep(1)
        
        // Verify modal is dismissed
        // Note: We need to check if sheet/modal is still present
    }
    
    func testCloseButton() throws {
        // Test clicking the Close button in folder modal
        
        // 1. Open a folder
        // 2. Find the Close button
        // 3. Click it
        
        let closeButton = app.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2) {
            closeButton.click()
            sleep(1)
            XCTAssertFalse(closeButton.exists, "Close button should not exist after dismissal")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFolderOpeningPerformance() throws {
        // Measure time to open a folder
        
        measure {
            // Open folder and measure
            // This would test the "卡頓" issue
            
            // Note: Needs a folder to exist
            sleep(1)
        }
    }
    
    // MARK: - Keyboard Tests
    
    func testEscapeKeyDismissesFolder() throws {
        // Test that ESC key dismisses folder modal
        
        // 1. Open folder (if available)
        // 2. Press ESC
        // 3. Verify modal closed
        
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        
        sleep(1)
    }
    
    func testEscapeKeyInEditMode() throws {
        // Test ESC in edit mode
        
        // 1. Enter edit mode (click edit button)
        // 2. Press ESC
        // 3. Verify edit mode exits
        
        let editButton = app.buttons.element(boundBy: 0)
        if editButton.exists {
            editButton.click()
            sleep(1)
            
            // Press Escape
            app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
            
            sleep(1)
        }
    }
}