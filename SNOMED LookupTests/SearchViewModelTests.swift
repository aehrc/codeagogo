import XCTest
import Combine
@testable import SNOMED_Lookup

/// Mock implementation of `ConceptSearching` for deterministic testing.
///
/// Allows tests to control search results, editions, and error conditions
/// without hitting the live FHIR server.
final class MockConceptSearchClient: ConceptSearching {
    /// The results to return from `searchConcepts`.
    var searchResults: [SearchResult] = []

    /// The editions to return from `getAvailableEditions`.
    var editions: [SNOMEDEdition] = []

    /// If set, `searchConcepts` will throw this error.
    var searchError: Error?

    /// If set, `getAvailableEditions` will throw this error.
    var editionsError: Error?

    /// Number of times `searchConcepts` was called.
    var searchCallCount = 0

    /// The most recent filter passed to `searchConcepts`.
    var lastSearchFilter: String?

    /// The most recent edition URI passed to `searchConcepts`.
    var lastEditionURI: String?

    /// Optional delay before returning search results (seconds).
    var searchDelay: TimeInterval = 0

    func searchConcepts(filter: String, editionURI: String?, count: Int) async throws -> [SearchResult] {
        searchCallCount += 1
        lastSearchFilter = filter
        lastEditionURI = editionURI

        if searchDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(searchDelay * 1_000_000_000))
        }

        if let error = searchError {
            throw error
        }
        return searchResults
    }

    func getAvailableEditions() async throws -> [SNOMEDEdition] {
        if let error = editionsError {
            throw error
        }
        return editions
    }
}

/// Unit tests for `SearchViewModel` using a mock client.
///
/// Tests cover search triggering, result population, auto-selection,
/// state clearing, error handling, and format output.
@MainActor
final class SearchViewModelTests: XCTestCase {

    private var mockClient: MockConceptSearchClient!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockClient = MockConceptSearchClient()
        cancellables = []
    }

    override func tearDown() {
        mockClient = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Creates a `SearchViewModel` with the mock client injected.
    private func makeViewModel() -> SearchViewModel {
        SearchViewModel(client: mockClient)
    }

    /// Creates a sample search result for testing.
    private func sampleResult(
        code: String = "73211009",
        display: String = "Diabetes mellitus",
        fsn: String? = "Diabetes mellitus (disorder)"
    ) -> SearchResult {
        SearchResult(
            code: code,
            display: display,
            fsn: fsn,
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/900000000000207008/version/20240101",
            editionName: "International"
        )
    }

    // MARK: - Search Triggering

    func testSearchTriggersAfterTextChange() async throws {
        let vm = makeViewModel()
        mockClient.searchResults = [sampleResult()]

        vm.searchText = "diabetes"

        // Wait for debounce (300ms) plus processing time
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertGreaterThanOrEqual(mockClient.searchCallCount, 1,
                                    "Search should have been called after text change")
        XCTAssertEqual(mockClient.lastSearchFilter, "diabetes")
    }

    func testEmptySearchTextReturnsNoResults() async throws {
        let vm = makeViewModel()
        mockClient.searchResults = [sampleResult()]

        // First trigger a search
        vm.searchText = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        // Now clear the text
        vm.searchText = ""
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertTrue(vm.results.isEmpty,
                      "Results should be empty when search text is cleared")
    }

    // MARK: - Results Population

    func testResultsPopulateFromMockResponse() async throws {
        let vm = makeViewModel()
        let results = [
            sampleResult(code: "73211009", display: "Diabetes mellitus"),
            sampleResult(code: "387517004", display: "Paracetamol")
        ]
        mockClient.searchResults = results

        vm.searchText = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(vm.results.count, 2,
                       "Should have 2 results from mock")
        XCTAssertEqual(vm.results.first?.code, "73211009")
        XCTAssertEqual(vm.results.last?.code, "387517004")
    }

    func testFirstResultAutoSelected() async throws {
        let vm = makeViewModel()
        mockClient.searchResults = [
            sampleResult(code: "73211009", display: "Diabetes mellitus"),
            sampleResult(code: "387517004", display: "Paracetamol")
        ]

        vm.searchText = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertNotNil(vm.selectedResult,
                        "First result should be auto-selected")
        XCTAssertEqual(vm.selectedResult?.code, "73211009",
                       "Selected result should be the first result")
    }

    // MARK: - State Management

    func testClearStateResetsAllProperties() async throws {
        let vm = makeViewModel()
        mockClient.searchResults = [sampleResult()]

        // Set up some state
        vm.searchText = "diabetes"
        try await Task.sleep(nanoseconds: 600_000_000)

        // Verify state is populated
        XCTAssertFalse(vm.searchText.isEmpty)
        XCTAssertFalse(vm.results.isEmpty)

        // Clear state
        vm.clearState()

        XCTAssertTrue(vm.searchText.isEmpty, "searchText should be empty")
        XCTAssertTrue(vm.results.isEmpty, "results should be empty")
        XCTAssertNil(vm.selectedResult, "selectedResult should be nil")
        XCTAssertNil(vm.errorMessage, "errorMessage should be nil")
        XCTAssertFalse(vm.isSearching, "isSearching should be false")
    }

    // MARK: - Error Handling

    func testErrorMessageSetOnFailure() async throws {
        let vm = makeViewModel()
        mockClient.searchError = NSError(
            domain: "TestError",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Server error"]
        )

        vm.searchText = "test"
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertNotNil(vm.errorMessage,
                        "Error message should be set when search fails")
        XCTAssertTrue(vm.results.isEmpty,
                      "Results should be empty on error")
    }

    // MARK: - Loading State

    func testLoadingStateTransitions() async throws {
        let vm = makeViewModel()
        mockClient.searchDelay = 0.3
        mockClient.searchResults = [sampleResult()]

        // Manually trigger search to observe isSearching
        vm.searchText = "test"
        try await Task.sleep(nanoseconds: 400_000_000)

        // After debounce fires, isSearching should be true during the request
        // (search delay is 0.3s, so at 0.4s the search should have started)
        // Note: This is inherently racy; we check that isSearching
        // eventually becomes false when done.
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertFalse(vm.isSearching,
                       "isSearching should be false after search completes")
    }

    // MARK: - Edition Loading

    func testLoadEditionsPopulatesAvailableEditions() async throws {
        let vm = makeViewModel()
        mockClient.editions = [
            SNOMEDEdition(
                system: "http://snomed.info/sct",
                version: "http://snomed.info/sct/32506021000036107",
                title: "Australian"
            ),
            SNOMEDEdition(
                system: "http://snomed.info/sct",
                version: "http://snomed.info/sct/731000124108",
                title: "United States"
            )
        ]

        vm.loadEditions()

        // Wait for async loading
        try await Task.sleep(nanoseconds: 500_000_000)

        // availableEditions includes the mock editions plus the
        // International edition added by the ViewModel
        XCTAssertGreaterThanOrEqual(vm.availableEditions.count, 2,
                                    "Should have at least the mock editions")
        XCTAssertFalse(vm.isLoadingEditions,
                       "Should not be loading after completion")
    }

    // MARK: - Format Output

    func testSearchResultFormattedAsIdOnly() throws {
        let result = sampleResult()
        XCTAssertEqual(result.formatted(as: .idOnly), "73211009")
    }

    func testSearchResultFormattedAsIdPipePT() throws {
        let result = sampleResult()
        XCTAssertEqual(result.formatted(as: .idPipePT), "73211009 | Diabetes mellitus |")
    }
}
