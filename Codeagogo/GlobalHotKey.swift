import Carbon
import Cocoa

/// Registers and manages a system-wide global hotkey using the Carbon framework.
///
/// `GlobalHotKey` provides a way to register keyboard shortcuts that work
/// from any application. This is necessary for Codeagogo to respond to
/// its hotkey regardless of which app is currently focused.
///
/// ## Why Carbon?
///
/// macOS does not provide a modern API for global keyboard shortcuts. The
/// Carbon `RegisterEventHotKey` API remains the only supported method for
/// registering system-wide hotkeys that work in any application.
///
/// ## Usage
///
/// ```swift
/// let hotKey = GlobalHotKey(
///     keyCode: kVK_ANSI_L,
///     modifiers: [.control, .option],
///     handler: { print("Hotkey pressed!") }
/// )
///
/// hotKey.start()  // Begin listening
/// // ... later ...
/// hotKey.stop()   // Stop listening
/// ```
///
/// ## Memory Management
///
/// The `deinit` automatically calls `stop()` to clean up Carbon event handlers,
/// preventing memory leaks and ensuring the hotkey is properly unregistered.
///
/// ## Thread Safety
///
/// This class should be used from the main thread only, as Carbon event
/// handlers are delivered on the main thread.
///
/// - Note: Global hotkeys may conflict with system or application shortcuts.
///         The hotkey is configurable via Settings to avoid conflicts.
final class GlobalHotKey {
    /// Reference to the registered hotkey (for unregistration).
    private var hotKeyRef: EventHotKeyRef?

    /// Reference to the event handler (for cleanup).
    private var eventHandlerRef: EventHandlerRef?

    /// The callback to invoke when the hotkey is pressed.
    private var handler: (() -> Void)?

    /// The virtual key code (e.g., `kVK_ANSI_L` for the L key).
    private var keyCode: UInt32

    /// Carbon modifier flags (converted from `NSEvent.ModifierFlags`).
    private var modifiers: UInt32

    /// Unique identifier for this hotkey (allows multiple hotkeys to coexist).
    private let hotKeyId: UInt32

    /// Creates a new global hotkey handler.
    ///
    /// The hotkey is not active until `start()` is called.
    ///
    /// - Parameters:
    ///   - keyCode: The virtual key code for the hotkey
    ///   - modifiers: The modifier keys required (Control, Option, Command, Shift)
    ///   - id: Unique identifier for this hotkey (default: 1). Use different IDs
    ///         for multiple hotkeys (e.g., 1 for lookup, 2 for search).
    ///   - handler: The closure to execute when the hotkey is pressed
    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, id: UInt32 = 1, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = HotKeySettings.carbonModifiers(from: modifiers)
        self.hotKeyId = id
        self.handler = handler
    }

    /// Cleans up the hotkey registration when deallocated.
    deinit {
        stop()
    }

    /// Starts listening for the global hotkey.
    ///
    /// Installs a Carbon event handler for keyboard events and registers
    /// the hotkey with the system. When the hotkey is pressed, the handler
    /// closure is called.
    ///
    /// - Note: Call `stop()` to unregister the hotkey, or it will be
    ///         automatically unregistered when this instance is deallocated.
    func start() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()

            // Extract the hotkey ID from the event to match against this instance
            var firedKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &firedKeyID
            )
            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            // Only handle if the ID matches this instance
            guard firedKeyID.id == me.hotKeyId else { return OSStatus(eventNotHandledErr) }

            me.handler?()
            return noErr
        }, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &handlerRef)
        eventHandlerRef = handlerRef

        let hotKeyID = EventHotKeyID(signature: OSType("SNMD".fourCharCodeValue), id: hotKeyId)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    /// Stops listening for the global hotkey.
    ///
    /// Unregisters the hotkey and removes the event handler. Safe to call
    /// multiple times or if `start()` was never called.
    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    /// Updates the hotkey to use a new key code and modifiers.
    ///
    /// This stops the current hotkey registration and starts a new one
    /// with the updated settings. Used when the user changes the hotkey
    /// in Settings.
    ///
    /// - Parameters:
    ///   - keyCode: The new virtual key code
    ///   - modifiers: The new modifier flags
    func update(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        stop()
        self.keyCode = keyCode
        self.modifiers = HotKeySettings.carbonModifiers(from: modifiers)
        start()
    }
}

// MARK: - String Extension

private extension String {
    /// Converts a string (up to 4 characters) to a FourCharCode.
    ///
    /// Used to create the unique signature for hotkey registration.
    /// For example, "SNMD" becomes a unique 32-bit identifier.
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for scalar in unicodeScalars.prefix(4) {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}
