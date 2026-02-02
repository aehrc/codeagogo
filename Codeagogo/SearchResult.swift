import Foundation

/// A SNOMED CT concept returned from a ValueSet/$expand search operation.
///
/// `SearchResult` represents a single concept from the terminology server's
/// expansion of a ValueSet based on a text filter. It contains the essential
/// information needed to display search results and insert formatted concept
/// references.
///
/// ## Example
///
/// ```swift
/// let result = SearchResult(
///     code: "387517004",
///     display: "Paracetamol",
///     fsn: "Paracetamol (product)",
///     system: "http://snomed.info/sct",
///     version: "http://snomed.info/sct/32506021000036107/version/20251231",
///     editionName: "Australian"
/// )
/// ```
struct SearchResult: Identifiable, Hashable {
    /// Unique identifier for SwiftUI list rendering (uses the concept code).
    var id: String { code }

    /// The SNOMED CT concept identifier (6-18 digits).
    let code: String

    /// The Preferred Term (PT) - the commonly used clinical term.
    ///
    /// Example: "Paracetamol"
    let display: String

    /// The Fully Specified Name (FSN) - the unambiguous term with semantic tag.
    ///
    /// Example: "Paracetamol (product)"
    /// May be nil if the server did not return designations.
    let fsn: String?

    /// The SNOMED CT system URL.
    ///
    /// - `http://snomed.info/sct` for official editions
    /// - `http://snomed.info/xsct` for experimental/extension editions
    let system: String

    /// The edition version URI including version date.
    ///
    /// Example: "http://snomed.info/sct/32506021000036107/version/20251231"
    let version: String

    /// Human-readable edition name derived from the version URI.
    ///
    /// Example: "Australian", "International", "United States"
    var editionName: String

    /// Creates a formatted string based on the specified insert format.
    ///
    /// - Parameter format: The format to use for the output string
    /// - Returns: A formatted string representation of the concept
    func formatted(as format: InsertFormat) -> String {
        switch format {
        case .idOnly:
            return code
        case .ptOnly:
            return display
        case .fsnOnly:
            return fsn ?? display
        case .idPipePT:
            return "\(code) | \(display) |"
        case .idPipeFSN:
            return "\(code) | \(fsn ?? display) |"
        }
    }
}
