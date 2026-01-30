import Foundation

/// Formatter for SNOMED CT Expression Constraint Language (ECL).
///
/// Converts an ECL AST back to formatted text with proper indentation
/// and line breaks for improved readability.
struct ECLFormatter {
    /// Configuration options for formatting.
    struct Options {
        /// Number of spaces per indent level.
        var indentSize: Int = 2
        /// Maximum line length before breaking.
        var maxLineLength: Int = 80

        static let `default` = Options()
    }

    private let options: Options
    private var output: String = ""
    private var currentIndent: Int = 0
    private var currentColumn: Int = 0

    /// Creates a formatter with the given options.
    init(options: Options = .default) {
        self.options = options
    }

    /// Formats an ECL expression to a pretty-printed string.
    ///
    /// - Parameter expression: The ECL expression to format
    /// - Returns: The formatted ECL string
    mutating func format(_ expression: ECLExpression) -> String {
        output = ""
        currentIndent = 0
        currentColumn = 0

        printExpression(expression)

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Output Helpers

    private mutating func write(_ text: String) {
        output += text
        if let lastNewline = text.lastIndex(of: "\n") {
            currentColumn = text.distance(from: text.index(after: lastNewline), to: text.endIndex)
        } else {
            currentColumn += text.count
        }
    }

    private mutating func newline() {
        output += "\n"
        currentColumn = 0
    }

    private mutating func indent() {
        let spaces = String(repeating: " ", count: currentIndent * options.indentSize)
        write(spaces)
    }

    private mutating func increaseIndent() {
        currentIndent += 1
    }

    private mutating func decreaseIndent() {
        currentIndent = max(0, currentIndent - 1)
    }

    // MARK: - Complexity Detection

    /// Determines if an expression is complex enough to warrant line breaks.
    private func isComplex(_ expression: ECLExpression) -> Bool {
        switch expression {
        case .compound:
            return true
        case .refined:
            return true
        case .subExpression(let sub):
            return !sub.filters.isEmpty || isComplexFocus(sub.focusConcept)
        }
    }

    private func isComplexFocus(_ focus: FocusConcept) -> Bool {
        switch focus {
        case .nested:
            return true
        default:
            return false
        }
    }

    private func isComplexRefinement(_ refinement: Refinement) -> Bool {
        // Multiple items or any attribute groups make it complex
        if refinement.items.count > 1 { return true }
        for item in refinement.items {
            if case .attributeGroup = item { return true }
        }
        return false
    }

    // MARK: - Expression Printing

    private mutating func printExpression(_ expression: ECLExpression) {
        switch expression {
        case .compound(let compound):
            printCompound(compound)
        case .refined(let refined):
            printRefined(refined)
        case .subExpression(let sub):
            printSubExpression(sub)
        }
    }

    private mutating func printCompound(_ compound: CompoundExpression) {
        let shouldBreak = isComplex(compound.left) || isComplex(compound.right)

        // Print left side
        let leftNeedsParens = needsParens(compound.left, inCompound: compound.op)
        if leftNeedsParens {
            write("(")
            if shouldBreak && isComplex(compound.left) {
                newline()
                increaseIndent()
                indent()
            }
        }
        printExpression(compound.left)
        if leftNeedsParens {
            if shouldBreak && isComplex(compound.left) {
                newline()
                decreaseIndent()
                indent()
            }
            write(")")
        }

        // Print operator
        if shouldBreak {
            newline()
            indent()
        } else {
            write(" ")
        }
        write(compound.op.rawValue)
        write(" ")

        // Print right side
        let rightNeedsParens = needsParens(compound.right, inCompound: compound.op)
        if rightNeedsParens {
            write("(")
            if shouldBreak && isComplex(compound.right) {
                newline()
                increaseIndent()
                indent()
            }
        }
        printExpression(compound.right)
        if rightNeedsParens {
            if shouldBreak && isComplex(compound.right) {
                newline()
                decreaseIndent()
                indent()
            }
            write(")")
        }
    }

    private func needsParens(_ expression: ECLExpression, inCompound op: CompoundExpression.Operator) -> Bool {
        guard case .compound(let inner) = expression else { return false }
        // Need parens if inner has different/lower precedence
        // AND > OR > MINUS
        switch (op, inner.op) {
        case (.and, .or), (.and, .minus), (.or, .minus):
            return true
        default:
            return false
        }
    }

    private mutating func printRefined(_ refined: RefinedExpression) {
        printSubExpression(refined.expression)

        let shouldBreak = isComplexRefinement(refined.refinement)

        write(":")
        if shouldBreak {
            newline()
            increaseIndent()
            indent()
        } else {
            write(" ")
        }

        printRefinement(refined.refinement, multiline: shouldBreak)

        if shouldBreak {
            decreaseIndent()
        }
    }

    private mutating func printSubExpression(_ sub: SubExpression) {
        if let op = sub.constraintOp {
            write(op.rawValue)
            write(" ")
        }

        printFocusConcept(sub.focusConcept)

        for filter in sub.filters {
            write(" ")
            printFilter(filter)
        }
    }

    private mutating func printFocusConcept(_ focus: FocusConcept) {
        switch focus {
        case .concept(let concept):
            printConceptReference(concept)
        case .wildcard:
            write("*")
        case .nested(let expr):
            write("(")
            let complex = isComplex(expr)
            if complex {
                newline()
                increaseIndent()
                indent()
            }
            printExpression(expr)
            if complex {
                newline()
                decreaseIndent()
                indent()
            }
            write(")")
        case .memberOf(let inner):
            write("^")
            printFocusConcept(inner)
        }
    }

    private mutating func printConceptReference(_ concept: ConceptReference) {
        write(concept.sctId)
        if let term = concept.term {
            write(" |")
            write(term)
            write("|")
        }
    }

    // MARK: - Refinement Printing

    private mutating func printRefinement(_ refinement: Refinement, multiline: Bool) {
        for (index, item) in refinement.items.enumerated() {
            if index > 0 {
                write(",")
                if multiline {
                    newline()
                    indent()
                } else {
                    write(" ")
                }
            }
            printRefinementItem(item, multiline: multiline)
        }
    }

    private mutating func printRefinementItem(_ item: RefinementItem, multiline: Bool) {
        switch item {
        case .attribute(let attr):
            printAttribute(attr)
        case .attributeGroup(let group):
            printAttributeGroup(group, multiline: multiline)
        case .conjunction(let items):
            for (index, i) in items.enumerated() {
                if index > 0 {
                    write(",")
                    if multiline {
                        newline()
                        indent()
                    } else {
                        write(" ")
                    }
                }
                printRefinementItem(i, multiline: multiline)
            }
        case .disjunction(let items):
            for (index, i) in items.enumerated() {
                if index > 0 {
                    write(" OR ")
                }
                printRefinementItem(i, multiline: multiline)
            }
        }
    }

    private mutating func printAttribute(_ attr: Attribute) {
        if let card = attr.cardinality {
            write(card.text)
            write(" ")
        }

        if attr.isReverse {
            write("R ")
        }

        printAttributeName(attr.name)
        write(" ")
        write(attr.comparator.rawValue)
        write(" ")
        printAttributeValue(attr.value)
    }

    private mutating func printAttributeName(_ name: AttributeName) {
        switch name {
        case .concept(let concept):
            printConceptReference(concept)
        case .wildcard:
            write("*")
        case .nested(let expr):
            write("(")
            printExpression(expr)
            write(")")
        }
    }

    private mutating func printAttributeValue(_ value: AttributeValue) {
        switch value {
        case .expression(let expr):
            printExpression(expr)
        case .concept(let concept):
            printConceptReference(concept)
        case .wildcard:
            write("*")
        case .nested(let expr):
            write("(")
            printExpression(expr)
            write(")")
        case .stringValue(let s):
            write("\"")
            write(s)
            write("\"")
        case .integerValue(let i):
            write(String(i))
        case .booleanValue(let b):
            write(b ? "true" : "false")
        }
    }

    private mutating func printAttributeGroup(_ group: AttributeGroup, multiline: Bool) {
        write("{")
        if multiline && group.attributes.count > 1 {
            newline()
            increaseIndent()
            indent()
        } else {
            write(" ")
        }

        for (index, item) in group.attributes.enumerated() {
            if index > 0 {
                write(",")
                if multiline && group.attributes.count > 1 {
                    newline()
                    indent()
                } else {
                    write(" ")
                }
            }
            printRefinementItem(item, multiline: false)
        }

        if multiline && group.attributes.count > 1 {
            newline()
            decreaseIndent()
            indent()
        } else {
            write(" ")
        }
        write("}")
    }

    // MARK: - Filter Printing

    private mutating func printFilter(_ filter: Filter) {
        write("{{ ")
        for (index, constraint) in filter.constraints.enumerated() {
            if index > 0 {
                write(", ")
            }
            printFilterConstraint(constraint)
        }
        write(" }}")
    }

    private mutating func printFilterConstraint(_ constraint: FilterConstraint) {
        switch constraint {
        case .term(let termFilter):
            write("term = ")
            printTermFilter(termFilter)
        case .language(let lang):
            write("language = ")
            write(lang)
        case .type(let t):
            write("type = ")
            write(t)
        case .dialect(let d):
            write("dialect = ")
            write(d)
        case .active(let a):
            write("active = ")
            write(a ? "true" : "false")
        case .moduleId(let m):
            write("moduleId = ")
            write(m)
        }
    }

    private mutating func printTermFilter(_ filter: TermFilter) {
        switch filter.matchType {
        case .exact:
            break
        case .match:
            write("match:")
        case .wild:
            write("wild:")
        }
        write("\"")
        write(filter.value)
        write("\"")
    }
}

// MARK: - Minifying Formatter

/// A compact formatter that produces single-line ECL output.
///
/// Unlike `ECLFormatter`, this produces minimal whitespace output
/// suitable for storage or transmission where readability isn't a priority.
struct ECLMinifier {
    private var output: String = ""

    /// Minifies an ECL expression to a compact single-line string.
    ///
    /// - Parameter expression: The ECL expression to minify
    /// - Returns: The minified ECL string
    mutating func minify(_ expression: ECLExpression) -> String {
        output = ""
        printExpression(expression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func write(_ text: String) {
        output += text
    }

    private mutating func printExpression(_ expression: ECLExpression) {
        switch expression {
        case .compound(let compound):
            printCompound(compound)
        case .refined(let refined):
            printRefined(refined)
        case .subExpression(let sub):
            printSubExpression(sub)
        }
    }

    private mutating func printCompound(_ compound: CompoundExpression) {
        let leftNeedsParens = needsParens(compound.left, inCompound: compound.op)
        if leftNeedsParens { write("(") }
        printExpression(compound.left)
        if leftNeedsParens { write(")") }

        write(" \(compound.op.rawValue) ")

        let rightNeedsParens = needsParens(compound.right, inCompound: compound.op)
        if rightNeedsParens { write("(") }
        printExpression(compound.right)
        if rightNeedsParens { write(")") }
    }

    private func needsParens(_ expression: ECLExpression, inCompound op: CompoundExpression.Operator) -> Bool {
        guard case .compound(let inner) = expression else { return false }
        switch (op, inner.op) {
        case (.and, .or), (.and, .minus), (.or, .minus):
            return true
        default:
            return false
        }
    }

    private mutating func printRefined(_ refined: RefinedExpression) {
        printSubExpression(refined.expression)
        write(": ")
        printRefinement(refined.refinement)
    }

    private mutating func printSubExpression(_ sub: SubExpression) {
        if let op = sub.constraintOp {
            write(op.rawValue)
            write(" ")
        }
        printFocusConcept(sub.focusConcept)
        for filter in sub.filters {
            write(" ")
            printFilter(filter)
        }
    }

    private mutating func printFocusConcept(_ focus: FocusConcept) {
        switch focus {
        case .concept(let concept):
            printConceptReference(concept)
        case .wildcard:
            write("*")
        case .nested(let expr):
            write("(")
            printExpression(expr)
            write(")")
        case .memberOf(let inner):
            write("^")
            printFocusConcept(inner)
        }
    }

    private mutating func printConceptReference(_ concept: ConceptReference) {
        write(concept.sctId)
        if let term = concept.term {
            write(" |")
            write(term)
            write("|")
        }
    }

    private mutating func printRefinement(_ refinement: Refinement) {
        for (index, item) in refinement.items.enumerated() {
            if index > 0 { write(", ") }
            printRefinementItem(item)
        }
    }

    private mutating func printRefinementItem(_ item: RefinementItem) {
        switch item {
        case .attribute(let attr):
            printAttribute(attr)
        case .attributeGroup(let group):
            printAttributeGroup(group)
        case .conjunction(let items):
            for (index, i) in items.enumerated() {
                if index > 0 { write(", ") }
                printRefinementItem(i)
            }
        case .disjunction(let items):
            for (index, i) in items.enumerated() {
                if index > 0 { write(" OR ") }
                printRefinementItem(i)
            }
        }
    }

    private mutating func printAttribute(_ attr: Attribute) {
        if let card = attr.cardinality {
            write(card.text)
            write(" ")
        }
        if attr.isReverse { write("R ") }
        printAttributeName(attr.name)
        write(" \(attr.comparator.rawValue) ")
        printAttributeValue(attr.value)
    }

    private mutating func printAttributeName(_ name: AttributeName) {
        switch name {
        case .concept(let concept):
            printConceptReference(concept)
        case .wildcard:
            write("*")
        case .nested(let expr):
            write("(")
            printExpression(expr)
            write(")")
        }
    }

    private mutating func printAttributeValue(_ value: AttributeValue) {
        switch value {
        case .expression(let expr):
            printExpression(expr)
        case .concept(let concept):
            printConceptReference(concept)
        case .wildcard:
            write("*")
        case .nested(let expr):
            write("(")
            printExpression(expr)
            write(")")
        case .stringValue(let s):
            write("\"\(s)\"")
        case .integerValue(let i):
            write(String(i))
        case .booleanValue(let b):
            write(b ? "true" : "false")
        }
    }

    private mutating func printAttributeGroup(_ group: AttributeGroup) {
        write("{ ")
        for (index, item) in group.attributes.enumerated() {
            if index > 0 { write(", ") }
            printRefinementItem(item)
        }
        write(" }")
    }

    private mutating func printFilter(_ filter: Filter) {
        write("{{ ")
        for (index, constraint) in filter.constraints.enumerated() {
            if index > 0 { write(", ") }
            printFilterConstraint(constraint)
        }
        write(" }}")
    }

    private mutating func printFilterConstraint(_ constraint: FilterConstraint) {
        switch constraint {
        case .term(let termFilter):
            write("term = ")
            printTermFilter(termFilter)
        case .language(let lang):
            write("language = \(lang)")
        case .type(let t):
            write("type = \(t)")
        case .dialect(let d):
            write("dialect = \(d)")
        case .active(let a):
            write("active = \(a ? "true" : "false")")
        case .moduleId(let m):
            write("moduleId = \(m)")
        }
    }

    private mutating func printTermFilter(_ filter: TermFilter) {
        switch filter.matchType {
        case .exact: break
        case .match: write("match:")
        case .wild: write("wild:")
        }
        write("\"\(filter.value)\"")
    }
}

// MARK: - Public API

/// Formats an ECL expression string to improve readability.
///
/// - Parameters:
///   - ecl: The ECL expression string to format
///   - options: Formatting options (indent size, etc.)
/// - Returns: The formatted ECL string
/// - Throws: `ECLError` if the input cannot be parsed
func formatECL(_ ecl: String, options: ECLFormatter.Options = .default) throws -> String {
    // Tokenize
    var lexer = ECLLexer(source: ecl)
    let tokens = try lexer.tokenize()

    // Parse
    var parser = ECLParser(tokens: tokens)
    let ast = try parser.parse()

    // Format
    var formatter = ECLFormatter(options: options)
    return formatter.format(ast)
}

/// Minifies an ECL expression string to a compact single-line format.
///
/// - Parameter ecl: The ECL expression string to minify
/// - Returns: The minified ECL string
/// - Throws: `ECLError` if the input cannot be parsed
func minifyECL(_ ecl: String) throws -> String {
    // Tokenize
    var lexer = ECLLexer(source: ecl)
    let tokens = try lexer.tokenize()

    // Parse
    var parser = ECLParser(tokens: tokens)
    let ast = try parser.parse()

    // Minify
    var minifier = ECLMinifier()
    return minifier.minify(ast)
}

/// Toggles an ECL expression between pretty-printed and minified formats.
///
/// - If the input is already pretty-printed, returns the minified version
/// - If the input is minified or irregular, returns the pretty-printed version
///
/// Detection works by comparing the normalized input with the pretty-printed output.
///
/// - Parameter ecl: The ECL expression string to toggle
/// - Returns: The toggled ECL string (pretty if was minified, minified if was pretty)
/// - Throws: `ECLError` if the input cannot be parsed
func toggleECLFormat(_ ecl: String) throws -> String {
    // Tokenize
    var lexer = ECLLexer(source: ecl)
    let tokens = try lexer.tokenize()

    // Parse
    var parser = ECLParser(tokens: tokens)
    let ast = try parser.parse()

    // Generate both formats
    var formatter = ECLFormatter(options: .default)
    let prettyPrinted = formatter.format(ast)

    var minifier = ECLMinifier()
    let minified = minifier.minify(ast)

    // Normalize input for comparison (trim whitespace, normalize line endings)
    let normalizedInput = ecl.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\r\n", with: "\n")

    // If input matches pretty-printed, return minified; otherwise return pretty-printed
    if normalizedInput == prettyPrinted {
        return minified
    } else {
        return prettyPrinted
    }
}

/// Checks if a string appears to be a valid ECL expression.
///
/// - Parameter text: The text to check
/// - Returns: `true` if the text can be parsed as ECL
func isValidECL(_ text: String) -> Bool {
    do {
        var lexer = ECLLexer(source: text)
        let tokens = try lexer.tokenize()
        var parser = ECLParser(tokens: tokens)
        _ = try parser.parse()
        return true
    } catch {
        return false
    }
}
