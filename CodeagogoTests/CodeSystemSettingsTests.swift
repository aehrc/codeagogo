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

/// Tests for CodeSystemSettings and ConfiguredCodeSystem.
final class CodeSystemSettingsTests: XCTestCase {

    // MARK: - ConfiguredCodeSystem Tests

    func testConfiguredCodeSystem_Initialization() {
        let system = ConfiguredCodeSystem(
            uri: "http://loinc.org",
            title: "LOINC",
            enabled: true
        )

        XCTAssertEqual(system.uri, "http://loinc.org")
        XCTAssertEqual(system.title, "LOINC")
        XCTAssertTrue(system.enabled)
    }

    func testConfiguredCodeSystem_IdUsesURI() {
        let system = ConfiguredCodeSystem(
            uri: "http://loinc.org",
            title: "LOINC",
            enabled: true
        )

        XCTAssertEqual(system.id, "http://loinc.org")
    }

    func testConfiguredCodeSystem_Hashable() {
        let system1 = ConfiguredCodeSystem(uri: "http://loinc.org", title: "LOINC", enabled: true)
        let system2 = ConfiguredCodeSystem(uri: "http://loinc.org", title: "LOINC", enabled: true)
        let system3 = ConfiguredCodeSystem(uri: "http://rxnorm.org", title: "RxNorm", enabled: true)

        XCTAssertEqual(system1, system2)
        XCTAssertNotEqual(system1, system3)
    }

    func testConfiguredCodeSystem_Codable() throws {
        let original = ConfiguredCodeSystem(
            uri: "http://loinc.org",
            title: "LOINC",
            enabled: false
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConfiguredCodeSystem.self, from: encoded)

        XCTAssertEqual(decoded.uri, original.uri)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.enabled, original.enabled)
    }

    // MARK: - AvailableCodeSystem Tests

    func testAvailableCodeSystem_Initialization() {
        let system = AvailableCodeSystem(
            url: "http://loinc.org",
            title: "LOINC",
            version: "2.74"
        )

        XCTAssertEqual(system.url, "http://loinc.org")
        XCTAssertEqual(system.title, "LOINC")
        XCTAssertEqual(system.version, "2.74")
    }

    func testAvailableCodeSystem_IdUsesURL() {
        let system = AvailableCodeSystem(
            url: "http://loinc.org",
            title: "LOINC",
            version: nil
        )

        XCTAssertEqual(system.id, "http://loinc.org")
    }

    func testAvailableCodeSystem_OptionalVersion() {
        let system = AvailableCodeSystem(
            url: "http://loinc.org",
            title: "LOINC",
            version: nil
        )

        XCTAssertNil(system.version)
    }

    // MARK: - ConceptResult Code System Tests

    func testConceptResult_SystemNameForSNOMED() {
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

        XCTAssertEqual(result.systemName, "SNOMED CT")
        XCTAssertTrue(result.isSNOMEDCT)
    }

    func testConceptResult_SystemNameForSNOMEDExplicit() {
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "International",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: true,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://snomed.info/sct"
        )

        XCTAssertEqual(result.systemName, "SNOMED CT")
        XCTAssertTrue(result.isSNOMEDCT)
    }

    func testConceptResult_SystemNameForLOINC() {
        let result = ConceptResult(
            conceptId: "8867-4",
            branch: "",
            fsn: nil,
            pt: "Heart rate",
            active: nil,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://loinc.org"
        )

        XCTAssertEqual(result.systemName, "LOINC")
        XCTAssertFalse(result.isSNOMEDCT)
    }

    func testConceptResult_SystemNameForRxNorm() {
        let result = ConceptResult(
            conceptId: "1049502",
            branch: "",
            fsn: nil,
            pt: "Aspirin 81 MG Oral Tablet",
            active: nil,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://www.nlm.nih.gov/research/umls/rxnorm"
        )

        XCTAssertEqual(result.systemName, "RxNorm")
        XCTAssertFalse(result.isSNOMEDCT)
    }

    func testConceptResult_SystemNameForICD10CM() {
        let result = ConceptResult(
            conceptId: "J45.901",
            branch: "",
            fsn: nil,
            pt: "Unspecified asthma, uncomplicated",
            active: nil,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://hl7.org/fhir/sid/icd-10-cm"
        )

        XCTAssertEqual(result.systemName, "ICD-10-CM")
        XCTAssertFalse(result.isSNOMEDCT)
    }

    func testConceptResult_SystemNameForUnknown() {
        let result = ConceptResult(
            conceptId: "12345",
            branch: "",
            fsn: nil,
            pt: "Test",
            active: nil,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://example.org/custom-system"
        )

        XCTAssertEqual(result.systemName, "custom-system")
        XCTAssertFalse(result.isSNOMEDCT)
    }

    // MARK: - ConceptResult Initialization Tests

    // MARK: - URI Validation Security Tests

    /// Verifies valid HTTP URI passes validation.
    func testIsValidCodeSystemURI_validHTTP() {
        XCTAssertTrue(CodeSystemSettings.isValidCodeSystemURI("http://loinc.org"))
    }

    /// Verifies valid HTTPS URI passes validation.
    func testIsValidCodeSystemURI_validHTTPS() {
        XCTAssertTrue(CodeSystemSettings.isValidCodeSystemURI("https://snomed.info/sct"))
    }

    /// Verifies URI with query params is rejected.
    func testIsValidCodeSystemURI_withQuery_rejected() {
        XCTAssertFalse(CodeSystemSettings.isValidCodeSystemURI("http://loinc.org?token=abc"))
    }

    /// Verifies URI with fragment is rejected.
    func testIsValidCodeSystemURI_withFragment_rejected() {
        XCTAssertFalse(CodeSystemSettings.isValidCodeSystemURI("http://loinc.org#section"))
    }

    /// Verifies non-http scheme is rejected.
    func testIsValidCodeSystemURI_ftpScheme_rejected() {
        XCTAssertFalse(CodeSystemSettings.isValidCodeSystemURI("ftp://loinc.org"))
    }

    /// Verifies empty string is rejected.
    func testIsValidCodeSystemURI_empty_rejected() {
        XCTAssertFalse(CodeSystemSettings.isValidCodeSystemURI(""))
    }

    /// Verifies bare path is rejected.
    func testIsValidCodeSystemURI_noScheme_rejected() {
        XCTAssertFalse(CodeSystemSettings.isValidCodeSystemURI("loinc.org"))
    }

    func testConceptResult_DefaultSystemIsNil() {
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "International",
            fsn: "Test",
            pt: "Test",
            active: true,
            effectiveTime: nil,
            moduleId: nil
        )

        XCTAssertNil(result.system)
        XCTAssertTrue(result.isSNOMEDCT)
    }
}
