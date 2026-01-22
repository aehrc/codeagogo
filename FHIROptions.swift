import Foundation
import Combine

@MainActor
final class FHIROptions: ObservableObject {
    static let shared = FHIROptions()

    private static let endpointKey = "fhir.baseURL"
    private static let defaultEndpoint = "https://tx.ontoserver.csiro.au/fhir"

    @Published var baseURLString: String

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.endpointKey)
        self.baseURLString = (saved?.isEmpty == false ? saved! : Self.defaultEndpoint)
    }

    func save() {
        UserDefaults.standard.set(baseURLString, forKey: Self.endpointKey)
    }

    var baseURL: URL {
        // Fallback to default if invalid
        if let url = URL(string: baseURLString), !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: Self.defaultEndpoint)!
    }

    /// Thread-safe access to the base URL for non-MainActor contexts.
    /// Reads directly from UserDefaults to avoid actor isolation issues.
    nonisolated static var currentBaseURL: URL {
        let saved = UserDefaults.standard.string(forKey: endpointKey)
        if let urlString = saved, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: urlString) {
            return url
        }
        return URL(string: defaultEndpoint)!
    }
}
