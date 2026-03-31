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

/// Tests for SNOMED CT concept ID extraction from text
final class ConceptIdExtractionTests: XCTestCase {

    // MARK: - Valid Concept ID Tests

    func testExtractSimpleConceptId() {
        // Basic concept ID (6-18 digits)
        let text = "404684003"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "404684003")
    }

    func testExtractConceptIdWithSurroundingText() {
        let text = "The concept 404684003 is for Clinical Finding"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "404684003")
    }

    func testExtractConceptIdWithWhitespace() {
        let text = "  404684003  "
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "404684003")
    }

    func testExtractConceptIdWithNewlines() {
        let text = "\n404684003\n"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "404684003")
    }

    func testExtractMinimumLengthConceptId() {
        // Minimum 6 digits
        let text = "123456"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "123456")
    }

    func testExtractMaximumLengthConceptId() {
        // Maximum 18 digits
        let text = "123456789012345678"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "123456789012345678")
    }

    func testExtractFirstConceptIdWhenMultiplePresent() {
        let text = "404684003 and 73211009"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "404684003", "Should extract the first concept ID")
    }

    // MARK: - Real SNOMED CT Concept IDs

    func testExtractClinicalFindingId() {
        // 404684003 = Clinical finding (finding)
        let conceptId = extractConceptId(from: "404684003")
        XCTAssertEqual(conceptId, "404684003")
    }

    func testExtractDiabetesId() {
        // 73211009 = Diabetes mellitus (disorder)
        let conceptId = extractConceptId(from: "73211009")
        XCTAssertEqual(conceptId, "73211009")
    }

    func testExtractAspirinId() {
        // 387458008 = Aspirin (substance)
        let conceptId = extractConceptId(from: "387458008")
        XCTAssertEqual(conceptId, "387458008")
    }

    func testExtractInternationalEditionModuleId() {
        // 900000000000207008 = SNOMED CT core module
        let conceptId = extractConceptId(from: "900000000000207008")
        XCTAssertEqual(conceptId, "900000000000207008")
    }

    // MARK: - Invalid Input Tests

    func testRejectTooShortNumber() {
        // Less than 6 digits should not match
        let text = "12345"
        let conceptId = extractConceptId(from: text)
        XCTAssertNil(conceptId)
    }

    func testRejectTooLongNumber() {
        // More than 18 digits should not match
        let text = "1234567890123456789"
        let conceptId = extractConceptId(from: text)
        XCTAssertNil(conceptId)
    }

    func testRejectEmptyString() {
        let conceptId = extractConceptId(from: "")
        XCTAssertNil(conceptId)
    }

    func testRejectWhitespaceOnly() {
        let conceptId = extractConceptId(from: "   ")
        XCTAssertNil(conceptId)
    }

    func testRejectTextOnly() {
        let conceptId = extractConceptId(from: "Hello World")
        XCTAssertNil(conceptId)
    }

    func testRejectNumberWithLetters() {
        // Word boundaries should prevent partial matches
        let text = "ABC123456DEF"
        let conceptId = extractConceptId(from: text)
        XCTAssertNil(conceptId, "Should not match digits embedded in words")
    }

    // MARK: - Edge Cases

    func testExtractFromPipeSeparatedFormat() {
        // Common copy format: "123456789 | Term | "
        let text = "73211009 | Diabetes mellitus (disorder) | "
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "73211009")
    }

    func testExtractFromTabSeparatedFormat() {
        let text = "73211009\tDiabetes mellitus"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "73211009")
    }

    func testExtractFromCommaSeparatedFormat() {
        let text = "73211009, Diabetes mellitus"
        let conceptId = extractConceptId(from: text)
        XCTAssertEqual(conceptId, "73211009")
    }

    // MARK: - Multiple Concept ID Extraction Tests

    func testExtractAllConceptIdsFromMultipleCodes() async {
        let text = "385804009 and this other code 999000001000168109"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].conceptId, "385804009")
        XCTAssertNil(matches[0].existingTerm)
        XCTAssertEqual(matches[1].conceptId, "999000001000168109")
        XCTAssertNil(matches[1].existingTerm)
    }

    func testExtractAllConceptIdsPreservesOrder() async {
        let text = "First: 73211009, Second: 404684003, Third: 387458008"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertEqual(matches[1].conceptId, "404684003")
        XCTAssertEqual(matches[2].conceptId, "387458008")
    }

    func testExtractAllConceptIdsWithDuplicates() async {
        let text = "73211009 appears twice: 73211009"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertEqual(matches[1].conceptId, "73211009")
    }

    func testExtractAllConceptIdsEmptyForNoMatches() async {
        let text = "No concept IDs here, just text"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertTrue(matches.isEmpty)
    }

    func testExtractAllConceptIdsSingleCode() async {
        let text = "Just one code: 73211009"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertNil(matches[0].existingTerm)
    }

    func testExtractAllConceptIdsRangesAreCorrect() async {
        let text = "Code 73211009 is here"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(String(text[matches[0].range]), "73211009")
    }

    func testExtractAllConceptIdsReplacementPreservesText() async {
        let text = "385804009 and this other code 999000001000168109"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        // Simulate replacement (reverse order to preserve indices)
        var result = text
        for match in matches.reversed() {
            let replacement = "\(match.conceptId) | Term |"
            result.replaceSubrange(match.range, with: replacement)
        }

        XCTAssertEqual(result, "385804009 | Term | and this other code 999000001000168109 | Term |")
    }

    // MARK: - Existing Term Detection Tests

    func testExtractDetectsExistingPipeDelimitedTerm() async {
        let text = "73211009 | Diabetes mellitus |"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertEqual(matches[0].existingTerm, "Diabetes mellitus")
    }

    func testExtractDetectsExistingTermWithExtraWhitespace() async {
        let text = "73211009  |  Diabetes mellitus  |"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].existingTerm, "Diabetes mellitus")
    }

    func testExtractMixedCodesWithAndWithoutTerms() async {
        let text = "73211009 | Diabetes | and 385804009"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertEqual(matches[0].existingTerm, "Diabetes")
        XCTAssertEqual(matches[1].conceptId, "385804009")
        XCTAssertNil(matches[1].existingTerm)
    }

    func testExtractRangeIncludesPipeDelimitedTerm() async {
        let text = "Code: 73211009 | Diabetes | is here"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(String(text[matches[0].range]), "73211009 | Diabetes |")
    }

    func testExtractMultipleCodesAllWithTerms() async {
        let text = "73211009 | Diabetes | and 385804009 | Diabetic care |"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].existingTerm, "Diabetes")
        XCTAssertEqual(matches[1].existingTerm, "Diabetic care")
    }

    func testRemoveTermsSimulation() async {
        // Simulate the "remove" toggle behavior
        let text = "73211009 | Diabetes | and 385804009 | Diabetic care |"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        // Replace in reverse order with just the concept IDs
        var result = text
        for match in matches.reversed() {
            result.replaceSubrange(match.range, with: match.conceptId)
        }

        XCTAssertEqual(result, "73211009 and 385804009")
    }

    func testUpdateTermsSimulation() async {
        // Simulate updating wrong terms to correct ones
        let text = "73211009 | Wrong term | and 385804009"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        // Replace with "correct" terms
        var result = text
        for match in matches.reversed() {
            let newTerm = match.conceptId == "73211009" ? "Diabetes mellitus" : "Diabetic care"
            result.replaceSubrange(match.range, with: "\(match.conceptId) | \(newTerm) |")
        }

        XCTAssertEqual(result, "73211009 | Diabetes mellitus | and 385804009 | Diabetic care |")
    }

    // MARK: - SCTID Validation in ConceptMatch Tests

    func testExtractAllConceptIds_SCTIDValidation() async {
        // 73211009 is a valid SCTID, 73211000 has invalid check digit
        let text = "Valid: 73211009 and Invalid: 73211000"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertTrue(matches[0].isSCTID, "73211009 should be a valid SCTID")
        XCTAssertEqual(matches[1].conceptId, "73211000")
        XCTAssertFalse(matches[1].isSCTID, "73211000 should not be a valid SCTID")
    }

    func testExtractAllConceptIds_AllValidSCTIDs() async {
        let text = "73211009 and 385804009"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertTrue(matches[0].isSCTID)
        XCTAssertTrue(matches[1].isSCTID)
    }

    // MARK: - ExtractCode Tests

    func testExtractCode_ValidSCTID() async {
        let text = "73211009"
        let extracted = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractCode(from: text)
        }

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "73211009")
        XCTAssertTrue(extracted?.isSCTID ?? false)
    }

    func testExtractCode_InvalidCheckDigit() async {
        let text = "73211000"
        let extracted = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractCode(from: text)
        }

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "73211000")
        XCTAssertFalse(extracted?.isSCTID ?? true, "Code with invalid check digit should not be marked as SCTID")
    }

    func testExtractCode_LOINCFormat() async {
        let text = "8867-4"
        let extracted = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractCode(from: text)
        }

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "8867-4")
        XCTAssertFalse(extracted?.isSCTID ?? true, "LOINC code should not be marked as SCTID")
    }

    func testExtractCode_ICD10Format() async {
        let text = "J45.901"
        let extracted = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractCode(from: text)
        }

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "J45.901")
        XCTAssertFalse(extracted?.isSCTID ?? true, "ICD-10 code should not be marked as SCTID")
    }

    func testExtractCode_EmptyText() async {
        let text = ""
        let extracted = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractCode(from: text)
        }

        XCTAssertNil(extracted)
    }

    func testExtractCode_WhitespaceOnly() async {
        let text = "   "
        let extracted = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractCode(from: text)
        }

        XCTAssertNil(extracted)
    }

    func testExtractCode_PrefersNumericSCTID() async {
        // When there's a valid numeric SCTID, it should be preferred
        let text = "Concept 73211009 is for diabetes"
        let extracted = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractCode(from: text)
        }

        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.code, "73211009")
        XCTAssertTrue(extracted?.isSCTID ?? false)
    }

    // MARK: - extractAllConceptIds Non-Numeric Code Tests

    func testExtractAllConceptIds_LOINCCode() async {
        let text = "LOINC 8867-4 is heart rate"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].conceptId, "8867-4")
        XCTAssertFalse(matches[0].isSCTID)
    }

    func testExtractAllConceptIds_ICD10Code() async {
        let text = "Diagnosis: E11.9"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].conceptId, "E11.9")
        XCTAssertFalse(matches[0].isSCTID)
    }

    func testExtractAllConceptIds_MixedSNOMEDAndLOINC() async {
        let text = "73211009 and 8867-4"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].conceptId, "73211009")
        XCTAssertTrue(matches[0].isSCTID)
        XCTAssertEqual(matches[1].conceptId, "8867-4")
        XCTAssertFalse(matches[1].isSCTID)
    }

    func testExtractAllConceptIds_LOINCWithPipeTerm() async {
        let text = "8867-4 | Heart rate |"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].conceptId, "8867-4")
        XCTAssertEqual(matches[0].existingTerm, "Heart rate")
    }

    func testExtractAllConceptIds_DoesNotMatchPlainWords() async {
        let text = "This is just plain text with no codes"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertTrue(matches.isEmpty)
    }

    func testExtractAllConceptIds_DoesNotMatchECLCardinality() async {
        // ECL cardinality "0..0" should not be extracted as a code
        let text = "[0..0] 127489000 != 395814003"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].conceptId, "127489000")
        XCTAssertEqual(matches[1].conceptId, "395814003")
    }

    func testExtractAllConceptIds_ECLWithSNOMEDCodes() async {
        // Full ECL expression — should only extract the SNOMED IDs, not ECL syntax
        let text = "(< 763158003 AND ^ 929360061000036106): 127489000 = 395814003, [0..0] 127489000 != 395814003"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        let codes = matches.map { $0.conceptId }
        XCTAssertTrue(codes.contains("763158003"))
        XCTAssertTrue(codes.contains("929360061000036106"))
        XCTAssertTrue(codes.contains("127489000"))
        XCTAssertTrue(codes.contains("395814003"))
        XCTAssertFalse(codes.contains("0..0"), "ECL cardinality should not be extracted")
    }

    func testExtractAllConceptIds_MultipleLOINCCodes() async {
        let text = "8867-4 and 2951-2 and 55284-4"
        let matches = await MainActor.run {
            let vm = LookupViewModel()
            return vm.extractAllConceptIds(from: text)
        }

        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].conceptId, "8867-4")
        XCTAssertEqual(matches[1].conceptId, "2951-2")
        XCTAssertEqual(matches[2].conceptId, "55284-4")
    }

    // MARK: - Helper

    /// Mirrors the extraction logic from LookupViewModel
    private func extractConceptId(from text: String) -> String? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let pattern = #"\b(\d{6,18})\b"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let match = re.firstMatch(in: s, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: s)
        else { return nil }

        return String(s[r])
    }
}
