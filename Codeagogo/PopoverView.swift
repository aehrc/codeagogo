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

struct PopoverView: View {
    @EnvironmentObject var model: LookupViewModel
    @ObservedObject private var hotKeySettings = HotKeySettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Codeagogo")
                    .font(.headline)
                Spacer()

                if model.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityIdentifier("popover.loading")
                        .accessibilityLabel("Loading concept data")
                }

                // Action buttons
                Button("Diagram") {
                    model.openVisualization()
                }
                .disabled(model.result == nil)
                .font(.caption)
                .accessibilityLabel("Show Diagram")

                Button(action: { model.openInShrimp() }) {
                    HStack(spacing: 4) {
                        Text("Browser")
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                    }
                }
                .disabled(model.result == nil)
                .font(.caption)
                .accessibilityLabel("Open in Browser")
            }

            if let err = model.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .accessibilityIdentifier("popover.error")
                    .accessibilityLabel("Error: \(err)")
            }

            Group {
                if let result = model.result {
                    if result.isSNOMEDCT {
                        // SNOMED CT result - show full details
                        row("Concept ID", result.conceptId)
                            .accessibilityIdentifier("popover.conceptId")
                        row("FSN", result.fsn ?? "—")
                            .accessibilityIdentifier("popover.fsn")
                        row("PT", result.pt ?? "—")
                            .accessibilityIdentifier("popover.pt")
                        statusRow(result)
                            .accessibilityIdentifier("popover.status")
                        row("Edition", result.branch)
                            .accessibilityIdentifier("popover.edition")
                    } else {
                        // Non-SNOMED result - show simplified view
                        row("Code", result.conceptId)
                            .accessibilityIdentifier("popover.conceptId")
                        row("Display", result.pt ?? "—")
                            .accessibilityIdentifier("popover.pt")
                        row("System", result.systemName)
                            .accessibilityIdentifier("popover.system")
                        if !result.branch.isEmpty {
                            row("Version", result.branch)
                                .accessibilityIdentifier("popover.version")
                        }
                    }
                } else {
                    row("Concept ID", "—")
                        .accessibilityIdentifier("popover.conceptId")
                    row("FSN", "—")
                        .accessibilityIdentifier("popover.fsn")
                    row("PT", "—")
                        .accessibilityIdentifier("popover.pt")
                    row("Status", "—")
                        .accessibilityIdentifier("popover.status")
                    row("Edition", "—")
                        .accessibilityIdentifier("popover.edition")
                }
            }

            HStack {
                if let result = model.result, result.isSNOMEDCT {
                    // SNOMED CT buttons
                    Button("Copy FSN") { model.copyToPasteboard(model.result?.fsn) }
                        .disabled(model.result?.fsn == nil)
                        .accessibilityLabel("Copy Fully Specified Name")
                        .accessibilityHint("Copies the FSN to clipboard")
                    Button("Copy PT") { model.copyToPasteboard(model.result?.pt) }
                        .disabled(model.result?.pt == nil)
                        .accessibilityLabel("Copy Preferred Term")
                        .accessibilityHint("Copies the preferred term to clipboard")
                    Button("Copy ID") { model.copyToPasteboard(model.result?.conceptId) }
                        .disabled(model.result?.conceptId == nil)
                        .accessibilityLabel("Copy Concept ID")
                        .accessibilityHint("Copies the SNOMED CT concept ID to clipboard")
                    Button("Copy ID & FSN") {
                        if let result = model.result, let fsn = result.fsn {
                            model.copyToPasteboard("\(result.conceptId) | \(fsn) | ")
                        }
                    }
                    .disabled(model.result?.conceptId == nil || model.result?.fsn == nil)
                    .accessibilityLabel("Copy ID and FSN")
                    .accessibilityHint("Copies concept ID and Fully Specified Name to clipboard")
                    Button("Copy ID & PT") {
                        if let result = model.result, let pt = result.pt {
                            model.copyToPasteboard("\(result.conceptId) | \(pt) | ")
                        }
                    }
                    .disabled(model.result?.conceptId == nil || model.result?.pt == nil)
                    .accessibilityLabel("Copy ID and PT")
                    .accessibilityHint("Copies concept ID and preferred term to clipboard")
                } else {
                    // Non-SNOMED buttons (simpler)
                    Button("Copy Code") { model.copyToPasteboard(model.result?.conceptId) }
                        .disabled(model.result?.conceptId == nil)
                        .accessibilityLabel("Copy Code")
                        .accessibilityHint("Copies the code to clipboard")
                    Button("Copy Display") { model.copyToPasteboard(model.result?.pt) }
                        .disabled(model.result?.pt == nil)
                        .accessibilityLabel("Copy Display Name")
                        .accessibilityHint("Copies the display name to clipboard")
                    Button("Copy Code & Display") {
                        if let result = model.result, let pt = result.pt {
                            model.copyToPasteboard("\(result.conceptId) | \(pt) |")
                        }
                    }
                    .disabled(model.result?.conceptId == nil || model.result?.pt == nil)
                    .accessibilityLabel("Copy Code and Display")
                    .accessibilityHint("Copies code and display name to clipboard")
                }
            }
            .padding(.top, 6)

            Text("Select a code (SNOMED CT, LOINC, etc.) in any app, then press \(hotKeySettings.hotkeyDescription).")
                .foregroundStyle(.secondary)
                .font(.footnote)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(width: 520, height: 220)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    /// Displays the concept status with special highlighting for inactive concepts.
    private func statusRow(_ result: ConceptResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Status")
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)

            if result.active == false {
                // Inactive concept - highlight with warning
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("INACTIVE")
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            } else {
                Text(result.activeText)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(result.activeText)")
    }
}
