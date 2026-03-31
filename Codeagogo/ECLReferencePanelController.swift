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

/// Manages the floating ECL operator reference panel window.
///
/// Creates and manages an NSPanel that hosts the `ECLReferencePanelView`.
/// The panel remembers its size and position between sessions.
///
/// ## Usage
///
/// ```swift
/// let controller = ECLReferencePanelController()
/// controller.show(at: NSEvent.mouseLocation)
/// ```
@MainActor
final class ECLReferencePanelController: NSObject {

    /// The floating panel window.
    private var panel: NSPanel?

    /// Bridge to ecl-core for loading knowledge base.
    private let eclBridge = ECLBridge()

    /// Cached knowledge articles loaded from ecl-core.
    private lazy var articles: [ECLBridge.KnowledgeArticle] = {
        let items = eclBridge.getArticles()
        AppLog.debug(AppLog.ui, "ECL reference: loaded \(items.count) articles")
        return items
    }()

    /// Whether the panel is currently visible.
    var isShown: Bool {
        panel?.isVisible ?? false
    }

    /// Shows the ECL reference panel.
    ///
    /// If the panel is already visible, brings it to front. Otherwise
    /// creates a new panel and positions it near the specified point.
    ///
    /// - Parameter point: The screen point to position near (typically mouse location)
    func show(at point: NSPoint) {
        if let existingPanel = panel, existingPanel.isVisible {
            existingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let referenceView = ECLReferencePanelView(
            onClose: { [weak self] in self?.close() },
            articles: articles
        )

        let defaultSize = NSRect(x: 0, y: 0, width: 520, height: 600)

        let newPanel = NSPanel(
            contentRect: defaultSize,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        let hostingView = NSHostingView(rootView: referenceView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        newPanel.contentView = hostingView

        newPanel.title = "ECL Reference"
        newPanel.isReleasedWhenClosed = false
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.minSize = NSSize(width: 380, height: 300)
        newPanel.delegate = self

        // Restore saved size/position, or position near cursor on first use
        newPanel.setFrameAutosaveName("ECLReferencePanel")
        if !newPanel.setFrameUsingName("ECLReferencePanel") {
            positionPanel(newPanel, near: point)
        }

        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        panel = newPanel
        AppLog.info(AppLog.ui, "ECL reference panel shown")
    }

    /// Closes the reference panel.
    func close() {
        guard let panel else { return }
        panel.close()
        self.panel = nil
    }

    /// Positions the panel near the specified screen point.
    private func positionPanel(_ panel: NSPanel, near point: NSPoint) {
        guard let screen = NSScreen.main else { return }

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 20

        var origin = NSPoint(
            x: point.x - panelSize.width / 2,
            y: point.y - panelSize.height / 2
        )

        if origin.x < screenFrame.minX + margin {
            origin.x = screenFrame.minX + margin
        } else if origin.x + panelSize.width > screenFrame.maxX - margin {
            origin.x = screenFrame.maxX - panelSize.width - margin
        }

        if origin.y < screenFrame.minY + margin {
            origin.y = screenFrame.minY + margin
        } else if origin.y + panelSize.height > screenFrame.maxY - margin {
            origin.y = screenFrame.maxY - panelSize.height - margin
        }

        panel.setFrameOrigin(origin)
    }
}

// MARK: - NSWindowDelegate

extension ECLReferencePanelController: NSWindowDelegate {
    /// Clears the panel reference when the user closes the window.
    func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}
