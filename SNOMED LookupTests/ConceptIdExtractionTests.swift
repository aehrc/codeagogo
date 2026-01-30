import XCTest
@testable import SNOMED_Lookup

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
