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

import Foundation
import Combine
import AppKit

// MARK: - Protocols for Dependency Injection

/// Protocol for reading the current system text selection.
///
/// This protocol enables dependency injection for testing. The default
/// implementation uses `SystemSelectionReader` which captures selections
/// via simulated Cmd+C keystrokes.
///
/// - Note: Implementations require Accessibility permission to function.
protocol SelectionReading {
    /// Reads the currently selected text from the frontmost application.
    ///
    /// This method captures the selection by simulating a Cmd+C keystroke,
    /// reading the pasteboard, and restoring the original pasteboard contents.
    ///
    /// - Returns: The selected text as a string (may be empty if nothing selected)
    /// - Throws: `LookupError.accessibilityPermissionLikelyMissing` if the
    ///           simulated keystroke fails
    func readSelectionByCopying() throws -> String
}

/// Protocol for looking up concepts across code systems.
///
/// This protocol enables dependency injection for testing. The default
/// implementation uses `OntoserverClient` which queries FHIR terminology servers.
protocol ConceptLookupClient {
    /// Looks up a SNOMED CT concept by its identifier.
    ///
    /// - Parameter conceptId: The SNOMED CT concept identifier (6-18 digits)
    /// - Returns: The concept result containing FSN, PT, status, and edition
    /// - Throws: `OntoserverError.conceptNotFound` if the concept doesn't exist
    func lookup(conceptId: String) async throws -> ConceptResult

    /// Looks up a code in configured non-SNOMED code systems.
    ///
    /// Searches through the provided code systems in parallel and returns
    /// the first match found.
    ///
    /// - Parameters:
    ///   - code: The code to look up
    ///   - systems: Array of code system URIs to search
    /// - Returns: The concept result, or nil if not found in any system
    /// - Throws: Network errors
    func lookupInConfiguredSystems(code: String, systems: [String]) async throws -> ConceptResult?
}

/// Protocol for looking up concept properties for visualization.
///
/// This protocol enables dependency injection for testing the visualization
/// view model without requiring network access.
protocol ConceptPropertyLookup {
    /// Looks up all properties for a concept.
    func lookupWithProperties(conceptId: String, system: String, version: String) async throws -> [ConceptProperty]

    /// Looks up a concept by its identifier.
    func lookup(conceptId: String) async throws -> ConceptResult

    /// Looks up a concept's preferred term using the server's default edition.
    func lookupPreferredTerm(conceptId: String, system: String) async throws -> String?
}

// MARK: - Default Implementations

extension SystemSelectionReader: SelectionReading {}
extension OntoserverClient: ConceptLookupClient {}
extension OntoserverClient: ConceptPropertyLookup {}

// MARK: - View Model

/// View model for SNOMED CT concept lookup operations.
///
/// `LookupViewModel` coordinates between the UI and backend services to:
/// 1. Read the current text selection from any application
/// 2. Extract SNOMED CT concept IDs from the selected text
/// 3. Look up concept details from the FHIR terminology server
/// 4. Publish results for display in the popover
///
/// ## Usage
///
/// ```swift
/// let viewModel = LookupViewModel()
///
/// // Trigger a lookup from the current selection
/// await viewModel.lookupFromSystemSelection()
///
/// // Check results
/// if let result = viewModel.result {
///     print("Found: \(result.fsn ?? "Unknown")")
/// }
/// ```
///
/// ## Testing
///
/// For unit testing, inject mock dependencies:
///
/// ```swift
/// let mockReader = MockSelectionReader()
/// let mockClient = MockLookupClient()
/// let viewModel = LookupViewModel(selectionReader: mockReader, client: mockClient)
/// ```
///
/// - Note: This class is `@MainActor` isolated to ensure all UI updates
///         happen on the main thread.
@MainActor
final class LookupViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Indicates whether a lookup operation is in progress.
    @Published var isLoading = false

    /// The error message to display, or `nil` if no error occurred.
    @Published var errorMessage: String?

    /// The most recent lookup result, or `nil` if no lookup has been performed.
    @Published var result: ConceptResult?

    // MARK: - Dependencies

    private let selectionReader: SelectionReading
    private let client: ConceptLookupClient

    // MARK: - Callbacks

    /// Callback for opening visualization panel
    var onVisualize: ((ConceptResult) -> Void)?

    // MARK: - Initialization

    /// Creates a new lookup view model with optional custom dependencies.
    ///
    /// - Parameters:
    ///   - selectionReader: The selection reader to use. Defaults to `SystemSelectionReader`.
    ///   - client: The lookup client to use. Defaults to `OntoserverClient`.
    init(selectionReader: SelectionReading? = nil,
         client: ConceptLookupClient? = nil) {
        self.selectionReader = selectionReader ?? SystemSelectionReader()
        self.client = client ?? OntoserverClient()
    }

    // MARK: - Public Methods

    /// Performs a concept lookup using the current system text selection.
    ///
    /// This method:
    /// 1. Reads the current selection from the frontmost application
    /// 2. Extracts a code and validates if it's a SNOMED CT ID (Verhoeff check)
    /// 3. For valid SCTIDs: queries SNOMED CT directly
    /// 4. For other codes: searches configured code systems (LOINC, ICD-10, etc.)
    /// 5. Updates `result` with the concept details or `errorMessage` on failure
    ///
    /// The `isLoading` property is set to `true` during the operation and
    /// automatically set back to `false` when complete.
    ///
    /// - Note: This method clears any previous error before starting.
    func lookupFromSystemSelection() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let text = try selectionReader.readSelectionByCopying()

            guard let extracted = extractCode(from: text) else {
                throw LookupError.notAConceptId
            }

            let concept: ConceptResult

            if extracted.isSCTID {
                // Valid SNOMED CT ID - use direct lookup
                concept = try await client.lookup(conceptId: extracted.code)
            } else {
                // Not a valid SCTID - search configured code systems
                let systems = await CodeSystemSettings.shared.enabledSystems.map { $0.uri }

                if systems.isEmpty {
                    // No code systems configured, try SNOMED anyway (might be an invalid check digit)
                    concept = try await client.lookup(conceptId: extracted.code)
                } else {
                    // Try configured code systems first, fall back to SNOMED
                    if let result = try await client.lookupInConfiguredSystems(code: extracted.code, systems: systems) {
                        concept = result
                    } else {
                        // Not found in configured systems, try SNOMED as fallback
                        concept = try await client.lookup(conceptId: extracted.code)
                    }
                }
            }

            self.result = concept
        } catch {
            self.result = nil
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    // MARK: - Concept ID Extraction

    /// An extracted code with metadata about its type.
    struct ExtractedCode {
        /// The extracted code string.
        let code: String

        /// Whether the code is a valid SNOMED CT ID (passes Verhoeff check).
        let isSCTID: Bool
    }

    /// Extracts the first plausible SNOMED CT concept ID from text.
    ///
    /// SNOMED CT concept IDs are numeric identifiers between 6 and 18 digits.
    /// This method finds the first such number in the input text, using word
    /// boundaries to avoid matching partial numbers.
    ///
    /// - Parameter text: The text to search for a concept ID
    /// - Returns: The first valid concept ID found, or `nil` if none found
    ///
    /// ## Examples
    ///
    /// ```swift
    /// extractConceptId(from: "73211009")           // Returns "73211009"
    /// extractConceptId(from: "Code: 73211009")     // Returns "73211009"
    /// extractConceptId(from: "No numbers here")   // Returns nil
    /// extractConceptId(from: "12345")             // Returns nil (too short)
    /// ```
    /// Maximum input size (in characters) accepted by extraction methods.
    ///
    /// Inputs larger than this are rejected to prevent excessive regex processing.
    static let maxExtractionInputSize = 10_000

    func extractConceptId(from text: String) -> String? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count <= Self.maxExtractionInputSize else { return nil }

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

    /// Extracts a code from text and validates whether it's a SNOMED CT ID.
    ///
    /// This method attempts to extract codes in order of preference:
    /// 1. Valid SNOMED CT ID (6-18 digits passing Verhoeff check)
    /// 2. Numeric code (6-18 digits but fails Verhoeff - may be from other system)
    /// 3. Alphanumeric code (e.g., LOINC "8867-4", ICD-10 "J45.901")
    ///
    /// - Parameter text: The text to search for a code
    /// - Returns: The extracted code with type information, or nil if none found
    ///
    /// ## Examples
    ///
    /// ```swift
    /// extractCode(from: "73211009")        // isSCTID = true (valid Verhoeff)
    /// extractCode(from: "73211000")        // isSCTID = false (invalid check digit)
    /// extractCode(from: "8867-4")          // isSCTID = false (LOINC format)
    /// extractCode(from: "J45.901")         // isSCTID = false (ICD-10 format)
    /// ```
    func extractCode(from text: String) -> ExtractedCode? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s.count <= Self.maxExtractionInputSize else { return nil }

        // First try SNOMED pattern (6-18 digits)
        let snomedPattern = #"\b(\d{6,18})\b"#
        if let re = try? NSRegularExpression(pattern: snomedPattern),
           let match = re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)),
           match.numberOfRanges >= 2,
           let r = Range(match.range(at: 1), in: s) {
            let code = String(s[r])
            let isSCTID = SCTIDValidator.isValidSCTID(code)
            return ExtractedCode(code: code, isSCTID: isSCTID)
        }

        // For non-numeric codes (e.g., LOINC "8867-4", ICD "J45.901")
        // Pattern: starts with letter or digit, followed by alphanumeric, dots, or hyphens
        let generalPattern = #"\b([A-Za-z0-9][A-Za-z0-9.\-]{1,})\b"#
        if let re = try? NSRegularExpression(pattern: generalPattern),
           let match = re.firstMatch(in: s, range: NSRange(s.startIndex..<s.endIndex, in: s)),
           match.numberOfRanges >= 2,
           let r = Range(match.range(at: 1), in: s) {
            let code = String(s[r])
            return ExtractedCode(code: code, isSCTID: false)
        }

        return nil
    }

    /// A concept ID match with its location in the original text.
    struct ConceptMatch {
        /// The concept ID/code string.
        let conceptId: String
        /// The range of the entire match in the original text (code + optional pipe-delimited term).
        let range: Range<String.Index>
        /// The existing pipe-delimited term, if present (without the pipes).
        let existingTerm: String?
        /// Whether the code is a valid SNOMED CT ID (passes Verhoeff check).
        let isSCTID: Bool
    }

    /// Extracts all plausible concept IDs from text with their positions.
    ///
    /// This method finds numeric codes (6-18 digits) in the input text, using word
    /// boundaries to avoid matching partial numbers. It also detects if a code
    /// is followed by a pipe-delimited term (e.g., `385804009 | Diabetic care |`).
    ///
    /// Each match includes an `isSCTID` flag indicating whether the code passes
    /// Verhoeff validation (valid SNOMED CT identifier).
    ///
    /// - Parameter text: The text to search for concept IDs
    /// - Returns: An array of matches containing concept IDs, their ranges,
    ///            existing terms, and SCTID validation status, ordered by position
    ///
    /// ## Examples
    ///
    /// ```swift
    /// extractAllConceptIds(from: "73211009 and 385804009")
    /// // Returns matches with existingTerm = nil, isSCTID = true (both valid)
    ///
    /// extractAllConceptIds(from: "73211009 | Diabetes | and 385804009")
    /// // First match has existingTerm = "Diabetes", second has existingTerm = nil
    /// ```
    func extractAllConceptIds(from text: String) -> [ConceptMatch] {
        guard text.count <= Self.maxExtractionInputSize else { return [] }

        // Two-pass extraction: SNOMED numeric codes first, then alphanumeric codes (LOINC, ICD-10, etc.)
        // This ensures SNOMED codes are matched by the specific numeric pattern while
        // non-numeric codes like "8867-4" or "J45.901" are also captured.

        // Pass 1: SNOMED numeric codes (6-18 digits) with optional pipe-delimited term
        let snomedPattern = #"\b(\d{6,18})(\s*\|\s*([^|]+?)\s*\|)?"#

        // Pass 2: Alphanumeric codes (e.g., LOINC "8867-4", ICD-10 "E11.9") with optional pipe-delimited term.
        // Lookaheads require the match contains at least one digit AND at least one letter or hyphen,
        // preventing matches on pure words, pure numbers (pass 1), and digit-dot patterns like "0..0".
        let alphanumericPattern = #"\b((?=[A-Za-z0-9.\-]*\d)(?=[A-Za-z0-9.\-]*[A-Za-z\-])[A-Za-z0-9][A-Za-z0-9.\-]{1,17})(\s*\|\s*([^|]+?)\s*\|)?"#

        var allMatches: [ConceptMatch] = []
        var matchedRanges: [Range<String.Index>] = []

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        // Pass 1: SNOMED numeric codes
        if let re = try? NSRegularExpression(pattern: snomedPattern) {
            let matches = re.matches(in: text, range: nsRange)
            for match in matches {
                if let conceptMatch = buildConceptMatch(from: match, in: text) {
                    allMatches.append(conceptMatch)
                    matchedRanges.append(conceptMatch.range)
                }
            }
        }

        // Pass 2: Alphanumeric codes (skip ranges already matched by pass 1)
        if let re = try? NSRegularExpression(pattern: alphanumericPattern) {
            let matches = re.matches(in: text, range: nsRange)
            for match in matches {
                guard let conceptMatch = buildConceptMatch(from: match, in: text) else { continue }
                // Skip if this range overlaps with a SNOMED match from pass 1
                let overlaps = matchedRanges.contains { existing in
                    existing.overlaps(conceptMatch.range)
                }
                if !overlaps {
                    allMatches.append(conceptMatch)
                }
            }
        }

        // Sort by position in the original text
        allMatches.sort { $0.range.lowerBound < $1.range.lowerBound }
        return allMatches
    }

    /// Builds a ConceptMatch from a regex match result.
    private func buildConceptMatch(from match: NSTextCheckingResult, in text: String) -> ConceptMatch? {
        guard match.numberOfRanges >= 2,
              let conceptIdRange = Range(match.range(at: 1), in: text)
        else { return nil }

        let conceptId = String(text[conceptIdRange])

        // Determine the full range (code + optional term)
        // swiftlint:disable:next force_unwrapping
        let fullRange = Range(match.range(at: 0), in: text)!

        // Extract existing term if present (group 3)
        var existingTerm: String?
        if match.numberOfRanges >= 4,
           match.range(at: 3).location != NSNotFound,
           let termRange = Range(match.range(at: 3), in: text) {
            existingTerm = String(text[termRange]).trimmingCharacters(in: .whitespaces)
        }

        let isSCTID = SCTIDValidator.isValidSCTID(conceptId)

        return ConceptMatch(conceptId: conceptId, range: fullRange, existingTerm: existingTerm, isSCTID: isSCTID)
    }

    /// Copies a string to the system pasteboard.
    ///
    /// - Parameter s: The string to copy. If `nil` or empty, no action is taken.
    func copyToPasteboard(_ s: String?) {
        guard let s, !s.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    /// Opens the current lookup result in the Shrimp terminology browser.
    ///
    /// This method constructs a URL to view the concept in Shrimp and opens
    /// it in the user's default web browser. The URL includes the concept code,
    /// version information, and FHIR endpoint for full context.
    ///
    /// If no lookup result is available or the URL cannot be constructed,
    /// this method logs a warning and does nothing.
    func openInShrimp() {
        guard let result = result else {
            AppLog.warning(AppLog.general, "Cannot open in Shrimp: no lookup result")
            return
        }

        let fhirEndpoint = FHIROptions.shared.baseURLString

        guard let url = ShrimpURLBuilder.buildURL(from: result, fhirEndpoint: fhirEndpoint) else {
            AppLog.warning(AppLog.general, "Cannot open in Shrimp: failed to build URL")
            return
        }

        AppLog.info(AppLog.general, "Opening concept in Shrimp: \(url)")
        NSWorkspace.shared.open(url)
    }

    /// Opens visualization panel for current result.
    func openVisualization() {
        guard let result = result else {
            AppLog.warning(AppLog.general, "Cannot open visualization: no result")
            return
        }
        onVisualize?(result)
    }

    /// Looks up a concept from text and opens it in the Shrimp browser.
    ///
    /// This method extracts a code from the text, performs a lookup to get
    /// concept details, and opens the result in Shrimp. Unlike `lookup()`,
    /// this does not update the `result` property or show the popover.
    ///
    /// - Parameter text: The text containing a concept code
    /// - Throws: LookupError if extraction or lookup fails
    func lookupAndOpenInShrimp(from text: String) async throws {
        // Extract code
        guard let extracted = extractCode(from: text) else {
            throw LookupError.notAConceptId
        }

        // Perform lookup (handle both SNOMED CT and non-SNOMED codes)
        let conceptResult: ConceptResult

        if extracted.isSCTID {
            // Valid SNOMED CT ID - use direct lookup
            conceptResult = try await client.lookup(conceptId: extracted.code)
        } else {
            // Not a valid SCTID - search configured code systems
            let systems = await CodeSystemSettings.shared.enabledSystems.map { $0.uri }

            if systems.isEmpty {
                // No code systems configured, try SNOMED anyway (might be an invalid check digit)
                conceptResult = try await client.lookup(conceptId: extracted.code)
            } else {
                // Try configured code systems first, fall back to SNOMED
                if let result = try await client.lookupInConfiguredSystems(code: extracted.code, systems: systems) {
                    conceptResult = result
                } else {
                    // Not found in configured systems, try SNOMED as fallback
                    conceptResult = try await client.lookup(conceptId: extracted.code)
                }
            }
        }

        // Open in Shrimp
        let fhirEndpoint = FHIROptions.shared.baseURLString

        guard let url = ShrimpURLBuilder.buildURL(from: conceptResult, fhirEndpoint: fhirEndpoint) else {
            AppLog.warning(AppLog.general, "Cannot open in Shrimp: failed to build URL")
            return
        }

        AppLog.info(AppLog.general, "Opening concept in Shrimp: \(url)")
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Errors

/// Errors that can occur during the lookup process.
///
/// These errors represent user-facing issues that should be displayed
/// in the popover with helpful guidance.
enum LookupError: LocalizedError {
    /// The selected text did not contain a recognizable code.
    ///
    /// A valid code is either a SNOMED CT ID (6-18 digits) or an
    /// alphanumeric code (e.g., LOINC "8867-4", ICD-10 "J45.901").
    case notAConceptId

    /// The app lacks Accessibility permission to read selections.
    ///
    /// Users need to grant permission in System Settings → Privacy & Security → Accessibility.
    case accessibilityPermissionLikelyMissing

    /// The code was not found in any configured code system.
    case codeNotFound(String)

    var errorDescription: String? {
        switch self {
        case .notAConceptId:
            return "Selection did not contain a recognizable code (SNOMED CT, LOINC, ICD-10, etc.)."
        case .accessibilityPermissionLikelyMissing:
            return "Unable to read selection. Grant Accessibility permission in System Settings → Privacy & Security → Accessibility."
        case .codeNotFound(let code):
            return "Code '\(code)' not found in any configured code system."
        }
    }
}
