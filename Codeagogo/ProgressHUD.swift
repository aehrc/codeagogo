import Cocoa
import SwiftUI
import Combine

/// A lightweight floating HUD that shows progress during long-running operations.
///
/// The HUD appears near the cursor and displays a message with an optional
/// progress indicator. It automatically positions itself to stay on screen.
@MainActor
final class ProgressHUD {
    private var window: NSPanel?
    private var hostingView: NSHostingView<ProgressHUDView>?
    private var viewModel = ProgressHUDViewModel()

    /// Shows the HUD near the current cursor position.
    ///
    /// - Parameter message: The message to display
    func show(message: String) {
        viewModel.message = message
        viewModel.progress = nil

        if window == nil {
            createWindow()
        }

        positionNearCursor()
        window?.orderFront(nil)
    }

    /// Updates the HUD message and optional progress.
    ///
    /// - Parameters:
    ///   - message: The new message to display
    ///   - progress: Optional progress value (0.0 to 1.0)
    func update(message: String, progress: Double? = nil) {
        viewModel.message = message
        viewModel.progress = progress
    }

    /// Hides and releases the HUD.
    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }

    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: ProgressHUDView(viewModel: viewModel))
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        self.window = panel
        self.hostingView = hostingView
    }

    private func positionNearCursor() {
        guard let window = window,
              let screen = NSScreen.main else { return }

        let mouseLocation = NSEvent.mouseLocation
        let windowSize = window.frame.size

        // Position below and to the right of cursor, with some offset
        var x = mouseLocation.x + 10
        var y = mouseLocation.y - windowSize.height - 10

        // Keep on screen
        let screenFrame = screen.visibleFrame
        if x + windowSize.width > screenFrame.maxX {
            x = screenFrame.maxX - windowSize.width - 10
        }
        if y < screenFrame.minY {
            y = mouseLocation.y + 20  // Show above cursor instead
        }

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// View model for the progress HUD.
@MainActor
final class ProgressHUDViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var progress: Double?
}

/// SwiftUI view for the progress HUD content.
struct ProgressHUDView: View {
    @ObservedObject var viewModel: ProgressHUDViewModel

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let progress = viewModel.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}
