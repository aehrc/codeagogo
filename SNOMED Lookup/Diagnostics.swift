import Foundation
import AppKit
import OSLog

enum Diagnostics {

    static func copyRecentLogsToClipboard(minutes: Int = 15) {
        let subsystem = AppLog.subsystem

        var outputLines: [String] = []
        outputLines.append("SNOMED Lookup diagnostics")
        outputLines.append("Subsystem: \(subsystem)")
        outputLines.append("Window: last \(minutes) minutes")
        outputLines.append("")

        guard #available(macOS 10.15, *) else {
            outputLines.append(fallbackInstructions(subsystem: subsystem))
            outputLines.append("")
            outputLines.append("Export failure: OSLogStore requires macOS 10.15+")
            writeClipboard(outputLines.joined(separator: "\n"))
            AppLog.info(AppLog.general, "Diagnostics copy attempted on unsupported macOS")
            return
        }

        let startDate = Date().addingTimeInterval(TimeInterval(-minutes * 60))

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: startDate)
            let entries = try store.getEntries(at: position)

            var matched = 0
            let formatter = ISO8601DateFormatter()

            func levelText(_ level: OSLogEntryLog.Level) -> String {
                switch level {
                case .undefined: return "UNDEFINED"
                case .debug: return "DEBUG"
                case .info: return "INFO"
                case .notice: return "NOTICE"
                case .error: return "ERROR"
                case .fault: return "FAULT"
                @unknown default: return "UNKNOWN"
                }
            }

            for case let entry as OSLogEntryLog in entries {
                guard entry.subsystem == subsystem else { continue }

                matched += 1

                let ts = formatter.string(from: entry.date)
                let category = entry.category
                let level = levelText(entry.level)
                let msg = entry.composedMessage

                outputLines.append("[\(ts)] [\(level)] [\(category)] \(msg)")
            }

            if matched == 0 {
                outputLines.append(fallbackInstructions(subsystem: subsystem))
            }

        } catch {
            outputLines.append(fallbackInstructions(subsystem: subsystem))
            outputLines.append("")
            outputLines.append("Export failure: \(error.localizedDescription)")
        }

        writeClipboard(outputLines.joined(separator: "\n"))
        AppLog.info(AppLog.general, "Diagnostics copied to clipboard (window=\(minutes)m)")
    }

    private static func writeClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private static func fallbackInstructions(subsystem: String) -> String {
        """
        Could not automatically export logs.

        Please open Console.app and search for:
        \(subsystem)

        Then reproduce the issue and copy the relevant lines.

        Tip: ensure Console is showing All Messages (not Errors only).
        """
    }
}
