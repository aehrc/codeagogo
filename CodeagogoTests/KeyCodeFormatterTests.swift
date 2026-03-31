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
@testable import Codeagogo

/// Tests for `KeyCodeFormatter` hotkey display formatting.
final class KeyCodeFormatterTests: XCTestCase {

    // MARK: - Format Tests with Modifiers

    /// Tests formatting with all four modifiers.
    func testFormatWithAllModifiers() {
        let modifiers = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_L), modifiers: modifiers)
        XCTAssertEqual(result, "⌃⌥⇧⌘L")
    }

    /// Tests formatting with a single modifier (Control).
    func testFormatWithControlOnly() {
        let modifiers = UInt32(controlKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers)
        XCTAssertEqual(result, "⌃S")
    }

    /// Tests formatting with Command modifier only.
    func testFormatWithCommandOnly() {
        let modifiers = UInt32(cmdKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers)
        XCTAssertEqual(result, "⌘S")
    }

    /// Tests formatting with Control+Option modifiers.
    func testFormatWithControlOption() {
        let modifiers = UInt32(controlKey | optionKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_L), modifiers: modifiers)
        XCTAssertEqual(result, "⌃⌥L")
    }

    /// Tests formatting with Command+Shift modifiers.
    func testFormatWithCommandShift() {
        let modifiers = UInt32(cmdKey | shiftKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_K), modifiers: modifiers)
        XCTAssertEqual(result, "⇧⌘K")
    }

    /// Tests formatting with no modifiers.
    func testFormatWithNoModifiers() {
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_A), modifiers: 0)
        XCTAssertEqual(result, "A")
    }

    // MARK: - Letter Key Tests

    /// Tests keyName returns correct letter for all A-Z keys.
    func testKeyNameLetterKeys() {
        let letterKeys: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"), (kVK_ANSI_D, "D"),
            (kVK_ANSI_E, "E"), (kVK_ANSI_F, "F"), (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"),
            (kVK_ANSI_I, "I"), (kVK_ANSI_J, "J"), (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"),
            (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"), (kVK_ANSI_P, "P"),
            (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"), (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"),
            (kVK_ANSI_U, "U"), (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"),
            (kVK_ANSI_Y, "Y"), (kVK_ANSI_Z, "Z")
        ]

        for (code, expected) in letterKeys {
            let result = KeyCodeFormatter.keyName(for: UInt32(code))
            XCTAssertEqual(result, expected, "Expected \(expected) for key code \(code)")
        }
    }

    // MARK: - Number Key Tests

    /// Tests keyName returns correct number for 0-9 keys.
    func testKeyNameNumberKeys() {
        let numberKeys: [(Int, String)] = [
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"),
            (kVK_ANSI_8, "8"), (kVK_ANSI_9, "9")
        ]

        for (code, expected) in numberKeys {
            let result = KeyCodeFormatter.keyName(for: UInt32(code))
            XCTAssertEqual(result, expected, "Expected \(expected) for key code \(code)")
        }
    }

    // MARK: - Function Key Tests

    /// Tests keyName returns correct name for F1-F12 keys.
    func testKeyNameFunctionKeys() {
        let functionKeys: [(Int, String)] = [
            (kVK_F1, "F1"), (kVK_F2, "F2"), (kVK_F3, "F3"), (kVK_F4, "F4"),
            (kVK_F5, "F5"), (kVK_F6, "F6"), (kVK_F7, "F7"), (kVK_F8, "F8"),
            (kVK_F9, "F9"), (kVK_F10, "F10"), (kVK_F11, "F11"), (kVK_F12, "F12")
        ]

        for (code, expected) in functionKeys {
            let result = KeyCodeFormatter.keyName(for: UInt32(code))
            XCTAssertEqual(result, expected, "Expected \(expected) for key code \(code)")
        }
    }

    // MARK: - Special Key Tests

    /// Tests keyName returns correct symbol/name for special keys.
    func testKeyNameSpecialKeys() {
        let specialKeys: [(Int, String)] = [
            (kVK_Space, "Space"),
            (kVK_Return, "↩"),
            (kVK_Tab, "⇥"),
            (kVK_Delete, "⌫"),
            (kVK_ForwardDelete, "⌦"),
            (kVK_Escape, "⎋")
        ]

        for (code, expected) in specialKeys {
            let result = KeyCodeFormatter.keyName(for: UInt32(code))
            XCTAssertEqual(result, expected, "Expected \(expected) for key code \(code)")
        }
    }

    // MARK: - Arrow Key Tests

    /// Tests keyName returns correct symbol for arrow keys.
    func testKeyNameArrowKeys() {
        let arrowKeys: [(Int, String)] = [
            (kVK_UpArrow, "↑"),
            (kVK_DownArrow, "↓"),
            (kVK_LeftArrow, "←"),
            (kVK_RightArrow, "→")
        ]

        for (code, expected) in arrowKeys {
            let result = KeyCodeFormatter.keyName(for: UInt32(code))
            XCTAssertEqual(result, expected, "Expected \(expected) for key code \(code)")
        }
    }

    // MARK: - Punctuation Key Tests

    /// Tests keyName returns correct character for punctuation keys.
    func testKeyNamePunctuationKeys() {
        let punctuationKeys: [(Int, String)] = [
            (kVK_ANSI_Minus, "-"),
            (kVK_ANSI_Equal, "="),
            (kVK_ANSI_LeftBracket, "["),
            (kVK_ANSI_RightBracket, "]"),
            (kVK_ANSI_Backslash, "\\"),
            (kVK_ANSI_Semicolon, ";"),
            (kVK_ANSI_Quote, "'"),
            (kVK_ANSI_Comma, ","),
            (kVK_ANSI_Period, "."),
            (kVK_ANSI_Slash, "/"),
            (kVK_ANSI_Grave, "`")
        ]

        for (code, expected) in punctuationKeys {
            let result = KeyCodeFormatter.keyName(for: UInt32(code))
            XCTAssertEqual(result, expected, "Expected \(expected) for key code \(code)")
        }
    }

    // MARK: - Unknown Key Tests

    /// Tests keyName returns "?" for unknown key codes.
    func testKeyNameUnknownKey() {
        let result = KeyCodeFormatter.keyName(for: 999)
        XCTAssertEqual(result, "?")
    }

    // MARK: - Modifier Order Tests

    /// Tests that modifiers are displayed in standard macOS order: Control, Option, Shift, Command.
    func testModifierOrder() {
        // Test with all modifiers in different orders should still produce same output
        let modifiers1 = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        let modifiers2 = UInt32(controlKey | optionKey | shiftKey | cmdKey)

        let result1 = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_A), modifiers: modifiers1)
        let result2 = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_A), modifiers: modifiers2)

        XCTAssertEqual(result1, result2)
        XCTAssertEqual(result1, "⌃⌥⇧⌘A")
    }

    // MARK: - Real-World Hotkey Tests

    /// Tests formatting of default lookup hotkey (Control+Option+L).
    func testDefaultLookupHotkey() {
        let modifiers = UInt32(controlKey | optionKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_L), modifiers: modifiers)
        XCTAssertEqual(result, "⌃⌥L")
    }

    /// Tests formatting of default search hotkey (Control+Option+S).
    func testDefaultSearchHotkey() {
        let modifiers = UInt32(controlKey | optionKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers)
        XCTAssertEqual(result, "⌃⌥S")
    }

    /// Tests formatting of default replace hotkey (Control+Option+R).
    func testDefaultReplaceHotkey() {
        let modifiers = UInt32(controlKey | optionKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_R), modifiers: modifiers)
        XCTAssertEqual(result, "⌃⌥R")
    }

    /// Tests formatting of default ECL format hotkey (Control+Option+E).
    func testDefaultECLFormatHotkey() {
        let modifiers = UInt32(controlKey | optionKey)
        let result = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_E), modifiers: modifiers)
        XCTAssertEqual(result, "⌃⌥E")
    }
}
