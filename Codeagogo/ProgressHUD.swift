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
    private var autoDismissTask: Task<Void, Never>?

    /// Shows the HUD near the current cursor position.
    ///
    /// - Parameter message: The message to display
    func show(message: String) {
        autoDismissTask?.cancel()
        viewModel.message = message
        viewModel.progress = nil
        viewModel.isError = false

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

    /// Shows a transient error message near the cursor that auto-dismisses.
    ///
    /// - Parameters:
    ///   - message: The error message to display
    ///   - duration: How long to show the HUD (default 4 seconds)
    func showError(message: String, duration: TimeInterval = 4) {
        autoDismissTask?.cancel()

        viewModel.message = message
        viewModel.progress = nil
        viewModel.isError = true

        if window == nil {
            createWindow()
        }

        positionNearCursor()
        window?.orderFront(nil)

        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    /// Shows a transient warning message near the cursor that auto-dismisses.
    ///
    /// Unlike `showError`, this displays a yellow warning icon to indicate
    /// non-blocking informational warnings (e.g., inactive concepts detected).
    ///
    /// - Parameters:
    ///   - message: The warning message to display
    ///   - duration: How long to show the HUD (default 5 seconds)
    func showWarning(message: String, duration: TimeInterval = 5) {
        autoDismissTask?.cancel()

        viewModel.message = message
        viewModel.progress = nil
        viewModel.isError = false
        viewModel.isWarning = true

        if window == nil {
            createWindow()
        }

        positionNearCursor()
        window?.orderFront(nil)

        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    /// Hides and releases the HUD.
    func hide() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        viewModel.isError = false
        viewModel.isWarning = false
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
    @Published var isError: Bool = false
    @Published var isWarning: Bool = false
}

/// SwiftUI view for the progress HUD content.
struct ProgressHUDView: View {
    @ObservedObject var viewModel: ProgressHUDViewModel

    var body: some View {
        HStack(spacing: 10) {
            if viewModel.isError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                    .frame(width: 20, height: 20)
            } else if viewModel.isWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                    .frame(width: 20, height: 20)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(3)

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
