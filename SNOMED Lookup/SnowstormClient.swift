import Foundation
import os

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
        AppLog.info(AppLog.network, "SnowstormClient init base=\(base.absoluteString)")
    }

    func lookup(conceptId: String) async throws -> ConceptResult {
        if let (cached, ts) = cache[conceptId], Date().timeIntervalSince(ts) < cacheTTL {
            AppLog.debug(AppLog.network, "cache hit conceptId=\(conceptId)")
            return cached
        }

        AppLog.info(AppLog.network, "lookup conceptId=\(conceptId)")

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

        AppLog.info(AppLog.network, "lookup success conceptId=\(conceptId) branch=\(branch) active=\(result.activeText)")
        return result
    }

    private func resolveBranch(conceptId: String) async throws -> String {
        var comps = URLComponents(
            url: base.appendingPathComponent("multisearch/concepts"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [URLQueryItem(name: "conceptIds", value: conceptId)]
        let url = comps.url!

        AppLog.debug(AppLog.network, "resolveBranch request url=\(url.absoluteString)")

        let ms: MultiSearchResponse = try await getJSON(url)
        guard let item = ms.items.first, let branch = item.branch, !branch.isEmpty else {
            AppLog.error(AppLog.network, "resolveBranch not found conceptId=\(conceptId)")
            throw NSError(
                domain: "SnowstormClient",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Concept not found"]
            )
        }

        AppLog.debug(AppLog.network, "resolveBranch ok conceptId=\(conceptId) branch=\(branch)")
        return branch
    }

    private func fetchConcept(branch: String, conceptId: String) async throws -> ConceptDetail {
        let safeBranch = branch
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        let url = base
            .appendingPathComponent("browser")
            .appendingPathComponent(safeBranch)
            .appendingPathComponent("concepts")
            .appendingPathComponent(conceptId)

        AppLog.debug(AppLog.network, "fetchConcept request conceptId=\(conceptId) url=\(url.absoluteString)")

        return try await getJSON(url)
    }

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

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
                    domain: "SnowstormClient",
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
            // Key for "can't connect": concrete URLError code and description
            AppLog.error(
                AppLog.network,
                "URLError url=\(url.absoluteString) code=\(urlError.code.rawValue) (\(String(describing: urlError.code))) desc=\(urlError.localizedDescription)"
            )
            throw urlError

        } catch {
            AppLog.error(AppLog.network, "error url=\(url.absoluteString) desc=\(error.localizedDescription)")
            throw error
        }
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
