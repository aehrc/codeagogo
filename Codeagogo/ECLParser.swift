import Foundation

/// Parser for SNOMED CT Expression Constraint Language (ECL).
///
/// Converts a sequence of tokens into an Abstract Syntax Tree (AST).
/// Implements a recursive descent parser following the ECL 2.x grammar.
struct ECLParser {
    private var tokens: [ECLToken]
    private var current: Int = 0

    /// Creates a parser for the given tokens.
    init(tokens: [ECLToken]) {
        // Filter out whitespace and comments for parsing
        self.tokens = tokens.filter { !$0.isTrivia }
    }

    /// Parses the tokens and returns an ECL expression.
    ///
    /// - Returns: The parsed ECL expression
    /// - Throws: `ECLError.parserError` if the input is invalid
    mutating func parse() throws -> ECLExpression {
        let expr = try parseExpression()

        if !isAtEnd {
            throw ECLError.parserError("Unexpected token '\(peek().text)' after expression")
        }

        return expr
    }

    // MARK: - Token Access

    private var isAtEnd: Bool {
        peek().type == .eof
    }

    private func peek(offset: Int = 0) -> ECLToken {
        let index = current + offset
        guard index < tokens.count else {
            return tokens.last ?? ECLToken(type: .eof, text: "", start: "".startIndex, end: "".endIndex)
        }
        return tokens[index]
    }

    @discardableResult
    private mutating func advance() -> ECLToken {
        if !isAtEnd {
            current += 1
        }
        return tokens[current - 1]
    }

    private func check(_ type: ECLTokenType) -> Bool {
        if isAtEnd { return false }
        return tokenTypeMatches(peek().type, type)
    }

    private mutating func match(_ types: ECLTokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }

    private mutating func consume(_ type: ECLTokenType, message: String) throws -> ECLToken {
        if check(type) { return advance() }
        throw ECLError.parserError("\(message), got '\(peek().text)'")
    }

    /// Checks if two token types match, handling associated values.
    private func tokenTypeMatches(_ a: ECLTokenType, _ b: ECLTokenType) -> Bool {
        switch (a, b) {
        case (.sctId, .sctId), (.termString, .termString),
             (.stringLiteral, .stringLiteral), (.integer, .integer),
             (.identifier, .identifier), (.whitespace, .whitespace),
             (.comment, .comment):
            return true
        default:
            return a == b
        }
    }

    // MARK: - Expression Parsing

    /// expressionConstraint = compoundExpression | refinedExpression | subExpression
    private mutating func parseExpression() throws -> ECLExpression {
        return try parseCompoundExpression()
    }

    /// compoundExpression = subExpression (("AND" | "OR" | "MINUS") subExpression)*
    private mutating func parseCompoundExpression() throws -> ECLExpression {
        var left = try parseRefinedOrSubExpression()

        while true {
            let op: CompoundExpression.Operator?
            if match(.and) {
                op = .and
            } else if match(.or) {
                op = .or
            } else if match(.minus) {
                op = .minus
            } else {
                op = nil
            }

            guard let compoundOp = op else { break }

            let right = try parseRefinedOrSubExpression()
            left = .compound(CompoundExpression(left: left, op: compoundOp, right: right))
        }

        return left
    }

    /// refinedExpression = subExpression ":" refinement
    private mutating func parseRefinedOrSubExpression() throws -> ECLExpression {
        let subExpr = try parseSubExpression()

        if match(.colon) {
            let refinement = try parseRefinement()
            return .refined(RefinedExpression(expression: subExpr, refinement: refinement))
        }

        return .subExpression(subExpr)
    }

    /// subExpression = [constraintOperator] focusConcept [filter]*
    private mutating func parseSubExpression() throws -> SubExpression {
        let constraintOp = parseConstraintOperator()
        let focus = try parseFocusConcept()
        let filters = try parseFilters()

        return SubExpression(constraintOp: constraintOp, focusConcept: focus, filters: filters)
    }

    /// constraintOperator = "<" | "<<" | "<!" | "<<!" | ">" | ">>" | ">!" | ">>!" | "^"
    private mutating func parseConstraintOperator() -> ConstraintOperator? {
        if match(.descendantOf) { return .descendantOf }
        if match(.descendantOrSelfOf) { return .descendantOrSelfOf }
        if match(.childOf) { return .childOf }
        if match(.childOrSelfOf) { return .childOrSelfOf }
        if match(.ancestorOf) { return .ancestorOf }
        if match(.ancestorOrSelfOf) { return .ancestorOrSelfOf }
        if match(.parentOf) { return .parentOf }
        if match(.parentOrSelfOf) { return .parentOrSelfOf }
        if match(.memberOf) { return .memberOf }
        return nil
    }

    /// focusConcept = conceptReference | wildcard | "(" expression ")"
    private mutating func parseFocusConcept() throws -> FocusConcept {
        if match(.wildcard) {
            return .wildcard
        }

        if match(.leftParen) {
            let expr = try parseExpression()
            _ = try consume(.rightParen, message: "Expected ')' after expression")
            return .nested(expr)
        }

        // Check for SCTID
        if case .sctId = peek().type {
            let concept = try parseConceptReference()
            return .concept(concept)
        }

        throw ECLError.parserError("Expected concept reference, wildcard, or nested expression, got '\(peek().text)'")
    }

    /// conceptReference = sctId ["|" term "|"]
    private mutating func parseConceptReference() throws -> ConceptReference {
        guard case .sctId(let id) = peek().type else {
            throw ECLError.parserError("Expected SCTID, got '\(peek().text)'")
        }
        advance()

        var term: String?
        if case .termString(let t) = peek().type {
            term = t
            advance()
        }

        return ConceptReference(sctId: id, term: term)
    }

    // MARK: - Refinement Parsing

    /// refinement = refinementItem (("," | "AND" | "OR") refinementItem)*
    private mutating func parseRefinement() throws -> Refinement {
        var items: [RefinementItem] = []
        items.append(try parseRefinementItem())

        while match(.comma) || check(.and) || check(.or) {
            if match(.and) || match(.or) {
                // Handle conjunction/disjunction
            }
            items.append(try parseRefinementItem())
        }

        return Refinement(items: items)
    }

    /// refinementItem = attribute | attributeGroup | "(" refinement ")"
    private mutating func parseRefinementItem() throws -> RefinementItem {
        if match(.leftBrace) {
            let group = try parseAttributeGroup()
            return .attributeGroup(group)
        }

        return .attribute(try parseAttribute())
    }

    /// attribute = [cardinality] ["R"] attributeName comparator attributeValue
    private mutating func parseAttribute() throws -> Attribute {
        let cardinality = try parseCardinality()
        let isReverse = match(.reverse)
        let name = try parseAttributeName()
        let comparator = try parseComparator()
        let value = try parseAttributeValue()

        return Attribute(
            cardinality: cardinality,
            isReverse: isReverse,
            name: name,
            comparator: comparator,
            value: value
        )
    }

    /// cardinality = "[" min ".." max "]"
    private mutating func parseCardinality() throws -> Cardinality? {
        guard match(.leftBracket) else { return nil }

        guard case .integer(let min) = peek().type else {
            throw ECLError.parserError("Expected integer in cardinality, got '\(peek().text)'")
        }
        advance()

        _ = try consume(.range, message: "Expected '..' in cardinality")

        var max: Int?
        if match(.wildcard) {
            max = nil
        } else if case .integer(let m) = peek().type {
            max = m
            advance()
        } else {
            throw ECLError.parserError("Expected integer or '*' in cardinality, got '\(peek().text)'")
        }

        _ = try consume(.rightBracket, message: "Expected ']' after cardinality")

        return Cardinality(min: min, max: max)
    }

    /// attributeName = conceptReference | wildcard | "(" expression ")"
    private mutating func parseAttributeName() throws -> AttributeName {
        if match(.wildcard) {
            return .wildcard
        }

        if match(.leftParen) {
            let expr = try parseExpression()
            _ = try consume(.rightParen, message: "Expected ')' after attribute name expression")
            return .nested(expr)
        }

        let concept = try parseConceptReference()
        return .concept(concept)
    }

    /// comparator = "=" | "!=" | "<" | "<=" | ">" | ">="
    private mutating func parseComparator() throws -> Comparator {
        if match(.equals) { return .equals }
        if match(.notEquals) { return .notEquals }
        if match(.lessThanOrEquals) { return .lessThanOrEquals }
        if match(.greaterThanOrEquals) { return .greaterThanOrEquals }
        if match(.descendantOf) { return .lessThan }
        if match(.ancestorOf) { return .greaterThan }

        throw ECLError.parserError("Expected comparator, got '\(peek().text)'")
    }

    /// attributeValue = expression | conceptReference | wildcard | string | number | boolean
    private mutating func parseAttributeValue() throws -> AttributeValue {
        if match(.wildcard) {
            return .wildcard
        }

        if match(.leftParen) {
            let expr = try parseExpression()
            _ = try consume(.rightParen, message: "Expected ')' after attribute value expression")
            return .nested(expr)
        }

        if case .stringLiteral(let s) = peek().type {
            advance()
            return .stringValue(s)
        }

        if case .integer(let i) = peek().type {
            advance()
            return .integerValue(i)
        }

        if match(.trueKeyword) {
            return .booleanValue(true)
        }

        if match(.falseKeyword) {
            return .booleanValue(false)
        }

        // Try to parse as a sub-expression (with optional constraint operator)
        let constraintOp = parseConstraintOperator()

        if case .sctId = peek().type {
            if constraintOp != nil {
                // This is a sub-expression
                let concept = try parseConceptReference()
                let subExpr = SubExpression(constraintOp: constraintOp, focusConcept: .concept(concept), filters: [])
                return .expression(.subExpression(subExpr))
            } else {
                let concept = try parseConceptReference()
                return .concept(concept)
            }
        }

        throw ECLError.parserError("Expected attribute value, got '\(peek().text)'")
    }

    /// attributeGroup = "{" attribute ("," attribute)* "}"
    private mutating func parseAttributeGroup() throws -> AttributeGroup {
        var items: [RefinementItem] = []
        items.append(try parseRefinementItem())

        while match(.comma) {
            items.append(try parseRefinementItem())
        }

        _ = try consume(.rightBrace, message: "Expected '}' after attribute group")

        return AttributeGroup(attributes: items)
    }

    // MARK: - Filter Parsing

    /// filter = "{{" filterConstraint ("," filterConstraint)* "}}"
    private mutating func parseFilters() throws -> [Filter] {
        var filters: [Filter] = []

        while match(.leftDoubleBrace) {
            var constraints: [FilterConstraint] = []
            constraints.append(try parseFilterConstraint())

            while match(.comma) {
                constraints.append(try parseFilterConstraint())
            }

            _ = try consume(.rightDoubleBrace, message: "Expected '}}' after filter")
            filters.append(Filter(constraints: constraints))
        }

        return filters
    }

    /// filterConstraint = termFilter | languageFilter | typeFilter | dialectFilter | ...
    private mutating func parseFilterConstraint() throws -> FilterConstraint {
        if match(.termKeyword) {
            _ = try consume(.equals, message: "Expected '=' after 'term'")
            return .term(try parseTermFilter())
        }

        if match(.languageKeyword) {
            _ = try consume(.equals, message: "Expected '=' after 'language'")
            if case .identifier(let lang) = peek().type {
                advance()
                return .language(lang)
            }
            throw ECLError.parserError("Expected language code")
        }

        if match(.typeKeyword) {
            _ = try consume(.equals, message: "Expected '=' after 'type'")
            if case .identifier(let t) = peek().type {
                advance()
                return .type(t)
            }
            throw ECLError.parserError("Expected type identifier")
        }

        if match(.dialectKeyword) {
            _ = try consume(.equals, message: "Expected '=' after 'dialect'")
            if case .identifier(let d) = peek().type {
                advance()
                return .dialect(d)
            }
            throw ECLError.parserError("Expected dialect identifier")
        }

        if match(.activeKeyword) {
            _ = try consume(.equals, message: "Expected '=' after 'active'")
            if match(.trueKeyword) {
                return .active(true)
            }
            if match(.falseKeyword) {
                return .active(false)
            }
            throw ECLError.parserError("Expected true or false after 'active ='")
        }

        throw ECLError.parserError("Unknown filter type '\(peek().text)'")
    }

    /// termFilter = [("match" | "wild") ":"] stringLiteral
    private mutating func parseTermFilter() throws -> TermFilter {
        var matchType: TermFilter.MatchType = .exact

        if match(.matchKeyword) {
            _ = try consume(.colon, message: "Expected ':' after 'match'")
            matchType = .match
        } else if match(.wildKeyword) {
            _ = try consume(.colon, message: "Expected ':' after 'wild'")
            matchType = .wild
        }

        guard case .stringLiteral(let value) = peek().type else {
            throw ECLError.parserError("Expected string literal in term filter, got '\(peek().text)'")
        }
        advance()

        return TermFilter(matchType: matchType, value: value)
    }
}
