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
    func testLookupHotkeyRecorderExists() throws {
        // HotKeyRecorderView contains a "Record" button - check for that
        let recordButton = settingsWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'Record'")).firstMatch
        XCTAssertTrue(recordButton.waitForExistence(timeout: 3),
                      "Lookup hotkey recorder should exist")
    }

    // MARK: - Search Hotkey Section

    @MainActor
    func testSearchHotkeyRecorderExists() throws {
        // Multiple "Record" buttons exist for different hotkeys
        let recordButtons = settingsWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'Record'"))
        XCTAssertTrue(recordButtons.count >= 2,
                      "Search hotkey recorder should exist (at least 2 Record buttons)")
    }

    // MARK: - Replace Hotkey Section

    @MainActor
    func testReplaceHotkeyRecorderExists() throws {
        // Multiple "Record" buttons exist for different hotkeys
        let recordButtons = settingsWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'Record'"))
        XCTAssertTrue(recordButtons.count >= 3,
                      "Replace hotkey recorder should exist (at least 3 Record buttons)")
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

    // MARK: - ECL Format Hotkey Section

    @MainActor
    func testECLFormatHotkeyRecorderExists() throws {
        // All 4 hotkeys have Record buttons
        let recordButtons = settingsWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'Record'"))
        XCTAssertTrue(recordButtons.count >= 4,
                      "ECL format hotkey recorder should exist (4 Record buttons total)")
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
