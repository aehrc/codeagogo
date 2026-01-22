import Foundation
import Combine

/// Constants used by FHIROptions, accessible from any isolation context.
private enum FHIRConstants: Sendable {
    static let endpointKey = "fhir.baseURL"
    static let defaultEndpoint = "https://tx.ontoserver.csiro.au/fhir"
}

@MainActor
final class FHIROptions: ObservableObject {
    static let shared = FHIROptions()

    @Published var baseURLString: String

    private init() {
        let saved = UserDefaults.standard.string(forKey: FHIRConstants.endpointKey)
        self.baseURLString = (saved?.isEmpty == false ? saved! : FHIRConstants.defaultEndpoint)
    }

    func save() {
        UserDefaults.standard.set(baseURLString, forKey: FHIRConstants.endpointKey)
    }

    var baseURL: URL {
        // Fallback to default if invalid
        if let url = URL(string: baseURLString), !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: FHIRConstants.defaultEndpoint)!
    }

    /// Thread-safe access to the base URL for non-MainActor contexts.
    /// Reads directly from UserDefaults to avoid actor isolation issues.
    nonisolated static var currentBaseURL: URL {
        let saved = UserDefaults.standard.string(forKey: FHIRConstants.endpointKey)
        if let urlString = saved, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: urlString) {
            return url
        }
        return URL(string: FHIRConstants.defaultEndpoint)!
    }
}
