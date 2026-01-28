import Foundation
import Combine
import AppKit

/// View model for the SNOMED CT concept search panel.
///
/// `SearchViewModel` coordinates search operations and manages the state
/// for the search UI. It handles debounced typeahead search, edition filtering,
/// and text insertion via the clipboard.
///
/// ## Usage
///
/// ```swift
/// let viewModel = SearchViewModel()
///
/// // Bind to searchText for typeahead
/// viewModel.searchText = "paracetamol"
///
/// // Results are updated automatically via Combine
/// for result in viewModel.results {
///     print(result.display)
/// }
///
/// // Insert selected result
/// viewModel.selectedResult = viewModel.results.first
/// viewModel.insertSelected()
/// ```
@MainActor
final class SearchViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The current search text (bound to the text field).
    @Published var searchText: String = ""

    /// The search results from the API.
    @Published var results: [SearchResult] = []

    /// Whether a search is currently in progress.
    @Published var isSearching: Bool = false

    /// The currently selected result in the list.
    @Published var selectedResult: SearchResult?

    /// Error message to display, if any.
    @Published var errorMessage: String?

    /// Available editions for the picker.
    @Published var availableEditions: [SNOMEDEdition] = []

    /// Whether editions are being loaded.
    @Published var isLoadingEditions: Bool = false

    // MARK: - Dependencies

    /// The API client for searching concepts.
    private let client: ConceptSearching

    /// Settings for insert format and edition selection.
    private let settings: SearchSettings

    /// Helper for sending paste commands.
    private let selectionReader: SystemSelectionReader

    /// Callback to close the search panel after insertion.
    var onInsertComplete: (() -> Void)?

    /// Callback for the previously active app to restore focus.
    var previousApp: NSRunningApplication?

    // MARK: - Private Properties

    /// Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Debounce delay for search (milliseconds).
    private let debounceDelay: Int = 300

    /// The current search task (for cancellation).
    private var currentSearchTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new search view model.
    ///
    /// - Parameters:
    ///   - client: The API client for searching. Defaults to a new `OntoserverClient`.
    ///   - settings: The search settings. Defaults to the shared instance.
    ///   - selectionReader: Helper for paste operations. Defaults to a new reader.
    init(
        client: ConceptSearching = OntoserverClient(),
        settings: SearchSettings? = nil,
        selectionReader: SystemSelectionReader = SystemSelectionReader()
    ) {
        self.client = client
        self.settings = settings ?? SearchSettings.shared
        self.selectionReader = selectionReader

        setupSearchDebouncing()
    }

    // MARK: - Public Methods

    /// Loads available editions from the server.
    ///
    /// Called when the search panel is shown to populate the edition picker.
    func loadEditions() {
        guard availableEditions.isEmpty else { return }

        isLoadingEditions = true

        Task {
            do {
                let editions = try await client.getAvailableEditions()
                // Add International edition and sort all alphabetically
                let international = SNOMEDEdition(
                    system: "http://snomed.info/sct",
                    version: "http://snomed.info/sct/900000000000207008",
                    title: "International"
                )
                let allEditions = ([international] + editions).sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                await MainActor.run {
                    self.availableEditions = allEditions
                    self.isLoadingEditions = false
                }
            } catch {
                AppLog.error(AppLog.network, "Failed to load editions: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingEditions = false
                }
            }
        }
    }

    /// Performs a search with the current search text.
    ///
    /// This is called automatically via debouncing, but can also be
    /// called manually to force a search.
    func search() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        // Cancel any existing search
        currentSearchTask?.cancel()

        isSearching = true
        errorMessage = nil

        currentSearchTask = Task {
            do {
                let searchResults = try await client.searchConcepts(
                    filter: trimmed,
                    editionURI: settings.selectedEditionURI
                )

                if !Task.isCancelled {
                    await MainActor.run {
                        self.results = searchResults
                        self.isSearching = false

                        // Select the first result if available
                        if self.selectedResult == nil, let first = searchResults.first {
                            self.selectedResult = first
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.results = []
                        self.isSearching = false
                        if let nsError = error as NSError?, nsError.code == NSURLErrorCancelled {
                            // Ignore cancellation errors
                        } else {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    /// Inserts the selected result into the active application.
    ///
    /// Formats the result according to the current settings, copies it
    /// to the clipboard, and simulates Cmd+V to paste.
    func insertSelected() {
        guard let result = selectedResult else {
            AppLog.warning(AppLog.ui, "insertSelected called with no selection")
            return
        }

        // Format the result
        let formatted = result.formatted(as: settings.selectedFormat)

        AppLog.info(AppLog.ui, "Inserting concept: \(result.code) as '\(formatted)'")

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(formatted, forType: .string)

        // Close the panel first so the previous app can receive focus
        onInsertComplete?()

        // Small delay to allow window to close and focus to shift
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Restore focus to the previous app
            self?.previousApp?.activate()

            // Send Cmd+V after another small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                if !self.selectionReader.sendCmdV() {
                    AppLog.error(AppLog.ui, "Failed to send Cmd+V - accessibility permission may be missing")
                }
            }
        }
    }

    /// Clears the search state.
    ///
    /// Called when the panel is closed to reset for next use.
    func clearState() {
        searchText = ""
        results = []
        selectedResult = nil
        errorMessage = nil
        isSearching = false
        currentSearchTask?.cancel()
        currentSearchTask = nil
    }

    // MARK: - Private Methods

    /// Sets up debounced search triggered by searchText or edition changes.
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(debounceDelay), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.search()
            }
            .store(in: &cancellables)

        // Re-search when the edition selection changes
        settings.$selectedEditionURI
            .dropFirst()  // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.search()
            }
            .store(in: &cancellables)
    }
}
