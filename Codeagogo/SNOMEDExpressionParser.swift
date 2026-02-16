import Foundation

// MARK: - AST Nodes

/// Represents a parsed SNOMED CT expression.
struct SNOMEDExpression {
    let definitionStatus: SNOMEDDefinitionStatus
    let focusConcepts: [SNOMEDConceptReference]
    let refinement: SNOMEDRefinement?

    var debugDescription: String {
        var desc = "Expression(status: \(definitionStatus), focus: \(focusConcepts.count)"
        if let ref = refinement {
            desc += ", groups: \(ref.attributeGroups.count), ungrouped: \(ref.ungroupedAttributes.count)"
        }
        desc += ")"
        return desc
    }
}

enum SNOMEDDefinitionStatus {
    case primitive          // Subtype (necessary conditions)
    case defined           // Equivalence (necessary and sufficient)
}

struct SNOMEDConceptReference {
    let conceptId: String
    let term: String?

    var displayText: String {
        term ?? conceptId
    }
}

struct SNOMEDRefinement {
    let attributeGroups: [SNOMEDAttributeGroup]
    let ungroupedAttributes: [SNOMEDAttribute]
}

struct SNOMEDAttributeGroup {
    let attributes: [SNOMEDAttribute]
}

struct SNOMEDAttribute {
    let name: SNOMEDConceptReference
    let value: SNOMEDAttributeValue
}

enum SNOMEDAttributeValue {
    case conceptReference(SNOMEDConceptReference)
    case expression(SNOMEDExpression)
    case concreteValue(String)  // e.g., "#500" or "= 500"
}

// MARK: - Parser

/// Parses SNOMED CT expression syntax according to the compositional grammar.
class SNOMEDExpressionParser {
    private var input: String
    private var position: String.Index

    init(input: String) {
        self.input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = self.input.startIndex
    }

    /// Parses a complete SNOMED CT expression.
    func parse() throws -> SNOMEDExpression {
        skipWhitespace()

        // Check for definition status (=== or <<<)
        let definitionStatus: SNOMEDDefinitionStatus
        if consume("===") {
            definitionStatus = .defined
        } else if consume("<<<") {
            definitionStatus = .primitive
        } else {
            definitionStatus = .primitive  // Default
        }

        skipWhitespace()

        // Parse focus concepts
        let focusConcepts = try parseFocusConcepts()

        skipWhitespace()

        // Parse refinement if present (after ":")
        var refinement: SNOMEDRefinement?
        if consume(":") {
            skipWhitespace()
            refinement = try parseRefinement()
        }

        return SNOMEDExpression(
            definitionStatus: definitionStatus,
            focusConcepts: focusConcepts,
            refinement: refinement
        )
    }

    // MARK: - Parsing Methods

    private func parseFocusConcepts() throws -> [SNOMEDConceptReference] {
        var concepts: [SNOMEDConceptReference] = []
        concepts.append(try parseConceptReference())

        skipWhitespace()
        while consume("+") {
            skipWhitespace()
            concepts.append(try parseConceptReference())
            skipWhitespace()
        }

        return concepts
    }

    private func parseConceptReference() throws -> SNOMEDConceptReference {
        skipWhitespace()

        // Parse concept ID (digits)
        let conceptId = try parseConceptId()

        skipWhitespace()

        // Parse optional term in pipes
        var term: String?
        if peek() == "|" {
            _ = consume("|")
            term = try parseTerm()
            if !consume("|") {
                throw ParseError.expectedClosingPipe
            }
        }

        return SNOMEDConceptReference(conceptId: conceptId, term: term)
    }

    private func parseConceptId() throws -> String {
        var id = ""
        while position < input.endIndex && input[position].isNumber {
            id.append(input[position])
            position = input.index(after: position)
        }

        guard !id.isEmpty else {
            // Add context to error
            let offset = input.distance(from: input.startIndex, to: position)
            let contextStart = input.index(position, offsetBy: -20, limitedBy: input.startIndex) ?? input.startIndex
            let contextEnd = input.index(position, offsetBy: 20, limitedBy: input.endIndex) ?? input.endIndex
            let context = String(input[contextStart..<contextEnd])
            let nextChar = position < input.endIndex ? String(input[position]) : "EOF"
            print("   Parse error at offset \(offset), next char: '\(nextChar)'")
            print("   Context: ...\(context)...")
            throw ParseError.expectedConceptId
        }

        return id
    }

    private func parseTerm() throws -> String {
        var term = ""
        while position < input.endIndex && input[position] != "|" {
            term.append(input[position])
            position = input.index(after: position)
        }
        return term.trimmingCharacters(in: .whitespaces)
    }

    private func parseRefinement() throws -> SNOMEDRefinement {
        var attributeGroups: [SNOMEDAttributeGroup] = []
        var ungroupedAttributes: [SNOMEDAttribute] = []

        skipWhitespace()

        // Keep parsing until we run out of attributes/groups or hit end
        while position < input.endIndex {
            skipWhitespace()

            // Check for end of input
            if position >= input.endIndex {
                break
            }

            if peek() == "{" {
                // Grouped attributes
                _ = consume("{")
                skipWhitespace()
                let attributes = try parseAttributeList()
                skipWhitespace()
                if !consume("}") {
                    throw ParseError.expectedClosingBrace
                }
                attributeGroups.append(SNOMEDAttributeGroup(attributes: attributes))
            } else if isStartOfAttribute() {
                // Ungrouped attribute
                ungroupedAttributes.append(try parseAttribute())
            } else {
                // Unknown character, stop parsing
                break
            }

            skipWhitespace()
            // Optional comma separator between attributes/groups
            _ = consume(",")
        }

        return SNOMEDRefinement(attributeGroups: attributeGroups, ungroupedAttributes: ungroupedAttributes)
    }

    private func parseAttributeList() throws -> [SNOMEDAttribute] {
        var attributes: [SNOMEDAttribute] = []

        skipWhitespace()

        // Handle empty group
        if peek() == "}" {
            return attributes
        }

        attributes.append(try parseAttribute())

        skipWhitespace()
        while consume(",") {
            skipWhitespace()
            // Check for trailing comma before closing brace
            if peek() == "}" {
                break
            }
            attributes.append(try parseAttribute())
            skipWhitespace()
        }

        return attributes
    }

    private func parseAttribute() throws -> SNOMEDAttribute {
        skipWhitespace()
        let name = try parseConceptReference()

        skipWhitespace()
        if !consume("=") {
            throw ParseError.expectedEquals
        }

        skipWhitespace()
        let value = try parseAttributeValue()

        return SNOMEDAttribute(name: name, value: value)
    }

    private func parseAttributeValue() throws -> SNOMEDAttributeValue {
        skipWhitespace()

        guard let char = peek() else {
            throw ParseError.unexpectedEnd
        }

        // Check for concrete value starting with #
        if char == "#" {
            return .concreteValue(try parseConcreteValue())
        }

        // Check for quoted string (concrete string value without # prefix)
        if char == "\"" {
            return .concreteValue(try parseQuotedString())
        }

        // Check for nested expression in parentheses
        if char == "(" {
            _ = consume("(")
            skipWhitespace()
            let expr = try parse()
            skipWhitespace()
            if !consume(")") {
                throw ParseError.expectedClosingParen
            }
            return .expression(expr)
        }

        // Otherwise, must be a concept reference
        return .conceptReference(try parseConceptReference())
    }

    private func parseQuotedString() throws -> String {
        var value = ""

        // Consume opening quote
        guard position < input.endIndex && input[position] == "\"" else {
            throw ParseError.unexpectedEnd
        }
        value.append(input[position])
        position = input.index(after: position)

        // Read until closing quote
        while position < input.endIndex && input[position] != "\"" {
            value.append(input[position])
            position = input.index(after: position)
        }

        // Consume closing quote
        if position < input.endIndex && input[position] == "\"" {
            value.append(input[position])
            position = input.index(after: position)
        } else {
            throw ParseError.unexpectedEnd
        }

        return value
    }

    private func parseConcreteValue() throws -> String {
        var value = ""

        // Consume the # prefix
        if peek() == "#" {
            value.append(input[position])
            position = input.index(after: position)
        }

        // Read the value (number, decimal, or quoted string)
        if peek() == "\"" {
            // Quoted string
            value.append(input[position])
            position = input.index(after: position)
            while position < input.endIndex && input[position] != "\"" {
                value.append(input[position])
                position = input.index(after: position)
            }
            if position < input.endIndex && input[position] == "\"" {
                value.append(input[position])
                position = input.index(after: position)
            }
        } else {
            // Number (integer or decimal)
            while position < input.endIndex {
                let char = input[position]
                if char.isNumber || char == "." || char == "-" {
                    value.append(char)
                    position = input.index(after: position)
                } else {
                    break
                }
            }
        }

        return value.trimmingCharacters(in: .whitespaces)
    }

    private func isStartOfAttribute() -> Bool {
        guard position < input.endIndex else { return false }
        let char = input[position]
        // An attribute starts with a digit (concept ID)
        return char.isNumber
    }

    // MARK: - Helper Methods

    private func peek() -> Character? {
        guard position < input.endIndex else { return nil }
        return input[position]
    }

    private func consume(_ string: String) -> Bool {
        skipWhitespace()

        let endIndex = input.index(position, offsetBy: string.count, limitedBy: input.endIndex) ?? input.endIndex
        let substring = String(input[position..<endIndex])

        if substring == string {
            position = endIndex
            return true
        }

        return false
    }

    private func skipWhitespace() {
        while position < input.endIndex && input[position].isWhitespace {
            position = input.index(after: position)
        }
    }

    // MARK: - Errors

    enum ParseError: Error, LocalizedError {
        case expectedConceptId
        case expectedClosingPipe
        case expectedClosingBrace
        case expectedClosingParen
        case expectedEquals
        case unexpectedEnd

        var errorDescription: String? {
            switch self {
            case .expectedConceptId: return "Expected concept ID"
            case .expectedClosingPipe: return "Expected closing |"
            case .expectedClosingBrace: return "Expected closing }"
            case .expectedClosingParen: return "Expected closing )"
            case .expectedEquals: return "Expected ="
            case .unexpectedEnd: return "Unexpected end of input"
            }
        }
    }
}
