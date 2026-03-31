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
import SwiftUI
import ViewInspector
@testable import Codeagogo

/// Tests for SettingsView using ViewInspector for headless SwiftUI inspection.
@MainActor
final class SettingsViewTests: XCTestCase {

    // MARK: - Tests

    /// Verifies settings view renders without crash.
    func testSettingsView_renders() throws {
        let view = SettingsView()

        // Should not throw — validates that the view can be inspected
        XCTAssertNoThrow(try view.inspect())
    }

    /// Verifies settings view contains a ScrollView.
    func testSettingsView_containsScrollView() throws {
        let view = SettingsView()

        let inspection = try view.inspect()
        XCTAssertNoThrow(try inspection.find(ViewType.ScrollView.self))
    }

    /// Verifies hotkey section contains GroupBox.
    func testSettingsView_hotkeySection_exists() throws {
        let view = SettingsView()

        let inspection = try view.inspect()
        // Settings view uses multiple GroupBox elements
        XCTAssertNoThrow(try inspection.find(ViewType.GroupBox.self))
    }

    /// Verifies FHIR endpoint text field is present.
    func testSettingsView_serverUrlField_exists() throws {
        let view = SettingsView()

        let inspection = try view.inspect()
        // Should contain at least one TextField (for FHIR endpoint URL)
        XCTAssertNoThrow(try inspection.find(ViewType.TextField.self))
    }

    /// Verifies the debug logging toggle is present.
    func testSettingsView_debugToggle_exists() throws {
        let view = SettingsView()

        let inspection = try view.inspect()
        // Should contain a Toggle (debug logging)
        XCTAssertNoThrow(try inspection.find(ViewType.Toggle.self))
    }
}
