import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

/// Constants used by ECLFormatHotKeySettings, accessible from any isolation context.
private enum ECLFormatHotKeyConstants: Sendable {
    static let keyCodeKey = "eclFormatHotkey.keyCode"
    static let modifiersKey = "eclFormatHotkey.modifiersRaw"
    // kVK_ANSI_E = 0x0E = 14
    static let defaultKeyCode: UInt32 = 14
    // controlKey | optionKey = 0x1000 | 0x0800 = 0x1800 = 6144
    static let defaultModifiers: UInt32 = 6144
}

/// Manages the global hotkey configuration for the ECL format feature.
///
/// `ECLFormatHotKeySettings` follows the same pattern as other hotkey settings
/// but uses different UserDefaults keys. The default hotkey is Control+Option+E.
///
/// ## Thread Safety
///
/// This class is marked `@MainActor` and should be accessed from the main
/// thread. Use the static thread-safe accessors for non-MainActor contexts.
///
/// ## Usage
///
/// ```swift
/// let settings = ECLFormatHotKeySettings.shared
///
/// // Get current settings
/// let code = settings.keyCode
/// let mods = settings.modifiers
///
/// // Update settings
/// settings.keyCode = UInt32(kVK_ANSI_F)
/// settings.save()
/// ```
@MainActor
final class ECLFormatHotKeySettings: ObservableObject {
    /// Shared singleton instance.
    static let shared = ECLFormatHotKeySettings()

    /// The virtual key code for the ECL format hotkey.
    @Published var keyCode: UInt32

    /// The Carbon modifier mask (Control, Option, Command, Shift).
    @Published var modifiersRaw: UInt32

    private init() {
        let savedKey = UserDefaults.standard.object(forKey: ECLFormatHotKeyConstants.keyCodeKey) as? Int
        let savedMods = UserDefaults.standard.object(forKey: ECLFormatHotKeyConstants.modifiersKey) as? Int

        self.keyCode = UInt32(savedKey ?? Int(ECLFormatHotKeyConstants.defaultKeyCode))
        self.modifiersRaw = UInt32(savedMods ?? Int(ECLFormatHotKeyConstants.defaultModifiers))
    }

    /// Persists the current settings to UserDefaults.
    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: ECLFormatHotKeyConstants.keyCodeKey)
        UserDefaults.standard.set(Int(modifiersRaw), forKey: ECLFormatHotKeyConstants.modifiersKey)
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
        let saved = UserDefaults.standard.object(forKey: ECLFormatHotKeyConstants.keyCodeKey) as? Int
        return UInt32(saved ?? Int(ECLFormatHotKeyConstants.defaultKeyCode))
    }

    /// Thread-safe access to modifiers for non-MainActor contexts.
    nonisolated static var currentModifiers: NSEvent.ModifierFlags {
        let saved = UserDefaults.standard.object(forKey: ECLFormatHotKeyConstants.modifiersKey) as? Int
        let raw = UInt32(saved ?? Int(ECLFormatHotKeyConstants.defaultModifiers))
        var f: NSEvent.ModifierFlags = []
        if (raw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { f.insert(.control) }
        if (raw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { f.insert(.option) }
        if (raw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { f.insert(.command) }
        if (raw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { f.insert(.shift) }
        return f
    }

    /// Human-readable description of the current hotkey with modifier symbols (e.g., "⌃⌥E").
    var hotkeyDescription: String {
        KeyCodeFormatter.format(keyCode: keyCode, modifiers: modifiersRaw)
    }
}
