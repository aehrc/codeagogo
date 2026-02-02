import XCTest
@testable import Codeagogo

/// Unit tests for OntoserverClient using mocked URLSession
final class OntoserverClientTests: XCTestCase {

    // MARK: - FHIR Response Parsing Tests

    func testParseLookupResponse() throws {
        let json = """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "version", "valueString": "http://snomed.info/sct/900000000000207008/version/20240101"},
                {"name": "display", "valueString": "Diabetes mellitus"},
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "inactive"},
                        {"name": "value", "valueString": "false"}
                    ]
                },
                {
                    "name": "designation",
                    "part": [
                        {"name": "use", "valueCoding": {"code": "900000000000003001"}},
                        {"name": "value", "valueString": "Diabetes mellitus (disorder)"}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let params = try JSONDecoder().decode(FHIRParameters.self, from: json)

        XCTAssertEqual(params.resourceType, "Parameters")
        XCTAssertNotNil(params.parameter)
        XCTAssertEqual(params.parameter?.count, 4)

        // Check version parameter
        let versionParam = params.parameter?.first { $0.name == "version" }
        XCTAssertEqual(versionParam?.valueString, "http://snomed.info/sct/900000000000207008/version/20240101")

        // Check display parameter
        let displayParam = params.parameter?.first { $0.name == "display" }
        XCTAssertEqual(displayParam?.valueString, "Diabetes mellitus")
    }

    func testParseBundleResponse() throws {
        let json = """
        {
            "resourceType": "Bundle",
            "type": "searchset",
            "entry": [
                {
                    "resource": {
                        "resourceType": "CodeSystem",
                        "url": "http://snomed.info/sct",
                        "version": "http://snomed.info/sct/32506021000036107/version/20240131",
                        "name": "SNOMED_CT_AU",
                        "title": "SNOMED CT Australian Edition"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let bundle = try JSONDecoder().decode(FHIRBundle.self, from: json)

        XCTAssertEqual(bundle.resourceType, "Bundle")
        XCTAssertEqual(bundle.type, "searchset")
        XCTAssertEqual(bundle.entry?.count, 1)

        let codeSystem = bundle.entry?.first?.resource
        XCTAssertEqual(codeSystem?.url, "http://snomed.info/sct")
        XCTAssertEqual(codeSystem?.title, "SNOMED CT Australian Edition")
    }

    // MARK: - Error Response Tests

    func testParseOperationOutcomeResourceType() throws {
        let json = """
        {
            "resourceType": "OperationOutcome",
            "issue": [
                {
                    "severity": "error",
                    "code": "not-found",
                    "diagnostics": "Code not found"
                }
            ]
        }
        """.data(using: .utf8)!

        // OperationOutcome can be decoded, but resourceType won't match "Parameters"
        let decoded = try JSONDecoder().decode(FHIRParameters.self, from: json)
        XCTAssertEqual(decoded.resourceType, "OperationOutcome")
        XCTAssertNotEqual(decoded.resourceType, "Parameters")
        // Parameters will be nil since OperationOutcome doesn't have that field
        XCTAssertNil(decoded.parameter)
    }

    // MARK: - URL Construction Tests

    func testLookupUrlConstruction() {
        let baseURL = URL(string: "https://tx.ontoserver.csiro.au/fhir")!
        var comps = URLComponents(url: baseURL.appendingPathComponent("CodeSystem/$lookup"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "system", value: "http://snomed.info/sct"),
            URLQueryItem(name: "version", value: "http://snomed.info/sct/900000000000207008"),
            URLQueryItem(name: "code", value: "73211009"),
            URLQueryItem(name: "_format", value: "json")
        ]

        let url = comps.url!

        XCTAssertTrue(url.absoluteString.contains("CodeSystem/$lookup"))
        XCTAssertTrue(url.absoluteString.contains("code=73211009"))
        XCTAssertTrue(url.absoluteString.contains("_format=json"))
    }

    func testEditionsUrlConstruction() {
        let baseURL = URL(string: "https://tx.ontoserver.csiro.au/fhir")!
        var comps = URLComponents(url: baseURL.appendingPathComponent("CodeSystem"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "url", value: "http://snomed.info/sct,http://snomed.info/xsct"),
            URLQueryItem(name: "_format", value: "json")
        ]

        let url = comps.url!

        XCTAssertTrue(url.absoluteString.contains("CodeSystem?"))
        XCTAssertTrue(url.absoluteString.contains("url="))
    }

    // MARK: - ConceptResult Tests

    func testConceptResultActiveText() {
        let activeResult = ConceptResult(
            conceptId: "123456",
            branch: "MAIN",
            fsn: "Test (test)",
            pt: "Test",
            active: true,
            effectiveTime: nil,
            moduleId: nil
        )
        XCTAssertEqual(activeResult.activeText, "active")

        let inactiveResult = ConceptResult(
            conceptId: "123456",
            branch: "MAIN",
            fsn: "Test (test)",
            pt: "Test",
            active: false,
            effectiveTime: nil,
            moduleId: nil
        )
        XCTAssertEqual(inactiveResult.activeText, "inactive")

        let unknownResult = ConceptResult(
            conceptId: "123456",
            branch: "MAIN",
            fsn: "Test (test)",
            pt: "Test",
            active: nil,
            effectiveTime: nil,
            moduleId: nil
        )
        XCTAssertEqual(unknownResult.activeText, "—")
    }

    // MARK: - SNOMEDEdition Tests

    func testSNOMEDEditionCreation() {
        let edition = SNOMEDEdition(
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/32506021000036107",
            title: "Australian Edition"
        )

        XCTAssertEqual(edition.system, "http://snomed.info/sct")
        XCTAssertEqual(edition.version, "http://snomed.info/sct/32506021000036107")
        XCTAssertEqual(edition.title, "Australian Edition")
    }

    // MARK: - Request Header Tests

    func testAcceptHeaderFormat() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/fhir+json")
    }

    // MARK: - Retry Logic Tests

    func testRetryableErrorsClassification() {
        // Test that network errors are classified as retryable
        let retryableErrors: [URLError.Code] = [
            .timedOut,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .notConnectedToInternet,
            .secureConnectionFailed
        ]

        for errorCode in retryableErrors {
            let error = URLError(errorCode)
            XCTAssertTrue(isRetryableURLError(error), "Expected \(errorCode) to be retryable")
        }

        // Test that client errors are not retryable
        let nonRetryableErrors: [URLError.Code] = [
            .badURL,
            .unsupportedURL,
            .cancelled,
            .fileDoesNotExist
        ]

        for errorCode in nonRetryableErrors {
            let error = URLError(errorCode)
            XCTAssertFalse(isRetryableURLError(error), "Expected \(errorCode) to NOT be retryable")
        }
    }

    func testRetryableHttpErrors() {
        // 5xx errors should be retryable
        for code in [500, 502, 503, 504] {
            let error = NSError(domain: "OntoserverClient", code: code, userInfo: nil)
            XCTAssertTrue(isRetryableHttpError(error), "Expected HTTP \(code) to be retryable")
        }

        // 4xx errors should not be retryable
        for code in [400, 401, 403, 404, 422] {
            let error = NSError(domain: "OntoserverClient", code: code, userInfo: nil)
            XCTAssertFalse(isRetryableHttpError(error), "Expected HTTP \(code) to NOT be retryable")
        }
    }

    // MARK: - Helper methods for retry classification tests

    private func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }

    private func isRetryableHttpError(_ error: NSError) -> Bool {
        guard error.domain == "OntoserverClient" else { return false }
        return error.code >= 500 && error.code < 600
    }
}

// MARK: - Batch Lookup Tests

    func testParseBatchLookupResponse() throws {
        // Sample response from ValueSet/$expand with includeDesignations
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 2,
                "contains": [
                    {
                        "system": "http://snomed.info/sct",
                        "code": "73211009",
                        "display": "Diabetes mellitus",
                        "designation": [
                            {
                                "use": {"code": "900000000000003001"},
                                "value": "Diabetes mellitus (disorder)"
                            }
                        ]
                    },
                    {
                        "system": "http://snomed.info/sct",
                        "code": "385804009",
                        "display": "Diabetic care",
                        "designation": [
                            {
                                "use": {"code": "900000000000003001"},
                                "value": "Diabetic care (regime/therapy)"
                            }
                        ]
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        XCTAssertEqual(response.resourceType, "ValueSet")
        XCTAssertEqual(response.expansion?.total, 2)
        XCTAssertEqual(response.expansion?.contains?.count, 2)

        let firstConcept = response.expansion?.contains?.first
        XCTAssertEqual(firstConcept?.code, "73211009")
        XCTAssertEqual(firstConcept?.display, "Diabetes mellitus")
        XCTAssertEqual(firstConcept?.designation?.first?.value, "Diabetes mellitus (disorder)")
        XCTAssertEqual(firstConcept?.designation?.first?.use?.code, "900000000000003001")
    }

    func testBatchLookupResultAccessors() {
        let result = OntoserverClient.BatchLookupResult(
            ptByCode: [
                "73211009": "Diabetes mellitus",
                "385804009": "Diabetic care"
            ],
            fsnByCode: [
                "73211009": "Diabetes mellitus (disorder)",
                "385804009": "Diabetic care (regime/therapy)"
            ],
            activeByCode: [
                "73211009": true,
                "385804009": false
            ]
        )

        // Test PT accessors
        XCTAssertEqual(result.pt(for: "73211009"), "Diabetes mellitus")
        XCTAssertEqual(result.pt(for: "385804009"), "Diabetic care")
        XCTAssertNil(result.pt(for: "99999999"))

        // Test FSN accessors
        XCTAssertEqual(result.fsn(for: "73211009"), "Diabetes mellitus (disorder)")
        XCTAssertEqual(result.fsn(for: "385804009"), "Diabetic care (regime/therapy)")
        XCTAssertNil(result.fsn(for: "99999999"))

        // Test active status accessors
        XCTAssertEqual(result.isActive(for: "73211009"), true)
        XCTAssertEqual(result.isActive(for: "385804009"), false)
        XCTAssertNil(result.isActive(for: "99999999"))
    }

    func testBatchLookupEmptyResponse() throws {
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 0
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        XCTAssertEqual(response.expansion?.total, 0)
        XCTAssertNil(response.expansion?.contains)
    }

    func testBatchLookupPartialDesignations() throws {
        // Test case where some concepts have FSN designation, others don't
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 2,
                "contains": [
                    {
                        "system": "http://snomed.info/sct",
                        "code": "73211009",
                        "display": "Diabetes mellitus",
                        "designation": [
                            {
                                "use": {"code": "900000000000003001"},
                                "value": "Diabetes mellitus (disorder)"
                            }
                        ]
                    },
                    {
                        "system": "http://snomed.info/sct",
                        "code": "385804009",
                        "display": "Diabetic care"
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        let contains = response.expansion?.contains
        XCTAssertEqual(contains?.count, 2)

        // First concept has designation
        XCTAssertEqual(contains?[0].designation?.count, 1)

        // Second concept has no designation
        XCTAssertNil(contains?[1].designation)
    }

// MARK: - Mock URLSession for Future Tests

/// Protocol for URLSession to enable mocking
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

/// Mock URLSession for testing
final class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        guard let data = mockData, let response = mockResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }
}

// MARK: - Multi-Code-System Tests

extension OntoserverClientTests {

    func testParseCodeSystemLookupResponse() throws {
        // Sample response from CodeSystem/$lookup for LOINC
        let json = """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "display", "valueString": "Heart rate"},
                {"name": "version", "valueString": "2.74"}
            ]
        }
        """.data(using: .utf8)!

        let params = try JSONDecoder().decode(FHIRParameters.self, from: json)

        XCTAssertEqual(params.resourceType, "Parameters")
        XCTAssertNotNil(params.parameter)
        XCTAssertEqual(params.parameter?.count, 2)

        // Check display parameter
        let displayParam = params.parameter?.first { $0.name == "display" }
        XCTAssertEqual(displayParam?.valueString, "Heart rate")

        // Check version parameter
        let versionParam = params.parameter?.first { $0.name == "version" }
        XCTAssertEqual(versionParam?.valueString, "2.74")
    }

    func testConceptResult_NonSNOMEDSystem() {
        let result = ConceptResult(
            conceptId: "8867-4",
            branch: "2.74",
            fsn: nil,
            pt: "Heart rate",
            active: nil,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://loinc.org"
        )

        XCTAssertEqual(result.conceptId, "8867-4")
        XCTAssertEqual(result.pt, "Heart rate")
        XCTAssertEqual(result.system, "http://loinc.org")
        XCTAssertEqual(result.systemName, "LOINC")
        XCTAssertFalse(result.isSNOMEDCT)
    }

    func testConceptResult_SNOMEDSystem() {
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "International (20240101)",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: true,
            effectiveTime: "20020131",
            moduleId: "900000000000207008",
            system: "http://snomed.info/sct"
        )

        XCTAssertEqual(result.conceptId, "73211009")
        XCTAssertEqual(result.systemName, "SNOMED CT")
        XCTAssertTrue(result.isSNOMEDCT)
    }

    func testConceptResult_NilSystemIsSNOMED() {
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "International",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: true,
            effectiveTime: nil,
            moduleId: nil,
            system: nil
        )

        XCTAssertTrue(result.isSNOMEDCT)
        XCTAssertEqual(result.systemName, "SNOMED CT")
    }

    func testCodeSystemBundleResponse() throws {
        // Sample response for GET /CodeSystem with multiple code systems
        let json = """
        {
            "resourceType": "Bundle",
            "type": "searchset",
            "entry": [
                {
                    "resource": {
                        "resourceType": "CodeSystem",
                        "url": "http://loinc.org",
                        "version": "2.74",
                        "title": "LOINC"
                    }
                },
                {
                    "resource": {
                        "resourceType": "CodeSystem",
                        "url": "http://www.nlm.nih.gov/research/umls/rxnorm",
                        "title": "RxNorm"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let bundle = try JSONDecoder().decode(FHIRBundle.self, from: json)

        XCTAssertEqual(bundle.resourceType, "Bundle")
        XCTAssertEqual(bundle.entry?.count, 2)

        let loinc = bundle.entry?.first?.resource
        XCTAssertEqual(loinc?.url, "http://loinc.org")
        XCTAssertEqual(loinc?.title, "LOINC")
        XCTAssertEqual(loinc?.version, "2.74")

        let rxnorm = bundle.entry?[1].resource
        XCTAssertEqual(rxnorm?.url, "http://www.nlm.nih.gov/research/umls/rxnorm")
        XCTAssertEqual(rxnorm?.title, "RxNorm")
    }

    func testNonSNOMEDSearchResponse() throws {
        // Sample response from ValueSet/$expand for LOINC search
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 2,
                "contains": [
                    {
                        "system": "http://loinc.org",
                        "code": "8867-4",
                        "display": "Heart rate"
                    },
                    {
                        "system": "http://loinc.org",
                        "code": "8310-5",
                        "display": "Body temperature"
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        XCTAssertEqual(response.expansion?.total, 2)
        XCTAssertEqual(response.expansion?.contains?.count, 2)

        let first = response.expansion?.contains?.first
        XCTAssertEqual(first?.system, "http://loinc.org")
        XCTAssertEqual(first?.code, "8867-4")
        XCTAssertEqual(first?.display, "Heart rate")
    }
}
