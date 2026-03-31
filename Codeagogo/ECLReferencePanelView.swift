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

import SwiftUI

/// A floating panel view displaying ECL reference documentation.
///
/// Shows 50 knowledge articles from ecl-core grouped by category (operators,
/// refinements, filters, patterns, grammar, history). Each article is
/// expandable to show full content and ECL examples.
struct ECLReferencePanelView: View {
    var onClose: (() -> Void)?
    let articles: [ECLBridge.KnowledgeArticle]

    /// Tracks which articles are expanded by ID.
    @State private var expandedArticles: Set<String> = []

    /// Search/filter text.
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            articleList
            Divider()
            footerSection
        }
        .frame(minWidth: 420, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ECL Reference")
                    .font(.headline)
                    .accessibilityIdentifier("eclReference.title")
                Spacer()
                Text("\(filteredArticles.count) topics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            TextField("Filter...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .accessibilityIdentifier("eclReference.search")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Article List

    private var filteredArticles: [ECLBridge.KnowledgeArticle] {
        guard !searchText.isEmpty else { return articles }
        let query = searchText.lowercased()
        return articles.filter {
            $0.name.lowercased().contains(query)
            || $0.summary.lowercased().contains(query)
            || $0.content.lowercased().contains(query)
        }
    }

    private var articleList: some View {
        List {
            ForEach(ArticleCategory.allCases, id: \.self) { category in
                let categoryArticles = filteredArticles.filter { $0.category == category.rawValue }
                if !categoryArticles.isEmpty {
                    Section {
                        ForEach(categoryArticles) { article in
                            articleRow(article)
                        }
                    } header: {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.caption)
                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .accessibilityIdentifier("eclReference.section.\(category.rawValue)")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("eclReference.list")
    }

    private func articleRow(_ article: ECLBridge.KnowledgeArticle) -> some View {
        let isExpanded = expandedArticles.contains(article.id)

        return VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isExpanded {
                        expandedArticles.remove(article.id)
                    } else {
                        expandedArticles.insert(article.id)
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        Text(article.summary)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("eclReference.article.\(article.id)")

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Content (rendered as plain text from Markdown)
                    contentView(article.content)

                    // Examples
                    if !article.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Examples")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(article.examples, id: \.self) { example in
                                Text(example)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(4)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(.leading, 18)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 2)
    }

    /// Renders Markdown content as styled text with code blocks and tables.
    private func contentView(_ markdown: String) -> some View {
        let sections = parseMarkdownSections(markdown)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                switch section.kind {
                case .code:
                    Text(section.text)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .textSelection(.enabled)

                case .table:
                    tableView(section.text)

                case .prose:
                    let cleaned = cleanMarkdown(section.text)
                    if !cleaned.isEmpty {
                        Text(cleaned)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    /// Renders a Markdown table as a grid.
    private func tableView(_ text: String) -> some View {
        let rows = parseTableRows(text)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, columns in
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, cell in
                        Text(cell)
                            .font(.system(size: 11, weight: index == 0 ? .semibold : .regular))
                            .foregroundColor(index == 0 ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(index == 0 ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    }
                }
                if index == 0 {
                    Divider()
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor).opacity(0.3))
        .cornerRadius(4)
        .textSelection(.enabled)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if let url = URL(string: "https://confluence.ihtsdotools.org/display/DOCECL") {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "book")
                            .font(.caption)
                        Text("ECL Specification")
                            .font(.callout)
                    }
                }
                .accessibilityIdentifier("eclReference.specLink")
            }
            Spacer()
            Button("Close") {
                onClose?()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("eclReference.close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Markdown Helpers

    private enum SectionKind {
        case prose, code, table
    }

    private struct MarkdownSection {
        let text: String
        let kind: SectionKind

        var isCode: Bool { kind == .code }
    }

    /// Splits Markdown into prose, code block, and table sections.
    private func parseMarkdownSections(_ markdown: String) -> [MarkdownSection] {
        var sections: [MarkdownSection] = []
        var current = ""
        var currentKind: SectionKind = .prose
        let lines = markdown.components(separatedBy: "\n")

        func flush() {
            let trimmed = current.trimmingCharacters(in: .newlines)
            if !trimmed.isEmpty {
                sections.append(MarkdownSection(text: trimmed, kind: currentKind))
            }
            current = ""
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.hasPrefix("```") {
                if currentKind == .code {
                    flush()
                    currentKind = .prose
                } else {
                    flush()
                    currentKind = .code
                }
                continue
            }

            // Detect table rows (start with |)
            let isTableLine = trimmedLine.hasPrefix("|")
            // Skip separator rows like |---|---|
            let isSeparator = isTableLine && trimmedLine.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }

            if currentKind == .code {
                if !current.isEmpty { current += "\n" }
                current += line
            } else if isTableLine {
                if currentKind != .table {
                    flush()
                    currentKind = .table
                }
                if !isSeparator {
                    if !current.isEmpty { current += "\n" }
                    current += line
                }
            } else {
                if currentKind == .table {
                    flush()
                    currentKind = .prose
                }
                if !current.isEmpty { current += "\n" }
                current += line
            }
        }

        flush()
        return sections
    }

    /// Strips basic Markdown formatting for plain text display.
    private func cleanMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "# ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses a Markdown table block into rows of columns.
    private func parseTableRows(_ text: String) -> [[String]] {
        text.components(separatedBy: "\n").map { line in
            line.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }
}

// MARK: - ArticleCategory

/// Maps ecl-core knowledge categories to display metadata.
enum ArticleCategory: String, CaseIterable {
    case operator_ = "operator"
    case refinement
    case filter
    case pattern
    case grammar
    case history

    var displayName: String {
        switch self {
        case .operator_: return "Operators"
        case .refinement: return "Refinements"
        case .filter: return "Filters"
        case .pattern: return "Patterns & Examples"
        case .grammar: return "Grammar"
        case .history: return "History Supplements"
        }
    }

    var icon: String {
        switch self {
        case .operator_: return "chevron.left.forwardslash.chevron.right"
        case .refinement: return "slider.horizontal.3"
        case .filter: return "line.3.horizontal.decrease"
        case .pattern: return "doc.text.magnifyingglass"
        case .grammar: return "textformat"
        case .history: return "clock.arrow.circlepath"
        }
    }
}
