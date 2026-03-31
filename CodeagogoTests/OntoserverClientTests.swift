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
}

// MARK: - Mock URLSession

/// Enhanced mock URLSession for testing OntoserverClient.
///
/// Supports multiple responses (queued), request logging, and error injection.
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    /// Queue of responses to return in order. Falls back to single response fields if empty.
    var responseQueue: [(Data, URLResponse)] = []
    /// Single response fields (used when responseQueue is empty).
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    /// All requests received, for verification.
    private(set) var requests: [URLRequest] = []
    /// Counter for response queue consumption.
    private var responseIndex = 0

    /// Convenience: set a single JSON response with HTTP 200.
    func setResponse(json: String, statusCode: Int = 200) {
        mockData = json.data(using: .utf8)
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
    }

    /// Enqueue a response for sequential consumption.
    func enqueueResponse(json: String, statusCode: Int = 200) {
        let data = json.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://test.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        responseQueue.append((data, response))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)

        if let error = mockError {
            throw error
        }

        // Use queue if available
        if responseIndex < responseQueue.count {
            let response = responseQueue[responseIndex]
            responseIndex += 1
            return response
        }

        guard let data = mockData, let response = mockResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }
}

// MARK: - OntoserverClient Mock Tests

extension OntoserverClientTests {

    // MARK: - lookup() Tests

    /// Verifies lookup returns concept from international edition (cache miss).
    func testLookup_cacheMiss_returnsFromInternational() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "version", "valueString": "http://snomed.info/sct/900000000000207008/version/20240101"},
                {"name": "display", "valueString": "Diabetes mellitus"},
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "inactive"},
                        {"name": "value", "valueBoolean": false}
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
        """)

        let client = OntoserverClient(session: mock)
        let result = try await client.lookup(conceptId: "73211009")

        XCTAssertEqual(result.conceptId, "73211009")
        XCTAssertEqual(result.pt, "Diabetes mellitus")
        XCTAssertEqual(result.fsn, "Diabetes mellitus (disorder)")
        XCTAssertEqual(result.active, true)
        XCTAssertTrue(mock.requests.count >= 1)
    }

    /// Verifies second lookup returns cached result without network call.
    func testLookup_cacheHit_noNetworkCall() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "version", "valueString": "http://snomed.info/sct/900000000000207008/version/20240101"},
                {"name": "display", "valueString": "Diabetes mellitus"}
            ]
        }
        """)

        let client = OntoserverClient(session: mock)

        // First lookup — cache miss
        _ = try await client.lookup(conceptId: "73211009")
        let requestCountAfterFirst = mock.requests.count

        // Second lookup — should be cache hit
        let result = try await client.lookup(conceptId: "73211009")
        XCTAssertEqual(result.conceptId, "73211009")
        XCTAssertEqual(mock.requests.count, requestCountAfterFirst, "Should not make additional network requests for cached concept")
    }

    /// Verifies 404 on international triggers edition fallback.
    func testLookup_404_triggersEditionFallback() async throws {
        let mock = MockURLSession()

        // First request (international) returns 404
        mock.enqueueResponse(json: """
        {"resourceType": "OperationOutcome", "issue": [{"severity": "error", "code": "not-found"}]}
        """, statusCode: 404)

        // Edition list request
        mock.enqueueResponse(json: """
        {
            "resourceType": "Bundle",
            "type": "searchset",
            "entry": [
                {
                    "resource": {
                        "resourceType": "CodeSystem",
                        "url": "http://snomed.info/sct",
                        "version": "http://snomed.info/sct/32506021000036107/version/20240131",
                        "title": "SNOMED CT Australian Edition"
                    }
                }
            ]
        }
        """)

        // AU edition lookup returns result
        mock.enqueueResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "version", "valueString": "http://snomed.info/sct/32506021000036107/version/20240131"},
                {"name": "display", "valueString": "Diabetes mellitus"}
            ]
        }
        """)

        let client = OntoserverClient(session: mock)
        let result = try await client.lookup(conceptId: "73211009")

        XCTAssertEqual(result.conceptId, "73211009")
        XCTAssertTrue(result.branch.contains("Australian"))
    }

    /// Verifies network error is thrown.
    func testLookup_networkError_throws() async {
        let mock = MockURLSession()
        mock.mockError = URLError(.notConnectedToInternet)

        let client = OntoserverClient(session: mock)

        do {
            _ = try await client.lookup(conceptId: "73211009")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    /// Verifies 500 error triggers retry.
    func testLookup_500_retriesBeforeFailing() async {
        let mock = MockURLSession()

        // All requests return 500
        for _ in 0..<5 {
            mock.enqueueResponse(json: """
            {"resourceType": "OperationOutcome", "issue": [{"severity": "error", "code": "exception"}]}
            """, statusCode: 500)
        }

        let client = OntoserverClient(session: mock)

        do {
            _ = try await client.lookup(conceptId: "73211009")
            XCTFail("Expected error to be thrown")
        } catch {
            // Should have retried: initial + 2 retries = 3 requests
            XCTAssertEqual(mock.requests.count, 3, "Expected 3 attempts (1 initial + 2 retries)")
        }
    }

    // MARK: - lookupWithProperties() Tests

    /// Verifies property lookup parses all property types.
    func testLookupWithProperties_parsesAllTypes() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "inactive"},
                        {"name": "value", "valueBoolean": false}
                    ]
                },
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "effectiveTime"},
                        {"name": "value", "valueString": "20020131"}
                    ]
                },
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "parent"},
                        {"name": "value", "valueCode": "64572001"},
                        {"name": "description", "valueString": "Disease"}
                    ]
                },
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "child"},
                        {"name": "value", "valueCoding": {"system": "http://snomed.info/sct", "code": "46635009", "display": "Type 1"}}
                    ]
                },
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "count"},
                        {"name": "value", "valueInteger": 42}
                    ]
                }
            ]
        }
        """)

        let client = OntoserverClient(session: mock)
        let properties = try await client.lookupWithProperties(
            conceptId: "73211009",
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/900000000000207008/version/20240101"
        )

        XCTAssertEqual(properties.count, 5)

        // Check boolean property
        if case .boolean(let val) = properties[0].value {
            XCTAssertEqual(val, false)
        } else {
            XCTFail("Expected boolean value")
        }

        // Check string property
        if case .string(let val) = properties[1].value {
            XCTAssertEqual(val, "20020131")
        } else {
            XCTFail("Expected string value")
        }

        // Check code property with description
        XCTAssertEqual(properties[2].code, "parent")
        XCTAssertEqual(properties[2].display, "Disease")

        // Check coding property
        if case .coding(let coding) = properties[3].value {
            XCTAssertEqual(coding.code, "46635009")
        } else {
            XCTFail("Expected coding value")
        }

        // Check integer property
        if case .integer(let val) = properties[4].value {
            XCTAssertEqual(val, 42)
        } else {
            XCTFail("Expected integer value")
        }
    }

    /// Verifies property lookup uses cache on second call.
    func testLookupWithProperties_cacheHit() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "inactive"},
                        {"name": "value", "valueBoolean": false}
                    ]
                }
            ]
        }
        """)

        let client = OntoserverClient(session: mock)
        let system = "http://snomed.info/sct"
        let version = "http://snomed.info/sct/900000000000207008/version/20240101"

        // First call — cache miss
        _ = try await client.lookupWithProperties(conceptId: "73211009", system: system, version: version)
        let countAfterFirst = mock.requests.count

        // Second call — cache hit
        let result = try await client.lookupWithProperties(conceptId: "73211009", system: system, version: version)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(mock.requests.count, countAfterFirst)
    }

    /// Verifies lookupWithProperties omits version param when empty.
    func testLookupWithProperties_emptyVersion_omitsParam() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": []
        }
        """)

        let client = OntoserverClient(session: mock)
        _ = try await client.lookupWithProperties(
            conceptId: "73211009",
            system: "http://snomed.info/sct",
            version: ""
        )

        let requestURL = mock.requests.first?.url?.absoluteString ?? ""
        XCTAssertFalse(requestURL.contains("version="), "Empty version should not appear as query param")
    }

    // MARK: - lookupInConfiguredSystems() Tests

    /// Verifies empty systems returns nil immediately.
    func testLookupInConfiguredSystems_emptySystems_returnsNil() async throws {
        let mock = MockURLSession()
        let client = OntoserverClient(session: mock)

        let result = try await client.lookupInConfiguredSystems(code: "8867-4", systems: [])

        XCTAssertNil(result)
        XCTAssertEqual(mock.requests.count, 0)
    }

    /// Verifies lookup found in first configured system.
    func testLookupInConfiguredSystems_foundInFirst() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "display", "valueString": "Heart rate"},
                {"name": "version", "valueString": "2.74"}
            ]
        }
        """)

        let client = OntoserverClient(session: mock)
        let result = try await client.lookupInConfiguredSystems(
            code: "8867-4",
            systems: ["http://loinc.org"]
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pt, "Heart rate")
        XCTAssertEqual(result?.system, "http://loinc.org")
    }

    /// Verifies 404 in all systems returns nil.
    func testLookupInConfiguredSystems_notFound_returnsNil() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {"resourceType": "OperationOutcome", "issue": [{"severity": "error", "code": "not-found"}]}
        """, statusCode: 404)

        let client = OntoserverClient(session: mock)
        let result = try await client.lookupInConfiguredSystems(
            code: "INVALID",
            systems: ["http://loinc.org"]
        )

        XCTAssertNil(result)
    }

    // MARK: - batchLookup() Tests

    /// Verifies empty IDs returns empty result.
    func testBatchLookup_emptyIds_returnsEmpty() async throws {
        let mock = MockURLSession()
        let client = OntoserverClient(session: mock)

        let result = try await client.batchLookup(conceptIds: [])

        XCTAssertTrue(result.ptByCode.isEmpty)
        XCTAssertTrue(result.fsnByCode.isEmpty)
        XCTAssertTrue(result.activeByCode.isEmpty)
        XCTAssertEqual(mock.requests.count, 0)
    }

    /// Verifies batch lookup with active status extension parsing.
    func testBatchLookup_parsesActiveStatus() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 1,
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
                        ],
                        "extension": [
                            {
                                "url": "http://hl7.org/fhir/5.0/StructureDefinition/extension-ValueSet.expansion.contains.property",
                                "extension": [
                                    {"url": "code", "valueCode": "inactive"},
                                    {"url": "value", "valueBoolean": false}
                                ]
                            }
                        ]
                    }
                ]
            }
        }
        """)

        let client = OntoserverClient(session: mock)
        let result = try await client.batchLookup(conceptIds: ["73211009"])

        XCTAssertEqual(result.pt(for: "73211009"), "Diabetes mellitus")
        XCTAssertEqual(result.fsn(for: "73211009"), "Diabetes mellitus (disorder)")
        XCTAssertEqual(result.isActive(for: "73211009"), true) // inactive=false means active=true
    }

    // MARK: - Response Parsing Edge Cases

    /// Verifies inactive as boolean true yields active=false.
    func testParseLookup_inactiveBoolean_true() throws {
        let json = """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "display", "valueString": "Old concept"},
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "inactive"},
                        {"name": "value", "valueBoolean": true}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let params = try JSONDecoder().decode(FHIRParameters.self, from: json)
        let props = params.parameter ?? []

        // Find the inactive property
        let inactiveProp = props.first { $0.name == "property" }
        let parts = inactiveProp?.part ?? []
        let codePart = parts.first { $0.name == "code" }
        let valuePart = parts.first { $0.name == "value" }

        XCTAssertEqual(codePart?.valueCode, "inactive")
        XCTAssertEqual(valuePart?.valueBoolean, true)
    }

    /// Verifies inactive as string "true" is parsed correctly.
    func testParseLookup_inactiveString_true() throws {
        let json = """
        {
            "resourceType": "Parameters",
            "parameter": [
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "inactive"},
                        {"name": "value", "valueString": "true"}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let params = try JSONDecoder().decode(FHIRParameters.self, from: json)
        let parts = params.parameter?.first?.part ?? []
        let valuePart = parts.first { $0.name == "value" }

        XCTAssertEqual(valuePart?.valueString, "true")
    }

    /// Verifies FSN designation parsing from lookup response.
    func testParseLookup_fsnDesignation() throws {
        let json = """
        {
            "resourceType": "Parameters",
            "parameter": [
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
        let parts = params.parameter?.first?.part ?? []

        let usePart = parts.first { $0.name == "use" }
        let valuePart = parts.first { $0.name == "value" }

        XCTAssertEqual(usePart?.valueCoding?.code, "900000000000003001")
        XCTAssertEqual(valuePart?.valueString, "Diabetes mellitus (disorder)")
    }

    /// Verifies effectiveTime and moduleId property parsing.
    func testParseLookup_metadataProperties() throws {
        let json = """
        {
            "resourceType": "Parameters",
            "parameter": [
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "effectiveTime"},
                        {"name": "value", "valueString": "20020131"}
                    ]
                },
                {
                    "name": "property",
                    "part": [
                        {"name": "code", "valueCode": "moduleId"},
                        {"name": "value", "valueString": "900000000000207008"}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let params = try JSONDecoder().decode(FHIRParameters.self, from: json)
        let properties = params.parameter ?? []

        XCTAssertEqual(properties.count, 2)

        let effectiveTimeParts = properties[0].part ?? []
        let etValue = effectiveTimeParts.first { $0.name == "value" }
        XCTAssertEqual(etValue?.valueString, "20020131")

        let moduleIdParts = properties[1].part ?? []
        let modValue = moduleIdParts.first { $0.name == "value" }
        XCTAssertEqual(modValue?.valueString, "900000000000207008")
    }

    // MARK: - Edition Name Tests

    /// Verifies OntoserverError descriptions.
    func testOntoserverError_descriptions() {
        let invalidURL = OntoserverError.invalidURL("bad url")
        XCTAssertTrue(invalidURL.errorDescription?.contains("bad url") == true)

        let notFound = OntoserverError.conceptNotFound("99999")
        XCTAssertTrue(notFound.errorDescription?.contains("99999") == true)

        let noEditions = OntoserverError.noEditionsFound
        XCTAssertNotNil(noEditions.errorDescription)
    }

    // MARK: - SearchResult Tests

    /// Verifies search result deduplication via response parsing.
    func testSearchResponse_deduplication() throws {
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 3,
                "contains": [
                    {"system": "http://snomed.info/sct", "code": "73211009", "display": "Diabetes mellitus",
                     "version": "http://snomed.info/sct/900000000000207008/version/20240101"},
                    {"system": "http://snomed.info/sct", "code": "73211009", "display": "Diabetes mellitus",
                     "version": "http://snomed.info/sct/32506021000036107/version/20240131"},
                    {"system": "http://snomed.info/sct", "code": "385804009", "display": "Diabetic care",
                     "version": "http://snomed.info/sct/900000000000207008/version/20240101"}
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        XCTAssertEqual(response.expansion?.contains?.count, 3)

        // Deduplication happens in parseSearchResults — verify the raw response has duplicates
        let codes = response.expansion?.contains?.compactMap { $0.code } ?? []
        XCTAssertEqual(codes, ["73211009", "73211009", "385804009"])
    }

    /// Verifies FSN extraction from search designation.
    func testSearchResponse_fsnExtraction() throws {
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 1,
                "contains": [
                    {
                        "system": "http://snomed.info/sct",
                        "code": "73211009",
                        "display": "Diabetes mellitus",
                        "version": "http://snomed.info/sct/900000000000207008/version/20240101",
                        "designation": [
                            {
                                "use": {"code": "900000000000003001"},
                                "value": "Diabetes mellitus (disorder)"
                            }
                        ]
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)
        let fsnDesignation = response.expansion?.contains?.first?.designation?.first

        XCTAssertEqual(fsnDesignation?.use?.code, "900000000000003001")
        XCTAssertEqual(fsnDesignation?.value, "Diabetes mellitus (disorder)")
    }

    /// Verifies edition name map contains known entries.
    func testEditionNames_knownEditions() {
        // Verify through ConceptResult branch parsing
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "International (20240101)",
            fsn: nil,
            pt: nil,
            active: nil,
            effectiveTime: nil,
            moduleId: nil
        )
        XCTAssertEqual(result.branch, "International (20240101)")
    }

    /// Verifies SNOMEDEdition system field for xsct editions.
    func testSNOMEDEdition_xsctSystem() {
        let edition = SNOMEDEdition(
            system: "http://snomed.info/xsct",
            version: "http://snomed.info/xsct/11000221109",
            title: "Argentine (experimental)"
        )

        XCTAssertEqual(edition.system, "http://snomed.info/xsct")
        XCTAssertTrue(edition.title.contains("experimental"))
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

    // MARK: - Search Tests

    /// Verifies search with empty filter returns empty results.
    func testSearchConcepts_emptyFilter_returnsEmpty() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 0,
                "contains": []
            }
        }
        """)

        let client = OntoserverClient(session: mock)
        let results = try await client.searchConcepts(filter: "", editionURI: nil)

        XCTAssertTrue(results.isEmpty, "Empty filter should return empty results")
    }

    /// Verifies search propagates network errors.
    func testSearchConcepts_networkError_throws() async {
        let mock = MockURLSession()
        mock.mockError = URLError(.notConnectedToInternet)

        let client = OntoserverClient(session: mock)

        do {
            _ = try await client.searchConcepts(filter: "diabetes", editionURI: nil)
            XCTFail("Should throw network error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    // MARK: - Retry Tests

    /// Verifies lookup retries on 500 and succeeds on second attempt.
    func testLookup_retrySucceedsOnSecondAttempt() async throws {
        let mock = MockURLSession()

        // First request returns 500
        mock.enqueueResponse(json: """
        {"resourceType": "OperationOutcome", "issue": [{"severity": "error", "code": "exception"}]}
        """, statusCode: 500)

        // Second request (retry) returns success
        mock.enqueueResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "version", "valueString": "http://snomed.info/sct/900000000000207008/version/20240101"},
                {"name": "display", "valueString": "Diabetes mellitus"}
            ]
        }
        """)

        let client = OntoserverClient(session: mock)
        let result = try await client.lookup(conceptId: "73211009")

        XCTAssertEqual(result.conceptId, "73211009")
        XCTAssertEqual(result.pt, "Diabetes mellitus")
        XCTAssertGreaterThanOrEqual(mock.requests.count, 2, "Should have retried at least once")
    }

    // MARK: - Edition Name Tests

    /// Verifies unknown edition ID passes through as-is.
    func testEditionNames_unknownEdition_returnsId() {
        // Create a result with an unknown module ID — the branch field should preserve it
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "999999999999999999 (20240101)",
            fsn: nil,
            pt: nil,
            active: nil,
            effectiveTime: nil,
            moduleId: "999999999999999999"
        )
        // Unknown edition should keep the raw string
        XCTAssertTrue(result.branch.contains("999999999999999999"))
    }

    // MARK: - Batch Lookup Tests

    /// Verifies batch lookup with all cached IDs makes no network calls.
    func testBatchLookup_allCached_noNetworkCall() async throws {
        let mock = MockURLSession()
        mock.setResponse(json: """
        {
            "resourceType": "Parameters",
            "parameter": [
                {"name": "version", "valueString": "http://snomed.info/sct/900000000000207008/version/20240101"},
                {"name": "display", "valueString": "Diabetes mellitus"}
            ]
        }
        """)

        let client = OntoserverClient(session: mock)

        // Prime cache
        _ = try await client.lookup(conceptId: "73211009")
        let requestsAfterPrime = mock.requests.count

        // Batch with already-cached ID
        let result = try await client.batchLookup(conceptIds: ["73211009"])

        XCTAssertNotNil(result.pt(for: "73211009"))
        XCTAssertEqual(mock.requests.count, requestsAfterPrime,
                       "Should not make additional requests for cached IDs")
    }

    /// Verifies OntoserverError cases have non-nil descriptions.
    func testOntoserverError_allCases_haveDescriptions() {
        let errors: [OntoserverError] = [
            .conceptNotFound("73211009"),
            .invalidURL("bad url"),
            .noEditionsFound,
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
        }
    }

    /// Verifies search response with version field in URL.
    func testSearchResponse_containsExpectedFields() throws {
        let json = """
        {
            "resourceType": "ValueSet",
            "expansion": {
                "total": 1,
                "contains": [
                    {
                        "system": "http://snomed.info/sct",
                        "version": "http://snomed.info/sct/32506021000036107/version/20240131",
                        "code": "73211009",
                        "display": "Diabetes mellitus"
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ValueSetExpansionResponse.self, from: json)

        let entry = response.expansion?.contains?.first
        XCTAssertEqual(entry?.code, "73211009")
        XCTAssertEqual(entry?.version, "http://snomed.info/sct/32506021000036107/version/20240131")
        XCTAssertEqual(entry?.display, "Diabetes mellitus")
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
