import Foundation
import Combine

@MainActor
final class FHIROptions: ObservableObject {
    static let shared = FHIROptions()

    private let endpointKey = "fhir.baseURL"
    private let defaultEndpoint = "https://tx.ontoserver.csiro.au/fhir"

    @Published var baseURLString: String

    private init() {
        let saved = UserDefaults.standard.string(forKey: endpointKey)
        self.baseURLString = (saved?.isEmpty == false ? saved! : defaultEndpoint)
    }

    func save() {
        UserDefaults.standard.set(baseURLString, forKey: endpointKey)
    }

    var baseURL: URL {
        // Fallback to default if invalid
        if let url = URL(string: baseURLString), !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: defaultEndpoint)!
    }
}
