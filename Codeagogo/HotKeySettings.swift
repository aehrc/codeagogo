import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

/// Constants used by HotKeySettings, accessible from any isolation context.
private enum HotKeyConstants: Sendable {
    static let keyCodeKey = "hotkey.keyCode"
    static let modifiersKey = "hotkey.modifiersRaw"
    // kVK_ANSI_L = 0x25 = 37
    static let defaultKeyCode: UInt32 = 37
    // controlKey | optionKey = 0x1000 | 0x0800 = 0x1800 = 6144
    static let defaultModifiers: UInt32 = 6144
}

@MainActor
final class HotKeySettings: ObservableObject {
    static let shared = HotKeySettings()

    @Published var keyCode: UInt32
    @Published var modifiersRaw: UInt32

    private init() {
        let savedKey = UserDefaults.standard.object(forKey: HotKeyConstants.keyCodeKey) as? Int
        let savedMods = UserDefaults.standard.object(forKey: HotKeyConstants.modifiersKey) as? Int

        self.keyCode = UInt32(savedKey ?? Int(HotKeyConstants.defaultKeyCode))
        self.modifiersRaw = UInt32(savedMods ?? Int(HotKeyConstants.defaultModifiers))
    }

    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: HotKeyConstants.keyCodeKey)
        UserDefaults.standard.set(Int(modifiersRaw), forKey: HotKeyConstants.modifiersKey)
    }

    var modifiers: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if (modifiersRaw & Self.carbonModifiers(from: [.control])) != 0 { f.insert(.control) }
        if (modifiersRaw & Self.carbonModifiers(from: [.option])) != 0 { f.insert(.option) }
        if (modifiersRaw & Self.carbonModifiers(from: [.command])) != 0 { f.insert(.command) }
        if (modifiersRaw & Self.carbonModifiers(from: [.shift])) != 0 { f.insert(.shift) }
        return f
    }

    /// Thread-safe access to key code for non-MainActor contexts.
    nonisolated static var currentKeyCode: UInt32 {
        let saved = UserDefaults.standard.object(forKey: HotKeyConstants.keyCodeKey) as? Int
        return UInt32(saved ?? Int(HotKeyConstants.defaultKeyCode))
    }

    /// Thread-safe access to modifiers for non-MainActor contexts.
    nonisolated static var currentModifiers: NSEvent.ModifierFlags {
        let saved = UserDefaults.standard.object(forKey: HotKeyConstants.modifiersKey) as? Int
        let raw = UInt32(saved ?? Int(HotKeyConstants.defaultModifiers))
        var f: NSEvent.ModifierFlags = []
        if (raw & carbonModifiers(from: [.control])) != 0 { f.insert(.control) }
        if (raw & carbonModifiers(from: [.option])) != 0 { f.insert(.option) }
        if (raw & carbonModifiers(from: [.command])) != 0 { f.insert(.command) }
        if (raw & carbonModifiers(from: [.shift])) != 0 { f.insert(.shift) }
        return f
    }

    /// Converts NSEvent.ModifierFlags to Carbon modifier mask
    nonisolated static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    /// Human-readable description of the current hotkey with modifier symbols (e.g., "⌃⌥L").
    var hotkeyDescription: String {
        KeyCodeFormatter.format(keyCode: keyCode, modifiers: modifiersRaw)
    }
}
