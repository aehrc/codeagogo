import XCTest
@testable import SNOMED_Lookup

/// Integration tests that hit the real FHIR endpoint
/// These tests require network access and may be slow
final class IntegrationTests: XCTestCase {

    private var client: OntoserverClient!

    override func setUp() {
        super.setUp()
        client = OntoserverClient()
    }

    override func tearDown() {
        client = nil
        super.tearDown()
    }

    // MARK: - Live Lookup Tests

    func testLookupInternationalConcept() async throws {
        // 73211009 = Diabetes mellitus (disorder) - International edition
        let result = try await client.lookup(conceptId: "73211009")

        XCTAssertEqual(result.conceptId, "73211009")
        XCTAssertNotNil(result.fsn)
        XCTAssertNotNil(result.pt)
        XCTAssertTrue(result.fsn?.contains("Diabetes") ?? false)
        XCTAssertEqual(result.active, true)
    }

    func testLookupClinicalFinding() async throws {
        // 404684003 = Clinical finding (finding) - root concept
        let result = try await client.lookup(conceptId: "404684003")

        XCTAssertEqual(result.conceptId, "404684003")
        XCTAssertNotNil(result.fsn)
        XCTAssertTrue(result.fsn?.lowercased().contains("clinical finding") ?? false)
    }

    func testLookupBodyStructure() async throws {
        // 123037004 = Body structure (body structure)
        let result = try await client.lookup(conceptId: "123037004")

        XCTAssertEqual(result.conceptId, "123037004")
        XCTAssertNotNil(result.fsn)
    }

    func testLookupProcedure() async throws {
        // 71388002 = Procedure (procedure)
        let result = try await client.lookup(conceptId: "71388002")

        XCTAssertEqual(result.conceptId, "71388002")
        XCTAssertNotNil(result.fsn)
        XCTAssertTrue(result.fsn?.lowercased().contains("procedure") ?? false)
    }

    func testLookupSubstance() async throws {
        // 387458008 = Aspirin (substance)
        let result = try await client.lookup(conceptId: "387458008")

        XCTAssertEqual(result.conceptId, "387458008")
        XCTAssertNotNil(result.fsn)
        XCTAssertTrue(result.fsn?.lowercased().contains("aspirin") ?? false)
    }

    // MARK: - Error Handling Tests

    func testLookupNonexistentConcept() async {
        // This concept ID should not exist
        do {
            _ = try await client.lookup(conceptId: "999999999999")
            XCTFail("Should throw an error for nonexistent concept")
        } catch {
            // Expected - concept not found
            XCTAssertTrue(error.localizedDescription.lowercased().contains("not found") ||
                         (error as NSError).code == 404)
        }
    }

    func testLookupInvalidConceptId() async {
        // Invalid format
        do {
            _ = try await client.lookup(conceptId: "invalid")
            XCTFail("Should throw an error for invalid concept ID")
        } catch {
            // Expected - invalid input
        }
    }

    // MARK: - Cache Tests

    func testCacheHitOnSecondLookup() async throws {
        let conceptId = "73211009"

        // First lookup - cache miss
        let result1 = try await client.lookup(conceptId: conceptId)

        // Second lookup - should be cache hit (much faster)
        let start = Date()
        let result2 = try await client.lookup(conceptId: conceptId)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(result1.conceptId, result2.conceptId)
        XCTAssertEqual(result1.fsn, result2.fsn)

        // Cache hit should be nearly instant (< 10ms typically)
        // Allow up to 100ms to account for test infrastructure
        XCTAssertLessThan(elapsed, 0.1, "Second lookup should be fast (cache hit)")
    }

    // MARK: - Response Validation Tests

    func testResponseContainsRequiredFields() async throws {
        let result = try await client.lookup(conceptId: "73211009")

        // Required fields
        XCTAssertFalse(result.conceptId.isEmpty)
        XCTAssertFalse(result.branch.isEmpty)

        // FSN should have semantic tag
        if let fsn = result.fsn {
            XCTAssertTrue(fsn.contains("("), "FSN should contain semantic tag in parentheses")
            XCTAssertTrue(fsn.contains(")"), "FSN should contain semantic tag in parentheses")
        }
    }

    func testEditionNameFormatting() async throws {
        let result = try await client.lookup(conceptId: "73211009")

        // Branch/edition should be human-readable
        XCTAssertFalse(result.branch.isEmpty)

        // Should not be raw URL
        XCTAssertFalse(result.branch.hasPrefix("http://"))

        // Should contain edition name or identifier
        // Common formats: "International (20240101)" or "Australian (20240131)"
        print("Edition format: \(result.branch)")
    }

    // MARK: - Performance Tests

    func testLookupPerformance() async throws {
        // Simple performance sanity check - lookup should complete within reasonable time
        let start = Date()
        let freshClient = OntoserverClient()
        _ = try await freshClient.lookup(conceptId: "73211009")
        let elapsed = Date().timeIntervalSince(start)

        // Network lookup should typically complete within 10 seconds
        // Allow up to 30 seconds for slow connections
        XCTAssertLessThan(elapsed, 30.0, "Lookup took too long: \(elapsed) seconds")
    }
}

