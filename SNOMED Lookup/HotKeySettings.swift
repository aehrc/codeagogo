import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeySettings: ObservableObject {
    static let shared = HotKeySettings()

    @Published var keyCode: UInt32
    @Published var modifiersRaw: UInt32

    private let keyCodeKey = "hotkey.keyCode"
    private let modifiersKey = "hotkey.modifiersRaw"

    private init() {
        // Default: Control + Option + L
        let defaultKey = UInt32(kVK_ANSI_L)
        let defaultMods: UInt32 = Self.carbonModifiers(from: [.control, .option])

        let savedKey = UserDefaults.standard.object(forKey: keyCodeKey) as? Int
        let savedMods = UserDefaults.standard.object(forKey: modifiersKey) as? Int

        self.keyCode = UInt32(savedKey ?? Int(defaultKey))
        self.modifiersRaw = UInt32(savedMods ?? Int(defaultMods))
    }

    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(modifiersRaw), forKey: modifiersKey)
    }

    var modifiers: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if (modifiersRaw & Self.carbonModifiers(from: [.control])) != 0 { f.insert(.control) }
        if (modifiersRaw & Self.carbonModifiers(from: [.option])) != 0 { f.insert(.option) }
        if (modifiersRaw & Self.carbonModifiers(from: [.command])) != 0 { f.insert(.command) }
        if (modifiersRaw & Self.carbonModifiers(from: [.shift])) != 0 { f.insert(.shift) }
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
