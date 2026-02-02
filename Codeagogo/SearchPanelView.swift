import SwiftUI

/// The main view for the concept search panel.
///
/// `SearchPanelView` provides a floating search interface with:
/// - A search text field with typeahead
/// - A code system picker (SNOMED CT or configured systems)
/// - An edition filter picker (SNOMED CT only)
/// - A scrollable list of search results
/// - An insert format picker and Insert button
///
/// The view is 450x400 points and designed to be used in a floating panel.
struct SearchPanelView: View {
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject private var settings = SearchSettings.shared
    @ObservedObject private var codeSystemSettings = CodeSystemSettings.shared
    @FocusState private var isSearchFieldFocused: Bool

    /// Callback to close the panel.
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with search field and edition picker
            headerSection

            Divider()

            // Results list
            resultsSection

            Divider()

            // Footer with format picker and Insert button
            footerSection
        }
        .frame(width: 450, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.loadEditions()
            // Focus the search field when the panel appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 10) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(searchPlaceholder, text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFieldFocused)
                    .accessibilityIdentifier("search.searchField")
                    .accessibilityLabel("Search field")
                    .accessibilityHint("Type to search for concepts")

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.results = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search.clearButton")
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Code system picker
            HStack {
                Text("Code System:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.selectedCodeSystemURI) {
                    Text("SNOMED CT").tag(nil as String?)
                    if !codeSystemSettings.enabledSystems.isEmpty {
                        Divider()
                        ForEach(codeSystemSettings.enabledSystems) { system in
                            Text(system.title).tag(system.uri as String?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("search.codeSystemPicker")
                .accessibilityLabel("Code system")
                .accessibilityHint("Select a code system to search")
            }

            // Edition picker (only shown for SNOMED CT)
            if settings.isSNOMEDSelected {
                HStack {
                    Text("Edition:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.selectedEditionURI) {
                        Text("All Editions").tag(nil as String?)
                        if !viewModel.availableEditions.isEmpty {
                            Divider()
                            ForEach(viewModel.availableEditions) { edition in
                                Text(edition.title).tag(edition.version as String?)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("search.editionFilter")
                    .accessibilityLabel("Edition filter")
                    .accessibilityHint("Select an edition to filter search results")

                    if viewModel.isLoadingEditions {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .padding(12)
    }

    /// The placeholder text for the search field, based on selected code system.
    private var searchPlaceholder: String {
        if settings.isSNOMEDSelected {
            return "Search SNOMED CT concepts..."
        } else if let uri = settings.selectedCodeSystemURI {
            // Get the title from configured systems
            if let system = codeSystemSettings.configuredSystems.first(where: { $0.uri == uri }) {
                return "Search \(system.title) codes..."
            }
        }
        return "Search concepts..."
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Group {
            if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isSearching {
                emptyResultsView
            } else if viewModel.results.isEmpty && viewModel.searchText.isEmpty {
                placeholderView
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(viewModel.results, selection: $viewModel.selectedResult) { result in
                SearchResultRow(result: result, isSelected: viewModel.selectedResult == result)
                    .tag(result)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .id(result.id)
            }
            .listStyle(.plain)
            .accessibilityIdentifier("search.resultsList")
            .onChange(of: viewModel.selectedResult) { newValue in
                if let selected = newValue {
                    withAnimation {
                        proxy.scrollTo(selected.id, anchor: .center)
                    }
                }
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Type to search for concepts")
                .foregroundColor(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("search.placeholder")
    }

    private var emptyResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No concepts found")
                .foregroundColor(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("search.noResults")
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("search.errorView")
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 12) {
            // Format picker
            HStack(spacing: 6) {
                Text("Format:")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize()

                Picker("", selection: $settings.selectedFormat) {
                    ForEach(InsertFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
                .accessibilityIdentifier("search.insertFormat")
                .accessibilityLabel("Insert format")
                .accessibilityHint("Select how the concept will be formatted when inserted")
            }

            Spacer()

            // Cancel button
            Button("Cancel") {
                onClose?()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityIdentifier("search.cancelButton")
            .accessibilityLabel("Cancel")
            .accessibilityHint("Close the search panel")

            // Insert button
            Button("Insert") {
                viewModel.insertSelected()
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(viewModel.selectedResult == nil)
            .accessibilityIdentifier("search.insertButton")
            .accessibilityLabel("Insert")
            .accessibilityHint("Insert the selected concept into the active application")
        }
        .padding(12)
    }
}

// MARK: - Search Result Row

/// A single row in the search results list.
struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Preferred Term (primary)
            Text(result.display)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            // FSN (if different from PT)
            if let fsn = result.fsn, fsn != result.display {
                Text(fsn)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Code and Edition
            HStack(spacing: 4) {
                Text(result.code)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary)

                Text(result.editionName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#if DEBUG
struct SearchPanelView_Previews: PreviewProvider {
    static var previews: some View {
        SearchPanelView(viewModel: SearchViewModel())
    }
}
#endif
