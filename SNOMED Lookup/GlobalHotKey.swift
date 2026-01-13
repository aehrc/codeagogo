import Carbon
import Cocoa

/// Minimal global hotkey using Carbon.
/// Note: Global hotkeys can conflict with system/app shortcuts - you can make this configurable later.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    private var keyCode: UInt32
    private var modifiers: UInt32

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = Self.carbonModifiers(from: modifiers)
        self.handler = handler
    }

    func start() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            me.handler?()
            return noErr
        }, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)

        let hotKeyID = EventHotKeyID(signature: OSType("SNMD".fourCharCodeValue), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    func update(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        stop()
        self.keyCode = keyCode
        self.modifiers = Self.carbonModifiers(from: modifiers)
        start()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for scalar in unicodeScalars.prefix(4) {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}
