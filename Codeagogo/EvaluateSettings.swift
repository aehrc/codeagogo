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

/// Manages user-configurable settings for ECL evaluation.
///
/// Settings are persisted to `UserDefaults.standard` and published so that
/// SwiftUI views can react to changes immediately.
///
/// ## Thread Safety
///
/// This class is marked `@MainActor` and should be accessed from the main
/// thread. Use the static thread-safe accessor for non-MainActor contexts.
///
/// ## Usage
///
/// ```swift
/// let settings = EvaluateSettings.shared
/// settings.resultLimit = 100
/// ```
@MainActor
final class EvaluateSettings: ObservableObject {

    /// Shared singleton instance.
    static let shared = EvaluateSettings()

    /// The maximum number of results to return from an ECL evaluation.
    ///
    /// Changes are automatically persisted to UserDefaults.
    @Published var resultLimit: Int {
        didSet {
            UserDefaults.standard.set(resultLimit, forKey: "evaluate.resultLimit")
        }
    }

    // MARK: - Thread-safe accessors

    /// Returns the current result limit from UserDefaults without requiring main-actor isolation.
    nonisolated static var currentResultLimit: Int {
        let stored = UserDefaults.standard.object(forKey: "evaluate.resultLimit") as? Int
        return stored ?? 50
    }

    // MARK: - Initialisation

    private init() {
        let stored = UserDefaults.standard.object(forKey: "evaluate.resultLimit") as? Int
        self.resultLimit = stored ?? 50
    }
}
