import Foundation
import Combine

/// A configured code system for lookup operations.
///
/// Represents a non-SNOMED code system (e.g., LOINC, ICD-10) that can be
/// searched when a selected code doesn't match the SNOMED CT format.
struct ConfiguredCodeSystem: Codable, Identifiable, Hashable {
    /// Unique identifier for the code system (uses the URI).
    var id: String { uri }

    /// The canonical URI for the code system.
    ///
    /// Examples:
    /// - `http://loinc.org`
    /// - `http://hl7.org/fhir/sid/icd-10-cm`
    /// - `http://www.nlm.nih.gov/research/umls/rxnorm`
    let uri: String

    /// Human-readable name for the code system.
    ///
    /// Examples: "LOINC", "ICD-10-CM", "RxNorm"
    let title: String

    /// Whether this code system is enabled for lookups.
    var enabled: Bool
}

/// Manages the list of non-SNOMED code systems to search during lookups.
///
/// `CodeSystemSettings` maintains a list of configured code systems that are
/// searched when a selected code doesn't appear to be a valid SNOMED CT
/// identifier (fails Verhoeff check or is alphanumeric).
///
/// ## Default Configuration
///
/// By default, only LOINC is enabled:
/// - LOINC (`http://loinc.org`)
///
/// ## Usage
///
/// ```swift
/// let settings = CodeSystemSettings.shared
///
/// // Get enabled systems for lookup
/// let systems = settings.enabledSystems
///
/// // Add a new code system
/// settings.addSystem(uri: "http://hl7.org/fhir/sid/icd-10-cm", title: "ICD-10-CM")
///
/// // Toggle a code system
/// if var loinc = settings.configuredSystems.first(where: { $0.uri.contains("loinc") }) {
///     loinc.enabled = false
///     settings.updateSystem(loinc)
/// }
/// ```
///
/// - Note: Settings are automatically persisted to UserDefaults.
@MainActor
final class CodeSystemSettings: ObservableObject {
    /// Shared singleton instance.
    static let shared = CodeSystemSettings()

    /// UserDefaults key for storing configured code systems.
    private static let storageKey = "codeSystem.configured"

    /// Default code systems (LOINC only).
    private static let defaultSystems: [ConfiguredCodeSystem] = [
        ConfiguredCodeSystem(uri: "http://loinc.org", title: "LOINC", enabled: true)
    ]

    /// The list of configured code systems.
    ///
    /// Changes are automatically persisted to UserDefaults.
    @Published var configuredSystems: [ConfiguredCodeSystem] {
        didSet { save() }
    }

    /// Returns only the enabled code systems.
    ///
    /// Use this property when performing lookups to get the list of systems
    /// to search for non-SNOMED codes.
    var enabledSystems: [ConfiguredCodeSystem] {
        configuredSystems.filter { $0.enabled }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let systems = try? JSONDecoder().decode([ConfiguredCodeSystem].self, from: data) {
            self.configuredSystems = systems
        } else {
            self.configuredSystems = Self.defaultSystems
        }
    }

    /// Persists the current configuration to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(configuredSystems) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Adds a new code system to the configuration.
    ///
    /// If a system with the same URI already exists, this method does nothing.
    ///
    /// - Parameters:
    ///   - uri: The canonical URI for the code system
    ///   - title: Human-readable name for the code system
    func addSystem(uri: String, title: String) {
        guard !configuredSystems.contains(where: { $0.uri == uri }) else { return }
        configuredSystems.append(ConfiguredCodeSystem(uri: uri, title: title, enabled: true))
    }

    /// Removes a code system from the configuration.
    ///
    /// - Parameter uri: The URI of the code system to remove
    func removeSystem(uri: String) {
        configuredSystems.removeAll { $0.uri == uri }
    }

    /// Updates an existing code system in the configuration.
    ///
    /// If the system doesn't exist, this method does nothing.
    ///
    /// - Parameter system: The updated code system
    func updateSystem(_ system: ConfiguredCodeSystem) {
        guard let index = configuredSystems.firstIndex(where: { $0.uri == system.uri }) else { return }
        configuredSystems[index] = system
    }

    /// Resets the configuration to defaults.
    ///
    /// This removes all custom code systems and restores the default
    /// configuration (LOINC only).
    func resetToDefaults() {
        configuredSystems = Self.defaultSystems
    }
}

/// A code system available on the terminology server.
///
/// Represents a code system discovered via the FHIR `CodeSystem` resource.
/// Used to populate the "Add Code System" picker in settings.
struct AvailableCodeSystem: Identifiable, Hashable {
    /// Unique identifier (uses the URL).
    var id: String { url }

    /// The canonical URL for the code system.
    let url: String

    /// Human-readable name for the code system.
    let title: String

    /// Version string, if available.
    let version: String?
}
