import Foundation
import os

// MARK: - Concept Result Model

/// The result of looking up a SNOMED CT concept from the terminology server.
///
/// `ConceptResult` encapsulates all relevant metadata returned from a FHIR
/// `CodeSystem/$lookup` operation, including the concept's terms, status,
/// and edition information.
///
/// ## Example
///
/// ```swift
/// let result = ConceptResult(
///     conceptId: "73211009",
///     branch: "International (20240101)",
///     fsn: "Diabetes mellitus (disorder)",
///     pt: "Diabetes mellitus",
///     active: true,
///     effectiveTime: "20020131",
///     moduleId: "900000000000207008"
/// )
///
/// print(result.fsn ?? "Unknown")  // "Diabetes mellitus (disorder)"
/// print(result.activeText)        // "active"
/// ```
struct ConceptResult {
    /// The SNOMED CT concept identifier (6-18 digits).
    let conceptId: String

    /// Human-readable edition name with version date.
    ///
    /// Examples: "International (20240101)", "Australian (20231130)"
    let branch: String

    /// The Fully Specified Name — the unambiguous term with semantic tag.
    ///
    /// Example: "Diabetes mellitus (disorder)"
    let fsn: String?

    /// The Preferred Term — the commonly used clinical term.
    ///
    /// Example: "Diabetes mellitus"
    let pt: String?

    /// Whether the concept is currently active in SNOMED CT.
    ///
    /// - `true`: The concept is active and can be used
    /// - `false`: The concept is inactive/retired
    /// - `nil`: Status information was not available
    let active: Bool?

    /// The effective date when this concept version was published.
    ///
    /// Format: YYYYMMDD (e.g., "20020131")
    let effectiveTime: String?

    /// The SNOMED CT module that contains this concept.
    ///
    /// Example: "900000000000207008" (International Core Module)
    let moduleId: String?

    /// Human-readable representation of the active status.
    ///
    /// - Returns: "active", "inactive", or "—" if unknown
    var activeText: String {
        switch active {
        case true: return "active"
        case false: return "inactive"
        default: return "—"
        }
    }
}

// MARK: - Constants

private enum SNOMEDConstants {
    /// SNOMED CT International Edition module ID
    static let internationalEditionId = "900000000000207008"
    /// SNOMED CT FSN (Fully Specified Name) designation type ID
    static let fsnDesignationCode = "900000000000003001"
}

private enum NetworkConstants {
    /// Cache TTL: 6 hours in seconds
    static let cacheTTL: TimeInterval = 6 * 60 * 60
    /// Maximum retry attempts for transient failures
    static let maxRetries = 2
    /// Base delay for exponential backoff (doubles each retry)
    static let baseRetryDelay: TimeInterval = 0.5
    /// HTTP request timeout in seconds
    static let requestTimeout: TimeInterval = 30
}

// MARK: - Client Errors

/// Errors that can occur when communicating with the FHIR terminology server.
///
/// These errors represent failures in the lookup process that should be
/// displayed to the user with appropriate guidance.
enum OntoserverError: LocalizedError {
    /// Failed to construct a valid URL for the API request.
    ///
    /// This typically indicates a configuration issue with the FHIR endpoint
    /// or invalid query parameters.
    case invalidURL(String)

    /// The concept ID was not found in any available SNOMED CT edition.
    ///
    /// The associated value contains the concept ID that was searched for.
    case conceptNotFound(String)

    /// No SNOMED CT editions were returned by the server.
    ///
    /// This may indicate a server configuration issue or connectivity problem.
    case noEditionsFound

    var errorDescription: String? {
        switch self {
        case .invalidURL(let details):
            return "Failed to construct request URL: \(details)"
        case .conceptNotFound(let conceptId):
            return "Concept \(conceptId) not found in any SNOMED edition"
        case .noEditionsFound:
            return "No SNOMED editions found on server"
        }
    }
}

// MARK: - ConceptSearching Protocol

/// Protocol for searching SNOMED CT concepts and retrieving editions.
///
/// Used by `SearchViewModel` for dependency injection and testability.
/// The default implementation is `OntoserverClient`.
///
/// Marked `Sendable` to allow use across actor boundaries.
protocol ConceptSearching: Sendable {
    /// Searches for SNOMED CT concepts matching a text filter.
    ///
    /// - Parameters:
    ///   - filter: The search text to match against concept terms
    ///   - editionURI: Optional edition URI to limit search; nil = all editions
    ///   - count: Maximum number of results to return
    /// - Returns: Array of matching concepts
    /// - Throws: Network or parsing errors
    func searchConcepts(filter: String, editionURI: String?, count: Int) async throws -> [SearchResult]

    /// Returns all available SNOMED CT editions from the server.
    ///
    /// - Returns: Array of available editions
    /// - Throws: Network or parsing errors
    func getAvailableEditions() async throws -> [SNOMEDEdition]
}

extension ConceptSearching {
    /// Searches with a default count of 30.
    func searchConcepts(filter: String, editionURI: String?) async throws -> [SearchResult] {
        try await searchConcepts(filter: filter, editionURI: editionURI, count: 30)
    }
}

// MARK: - FHIR Client

/// Client for looking up SNOMED CT concepts via a FHIR R4 terminology server.
///
/// `OntoserverClient` communicates with FHIR terminology servers (primarily CSIRO
/// Ontoserver) to retrieve concept details using the `CodeSystem/$lookup` operation.
///
/// ## Lookup Strategy
///
/// The client uses a multi-step lookup strategy for efficiency:
///
/// 1. **Check cache** — Return immediately if the concept is cached and not expired
/// 2. **Try International Edition** — Most concepts are in the International Edition
/// 3. **Parallel edition search** — If not found, search all available editions concurrently
///
/// ## Caching
///
/// Results are cached in memory with a 6-hour TTL and LRU eviction at 100 entries.
/// The cache is thread-safe using a Swift actor.
///
/// ## Retry Logic
///
/// Transient network failures (timeouts, connection issues, 5xx errors) are
/// automatically retried up to 2 times with exponential backoff.
///
/// ## Usage
///
/// ```swift
/// let client = OntoserverClient()
///
/// do {
///     let result = try await client.lookup(conceptId: "73211009")
///     print("FSN: \(result.fsn ?? "Unknown")")
///     print("PT: \(result.pt ?? "Unknown")")
/// } catch OntoserverError.conceptNotFound(let id) {
///     print("Concept \(id) not found")
/// }
/// ```
///
/// ## Thread Safety
///
/// This class is safe to use from any thread. Network operations use
/// async/await, and the cache is protected by a Swift actor.
final class OntoserverClient: ConceptSearching, @unchecked Sendable {
    /// The base URL for FHIR API requests, read from user settings.
    /// Uses the thread-safe static accessor to avoid MainActor isolation issues.
    private var baseURL: URL { FHIROptions.currentBaseURL }

    /// The URL session used for network requests.
    private let session: URLSession

    /// Thread-safe LRU cache for lookup results.
    private let cache = ConceptCache()

    /// Creates a new Ontoserver client.
    ///
    /// - Parameter session: The URL session to use for requests. Defaults to `.shared`.
    init(session: URLSession = .shared) {
        self.session = session
        AppLog.info(AppLog.network, "OntoserverClient init base=\(baseURL.absoluteString)")
    }

    /// Looks up a SNOMED CT concept by its identifier.
    ///
    /// This method implements a multi-step lookup strategy:
    /// 1. Returns cached result if available and not expired
    /// 2. Tries the International Edition first (most concepts are there)
    /// 3. Falls back to searching all available editions in parallel
    ///
    /// - Parameter conceptId: The SNOMED CT concept identifier (6-18 digits)
    /// - Returns: The concept details including FSN, PT, and status
    /// - Throws: `OntoserverError.conceptNotFound` if the concept doesn't exist
    ///           in any edition, or network errors if the server is unreachable
    func lookup(conceptId: String) async throws -> ConceptResult {
        if let cached = await cache.get(conceptId, ttl: NetworkConstants.cacheTTL) {
            AppLog.debug(AppLog.network, "cache hit conceptId=\(conceptId)")
            return cached
        }

        AppLog.info(AppLog.network, "lookup conceptId=\(conceptId)")

        // Step 1: Try latest international edition first
        if let result = try await lookupInSystem(conceptId: conceptId, system: "http://snomed.info/sct", version: "http://snomed.info/sct/" + SNOMEDConstants.internationalEditionId) {
            await cache.set(conceptId, result: result)
            AppLog.info(AppLog.network, "lookup success in international edition conceptId=\(conceptId)")
            return result
        }

        AppLog.info(AppLog.network, "not found in international edition, trying all editions conceptId=\(conceptId)")

        // Step 2: Get all SNOMED CT editions
        let editions = try await fetchAllEditions()

        // Step 3: Look up in all editions in parallel
        let result = try await lookupInAllEditions(conceptId: conceptId, editions: editions)

        await cache.set(conceptId, result: result)
        AppLog.info(AppLog.network, "lookup success conceptId=\(conceptId) edition=\(result.branch)")
        return result
    }

    // MARK: - Batch Lookup (ValueSet/$expand)

    /// Result of a batch lookup operation containing display names for multiple concepts.
    struct BatchLookupResult {
        /// Map from concept ID to its preferred term (display name).
        let ptByCode: [String: String]
        /// Map from concept ID to its fully specified name.
        let fsnByCode: [String: String]

        /// Returns the PT for a code, or nil if not found.
        func pt(for code: String) -> String? { ptByCode[code] }
        /// Returns the FSN for a code, or nil if not found.
        func fsn(for code: String) -> String? { fsnByCode[code] }
    }

    /// Looks up multiple SNOMED CT concepts in a single batch request.
    ///
    /// Uses `ValueSet/$expand` with explicit code inclusion to efficiently look up
    /// display names for multiple concepts in one API call. This is significantly
    /// faster than individual lookups when processing many codes.
    ///
    /// ## Caching
    ///
    /// This method integrates with the existing concept cache:
    /// 1. Checks the cache first and returns cached results immediately
    /// 2. Only requests uncached codes from the server
    /// 3. Stores newly fetched results in the cache for future lookups
    ///
    /// - Parameter conceptIds: Array of SNOMED CT concept identifiers to look up
    /// - Returns: A `BatchLookupResult` containing PT and FSN for each found concept
    /// - Throws: Network or parsing errors
    ///
    /// ## Performance
    ///
    /// A single batch request for 62 codes takes ~0.5 seconds, compared to ~7+ seconds
    /// for individual lookups (14x faster). Cached results are returned instantly.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let client = OntoserverClient()
    /// let result = try await client.batchLookup(conceptIds: ["73211009", "385804009"])
    ///
    /// print(result.pt(for: "73211009"))  // "Diabetes mellitus"
    /// print(result.fsn(for: "73211009")) // "Diabetes mellitus (disorder)"
    /// ```
    func batchLookup(conceptIds: [String]) async throws -> BatchLookupResult {
        guard !conceptIds.isEmpty else {
            return BatchLookupResult(ptByCode: [:], fsnByCode: [:])
        }

        // Check cache first and collect results for cached concepts
        var ptByCode: [String: String] = [:]
        var fsnByCode: [String: String] = [:]
        var uncachedIds: [String] = []

        for conceptId in conceptIds {
            if let cached = await cache.get(conceptId, ttl: NetworkConstants.cacheTTL) {
                if let pt = cached.pt { ptByCode[conceptId] = pt }
                if let fsn = cached.fsn { fsnByCode[conceptId] = fsn }
            } else {
                uncachedIds.append(conceptId)
            }
        }

        let cachedCount = conceptIds.count - uncachedIds.count
        if cachedCount > 0 {
            AppLog.debug(AppLog.network, "batchLookup cache hits=\(cachedCount)")
        }

        // If all concepts were cached, return early
        if uncachedIds.isEmpty {
            AppLog.info(AppLog.network, "batchLookup all \(conceptIds.count) concepts from cache")
            return BatchLookupResult(ptByCode: ptByCode, fsnByCode: fsnByCode)
        }

        AppLog.info(AppLog.network, "batchLookup requesting \(uncachedIds.count) uncached concepts")

        // Build the request body with uncached codes only
        let requestBody = buildBatchLookupRequestBody(conceptIds: uncachedIds)

        // Make the POST request
        let url = baseURL.appendingPathComponent("ValueSet/$expand")
        let response: ValueSetExpansionResponse = try await postJSON(url, body: requestBody)

        // Parse the results and merge with cached results
        let fetchedResults = parseBatchLookupResults(from: response)

        // Store fetched results in cache and merge into result
        for (code, pt) in fetchedResults.ptByCode {
            ptByCode[code] = pt

            // Create a minimal ConceptResult for caching
            let fsn = fetchedResults.fsnByCode[code]
            let cachedResult = ConceptResult(
                conceptId: code,
                branch: "batch-lookup",  // Marker to indicate this came from batch lookup
                fsn: fsn,
                pt: pt,
                active: nil,
                effectiveTime: nil,
                moduleId: nil
            )
            await cache.set(code, result: cachedResult)
        }

        for (code, fsn) in fetchedResults.fsnByCode {
            fsnByCode[code] = fsn
        }

        AppLog.info(AppLog.network, "batchLookup found \(fetchedResults.ptByCode.count) new concepts, total \(ptByCode.count)")
        return BatchLookupResult(ptByCode: ptByCode, fsnByCode: fsnByCode)
    }

    /// Builds the FHIR Parameters request body for batch lookup via ValueSet/$expand.
    private func buildBatchLookupRequestBody(conceptIds: [String]) -> [String: Any] {
        // Build the concept array with explicit codes
        let concepts: [[String: String]] = conceptIds.map { ["code": $0] }

        let valueSetResource: [String: Any] = [
            "resourceType": "ValueSet",
            "compose": [
                "include": [
                    [
                        "system": "http://snomed.info/sct",
                        "concept": concepts
                    ]
                ]
            ]
        ]

        let parameters: [[String: Any]] = [
            ["name": "valueSet", "resource": valueSetResource],
            ["name": "includeDesignations", "valueBoolean": true]
        ]

        return [
            "resourceType": "Parameters",
            "parameter": parameters
        ]
    }

    /// Parses batch lookup results from a ValueSet expansion response.
    private func parseBatchLookupResults(from response: ValueSetExpansionResponse) -> BatchLookupResult {
        var ptByCode: [String: String] = [:]
        var fsnByCode: [String: String] = [:]

        guard let contains = response.expansion?.contains else {
            return BatchLookupResult(ptByCode: ptByCode, fsnByCode: fsnByCode)
        }

        for item in contains {
            guard let code = item.code else { continue }

            // The display field contains the preferred term
            if let display = item.display {
                ptByCode[code] = display
            }

            // Extract FSN from designations (use code 900000000000003001)
            if let designations = item.designation {
                for designation in designations {
                    if designation.use?.code == SNOMEDConstants.fsnDesignationCode {
                        fsnByCode[code] = designation.value
                        break
                    }
                }
            }
        }

        AppLog.info(AppLog.network, "batchLookup found \(ptByCode.count) concepts")
        return BatchLookupResult(ptByCode: ptByCode, fsnByCode: fsnByCode)
    }

    // MARK: - Search (ValueSet/$expand)

    /// Searches for SNOMED CT concepts matching a text filter.
    ///
    /// Uses the `ValueSet/$expand` operation with a filter to find concepts
    /// across one or more SNOMED CT editions.
    ///
    /// - Parameters:
    ///   - filter: The search text to match against concept terms
    ///   - editionURI: Optional edition URI to limit search; nil = all editions
    ///   - count: Maximum number of results to return (default: 30)
    /// - Returns: Array of matching concepts with PT, FSN, and edition info
    /// - Throws: Network or parsing errors
    func searchConcepts(filter: String, editionURI: String?, count: Int = 30) async throws -> [SearchResult] {
        guard !filter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        AppLog.info(AppLog.network, "searchConcepts filter=\(filter) editionURI=\(editionURI ?? "all")")

        // Fetch all editions for both the request and name resolution
        let allEditions = try await fetchAllEditions()

        // Add International edition (it's filtered out in fetchAllEditions)
        let international = SNOMEDEdition(
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/\(SNOMEDConstants.internationalEditionId)",
            title: "International"
        )
        let allEditionsWithInternational = [international] + allEditions

        // Build the list of editions to include in the search
        let editionsToInclude: [SNOMEDEdition]
        if let specificURI = editionURI {
            // Single edition selected - look up from fetched editions for correct system URL
            if let matched = allEditionsWithInternational.first(where: { $0.version == specificURI }) {
                editionsToInclude = [matched]
            } else {
                editionsToInclude = [SNOMEDEdition(system: "http://snomed.info/sct", version: specificURI, title: "")]
            }
        } else {
            // All editions
            editionsToInclude = allEditionsWithInternational
        }

        // Build the request body
        let requestBody = buildExpandRequestBody(filter: filter, editions: editionsToInclude, count: count)

        AppLog.debug(AppLog.network, "searchConcepts editions=\(editionsToInclude.map { $0.version })")

        // Make the POST request
        let url = baseURL.appendingPathComponent("ValueSet/$expand")
        let response: ValueSetExpansionResponse = try await postJSON(url, body: requestBody)

        // Parse and deduplicate the results
        return parseSearchResults(from: response, allEditions: allEditionsWithInternational)
    }

    /// Returns all available SNOMED CT editions from the server.
    ///
    /// This is exposed publicly for the search panel to populate the edition picker.
    ///
    /// - Returns: Array of available editions (excluding International, which is handled separately)
    /// - Throws: Network or parsing errors
    func getAvailableEditions() async throws -> [SNOMEDEdition] {
        try await fetchAllEditions()
    }

    /// Builds the FHIR Parameters request body for ValueSet/$expand.
    private func buildExpandRequestBody(filter: String, editions: [SNOMEDEdition], count: Int) -> [String: Any] {
        // Build the compose.include array
        var includes: [[String: String]] = []
        for edition in editions {
            includes.append([
                "system": edition.system,
                "version": edition.version
            ])
        }

        let valueSetResource: [String: Any] = [
            "resourceType": "ValueSet",
            "compose": [
                "include": includes
            ]
        ]

        let parameters: [[String: Any]] = [
            ["name": "filter", "valueString": filter],
            ["name": "valueSet", "resource": valueSetResource],
            ["name": "count", "valueInteger": count],
            ["name": "activeOnly", "valueBoolean": true],
            ["name": "includeDesignations", "valueBoolean": true]
        ]

        return [
            "resourceType": "Parameters",
            "parameter": parameters
        ]
    }

    /// Parses search results from a ValueSet expansion response.
    ///
    /// Results are deduplicated by code, keeping only the first occurrence.
    ///
    /// When searching a single edition, the server may omit the `version` field
    /// from results. In that case, the version and edition name are inferred
    /// from the searched editions.
    private func parseSearchResults(from response: ValueSetExpansionResponse, allEditions: [SNOMEDEdition]) -> [SearchResult] {
        guard let contains = response.expansion?.contains else {
            return []
        }

        // Build edition name map from static dictionary + fetched editions
        var editionNames = Self.editionNamesByModuleId
        for edition in allEditions {
            // Extract edition ID from version URI (e.g., "http://snomed.info/sct/123" -> "123")
            let components = edition.version.split(separator: "/")
            if components.count >= 4 {
                let editionId = String(components[3])
                // Only add if not already in static dictionary (static names take precedence)
                if editionNames[editionId] == nil {
                    editionNames[editionId] = edition.title
                }
            }
        }

        // Extract used-codesystem parameters for version fallback.
        // Format: "http://snomed.info/sct|http://snomed.info/sct/32506021000036107/version/20260131"
        // Build a map from system URI to the full version URI (with date).
        var usedCodeSystemVersions: [String: String] = [:]
        if let parameters = response.expansion?.parameter {
            for param in parameters where param.name == "used-codesystem" {
                guard let valueUri = param.valueUri else { continue }
                let parts = valueUri.split(separator: "|", maxSplits: 1)
                if parts.count == 2 {
                    let systemURI = String(parts[0])
                    let versionURI = String(parts[1])
                    usedCodeSystemVersions[systemURI] = versionURI
                }
            }
        }

        // Parse results and deduplicate by code
        var seenCodes = Set<String>()
        var results: [SearchResult] = []

        for item in contains {
            guard let code = item.code,
                  let display = item.display else {
                continue
            }

            // Skip duplicates
            if seenCodes.contains(code) {
                continue
            }
            seenCodes.insert(code)

            let system = item.system ?? "http://snomed.info/sct"

            // Use item version if present, otherwise fall back to used-codesystem version
            let version = item.version ?? usedCodeSystemVersions[system] ?? ""

            // Extract FSN from designations
            let fsn = item.designation?.first(where: { designation in
                designation.use?.code == SNOMEDConstants.fsnDesignationCode
            })?.value

            // Derive edition name from version
            let editionName = deriveEditionName(from: version, editionNames: editionNames)

            results.append(SearchResult(
                code: code,
                display: display,
                fsn: fsn,
                system: system,
                version: version,
                editionName: editionName
            ))
        }

        return results
    }

    /// Map of known SNOMED CT edition module IDs to human-readable names.
    ///
    /// Used to derive display names for editions. Falls back to the
    /// CodeSystem.title from the server for unknown edition IDs.
    private static let editionNamesByModuleId: [String: String] = [
        // International
        "900000000000207008": "International",
        // National editions
        "11000221109": "Argentine",
        "32506021000036107": "Australian",
        "11000234105": "Austrian",
        "11000172109": "Belgian",
        "20611000087101": "Canadian",
        "554471000005108": "Danish",
        "11000181102": "Estonian",
        "11000315107": "French",
        "11000274103": "German",
        "11000220105": "Irish",
        "11000318109": "Jamaican",
        "450829007": "Latin American Spanish",
        "11000146104": "Netherlands",
        "21000210109": "New Zealand",
        "51000202101": "Norwegian",
        "900000001000122104": "Spanish",
        "45991000052106": "Swedish",
        "2011000195101": "Swiss",
        "83821000000107": "United Kingdom composition module",
        "999000041000000102": "United Kingdom",
        "999000011000000103": "United Kingdom Clinical",
        "999000021000000109": "United Kingdom Drug",
        "731000124108": "United States",
        "5631000179106": "Uruguayan",
        // Special-purpose modules
        "999991001000101": "IPS Terminology",
        "11010000107": "LOINC Extension",
        "332351000009108": "Veterinary Extension",
    ]

    /// Derives a human-readable edition name from a version URI.
    private func deriveEditionName(from version: String, editionNames: [String: String]) -> String {
        // Version format: http://snomed.info/sct/<editionId>/version/<date>
        let components = version.split(separator: "/")
        guard components.count >= 4 else {
            return "Unknown"
        }

        let editionId = String(components[3])
        return editionNames[editionId] ?? editionId
    }

    /// Performs a POST request with JSON body and decodes the response.
    private func postJSON<T: Decodable>(_ url: URL, body: [String: Any]) async throws -> T {
        var lastError: Error?

        for attempt in 0...NetworkConstants.maxRetries {
            if attempt > 0 {
                let delay = NetworkConstants.baseRetryDelay * pow(2.0, Double(attempt - 1))
                AppLog.info(AppLog.network, "retry attempt=\(attempt)/\(NetworkConstants.maxRetries) delay=\(delay)s url=\(url.absoluteString)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                return try await performPostRequest(url, body: body)
            } catch {
                lastError = error

                // Only retry on transient errors
                if !isRetryableError(error) {
                    throw error
                }

                if attempt == NetworkConstants.maxRetries {
                    AppLog.error(AppLog.network, "all retries exhausted url=\(url.absoluteString)")
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Performs the actual POST request.
    private func performPostRequest<T: Decodable>(_ url: URL, body: [String: Any]) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        req.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = NetworkConstants.requestTimeout

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        req.httpBody = jsonData

        AppLog.debug(AppLog.network, "request POST url=\(url.absoluteString)")

        do {
            let (data, resp) = try await session.data(for: req)

            if let http = resp as? HTTPURLResponse {
                AppLog.info(AppLog.network, "response status=\(http.statusCode) url=\(url.absoluteString)")
            } else {
                AppLog.warning(AppLog.network, "response non-HTTP url=\(url.absoluteString)")
            }

            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                let bodySnippet = AppLog.snippet(responseBody, limit: 2000)

                AppLog.error(AppLog.network, "HTTP error code=\(code) url=\(url.absoluteString) body=\(bodySnippet)")

                throw NSError(
                    domain: "OntoserverClient",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(code): \(bodySnippet)"]
                )
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                let bodySnippet = AppLog.snippet(responseBody, limit: 2000)

                AppLog.error(AppLog.network, "decode error url=\(url.absoluteString) error=\(error.localizedDescription) body=\(bodySnippet)")
                throw error
            }

        } catch let urlError as URLError {
            AppLog.error(
                AppLog.network,
                "URLError url=\(url.absoluteString) code=\(urlError.code.rawValue) desc=\(urlError.localizedDescription)"
            )
            throw urlError

        } catch {
            AppLog.error(AppLog.network, "error url=\(url.absoluteString) desc=\(error.localizedDescription)")
            throw error
        }
    }

    private func lookupInSystem(conceptId: String, system: String, version: String) async throws -> ConceptResult? {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("CodeSystem/$lookup"), resolvingAgainstBaseURL: false) else {
            throw OntoserverError.invalidURL("Cannot create URL components from base URL")
        }
        comps.queryItems = [
            URLQueryItem(name: "system", value: system),
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "code", value: conceptId),
            URLQueryItem(name: "_format", value: "json")
        ]

        guard let url = comps.url else {
            throw OntoserverError.invalidURL("Invalid query parameters for lookup request")
        }
        AppLog.debug(AppLog.network, "lookupInSystem request system=\(system) code=\(conceptId) url=\(url.absoluteString)")
        
        do {
            let response: FHIRParameters = try await getJSON(url)
            return parseConceptFromParameters(response, conceptId: conceptId, system: system)
        } catch let error as NSError where error.code == 404 {
            AppLog.debug(AppLog.network, "concept not found in system=\(system) code=\(conceptId)")
            return nil
        }
    }
    
    private func fetchAllEditions() async throws -> [SNOMEDEdition] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("CodeSystem"), resolvingAgainstBaseURL: false) else {
            throw OntoserverError.invalidURL("Cannot create URL components from base URL")
        }
        comps.queryItems = [
            // Look for both SCT and xSCT
            URLQueryItem(name: "url", value: "http://snomed.info/sct,http://snomed.info/xsct"),
            URLQueryItem(name: "_format", value: "json")
        ]

        guard let url = comps.url else {
            throw OntoserverError.invalidURL("Invalid query parameters for editions request")
        }
        AppLog.debug(AppLog.network, "fetchAllEditions request url=\(url.absoluteString)")

        let bundle: FHIRBundle = try await getJSON(url)

        guard let entries = bundle.entry, !entries.isEmpty else {
            AppLog.error(AppLog.network, "no SNOMED editions found")
            throw OntoserverError.noEditionsFound
        }

        // One CodeSystem per edition URI
        var editionMap: [String: CodeSystem] = [:]

        for entry in entries {
            guard let codeSystem = entry.resource else { continue }
            guard let rawVersion = codeSystem.version else { continue }
            guard let editionURI = extractEditionURI(from: rawVersion) else { continue }

            // Strip out the International edition (handled elsewhere)
            if editionURI.hasSuffix("/\(SNOMEDConstants.internationalEditionId)") {
                continue
            }

            editionMap[editionURI] = editionMap[editionURI] ?? codeSystem
        }

        var editions = editionMap.values.map { cs -> SNOMEDEdition in
            let version = extractEditionURI(from: cs.version ?? "") ?? "unknown-edition"
            // Extract module ID from version URI (e.g., "http://snomed.info/sct/32506021000036107" -> "32506021000036107")
            let components = version.split(separator: "/")
            let moduleId = components.count >= 4 ? String(components[3]) : nil
            // Prefer static name map, fall back to CodeSystem title from server
            let title = moduleId.flatMap({ Self.editionNamesByModuleId[$0] })
                ?? cs.title ?? cs.name ?? "Unknown Edition"
            return SNOMEDEdition(
                system: cs.url ?? "http://snomed.info/sct",
                version: version,
                title: title
            )
        }

        // Sort alphabetically by title, with xSCT editions at the bottom
        editions.sort {
            let systemOrder0 = systemSortKey($0.system)
            let systemOrder1 = systemSortKey($1.system)
            if systemOrder0 != systemOrder1 {
                return systemOrder0 < systemOrder1
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        AppLog.info(AppLog.network, "found \(editions.count) SNOMED editions")
        return editions
    }
    
    private func systemSortKey(_ system: String) -> Int {
        switch system {
        case "http://snomed.info/sct":
            return 0
        case "http://snomed.info/xsct":
            return 1
        default:
            return 2
        }
    }
    
    /// Converts a SNOMED version URI like:
    ///   http://snomed.info/sct/45991000052106/version/20221130
    /// into an edition URI:
    ///   http://snomed.info/sct/45991000052106
    private func extractEditionURI(from version: String) -> String? {
        guard !version.isEmpty else { return nil }
        // Split on "/version/" and keep the left side.
        let parts = version.components(separatedBy: "/version/")
        guard let left = parts.first, !left.isEmpty else { return nil }
        return left
    }

    /// Returns a sortable key for "latest" selection.
    /// For SNOMED URIs ending in .../version/YYYYMMDD it returns YYYYMMDD.
    /// Falls back to nil if it can't find it.
    private func extractVersionSortKey(from version: String?) -> String? {
        guard let version, !version.isEmpty else { return nil }
        // Expect final segment to be the date
        let parts = version.split(separator: "/")
        guard let last = parts.last, last.allSatisfy({ $0.isNumber }) else { return nil }
        return String(last)
    }
    
    private func lookupInAllEditions(conceptId: String, editions: [SNOMEDEdition]) async throws -> ConceptResult {
        // Look up in parallel using TaskGroup
        try await withThrowingTaskGroup(of: ConceptResult?.self) { group in
            for edition in editions {
                group.addTask {
                    try await self.lookupInSystem(conceptId: conceptId, system: edition.system, version: edition.version)
                }
            }
            
            // Return the first successful result
            for try await result in group {
                if let result = result {
                    // Cancel remaining tasks
                    group.cancelAll()
                    return result
                }
            }
            
            // If we get here, no edition had the concept
            AppLog.error(AppLog.network, "concept not found in any edition conceptId=\(conceptId)")
            throw OntoserverError.conceptNotFound(conceptId)
        }
    }
    
    private func parseConceptFromParameters(_ params: FHIRParameters, conceptId: String, system: String) -> ConceptResult? {
        var display: String?
        var fsn: String?
        var active: Bool?
        var effectiveTime: String?
        var moduleId: String?
        var version: String?
        
        for param in params.parameter ?? [] {
            switch param.name {
            case "version":
                version = param.valueString
            case "display":
                display = param.valueString
            case "property":
                if let parts = param.part {
                    var propCode: String?
                    var propValue: String?
                    
                    for part in parts {
                        if part.name == "code" {
                            propCode = part.valueCode
                        } else if part.name == "value" {
                            propValue = part.valueString ?? part.valueCode
                        }
                    }
                    
                    if let code = propCode {
                        switch code {
                        case "inactive":
                            active = propValue != "true"
                        case "effectiveTime":
                            effectiveTime = propValue
                        case "moduleId":
                            moduleId = propValue
                        default:
                            break
                        }
                    }
                }
            case "designation":
                if let parts = param.part {
                    var use: String?
                    var value: String?
                    
                    for part in parts {
                        if part.name == "use" {
                            use = part.valueCoding?.code
                        } else if part.name == "value" {
                            value = part.valueString
                        }
                    }
                    
                    // FSN has use code for Fully Specified Name
                    if use == SNOMEDConstants.fsnDesignationCode {
                        fsn = value
                    }
                }
            default:
                break
            }
        }
        
        // Use display as PT if we have it
        let pt = display
        
        // Extract edition name from system URL for the branch field, passing version
        let branch = extractEditionName(system: system, version: version)
        
        return ConceptResult(
            conceptId: conceptId,
            branch: branch,
            fsn: fsn,
            pt: pt,
            active: active,
            effectiveTime: effectiveTime,
            moduleId: moduleId
        )
    }
    
    private func extractEditionName(system: String, version: String?) -> String {
        let isExperimental = system.range(of: "xsct", options: .caseInsensitive) != nil
            || (version?.range(of: "xsct", options: .caseInsensitive) != nil)
        
        func mark(_ name: String) -> String {
            isExperimental ? "\(name) (experimental)" : name
        }
        
        // If version is provided and non-empty, use it
        // Format: http://snomed.info/sct/<editionId>/version/<date>
        // split() omits empty strings, so indices are: [0]=http: [1]=snomed.info [2]=sct [3]=editionId [4]=version [5]=date
        if let version = version, !version.isEmpty {
            let components = version.split(separator: "/")

            if components.count >= 6 {
                // Full form with /version/date suffix
                let editionId = String(components[3])
                let date = String(components[5])
                let humanReadableName = getEditionName(for: editionId)
                return mark("\(humanReadableName) (\(date))")
            } else if components.count >= 4 {
                // Short form without /version/date suffix
                let editionId = String(components[3])
                let humanReadableName = getEditionName(for: editionId)
                return mark(humanReadableName)
            }
            // Fallback if format doesn't match
            return mark("\(system) (\(version))")
        }

        // If no version provided, fallback to system URL parsing
        let components = system.split(separator: "/")

        if components.count >= 6 {
            // Full form with /version/date suffix
            let editionId = String(components[3])
            let date = String(components[5])
            let humanReadableName = getEditionName(for: editionId)
            return mark("\(humanReadableName) (\(date))")
        } else if components.count >= 4 {
            // Short form without /version/date suffix
            let editionId = String(components[3])
            let humanReadableName = getEditionName(for: editionId)
            return mark(humanReadableName)
        }
        
        // Default to international if it's just "http://snomed.info/sct"
        if system == "http://snomed.info/sct" {
            return "MAIN (International)"
        }
        
        return system
    }
    
    private func getEditionName(for editionId: String) -> String {
        Self.editionNamesByModuleId[editionId] ?? editionId
    }
    
    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var lastError: Error?

        for attempt in 0...NetworkConstants.maxRetries {
            if attempt > 0 {
                let delay = NetworkConstants.baseRetryDelay * pow(2.0, Double(attempt - 1))
                AppLog.info(AppLog.network, "retry attempt=\(attempt)/\(NetworkConstants.maxRetries) delay=\(delay)s url=\(url.absoluteString)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                return try await performRequest(url)
            } catch {
                lastError = error

                // Only retry on transient errors
                if !isRetryableError(error) {
                    throw error
                }

                if attempt == NetworkConstants.maxRetries {
                    AppLog.error(AppLog.network, "all retries exhausted url=\(url.absoluteString)")
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    private func performRequest<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = NetworkConstants.requestTimeout

        AppLog.debug(AppLog.network, "request GET url=\(url.absoluteString)")

        do {
            let (data, resp) = try await session.data(for: req)

            if let http = resp as? HTTPURLResponse {
                AppLog.info(AppLog.network, "response status=\(http.statusCode) url=\(url.absoluteString)")
            } else {
                AppLog.warning(AppLog.network, "response non-HTTP url=\(url.absoluteString)")
            }

            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? ""
                let bodySnippet = AppLog.snippet(body, limit: 2000)

                AppLog.error(AppLog.network, "HTTP error code=\(code) url=\(url.absoluteString) body=\(bodySnippet)")

                throw NSError(
                    domain: "OntoserverClient",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(code): \(bodySnippet)"]
                )
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                let bodySnippet = AppLog.snippet(body, limit: 2000)

                AppLog.error(AppLog.network, "decode error url=\(url.absoluteString) error=\(error.localizedDescription) body=\(bodySnippet)")
                throw error
            }

        } catch let urlError as URLError {
            AppLog.error(
                AppLog.network,
                "URLError url=\(url.absoluteString) code=\(urlError.code.rawValue) desc=\(urlError.localizedDescription)"
            )
            throw urlError

        } catch {
            AppLog.error(AppLog.network, "error url=\(url.absoluteString) desc=\(error.localizedDescription)")
            throw error
        }
    }

    /// Determines if an error is transient and worth retrying
    private func isRetryableError(_ error: Error) -> Bool {
        // Retry on URLError network issues
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .secureConnectionFailed:
                return true
            default:
                return false
            }
        }

        // Retry on 5xx server errors
        if let nsError = error as NSError?, nsError.domain == "OntoserverClient" {
            let code = nsError.code
            return code >= 500 && code < 600
        }

        return false
    }
}

// MARK: - Thread-Safe LRU Cache

/// Thread-safe in-memory cache for SNOMED CT concept lookup results.
///
/// `ConceptCache` uses Swift actors for thread safety and implements:
/// - **TTL expiration**: Entries expire after a configurable time-to-live
/// - **LRU eviction**: When at capacity, the least recently used entry is removed
///
/// ## Thread Safety
///
/// As a Swift actor, all method calls are serialized automatically. Safe to
/// call from any thread or task without external synchronization.
///
/// ## Example
///
/// ```swift
/// let cache = ConceptCache()
///
/// // Store a result
/// await cache.set("73211009", result: conceptResult)
///
/// // Retrieve with 6-hour TTL
/// if let cached = await cache.get("73211009", ttl: 6 * 60 * 60) {
///     print("Cache hit!")
/// }
/// ```
private actor ConceptCache {
    /// Maximum number of cached concept results before LRU eviction.
    private let maxSize = 100

    /// Internal cache entry with timestamps for TTL and LRU tracking.
    private struct CacheEntry {
        /// The cached concept result.
        let result: ConceptResult
        /// When this entry was first created (for TTL).
        let createdAt: Date
        /// When this entry was last accessed (for LRU eviction).
        var lastAccessedAt: Date
    }

    /// The underlying storage dictionary keyed by concept ID.
    private var storage: [String: CacheEntry] = [:]

    /// Retrieves a cached concept result if it exists and hasn't expired.
    ///
    /// This method also updates the last accessed time for LRU tracking.
    ///
    /// - Parameters:
    ///   - conceptId: The SNOMED CT concept identifier to look up
    ///   - ttl: Time-to-live in seconds; entries older than this are considered expired
    /// - Returns: The cached result, or `nil` if not found or expired
    func get(_ conceptId: String, ttl: TimeInterval) -> ConceptResult? {
        guard var entry = storage[conceptId],
              Date().timeIntervalSince(entry.createdAt) < ttl else {
            // Remove expired entry if it exists
            storage.removeValue(forKey: conceptId)
            return nil
        }
        // Update last accessed time for LRU tracking
        entry.lastAccessedAt = Date()
        storage[conceptId] = entry
        return entry.result
    }

    /// Stores a concept result in the cache.
    ///
    /// If the cache is at capacity and this is a new entry (not an update),
    /// the least recently used entry is evicted first.
    ///
    /// - Parameters:
    ///   - conceptId: The SNOMED CT concept identifier as the cache key
    ///   - result: The concept result to cache
    func set(_ conceptId: String, result: ConceptResult) {
        // If at capacity and this is a new entry, evict the least recently used
        if storage[conceptId] == nil && storage.count >= maxSize {
            evictLeastRecentlyUsed()
        }

        let now = Date()
        storage[conceptId] = CacheEntry(
            result: result,
            createdAt: now,
            lastAccessedAt: now
        )
    }

    /// Removes the least recently used entry from the cache.
    ///
    /// Called automatically when the cache reaches capacity and a new entry
    /// needs to be added.
    private func evictLeastRecentlyUsed() {
        guard let lruKey = storage.min(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?.key else {
            return
        }
        storage.removeValue(forKey: lruKey)
    }

    /// Returns the current number of cached entries.
    ///
    /// Primarily used for testing cache behavior.
    func count() -> Int {
        storage.count
    }
}

// MARK: - FHIR Data Structures

/// FHIR Parameters resource returned by the `CodeSystem/$lookup` operation.
///
/// Contains an array of named parameters with values representing
/// the concept's properties, designations, and metadata.
///
/// - SeeAlso: [FHIR Parameters](https://hl7.org/fhir/R4/parameters.html)
struct FHIRParameters: Decodable {
    let resourceType: String
    let parameter: [Parameter]?

    /// A single parameter within the Parameters resource.
    struct Parameter: Decodable {
        let name: String
        let valueString: String?
        let valueCode: String?
        let valueCoding: Coding?
        let part: [Part]?
    }

    /// A nested part within a parameter (used for complex properties).
    struct Part: Decodable {
        let name: String
        let valueString: String?
        let valueCode: String?
        let valueCoding: Coding?
    }

    /// A FHIR Coding data type representing a code from a code system.
    struct Coding: Decodable {
        let system: String?
        let code: String?
        let display: String?
    }
}

/// FHIR Bundle resource returned when searching for CodeSystems.
///
/// Contains an array of entries, each wrapping a CodeSystem resource
/// representing a SNOMED CT edition.
///
/// - SeeAlso: [FHIR Bundle](https://hl7.org/fhir/R4/bundle.html)
struct FHIRBundle: Decodable {
    let resourceType: String
    let type: String?
    let entry: [Entry]?

    /// A single entry in the bundle containing a CodeSystem resource.
    struct Entry: Decodable {
        let resource: CodeSystem?
    }
}

/// FHIR CodeSystem resource representing a SNOMED CT edition.
///
/// - SeeAlso: [FHIR CodeSystem](https://hl7.org/fhir/R4/codesystem.html)
struct CodeSystem: Decodable {
    let resourceType: String
    let url: String?
    let version: String?
    let name: String?
    let title: String?
    let status: String?
}

/// Represents a SNOMED CT edition available on the terminology server.
///
/// Each edition has a unique system URL (sct or xsct), a version URI
/// containing the edition module ID, and a human-readable title.
///
/// ## Example Editions
///
/// - International: `http://snomed.info/sct/900000000000207008`
/// - Australian: `http://snomed.info/sct/32506021000036107`
/// - US: `http://snomed.info/sct/731000124108`
struct SNOMEDEdition: Identifiable, Hashable {
    /// Unique identifier for SwiftUI lists (uses the version URI).
    var id: String { version }

    /// The SNOMED CT system URL.
    ///
    /// - `http://snomed.info/sct` for official editions
    /// - `http://snomed.info/xsct` for experimental/extension editions
    let system: String

    /// The full edition version URI including the module ID.
    ///
    /// Example: `http://snomed.info/sct/32506021000036107`
    let version: String

    /// Human-readable name of the edition.
    ///
    /// Example: "Australian", "United States", "International"
    let title: String
}

// MARK: - ValueSet Expansion Structures

/// Response from a ValueSet/$expand operation.
///
/// Contains the expansion with a list of concepts matching the search filter.
struct ValueSetExpansionResponse: Decodable {
    let resourceType: String
    let expansion: Expansion?

    struct Expansion: Decodable {
        let identifier: String?
        let timestamp: String?
        let total: Int?
        let parameter: [ExpansionParameter]?
        let contains: [ExpansionContains]?
    }

    /// A parameter within the expansion metadata (e.g., `used-codesystem`).
    struct ExpansionParameter: Decodable {
        let name: String?
        let valueUri: String?
    }

    struct ExpansionContains: Decodable {
        let system: String?
        let version: String?
        let code: String?
        let display: String?
        let designation: [Designation]?
    }

    struct Designation: Decodable {
        let language: String?
        let use: DesignationUse?
        let value: String?
    }

    struct DesignationUse: Decodable {
        let system: String?
        let code: String?
        let display: String?
    }
}
