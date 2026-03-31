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

/// Manages the visualization panel window lifecycle.
///
/// `VisualizationPanelController` creates and manages an NSPanel that hosts the
/// `VisualizationPanelView`. It follows the same pattern as `SearchPanelController`,
/// handling positioning, focus management, and window lifecycle.
///
/// ## Usage
///
/// ```swift
/// let controller = VisualizationPanelController()
///
/// // Show visualization for a concept result
/// controller.show(for: result, near: NSEvent.mouseLocation)
///
/// // Close the panel
/// controller.close()
/// ```
@MainActor
final class VisualizationPanelController: NSObject {
    /// The floating panel window.
    private var panel: NSPanel?

    /// The view model for the visualization panel.
    private let viewModel = VisualizationViewModel()

    /// Shows the visualization panel for a concept result.
    ///
    /// The panel is positioned near the specified point, with automatic adjustment
    /// to stay within screen bounds. Triggers async loading of property data.
    ///
    /// - Parameters:
    ///   - result: The concept result to visualize
    ///   - point: The screen point to position near (typically popover location)
    func show(for result: ConceptResult, near point: NSPoint) {
        if panel == nil { createPanel() }

        Task { await viewModel.loadProperties(for: result) }

        if let panel = panel {
            positionPanel(panel, near: point)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Shows the visualization panel beside a source window.
    ///
    /// Positions the diagram to the right of the source window if there's room,
    /// otherwise to the left, without overlapping.
    ///
    /// - Parameters:
    ///   - result: The concept result to visualize
    ///   - anchorFrame: The frame of the window to position beside
    func show(for result: ConceptResult, beside anchorFrame: NSRect) {
        if panel == nil { createPanel() }

        Task { await viewModel.loadProperties(for: result) }

        if let panel = panel {
            positionPanelBeside(panel, anchor: anchorFrame)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Closes the visualization panel.
    func close() {
        panel?.close()
        panel = nil
    }

    // MARK: - Private Methods

    /// Creates the panel with SwiftUI content.
    private func createPanel() {
        let view = VisualizationPanelView(viewModel: viewModel) { [weak self] in
            self?.close()
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 700, height: 600)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Concept Visualization"
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 500, height: 400)
        panel.maxSize = NSSize(width: 2000, height: 1500)
        panel.delegate = self

        self.panel = panel
    }

    /// Positions the panel near the specified screen point.
    ///
    /// Attempts to position the panel to the right of the point (e.g., right of popover).
    /// If there's insufficient space, positions it to the left instead.
    /// Ensures the panel stays within screen bounds with a 20pt margin.
    private func positionPanel(_ panel: NSPanel, near point: NSPoint) {
        guard let screen = NSScreen.main else { return }

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 20

        // Position to right of popover (point is popover location)
        // Popover width is 520, add 20pt spacing
        var origin = NSPoint(
            x: point.x + 540,
            y: point.y - panelSize.height / 2
        )

        // If doesn't fit on right, try left
        if origin.x + panelSize.width > screenFrame.maxX - margin {
            origin.x = point.x - panelSize.width - 20
        }

        // Ensure within screen bounds
        origin.x = max(screenFrame.minX + margin,
                       min(origin.x, screenFrame.maxX - panelSize.width - margin))
        origin.y = max(screenFrame.minY + margin,
                       min(origin.y, screenFrame.maxY - panelSize.height - margin))

        panel.setFrameOrigin(origin)
    }

    /// Positions the panel beside an anchor window frame without overlapping.
    ///
    /// Tries the right side first, then falls back to the left side.
    /// Vertically centers relative to the anchor.
    private func positionPanelBeside(_ panel: NSPanel, anchor: NSRect) {
        guard let screen = NSScreen.main else { return }

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame
        let gap: CGFloat = 10
        let margin: CGFloat = 20

        // Try right of anchor
        var origin = NSPoint(
            x: anchor.maxX + gap,
            y: anchor.midY - panelSize.height / 2
        )

        // If right doesn't fit, try left of anchor
        if origin.x + panelSize.width > screenFrame.maxX - margin {
            origin.x = anchor.minX - panelSize.width - gap
        }

        // Clamp to screen
        origin.x = max(screenFrame.minX + margin,
                       min(origin.x, screenFrame.maxX - panelSize.width - margin))
        origin.y = max(screenFrame.minY + margin,
                       min(origin.y, screenFrame.maxY - panelSize.height - margin))

        panel.setFrameOrigin(origin)
    }
}

// MARK: - NSWindowDelegate

extension VisualizationPanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}
