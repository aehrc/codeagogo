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

import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

/// Constants used by ReplaceHotKeySettings, accessible from any isolation context.
private enum ReplaceHotKeyConstants: Sendable {
    static let keyCodeKey = "replaceHotkey.keyCode"
    static let modifiersKey = "replaceHotkey.modifiersRaw"
    // kVK_ANSI_R = 0x0F = 15
    static let defaultKeyCode: UInt32 = 15
    // controlKey | optionKey = 0x1000 | 0x0800 = 0x1800 = 6144
    static let defaultModifiers: UInt32 = 6144
}

/// Manages the global hotkey configuration for the replace feature.
///
/// `ReplaceHotKeySettings` follows the same pattern as `HotKeySettings` and
/// `SearchHotKeySettings` but uses different UserDefaults keys. The default
/// hotkey is Control+Option+R.
///
/// ## Thread Safety
///
/// This class is marked `@MainActor` and should be accessed from the main
/// thread. Use the static thread-safe accessors for non-MainActor contexts.
///
/// ## Usage
///
/// ```swift
/// let settings = ReplaceHotKeySettings.shared
///
/// // Get current settings
/// let code = settings.keyCode
/// let mods = settings.modifiers
///
/// // Update settings
/// settings.keyCode = UInt32(kVK_ANSI_Y)
/// settings.save()
/// ```
@MainActor
final class ReplaceHotKeySettings: ObservableObject {
    /// Shared singleton instance.
    static let shared = ReplaceHotKeySettings()

    /// The virtual key code for the replace hotkey.
    @Published var keyCode: UInt32

    /// The Carbon modifier mask (Control, Option, Command, Shift).
    @Published var modifiersRaw: UInt32

    private init() {
        let savedKey = UserDefaults.standard.object(forKey: ReplaceHotKeyConstants.keyCodeKey) as? Int
        let savedMods = UserDefaults.standard.object(forKey: ReplaceHotKeyConstants.modifiersKey) as? Int

        self.keyCode = UInt32(savedKey ?? Int(ReplaceHotKeyConstants.defaultKeyCode))
        self.modifiersRaw = UInt32(savedMods ?? Int(ReplaceHotKeyConstants.defaultModifiers))
    }

    /// Persists the current settings to UserDefaults.
    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: ReplaceHotKeyConstants.keyCodeKey)
        UserDefaults.standard.set(Int(modifiersRaw), forKey: ReplaceHotKeyConstants.modifiersKey)
    }

    /// The current modifiers as NSEvent.ModifierFlags.
    var modifiers: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if (modifiersRaw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { f.insert(.control) }
        if (modifiersRaw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { f.insert(.option) }
        if (modifiersRaw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { f.insert(.command) }
        if (modifiersRaw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { f.insert(.shift) }
        return f
    }

    /// Thread-safe access to key code for non-MainActor contexts.
    nonisolated static var currentKeyCode: UInt32 {
        let saved = UserDefaults.standard.object(forKey: ReplaceHotKeyConstants.keyCodeKey) as? Int
        return UInt32(saved ?? Int(ReplaceHotKeyConstants.defaultKeyCode))
    }

    /// Thread-safe access to modifiers for non-MainActor contexts.
    nonisolated static var currentModifiers: NSEvent.ModifierFlags {
        let saved = UserDefaults.standard.object(forKey: ReplaceHotKeyConstants.modifiersKey) as? Int
        let raw = UInt32(saved ?? Int(ReplaceHotKeyConstants.defaultModifiers))
        var f: NSEvent.ModifierFlags = []
        if (raw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { f.insert(.control) }
        if (raw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { f.insert(.option) }
        if (raw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { f.insert(.command) }
        if (raw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { f.insert(.shift) }
        return f
    }

    /// Human-readable description of the current hotkey with modifier symbols (e.g., "⌃⌥R").
    var hotkeyDescription: String {
        KeyCodeFormatter.format(keyCode: keyCode, modifiers: modifiersRaw)
    }
}
