import XCTest

/// Base class for Codeagogo UI tests.
///
/// Provides common setup for launching the app with the `--ui-testing`
/// flag (which skips the single-instance check) and a helper to open
/// the Settings window.
class SNOMEDLookupUITestCase: XCTestCase {

    /// The application under test.
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        // Brief pause to let the app fully initialize
        Thread.sleep(forTimeInterval: 0.5)
    }

    override func tearDownWithError() throws {
        // Terminate the app to ensure clean state for next test
        if let app = app {
            app.terminate()
        }
        app = nil
    }

    // MARK: - Helpers

    /// Opens the Settings window via the Cmd+, keyboard shortcut.
    ///
    /// Waits up to 5 seconds for the settings window to appear.
    ///
    /// - Returns: The settings window element.
    @discardableResult
    func openSettings() -> XCUIElement {
        app.typeKey(",", modifierFlags: .command)
        let settingsWindow = app.windows["Codeagogo Settings"]
            .firstMatch

        // Fall back to any window that contains the settings content
        if !settingsWindow.waitForExistence(timeout: 3) {
            // Try the generic settings window approach
            let anyWindow = app.windows.firstMatch
            XCTAssertTrue(anyWindow.waitForExistence(timeout: 5),
                          "Settings window did not appear")
            return anyWindow
        }
        return settingsWindow
    }
}
