import Cocoa
import Carbon.HIToolbox

/// Reads the current selection from the frontmost app by:
/// - snapshot clipboard data
/// - send Cmd+C
/// - read clipboard string
/// - restore clipboard data
///
/// Requires Accessibility permission to send key events.
final class SystemSelectionReader {

    /// Delay after sending Cmd+C before reading clipboard (seconds)
    private let clipboardCopyDelay: TimeInterval = 0.08

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
        let changeCount: Int
    }

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
