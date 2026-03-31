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

/// Manages the welcome screen display state.
///
/// Tracks whether the first-launch welcome screen has been shown via a
/// `welcome.hasShown` key in UserDefaults. The welcome screen is displayed
/// once on first launch (or upgrade) and can be re-shown from Settings.
@MainActor
final class WelcomeSettings: ObservableObject {
    static let shared = WelcomeSettings()

    /// UserDefaults key for tracking whether the welcome screen has been shown.
    static let hasShownKey = "welcome.hasShown"

    /// Whether the welcome screen has been shown to the user.
    @Published var hasShown: Bool {
        didSet {
            UserDefaults.standard.set(hasShown, forKey: WelcomeSettings.hasShownKey)
        }
    }

    private init() {
        self.hasShown = UserDefaults.standard.bool(forKey: WelcomeSettings.hasShownKey)
    }

    /// Resets the welcome state so the screen will be shown again.
    func reset() {
        hasShown = false
    }

    /// Marks the welcome screen as shown.
    func markAsShown() {
        hasShown = true
    }
}
