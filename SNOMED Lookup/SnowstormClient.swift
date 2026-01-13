import Foundation

struct ConceptResult {
    let conceptId: String
    let branch: String
    let fsn: String?
    let pt: String?
    let active: Bool?
    let effectiveTime: String?
    let moduleId: String?

    var activeText: String {
        switch active {
        case true: return "active"
        case false: return "inactive"
        default: return "—"
        }
    }
}

final class SnowstormClient {
    private let base = URL(string: "https://lookup.snomedtools.org/snowstorm/snomed-ct")!
    private let session: URLSession
    
    // Cache (conceptId -> (result, timestamp))
    private var cache: [String: (ConceptResult, Date)] = [:]
    private let cacheTTL: TimeInterval = 60 * 60 * 6 // 6 hours

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookup(conceptId: String) async throws -> ConceptResult {
        if let (cached, ts) = cache[conceptId], Date().timeIntervalSince(ts) < cacheTTL {
            return cached
        }

        let branch = try await resolveBranch(conceptId: conceptId)
        let detail = try await fetchConcept(branch: branch, conceptId: conceptId)

        let result = ConceptResult(
            conceptId: conceptId,
            branch: branch,
            fsn: detail.fsn?.term,
            pt: detail.pt?.term,
            active: detail.active,
            effectiveTime: detail.effectiveTime,
            moduleId: detail.moduleId
        )

        cache[conceptId] = (result, Date())
        return result
    }

    private func resolveBranch(conceptId: String) async throws -> String {
        var comps = URLComponents(url: base.appendingPathComponent("multisearch/concepts"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "conceptIds", value: conceptId)]
        let url = comps.url!

        let ms: MultiSearchResponse = try await getJSON(url)
        guard let item = ms.items.first, let branch = item.branch, !branch.isEmpty else {
            throw NSError(domain: "SnowstormClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Concept not found"])
        }
        return branch
    }

    private func fetchConcept(branch: String, conceptId: String) async throws -> ConceptDetail {
        // Encode branch segments
        let safeBranch = branch.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        let url = base
            .appendingPathComponent("browser")
            .appendingPathComponent(safeBranch)
            .appendingPathComponent("concepts")
            .appendingPathComponent(conceptId)

        return try await getJSON(url)
    }

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "SnowstormClient", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code): \(body)"])
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct MultiSearchResponse: Decodable {
    struct Item: Decodable {
        let conceptId: String?
        let active: Bool?
        let branch: String?
        let moduleId: String?
    }
    let items: [Item]
}

struct ConceptDetail: Decodable {
    struct TermObj: Decodable { let term: String?; let lang: String? }
    let conceptId: String?
    let fsn: TermObj?
    let pt: TermObj?
    let active: Bool?
    let effectiveTime: String?
    let moduleId: String?
}
