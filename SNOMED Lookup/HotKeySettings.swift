import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeySettings: ObservableObject {
    static let shared = HotKeySettings()

    @Published var keyCode: UInt32
    @Published var modifiersRaw: UInt32

    private static let keyCodeKey = "hotkey.keyCode"
    private static let modifiersKey = "hotkey.modifiersRaw"
    private static let defaultKeyCode = UInt32(kVK_ANSI_L)
    private static let defaultModifiers: UInt32 = carbonModifiers(from: [.control, .option])

    private init() {
        let savedKey = UserDefaults.standard.object(forKey: Self.keyCodeKey) as? Int
        let savedMods = UserDefaults.standard.object(forKey: Self.modifiersKey) as? Int

        self.keyCode = UInt32(savedKey ?? Int(Self.defaultKeyCode))
        self.modifiersRaw = UInt32(savedMods ?? Int(Self.defaultModifiers))
    }

    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: Self.keyCodeKey)
        UserDefaults.standard.set(Int(modifiersRaw), forKey: Self.modifiersKey)
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
        let saved = UserDefaults.standard.object(forKey: keyCodeKey) as? Int
        return UInt32(saved ?? Int(defaultKeyCode))
    }

    /// Thread-safe access to modifiers for non-MainActor contexts.
    nonisolated static var currentModifiers: NSEvent.ModifierFlags {
        let saved = UserDefaults.standard.object(forKey: modifiersKey) as? Int
        let raw = UInt32(saved ?? Int(defaultModifiers))
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

    /// Human-readable description of the current hotkey (e.g., "Control-Option-L")
    var hotkeyDescription: String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }

        parts.append(keyName(for: keyCode))

        return parts.joined(separator: "-")
    }

    private func keyName(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_U: return "U"
        default: return "?"
        }
    }
}
