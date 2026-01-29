import Foundation
import Combine

/// The term format to use when replacing a SNOMED CT concept ID.
///
/// This setting controls which term is displayed alongside the concept ID
/// when using the replace hotkey feature.
enum ReplaceTermFormat: String, CaseIterable {
    /// Use the Fully Specified Name (FSN) — the unambiguous term with semantic tag.
    ///
    /// Example: "Paracetamol (product)"
    case fsn = "Fully Specified Name (FSN)"

    /// Use the Preferred Term (PT) — the commonly used clinical term.
    ///
    /// Example: "Paracetamol"
    case pt = "Preferred Term (PT)"
}

/// Manages the replace feature settings.
///
/// `ReplaceSettings` stores user preferences for the replace hotkey feature,
/// including the term format to use when replacing selected concept IDs.
///
/// ## Thread Safety
///
/// This class is marked `@MainActor` and should be accessed from the main
/// thread.
///
/// ## Usage
///
/// ```swift
/// let settings = ReplaceSettings.shared
///
/// // Get current format
/// let format = settings.termFormat
///
/// // Update format
/// settings.termFormat = .pt
/// ```
@MainActor
final class ReplaceSettings: ObservableObject {
    /// The UserDefaults key for the term format setting.
    private static let termFormatKey = "replace.termFormat"

    /// Shared singleton instance.
    static let shared = ReplaceSettings()

    /// The term format to use when replacing concept IDs.
    ///
    /// Defaults to FSN (Fully Specified Name).
    @Published var termFormat: ReplaceTermFormat {
        didSet {
            UserDefaults.standard.set(termFormat.rawValue, forKey: Self.termFormatKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.termFormatKey),
           let format = ReplaceTermFormat(rawValue: saved) {
            self.termFormat = format
        } else {
            self.termFormat = .fsn
        }
    }
}
