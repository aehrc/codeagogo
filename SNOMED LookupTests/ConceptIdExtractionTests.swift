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
