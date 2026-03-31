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

/// View model for the ECL evaluation panel.
///
/// Manages the state of an ECL evaluation request — the expression being
/// evaluated, the loading state, results, and any error messages.
@MainActor
final class EvaluateViewModel: ObservableObject {
    /// The ECL expression being evaluated.
    @Published var expression: String = ""

    /// Whether an evaluation is in progress.
    @Published var isEvaluating: Bool = false

    /// The evaluation result, if available.
    @Published var result: ECLEvaluationResult?

    /// An error message if the evaluation failed.
    @Published var errorMessage: String?

    /// Semantic validation warnings for concepts referenced in the expression.
    ///
    /// Populated asynchronously after evaluation begins. Each entry describes
    /// an inactive or unknown concept (e.g., "73211009 is inactive").
    /// Empty when no problems are detected.
    @Published var warnings: [String] = []

    private let client: OntoserverClient
    private let settings: EvaluateSettings
    private var evaluationTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init(client: OntoserverClient = OntoserverClient(),
         settings: EvaluateSettings? = nil) {
        self.client = client
        self.settings = settings ?? EvaluateSettings.shared
    }

    /// Evaluates the current ECL expression.
    ///
    /// Cancels any in-progress evaluation before starting a new one.
    /// Updates `result` on success or `errorMessage` on failure.
    func evaluate() {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        evaluationTask?.cancel()
        isEvaluating = true
        errorMessage = nil
        result = nil

        evaluationTask = Task {
            do {
                let evalResult = try await client.evaluateECL(
                    expression: trimmed,
                    count: settings.resultLimit
                )
                guard !Task.isCancelled else { return }
                self.result = evalResult
                self.isEvaluating = false
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                self.isEvaluating = false
            }
        }
    }

    /// Evaluates after a debounce delay (1 second).
    ///
    /// Called when the editor content changes. Cancels any pending debounce
    /// and schedules a new evaluation. This avoids hammering the server
    /// on every keystroke.
    func evaluateDebounced() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            evaluate()
        }
    }

    /// Updates the semantic validation warnings displayed in the panel.
    ///
    /// Called by `AppDelegate` after background concept validation completes.
    /// Each warning string describes a single inactive or unknown concept.
    ///
    /// - Parameter warnings: The warning strings to display
    func setWarnings(_ warnings: [String]) {
        self.warnings = warnings
    }

    /// Resets all state for reuse.
    func clearState() {
        evaluationTask?.cancel()
        expression = ""
        isEvaluating = false
        result = nil
        errorMessage = nil
        warnings = []
    }
}
