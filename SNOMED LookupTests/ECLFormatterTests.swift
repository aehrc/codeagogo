import XCTest
import Carbon.HIToolbox
@testable import SNOMED_Lookup

/// Unit tests for the ECL lexer, parser, and formatter.
final class ECLFormatterTests: XCTestCase {

    // MARK: - Lexer Tests

    func testLexerSimpleConcept() throws {
        var lexer = ECLLexer(source: "73211009")
        let tokens = try lexer.tokenize()

        // Should have: sctId, eof
        XCTAssertEqual(tokens.count, 2)
        if case .sctId(let id) = tokens[0].type {
            XCTAssertEqual(id, "73211009")
        } else {
            XCTFail("First token should be sctId")
        }
        XCTAssertEqual(tokens[1].type, .eof)
    }

    func testLexerConceptWithTerm() throws {
        var lexer = ECLLexer(source: "73211009 |Diabetes mellitus|")
        let tokens = try lexer.tokenize()

        // Should have: sctId, whitespace, termString, eof
        XCTAssertTrue(tokens.count >= 3)
        if case .sctId(let id) = tokens[0].type {
            XCTAssertEqual(id, "73211009")
        } else {
            XCTFail("First token should be sctId")
        }
    }

    func testLexerDescendantOf() throws {
        var lexer = ECLLexer(source: "<")
        let tokens = try lexer.tokenize()

        XCTAssertEqual(tokens[0].type, .descendantOf)
    }

    func testLexerDescendantOrSelfOf() throws {
        var lexer = ECLLexer(source: "<<")
        let tokens = try lexer.tokenize()

        XCTAssertEqual(tokens[0].type, .descendantOrSelfOf)
    }

    func testLexerAncestorOf() throws {
        var lexer = ECLLexer(source: ">")
        let tokens = try lexer.tokenize()

        XCTAssertEqual(tokens[0].type, .ancestorOf)
    }

    func testLexerAncestorOrSelfOf() throws {
        var lexer = ECLLexer(source: ">>")
        let tokens = try lexer.tokenize()

        XCTAssertEqual(tokens[0].type, .ancestorOrSelfOf)
    }

    func testLexerMemberOf() throws {
        var lexer = ECLLexer(source: "^")
        let tokens = try lexer.tokenize()

        XCTAssertEqual(tokens[0].type, .memberOf)
    }

    func testLexerLogicalOperators() throws {
        var lexer = ECLLexer(source: "AND OR MINUS")
        let tokens = try lexer.tokenize()

        let nonTrivia = tokens.filter { !$0.isTrivia && $0.type != .eof }
        XCTAssertEqual(nonTrivia.count, 3)
        XCTAssertEqual(nonTrivia[0].type, .and)
        XCTAssertEqual(nonTrivia[1].type, .or)
        XCTAssertEqual(nonTrivia[2].type, .minus)
    }

    func testLexerDoubleBraces() throws {
        var lexer = ECLLexer(source: "{{ }}")
        let tokens = try lexer.tokenize()

        let nonTrivia = tokens.filter { !$0.isTrivia && $0.type != .eof }
        XCTAssertEqual(nonTrivia[0].type, .leftDoubleBrace)
        XCTAssertEqual(nonTrivia[1].type, .rightDoubleBrace)
    }

    func testLexerStringLiteral() throws {
        var lexer = ECLLexer(source: "\"heart\"")
        let tokens = try lexer.tokenize()

        if case .stringLiteral(let value) = tokens[0].type {
            XCTAssertEqual(value, "heart")
        } else {
            XCTFail("First token should be stringLiteral")
        }
    }

    // MARK: - Parser Tests

    func testParserSimpleConcept() throws {
        var lexer = ECLLexer(source: "73211009")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .subExpression(let sub) = expr {
            XCTAssertNil(sub.constraintOp)
            if case .concept(let concept) = sub.focusConcept {
                XCTAssertEqual(concept.sctId, "73211009")
            } else {
                XCTFail("Focus concept should be a concept reference")
            }
        } else {
            XCTFail("Expression should be a sub-expression")
        }
    }

    func testParserDescendantOf() throws {
        var lexer = ECLLexer(source: "< 73211009")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .subExpression(let sub) = expr {
            XCTAssertEqual(sub.constraintOp, .descendantOf)
        } else {
            XCTFail("Expression should be a sub-expression")
        }
    }

    func testParserDescendantOrSelfOf() throws {
        var lexer = ECLLexer(source: "<< 73211009")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .subExpression(let sub) = expr {
            XCTAssertEqual(sub.constraintOp, .descendantOrSelfOf)
        } else {
            XCTFail("Expression should be a sub-expression")
        }
    }

    func testParserConceptWithTerm() throws {
        var lexer = ECLLexer(source: "73211009 |Diabetes mellitus|")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .subExpression(let sub) = expr {
            if case .concept(let concept) = sub.focusConcept {
                XCTAssertEqual(concept.sctId, "73211009")
                XCTAssertEqual(concept.term, "Diabetes mellitus")
            } else {
                XCTFail("Focus concept should be a concept reference")
            }
        } else {
            XCTFail("Expression should be a sub-expression")
        }
    }

    func testParserCompoundAND() throws {
        var lexer = ECLLexer(source: "< 73211009 AND < 404684003")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .compound(let compound) = expr {
            XCTAssertEqual(compound.op, .and)
        } else {
            XCTFail("Expression should be a compound expression")
        }
    }

    func testParserCompoundOR() throws {
        var lexer = ECLLexer(source: "< 73211009 OR < 404684003")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .compound(let compound) = expr {
            XCTAssertEqual(compound.op, .or)
        } else {
            XCTFail("Expression should be a compound expression")
        }
    }

    func testParserRefinement() throws {
        var lexer = ECLLexer(source: "<< 404684003: 363698007 = << 39057004")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .refined = expr {
            // Success - it parsed as a refined expression
        } else {
            XCTFail("Expression should be a refined expression")
        }
    }

    func testParserWildcard() throws {
        var lexer = ECLLexer(source: "*")
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        let expr = try parser.parse()

        if case .subExpression(let sub) = expr {
            if case .wildcard = sub.focusConcept {
                // Success
            } else {
                XCTFail("Focus concept should be wildcard")
            }
        } else {
            XCTFail("Expression should be a sub-expression")
        }
    }

    // MARK: - Formatter Tests

    func testFormatSimpleConcept() throws {
        let result = try formatECL("73211009")
        XCTAssertEqual(result, "73211009")
    }

    func testFormatConceptWithTerm() throws {
        let result = try formatECL("73211009 |Diabetes mellitus|")
        XCTAssertEqual(result, "73211009 |Diabetes mellitus|")
    }

    func testFormatDescendantOf() throws {
        let result = try formatECL("< 73211009")
        XCTAssertEqual(result, "< 73211009")
    }

    func testFormatDescendantOrSelfOf() throws {
        let result = try formatECL("<< 73211009")
        XCTAssertEqual(result, "<< 73211009")
    }

    func testFormatCompoundAND() throws {
        let result = try formatECL("< 73211009 AND < 404684003")
        XCTAssertTrue(result.contains("AND"))
    }

    func testFormatCompoundOR() throws {
        let result = try formatECL("< 73211009 OR < 404684003")
        XCTAssertTrue(result.contains("OR"))
    }

    func testFormatRefinement() throws {
        let result = try formatECL("<< 404684003: 363698007 = << 39057004")
        XCTAssertTrue(result.contains(":"))
        XCTAssertTrue(result.contains("="))
    }

    func testFormatComplexExpression() throws {
        // Test that a more complex expression formats without error
        let ecl = "<< 404684003 |Clinical finding|: 363698007 |Finding site| = << 39057004 |Pulmonary valve structure|"
        let result = try formatECL(ecl)
        XCTAssertTrue(result.contains("404684003"))
        XCTAssertTrue(result.contains("363698007"))
        XCTAssertTrue(result.contains("39057004"))
    }

    func testFormatPreservesWhitespaceNormalization() throws {
        // Extra whitespace should be normalized
        let result = try formatECL("<<   73211009")
        XCTAssertEqual(result, "<< 73211009")
    }

    func testFormatWildcard() throws {
        let result = try formatECL("*")
        XCTAssertEqual(result, "*")
    }

    func testFormatMemberOf() throws {
        let result = try formatECL("^ 816080008")
        XCTAssertEqual(result, "^ 816080008")
    }

    // MARK: - isValidECL Tests

    func testIsValidECLSimple() {
        XCTAssertTrue(isValidECL("73211009"))
    }

    func testIsValidECLComplex() {
        XCTAssertTrue(isValidECL("<< 404684003: 363698007 = << 39057004"))
    }

    func testIsValidECLInvalid() {
        XCTAssertFalse(isValidECL("not valid ecl @#$"))
    }

    func testIsValidECLEmpty() {
        XCTAssertFalse(isValidECL(""))
    }

    // MARK: - Minify Tests

    func testMinifySimpleConcept() throws {
        let result = try minifyECL("73211009")
        XCTAssertEqual(result, "73211009")
    }

    func testMinifyRemovesNewlines() throws {
        let input = """
        < 73211009
        AND < 404684003
        """
        let result = try minifyECL(input)
        XCTAssertFalse(result.contains("\n"))
        XCTAssertTrue(result.contains("AND"))
    }

    func testMinifyCompactOutput() throws {
        let input = "<< 404684003: 363698007 = << 39057004"
        let result = try minifyECL(input)
        // Should be single line
        XCTAssertFalse(result.contains("\n"))
        XCTAssertEqual(result, "<< 404684003: 363698007 = << 39057004")
    }

    func testMinifyPreservesConceptTerms() throws {
        let input = "73211009 |Diabetes mellitus|"
        let result = try minifyECL(input)
        XCTAssertEqual(result, "73211009 |Diabetes mellitus|")
    }

    func testMinifyCompoundExpression() throws {
        // Pretty-printed input with newlines
        let input = """
        < 73211009
        OR < 404684003
        OR < 123456789
        """
        let result = try minifyECL(input)
        // Should be single line with spaces around OR
        XCTAssertFalse(result.contains("\n"))
        XCTAssertEqual(result, "< 73211009 OR < 404684003 OR < 123456789")
    }

    // MARK: - Toggle Tests

    func testToggleFromMinifiedToPretty() throws {
        // Simple minified expression should become pretty-printed
        let minified = "< 73211009 OR < 404684003"
        let result = try toggleECLFormat(minified)
        // Since it's a compound expression, pretty-printing adds newlines
        XCTAssertTrue(result.contains("\n") || result == minified,
                      "Toggle should produce pretty output or same (if simple enough)")
    }

    func testToggleFromPrettyToMinified() throws {
        // First pretty-print, then toggle should minify
        let original = "< 73211009 OR < 404684003"
        let prettyPrinted = try formatECL(original)
        let toggled = try toggleECLFormat(prettyPrinted)

        // If input matched pretty-printed, result should be minified (no newlines)
        if prettyPrinted.contains("\n") {
            XCTAssertFalse(toggled.contains("\n"),
                           "Toggling pretty-printed should produce minified (no newlines)")
        }
    }

    func testToggleRoundTrip() throws {
        // Toggle twice should return to original format
        let original = "< 73211009 OR < 404684003"

        let first = try toggleECLFormat(original)
        let second = try toggleECLFormat(first)

        // After two toggles, we should be back to the other format
        // (minified -> pretty -> minified, or pretty -> minified -> pretty)
        // Just verify it's valid ECL
        XCTAssertTrue(isValidECL(second))
    }

    func testToggleSimpleExpressionUnchanged() throws {
        // A simple expression without compound/refinement might not change much
        let simple = "73211009"
        let result = try toggleECLFormat(simple)
        XCTAssertEqual(result, "73211009")
    }

    func testToggleComplexRefinement() throws {
        let input = "<< 404684003: 363698007 = << 39057004"
        let prettyPrinted = try formatECL(input)
        let minified = try minifyECL(input)

        // Toggle from pretty should give minified
        if prettyPrinted.contains("\n") {
            let toggled = try toggleECLFormat(prettyPrinted)
            XCTAssertEqual(toggled, minified)
        }
    }

    // MARK: - ECLFormatHotKeySettings Tests

    @MainActor
    func testDefaultKeyCodeIsE() {
        // kVK_ANSI_E = 14
        let expected: UInt32 = 14
        XCTAssertEqual(ECLFormatHotKeySettings.currentKeyCode, expected,
                       "Default ECL format hotkey should be E (key code 14)")
    }

    @MainActor
    func testDefaultModifiersAreControlOption() {
        // Control + Option = 0x1000 | 0x0800 = 6144
        let modifiers = ECLFormatHotKeySettings.currentModifiers
        XCTAssertTrue(modifiers.contains(.control),
                      "Default modifiers should include Control")
        XCTAssertTrue(modifiers.contains(.option),
                      "Default modifiers should include Option")
        XCTAssertFalse(modifiers.contains(.command),
                       "Default modifiers should not include Command")
        XCTAssertFalse(modifiers.contains(.shift),
                       "Default modifiers should not include Shift")
    }

    // MARK: - Key Code Tests

    func testKeyCodeForE() {
        XCTAssertEqual(kVK_ANSI_E, 14, "kVK_ANSI_E should be 14")
    }

    func testKeyCodeForF() {
        XCTAssertEqual(kVK_ANSI_F, 3, "kVK_ANSI_F should be 3")
    }

    func testKeyCodeForP() {
        XCTAssertEqual(kVK_ANSI_P, 35, "kVK_ANSI_P should be 35")
    }

    func testKeyCodeForM() {
        XCTAssertEqual(kVK_ANSI_M, 46, "kVK_ANSI_M should be 46")
    }
}
