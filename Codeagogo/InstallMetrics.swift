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

/// Constants used by InstallMetrics, accessible from any isolation context.
private enum InstallMetricsConstants: Sendable {
    static let installIdKey = "metrics.installId"
}

/// Manages an anonymous install identifier for usage metrics.
///
/// Generates a random UUID on first launch and persists it in UserDefaults.
/// The ID is included in the User-Agent header on all terminology server
/// requests to enable usage counting from server logs without collecting
/// personal data.
@MainActor
final class InstallMetrics: ObservableObject {
    static let shared = InstallMetrics()

    /// The current anonymous install identifier.
    @Published private(set) var installId: String

    private init() {
        if let existing = UserDefaults.standard.string(forKey: InstallMetricsConstants.installIdKey),
           !existing.isEmpty {
            self.installId = existing
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: InstallMetricsConstants.installIdKey)
            self.installId = newId
        }
    }

    /// Thread-safe accessor for use in non-MainActor contexts (e.g. OntoserverClient).
    nonisolated static var currentInstallId: String {
        if let existing = UserDefaults.standard.string(forKey: InstallMetricsConstants.installIdKey),
           !existing.isEmpty {
            return existing
        }
        // Fallback: generate and persist if not yet initialised.
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: InstallMetricsConstants.installIdKey)
        return newId
    }

    /// Resets the install ID to a new random UUID.
    ///
    /// Provides a privacy control for users who want a fresh anonymous identity.
    func resetInstallId() {
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: InstallMetricsConstants.installIdKey)
        self.installId = newId
    }
}
