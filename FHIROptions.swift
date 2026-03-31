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

/// Constants used by FHIROptions, accessible from any isolation context.
private enum FHIRConstants: Sendable {
    static let endpointKey = "fhir.baseURL"
    static let defaultEndpoint = "https://tx.ontoserver.csiro.au/fhir"
}

@MainActor
final class FHIROptions: ObservableObject {
    static let shared = FHIROptions()

    @Published var baseURLString: String

    /// Whether the current endpoint uses an insecure (non-HTTPS) scheme.
    var isInsecure: Bool {
        baseURL.scheme?.lowercased() != "https"
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: FHIRConstants.endpointKey)
        // guarded by isEmpty check above
        // swiftlint:disable:next force_unwrapping
        self.baseURLString = (saved?.isEmpty == false ? saved! : FHIRConstants.defaultEndpoint)
    }

    func save() {
        UserDefaults.standard.set(baseURLString, forKey: FHIRConstants.endpointKey)
        if isInsecure {
            AppLog.warning(AppLog.network, "FHIR endpoint uses insecure HTTP: \(baseURLString)")
        }
    }

    var baseURL: URL {
        Self.validatedURL(from: baseURLString)
    }

    /// Thread-safe access to the base URL for non-MainActor contexts.
    /// Reads directly from UserDefaults to avoid actor isolation issues.
    nonisolated static var currentBaseURL: URL {
        // Read directly from UserDefaults using inline key to avoid actor isolation warnings
        let saved = UserDefaults.standard.string(forKey: "fhir.baseURL")
        return validatedURL(from: saved ?? "")
    }

    /// Validates and returns a URL suitable for use as a FHIR base endpoint.
    ///
    /// Rejects URLs that contain query parameters or fragments, as these are
    /// not valid base URLs and could cause unexpected behavior in API requests.
    ///
    /// - Parameter urlString: The URL string to validate.
    /// - Returns: The validated URL, or the default endpoint if invalid.
    nonisolated private static func validatedURL(from urlString: String) -> URL {
        // Use inline default to avoid actor isolation warnings on FHIRConstants
        let defaultURL = "https://tx.ontoserver.csiro.au/fhir"
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme != nil,
              url.query == nil,
              url.fragment == nil
        else {
            // swiftlint:disable:next force_unwrapping
            return URL(string: defaultURL)!
        }
        return url
    }
}
