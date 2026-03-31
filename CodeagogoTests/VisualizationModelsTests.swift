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

/// Tests for PropertyValue.displayString and VisualizationData computed properties.
final class VisualizationModelsTests: XCTestCase {

    // MARK: - PropertyValue.displayString Tests

    func testPropertyValue_stringDisplayString() {
        let value = PropertyValue.string("Diabetes mellitus")
        XCTAssertEqual(value.displayString, "Diabetes mellitus")
    }

    func testPropertyValue_booleanDisplayString() {
        XCTAssertEqual(PropertyValue.boolean(true).displayString, "true")
        XCTAssertEqual(PropertyValue.boolean(false).displayString, "false")
    }

    func testPropertyValue_codeDisplayString() {
        let value = PropertyValue.code("900000000000207008")
        XCTAssertEqual(value.displayString, "900000000000207008")
    }

    func testPropertyValue_codingDisplayString_withDisplay() {
        let coding = FHIRParameters.Coding(system: "http://snomed.info/sct", code: "73211009", display: "Diabetes mellitus")
        let value = PropertyValue.coding(coding)
        XCTAssertEqual(value.displayString, "Diabetes mellitus")
    }

    func testPropertyValue_codingDisplayString_fallsBackToCode() {
        let coding = FHIRParameters.Coding(system: "http://snomed.info/sct", code: "73211009", display: nil)
        let value = PropertyValue.coding(coding)
        XCTAssertEqual(value.displayString, "73211009")
    }

    func testPropertyValue_codingDisplayString_unknownFallback() {
        let coding = FHIRParameters.Coding(system: nil, code: nil, display: nil)
        let value = PropertyValue.coding(coding)
        XCTAssertEqual(value.displayString, "Unknown")
    }

    func testPropertyValue_integerDisplayString() {
        let value = PropertyValue.integer(42)
        XCTAssertEqual(value.displayString, "42")
    }

    // MARK: - VisualizationData Tests

    private func makeSNOMEDData() -> VisualizationData {
        let concept = ConceptResult(
            conceptId: "73211009",
            branch: "International (20240101)",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: true,
            effectiveTime: "20020131",
            moduleId: "900000000000207008",
            system: "http://snomed.info/sct"
        )
        return VisualizationData(
            concept: concept,
            properties: [],
            definitionStatusMap: ["73211009": true, "64572001": false],
            displayNameMap: ["73211009": "Diabetes mellitus", "64572001": "Disease"]
        )
    }

    private func makeLOINCData() -> VisualizationData {
        let concept = ConceptResult(
            conceptId: "8867-4",
            branch: "LOINC (2.81)",
            fsn: nil,
            pt: "Heart rate",
            active: true,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://loinc.org"
        )
        return VisualizationData(
            concept: concept,
            properties: [],
            definitionStatusMap: [:],
            displayNameMap: [:]
        )
    }

    func testVisualizationData_isSNOMEDCT() {
        XCTAssertTrue(makeSNOMEDData().isSNOMEDCT)
        XCTAssertFalse(makeLOINCData().isSNOMEDCT)
    }

    func testVisualizationData_isDefinedConcept() {
        let data = makeSNOMEDData()
        XCTAssertEqual(data.isDefinedConcept("73211009"), true)
        XCTAssertEqual(data.isDefinedConcept("64572001"), false)
        XCTAssertNil(data.isDefinedConcept("999999"))
    }

    func testVisualizationData_displayName() {
        let data = makeSNOMEDData()
        XCTAssertEqual(data.displayName(for: "73211009"), "Diabetes mellitus")
        XCTAssertEqual(data.displayName(for: "64572001"), "Disease")
    }

    func testVisualizationData_displayName_nil() {
        let data = makeSNOMEDData()
        XCTAssertNil(data.displayName(for: "999999"))
    }
}
