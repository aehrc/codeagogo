import XCTest

/// UI tests for the Search Panel (NSPanel).
///
/// These tests are exploratory because `NSPanel` with `.nonactivatingPanel`
/// style may have limited XCUITest support. Tests verify the panel opens,
/// accepts input, and contains the expected controls.
final class SearchPanelUITests: SNOMEDLookupUITestCase {

    // MARK: - Panel Lifecycle

    @MainActor
    func testSearchPanelOpensViaMenu() throws {
        // Click the status item to open the menu
        let menuBars = app.menuBars
        let statusItem = menuBars.statusItems["SNOMED Lookup"]

        // If the status item is not directly accessible, try the menu bar items
        if statusItem.waitForExistence(timeout: 3) {
            statusItem.click()
        }

        // Look for "Search Concepts..." menu item
        let searchMenuItem = app.menuItems["Search Concepts..."]
        if searchMenuItem.waitForExistence(timeout: 3) {
            searchMenuItem.click()

            // Wait for the search panel to appear
            let searchPanel = app.windows["SNOMED CT Search"]
            XCTAssertTrue(searchPanel.waitForExistence(timeout: 5),
                          "Search panel should appear after clicking menu item")
        }
    }

    @MainActor
    func testSearchFieldExistsWhenPanelOpens() throws {
        openSearchPanel()

        let searchField = app.textFields["search.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field should exist in the search panel")
    }

    @MainActor
    func testSearchFieldAcceptsTextInput() throws {
        openSearchPanel()

        let searchField = app.textFields["search.searchField"]
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Search field not found")
            return
        }

        searchField.click()
        searchField.typeText("diabetes")

        let value = searchField.value as? String ?? ""
        XCTAssertTrue(value.contains("diabetes"),
                      "Search field should contain typed text")
    }

    @MainActor
    func testCancelButtonClosesPanel() throws {
        openSearchPanel()

        let cancelButton = app.buttons["search.cancelButton"]
        guard cancelButton.waitForExistence(timeout: 5) else {
            XCTFail("Cancel button not found")
            return
        }

        cancelButton.click()

        // Panel should close
        let searchPanel = app.windows["SNOMED CT Search"]
        let closed = searchPanel.waitForNonExistence(timeout: 5)
        XCTAssertTrue(closed, "Search panel should close after clicking Cancel")
    }

    @MainActor
    func testInsertButtonDisabledWithNoSelection() throws {
        openSearchPanel()

        let insertButton = app.buttons["search.insertButton"]
        guard insertButton.waitForExistence(timeout: 5) else {
            XCTFail("Insert button not found")
            return
        }

        XCTAssertFalse(insertButton.isEnabled,
                       "Insert button should be disabled when no result is selected")
    }

    @MainActor
    func testEditionPickerExists() throws {
        openSearchPanel()

        let editionPicker = app.popUpButtons["search.editionFilter"]
        XCTAssertTrue(editionPicker.waitForExistence(timeout: 5),
                      "Edition picker should exist in the search panel")
    }

    @MainActor
    func testInsertFormatPickerExists() throws {
        openSearchPanel()

        let formatPicker = app.popUpButtons["search.insertFormat"]
        XCTAssertTrue(formatPicker.waitForExistence(timeout: 5),
                      "Insert format picker should exist in the search panel")
    }

    @MainActor
    func testPlaceholderVisibleOnOpen() throws {
        openSearchPanel()

        // The placeholder should be visible before any search
        let placeholder = app.otherElements["search.placeholder"]
            .firstMatch
        // This might appear as a staticText or other element depending on
        // how SwiftUI renders the accessibility tree
        let placeholderText = app.staticTexts["Type to search for SNOMED CT concepts"]
        let found = placeholder.waitForExistence(timeout: 3) ||
                    placeholderText.waitForExistence(timeout: 3)

        XCTAssertTrue(found, "Placeholder view should be visible when search field is empty")
    }

    // MARK: - Helpers

    /// Opens the search panel via the status bar menu.
    ///
    /// Falls back to searching for the panel directly if the menu
    /// interaction is not possible.
    private func openSearchPanel() {
        // Try opening via the status item menu
        let menuBars = app.menuBars
        let statusItem = menuBars.statusItems["SNOMED Lookup"]

        if statusItem.waitForExistence(timeout: 3) {
            statusItem.click()
            let searchMenuItem = app.menuItems["Search Concepts..."]
            if searchMenuItem.waitForExistence(timeout: 3) {
                searchMenuItem.click()
            }
        }

        // Wait for the panel
        let searchPanel = app.windows["SNOMED CT Search"]
        if !searchPanel.waitForExistence(timeout: 5) {
            // The panel may not be discoverable via XCUITest for NSPanel
            // with nonactivatingPanel style — this is a known limitation
            XCTFail("Search panel did not appear — this may be a known NSPanel limitation")
        }
    }
}

private extension XCUIElement {
    /// Waits for the element to no longer exist.
    ///
    /// - Parameter timeout: Maximum time to wait in seconds.
    /// - Returns: `true` if the element ceased to exist within the timeout.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
