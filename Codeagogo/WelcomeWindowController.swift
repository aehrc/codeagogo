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
import SwiftUI

/// Manages the welcome screen window lifecycle.
///
/// Presents a centered, standalone window hosting `WelcomeView` on first launch.
/// Marks the welcome screen as shown when the window closes by any means
/// (Get Started button, Cmd+W, window close button).
///
/// ## Usage
///
/// ```swift
/// // Show the welcome screen (typically from AppDelegate)
/// WelcomeWindowController.show()
/// ```
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    /// The welcome window.
    private var window: NSWindow?

    /// Singleton instance retained while the window is open.
    private static var current: WelcomeWindowController?

    /// Shows the welcome screen as a centered standalone window.
    ///
    /// Creates a new window if one is not already visible. The window is
    /// centered on screen and made key. Only one welcome window can be
    /// open at a time.
    static func show() {
        guard current == nil else {
            current?.window?.makeKeyAndOrderFront(nil)
            return
        }

        let controller = WelcomeWindowController()
        current = controller
        controller.presentWindow()
    }

    private func presentWindow() {
        let welcomeView = WelcomeView(onDismiss: { [weak self] in
            self?.close()
        })

        let hostingView = NSHostingView(rootView: welcomeView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Welcome to Codeagogo"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.window = window

        // Activate the app and show the window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Closes the welcome window and marks the welcome as shown.
    private func close() {
        WelcomeSettings.shared.markAsShown()
        window?.close()
        Self.current = nil
    }

    // MARK: - NSWindowDelegate

    /// Called when the window is about to close (by any means).
    ///
    /// Ensures the welcome is marked as shown regardless of how the user
    /// closes the window (Cmd+W, close button, or Get Started button).
    func windowWillClose(_ notification: Notification) {
        WelcomeSettings.shared.markAsShown()
        // Force UserDefaults to persist immediately
        UserDefaults.standard.synchronize()
        AppLog.info(AppLog.ui, "Welcome screen dismissed, hasShown=\(WelcomeSettings.shared.hasShown)")
        Self.current = nil
    }
}
