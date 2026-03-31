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

import Cocoa
import Carbon.HIToolbox
import ApplicationServices

/// Captures the current text selection from the frontmost application.
///
/// `SystemSelectionReader` provides a way to read selected text from any
/// macOS application by simulating a Cmd+C keystroke and reading the
/// resulting clipboard contents.
///
/// ## How It Works
///
/// 1. **Snapshot** the current clipboard contents
/// 2. **Clear** the clipboard to detect if copy succeeds
/// 3. **Simulate** Cmd+C using CoreGraphics events
/// 4. **Wait** briefly for the copy operation to complete
/// 5. **Read** the copied text from the clipboard
/// 6. **Restore** the original clipboard contents
///
/// ## Requirements
///
/// This class requires **Accessibility permission** to function. Without this
/// permission, the simulated keystroke will fail silently.
///
/// Users must grant permission in:
/// **System Settings → Privacy & Security → Accessibility**
///
/// ## Thread Safety
///
/// This class is **not thread-safe**. It should only be called from one
/// thread at a time, typically from the main thread via the view model.
///
/// ## Example
///
/// ```swift
/// let reader = SystemSelectionReader()
///
/// do {
///     let selectedText = try reader.readSelectionByCopying()
///     print("Selected: \(selectedText)")
/// } catch LookupError.accessibilityPermissionLikelyMissing {
///     print("Please grant Accessibility permission")
/// }
/// ```
///
/// ## Known Limitations
///
/// There is an inherent race condition in the clipboard-based selection
/// capture approach: if another application modifies the clipboard between
/// the snapshot and restore steps, those changes will be lost. This is a
/// fundamental limitation of the technique and cannot be fully mitigated.
/// The window is typically under 100ms, making conflicts rare in practice.
///
/// - Note: The clipboard is always restored after reading, even if the
///         copy operation fails or the text is empty.
final class SystemSelectionReader {

    /// Delay after sending Cmd+C before reading clipboard (seconds).
    ///
    /// This delay allows time for the frontmost application to process
    /// the copy command and update the clipboard.
    private let clipboardCopyDelay: TimeInterval = 0.08

    /// A snapshot of the pasteboard state for later restoration.
    private struct PasteboardSnapshot {
        /// All pasteboard items with their types and data.
        let items: [[NSPasteboard.PasteboardType: Data]]
        /// The change count at snapshot time (unused but captured for completeness).
        let changeCount: Int
    }

    /// Reads the currently selected text by simulating a copy operation.
    ///
    /// This method temporarily hijacks the system clipboard to capture the
    /// selection, then restores the original clipboard contents.
    ///
    /// - Returns: The selected text as a string. Returns an empty string if
    ///            nothing was selected or the copy operation produced no text.
    /// - Throws: `LookupError.accessibilityPermissionLikelyMissing` if the
    ///           simulated Cmd+C keystroke fails (usually due to missing
    ///           Accessibility permission).
    func readSelectionByCopying() throws -> String {
        let pb = NSPasteboard.general
        let snapshot = snapshotPasteboard(pb)

        // Clear so we can detect whether copy worked
        pb.clearContents()

        // Send Cmd+C to the frontmost app
        guard sendCmdC() else {
            restorePasteboard(pb, snapshot: snapshot)
            throw LookupError.accessibilityPermissionLikelyMissing
        }

        // Small wait for the copy to complete
        Thread.sleep(forTimeInterval: clipboardCopyDelay)

        // Read copied text
        let copied = pb.string(forType: .string) ?? ""

        // Debug logging (only when enabled in settings)
        if AppLog.isDebugEnabled {
            AppLog.debug(AppLog.selection, "raw clipboard string: '\(copied)'")
            AppLog.debug(AppLog.selection, "debug chars: \(debugDescribe(copied))")
            AppLog.debug(AppLog.selection, "utf16 count: \(copied.utf16.count)")
        }

        // Restore clipboard
        restorePasteboard(pb, snapshot: snapshot)

        return copied
    }

    /// Creates a snapshot of all items currently on the pasteboard.
    ///
    /// This captures all data for all types on each pasteboard item,
    /// allowing complete restoration of the clipboard state later.
    ///
    /// - Parameter pb: The pasteboard to snapshot
    /// - Returns: A snapshot containing all items and their data
    private func snapshotPasteboard(_ pb: NSPasteboard) -> PasteboardSnapshot {
        let items = (pb.pasteboardItems ?? []).map { item -> [NSPasteboard.PasteboardType: Data] in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
        return PasteboardSnapshot(items: items, changeCount: pb.changeCount)
    }

    /// Restores the pasteboard to a previously captured state.
    ///
    /// This method clears the current pasteboard contents and writes
    /// back all items from the snapshot. If the snapshot is empty,
    /// the pasteboard is left cleared.
    ///
    /// - Parameters:
    ///   - pb: The pasteboard to restore
    ///   - snapshot: The previously captured state to restore
    private func restorePasteboard(_ pb: NSPasteboard, snapshot: PasteboardSnapshot) {
        pb.clearContents()
        guard !snapshot.items.isEmpty else { return }

        let newItems: [NSPasteboardItem] = snapshot.items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }

        // Now safe: these are new items not associated with any pasteboard yet
        pb.writeObjects(newItems)
    }

    /// Simulates a Cmd+C keystroke to trigger a copy operation.
    ///
    /// This uses CoreGraphics to create and post keyboard events to the
    /// system event tap. The events are sent to whichever application
    /// is currently frontmost.
    ///
    /// - Returns: `true` if the events were successfully created and posted,
    ///            `false` if event creation failed (usually due to missing
    ///            Accessibility permission)
    private func sendCmdC() -> Bool {
        guard
            let src = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else { return false }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    /// Simulates a Cmd+V keystroke to trigger a paste operation.
    ///
    /// This uses CoreGraphics to create and post keyboard events to the
    /// system event tap. The events are sent to whichever application
    /// is currently frontmost.
    ///
    /// - Returns: `true` if the events were successfully created and posted,
    ///            `false` if event creation failed (usually due to missing
    ///            Accessibility permission)
    func sendCmdV() -> Bool {
        guard
            let src = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else { return false }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }


    /// Converts a string to a debug representation with visible whitespace.
    ///
    /// Used for debug logging to make whitespace characters visible:
    /// - Space → ␣
    /// - Newline → \n
    /// - Tab → \t
    /// - Other whitespace → [U+XXXX]
    ///
    /// - Parameter s: The string to convert
    /// - Returns: A string with whitespace characters made visible
    private func debugDescribe(_ s: String) -> String {
        s.map { ch -> String in
            if ch.isWhitespace {
                switch ch {
                case " ":
                    return "␣"
                case "\n":
                    return "\\n"
                case "\t":
                    return "\\t"
                default:
                    // Character always has at least one unicode scalar
                    // swiftlint:disable:next force_unwrapping
                    return "[U+\(String(format: "%04X", ch.unicodeScalars.first!.value))]"
                }
            } else {
                return String(ch)
            }
        }.joined()
    }

    // MARK: - Accessibility API for Selection

    /// Gets the currently focused UI element that accepts text input.
    ///
    /// This uses the Accessibility API to find the element that currently
    /// has keyboard focus. This is typically a text field, text view, or
    /// similar text input control.
    ///
    /// Includes retry logic to handle timing issues during hotkey processing.
    ///
    /// - Parameter maxRetries: Maximum number of retry attempts (default: 3)
    /// - Returns: The focused AXUIElement, or nil if none found
    private func getFocusedElement(maxRetries: Int = 3) -> AXUIElement? {
        for attempt in 1...maxRetries {
            if let element = getFocusedElementOnce() {
                return element
            }

            if attempt < maxRetries {
                // Longer delay before retry to allow focus state to settle
                Thread.sleep(forTimeInterval: 0.1)
                AppLog.info(AppLog.selection, "getFocusedElement: retry attempt \(attempt + 1)/\(maxRetries)")
            }
        }

        AppLog.info(AppLog.selection, "getFocusedElement: failed after \(maxRetries) attempts")
        return nil
    }

    /// Single attempt to get the focused UI element.
    private func getFocusedElementOnce() -> AXUIElement? {
        // First try: get frontmost app from NSWorkspace (more reliable during hotkey processing)
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            AppLog.info(AppLog.selection, "getFocusedElement: no frontmost application")
            return nil
        }

        let pid = frontmostApp.processIdentifier
        let appName = frontmostApp.localizedName ?? "unknown"
        let myPid = ProcessInfo.processInfo.processIdentifier

        // Check if we're accidentally checking our own app
        if pid == myPid {
            AppLog.info(AppLog.selection, "getFocusedElement: frontmost is SELF (our app), skipping")
            return nil
        }

        let isMainThread = Thread.isMainThread
        AppLog.info(AppLog.selection, "getFocusedElement: frontmost app=\(appName) pid=\(pid) mainThread=\(isMainThread)")

        let appElement = AXUIElementCreateApplication(pid)

        // First verify we can read basic attributes from the app element
        var appTitle: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(appElement, kAXTitleAttribute as CFString, &appTitle)
        AppLog.info(AppLog.selection, "getFocusedElement: app title query result=\(titleResult.rawValue) title=\(appTitle as? String ?? "nil")")

        // Try to get the focused UI element from this app
        var focusedElement: AnyObject?
        let elemResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        // AXUIElement is a CFType; cast is guaranteed after .success
        if elemResult == .success, let element = focusedElement {
            let axElement = element as! AXUIElement
            // Log the element's role and other attributes
            var role: AnyObject?
            AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role)
            let roleStr = role as? String ?? "unknown"

            // Check if this element supports selection
            var hasSelectionAttr: DarwinBoolean = false
            AXUIElementIsAttributeSettable(axElement, kAXSelectedTextRangeAttribute as CFString, &hasSelectionAttr)

            AppLog.info(AppLog.selection, "getFocusedElement: SUCCESS role=\(roleStr) supportsSelection=\(hasSelectionAttr.boolValue)")
            return axElement
        }

        // Log the specific error
        let errorName: String
        switch elemResult {
        case .success: errorName = "success"
        case .failure: errorName = "failure"
        case .illegalArgument: errorName = "illegalArgument"
        case .invalidUIElement: errorName = "invalidUIElement"
        case .invalidUIElementObserver: errorName = "invalidUIElementObserver"
        case .cannotComplete: errorName = "cannotComplete"
        case .attributeUnsupported: errorName = "attributeUnsupported"
        case .actionUnsupported: errorName = "actionUnsupported"
        case .notificationUnsupported: errorName = "notificationUnsupported"
        case .notImplemented: errorName = "notImplemented"
        case .notificationAlreadyRegistered: errorName = "notificationAlreadyRegistered"
        case .notificationNotRegistered: errorName = "notificationNotRegistered"
        case .apiDisabled: errorName = "apiDisabled"
        case .noValue: errorName = "noValue"
        case .parameterizedAttributeUnsupported: errorName = "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: errorName = "notEnoughPrecision"
        @unknown default: errorName = "unknown(\(elemResult.rawValue))"
        }
        AppLog.info(AppLog.selection, "getFocusedElement: FAILED app=\(appName) error=\(errorName) (\(elemResult.rawValue))")

        // Also try system-wide as fallback
        let systemWide = AXUIElementCreateSystemWide()
        var sysApp: AnyObject?
        let sysAppResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &sysApp
        )

        guard sysAppResult == .success, let app = sysApp else {
            AppLog.info(AppLog.selection, "getFocusedElement: system-wide also failed error=\(sysAppResult.rawValue)")
            return nil
        }

        // AXUIElement is a CFType; cast is guaranteed after .success
        // swiftlint:disable:next force_cast
        let sysAppElement = app as! AXUIElement
        var sysElement: AnyObject?
        let sysElemResult = AXUIElementCopyAttributeValue(
            sysAppElement,
            kAXFocusedUIElementAttribute as CFString,
            &sysElement
        )

        guard sysElemResult == .success, let element = sysElement else {
            AppLog.info(AppLog.selection, "getFocusedElement: system-wide focused element error=\(sysElemResult.rawValue)")
            return nil
        }

        // AXUIElement is a CFType; cast is guaranteed after .success
        // swiftlint:disable:next force_cast
        let axElement = element as! AXUIElement
        // Log the element's role
        var sysRole: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &sysRole) == .success {
            AppLog.info(AppLog.selection, "getFocusedElement: system-wide element role=\(sysRole as? String ?? "unknown")")
        }

        return axElement
    }

    /// Gets the current selection range from the focused text element.
    ///
    /// The selection range indicates where the cursor is (if length is 0)
    /// or what text is selected (if length > 0).
    ///
    /// - Returns: The current selection as a CFRange, or nil if unavailable
    func getSelectionRange() -> CFRange? {
        guard let element = getFocusedElement() else {
            return nil
        }

        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success else {
            AppLog.debug(AppLog.selection, "Could not get selected text range")
            return nil
        }

        // AXValue is a CFType; cast is guaranteed after .success
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
            AppLog.debug(AppLog.selection, "Could not extract CFRange from AXValue")
            return nil
        }

        return range
    }

    /// Sets the selection range on the focused text element.
    ///
    /// This can be used after pasting text to select the inserted content,
    /// allowing the user to easily see what was inserted or undo the operation.
    ///
    /// - Parameters:
    ///   - location: The start position of the selection (0-based character index)
    ///   - length: The number of characters to select
    /// - Returns: `true` if the selection was set successfully, `false` otherwise
    @discardableResult
    func setSelectionRange(location: Int, length: Int) -> Bool {
        guard let element = getFocusedElement() else {
            AppLog.debug(AppLog.selection, "setSelectionRange: no focused element")
            return false
        }

        var range = CFRange(location: location, length: length)
        guard let axRange = AXValueCreate(.cfRange, &range) else {
            AppLog.debug(AppLog.selection, "setSelectionRange: could not create AXValue")
            return false
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            axRange
        )

        if result == .success {
            AppLog.debug(AppLog.selection, "setSelectionRange: set selection to (\(location), \(length))")
            return true
        } else {
            AppLog.debug(AppLog.selection, "setSelectionRange: failed with error \(result.rawValue)")
            return false
        }
    }

    /// Pastes text and selects the inserted content.
    ///
    /// This method:
    /// 1. Pastes the clipboard contents via Cmd+V
    /// 2. Waits for the paste to complete
    /// 3. Gets the cursor position after paste (cursor is at end of inserted text)
    /// 4. Selects backwards from cursor using Accessibility API or keyboard fallback
    ///
    /// - Parameter textLength: The length of the text being pasted (in UTF-16 code units)
    /// - Returns: `true` if paste succeeded, `false` otherwise
    /// - Note: Selection may fail in some apps that don't support AXSelectedTextRangeAttribute
    func pasteAndSelect(textLength: Int) -> Bool {
        // Check if accessibility is trusted
        let trusted = AXIsProcessTrusted()
        AppLog.info(AppLog.selection, "pasteAndSelect: AXIsProcessTrusted=\(trusted), textLength=\(textLength)")

        // Perform the paste first
        guard sendCmdV() else {
            AppLog.warning(AppLog.selection, "pasteAndSelect: sendCmdV failed")
            return false
        }

        // Wait for paste to complete and focus to stabilize
        // Using a longer delay (0.25s) to ensure the target app has fully processed the paste
        Thread.sleep(forTimeInterval: 0.25)

        // After paste, cursor is at end of inserted text.
        // Try to get cursor position and select backwards using Accessibility API.
        var selectionSuccess = false

        if let cursorPosition = getSelectionRange() {
            // Cursor should be at position (insertionPoint + textLength) with length 0
            // We want to select from (cursorPosition.location - textLength) to cursorPosition.location
            let selectionStart = cursorPosition.location - textLength
            if selectionStart >= 0 {
                selectionSuccess = setSelectionRange(location: selectionStart, length: textLength)
                AppLog.info(AppLog.selection, "pasteAndSelect: setSelectionRange(\(selectionStart), \(textLength)) = \(selectionSuccess)")

                // Verify the selection was set
                if selectionSuccess, let newSelection = getSelectionRange() {
                    AppLog.info(AppLog.selection, "pasteAndSelect: actual selection = (\(newSelection.location), \(newSelection.length))")
                }
            } else {
                AppLog.info(AppLog.selection, "pasteAndSelect: selectionStart would be negative (\(selectionStart)), skipping AX selection")
            }
        } else {
            AppLog.info(AppLog.selection, "pasteAndSelect: could not get cursor position after paste")
        }

        // Fallback: if Accessibility API failed, try keyboard simulation
        // After paste, cursor is at end of pasted text. Use Shift+Left Arrow to select backwards.
        if !selectionSuccess {
            if textLength > maxKeyboardSelectionChars {
                AppLog.info(AppLog.selection, "pasteAndSelect: skipping selection for large text (\(textLength) chars > \(maxKeyboardSelectionChars) threshold)")
            } else {
                AppLog.info(AppLog.selection, "pasteAndSelect: trying keyboard fallback to select pasted text")
                selectBackwards(characterCount: textLength)
            }
        }

        return true
    }

    /// Maximum characters to attempt selection via keyboard fallback.
    /// Above this threshold, selection is skipped to avoid UI delays.
    private let maxKeyboardSelectionChars = 1000

    /// Selects text backwards from current cursor position using keyboard shortcuts.
    ///
    /// This is a fallback for when the Accessibility API doesn't work.
    /// Always uses character-by-character selection (Shift+Left Arrow) for precision.
    /// Word-by-word selection was tried but is unreliable due to varying token sizes
    /// (especially for code/ECL which has many short tokens).
    ///
    /// - For selections up to 1000 chars: Shift+Left Arrow (character-by-character, precise)
    /// - For very large selections (> 1000 chars): Skipped to avoid UI delays
    ///
    /// - Parameter characterCount: Number of characters to select backwards (UTF-16 code units)
    private func selectBackwards(characterCount: Int) {
        // Skip selection for very large text to avoid delays
        if characterCount > maxKeyboardSelectionChars {
            AppLog.info(AppLog.selection, "selectBackwards: skipping selection for \(characterCount) chars (exceeds threshold of \(maxKeyboardSelectionChars))")
            return
        }

        guard let src = CGEventSource(stateID: .combinedSessionState) else {
            AppLog.warning(AppLog.selection, "selectBackwards: could not create event source")
            return
        }

        AppLog.info(AppLog.selection, "selectBackwards: selecting \(characterCount) characters with Shift+Left Arrow")
        sendShiftLeftArrow(count: characterCount, source: src)
        AppLog.info(AppLog.selection, "selectBackwards: done")
    }

    /// Sends Shift+Left Arrow keystrokes for character-by-character selection.
    private func sendShiftLeftArrow(count: Int, source: CGEventSource) {
        for _ in 0..<count {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_LeftArrow), keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_LeftArrow), keyDown: false) else {
                continue
            }
            keyDown.flags = .maskShift
            keyUp.flags = .maskShift
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
