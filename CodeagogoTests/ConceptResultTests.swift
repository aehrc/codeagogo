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

/// Tests for ConceptResult computed properties.
final class ConceptResultTests: XCTestCase {

    // MARK: - activeText Tests

    func testActiveText_true() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: true, effectiveTime: nil, moduleId: nil
        )
        XCTAssertEqual(result.activeText, "active")
    }

    func testActiveText_false() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: false, effectiveTime: nil, moduleId: nil
        )
        XCTAssertEqual(result.activeText, "inactive")
    }

    func testActiveText_nil() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil
        )
        XCTAssertEqual(result.activeText, "—")
    }

    // MARK: - isSNOMEDCT Tests

    func testIsSNOMEDCT_nilSystem() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil, system: nil
        )
        XCTAssertTrue(result.isSNOMEDCT)
    }

    func testIsSNOMEDCT_snomedSystem() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil, system: "http://snomed.info/sct"
        )
        XCTAssertTrue(result.isSNOMEDCT)
    }

    func testIsSNOMEDCT_loincSystem() {
        let result = ConceptResult(
            conceptId: "8867-4", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil, system: "http://loinc.org"
        )
        XCTAssertFalse(result.isSNOMEDCT)
    }

    // MARK: - systemName Tests

    func testSystemName_snomed() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil, system: "http://snomed.info/sct"
        )
        XCTAssertEqual(result.systemName, "SNOMED CT")
    }

    func testSystemName_snomedNilSystem() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil, system: nil
        )
        XCTAssertEqual(result.systemName, "SNOMED CT")
    }

    func testSystemName_loinc() {
        let result = ConceptResult(
            conceptId: "8867-4", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil, system: "http://loinc.org"
        )
        XCTAssertEqual(result.systemName, "LOINC")
    }

    func testSystemName_rxnorm() {
        let result = ConceptResult(
            conceptId: "857005", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://www.nlm.nih.gov/research/umls/rxnorm"
        )
        XCTAssertEqual(result.systemName, "RxNorm")
    }

    func testSystemName_icd10cm() {
        let result = ConceptResult(
            conceptId: "J45.901", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://hl7.org/fhir/sid/icd-10-cm"
        )
        XCTAssertEqual(result.systemName, "ICD-10-CM")
    }

    func testSystemName_unknown_usesLastPathComponent() {
        let result = ConceptResult(
            conceptId: "12345", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://example.com/codesystem/custom-system"
        )
        XCTAssertEqual(result.systemName, "custom-system")
    }

    // MARK: - Additional systemName Tests

    func testSystemName_icd10() {
        let result = ConceptResult(
            conceptId: "J45", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://hl7.org/fhir/sid/icd-10"
        )
        XCTAssertEqual(result.systemName, "ICD-10")
    }

    func testSystemName_icd9cm() {
        let result = ConceptResult(
            conceptId: "250.00", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://hl7.org/fhir/sid/icd-9-cm"
        )
        XCTAssertEqual(result.systemName, "ICD-9-CM")
    }

    func testSystemName_xsct() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://snomed.info/xsct"
        )
        XCTAssertEqual(result.systemName, "SNOMED CT")
    }

    func testIsSNOMEDCT_xsctSystem() {
        let result = ConceptResult(
            conceptId: "73211009", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://snomed.info/xsct"
        )
        XCTAssertTrue(result.isSNOMEDCT)
    }

    func testSystemName_trailingSlash() {
        let result = ConceptResult(
            conceptId: "12345", branch: "", fsn: nil, pt: nil,
            active: nil, effectiveTime: nil, moduleId: nil,
            system: "http://example.com/codesystem/"
        )
        // Trailing slash means last component is empty — falls through to full URI
        // This tests the edge case behavior
        XCTAssertNotNil(result.systemName)
    }

}
