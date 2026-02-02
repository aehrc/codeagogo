import XCTest
@testable import Codeagogo

/// Unit tests for the SNOMED CT concept search functionality.
final class SearchTests: XCTestCase {

    // MARK: - InsertFormat Tests

    func testInsertFormatIdOnly() {
        let result = createTestSearchResult()
        XCTAssertEqual(result.formatted(as: .idOnly), "387517004")
    }

    func testInsertFormatPtOnly() {
        let result = createTestSearchResult()
        XCTAssertEqual(result.formatted(as: .ptOnly), "Paracetamol")
    }

    func testInsertFormatFsnOnly() {
        let result = createTestSearchResult()
        XCTAssertEqual(result.formatted(as: .fsnOnly), "Paracetamol (product)")
    }

    func testInsertFormatFsnOnlyFallsBackToPt() {
        let result = SearchResult(
            code: "387517004",
            display: "Paracetamol",
            fsn: nil,
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107/version/20251231",
            editionName: "Australian"
        )
        XCTAssertEqual(result.formatted(as: .fsnOnly), "Paracetamol")
    }

    func testInsertFormatIdPipePT() {
        let result = createTestSearchResult()
        XCTAssertEqual(result.formatted(as: .idPipePT), "387517004 | Paracetamol |")
    }

    func testInsertFormatIdPipeFSN() {
        let result = createTestSearchResult()
        XCTAssertEqual(result.formatted(as: .idPipeFSN), "387517004 | Paracetamol (product) |")
    }

    func testInsertFormatIdPipeFSNFallsBackToPt() {
        let result = SearchResult(
            code: "387517004",
            display: "Paracetamol",
            fsn: nil,
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107/version/20251231",
            editionName: "Australian"
        )
        XCTAssertEqual(result.formatted(as: .idPipeFSN), "387517004 | Paracetamol |")
    }

    func testAllInsertFormatsHaveRawValues() {
        XCTAssertEqual(InsertFormat.idOnly.rawValue, "ID Only")
        XCTAssertEqual(InsertFormat.ptOnly.rawValue, "PT Only")
        XCTAssertEqual(InsertFormat.fsnOnly.rawValue, "FSN Only")
        XCTAssertEqual(InsertFormat.idPipePT.rawValue, "ID | PT |")
        XCTAssertEqual(InsertFormat.idPipeFSN.rawValue, "ID | FSN |")
    }

    func testInsertFormatCaseCount() {
        XCTAssertEqual(InsertFormat.allCases.count, 5)
    }

    // MARK: - SearchResult Tests

    func testSearchResultIdentifiable() {
        let result = createTestSearchResult()
        XCTAssertEqual(result.id, "387517004")
    }

    func testSearchResultHashable() {
        let result1 = createTestSearchResult()
        let result2 = createTestSearchResult()
        XCTAssertEqual(result1, result2)
        XCTAssertEqual(result1.hashValue, result2.hashValue)
    }

    func testSearchResultWithDifferentCodes() {
        let result1 = createTestSearchResult()
        let result2 = SearchResult(
            code: "123456789",
            display: "Different Concept",
            fsn: "Different Concept (finding)",
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107/version/20251231",
            editionName: "Australian"
        )
        XCTAssertNotEqual(result1, result2)
    }

    // MARK: - ValueSet Expansion Response Parsing Tests

    func testParseValueSetExpansionResponse() throws {
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "identifier": "urn:uuid:12345",
                "timestamp": "2024-01-01T00:00:00Z",
                "total": 2,
                "contains": [
                    {
                        "system": "http://snomed.info/sct",
                        "version": "http://snomed.info/sct/32506021000036107/version/20251231",
                        "code": "387517004",
                        "display": "Paracetamol",
                        "designation": [
                            {
                                "use": {
                                    "system": "http://snomed.info/sct",
                                    "code": "900000000000003001"
                                },
                                "value": "Paracetamol (product)"
                            }
                        ]
                    },
                    {
                        "system": "http://snomed.info/sct",
                        "version": "http://snomed.info/sct/900000000000207008/version/20240101",
                        "code": "90332006",
                        "display": "Paracetamol poisoning"
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        XCTAssertEqual(response.resourceType, "ValueSet")
        XCTAssertNotNil(response.expansion)
        XCTAssertEqual(response.expansion?.total, 2)
        XCTAssertEqual(response.expansion?.contains?.count, 2)

        // Check first result
        let first = response.expansion?.contains?.first
        XCTAssertEqual(first?.code, "387517004")
        XCTAssertEqual(first?.display, "Paracetamol")
        XCTAssertEqual(first?.system, "http://snomed.info/sct")
        XCTAssertEqual(first?.version, "http://snomed.info/sct/32506021000036107/version/20251231")

        // Check FSN designation
        let fsn = first?.designation?.first
        XCTAssertEqual(fsn?.use?.code, "900000000000003001")
        XCTAssertEqual(fsn?.value, "Paracetamol (product)")

        // Check second result (no FSN)
        let second = response.expansion?.contains?[1]
        XCTAssertEqual(second?.code, "90332006")
        XCTAssertEqual(second?.display, "Paracetamol poisoning")
        XCTAssertNil(second?.designation)
    }

    func testParseEmptyExpansionResponse() throws {
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "timestamp": "2024-01-01T00:00:00Z",
                "total": 0,
                "contains": []
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        XCTAssertEqual(response.expansion?.total, 0)
        XCTAssertEqual(response.expansion?.contains?.count, 0)
    }

    func testParseExpansionWithNoContains() throws {
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "timestamp": "2024-01-01T00:00:00Z",
                "total": 0
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        XCTAssertNil(response.expansion?.contains)
    }

    // MARK: - SNOMEDEdition Tests

    func testSNOMEDEditionIdentifiable() {
        let edition = SNOMEDEdition(
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107",
            title: "Australian"
        )
        XCTAssertEqual(edition.id, "http://snomed.info/sct/32506021000036107")
    }

    func testSNOMEDEditionHashable() {
        let edition1 = SNOMEDEdition(
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107",
            title: "Australian"
        )
        let edition2 = SNOMEDEdition(
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107",
            title: "Australian"
        )
        XCTAssertEqual(edition1, edition2)
    }

    // MARK: - Edition Name Derivation Tests

    func testEditionNameFromVersionURI() {
        // Test that known edition IDs map to human-readable names
        let knownEditions: [String: String] = [
            "http://snomed.info/sct/900000000000207008/version/20240101": "International",
            "http://snomed.info/sct/32506021000036107/version/20251231": "Australian",
            "http://snomed.info/sct/731000124108/version/20240301": "United States",
            "http://snomed.info/sct/999000041000000102/version/20240101": "United Kingdom"
        ]

        for (versionURI, expectedName) in knownEditions {
            let result = SearchResult(
                code: "123",
                display: "Test",
                fsn: nil,
                system: "http://snomed.info/sct",
                version: versionURI,
                editionName: deriveEditionName(from: versionURI)
            )
            XCTAssertEqual(result.editionName, expectedName, "Expected \(expectedName) for \(versionURI)")
        }
    }

    // MARK: - Helper Methods

    private func createTestSearchResult() -> SearchResult {
        SearchResult(
            code: "387517004",
            display: "Paracetamol",
            fsn: "Paracetamol (product)",
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107/version/20251231",
            editionName: "Australian"
        )
    }

    /// Derives a human-readable edition name from a version URI (test helper).
    private func deriveEditionName(from version: String) -> String {
        let editionNames: [String: String] = [
            "900000000000207008": "International",
            "32506021000036107": "Australian",
            "731000124108": "United States",
            "999000041000000102": "United Kingdom",
            "20611000087101": "Canadian"
        ]

        let components = version.split(separator: "/")
        guard components.count >= 4 else { return "Unknown" }

        let editionId = String(components[3])
        return editionNames[editionId] ?? editionId
    }
}
