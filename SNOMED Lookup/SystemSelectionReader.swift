import Cocoa
import Carbon.HIToolbox

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
                    return "[U+\(String(format: "%04X", ch.unicodeScalars.first!.value))]"
                }
            } else {
                return String(ch)
            }
        }.joined()
    }
}
