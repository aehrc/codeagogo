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
import Carbon.HIToolbox
import AppKit
@testable import Codeagogo

/// Tests for HotKeySettings Carbon modifier conversion and defaults.
final class HotKeySettingsTests: XCTestCase {

    // MARK: - carbonModifiers Tests

    func testCarbonModifiers_control() {
        let result = HotKeySettings.carbonModifiers(from: [.control])
        XCTAssertEqual(result, UInt32(controlKey))
    }

    func testCarbonModifiers_option() {
        let result = HotKeySettings.carbonModifiers(from: [.option])
        XCTAssertEqual(result, UInt32(optionKey))
    }

    func testCarbonModifiers_command() {
        let result = HotKeySettings.carbonModifiers(from: [.command])
        XCTAssertEqual(result, UInt32(cmdKey))
    }

    func testCarbonModifiers_shift() {
        let result = HotKeySettings.carbonModifiers(from: [.shift])
        XCTAssertEqual(result, UInt32(shiftKey))
    }

    func testCarbonModifiers_controlOption() {
        let result = HotKeySettings.carbonModifiers(from: [.control, .option])
        XCTAssertEqual(result, UInt32(controlKey) | UInt32(optionKey))
    }

    func testCarbonModifiers_allModifiers() {
        let result = HotKeySettings.carbonModifiers(from: [.control, .option, .command, .shift])
        let expected = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey) | UInt32(shiftKey)
        XCTAssertEqual(result, expected)
    }

    func testCarbonModifiers_empty() {
        let result = HotKeySettings.carbonModifiers(from: [])
        XCTAssertEqual(result, 0)
    }

    // MARK: - Default Value Tests

    func testCurrentKeyCode_defaultValue() {
        // Default is kVK_ANSI_L = 37
        // Note: This reads from UserDefaults, so the default applies when unset
        let keyCode = HotKeySettings.currentKeyCode
        // Just verify it returns a reasonable value (the actual default or a saved value)
        XCTAssertTrue(keyCode < 256, "Key code should be a valid virtual key code")
    }

    func testCurrentModifiers_defaultValue() {
        // Just verify it returns a valid modifier set
        let modifiers = HotKeySettings.currentModifiers
        // Should not be empty — there's always at least one modifier set
        XCTAssertFalse(modifiers.isEmpty, "Modifiers should not be empty")
    }
}
