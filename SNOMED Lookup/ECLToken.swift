import Foundation

/// Token types for SNOMED CT Expression Constraint Language (ECL).
///
/// ECL tokens represent the lexical elements of the language, including
/// operators, keywords, identifiers, and literals.
enum ECLTokenType: Equatable {
    // MARK: - Constraint Operators (Brief Syntax)

    /// `<` - Descendant of
    case descendantOf
    /// `<<` - Descendant or self of
    case descendantOrSelfOf
    /// `<!` - Child of
    case childOf
    /// `<<!` - Child or self of
    case childOrSelfOf
    /// `>` - Ancestor of
    case ancestorOf
    /// `>>` - Ancestor or self of
    case ancestorOrSelfOf
    /// `>!` - Parent of
    case parentOf
    /// `>>!` - Parent or self of
    case parentOrSelfOf
    /// `^` - Member of
    case memberOf

    // MARK: - Logical Operators

    /// `AND` - Conjunction
    case and
    /// `OR` - Disjunction
    case or
    /// `MINUS` - Exclusion
    case minus

    // MARK: - Comparison Operators

    /// `=` - Equals
    case equals
    /// `!=` - Not equals
    case notEquals
    /// `<=` - Less than or equals
    case lessThanOrEquals
    /// `>=` - Greater than or equals
    case greaterThanOrEquals

    // MARK: - Delimiters

    /// `(` - Left parenthesis
    case leftParen
    /// `)` - Right parenthesis
    case rightParen
    /// `{` - Left brace (attribute group)
    case leftBrace
    /// `}` - Right brace
    case rightBrace
    /// `{{` - Left double brace (filter)
    case leftDoubleBrace
    /// `}}` - Right double brace
    case rightDoubleBrace
    /// `[` - Left bracket (cardinality)
    case leftBracket
    /// `]` - Right bracket
    case rightBracket
    /// `:` - Colon (refinement)
    case colon
    /// `,` - Comma
    case comma
    /// `..` - Range (cardinality)
    case range
    /// `.` - Dot (attribute path)
    case dot

    // MARK: - Special

    /// `*` - Wildcard
    case wildcard
    /// `R` - Reverse attribute (when followed by attribute)
    case reverse

    // MARK: - Literals

    /// SNOMED CT Identifier (6-18 digits)
    case sctId(String)
    /// Term string `|...|`
    case termString(String)
    /// Quoted string `"..."`
    case stringLiteral(String)
    /// Integer number
    case integer(Int)

    // MARK: - Filter Keywords

    /// `term` - Term filter
    case termKeyword
    /// `language` - Language filter
    case languageKeyword
    /// `type` - Type filter
    case typeKeyword
    /// `dialect` - Dialect filter
    case dialectKeyword
    /// `active` - Active filter
    case activeKeyword
    /// `moduleId` - Module ID filter
    case moduleIdKeyword
    /// `effectiveTime` - Effective time filter
    case effectiveTimeKeyword
    /// `definitionStatusId` - Definition status filter
    case definitionStatusIdKeyword
    /// `match` - Match operator
    case matchKeyword
    /// `wild` - Wild match operator
    case wildKeyword

    // MARK: - Boolean

    /// `true`
    case trueKeyword
    /// `false`
    case falseKeyword

    // MARK: - Other

    /// Identifier (unrecognized keyword or dialect alias)
    case identifier(String)
    /// End of input
    case eof
    /// Whitespace (preserved for formatting)
    case whitespace(String)
    /// Comment `/* ... */`
    case comment(String)
}

/// A token with its type and position in the source text.
struct ECLToken: Equatable {
    /// The token type.
    let type: ECLTokenType
    /// The original text of the token.
    let text: String
    /// Start position in the source.
    let start: String.Index
    /// End position in the source.
    let end: String.Index

    /// Returns true if this token is whitespace or comment.
    var isTrivia: Bool {
        switch type {
        case .whitespace, .comment:
            return true
        default:
            return false
        }
    }
}
