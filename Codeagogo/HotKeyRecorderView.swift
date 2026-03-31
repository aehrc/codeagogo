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
import AppKit
import Carbon.HIToolbox

/// A view that records keyboard shortcuts by capturing key presses.
///
/// `HotKeyRecorderView` provides an intuitive way for users to configure keyboard
/// shortcuts. When the user clicks "Record", the view enters recording mode and
/// captures the next keystroke with modifiers.
///
/// ## Usage
///
/// ```swift
/// @State private var keyCode: UInt32 = UInt32(kVK_ANSI_L)
/// @State private var modifiers: UInt32 = UInt32(controlKey | optionKey)
///
/// HotKeyRecorderView(
///     keyCode: $keyCode,
///     modifiersRaw: $modifiers
/// )
/// ```
///
/// ## Validation
///
/// The recorder requires at least one modifier key (Control, Option, Command, or Shift)
/// to be held when recording. Plain letter keys without modifiers are ignored to prevent
/// accidental hotkey registration that would interfere with normal typing.
struct HotKeyRecorderView: View {
    /// The current key code (Carbon virtual key code).
    @Binding var keyCode: UInt32

    /// The current modifiers (Carbon modifier mask).
    @Binding var modifiersRaw: UInt32

    /// Whether the view is currently recording a keystroke.
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            // Display current hotkey or recording prompt
            Text(isRecording ? "Press a key..." : formattedHotkey)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 100, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isRecording ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )

            // Record/Cancel button
            Button(isRecording ? "Cancel" : "Record") {
                isRecording.toggle()
            }
            .buttonStyle(.bordered)
        }
        .background(
            // Hidden key capture view
            KeyCaptureView(
                isRecording: $isRecording,
                keyCode: $keyCode,
                modifiersRaw: $modifiersRaw
            )
        )
    }

    /// Formats the current hotkey with modifier symbols.
    private var formattedHotkey: String {
        KeyCodeFormatter.format(keyCode: keyCode, modifiers: modifiersRaw)
    }
}

/// NSViewRepresentable that captures keyboard events when recording.
private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCode: UInt32
    @Binding var modifiersRaw: UInt32

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = { [self] event in
            guard isRecording else { return false }

            // Require at least one modifier
            let mods = event.modifierFlags.intersection([.control, .option, .command, .shift])
            guard !mods.isEmpty else { return false }

            // Update bindings
            keyCode = UInt32(event.keyCode)
            modifiersRaw = HotKeySettings.carbonModifiers(from: mods)
            isRecording = false
            return true
        }
        view.onCancel = { [self] in
            guard isRecording else { return false }
            isRecording = false
            return true
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            // Request focus when entering recording mode
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

/// Custom NSView that captures key events for hotkey recording.
///
/// This view becomes first responder when recording is active and intercepts
/// key events to capture the desired hotkey combination.
private class KeyCaptureNSView: NSView {
    /// Whether the view is currently recording a keystroke.
    var isRecording = false

    /// Callback for when a valid key is pressed.
    var onKeyDown: ((NSEvent) -> Bool)?

    /// Callback for when Escape is pressed to cancel.
    var onCancel: (() -> Bool)?

    override var acceptsFirstResponder: Bool { isRecording }

    override func keyDown(with event: NSEvent) {
        // Handle Escape to cancel recording
        if event.keyCode == UInt16(kVK_Escape) {
            if let handler = onCancel, handler() {
                return
            }
        }

        // Handle normal key capture
        if let handler = onKeyDown, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Preview

#if DEBUG
struct HotKeyRecorderView_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var keyCode: UInt32 = UInt32(kVK_ANSI_L)
        @State private var modifiers: UInt32 = UInt32(controlKey | optionKey)

        var body: some View {
            VStack(spacing: 20) {
                HotKeyRecorderView(keyCode: $keyCode, modifiersRaw: $modifiers)

                Text("Key Code: \(keyCode), Modifiers: \(modifiers)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    static var previews: some View {
        PreviewContainer()
    }
}
#endif
