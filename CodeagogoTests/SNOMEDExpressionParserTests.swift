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

/// Tests for SNOMEDExpressionParser — AST types, ParseError descriptions, and parser grammar.
final class SNOMEDExpressionParserTests: XCTestCase {

    // MARK: - SNOMEDConceptReference Tests

    /// Verifies displayText returns term when present.
    func testConceptReference_displayText_withTerm() {
        let ref = SNOMEDConceptReference(conceptId: "73211009", term: "Diabetes mellitus")
        XCTAssertEqual(ref.displayText, "Diabetes mellitus")
    }

    /// Verifies displayText falls back to conceptId when no term.
    func testConceptReference_displayText_noTerm() {
        let ref = SNOMEDConceptReference(conceptId: "73211009", term: nil)
        XCTAssertEqual(ref.displayText, "73211009")
    }

    /// Verifies conceptId is stored correctly.
    func testConceptReference_conceptId() {
        let ref = SNOMEDConceptReference(conceptId: "385804009", term: "Diabetic care")
        XCTAssertEqual(ref.conceptId, "385804009")
    }

    /// Verifies term can be empty string.
    func testConceptReference_emptyTerm() {
        let ref = SNOMEDConceptReference(conceptId: "73211009", term: "")
        XCTAssertEqual(ref.displayText, "")
    }

    // MARK: - SNOMEDDefinitionStatus Tests

    /// Verifies the two definition status cases exist and are distinct.
    func testDefinitionStatus_cases() {
        let primitive = SNOMEDDefinitionStatus.primitive
        let defined = SNOMEDDefinitionStatus.defined

        // These are distinct enum cases
        switch primitive {
        case .primitive: break
        case .defined: XCTFail("Expected primitive")
        }

        switch defined {
        case .defined: break
        case .primitive: XCTFail("Expected defined")
        }
    }

    // MARK: - SNOMEDExpression Tests

    /// Verifies debugDescription includes key information.
    func testExpression_debugDescription_noRefinement() {
        let expr = SNOMEDExpression(
            definitionStatus: .primitive,
            focusConcepts: [SNOMEDConceptReference(conceptId: "73211009", term: nil)],
            refinement: nil
        )
        let desc = expr.debugDescription

        XCTAssertTrue(desc.contains("Expression"))
        XCTAssertTrue(desc.contains("primitive"))
        XCTAssertTrue(desc.contains("focus: 1"))
        XCTAssertFalse(desc.contains("groups:"))
    }

    /// Verifies debugDescription with refinement includes group/attribute counts.
    func testExpression_debugDescription_withRefinement() {
        let attr = SNOMEDAttribute(
            name: SNOMEDConceptReference(conceptId: "116676008", term: nil),
            value: .conceptReference(SNOMEDConceptReference(conceptId: "49601007", term: nil))
        )
        let refinement = SNOMEDRefinement(
            attributeGroups: [SNOMEDAttributeGroup(attributes: [attr])],
            ungroupedAttributes: [attr]
        )
        let expr = SNOMEDExpression(
            definitionStatus: .defined,
            focusConcepts: [
                SNOMEDConceptReference(conceptId: "73211009", term: nil),
                SNOMEDConceptReference(conceptId: "385804009", term: nil)
            ],
            refinement: refinement
        )
        let desc = expr.debugDescription

        XCTAssertTrue(desc.contains("focus: 2"))
        XCTAssertTrue(desc.contains("groups: 1"))
        XCTAssertTrue(desc.contains("ungrouped: 1"))
    }

    // MARK: - SNOMEDAttributeValue Tests

    /// Verifies conceptReference value case.
    func testAttributeValue_conceptReference() {
        let ref = SNOMEDConceptReference(conceptId: "49601007", term: "Disorder")
        let value = SNOMEDAttributeValue.conceptReference(ref)

        if case .conceptReference(let extracted) = value {
            XCTAssertEqual(extracted.conceptId, "49601007")
        } else {
            XCTFail("Expected conceptReference")
        }
    }

    /// Verifies concreteValue case stores the value.
    func testAttributeValue_concreteValue() {
        let value = SNOMEDAttributeValue.concreteValue("#500")

        if case .concreteValue(let extracted) = value {
            XCTAssertEqual(extracted, "#500")
        } else {
            XCTFail("Expected concreteValue")
        }
    }

    /// Verifies expression value case (nested expression).
    func testAttributeValue_expression() {
        let nested = SNOMEDExpression(
            definitionStatus: .primitive,
            focusConcepts: [SNOMEDConceptReference(conceptId: "49601007", term: nil)],
            refinement: nil
        )
        let value = SNOMEDAttributeValue.expression(nested)

        if case .expression(let extracted) = value {
            XCTAssertEqual(extracted.focusConcepts[0].conceptId, "49601007")
        } else {
            XCTFail("Expected expression")
        }
    }

    // MARK: - SNOMEDRefinement Tests

    /// Verifies refinement stores grouped and ungrouped attributes.
    func testRefinement_structure() {
        let attr = SNOMEDAttribute(
            name: SNOMEDConceptReference(conceptId: "116676008", term: "Associated morphology"),
            value: .conceptReference(SNOMEDConceptReference(conceptId: "49601007", term: "Disorder"))
        )
        let group = SNOMEDAttributeGroup(attributes: [attr, attr])
        let refinement = SNOMEDRefinement(
            attributeGroups: [group],
            ungroupedAttributes: [attr]
        )

        XCTAssertEqual(refinement.attributeGroups.count, 1)
        XCTAssertEqual(refinement.attributeGroups[0].attributes.count, 2)
        XCTAssertEqual(refinement.ungroupedAttributes.count, 1)
    }

    /// Verifies empty refinement.
    func testRefinement_empty() {
        let refinement = SNOMEDRefinement(attributeGroups: [], ungroupedAttributes: [])

        XCTAssertEqual(refinement.attributeGroups.count, 0)
        XCTAssertEqual(refinement.ungroupedAttributes.count, 0)
    }

    // MARK: - SNOMEDAttributeGroup Tests

    /// Verifies attribute group stores attributes correctly.
    func testAttributeGroup_attributes() {
        let attr1 = SNOMEDAttribute(
            name: SNOMEDConceptReference(conceptId: "363698007", term: "Finding site"),
            value: .conceptReference(SNOMEDConceptReference(conceptId: "113331007", term: nil))
        )
        let attr2 = SNOMEDAttribute(
            name: SNOMEDConceptReference(conceptId: "116676008", term: "Associated morphology"),
            value: .concreteValue("#500")
        )
        let group = SNOMEDAttributeGroup(attributes: [attr1, attr2])

        XCTAssertEqual(group.attributes.count, 2)
        XCTAssertEqual(group.attributes[0].name.conceptId, "363698007")
        XCTAssertEqual(group.attributes[1].name.conceptId, "116676008")
    }

    // MARK: - SNOMEDAttribute Tests

    /// Verifies attribute stores name and value.
    func testAttribute_nameAndValue() {
        let attr = SNOMEDAttribute(
            name: SNOMEDConceptReference(conceptId: "363698007", term: "Finding site"),
            value: .conceptReference(SNOMEDConceptReference(conceptId: "113331007", term: "Endocrine system"))
        )

        XCTAssertEqual(attr.name.conceptId, "363698007")
        XCTAssertEqual(attr.name.term, "Finding site")

        if case .conceptReference(let ref) = attr.value {
            XCTAssertEqual(ref.conceptId, "113331007")
            XCTAssertEqual(ref.term, "Endocrine system")
        } else {
            XCTFail("Expected conceptReference")
        }
    }

    // MARK: - ParseError Tests

    /// Verifies all parse error descriptions are meaningful.
    func testParseError_descriptions() {
        let errors: [SNOMEDExpressionParser.ParseError] = [
            .expectedConceptId,
            .expectedClosingPipe,
            .expectedClosingBrace,
            .expectedClosingParen,
            .expectedEquals,
            .unexpectedEnd
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    /// Verifies specific error description text.
    func testParseError_specificDescriptions() {
        XCTAssertEqual(
            SNOMEDExpressionParser.ParseError.expectedConceptId.errorDescription,
            "Expected concept ID"
        )
        XCTAssertEqual(
            SNOMEDExpressionParser.ParseError.expectedClosingPipe.errorDescription,
            "Expected closing |"
        )
        XCTAssertEqual(
            SNOMEDExpressionParser.ParseError.expectedClosingBrace.errorDescription,
            "Expected closing }"
        )
        XCTAssertEqual(
            SNOMEDExpressionParser.ParseError.expectedClosingParen.errorDescription,
            "Expected closing )"
        )
        XCTAssertEqual(
            SNOMEDExpressionParser.ParseError.expectedEquals.errorDescription,
            "Expected ="
        )
        XCTAssertEqual(
            SNOMEDExpressionParser.ParseError.unexpectedEnd.errorDescription,
            "Unexpected end of input"
        )
    }

    /// Verifies ParseError conforms to LocalizedError.
    func testParseError_conformsToLocalizedError() {
        let error: LocalizedError = SNOMEDExpressionParser.ParseError.expectedConceptId
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Parser parse() Tests

    /// Parses a simple concept reference (digits only).
    func testParse_simpleConcept() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009")
        let expr = try parser.parse()

        XCTAssertEqual(expr.focusConcepts.count, 1)
        XCTAssertEqual(expr.focusConcepts[0].conceptId, "73211009")
        XCTAssertNil(expr.focusConcepts[0].term)
        XCTAssertNil(expr.refinement)
        XCTAssertEqual(expr.definitionStatus, .primitive)
    }

    /// Parses a concept with a piped term.
    func testParse_conceptWithTerm() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 |Diabetes mellitus|")
        let expr = try parser.parse()

        XCTAssertEqual(expr.focusConcepts.count, 1)
        XCTAssertEqual(expr.focusConcepts[0].conceptId, "73211009")
        XCTAssertEqual(expr.focusConcepts[0].term, "Diabetes mellitus")
    }

    /// Parses the defined (===) definition status.
    func testParse_definedStatus() throws {
        var parser = try SNOMEDExpressionParser(input: "=== 73211009")
        let expr = try parser.parse()

        XCTAssertEqual(expr.definitionStatus, .defined)
        XCTAssertEqual(expr.focusConcepts[0].conceptId, "73211009")
    }

    /// Parses the primitive (<<<) definition status.
    func testParse_primitiveStatus() throws {
        var parser = try SNOMEDExpressionParser(input: "<<< 73211009")
        let expr = try parser.parse()

        XCTAssertEqual(expr.definitionStatus, .primitive)
    }

    /// Parses multiple focus concepts separated by +.
    func testParse_multipleFocusConcepts() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 + 385804009")
        let expr = try parser.parse()

        XCTAssertEqual(expr.focusConcepts.count, 2)
        XCTAssertEqual(expr.focusConcepts[0].conceptId, "73211009")
        XCTAssertEqual(expr.focusConcepts[1].conceptId, "385804009")
    }

    /// Parses multiple focus concepts with terms.
    func testParse_multipleFocusConceptsWithTerms() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 |Diabetes mellitus| + 385804009 |Diabetic care|")
        let expr = try parser.parse()

        XCTAssertEqual(expr.focusConcepts.count, 2)
        XCTAssertEqual(expr.focusConcepts[0].term, "Diabetes mellitus")
        XCTAssertEqual(expr.focusConcepts[1].term, "Diabetic care")
    }

    /// Parses an ungrouped attribute refinement.
    func testParse_ungroupedAttribute() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 = 49601007")
        let expr = try parser.parse()

        XCTAssertNotNil(expr.refinement)
        XCTAssertEqual(expr.refinement?.ungroupedAttributes.count, 1)
        XCTAssertEqual(expr.refinement?.ungroupedAttributes[0].name.conceptId, "116676008")

        if case .conceptReference(let ref) = expr.refinement?.ungroupedAttributes[0].value {
            XCTAssertEqual(ref.conceptId, "49601007")
        } else {
            XCTFail("Expected conceptReference value")
        }
    }

    /// Parses a grouped attribute refinement.
    func testParse_groupedAttributes() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : { 116676008 = 49601007 }")
        let expr = try parser.parse()

        XCTAssertNotNil(expr.refinement)
        XCTAssertEqual(expr.refinement?.attributeGroups.count, 1)
        XCTAssertEqual(expr.refinement?.attributeGroups[0].attributes.count, 1)
        XCTAssertEqual(expr.refinement?.attributeGroups[0].attributes[0].name.conceptId, "116676008")
    }

    /// Parses multiple groups.
    func testParse_multipleGroups() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : { 116676008 = 49601007 }, { 363698007 = 113331007 }")
        let expr = try parser.parse()

        XCTAssertEqual(expr.refinement?.attributeGroups.count, 2)
    }

    /// Parses mixed ungrouped and grouped attributes.
    func testParse_mixedAttributes() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 = 49601007, { 363698007 = 113331007 }")
        let expr = try parser.parse()

        XCTAssertEqual(expr.refinement?.ungroupedAttributes.count, 1)
        XCTAssertEqual(expr.refinement?.attributeGroups.count, 1)
    }

    /// Parses a concrete integer value.
    func testParse_concreteIntegerValue() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 = #500")
        let expr = try parser.parse()

        if case .concreteValue(let val) = expr.refinement?.ungroupedAttributes[0].value {
            XCTAssertEqual(val, "#500")
        } else {
            XCTFail("Expected concreteValue")
        }
    }

    /// Parses a concrete decimal value.
    func testParse_concreteDecimalValue() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 = #37.5")
        let expr = try parser.parse()

        if case .concreteValue(let val) = expr.refinement?.ungroupedAttributes[0].value {
            XCTAssertEqual(val, "#37.5")
        } else {
            XCTFail("Expected concreteValue")
        }
    }

    /// Parses a concrete string value.
    func testParse_concreteStringValue() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 = #\"some text\"")
        let expr = try parser.parse()

        if case .concreteValue(let val) = expr.refinement?.ungroupedAttributes[0].value {
            XCTAssertTrue(val.contains("some text"))
        } else {
            XCTFail("Expected concreteValue")
        }
    }

    /// Parses a nested expression value.
    func testParse_nestedExpression() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 = (49601007 : 363698007 = 113331007)")
        let expr = try parser.parse()

        if case .expression(let nested) = expr.refinement?.ungroupedAttributes[0].value {
            XCTAssertEqual(nested.focusConcepts[0].conceptId, "49601007")
            XCTAssertNotNil(nested.refinement)
        } else {
            XCTFail("Expected expression value")
        }
    }

    /// Parses with extra whitespace.
    func testParse_extraWhitespace() throws {
        var parser = try SNOMEDExpressionParser(input: "   73211009   :   116676008   =   49601007   ")
        let expr = try parser.parse()

        XCTAssertEqual(expr.focusConcepts[0].conceptId, "73211009")
        XCTAssertNotNil(expr.refinement)
    }

    /// Verifies expectedConceptId error for non-digit input.
    func testParse_error_expectedConceptId() throws {
        var parser = try SNOMEDExpressionParser(input: "abc")
        XCTAssertThrowsError(try parser.parse()) { error in
            XCTAssertTrue(error is SNOMEDExpressionParser.ParseError)
            if let parseError = error as? SNOMEDExpressionParser.ParseError {
                XCTAssertEqual(parseError, .expectedConceptId)
            }
        }
    }

    /// Verifies unclosed pipe throws expectedClosingPipe.
    func testParse_error_unclosedPipe() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 |Diabetes mellitus")
        XCTAssertThrowsError(try parser.parse()) { error in
            if let parseError = error as? SNOMEDExpressionParser.ParseError {
                XCTAssertEqual(parseError, .expectedClosingPipe)
            }
        }
    }

    /// Verifies unclosed brace throws expectedClosingBrace.
    func testParse_error_unclosedBrace() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : { 116676008 = 49601007")
        XCTAssertThrowsError(try parser.parse()) { error in
            if let parseError = error as? SNOMEDExpressionParser.ParseError {
                XCTAssertEqual(parseError, .expectedClosingBrace)
            }
        }
    }

    /// Verifies missing equals throws expectedEquals.
    func testParse_error_missingEquals() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 49601007")
        XCTAssertThrowsError(try parser.parse()) { error in
            if let parseError = error as? SNOMEDExpressionParser.ParseError {
                XCTAssertEqual(parseError, .expectedEquals)
            }
        }
    }

    /// Verifies empty input throws expectedConceptId.
    func testParse_error_emptyInput() throws {
        var parser = try SNOMEDExpressionParser(input: "")
        XCTAssertThrowsError(try parser.parse())
    }

    /// Parses a realistic SNOMED CT normal form expression.
    func testParse_realisticNormalForm() throws {
        let input = "=== 73211009 |Diabetes mellitus| : " +
            "116676008 |Associated morphology| = 49601007 |Disorder of structure|, " +
            "{ 363698007 |Finding site| = 113331007 |Endocrine system| }"
        var parser = try SNOMEDExpressionParser(input: input)
        let expr = try parser.parse()

        XCTAssertEqual(expr.definitionStatus, .defined)
        XCTAssertEqual(expr.focusConcepts.count, 1)
        XCTAssertEqual(expr.focusConcepts[0].conceptId, "73211009")
        XCTAssertEqual(expr.focusConcepts[0].term, "Diabetes mellitus")
        XCTAssertNotNil(expr.refinement)
        XCTAssertEqual(expr.refinement?.ungroupedAttributes.count, 1)
        XCTAssertEqual(expr.refinement?.attributeGroups.count, 1)
    }

    /// Parses a quoted string attribute value (without # prefix).
    func testParse_quotedStringValue() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : 116676008 = \"some value\"")
        let expr = try parser.parse()

        if case .concreteValue(let val) = expr.refinement?.ungroupedAttributes[0].value {
            XCTAssertTrue(val.contains("some value"))
        } else {
            XCTFail("Expected concreteValue")
        }
    }

    /// Parses multiple attributes in a single group.
    func testParse_multipleAttributesInGroup() throws {
        var parser = try SNOMEDExpressionParser(input: "73211009 : { 116676008 = 49601007, 363698007 = 113331007 }")
        let expr = try parser.parse()

        XCTAssertEqual(expr.refinement?.attributeGroups.count, 1)
        XCTAssertEqual(expr.refinement?.attributeGroups[0].attributes.count, 2)
    }

    // MARK: - Security Tests

    /// Verifies init throws inputTooLarge for oversized input.
    func testInit_inputTooLarge_throws() {
        let oversized = String(repeating: "1", count: SNOMEDExpressionParser.maxInputSize + 1)
        XCTAssertThrowsError(try SNOMEDExpressionParser(input: oversized)) { error in
            if let parseError = error as? SNOMEDExpressionParser.ParseError {
                XCTAssertEqual(parseError, .inputTooLarge(SNOMEDExpressionParser.maxInputSize))
            } else {
                XCTFail("Expected ParseError.inputTooLarge, got \(error)")
            }
        }
    }

    /// Verifies init succeeds for input at exactly the size limit.
    func testInit_inputAtLimit_succeeds() throws {
        let atLimit = String(repeating: "1", count: SNOMEDExpressionParser.maxInputSize)
        _ = try SNOMEDExpressionParser(input: atLimit)
    }

    /// Verifies inputTooLarge error has a meaningful description.
    func testParseError_inputTooLarge_description() {
        let error = SNOMEDExpressionParser.ParseError.inputTooLarge(100_000)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("100000"))
    }

    /// Verifies maxDepthExceeded triggers for deeply nested expressions.
    func testParse_maxDepthExceeded_throws() throws {
        // Build a nested attribute value chain that exceeds maxDepth.
        // Each level: conceptId : attrId = (nextLevel)
        // With maxDepth=1, two levels of nesting should exceed it.
        let input = "73211009 : 116676008 = (49601007 : 363698007 = (113331007 : 116676008 = 49601007))"
        var parser = try SNOMEDExpressionParser(input: input, maxDepth: 1)
        XCTAssertThrowsError(try parser.parse()) { error in
            if let parseError = error as? SNOMEDExpressionParser.ParseError {
                XCTAssertEqual(parseError, .maxDepthExceeded(1))
            } else {
                XCTFail("Expected ParseError.maxDepthExceeded, got \(error)")
            }
        }
    }
}
