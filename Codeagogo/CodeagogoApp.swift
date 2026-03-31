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
