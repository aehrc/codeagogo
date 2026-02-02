import Cocoa
import SwiftUI

/// Manages the floating search panel window lifecycle.
///
/// `SearchPanelController` creates and manages an NSWindow that hosts the
/// `SearchPanelView`. It handles positioning the panel near the cursor,
/// keyboard handling (Escape to close), and focus management.
///
/// ## Usage
///
/// ```swift
/// let controller = SearchPanelController()
///
/// // Show at cursor position
/// controller.show(at: NSEvent.mouseLocation)
///
/// // Close the panel
/// controller.close()
/// ```
@MainActor
final class SearchPanelController: NSObject {
    /// The floating panel window.
    private var panel: NSPanel?

    /// The view model for the search panel.
    private let viewModel = SearchViewModel()

    /// The app that was active before showing the panel, for restoring focus.
    private var previousApp: NSRunningApplication?

    /// Local event monitor for double-click to insert.
    private var doubleClickMonitor: Any?

    /// Whether the panel is currently visible.
    var isShown: Bool {
        panel?.isVisible ?? false
    }

    override init() {
        super.init()

        // Set up callbacks
        viewModel.onInsertComplete = { [weak self] in
            self?.close()
        }
    }

    /// Shows the search panel near the specified screen point.
    ///
    /// The panel is positioned to appear near the cursor, adjusting to
    /// stay within screen bounds. If the panel is already visible, it
    /// is brought to the front.
    ///
    /// - Parameter point: The screen point (typically mouse location)
    func show(at point: NSPoint) {
        // Capture the currently active app before we take focus
        previousApp = NSWorkspace.shared.frontmostApplication
        viewModel.previousApp = previousApp

        if let existingPanel = panel, existingPanel.isVisible {
            // Already shown, just bring to front
            existingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create the SwiftUI view
        let searchView = SearchPanelView(viewModel: viewModel, onClose: { [weak self] in
            self?.close()
        })

        // Create the hosting view
        let hostingView = NSHostingView(rootView: searchView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 450, height: 400)

        // Create the panel
        let newPanel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.title = "SNOMED CT Search"
        newPanel.contentView = hostingView
        newPanel.isReleasedWhenClosed = false
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.delegate = self

        // Position the panel near the cursor
        positionPanel(newPanel, near: point)

        // Show the panel
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        panel = newPanel

        // Clear any previous state and focus the search field
        viewModel.clearState()

        // Monitor double-clicks to insert the selected result
        installDoubleClickMonitor()
    }

    /// Closes the search panel.
    func close() {
        removeDoubleClickMonitor()

        guard let panel else { return }

        panel.close()
        self.panel = nil

        // Restore focus to the previous app
        if let previousApp {
            previousApp.activate()
            self.previousApp = nil
        }
    }

    /// Installs a local event monitor that triggers insert on double-click.
    private func installDoubleClickMonitor() {
        removeDoubleClickMonitor()
        doubleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self,
                  event.clickCount == 2,
                  let panel = self.panel,
                  event.window === panel,
                  self.viewModel.selectedResult != nil else {
                return event
            }
            // Short delay so the List selection updates first
            DispatchQueue.main.async {
                self.viewModel.insertSelected()
            }
            return event
        }
    }

    /// Removes the double-click event monitor.
    private func removeDoubleClickMonitor() {
        if let monitor = doubleClickMonitor {
            NSEvent.removeMonitor(monitor)
            doubleClickMonitor = nil
        }
    }

    /// Positions the panel near the specified screen point.
    ///
    /// The panel is positioned so its top-left corner is near the point,
    /// with adjustments to keep it within screen bounds.
    private func positionPanel(_ panel: NSPanel, near point: NSPoint) {
        guard let screen = NSScreen.main else { return }

        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame

        // Start with the point as the top-left of the panel
        var origin = NSPoint(
            x: point.x - panelSize.width / 2,
            y: point.y - panelSize.height / 2
        )

        // Adjust to stay within screen bounds
        // Keep minimum 20pt margin from edges
        let margin: CGFloat = 20

        // Horizontal bounds
        if origin.x < screenFrame.minX + margin {
            origin.x = screenFrame.minX + margin
        } else if origin.x + panelSize.width > screenFrame.maxX - margin {
            origin.x = screenFrame.maxX - panelSize.width - margin
        }

        // Vertical bounds
        if origin.y < screenFrame.minY + margin {
            origin.y = screenFrame.minY + margin
        } else if origin.y + panelSize.height > screenFrame.maxY - margin {
            origin.y = screenFrame.maxY - panelSize.height - margin
        }

        panel.setFrameOrigin(origin)
    }
}

// MARK: - NSWindowDelegate

extension SearchPanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        removeDoubleClickMonitor()
        viewModel.clearState()
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        // Optionally close when losing focus (can be disabled if needed)
        // close()
    }
}
