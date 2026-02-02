import XCTest
@testable import Codeagogo

/// Tests for SNOMED edition URL parsing logic
final class EditionNameParsingTests: XCTestCase {

    // MARK: - URL Splitting Tests

    func testSplitBehaviorOmitsEmptyStrings() {
        // Verify Swift's split behavior (important for index calculations)
        let url = "http://snomed.info/sct/45991000052106/version/20221130"
        let components = url.split(separator: "/")

        XCTAssertEqual(components.count, 6)
        XCTAssertEqual(components[0], "http:")
        XCTAssertEqual(components[1], "snomed.info")
        XCTAssertEqual(components[2], "sct")
        XCTAssertEqual(components[3], "45991000052106")  // Edition ID
        XCTAssertEqual(components[4], "version")
        XCTAssertEqual(components[5], "20221130")        // Date
    }

    func testSplitShortFormUrl() {
        let url = "http://snomed.info/sct/900000000000207008"
        let components = url.split(separator: "/")

        XCTAssertEqual(components.count, 4)
        XCTAssertEqual(components[3], "900000000000207008")  // International edition ID
    }

    func testSplitBaseUrl() {
        let url = "http://snomed.info/sct"
        let components = url.split(separator: "/")

        XCTAssertEqual(components.count, 3)
    }

    // MARK: - Edition ID Mapping Tests

    func testKnownEditionIds() {
        let knownEditions: [String: String] = [
            "900000000000207008": "International",
            "32506021000036107": "Australian",
            "731000124108": "United States",
            "999000041000000102": "United Kingdom",
            "20611000087101": "Canadian",
            "449081005": "Spanish",
            "5991000124107": "Netherlands",
            "45991000052106": "Swedish",
            "554471000005108": "Danish",
            "11000146104": "Norwegian",
            "21000210109": "Belgian",
            "11000220105": "Ireland"
        ]

        // This test documents expected edition mappings
        // The actual mapping is in OntoserverClient.getEditionName()
        for (id, expectedName) in knownEditions {
            // Verify the ID format (6-18 digits)
            XCTAssertTrue(id.allSatisfy { $0.isNumber }, "Edition ID should be numeric: \(id)")
            XCTAssertGreaterThanOrEqual(id.count, 6, "Edition ID too short: \(id)")
            XCTAssertLessThanOrEqual(id.count, 18, "Edition ID too long: \(id)")

            // Document the expected name
            XCTAssertFalse(expectedName.isEmpty, "Edition name should not be empty for \(id)")
        }
    }

    // MARK: - Version URI Format Tests

    func testFullVersionUriFormat() {
        // Full format: http://snomed.info/sct/<editionId>/version/<date>
        let fullUri = "http://snomed.info/sct/32506021000036107/version/20240131"
        let components = fullUri.split(separator: "/")

        XCTAssertGreaterThanOrEqual(components.count, 6, "Full URI should have at least 6 components")

        let editionId = String(components[3])
        let date = String(components[5])

        XCTAssertEqual(editionId, "32506021000036107")
        XCTAssertEqual(date, "20240131")
    }

    func testExperimentalEditionDetection() {
        let experimentalUri = "http://snomed.info/xsct/123456789"
        XCTAssertTrue(experimentalUri.contains("xsct"))

        let standardUri = "http://snomed.info/sct/123456789"
        XCTAssertFalse(standardUri.contains("xsct"))
    }

    // MARK: - Bounds Safety Tests

    func testBoundsCheckForFullUri() {
        let fullUri = "http://snomed.info/sct/45991000052106/version/20221130"
        let components = fullUri.split(separator: "/")

        // Must have >= 6 components to safely access [3] and [5]
        XCTAssertGreaterThanOrEqual(components.count, 6)

        // These accesses should be safe
        XCTAssertNoThrow({
            _ = components[3]  // Edition ID
            _ = components[5]  // Date
        }())
    }

    func testBoundsCheckForShortUri() {
        let shortUri = "http://snomed.info/sct/900000000000207008"
        let components = shortUri.split(separator: "/")

        // Must have >= 4 components to safely access [3]
        XCTAssertGreaterThanOrEqual(components.count, 4)

        // Edition ID access should be safe
        XCTAssertNoThrow({
            _ = components[3]
        }())

        // Date access would be unsafe (only 4 components)
        XCTAssertLessThan(components.count, 6)
    }

    func testBoundsCheckForBaseUri() {
        let baseUri = "http://snomed.info/sct"
        let components = baseUri.split(separator: "/")

        // Only 3 components - cannot safely access edition ID
        XCTAssertEqual(components.count, 3)
        XCTAssertLessThan(components.count, 4)
    }
}
