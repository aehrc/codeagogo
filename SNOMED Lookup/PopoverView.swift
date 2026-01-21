import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var model: LookupViewModel
    @ObservedObject private var hotKeySettings = HotKeySettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SNOMED Lookup")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("Loading concept data")
                }
            }

            if let err = model.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .accessibilityLabel("Error: \(err)")
            }

            Group {
                row("Concept ID", model.result?.conceptId ?? "—")
                row("FSN", model.result?.fsn ?? "—")
                row("PT", model.result?.pt ?? "—")
                row("Status", model.result?.activeText ?? "—")
                row("Edition", model.result?.branch ?? "—")
            }

            HStack {
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
                Spacer()
            }
            .padding(.top, 6)

            Text("Select a SNOMED CT concept ID (6-18 digits) in any app, then press \(hotKeySettings.hotkeyDescription).")
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
}
