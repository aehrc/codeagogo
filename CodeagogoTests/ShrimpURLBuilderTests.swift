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

/// Tests for ShrimpURLBuilder URL construction.
final class ShrimpURLBuilderTests: XCTestCase {

    private let fhirEndpoint = "https://tx.ontoserver.csiro.au/fhir"

    /// Helper to extract query parameter values from a URL.
    private func queryValue(_ name: String, from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    // MARK: - SNOMED CT Tests

    /// Verifies SNOMED CT URL includes concept, version URI, valueset, and fhir params.
    func testBuildURL_snomedCT_withModuleId() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "73211009",
            system: "http://snomed.info/sct",
            moduleId: "32506021000036107",
            effectiveTime: "20240101",
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("concept", from: url!), "73211009")
        XCTAssertEqual(queryValue("version", from: url!), "http://snomed.info/sct/32506021000036107")
        XCTAssertEqual(queryValue("valueset", from: url!), "http://snomed.info/sct/32506021000036107?fhir_vs")
        XCTAssertEqual(queryValue("fhir", from: url!), fhirEndpoint)
    }

    /// Verifies SNOMED CT without moduleId falls back to International edition valueset.
    func testBuildURL_snomedCT_withoutModuleId() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "73211009",
            system: "http://snomed.info/sct",
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("concept", from: url!), "73211009")
        let valueset = queryValue("valueset", from: url!)
        XCTAssertNotNil(valueset)
        XCTAssertTrue(valueset!.contains("900000000000207008"))
        XCTAssertNil(queryValue("version", from: url!))
    }

    /// Verifies Core module 900000000000012004 is remapped to International 900000000000207008.
    func testBuildURL_snomedCT_coreModuleMapping() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "73211009",
            system: "http://snomed.info/sct",
            moduleId: "900000000000012004",
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNotNil(url)
        let version = queryValue("version", from: url!)
        XCTAssertNotNil(version)
        XCTAssertTrue(version!.contains("900000000000207008"))
        XCTAssertFalse(version!.contains("900000000000012004"))
    }

    // MARK: - Non-SNOMED Tests

    /// Verifies LOINC URL includes system, concept, loinc.org/vs valueset.
    func testBuildURL_loinc() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "8867-4",
            system: "http://loinc.org",
            version: "2.81",
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("concept", from: url!), "8867-4")
        XCTAssertEqual(queryValue("system", from: url!), "http://loinc.org")
        XCTAssertEqual(queryValue("version", from: url!), "2.81")
        XCTAssertEqual(queryValue("valueset", from: url!), "http://loinc.org/vs")
    }

    /// Verifies ICD-10 URL uses system?fhir_vs as valueset.
    func testBuildURL_icd10() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "J45.901",
            system: "http://hl7.org/fhir/sid/icd-10-cm",
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("concept", from: url!), "J45.901")
        XCTAssertEqual(queryValue("system", from: url!), "http://hl7.org/fhir/sid/icd-10-cm")
        let valueset = queryValue("valueset", from: url!)
        XCTAssertNotNil(valueset)
        XCTAssertTrue(valueset!.contains("icd-10-cm"))
        XCTAssertTrue(valueset!.contains("fhir_vs"))
    }

    /// Verifies RxNorm URL uses rxnorm?fhir_vs as valueset.
    func testBuildURL_rxnorm() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "857005",
            system: "http://www.nlm.nih.gov/research/umls/rxnorm",
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("concept", from: url!), "857005")
        let valueset = queryValue("valueset", from: url!)
        XCTAssertNotNil(valueset)
        XCTAssertTrue(valueset!.contains("rxnorm"))
        XCTAssertTrue(valueset!.contains("fhir_vs"))
    }

    // MARK: - Edge Cases

    /// Verifies nil system returns nil URL.
    func testBuildURL_nilSystem_returnsNil() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "73211009",
            system: nil,
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNil(url)
    }

    /// Verifies convenience method extracts info from ConceptResult.
    func testBuildURL_fromConceptResult() {
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "International (20240101)",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: true,
            effectiveTime: "20240101",
            moduleId: "900000000000207008",
            system: "http://snomed.info/sct"
        )

        let url = ShrimpURLBuilder.buildURL(from: result, fhirEndpoint: fhirEndpoint)
        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("concept", from: url!), "73211009")
    }

    /// Verifies version extraction from branch string like "LOINC (2.81)".
    func testBuildURL_extractsVersionFromBranch() {
        let result = ConceptResult(
            conceptId: "8867-4",
            branch: "LOINC (2.81)",
            fsn: nil,
            pt: "Heart rate",
            active: true,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://loinc.org"
        )

        let url = ShrimpURLBuilder.buildURL(from: result, fhirEndpoint: fhirEndpoint)
        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("version", from: url!), "2.81")
    }

    /// Verifies every URL includes the FHIR endpoint parameter.
    func testBuildURL_alwaysIncludesFhirEndpoint() {
        let url = ShrimpURLBuilder.buildURL(
            conceptId: "73211009",
            system: "http://snomed.info/sct",
            moduleId: "900000000000207008",
            fhirEndpoint: fhirEndpoint
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(queryValue("fhir", from: url!), fhirEndpoint)
    }
}
