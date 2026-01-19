import Foundation
import Combine
import AppKit

@MainActor
final class LookupViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var result: ConceptResult?

    private let selectionReader = SystemSelectionReader()
    private let client = OntoserverClient()

    func lookupFromSystemSelection() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let text = try selectionReader.readSelectionByCopying()

            guard let conceptId = extractConceptId(from: text) else {
                throw LookupError.notAConceptId
            }

            let concept = try await client.lookup(conceptId: conceptId)
            self.result = concept
        } catch {
            self.result = nil
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    /// Extract first plausible SNOMED CT conceptId (6–18 digits) from any text.
    private func extractConceptId(from text: String) -> String? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Match a digit run 6–18 digits (word boundaries reduce false matches)
        let pattern = #"\b(\d{6,18})\b"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let match = re.firstMatch(in: s, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: s)
        else { return nil }

        return String(s[r])
    }

    func copyToPasteboard(_ s: String?) {
        guard let s, !s.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

enum LookupError: LocalizedError {
    case notAConceptId
    case accessibilityPermissionLikelyMissing

    var errorDescription: String? {
        switch self {
        case .notAConceptId:
            return "Selection did not contain a SNOMED CT concept ID (expected a 6–18 digit number)."
        case .accessibilityPermissionLikelyMissing:
            return "Unable to read selection. Grant Accessibility permission in System Settings → Privacy & Security → Accessibility."
        }
    }
}
