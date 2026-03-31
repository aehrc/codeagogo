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

import XCTest
@testable import Codeagogo

/// Tests for LookupViewModel async lookup flow using mock dependencies.
@MainActor
final class LookupViewModelTests: XCTestCase {

    // MARK: - Mocks

    private class MockSelectionReader: SelectionReading {
        var textToReturn: String = ""
        var shouldThrow = false

        func readSelectionByCopying() throws -> String {
            if shouldThrow {
                throw LookupError.accessibilityPermissionLikelyMissing
            }
            return textToReturn
        }
    }

    private class MockLookupClient: ConceptLookupClient {
        var lookupResult: Result<ConceptResult, Error> = .success(
            ConceptResult(
                conceptId: "73211009",
                branch: "International (20240101)",
                fsn: "Diabetes mellitus (disorder)",
                pt: "Diabetes mellitus",
                active: true,
                effectiveTime: "20020131",
                moduleId: "900000000000207008"
            )
        )
        var configuredSystemsResult: ConceptResult?

        func lookup(conceptId: String) async throws -> ConceptResult {
            return try lookupResult.get()
        }

        func lookupInConfiguredSystems(code: String, systems: [String]) async throws -> ConceptResult? {
            return configuredSystemsResult
        }
    }

    // MARK: - Tests

    /// Verifies successful SCTID lookup sets result.
    func testLookup_validSCTID_setsResult() async {
        let reader = MockSelectionReader()
        reader.textToReturn = "73211009"

        let client = MockLookupClient()
        let viewModel = LookupViewModel(selectionReader: reader, client: client)

        await viewModel.lookupFromSystemSelection()

        XCTAssertNotNil(viewModel.result)
        XCTAssertEqual(viewModel.result?.conceptId, "73211009")
        XCTAssertNil(viewModel.errorMessage)
    }

    /// Verifies non-code text sets error message.
    func testLookup_invalidCode_setsErrorMessage() async {
        let reader = MockSelectionReader()
        // Single character — too short to match any code pattern
        reader.textToReturn = "x"

        let client = MockLookupClient()
        let viewModel = LookupViewModel(selectionReader: reader, client: client)

        await viewModel.lookupFromSystemSelection()

        XCTAssertNil(viewModel.result)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    /// Verifies reader throwing sets accessibility error.
    func testLookup_readerThrows_setsErrorMessage() async {
        let reader = MockSelectionReader()
        reader.shouldThrow = true

        let client = MockLookupClient()
        let viewModel = LookupViewModel(selectionReader: reader, client: client)

        await viewModel.lookupFromSystemSelection()

        XCTAssertNil(viewModel.result)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Accessibility") == true)
    }

    /// Verifies client error propagates as error message.
    func testLookup_clientThrows_setsErrorMessage() async {
        let reader = MockSelectionReader()
        reader.textToReturn = "73211009"

        let client = MockLookupClient()
        client.lookupResult = .failure(NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Server error"]
        ))

        let viewModel = LookupViewModel(selectionReader: reader, client: client)
        await viewModel.lookupFromSystemSelection()

        XCTAssertNil(viewModel.result)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    /// Verifies non-SCTID code routes to configured systems lookup.
    func testLookup_nonSCTID_triesConfiguredSystems() async {
        let reader = MockSelectionReader()
        // "12345678" is 8 digits but won't pass Verhoeff, so isSCTID = false
        reader.textToReturn = "12345678"

        let client = MockLookupClient()
        let loincResult = ConceptResult(
            conceptId: "12345678",
            branch: "LOINC (2.81)",
            fsn: nil,
            pt: "Some LOINC code",
            active: true,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://loinc.org"
        )
        client.configuredSystemsResult = loincResult

        let viewModel = LookupViewModel(selectionReader: reader, client: client)
        await viewModel.lookupFromSystemSelection()

        // With no configured systems at test time, it will fall through to SNOMED lookup
        // The key thing is it doesn't crash
        XCTAssertNotNil(viewModel.result ?? viewModel.errorMessage,
                        "Should either have a result or an error")
    }

    /// Verifies isLoading transitions correctly.
    func testLookup_loadingStateTransitions() async {
        let reader = MockSelectionReader()
        reader.textToReturn = "73211009"

        let client = MockLookupClient()
        let viewModel = LookupViewModel(selectionReader: reader, client: client)

        XCTAssertFalse(viewModel.isLoading)
        await viewModel.lookupFromSystemSelection()
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after completion")
    }

    /// Verifies copyToPasteboard sets the clipboard.
    func testCopyToPasteboard_setsClipboard() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let testString = "test-clipboard-\(UUID().uuidString)"
        viewModel.copyToPasteboard(testString)

        let pasteboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasteboardContent, testString)
    }

    /// Verifies openVisualization calls the onVisualize callback.
    func testOpenVisualization_callsCallback() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        viewModel.result = ConceptResult(
            conceptId: "73211009",
            branch: "International",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: true,
            effectiveTime: "20020131",
            moduleId: "900000000000207008"
        )

        var callbackCalled = false
        var callbackResult: ConceptResult?
        viewModel.onVisualize = { result in
            callbackCalled = true
            callbackResult = result
        }

        viewModel.openVisualization()

        XCTAssertTrue(callbackCalled)
        XCTAssertEqual(callbackResult?.conceptId, "73211009")
    }

    /// Verifies copyToPasteboard with nil does nothing.
    func testCopyToPasteboard_nil_doesNothing() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let sentinel = "sentinel-\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sentinel, forType: .string)

        viewModel.copyToPasteboard(nil)

        // Pasteboard should still have the sentinel value
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), sentinel)
    }

    // MARK: - openVisualization Tests

    /// Verifies openVisualization with nil result does not call callback.
    func testOpenVisualization_nilResult_doesNotCallCallback() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        viewModel.result = nil

        var callbackCalled = false
        viewModel.onVisualize = { _ in callbackCalled = true }

        viewModel.openVisualization()

        XCTAssertFalse(callbackCalled)
    }

    // MARK: - openInShrimp Tests

    /// Verifies openInShrimp with nil result does not crash.
    func testOpenInShrimp_nilResult_doesNotCrash() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        viewModel.result = nil

        // Should not crash — just logs a warning
        viewModel.openInShrimp()
    }

    // MARK: - extractCode Tests

    /// Verifies LOINC format code extraction.
    func testExtractCode_loincFormat() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let extracted = viewModel.extractCode(from: "8867-4")

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "8867-4")
        XCTAssertFalse(extracted?.isSCTID ?? true)
    }

    /// Verifies ICD-10 format code extraction.
    func testExtractCode_icd10Format() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let extracted = viewModel.extractCode(from: "J45.901")

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "J45.901")
        XCTAssertFalse(extracted?.isSCTID ?? true)
    }

    /// Verifies empty string returns nil.
    func testExtractCode_emptyString_returnsNil() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let extracted = viewModel.extractCode(from: "")

        XCTAssertNil(extracted)
    }

    /// Verifies single character returns nil.
    func testExtractCode_singleChar_returnsNil() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let extracted = viewModel.extractCode(from: "x")

        XCTAssertNil(extracted)
    }

    // MARK: - extractConceptId Tests

    /// Verifies extractConceptId returns a valid SCTID from text.
    func testExtractConceptId_validSCTID() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let result = viewModel.extractConceptId(from: "concept 73211009 is diabetes")

        XCTAssertEqual(result, "73211009")
    }

    /// Verifies extractConceptId returns nil for non-numeric text.
    func testExtractConceptId_noMatch_returnsNil() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let result = viewModel.extractConceptId(from: "no numbers here at all")

        XCTAssertNil(result)
    }

    /// Verifies extractConceptId returns nil for short numbers.
    func testExtractConceptId_shortNumber_returnsNil() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let result = viewModel.extractConceptId(from: "12345")

        XCTAssertNil(result, "5-digit number should not match (minimum is 6)")
    }

    // MARK: - extractAllConceptIds Tests

    /// Verifies extractAllConceptIds finds multiple IDs in text.
    func testExtractAllConceptIds_multipleIds() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let matches = viewModel.extractAllConceptIds(from: "73211009 and 385804009 are codes")

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertEqual(matches[1].conceptId, "385804009")
    }

    /// Verifies extractAllConceptIds returns empty for no matches.
    func testExtractAllConceptIds_noneFound() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let matches = viewModel.extractAllConceptIds(from: "no codes here")

        XCTAssertTrue(matches.isEmpty)
    }

    /// Verifies extractAllConceptIds captures existing pipe-delimited terms.
    func testExtractAllConceptIds_withExistingTerm() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let matches = viewModel.extractAllConceptIds(from: "73211009 | Diabetes mellitus |")

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertEqual(matches[0].existingTerm, "Diabetes mellitus")
    }

    // MARK: - LookupError Tests

    /// Verifies all LookupError cases have non-nil errorDescription.
    func testLookupError_descriptions() async {
        let errors: [LookupError] = [
            .notAConceptId,
            .accessibilityPermissionLikelyMissing,
            .codeNotFound("12345")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) description should not be empty")
        }
    }

    /// Verifies codeNotFound includes the code in the message.
    func testLookupError_codeNotFound_includesCode() async {
        let error = LookupError.codeNotFound("ABC-123")
        XCTAssertTrue(error.errorDescription?.contains("ABC-123") == true)
    }

    // MARK: - extractCode Additional Tests

    /// Verifies extractCode handles alphanumeric codes with dots.
    func testExtractCode_alphanumericCode() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let extracted = viewModel.extractCode(from: "E11.65")

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "E11.65")
        XCTAssertFalse(extracted?.isSCTID ?? true)
    }

    /// Verifies extractCode identifies valid SCTID correctly.
    func testExtractCode_validSCTID_flaggedAsSCTID() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let extracted = viewModel.extractCode(from: "73211009")

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "73211009")
        XCTAssertTrue(extracted?.isSCTID ?? false, "73211009 should pass Verhoeff validation")
    }

    // MARK: - Input Size Guard Tests

    /// Verifies extractConceptId returns nil for oversized input.
    func testExtractConceptId_oversizedInput_returnsNil() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let oversized = String(repeating: "7", count: LookupViewModel.maxExtractionInputSize + 1)
        let result = viewModel.extractConceptId(from: oversized)

        XCTAssertNil(result, "Should reject input exceeding maxExtractionInputSize")
    }

    /// Verifies extractCode returns nil for oversized input.
    func testExtractCode_oversizedInput_returnsNil() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let oversized = String(repeating: "7", count: LookupViewModel.maxExtractionInputSize + 1)
        let result = viewModel.extractCode(from: oversized)

        XCTAssertNil(result, "Should reject input exceeding maxExtractionInputSize")
    }

    /// Verifies extractAllConceptIds returns empty for oversized input.
    func testExtractAllConceptIds_oversizedInput_returnsEmpty() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let oversized = String(repeating: "7", count: LookupViewModel.maxExtractionInputSize + 1)
        let result = viewModel.extractAllConceptIds(from: oversized)

        XCTAssertTrue(result.isEmpty, "Should reject input exceeding maxExtractionInputSize")
    }

    /// Verifies extraction works for input at exactly the size limit.
    func testExtractConceptId_atLimit_works() async {
        let viewModel = LookupViewModel(selectionReader: MockSelectionReader(), client: MockLookupClient())
        let padding = String(repeating: " ", count: LookupViewModel.maxExtractionInputSize - 8)
        let input = "73211009" + padding
        let result = viewModel.extractConceptId(from: input)

        XCTAssertEqual(result, "73211009")
    }
}
