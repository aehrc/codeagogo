// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Combine

/// View model for the concept visualization panel.
///
/// Coordinates fetching property data for a concept and managing the
/// visualization state (loading, error, data).
@MainActor
final class VisualizationViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Indicates whether properties are currently being loaded.
    @Published var isLoading = false

    /// Error message to display, or nil if no error.
    @Published var error: String?

    /// The complete visualization data, or nil if not yet loaded.
    @Published var visualizationData: VisualizationData?

    // MARK: - Dependencies

    private let client: ConceptPropertyLookup

    // MARK: - Initialization

    /// Creates a new visualization view model.
    ///
    /// - Parameter client: The FHIR client to use for property lookups
    init(client: ConceptPropertyLookup = OntoserverClient()) {
        self.client = client
    }

    // MARK: - Public Methods

    /// Loads all properties for a concept result.
    ///
    /// This fetches properties using the `property=*` parameter on the
    /// CodeSystem/$lookup operation. The properties include both standard
    /// attributes (effectiveTime, moduleId) and relationships (finding site, etc.).
    ///
    /// - Parameter result: The concept result to fetch properties for
    func loadProperties(for result: ConceptResult) async {
        isLoading = true
        error = nil

        do {
            // Extract system and version from result
            let system = result.system ?? "http://snomed.info/sct"
            let version = extractVersion(from: result)

            let properties = try await client.lookupWithProperties(
                conceptId: result.conceptId,
                system: system,
                version: version
            )

            // Extract all unique concept IDs from the properties to look up their definition status
            var conceptIds = extractConceptIds(from: properties, mainConceptId: result.conceptId)

            // Check if normal form has the concept as its own parent (primitive concept issue)
            // If so, extract ALL parents from ALL parent properties and add them to conceptIds
            if let normalFormProp = properties.first(where: { $0.code == "normalForm" || $0.code == "normalFormTerse" }) {
                let normalForm = normalFormProp.value.displayString
                // Check if normal form starts with the concept's own ID
                if normalForm.contains(result.conceptId) {
                    // Look for ALL parent properties (there may be multiple parent properties)
                    let parentProps = properties.filter { $0.code == "parent" }
                    for parentProp in parentProps {
                        // Extract ALL parent IDs from this parent property
                        let parentIds = extractParentIds(from: parentProp.value)
                        for parentId in parentIds where parentId != result.conceptId {
                            AppLog.info(AppLog.network, "Adding parent \(parentId) to lookup list for primitive concept")
                            conceptIds.insert(parentId)
                        }
                    }
                }
            }

            // Fetch definition status and display names for all concepts (including parent if added)
            let (definitionStatusMap, displayNameMap) = try await fetchConceptInfo(
                for: Array(conceptIds),
                system: system,
                version: version
            )

            self.visualizationData = VisualizationData(
                concept: result,
                properties: properties,
                definitionStatusMap: definitionStatusMap,
                displayNameMap: displayNameMap
            )
            AppLog.info(AppLog.network, "Loaded \(properties.count) properties for \(result.conceptId)")
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            AppLog.error(AppLog.network, "Failed to load properties: \(error)")
        }

        isLoading = false
    }

    // MARK: - Private Methods

    /// Extracts the version URI from a concept result.
    ///
    /// For SNOMED CT, constructs the version URI from the moduleId if available.
    /// For other systems, uses the branch/version info from the result.
    private func extractVersion(from result: ConceptResult) -> String {
        // For SNOMED CT, construct version URI from moduleId if available
        if result.isSNOMEDCT, let moduleId = result.moduleId {
            // Map SNOMED CT Core module to International edition
            // 900000000000012004 = SNOMED CT Core module (not a proper edition)
            // 900000000000207008 = SNOMED CT International edition
            let mappedModuleId = (moduleId == "900000000000012004") ? "900000000000207008" : moduleId
            return "http://snomed.info/sct/\(mappedModuleId)"
        }

        // For other systems, use the branch (which may contain version info)
        if !result.branch.isEmpty {
            return result.branch
        }

        // Fallback to empty string (server will use default version)
        return ""
    }

    /// Extracts parent concept IDs from a parent property value.
    /// Returns all parent IDs found (concepts can have multiple parents joined by +).
    private func extractParentIds(from value: PropertyValue) -> [String] {
        switch value {
        case .coding(let coding):
            return coding.code.map { [$0] } ?? []
        case .string(let str):
            // Extract all IDs from the string (may be multiple parents joined by +)
            var ids: [String] = []
            let pattern = #"\b(\d{6,18})\b"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(str.startIndex..., in: str)
                let matches = regex.matches(in: str, range: range)
                for match in matches {
                    if let matchRange = Range(match.range(at: 1), in: str) {
                        ids.append(String(str[matchRange]))
                    }
                }
            }
            return ids
        case .code(let code):
            return [code]
        default:
            return []
        }
    }

    /// Extracts all unique concept IDs from the normalForm property.
    ///
    /// Parses the normalForm to find all concept IDs that appear in the expression,
    /// including the main concept, parent concepts, and attribute values.
    private func extractConceptIds(from properties: [ConceptProperty], mainConceptId: String) -> Set<String> {
        var conceptIds = Set<String>()
        conceptIds.insert(mainConceptId)

        // Look for normalForm property
        if let normalFormProp = properties.first(where: { $0.code == "normalForm" || $0.code == "normalFormTerse" }) {
            let normalForm = normalFormProp.value.displayString
            AppLog.info(AppLog.network, "Normal form for \(mainConceptId): \(normalForm.prefix(500))...")

            // Extract all concept IDs from the normal form (simple regex for SCTID pattern)
            let pattern = "\\b(\\d{6,18})\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(normalForm.startIndex..., in: normalForm)
                let matches = regex.matches(in: normalForm, range: range)

                for match in matches {
                    if let matchRange = Range(match.range(at: 1), in: normalForm) {
                        let conceptId = String(normalForm[matchRange])
                        conceptIds.insert(conceptId)
                    }
                }
            }
            AppLog.info(AppLog.network, "Extracted \(conceptIds.count) concept IDs from normal form: \(Array(conceptIds).sorted().joined(separator: ", "))")
        }

        return conceptIds
    }

    /// Fetches definition status and display names for a set of concept IDs.
    ///
    /// Uses parallel $lookup calls to efficiently fetch the definition status and display names.
    /// Calls both lookupWithProperties (for definition status) and lookup (for display name).
    /// - Returns: A tuple of (definitionStatusMap, displayNameMap)
    private func fetchConceptInfo(for conceptIds: [String], system: String, version: String) async throws -> ([String: Bool], [String: String]) {
        guard !conceptIds.isEmpty else { return ([:], [:]) }

        // Use TaskGroup for parallel lookups
        return try await withThrowingTaskGroup(of: (String, Bool, String?).self) { group in
            // Launch parallel lookup tasks for each concept
            for conceptId in conceptIds {
                group.addTask {
                    do {
                        // Fetch properties for definition status
                        let props = try await self.client.lookupWithProperties(
                            conceptId: conceptId,
                            system: system,
                            version: version
                        )

                        // Look for sufficientlyDefined property
                        var isDefined = false
                        if let definedProp = props.first(where: { $0.code == "sufficientlyDefined" }) {
                            if case .boolean(let defined) = definedProp.value {
                                isDefined = defined
                                AppLog.info(AppLog.network, "Concept \(conceptId) sufficientlyDefined=\(defined)")
                            } else {
                                AppLog.warning(AppLog.network, "Concept \(conceptId) sufficientlyDefined property is not boolean: \(definedProp.value)")
                            }
                        } else {
                            AppLog.warning(AppLog.network, "Concept \(conceptId) has no sufficientlyDefined property (defaulting to primitive)")
                        }

                        // Look up preferred term using the server's default edition
                        // (no version), which gives locale-appropriate display terms
                        // (e.g., "mL" from SCTAU instead of "Milliliter" from international)
                        var displayName: String?
                        do {
                            displayName = try await self.client.lookupPreferredTerm(
                                conceptId: conceptId,
                                system: system
                            )
                            if let name = displayName {
                                AppLog.info(AppLog.network, "Found display for \(conceptId): \(name)")
                            }
                        } catch {
                            AppLog.warning(AppLog.network, "Failed to lookup display for \(conceptId): \(error)")
                        }

                        return (conceptId, isDefined, displayName)
                    } catch {
                        // If lookup fails, default to primitive (false) and no display name
                        AppLog.warning(AppLog.network, "Failed to lookup concept info for \(conceptId): \(error)")
                        return (conceptId, false, nil)
                    }
                }
            }

            // Collect results from all parallel tasks
            var statusMap: [String: Bool] = [:]
            var displayMap: [String: String] = [:]
            for try await (conceptId, isDefined, displayName) in group {
                statusMap[conceptId] = isDefined
                if let displayName = displayName {
                    displayMap[conceptId] = displayName
                }
            }

            return (statusMap, displayMap)
        }
    }
}
