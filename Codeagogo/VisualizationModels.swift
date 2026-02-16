import Foundation

// MARK: - Property Value Types

/// Represents the different types of property values that can be returned from FHIR.
///
/// Not Codable since we don't persist these - they're fetched on demand.
enum PropertyValue {
    case string(String)
    case boolean(Bool)
    case code(String)
    case coding(FHIRParameters.Coding)
    case integer(Int)

    /// Returns a human-readable string representation of the value.
    var displayString: String {
        switch self {
        case .string(let s): return s
        case .boolean(let b): return b ? "true" : "false"
        case .code(let c): return c
        case .coding(let c): return c.display ?? c.code ?? "Unknown"
        case .integer(let i): return String(i)
        }
    }
}

// MARK: - Concept Property

/// Represents a single property of a concept returned from a CodeSystem/$lookup operation.
///
/// Properties can include both standard SNOMED CT properties (effectiveTime, moduleId, etc.)
/// and relationship properties (finding site, causative agent, etc.).
///
/// Not Codable since we don't persist these - they're fetched on demand for visualization.
struct ConceptProperty: Identifiable {
    let id = UUID()

    /// The property code (e.g., "effectiveTime", "Finding site", "parent")
    let code: String

    /// The property value (can be string, boolean, code, coding, or integer)
    let value: PropertyValue

    /// Optional human-readable description of the property
    let display: String?
}

// MARK: - Visualization Data

/// Contains all data needed to render a concept visualization.
///
/// Combines the basic concept result with the full set of properties
/// fetched via the `property=*` parameter.
struct VisualizationData {
    /// The base concept information (ID, PT, FSN, status, etc.)
    let concept: ConceptResult

    /// All properties including relationships and attributes
    let properties: [ConceptProperty]

    /// Map of concept ID to definition status (true = defined, false = primitive)
    /// Used to determine box colors in the diagram
    let definitionStatusMap: [String: Bool]

    /// Map of concept ID to display name/term
    /// Used to show proper terms for parent concepts
    let displayNameMap: [String: String]

    /// Whether this is a SNOMED CT concept (affects visualization style)
    var isSNOMEDCT: Bool { concept.isSNOMEDCT }

    /// Gets the definition status for a given concept ID
    /// - Parameter conceptId: The SNOMED CT concept ID
    /// - Returns: true if defined, false if primitive, nil if unknown
    func isDefinedConcept(_ conceptId: String) -> Bool? {
        return definitionStatusMap[conceptId]
    }

    /// Gets the display name for a given concept ID
    /// - Parameter conceptId: The SNOMED CT concept ID
    /// - Returns: Display name if available, nil otherwise
    func displayName(for conceptId: String) -> String? {
        return displayNameMap[conceptId]
    }
}
