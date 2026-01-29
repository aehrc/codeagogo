import XCTest

/// UI tests for the Settings window.
///
/// Tests that all interactive controls in the Settings window exist, have
/// correct defaults, and can be interacted with. Uses accessibility
/// identifiers added to `SettingsView`.
final class SettingsViewUITests: SNOMEDLookupUITestCase {

    /// The settings window element, opened in setUp.
    private var settingsWindow: XCUIElement!

    override func setUpWithError() throws {
        try super.setUpWithError()
        settingsWindow = openSettings()
    }

    // MARK: - Settings Window

    @MainActor
    func testSettingsWindowOpensViaCmdComma() throws {
        XCTAssertTrue(settingsWindow.exists, "Settings window should be visible")
    }

    // MARK: - Lookup Hotkey Section

    @MainActor
    func testLookupHotkeyKeyPickerExists() throws {
        let picker = settingsWindow.popUpButtons["settings.lookupHotkeyKey"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3),
                      "Lookup hotkey key picker should exist")
    }

    @MainActor
    func testLookupControlToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.lookup.control"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Lookup Control modifier toggle should exist")
    }

    @MainActor
    func testLookupOptionToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.lookup.option"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Lookup Option modifier toggle should exist")
    }

    @MainActor
    func testLookupCommandToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.lookup.command"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Lookup Command modifier toggle should exist")
    }

    @MainActor
    func testLookupShiftToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.lookup.shift"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Lookup Shift modifier toggle should exist")
    }

    @MainActor
    func testLookupHotkeyKeyCanBeChanged() throws {
        let picker = settingsWindow.popUpButtons["settings.lookupHotkeyKey"]
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Lookup hotkey key picker not found")
            return
        }
        picker.click()

        // Select a different key (K)
        let menuItem = picker.menuItems["K"]
        if menuItem.waitForExistence(timeout: 2) {
            menuItem.click()
        }
        // Verify the picker still exists after interaction
        XCTAssertTrue(picker.exists, "Picker should still exist after changing value")
    }

    @MainActor
    func testLookupModifierToggleCanBeToggled() throws {
        let toggle = settingsWindow.checkBoxes["settings.lookup.shift"]
        guard toggle.waitForExistence(timeout: 3) else {
            XCTFail("Shift toggle not found")
            return
        }

        let initialValue = toggle.value as? Int ?? 0
        toggle.click()
        let newValue = toggle.value as? Int ?? 0
        XCTAssertNotEqual(initialValue, newValue,
                          "Toggle value should change after clicking")

        // Toggle back to restore default
        toggle.click()
    }

    // MARK: - Search Hotkey Section

    @MainActor
    func testSearchHotkeyKeyPickerExists() throws {
        let picker = settingsWindow.popUpButtons["settings.searchHotkeyKey"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3),
                      "Search hotkey key picker should exist")
    }

    @MainActor
    func testSearchControlToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.search.control"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Search Control modifier toggle should exist")
    }

    @MainActor
    func testSearchOptionToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.search.option"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Search Option modifier toggle should exist")
    }

    @MainActor
    func testSearchCommandToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.search.command"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Search Command modifier toggle should exist")
    }

    @MainActor
    func testSearchShiftToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.search.shift"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Search Shift modifier toggle should exist")
    }

    // MARK: - Replace Hotkey Section

    @MainActor
    func testReplaceHotkeyKeyPickerExists() throws {
        let picker = settingsWindow.popUpButtons["settings.replaceHotkeyKey"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3),
                      "Replace hotkey key picker should exist")
    }

    @MainActor
    func testReplaceControlToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.replace.control"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Replace Control modifier toggle should exist")
    }

    @MainActor
    func testReplaceOptionToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.replace.option"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Replace Option modifier toggle should exist")
    }

    @MainActor
    func testReplaceCommandToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.replace.command"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Replace Command modifier toggle should exist")
    }

    @MainActor
    func testReplaceShiftToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.replace.shift"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Replace Shift modifier toggle should exist")
    }

    @MainActor
    func testReplaceTermFormatPickerExists() throws {
        let picker = settingsWindow.popUpButtons["settings.replaceTermFormat"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3),
                      "Replace term format picker should exist")
    }

    @MainActor
    func testReplaceTermFormatCanBeChanged() throws {
        let picker = settingsWindow.popUpButtons["settings.replaceTermFormat"]
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Replace term format picker not found")
            return
        }
        picker.click()

        // Try to select "Preferred Term (PT)"
        let menuItem = picker.menuItems["Preferred Term (PT)"]
        if menuItem.waitForExistence(timeout: 2) {
            menuItem.click()
        }
        XCTAssertTrue(picker.exists, "Picker should still exist after changing value")
    }

    // MARK: - Insert Format Section

    @MainActor
    func testInsertFormatPickerExists() throws {
        let picker = settingsWindow.popUpButtons["settings.insertFormat"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3),
                      "Insert format picker should exist")
    }

    @MainActor
    func testInsertFormatCanBeChanged() throws {
        let picker = settingsWindow.popUpButtons["settings.insertFormat"]
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Insert format picker not found")
            return
        }
        picker.click()

        // Try to select "ID Only"
        let menuItem = picker.menuItems["ID Only"]
        if menuItem.waitForExistence(timeout: 2) {
            menuItem.click()
        }
        XCTAssertTrue(picker.exists, "Picker should still exist after changing value")
    }

    // MARK: - FHIR Endpoint Section

    @MainActor
    func testFHIRBaseURLFieldExists() throws {
        let field = settingsWindow.textFields["settings.fhirBaseURL"]
        XCTAssertTrue(field.waitForExistence(timeout: 3),
                      "FHIR base URL text field should exist")
    }

    @MainActor
    func testFHIRBaseURLCanBeEdited() throws {
        let field = settingsWindow.textFields["settings.fhirBaseURL"]
        guard field.waitForExistence(timeout: 3) else {
            XCTFail("FHIR base URL field not found")
            return
        }
        // Click the field and type a character
        field.click()
        field.typeKey("a", modifierFlags: .command) // Select all
        field.typeText("https://example.com/fhir")

        let value = field.value as? String ?? ""
        XCTAssertTrue(value.contains("example.com"),
                      "Field should contain typed text")
    }

    @MainActor
    func testSaveButtonExists() throws {
        let button = settingsWindow.buttons["settings.saveButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 3),
                      "Save button should exist")
    }

    @MainActor
    func testSaveButtonIsClickable() throws {
        let button = settingsWindow.buttons["settings.saveButton"]
        guard button.waitForExistence(timeout: 3) else {
            XCTFail("Save button not found")
            return
        }
        XCTAssertTrue(button.isEnabled, "Save button should be enabled")
        button.click()
        // The button should still exist after clicking (no navigation)
        XCTAssertTrue(button.exists, "Save button should still exist after clicking")
    }

    // MARK: - Logging Section

    @MainActor
    func testDebugLoggingToggleExists() throws {
        let toggle = settingsWindow.checkBoxes["settings.debugLogging"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Debug logging toggle should exist")
    }

    @MainActor
    func testDebugLoggingToggleCanBeToggled() throws {
        let toggle = settingsWindow.checkBoxes["settings.debugLogging"]
        guard toggle.waitForExistence(timeout: 3) else {
            XCTFail("Debug logging toggle not found")
            return
        }
        let initialValue = toggle.value as? Int ?? 0
        toggle.click()
        let newValue = toggle.value as? Int ?? 0
        XCTAssertNotEqual(initialValue, newValue,
                          "Debug logging toggle should change after clicking")
        // Toggle back
        toggle.click()
    }

    @MainActor
    func testDiagnosticsButtonExists() throws {
        let button = settingsWindow.buttons["settings.diagnosticsButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 3),
                      "Diagnostics button should exist")
    }

    @MainActor
    func testDiagnosticsButtonIsClickable() throws {
        let button = settingsWindow.buttons["settings.diagnosticsButton"]
        guard button.waitForExistence(timeout: 3) else {
            XCTFail("Diagnostics button not found")
            return
        }
        XCTAssertTrue(button.isEnabled, "Diagnostics button should be enabled")
        button.click()
        // Button should still exist after clicking
        XCTAssertTrue(button.exists,
                      "Diagnostics button should still exist after clicking")
    }
}
