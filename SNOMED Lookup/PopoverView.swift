import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var model: LookupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SNOMED Lookup")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let err = model.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Group {
                row("Concept ID", model.result?.conceptId ?? "—")
                row("FSN", model.result?.fsn ?? "—")
                row("PT", model.result?.pt ?? "—")
                row("Status", model.result?.activeText ?? "—")
                row("Branch", model.result?.branch ?? "—")
            }

            HStack {
                Button("Copy FSN") { model.copyToPasteboard(model.result?.fsn) }
                    .disabled(model.result?.fsn == nil)
                Button("Copy PT") { model.copyToPasteboard(model.result?.pt) }
                    .disabled(model.result?.pt == nil)
                Button("Copy ID") { model.copyToPasteboard(model.result?.conceptId) }
                    .disabled(model.result?.conceptId == nil)
                Button("Copy ID & FSN") { model.copyToPasteboard(model.result!.conceptId + " | " + model.result!.fsn! + " | ") }
                    .disabled(model.result?.conceptId == nil || model.result?.fsn == nil)
                Button("Copy ID & PT") { model.copyToPasteboard(model.result!.conceptId + " | " + model.result!.pt! + " | ") }
                    .disabled(model.result?.conceptId == nil || model.result?.pt == nil)
                Spacer()
            }
            .padding(.top, 6)

            Text("Select a SNOMED CT concept ID (6-18 digits) in any app, then press Control-Option-L.")
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
    }
}
