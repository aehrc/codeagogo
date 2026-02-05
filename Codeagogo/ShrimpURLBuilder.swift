import Foundation

/// Builds URLs for opening concepts in the Shrimp browser.
///
/// Shrimp is a terminology browser that can display concept details
/// from various code systems. This utility constructs the appropriate
/// URL format based on the code system and available metadata.
///
/// ## Examples
///
/// ```swift
/// // SNOMED CT concept
/// let url = ShrimpURLBuilder.buildURL(
///     conceptId: "395216006",
///     system: "http://snomed.info/sct",
///     moduleId: "32506021000036107",
///     effectiveTime: "20260131",
///     fhirEndpoint: "https://tx.ontoserver.csiro.au/fhir"
/// )
/// // -> https://ontoserver.csiro.au/shrimp/?concept=395216006&version=...
///
/// // LOINC code
/// let url = ShrimpURLBuilder.buildURL(
///     conceptId: "30297-6",
///     system: "http://loinc.org",
///     version: "2.81",
///     fhirEndpoint: "https://tx.ontoserver.csiro.au/fhir"
/// )
/// // -> https://ontoserver.csiro.au/shrimp/?system=http://loinc.org&concept=30297-6&...
/// ```
struct ShrimpURLBuilder {

    /// The base URL for the Shrimp browser.
    private static let shrimpBaseURL = "https://ontoserver.csiro.au/shrimp/"

    /// Builds a Shrimp URL for a given concept.
    ///
    /// - Parameters:
    ///   - conceptId: The concept code/ID
    ///   - system: The code system URI (e.g., "http://snomed.info/sct")
    ///   - moduleId: The SNOMED CT module/edition ID (optional, for SNOMED only)
    ///   - effectiveTime: The version date in YYYYMMDD format (optional, for SNOMED only)
    ///   - version: The version string (optional, for non-SNOMED systems)
    ///   - fhirEndpoint: The FHIR server endpoint URL
    /// - Returns: A URL for opening the concept in Shrimp, or nil if URL construction fails
    static func buildURL(
        conceptId: String,
        system: String?,
        moduleId: String? = nil,
        effectiveTime: String? = nil,
        version: String? = nil,
        fhirEndpoint: String
    ) -> URL? {
        guard let system = system else {
            AppLog.warning(AppLog.general, "Cannot build Shrimp URL: no system specified")
            return nil
        }

        var components = URLComponents(string: shrimpBaseURL)
        var queryItems: [URLQueryItem] = []

        // Add concept parameter (always present)
        queryItems.append(URLQueryItem(name: "concept", value: conceptId))

        // Determine if this is SNOMED CT
        let isSNOMED = system.starts(with: "http://snomed.info/sct") || system.starts(with: "http://snomed.info/xsct")

        if isSNOMED {
            // SNOMED CT: use version URI and edition-specific ValueSet
            // Example: http://snomed.info/sct/32506021000036107

            if let moduleId = moduleId {
                let versionURI = "http://snomed.info/sct/\(moduleId)"
                queryItems.append(URLQueryItem(name: "version", value: versionURI))

                // ValueSet: http://snomed.info/sct/[moduleId]?fhir_vs
                let valuesetURI = "http://snomed.info/sct/\(moduleId)?fhir_vs"
                queryItems.append(URLQueryItem(name: "valueset", value: valuesetURI))
            } else {
                // Fallback: use International edition if no module/version info
                AppLog.info(AppLog.general, "Building Shrimp URL for SNOMED CT without module/version info")
                let internationalModule = "900000000000207008" // International edition
                let versionURI = "http://snomed.info/sct/\(internationalModule)?fhir_vs"
                queryItems.append(URLQueryItem(name: "valueset", value: versionURI))
            }
        } else {
            // Non-SNOMED systems: include system parameter
            queryItems.append(URLQueryItem(name: "system", value: system))

            // Add version if available
            if let version = version {
                queryItems.append(URLQueryItem(name: "version", value: version))
            }

            // ValueSet format depends on system
            let valuesetURI = buildValueSetURI(for: system)
            queryItems.append(URLQueryItem(name: "valueset", value: valuesetURI))
        }

        // Add FHIR endpoint (always present)
        queryItems.append(URLQueryItem(name: "fhir", value: fhirEndpoint))

        components?.queryItems = queryItems

        guard let url = components?.url else {
            AppLog.warning(AppLog.general, "Failed to construct Shrimp URL")
            return nil
        }

        AppLog.info(AppLog.general, "Built Shrimp URL: \(url)")
        return url
    }

    /// Builds a Shrimp URL from a ConceptResult.
    ///
    /// This is a convenience method that extracts the necessary information
    /// from a ConceptResult and calls the main buildURL method.
    ///
    /// - Parameters:
    ///   - result: The concept lookup result
    ///   - fhirEndpoint: The FHIR server endpoint URL
    /// - Returns: A URL for opening the concept in Shrimp, or nil if URL construction fails
    static func buildURL(from result: ConceptResult, fhirEndpoint: String) -> URL? {
        return buildURL(
            conceptId: result.conceptId,
            system: result.system,
            moduleId: result.moduleId,
            effectiveTime: result.effectiveTime,
            version: extractVersion(from: result.branch),
            fhirEndpoint: fhirEndpoint
        )
    }

    /// Extracts version string from a branch/edition string.
    ///
    /// For non-SNOMED systems, the branch often contains the version in parentheses,
    /// e.g., "LOINC (2.81)". This method extracts that version string.
    ///
    /// - Parameter branch: The branch/edition string
    /// - Returns: The version string, or nil if not found
    private static func extractVersion(from branch: String?) -> String? {
        guard let branch = branch else { return nil }

        // Try to extract version from parentheses: "System (2.81)" -> "2.81"
        if let start = branch.firstIndex(of: "("),
           let end = branch.firstIndex(of: ")"),
           start < end {
            let versionSubstring = branch[branch.index(after: start)..<end]
            return String(versionSubstring).trimmingCharacters(in: .whitespaces)
        }

        return nil
    }

    /// Builds the ValueSet URI for a given code system.
    ///
    /// Different code systems have different implicit ValueSet URI formats.
    ///
    /// - Parameter system: The code system URI
    /// - Returns: The implicit ValueSet URI for that system
    private static func buildValueSetURI(for system: String) -> String {
        switch system {
        case "http://loinc.org":
            return "http://loinc.org/vs"

        case let s where s.starts(with: "http://hl7.org/fhir/sid/icd-10"):
            // ICD-10 and ICD-10-CM
            return "\(s)?fhir_vs"

        case let s where s.starts(with: "http://hl7.org/fhir/sid/icd-9"):
            // ICD-9-CM
            return "\(s)?fhir_vs"

        case "http://www.nlm.nih.gov/research/umls/rxnorm":
            // RxNorm
            return "http://www.nlm.nih.gov/research/umls/rxnorm?fhir_vs"

        default:
            // Generic fallback
            return "\(system)?fhir_vs"
        }
    }
}
