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

/// ECL Workbench — a Monaco-based ECL editor with live evaluation results.
///
/// The top section is a full ECL editor with syntax highlighting, autocomplete,
/// and diagnostics powered by the ecl-editor web component. The bottom section
/// shows evaluation results that update as the user edits or presses Cmd+Enter.
struct EvaluatePanelView: View {
    @ObservedObject var viewModel: EvaluateViewModel
    var onClose: (() -> Void)?
    var onShowDiagram: ((ECLEvaluationConcept) -> Void)?

    /// Whether to show FSN instead of PT + semantic tag.
    @State private var showFSN: Bool = false

    /// Height of the editor portion (user-adjustable via drag).
    @State private var editorHeight: CGFloat = 300

    /// Editor height at the start of a drag gesture.
    @State private var dragStartHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            editorSection
                .frame(height: editorHeight)
            dragHandle
            resultsSection
                .frame(maxHeight: .infinity)
            Divider()
            footerSection
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Editor

    private var editorSection: some View {
        ECLEditorView(
            initialValue: viewModel.expression,
            fhirServerURL: FHIROptions.shared.baseURLString,
            darkTheme: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
            onValueChanged: { newValue in
                viewModel.expression = newValue
                viewModel.evaluateDebounced()
            },
            onEvaluate: { value in
                viewModel.expression = value
                viewModel.evaluate()
            }
        )
        .frame(height: editorHeight)
        .accessibilityIdentifier("evaluate.editor")
    }

    /// Draggable divider between editor and results.
    private var dragHandle: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
            HStack {
                Spacer()
                // Grip indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.tertiaryLabelColor))
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .frame(height: 10)
            .background(Color(NSColor.controlBackgroundColor))
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
        }
        .frame(height: 12)
        .contentShape(Rectangle())
        .cursor(.resizeUpDown)
        .onAppear { dragStartHeight = editorHeight }
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    let newHeight = dragStartHeight + value.translation.height
                    editorHeight = max(80, min(newHeight, 500))
                }
                .onEnded { _ in
                    dragStartHeight = editorHeight
                }
        )
        .accessibilityLabel("Resize editor")
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.isEvaluating {
            VStack {
                Spacer()
                ProgressView("Evaluating...")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("evaluate.error")
        } else if let result = viewModel.result {
            VStack(spacing: 0) {
                totalHeader(result: result)
                Divider()
                conceptList(concepts: result.concepts)
            }
        } else if viewModel.expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack {
                Spacer()
                Text("Type an ECL expression above")
                    .foregroundColor(.secondary)
                Text("Press ⌘Enter to evaluate")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack {
                Spacer()
                Text("Press ⌘Enter to evaluate")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func totalHeader(result: ECLEvaluationResult) -> some View {
        HStack {
            let countText = result.total > result.concepts.count
                ? "\(result.concepts.count) of \(result.total) concepts"
                : "\(result.total) concept\(result.total == 1 ? "" : "s")"
            Text(countText)
                .font(.callout)
                .fontWeight(.medium)
                .accessibilityIdentifier("evaluate.count")
            Spacer()
            Toggle("FSN", isOn: $showFSN)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityIdentifier("evaluate.fsnToggle")
                .accessibilityLabel("Show fully specified names")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func conceptList(concepts: [ECLEvaluationConcept]) -> some View {
        List(concepts, id: \.code) { concept in
            conceptRow(concept)
                .contextMenu {
                    Button("Show Diagram") {
                        onShowDiagram?(concept)
                    }
                    Button("Open in Shrimp") {
                        openInShrimp(code: concept.code)
                    }
                    Divider()
                    Button("Copy Code") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(concept.code, forType: .string)
                    }
                    Button("Copy Display") {
                        NSPasteboard.general.clearContents()
                        let text = showFSN ? (concept.fsn ?? concept.display) : concept.display
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
                .accessibilityIdentifier("evaluate.concept.\(concept.code)")
        }
        .listStyle(.plain)
    }

    private func conceptRow(_ concept: ECLEvaluationConcept) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                openInShrimp(code: concept.code)
            } label: {
                Text(concept.code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.blue)
                    .underline()
            }
            .buttonStyle(.plain)
            .frame(width: 130, alignment: .trailing)
            .accessibilityLabel("Open \(concept.code) in Shrimp")

            displayText(for: concept)
                .font(.system(size: 12))
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer()

            Button {
                onShowDiagram?(concept)
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show diagram for \(concept.code)")
        }
        .padding(.vertical, 1)
    }

    private func displayText(for concept: ECLEvaluationConcept) -> Text {
        if showFSN {
            return Text(concept.fsn ?? concept.display)
        }
        let term = concept.display
        if let tag = concept.semanticTag {
            return Text(term) + Text(" (\(tag))")
                .foregroundColor(.secondary)
        }
        return Text(term)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text("⌘Enter to evaluate")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
            Spacer()
            Button("Close") {
                onClose?()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("evaluate.close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func openInShrimp(code: String) {
        let fhirEndpoint = FHIROptions.shared.baseURLString
        guard let url = ShrimpURLBuilder.buildURL(
            conceptId: code,
            system: "http://snomed.info/sct",
            fhirEndpoint: fhirEndpoint
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Cursor Extension

extension View {
    /// Sets the cursor to a resize cursor when hovering.
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
