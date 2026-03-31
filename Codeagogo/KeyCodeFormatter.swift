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

import Carbon.HIToolbox

/// Formats key codes and modifiers for display with macOS-standard symbols.
///
/// `KeyCodeFormatter` converts Carbon virtual key codes and modifier masks into
/// human-readable strings using standard macOS keyboard symbols (⌃⌥⇧⌘).
///
/// ## Usage
///
/// ```swift
/// // Format a complete hotkey
/// let display = KeyCodeFormatter.format(keyCode: UInt32(kVK_ANSI_L),
///                                       modifiers: UInt32(controlKey | optionKey))
/// // Returns "⌃⌥L"
///
/// // Get just the key name
/// let name = KeyCodeFormatter.keyName(for: UInt32(kVK_Space))
/// // Returns "Space"
/// ```
enum KeyCodeFormatter {
    /// Formats a hotkey with modifier symbols (e.g., "⌃⌥L").
    ///
    /// Modifiers are displayed in standard macOS order: Control, Option, Shift, Command.
    ///
    /// - Parameters:
    ///   - keyCode: Carbon virtual key code (e.g., `kVK_ANSI_L`)
    ///   - modifiers: Carbon modifier mask (e.g., `controlKey | optionKey`)
    /// - Returns: A formatted string with modifier symbols followed by the key name
    static func format(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []

        // Modifiers in standard macOS order
        if (modifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
        if (modifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
        if (modifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
        if (modifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }

        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    /// Returns the display name for a Carbon virtual key code.
    ///
    /// Supports letters A-Z, numbers 0-9, function keys F1-F12, special keys
    /// (Space, Return, Tab, Delete, Escape, arrows), and common punctuation.
    ///
    /// - Parameter code: Carbon virtual key code
    /// - Returns: The display name for the key, or "?" for unknown key codes
    /// Exhaustive key code switch is inherently complex.
    // swiftlint:disable:next cyclomatic_complexity
    static func keyName(for code: UInt32) -> String {
        switch Int(code) {
        // Letters
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"

        // Numbers
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"

        // Function keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"

        // Special keys
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"

        // Arrow keys
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"

        // Punctuation
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"

        default: return "?"
        }
    }
}
