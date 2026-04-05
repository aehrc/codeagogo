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

import Foundation
import JavaScriptCore

/// Bridge to ecl-core (TypeScript) running in JavaScriptCore.
///
/// Provides ECL parsing, formatting, validation, and concept extraction
/// powered by the ecl-core library bundled as a single JavaScript file.
/// Runs entirely in-process with zero external dependencies.
///
/// ## Usage
///
/// ```swift
/// let bridge = ECLBridge()
/// let formatted = bridge.formatECL("<< 404684003: 363698007 = << 39057004")
/// let result = bridge.parseECL("<< 404684003")
/// ```
///
/// ## Thread Safety
///
/// `JSContext` is not thread-safe. All calls must happen on the same thread
/// (typically main). For background use, create a separate instance per thread.
final class ECLBridge {

    /// Formatting options matching ecl-core's `FormattingOptions`.
    struct FormattingOptions {
        var indentSize: Int = 2
        var indentStyle: String = "space"
        var spaceAroundOperators: Bool = true
        var maxLineLength: Int = 80
        var alignTerms: Bool = true
        var wrapComments: Bool = false
        var breakOnOperators: Bool = false
        var breakOnRefinementComma: Bool = false
        var breakAfterColon: Bool = false
        var removeRedundantParentheses: Bool = false

        static let `default` = FormattingOptions()

        /// Converts to a JS object string for evaluation.
        var jsObject: String {
            """
            {
                indentSize: \(indentSize),
                indentStyle: '\(indentStyle)',
                spaceAroundOperators: \(spaceAroundOperators),
                maxLineLength: \(maxLineLength),
                alignTerms: \(alignTerms),
                wrapComments: \(wrapComments),
                breakOnOperators: \(breakOnOperators),
                breakOnRefinementComma: \(breakOnRefinementComma),
                breakAfterColon: \(breakAfterColon),
                removeRedundantParentheses: \(removeRedundantParentheses)
            }
            """
        }
    }

    /// A parse error with location information.
    struct ParseError {
        let line: Int
        let column: Int
        let message: String
    }

    /// A concept reference extracted from an ECL expression.
    struct ConceptReference {
        let id: String
        let term: String?
    }

    /// An ECL operator reference documentation entry.
    struct OperatorDoc {
        /// The operator symbol or keyword (e.g., "<<", "AND", ":").
        let symbol: String
        /// Markdown documentation including name, description, and examples.
        let markdown: String
    }

    /// An ECL knowledge article from ecl-core's knowledge base.
    struct KnowledgeArticle: Identifiable {
        /// Unique identifier (e.g., "op:descendantOf", "pattern:disorders-by-site").
        let id: String
        /// Category: "operator", "refinement", "filter", "pattern", "grammar", "history".
        let category: String
        /// Short display name.
        let name: String
        /// One-line description.
        let summary: String
        /// Full Markdown content with explanations and examples.
        let content: String
        /// Standalone ECL expression examples.
        let examples: [String]
    }

    /// Result of parsing an ECL expression.
    struct ParseResult {
        let hasAST: Bool
        let errors: [ParseError]
        let warnings: [String]
    }

    private let context: JSContext

    /// Creates a new ECL bridge, loading the ecl-core bundle.
    ///
    /// - Parameter bundleURL: URL to the ecl-core-bundle.js file.
    ///   If nil, looks for the bundle in the app's main bundle.
    init(bundleURL: URL? = nil) {
        context = JSContext()!

        context.exceptionHandler = { _, exception in
            guard let exception else { return }
            AppLog.error(AppLog.ui, "ECLBridge JS error: \(exception)")
        }

        let url = bundleURL ?? Bundle.main.url(forResource: "ecl-core-bundle", withExtension: "js")

        guard let url, let js = try? String(contentsOf: url, encoding: .utf8) else {
            AppLog.error(AppLog.ui, "ECLBridge: could not load ecl-core-bundle.js")
            return
        }

        context.evaluateScript(js)
    }

    /// Creates a bridge with a pre-loaded JS string (useful for testing).
    init(bundleSource: String) {
        context = JSContext()!

        context.exceptionHandler = { _, exception in
            guard let exception else { return }
            AppLog.error(AppLog.ui, "ECLBridge JS error: \(exception)")
        }

        context.evaluateScript(bundleSource)
    }

    // MARK: - Formatting

    /// Formats an ECL expression using ecl-core's formatter.
    ///
    /// - Parameters:
    ///   - ecl: The ECL expression to format
    ///   - options: Formatting options (defaults to ecl-core defaults)
    /// - Returns: The formatted ECL string, or nil if formatting failed
    func formatECL(_ ecl: String, options: FormattingOptions = .default) -> String? {
        let escaped = escapeForJS(ecl)
        let result = context.evaluateScript("""
            (function() {
                try {
                    return ECLCore.formatDocument('\(escaped)', \(options.jsObject));
                } catch(e) {
                    return null;
                }
            })()
        """)
        guard let result, !result.isNull, !result.isUndefined else { return nil }
        return result.toString()
    }

    // MARK: - Parsing

    /// Parses an ECL expression and returns structured results.
    ///
    /// - Parameter ecl: The ECL expression to parse
    /// - Returns: A `ParseResult` with AST presence, errors, and warnings
    func parseECL(_ ecl: String) -> ParseResult {
        let escaped = escapeForJS(ecl)
        let result = context.evaluateScript("""
            (function() {
                var r = ECLCore.parseECL('\(escaped)');
                return JSON.stringify({
                    hasAST: r.ast !== null,
                    errors: r.errors.map(function(e) {
                        return { line: e.line, column: e.column, message: e.message };
                    }),
                    warnings: r.warnings.map(function(w) { return w.message || String(w); })
                });
            })()
        """)

        guard let json = result?.toString(),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParseResult(hasAST: false, errors: [], warnings: [])
        }

        let hasAST = dict["hasAST"] as? Bool ?? false

        let errors: [ParseError] = (dict["errors"] as? [[String: Any]] ?? []).map { e in
            ParseError(
                line: e["line"] as? Int ?? 0,
                column: e["column"] as? Int ?? 0,
                message: e["message"] as? String ?? "Unknown error"
            )
        }

        let warnings = dict["warnings"] as? [String] ?? []

        return ParseResult(hasAST: hasAST, errors: errors, warnings: warnings)
    }

    // MARK: - Validation

    /// Checks whether a string is a valid SNOMED CT concept ID (Verhoeff check).
    ///
    /// - Parameter sctid: The identifier to validate
    /// - Returns: `true` if the ID passes format and check digit validation
    func isValidConceptId(_ sctid: String) -> Bool {
        let result = context.evaluateScript("ECLCore.isValidConceptId('\(sctid)')")
        return result?.toBool() ?? false
    }

    /// Checks whether an ECL expression is syntactically valid.
    ///
    /// - Parameter ecl: The ECL expression to check
    /// - Returns: `true` if the expression parses without errors
    func isValidECL(_ ecl: String) -> Bool {
        let result = parseECL(ecl)
        return result.hasAST && result.errors.isEmpty
    }

    // MARK: - Concept Extraction

    /// Extracts concept IDs referenced in an ECL expression.
    ///
    /// - Parameter ecl: The ECL expression to analyze
    /// - Returns: Array of concept references with IDs and optional display terms
    func extractConceptIds(_ ecl: String) -> [ConceptReference] {
        let escaped = escapeForJS(ecl)
        let result = context.evaluateScript("""
            (function() {
                var r = ECLCore.parseECL('\(escaped)');
                if (!r.ast) return '[]';
                var concepts = ECLCore.extractConceptIds(r.ast);
                return JSON.stringify(concepts.map(function(c) {
                    return { id: c.id, term: c.term || null };
                }));
            })()
        """)

        guard let json = result?.toString(),
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return arr.map { dict in
            ConceptReference(
                id: dict["id"] as? String ?? "",
                term: dict["term"] as? String
            )
        }
    }

    // MARK: - Toggle (Pretty ↔ Minified)

    /// Toggles an ECL expression between formatted and minified forms.
    ///
    /// If the input matches the formatted output, returns minified.
    /// Otherwise returns formatted.
    ///
    /// - Parameter ecl: The ECL expression to toggle
    /// - Returns: The toggled ECL string, or nil if the input is not valid ECL
    func toggleECLFormat(_ ecl: String) -> String? {
        let escaped = escapeForJS(ecl)
        let result = context.evaluateScript("""
            (function() {
                try {
                    var opts = ECLCore.defaultFormattingOptions;
                    var formatted = ECLCore.formatDocument('\(escaped)', opts);
                    var input = '\(escaped)'.trim().replace(/\\r\\n/g, '\\n');
                    if (input === formatted.trim()) {
                        // Already formatted — return minified (single line, minimal whitespace)
                        return ECLCore.formatDocument('\(escaped)', {
                            indentSize: 0,
                            indentStyle: 'space',
                            spaceAroundOperators: true,
                            maxLineLength: 0,
                            alignTerms: false,
                            wrapComments: false,
                            breakOnOperators: false,
                            breakOnRefinementComma: false,
                            breakAfterColon: false,
                        });
                    }
                    return formatted;
                } catch(e) {
                    return null;
                }
            })()
        """)
        guard let result, !result.isNull, !result.isUndefined else { return nil }
        return result.toString()
    }

    // MARK: - Knowledge Base

    /// Returns all ECL knowledge articles from ecl-core's knowledge base.
    ///
    /// Articles cover operators, refinements, filters, patterns, grammar,
    /// and history supplements. Each includes Markdown content with examples.
    ///
    /// - Returns: Array of knowledge articles, or empty if unavailable
    func getArticles() -> [KnowledgeArticle] {
        let result = context.evaluateScript("""
            (function() {
                var articles = ECLCore.allArticles;
                if (!articles || !Array.isArray(articles)) return '[]';
                return JSON.stringify(articles.map(function(a) {
                    return {
                        id: a.id || '',
                        category: a.category || '',
                        name: a.name || '',
                        summary: a.summary || '',
                        content: a.content || '',
                        examples: a.examples || []
                    };
                }));
            })()
        """)

        guard let json = result?.toString(),
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            AppLog.warning(AppLog.ui, "ECLBridge: could not load knowledge articles")
            return []
        }

        return arr.map { dict in
            KnowledgeArticle(
                id: dict["id"] as? String ?? "",
                category: dict["category"] as? String ?? "",
                name: dict["name"] as? String ?? "",
                summary: dict["summary"] as? String ?? "",
                content: dict["content"] as? String ?? "",
                examples: dict["examples"] as? [String] ?? []
            )
        }
    }

    /// Returns ECL operator reference documentation from ecl-core's knowledge base.
    ///
    /// - Returns: Array of operator documentation entries, or empty if unavailable
    func getOperatorDocs() -> [OperatorDoc] {
        let result = context.evaluateScript("""
            (function() {
                var docs = ECLCore.operatorHoverDocs;
                if (!docs || !Array.isArray(docs)) return '[]';
                return JSON.stringify(docs.map(function(d) {
                    return { symbol: d.operator || '', markdown: d.markdown || '' };
                }));
            })()
        """)

        guard let json = result?.toString(),
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            AppLog.warning(AppLog.ui, "ECLBridge: could not load operator hover docs")
            return []
        }

        return arr.map { dict in
            OperatorDoc(
                symbol: dict["symbol"] as? String ?? "",
                markdown: dict["markdown"] as? String ?? ""
            )
        }
    }

    // MARK: - Helpers

    /// Escapes a string for safe inclusion in a JS single-quoted string literal.
    private func escapeForJS(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "'", with: "\\'")
           .replacingOccurrences(of: "\n", with: "\\n")
           .replacingOccurrences(of: "\r", with: "\\r")
           .replacingOccurrences(of: "\t", with: "\\t")
    }
}
