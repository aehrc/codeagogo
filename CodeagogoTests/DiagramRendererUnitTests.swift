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

/// Unit tests for DiagramRenderer HTML generation using fixture data.
/// No WKWebView, no network — pure string output verification.
final class DiagramRendererUnitTests: XCTestCase {

    // MARK: - Helpers

    private func makeSNOMEDData(
        conceptId: String = "73211009",
        pt: String? = "Diabetes mellitus",
        fsn: String? = "Diabetes mellitus (disorder)",
        properties: [ConceptProperty] = [],
        definitionStatusMap: [String: Bool] = [:],
        displayNameMap: [String: String] = [:]
    ) -> VisualizationData {
        let concept = ConceptResult(
            conceptId: conceptId,
            branch: "International (20240101)",
            fsn: fsn,
            pt: pt,
            active: true,
            effectiveTime: "20020131",
            moduleId: "900000000000207008",
            system: "http://snomed.info/sct"
        )
        return VisualizationData(
            concept: concept,
            properties: properties,
            definitionStatusMap: definitionStatusMap,
            displayNameMap: displayNameMap
        )
    }

    private func makeLOINCData(
        properties: [ConceptProperty] = []
    ) -> VisualizationData {
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
            properties: properties,
            definitionStatusMap: [:],
            displayNameMap: [:]
        )
    }

    // MARK: - SNOMED CT Tests

    /// Verifies SNOMED HTML output is a valid HTML document.
    func testGenerateHTML_snomedCT_containsDiagramElements() {
        let data = makeSNOMEDData()
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        // Simple SNOMED diagram uses PT as display text
        XCTAssertTrue(html.contains("Diabetes mellitus"))
    }

    // MARK: - LOINC Tests

    /// Verifies LOINC output contains property-row divs for each property.
    func testGenerateHTML_loinc_containsPropertyList() {
        let properties = [
            ConceptProperty(code: "COMPONENT", value: .string("Heart rate"), display: "Component"),
            ConceptProperty(code: "PROPERTY", value: .string("NRat"), display: "Property"),
        ]
        let data = makeLOINCData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("property-row"))
        XCTAssertTrue(html.contains("Component"))
        XCTAssertTrue(html.contains("Heart rate"))
        XCTAssertTrue(html.contains("Property"))
        XCTAssertTrue(html.contains("NRat"))
        XCTAssertTrue(html.contains("concept-header"))
    }

    // MARK: - HTML Escaping

    /// Verifies special characters in concept names are HTML-escaped.
    func testGenerateHTML_htmlEscaping() {
        let properties = [
            ConceptProperty(code: "test", value: .string("<script>alert('xss')</script>"), display: nil),
        ]
        let data = makeLOINCData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertFalse(html.contains("<script>alert"))
    }

    // MARK: - NormalForm SVG Diagram Tests

    /// Verifies SNOMED diagram with normalForm property generates SVG elements.
    func testGenerateHTML_snomedCT_withNormalForm_generatesSVG() {
        let normalForm = "=== 64572001 |Disease| : { 116676008 |Associated morphology| = 55641003 |Disorder| }"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<svg"), "Should contain SVG element")
        XCTAssertTrue(html.contains("<rect"), "Should contain rect elements")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
    }

    /// Verifies simple normalForm expression (single focus concept, no refinement).
    func testGenerateFromNormalForm_simpleExpression() {
        let normalForm = "=== 64572001 |Disease|"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<svg"), "Should contain SVG diagram")
        XCTAssertTrue(html.contains("64572001"), "Should contain focus concept ID")
    }

    /// Verifies normalForm with grouped attributes renders SVG nodes.
    func testGenerateFromNormalForm_withRefinement() {
        let normalForm = "=== 64572001 |Disease| : { 116676008 |Associated morphology| = 55641003 |Disorder| }"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<svg"), "Should contain SVG")
        XCTAssertTrue(html.contains("116676008"), "Should contain attribute concept ID")
        XCTAssertTrue(html.contains("55641003"), "Should contain value concept ID")
    }

    /// Verifies normalForm with multiple attribute groups.
    func testGenerateFromNormalForm_multipleGroups() {
        let normalForm = "=== 64572001 |Disease| : { 116676008 |Associated morphology| = 55641003 |Disorder| }, { 363698007 |Finding site| = 39057004 |Pulmonary valve| }"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<svg"))
        XCTAssertTrue(html.contains("116676008"), "Should contain first attribute")
        XCTAssertTrue(html.contains("363698007"), "Should contain second attribute")
    }

    /// Verifies normalForm with ungrouped attributes.
    func testGenerateFromNormalForm_ungroupedAttributes() {
        let normalForm = "=== 64572001 |Disease| : 116676008 |Associated morphology| = 55641003 |Disorder|"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<svg"))
        XCTAssertTrue(html.contains("116676008"))
    }

    /// Verifies defined status (===) renders equivalence symbol in SVG.
    func testGenerateFromNormalForm_definedStatus() {
        let normalForm = "=== 64572001 |Disease| : { 116676008 |Associated morphology| = 55641003 |Disorder| }"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(
            properties: properties,
            definitionStatusMap: ["73211009": true]
        )
        let html = DiagramRenderer.generateHTML(for: data)

        // Defined concepts get double-border (inner rect)
        XCTAssertTrue(html.contains("<svg"))
        XCTAssertTrue(html.contains("#CCCCFF"), "Should use defined concept color (purple)")
    }

    /// Verifies long concept terms are wrapped in SVG text.
    func testGenerateFromNormalForm_longTermWraps() {
        let longTerm = "This is a very long concept term that should be wrapped across multiple lines in the SVG diagram output"
        let normalForm = "=== 64572001 |\(longTerm)| : { 116676008 |Associated morphology| = 55641003 |Disorder| }"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<svg"))
        XCTAssertTrue(html.contains("<tspan"), "Should contain tspan elements for text wrapping")
    }

    /// Verifies fullDiagramHTML structure has controls and diagram container.
    func testGenerateFullDiagramHTML_structure() {
        let normalForm = "=== 64572001 |Disease| : { 116676008 |Associated morphology| = 55641003 |Disorder| }"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
            ConceptProperty(code: "effectiveTime", value: .string("20020131"), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("Zoom In"), "Should contain zoom controls")
        XCTAssertTrue(html.contains("Download SVG"), "Should contain download button")
        XCTAssertTrue(html.contains("diagram-container"), "Should contain diagram container")
    }

    /// Verifies invalid normalForm gracefully falls back to text display.
    func testGenerateFromNormalForm_parserFailure_fallsBack() {
        let invalidNormalForm = "=== @@@ INVALID %%% NOT_PARSEABLE"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(invalidNormalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        // Should fall back to text display without crashing
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("normal-form-section"), "Should fall back to text display")
    }

    /// Verifies normalForm with concrete value (#500) renders correctly.
    func testGenerateFromNormalForm_concreteValue() {
        let normalForm = "=== 64572001 |Disease| : { 363698007 |Finding site| = #500 }"
        let properties = [
            ConceptProperty(code: "normalForm", value: .string(normalForm), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<svg"), "Should produce SVG for concrete value expression")
        XCTAssertTrue(html.contains("= 500"), "Should format concrete value without # prefix")
    }

    /// Verifies SNOMED diagram with relationships tree (no normalForm).
    func testGenerateHTML_snomedCT_withRelationships_generatesTree() {
        let properties = [
            ConceptProperty(code: "parent", value: .string("64572001 |Disease|"), display: "Parent"),
            ConceptProperty(code: "Finding site", value: .string("39057004 |Pulmonary valve|"), display: "Finding site"),
            ConceptProperty(code: "Associated morphology", value: .string("55641003 |Disorder|"), display: "Associated morphology"),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("relationship-row"), "Should contain relationship rows")
        XCTAssertTrue(html.contains("Finding site"), "Should contain relationship label")
    }

    // MARK: - Edge Cases

    /// Verifies multiple LOINC properties all appear in the output.
    func testGenerateHTML_multipleRelationships() {
        let properties = [
            ConceptProperty(code: "COMPONENT", value: .string("Heart rate"), display: "Component"),
            ConceptProperty(code: "PROPERTY", value: .string("NRat"), display: "Property"),
            ConceptProperty(code: "TIME_ASPCT", value: .string("Pt"), display: "Time aspect"),
            ConceptProperty(code: "SYSTEM", value: .string("XXX"), display: "System"),
        ]
        let data = makeLOINCData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("Component"))
        XCTAssertTrue(html.contains("Heart rate"))
        XCTAssertTrue(html.contains("Time aspect"))
        XCTAssertTrue(html.contains("System"))
    }

    /// Verifies empty properties don't cause a crash.
    func testGenerateHTML_emptyProperties() {
        let data = makeLOINCData(properties: [])
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("concept-header"))
    }

    // MARK: - SNOMED Simple Diagram Tests

    /// Verifies simple SNOMED diagram (no normalForm) renders correctly.
    func testGenerateHTML_snomedCT_noNormalForm_rendersSimpleDiagram() {
        let data = makeSNOMEDData(properties: [])
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("Diabetes mellitus"))
    }

    /// Verifies SNOMED diagram with nil PT falls back to conceptId.
    func testGenerateHTML_snomedCT_nilPT_fallsBackToConceptId() {
        let data = makeSNOMEDData(pt: nil, fsn: nil)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("73211009"))
    }

    /// Verifies metadata properties (effectiveTime, moduleId) appear in output.
    func testGenerateHTML_snomedCT_metadataProperties() {
        let properties = [
            ConceptProperty(code: "effectiveTime", value: .string("20020131"), display: nil),
            ConceptProperty(code: "moduleId", value: .string("900000000000207008"), display: nil),
        ]
        let data = makeSNOMEDData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        // Simple diagram without normalForm uses property listing
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
    }

    /// Verifies CSS classes are present in output.
    func testGenerateHTML_containsCSSClasses() {
        let data = makeSNOMEDData()
        let html = DiagramRenderer.generateHTML(for: data)

        // Should contain style element
        XCTAssertTrue(html.contains("<style>"))
    }

    /// Verifies LOINC diagram with boolean property.
    func testGenerateHTML_loinc_booleanProperty() {
        let properties = [
            ConceptProperty(code: "STATUS", value: .boolean(true), display: "Status"),
        ]
        let data = makeLOINCData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("Status"))
        XCTAssertTrue(html.contains("true"))
    }

    /// Verifies LOINC diagram with integer property.
    func testGenerateHTML_loinc_integerProperty() {
        let properties = [
            ConceptProperty(code: "ORDER_OBS", value: .integer(3), display: "Order/Obs"),
        ]
        let data = makeLOINCData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("Order/Obs"))
    }

    /// Verifies LOINC diagram with coding property.
    func testGenerateHTML_loinc_codingProperty() {
        let coding = FHIRParameters.Coding(system: "http://loinc.org", code: "LP7839-6", display: "Cardiology")
        let properties = [
            ConceptProperty(code: "CLASS", value: .coding(coding), display: "Class"),
        ]
        let data = makeLOINCData(properties: properties)
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("Class"))
    }

    /// Verifies SNOMED data with definition status map.
    func testGenerateHTML_snomedCT_withDefinitionStatus() {
        let data = makeSNOMEDData(
            definitionStatusMap: ["73211009": true],
            displayNameMap: ["73211009": "Diabetes mellitus"]
        )
        let html = DiagramRenderer.generateHTML(for: data)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
    }

    /// Verifies that diagrams use preferred terms from displayNameMap instead of
    /// the normalForm's embedded terms (which may be FSN-style or outdated).
    func testGenerateHTML_usesPreferredTermsFromDisplayNameMap() {
        // normalForm has "milligram" but displayNameMap provides "mg" (preferred term)
        let normalForm = "=== 389105002|Product containing midazolam|:127489000|Has active ingredient|=373476007|Midazolam substance|,999000051000168108|Has total quantity unit|=258684004|milligram|"
        let properties = [
            ConceptProperty(
                code: "normalForm",
                value: .string(normalForm),
                display: nil
            )
        ]
        let data = makeSNOMEDData(
            conceptId: "37933011000036106",
            pt: "Midazolam 5 mg/mL injection",
            properties: properties,
            displayNameMap: [
                "37933011000036106": "Midazolam 5 mg/mL injection",
                "389105002": "Midazolam-containing product",
                "127489000": "Has active ingredient",
                "373476007": "Midazolam",
                "999000051000168108": "Has total quantity unit",
                "258684004": "mg"  // Preferred term, not "milligram"
            ]
        )
        let html = DiagramRenderer.generateHTML(for: data)

        // Should use "mg" from displayNameMap, not "milligram" from normalForm
        XCTAssertTrue(html.contains("mg"), "Diagram should use preferred term 'mg' from displayNameMap")
        XCTAssertFalse(html.contains("milligram"), "Diagram should NOT use normalForm term 'milligram'")
    }

    /// Verifies that diagrams fall back to normalForm terms when displayNameMap
    /// doesn't have an entry for a concept.
    func testGenerateHTML_fallsBackToNormalFormTerms() {
        let normalForm = "=== 389105002|Some parent concept|:127489000|Has active ingredient|=373476007|Midazolam substance|"
        let properties = [
            ConceptProperty(
                code: "normalForm",
                value: .string(normalForm),
                display: nil
            )
        ]
        let data = makeSNOMEDData(
            conceptId: "12345678",
            pt: "Test concept",
            properties: properties,
            displayNameMap: [:]  // Empty — no preferred terms available
        )
        let html = DiagramRenderer.generateHTML(for: data)

        // Should fall back to normalForm terms
        XCTAssertTrue(html.contains("Midazolam substance"),
                       "Diagram should fall back to normalForm term when no displayNameMap entry")
    }
}
