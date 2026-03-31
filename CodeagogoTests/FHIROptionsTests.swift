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

/// Tests for FHIROptions base URL resolution and thread-safe access.
final class FHIROptionsTests: XCTestCase {

    // MARK: - Setup/Teardown

    /// Key used by FHIROptions in UserDefaults.
    private let endpointKey = "fhir.baseURL"
    /// Stores original value to restore after each test.
    private var originalValue: String?

    override func setUp() {
        super.setUp()
        originalValue = UserDefaults.standard.string(forKey: endpointKey)
    }

    override func tearDown() {
        // Restore original UserDefaults value
        if let original = originalValue {
            UserDefaults.standard.set(original, forKey: endpointKey)
        } else {
            UserDefaults.standard.removeObject(forKey: endpointKey)
        }
        super.tearDown()
    }

    // MARK: - currentBaseURL Tests

    /// Verifies default URL when no UserDefaults value is set.
    func testCurrentBaseURL_default() {
        UserDefaults.standard.removeObject(forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://tx.ontoserver.csiro.au/fhir")
    }

    /// Verifies custom URL from UserDefaults.
    func testCurrentBaseURL_customURL() {
        UserDefaults.standard.set("https://custom.server.com/fhir", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://custom.server.com/fhir")
    }

    /// Verifies empty string falls back to default.
    func testCurrentBaseURL_emptyString_fallsBackToDefault() {
        UserDefaults.standard.set("", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://tx.ontoserver.csiro.au/fhir")
    }

    /// Verifies whitespace-only string falls back to default.
    func testCurrentBaseURL_whitespaceOnly_fallsBackToDefault() {
        UserDefaults.standard.set("   ", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://tx.ontoserver.csiro.au/fhir")
    }

    /// Verifies URL with trailing path is preserved.
    func testCurrentBaseURL_trailingPath() {
        UserDefaults.standard.set("https://server.com/fhir/r4", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://server.com/fhir/r4")
    }

    // MARK: - URL Validation Security Tests

    /// Verifies URL with query parameters falls back to default.
    func testCurrentBaseURL_withQueryParams_fallsBackToDefault() {
        UserDefaults.standard.set("https://server.com/fhir?token=secret", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://tx.ontoserver.csiro.au/fhir")
    }

    /// Verifies URL with fragment falls back to default.
    func testCurrentBaseURL_withFragment_fallsBackToDefault() {
        UserDefaults.standard.set("https://server.com/fhir#section", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://tx.ontoserver.csiro.au/fhir")
    }

    /// Verifies URL without scheme falls back to default.
    func testCurrentBaseURL_noScheme_fallsBackToDefault() {
        UserDefaults.standard.set("server.com/fhir", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "https://tx.ontoserver.csiro.au/fhir")
    }

    /// Verifies HTTP URL is accepted (warning only, not blocked).
    func testCurrentBaseURL_httpURL_accepted() {
        UserDefaults.standard.set("http://localhost:8080/fhir", forKey: endpointKey)

        let url = FHIROptions.currentBaseURL
        XCTAssertEqual(url.absoluteString, "http://localhost:8080/fhir")
    }
}
