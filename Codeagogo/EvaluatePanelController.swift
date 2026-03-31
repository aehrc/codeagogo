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

/// Manages the floating ECL evaluation panel window.
///
/// Creates and manages an NSPanel that hosts the `EvaluatePanelView`.
/// Handles positioning near the cursor and focus management.
///
/// ## Usage
///
/// ```swift
/// let controller = EvaluatePanelController()
/// controller.show(expression: "<< 404684003", at: NSEvent.mouseLocation)
/// ```
@MainActor
final class EvaluatePanelController: NSObject {
    /// The floating panel window.
    private var panel: NSPanel?

    /// The view model for the evaluation panel.
    private let viewModel = EvaluateViewModel()

    /// Callback invoked when the user requests a concept diagram.
    /// The second parameter is the panel window, for positioning the diagram next to it.
    var onShowDiagram: ((ECLEvaluationConcept, NSPanel?) -> Void)?

    /// The app that was active before showing the panel, for restoring focus.
    private var previousApp: NSRunningApplication?

    /// Whether the panel is currently visible.
    var isShown: Bool {
        panel?.isVisible ?? false
    }

    /// Shows the evaluation panel with results for the given ECL expression.
    ///
    /// - Parameters:
    ///   - expression: The ECL expression to evaluate
    ///   - point: The screen point to position near (typically mouse location)
    func show(expression: String, at point: NSPoint) {
        previousApp = NSWorkspace.shared.frontmostApplication

        if let existingPanel = panel, existingPanel.isVisible {
            // Reuse existing panel with new expression
            viewModel.clearState()
            viewModel.expression = expression
            viewModel.evaluate()
            existingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        viewModel.clearState()
        viewModel.expression = expression

        let evalView = EvaluatePanelView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.close() },
            onShowDiagram: { [weak self] concept in self?.onShowDiagram?(concept, self?.panel) }
        )

        let defaultSize = NSRect(x: 0, y: 0, width: 600, height: 600)

        let newPanel = NSPanel(
            contentRect: defaultSize,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        let hostingView = NSHostingView(rootView: evalView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        newPanel.contentView = hostingView

        newPanel.title = "ECL Workbench"
        newPanel.isReleasedWhenClosed = false
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = false
        newPanel.minSize = NSSize(width: 350, height: 250)
        newPanel.delegate = self

        // Restore saved size/position, or position near cursor on first use
        newPanel.setFrameAutosaveName("EvaluatePanel")
        if !newPanel.setFrameUsingName("EvaluatePanel") {
            positionPanel(newPanel, near: point)
        }

        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        panel = newPanel
    }

    /// Updates the semantic validation warnings displayed in the panel.
    ///
    /// Called by `AppDelegate` after background concept validation completes.
    /// Passes the warnings through to the underlying `EvaluateViewModel`.
    ///
    /// - Parameter warnings: The warning strings to display
    func setWarnings(_ warnings: [String]) {
        viewModel.setWarnings(warnings)
    }

    /// Closes the evaluation panel.
    func close() {
        guard let panel else { return }

        panel.close()
        self.panel = nil

        if let previousApp {
            previousApp.activate()
            self.previousApp = nil
        }
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

extension EvaluatePanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        viewModel.clearState()
        panel = nil
    }
}
