import Foundation
import os

final class OntoserverClient {
    private let internationalEditionId = "900000000000207008"
    private let baseURL = URL(string: "https://tx.ontoserver.csiro.au/fhir")!
    private let session: URLSession
    
    // Cache (conceptId -> (result, timestamp))
    private var cache: [String: (ConceptResult, Date)] = [:]
    private let cacheTTL: TimeInterval = 60 * 60 * 6 // 6 hours
    
    init(session: URLSession = .shared) {
        self.session = session
        AppLog.info(AppLog.network, "OntoserverClient init base=\(baseURL.absoluteString)")
    }
    
    func lookup(conceptId: String) async throws -> ConceptResult {
        if let (cached, ts) = cache[conceptId], Date().timeIntervalSince(ts) < cacheTTL {
            AppLog.debug(AppLog.network, "cache hit conceptId=\(conceptId)")
            return cached
        }
        
        AppLog.info(AppLog.network, "lookup conceptId=\(conceptId)")
        
        // Step 1: Try latest international edition first
        if let result = try await lookupInSystem(conceptId: conceptId, system: "http://snomed.info/sct", version: "http://snomed.info/sct/" + internationalEditionId) {
            cache[conceptId] = (result, Date())
            AppLog.info(AppLog.network, "lookup success in international edition conceptId=\(conceptId)")
            return result
        }
        
        AppLog.info(AppLog.network, "not found in international edition, trying all editions conceptId=\(conceptId)")
        
        // Step 2: Get all SNOMED CT editions
        let editions = try await fetchAllEditions()
        
        // Step 3: Look up in all editions in parallel
        let result = try await lookupInAllEditions(conceptId: conceptId, editions: editions)
        
        cache[conceptId] = (result, Date())
        AppLog.info(AppLog.network, "lookup success conceptId=\(conceptId) edition=\(result.branch)")
        return result
    }
    
    private func lookupInSystem(conceptId: String, system: String, version: String) async throws -> ConceptResult? {
        var comps = URLComponents(url: baseURL.appendingPathComponent("CodeSystem/$lookup"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "system", value: system),
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "code", value: conceptId),
            URLQueryItem(name: "_format", value: "json")
        ]
        
        let url = comps.url!
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
        var comps = URLComponents(url: baseURL.appendingPathComponent("CodeSystem"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            // Look for both SCT and xSCT
            URLQueryItem(name: "url", value: "http://snomed.info/sct,http://snomed.info/xsct"),
            URLQueryItem(name: "_format", value: "json")
        ]

        let url = comps.url!
        AppLog.debug(AppLog.network, "fetchAllEditions request url=\(url.absoluteString)")

        let bundle: FHIRBundle = try await getJSON(url)

        guard let entries = bundle.entry, !entries.isEmpty else {
            AppLog.error(AppLog.network, "no SNOMED editions found")
            throw NSError(
                domain: "OntoserverClient",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No SNOMED editions found"]
            )
        }

        let internationalEditionId = "900000000000207008"

        // One CodeSystem per edition URI
        var editionMap: [String: CodeSystem] = [:]

        for entry in entries {
            guard let codeSystem = entry.resource else { continue }
            guard let rawVersion = codeSystem.version else { continue }
            guard let editionURI = extractEditionURI(from: rawVersion) else { continue }

            // Strip out the International edition (handled elsewhere)
            if editionURI.hasSuffix("/\(internationalEditionId)") {
                continue
            }

            editionMap[editionURI] = editionMap[editionURI] ?? codeSystem
        }

        var editions = editionMap.values.map { cs in
            SNOMEDEdition(
                system: cs.url ?? "http://snomed.info/sct",
                version: extractEditionURI(from: cs.version ?? "") ?? "unknown-edition",
                title: cs.title ?? cs.name ?? "Unknown Edition"
            )
        }

        // Ensure xSCT editions are sorted to the bottom
        editions.sort {
            systemSortKey($0.system) < systemSortKey($1.system)
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
            throw NSError(
                domain: "OntoserverClient",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Concept not found in any SNOMED edition"]
            )
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
                    
                    // FSN has use code "900000000000003001"
                    if use == "900000000000003001" {
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
        if let version = version, !version.isEmpty {
            // Extract editionId from system URL as before
            let components = version.split(separator: "/")
            
            if components.count >= 4 {
                let editionId = String(components[3])
                let humanReadableName = getEditionName(for: editionId)
                return mark("\(humanReadableName) (\(components[5]))")
            }
            // Fallback if no editionId found
            return mark("\(system) (\(version))")
        }
        
        // If no version provided, fallback to previous logic
        let components = system.split(separator: "/")
        
        if components.count >= 4 {
            // Format: sct/<edition>/<version or 'version'>/<date>
            let editionId = String(components[3])
            let humanReadableName = getEditionName(for: editionId)
            
            if components.count >= 6 {
                let urlVersion = String(components[5])
                return mark("\(humanReadableName) (\(urlVersion))")
            }
            return mark(humanReadableName)
        }
        
        // Default to international if it's just "http://snomed.info/sct"
        if system == "http://snomed.info/sct" {
            return "MAIN (International)"
        }
        
        return system
    }
    
    private func getEditionName(for editionId: String) -> String {
        // Map of known edition IDs to human-readable names
        let editionNames: [String: String] = [
            "900000000000207008": "International",
            "32506021000036107": "Australian",
            "731000124108": "United States",
            "999000041000000102": "United Kingdom",
            "20611000087101": "Canadian",
            "449081005": "Spanish",
            "5991000124107": "Netherlands",
            "45991000052106": "Swedish",
            "554471000005108": "Danish",
            "11000146104": "Norwegian",
            "999000011000000103": "United Kingdom Clinical",
            "999000021000000109": "United Kingdom Drug",
            "21000210109": "Belgian",
            "83821000000107": "United Kingdom Edition"
        ]
        
        return editionNames[editionId] ?? editionId
    }
    
    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        
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
}

// MARK: - FHIR Data Structures

struct FHIRParameters: Decodable {
    let resourceType: String
    let parameter: [Parameter]?
    
    struct Parameter: Decodable {
        let name: String
        let valueString: String?
        let valueCode: String?
        let valueCoding: Coding?
        let part: [Part]?
    }
    
    struct Part: Decodable {
        let name: String
        let valueString: String?
        let valueCode: String?
        let valueCoding: Coding?
    }
    
    struct Coding: Decodable {
        let system: String?
        let code: String?
        let display: String?
    }
}

struct FHIRBundle: Decodable {
    let resourceType: String
    let type: String?
    let entry: [Entry]?
    
    struct Entry: Decodable {
        let resource: CodeSystem?
    }
}

struct CodeSystem: Decodable {
    let resourceType: String
    let url: String?
    let version: String?
    let name: String?
    let title: String?
    let status: String?
}

struct SNOMEDEdition {
    let system: String
    let version: String
    let title: String
}
