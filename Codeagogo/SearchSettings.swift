import Foundation
import Combine

/// The format options for inserting SNOMED CT concept references.
///
/// Users can choose how concept information is formatted when inserted
/// into documents or text fields.
///
/// ## Examples
///
/// For concept "387517004 | Paracetamol | Paracetamol (product)":
/// - `.idOnly`: "387517004"
/// - `.ptOnly`: "Paracetamol"
/// - `.fsnOnly`: "Paracetamol (product)"
/// - `.idPipePT`: "387517004 | Paracetamol"
/// - `.idPipeFSN`: "387517004 | Paracetamol (product)"
enum InsertFormat: String, CaseIterable, Codable {
    /// Insert only the concept ID.
    case idOnly = "ID Only"

    /// Insert only the Preferred Term (PT).
    case ptOnly = "PT Only"

    /// Insert only the Fully Specified Name (FSN).
    case fsnOnly = "FSN Only"

    /// Insert ID and PT separated by a pipe.
    case idPipePT = "ID | PT |"

    /// Insert ID and FSN separated by a pipe.
    case idPipeFSN = "ID | FSN |"
}

/// Constants used by SearchSettings, accessible from any isolation context.
private enum SearchSettingsConstants: Sendable {
    static let formatKey = "search.insertFormat"
    static let editionURIKey = "search.editionURI"
    static let codeSystemURIKey = "search.codeSystemURI"
    static let defaultFormat = InsertFormat.idPipePT
}

/// Manages user preferences for the SNOMED CT search feature.
///
/// `SearchSettings` stores the user's preferred insert format and edition
/// selection. Changes are automatically persisted to UserDefaults.
///
/// ## Thread Safety
///
/// This class is marked `@MainActor` and should be accessed from the main
/// thread. Use the static thread-safe accessors for non-MainActor contexts.
///
/// ## Usage
///
/// ```swift
/// let settings = SearchSettings.shared
///
/// // Get current format
/// let format = settings.selectedFormat
///
/// // Change format (automatically saved)
/// settings.selectedFormat = .idPipeFSN
/// ```
@MainActor
final class SearchSettings: ObservableObject {
    /// Shared singleton instance.
    static let shared = SearchSettings()

    /// The selected format for inserting concepts.
    ///
    /// Changes are automatically persisted to UserDefaults.
    @Published var selectedFormat: InsertFormat {
        didSet {
            UserDefaults.standard.set(selectedFormat.rawValue, forKey: SearchSettingsConstants.formatKey)
        }
    }

    /// The selected edition URI for filtering search results.
    ///
    /// - `nil`: Search all editions (default)
    /// - Non-nil: Search only the specified edition
    ///
    /// Changes are automatically persisted to UserDefaults.
    @Published var selectedEditionURI: String? {
        didSet {
            if let uri = selectedEditionURI {
                UserDefaults.standard.set(uri, forKey: SearchSettingsConstants.editionURIKey)
            } else {
                UserDefaults.standard.removeObject(forKey: SearchSettingsConstants.editionURIKey)
            }
        }
    }

    /// The selected code system URI for searching.
    ///
    /// - `nil` or `"snomed"`: Search SNOMED CT (default)
    /// - Non-nil: Search the specified code system (e.g., "http://loinc.org")
    ///
    /// Changes are automatically persisted to UserDefaults.
    @Published var selectedCodeSystemURI: String? {
        didSet {
            if let uri = selectedCodeSystemURI {
                UserDefaults.standard.set(uri, forKey: SearchSettingsConstants.codeSystemURIKey)
            } else {
                UserDefaults.standard.removeObject(forKey: SearchSettingsConstants.codeSystemURIKey)
            }
        }
    }

    /// Whether SNOMED CT is the currently selected code system.
    var isSNOMEDSelected: Bool {
        selectedCodeSystemURI == nil || selectedCodeSystemURI == "snomed"
    }

    private init() {
        // Load saved format or use default
        if let savedFormat = UserDefaults.standard.string(forKey: SearchSettingsConstants.formatKey),
           let format = InsertFormat(rawValue: savedFormat) {
            self.selectedFormat = format
        } else {
            self.selectedFormat = SearchSettingsConstants.defaultFormat
        }

        // Load saved edition URI (nil = All Editions)
        self.selectedEditionURI = UserDefaults.standard.string(forKey: SearchSettingsConstants.editionURIKey)

        // Load saved code system URI (nil = SNOMED CT)
        self.selectedCodeSystemURI = UserDefaults.standard.string(forKey: SearchSettingsConstants.codeSystemURIKey)
    }

    /// Thread-safe access to the current insert format for non-MainActor contexts.
    nonisolated static var currentFormat: InsertFormat {
        if let savedFormat = UserDefaults.standard.string(forKey: SearchSettingsConstants.formatKey),
           let format = InsertFormat(rawValue: savedFormat) {
            return format
        }
        return SearchSettingsConstants.defaultFormat
    }

    /// Thread-safe access to the current edition URI for non-MainActor contexts.
    nonisolated static var currentEditionURI: String? {
        UserDefaults.standard.string(forKey: SearchSettingsConstants.editionURIKey)
    }

    /// Thread-safe access to the current code system URI for non-MainActor contexts.
    nonisolated static var currentCodeSystemURI: String? {
        UserDefaults.standard.string(forKey: SearchSettingsConstants.codeSystemURIKey)
    }
}
