import Foundation

/// Lexer for SNOMED CT Expression Constraint Language (ECL).
///
/// Tokenizes ECL source text into a sequence of tokens for parsing.
/// Handles all ECL 2.x syntax including constraint operators, logical
/// operators, refinements, filters, and literals.
struct ECLLexer {
    private let source: String
    private var currentIndex: String.Index
    private var tokens: [ECLToken] = []

    /// Creates a lexer for the given source text.
    init(source: String) {
        self.source = source
        self.currentIndex = source.startIndex
    }

    /// Tokenizes the source and returns all tokens.
    ///
    /// - Returns: Array of tokens including whitespace and comments
    /// - Throws: `ECLError.lexerError` if invalid characters are encountered
    mutating func tokenize() throws -> [ECLToken] {
        tokens = []

        while !isAtEnd {
            try scanToken()
        }

        tokens.append(ECLToken(
            type: .eof,
            text: "",
            start: currentIndex,
            end: currentIndex
        ))

        return tokens
    }

    // MARK: - Scanner

    private var isAtEnd: Bool {
        currentIndex >= source.endIndex
    }

    private var currentChar: Character? {
        isAtEnd ? nil : source[currentIndex]
    }

    private func peek(offset: Int = 0) -> Character? {
        guard let idx = source.index(currentIndex, offsetBy: offset, limitedBy: source.endIndex),
              idx < source.endIndex else {
            return nil
        }
        return source[idx]
    }

    private mutating func advance() -> Character? {
        guard !isAtEnd else { return nil }
        let char = source[currentIndex]
        currentIndex = source.index(after: currentIndex)
        return char
    }

    private mutating func scanToken() throws {
        let start = currentIndex

        guard let char = advance() else { return }

        switch char {
        // Single character tokens
        case "(":
            addToken(.leftParen, start: start)
        case ")":
            addToken(.rightParen, start: start)
        case "[":
            addToken(.leftBracket, start: start)
        case "]":
            addToken(.rightBracket, start: start)
        case ":":
            addToken(.colon, start: start)
        case ",":
            addToken(.comma, start: start)
        case "*":
            addToken(.wildcard, start: start)

        // Dot or range
        case ".":
            if peek() == "." {
                _ = advance()
                addToken(.range, start: start)
            } else {
                addToken(.dot, start: start)
            }

        // Braces - single or double
        case "{":
            if peek() == "{" {
                _ = advance()
                addToken(.leftDoubleBrace, start: start)
            } else {
                addToken(.leftBrace, start: start)
            }
        case "}":
            if peek() == "}" {
                _ = advance()
                addToken(.rightDoubleBrace, start: start)
            } else {
                addToken(.rightBrace, start: start)
            }

        // Less than operators
        case "<":
            if peek() == "<" {
                _ = advance()
                if peek() == "!" {
                    _ = advance()
                    addToken(.childOrSelfOf, start: start)
                } else {
                    addToken(.descendantOrSelfOf, start: start)
                }
            } else if peek() == "!" {
                _ = advance()
                addToken(.childOf, start: start)
            } else if peek() == "=" {
                _ = advance()
                addToken(.lessThanOrEquals, start: start)
            } else {
                addToken(.descendantOf, start: start)
            }

        // Greater than operators
        case ">":
            if peek() == ">" {
                _ = advance()
                if peek() == "!" {
                    _ = advance()
                    addToken(.parentOrSelfOf, start: start)
                } else {
                    addToken(.ancestorOrSelfOf, start: start)
                }
            } else if peek() == "!" {
                _ = advance()
                addToken(.parentOf, start: start)
            } else if peek() == "=" {
                _ = advance()
                addToken(.greaterThanOrEquals, start: start)
            } else {
                addToken(.ancestorOf, start: start)
            }

        // Caret (member of)
        case "^":
            addToken(.memberOf, start: start)

        // Equals or not equals
        case "=":
            addToken(.equals, start: start)
        case "!":
            if peek() == "=" {
                _ = advance()
                addToken(.notEquals, start: start)
            } else {
                throw ECLError.lexerError("Unexpected character '!' at position \(offset(of: start))")
            }

        // Pipe (term string)
        case "|":
            try scanTermString(start: start)

        // Quote (string literal)
        case "\"":
            try scanStringLiteral(start: start)

        // Comment
        case "/":
            if peek() == "*" {
                _ = advance()
                try scanComment(start: start)
            } else {
                throw ECLError.lexerError("Unexpected character '/' at position \(offset(of: start))")
            }

        // Whitespace
        case " ", "\t", "\n", "\r":
            scanWhitespace(start: start, firstChar: char)

        // Numbers (SCTID or integer)
        case "0"..."9":
            scanNumber(start: start)

        // Letters (keywords or identifiers)
        case "a"..."z", "A"..."Z", "_":
            scanIdentifierOrKeyword(start: start)

        default:
            throw ECLError.lexerError("Unexpected character '\(char)' at position \(offset(of: start))")
        }
    }

    private mutating func addToken(_ type: ECLTokenType, start: String.Index) {
        let text = String(source[start..<currentIndex])
        tokens.append(ECLToken(type: type, text: text, start: start, end: currentIndex))
    }

    // MARK: - Complex Token Scanners

    private mutating func scanWhitespace(start: String.Index, firstChar: Character) {
        var ws = String(firstChar)
        while let char = currentChar, char.isWhitespace {
            ws.append(char)
            _ = advance()
        }
        tokens.append(ECLToken(type: .whitespace(ws), text: ws, start: start, end: currentIndex))
    }

    private mutating func scanNumber(start: String.Index) {
        while let char = currentChar, char.isNumber {
            _ = advance()
        }

        let text = String(source[start..<currentIndex])

        // SCTIDs are 6-18 digits
        if text.count >= 6 && text.count <= 18 {
            tokens.append(ECLToken(type: .sctId(text), text: text, start: start, end: currentIndex))
        } else if let value = Int(text) {
            tokens.append(ECLToken(type: .integer(value), text: text, start: start, end: currentIndex))
        } else {
            // Fallback to identifier for very long numbers
            tokens.append(ECLToken(type: .identifier(text), text: text, start: start, end: currentIndex))
        }
    }

    private mutating func scanIdentifierOrKeyword(start: String.Index) {
        while let char = currentChar, char.isLetter || char.isNumber || char == "_" || char == "-" {
            _ = advance()
        }

        let text = String(source[start..<currentIndex])
        let upperText = text.uppercased()

        // Check for keywords (case-insensitive for logical operators)
        let tokenType: ECLTokenType
        switch upperText {
        case "AND":
            tokenType = .and
        case "OR":
            tokenType = .or
        case "MINUS":
            tokenType = .minus
        case "TRUE":
            tokenType = .trueKeyword
        case "FALSE":
            tokenType = .falseKeyword
        default:
            // Check case-sensitive keywords
            switch text {
            case "R":
                tokenType = .reverse
            case "term":
                tokenType = .termKeyword
            case "language":
                tokenType = .languageKeyword
            case "type":
                tokenType = .typeKeyword
            case "dialect":
                tokenType = .dialectKeyword
            case "active":
                tokenType = .activeKeyword
            case "moduleId":
                tokenType = .moduleIdKeyword
            case "effectiveTime":
                tokenType = .effectiveTimeKeyword
            case "definitionStatusId":
                tokenType = .definitionStatusIdKeyword
            case "match":
                tokenType = .matchKeyword
            case "wild":
                tokenType = .wildKeyword
            // Long-form constraint operators
            case "descendantOf":
                tokenType = .descendantOf
            case "descendantOrSelfOf":
                tokenType = .descendantOrSelfOf
            case "childOf":
                tokenType = .childOf
            case "childOrSelfOf":
                tokenType = .childOrSelfOf
            case "ancestorOf":
                tokenType = .ancestorOf
            case "ancestorOrSelfOf":
                tokenType = .ancestorOrSelfOf
            case "parentOf":
                tokenType = .parentOf
            case "parentOrSelfOf":
                tokenType = .parentOrSelfOf
            case "memberOf":
                tokenType = .memberOf
            case "reverseOf":
                tokenType = .reverse
            default:
                tokenType = .identifier(text)
            }
        }

        tokens.append(ECLToken(type: tokenType, text: text, start: start, end: currentIndex))
    }

    private mutating func scanTermString(start: String.Index) throws {
        var content = ""
        while let char = currentChar, char != "|" {
            content.append(char)
            _ = advance()
        }

        guard currentChar == "|" else {
            throw ECLError.lexerError("Unterminated term string starting at position \(offset(of: start))")
        }
        _ = advance() // consume closing |

        let text = String(source[start..<currentIndex])
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        tokens.append(ECLToken(type: .termString(trimmed), text: text, start: start, end: currentIndex))
    }

    private mutating func scanStringLiteral(start: String.Index) throws {
        var content = ""
        while let char = currentChar, char != "\"" {
            if char == "\\" {
                _ = advance()
                if let escaped = currentChar {
                    content.append(escaped)
                    _ = advance()
                }
            } else {
                content.append(char)
                _ = advance()
            }
        }

        guard currentChar == "\"" else {
            throw ECLError.lexerError("Unterminated string literal starting at position \(offset(of: start))")
        }
        _ = advance() // consume closing "

        let text = String(source[start..<currentIndex])
        tokens.append(ECLToken(type: .stringLiteral(content), text: text, start: start, end: currentIndex))
    }

    private mutating func scanComment(start: String.Index) throws {
        var content = ""
        while !isAtEnd {
            if currentChar == "*" && peek(offset: 1) == "/" {
                _ = advance() // *
                _ = advance() // /
                break
            }
            content.append(advance()!)
        }

        let text = String(source[start..<currentIndex])
        tokens.append(ECLToken(type: .comment(content), text: text, start: start, end: currentIndex))
    }

    private func offset(of index: String.Index) -> Int {
        source.distance(from: source.startIndex, to: index)
    }
}

// MARK: - Errors

/// Errors that can occur during ECL processing.
enum ECLError: LocalizedError {
    case lexerError(String)
    case parserError(String)
    case formatError(String)

    var errorDescription: String? {
        switch self {
        case .lexerError(let msg):
            return "ECL Lexer Error: \(msg)"
        case .parserError(let msg):
            return "ECL Parser Error: \(msg)"
        case .formatError(let msg):
            return "ECL Format Error: \(msg)"
        }
    }
}
