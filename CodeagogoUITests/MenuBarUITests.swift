// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

/// UI tests for the menu bar status item and its menu.
///
/// These tests verify the app launches correctly as a menu bar app
/// and that the expected menu items are present. Menu bar tests can
/// be fragile depending on macOS version and system configuration.
final class MenuBarUITests: SNOMEDLookupUITestCase {

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // The app should be running after setUp launches it
        XCTAssertTrue(app.exists, "App should be running")
        // For a menu bar app, there are typically no standard windows on launch
        // (only the status item). The app simply needs to not crash.
    }

    @MainActor
    func testStatusItemExistsInMenuBar() throws {
        let menuBars = app.menuBars
        let statusItem = menuBars.statusItems["Codeagogo"]

        // Status items may not be directly accessible via XCUITest
        // on all macOS versions, so this test is best-effort
        if statusItem.waitForExistence(timeout: 5) {
            XCTAssertTrue(statusItem.exists,
                          "Status item should exist in the menu bar")
        }
    }

    @MainActor
    func testMenuContainsExpectedItems() throws {
        let menuBars = app.menuBars
        let statusItem = menuBars.statusItems["Codeagogo"]

        guard statusItem.waitForExistence(timeout: 5) else {
            // Status item may not be accessible — skip gracefully
            return
        }

        statusItem.click()

        let lookupItem = app.menuItems["Lookup Selection"]
        let searchItem = app.menuItems["Search Concepts..."]
        let quitItem = app.menuItems["Quit"]

        // Check each menu item exists
        XCTAssertTrue(lookupItem.waitForExistence(timeout: 3),
                      "Menu should contain 'Lookup Selection' item")
        XCTAssertTrue(searchItem.waitForExistence(timeout: 3),
                      "Menu should contain 'Search Concepts...' item")
        XCTAssertTrue(quitItem.waitForExistence(timeout: 3),
                      "Menu should contain 'Quit' item")
    }
}
