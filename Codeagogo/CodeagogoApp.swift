import SwiftUI

@main
struct Snomed_LookupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            // Add items in the Help menu (native place for diagnostics)
            CommandGroup(after: .help) {
                Button("Copy Codeagogo Diagnostics") {
                    Diagnostics.copyRecentLogsToClipboard(minutes: 15)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                // Optional: quick toggle without opening Settings
                Toggle("Enable Debug Logging", isOn: Binding(
                    get: { AppLog.isDebugEnabled },
                    set: { AppLog.isDebugEnabled = $0 }
                ))
            }
        }
    }
}
