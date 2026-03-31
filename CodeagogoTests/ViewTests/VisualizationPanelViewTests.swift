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

/// Tests for VisualizationPanelView data models verifying the visualization
/// data properties that drive the view's display logic.
@MainActor
final class VisualizationPanelViewTests: XCTestCase {

    // MARK: - VisualizationData Model Tests

    /// Verifies VisualizationData concept reference.
    func testVisualizationData_conceptReference() {
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
        let data = VisualizationData(
            concept: concept,
            properties: [],
            definitionStatusMap: [:],
            displayNameMap: [:]
        )
        XCTAssertEqual(data.concept.conceptId, "73211009")
        XCTAssertEqual(data.concept.pt, "Diabetes mellitus")
    }

    /// Verifies VisualizationData with properties.
    func testVisualizationData_withProperties() {
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
        let property = ConceptProperty(code: "parent", value: .code("362969004"), display: "Disorder of endocrine system")
        let data = VisualizationData(
            concept: concept,
            properties: [property],
            definitionStatusMap: [:],
            displayNameMap: [:]
        )
        XCTAssertEqual(data.properties.count, 1)
        XCTAssertEqual(data.properties.first?.code, "parent")
    }

    /// Verifies VisualizationData empty properties.
    func testVisualizationData_emptyProperties() {
        let concept = ConceptResult(
            conceptId: "73211009",
            branch: "Test",
            fsn: nil,
            pt: "Test",
            active: true,
            effectiveTime: nil,
            moduleId: nil
        )
        let data = VisualizationData(
            concept: concept,
            properties: [],
            definitionStatusMap: [:],
            displayNameMap: [:]
        )
        XCTAssertTrue(data.properties.isEmpty)
    }

    /// Verifies VisualizationData definition status map.
    func testVisualizationData_definitionStatusMap() {
        let concept = ConceptResult(
            conceptId: "73211009",
            branch: "Test",
            fsn: nil,
            pt: "Test",
            active: true,
            effectiveTime: nil,
            moduleId: nil
        )
        let data = VisualizationData(
            concept: concept,
            properties: [],
            definitionStatusMap: ["73211009": true],
            displayNameMap: [:]
        )
        XCTAssertEqual(data.definitionStatusMap["73211009"], true)
    }
}
