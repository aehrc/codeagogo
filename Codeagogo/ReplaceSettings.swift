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

/// The term format to use when replacing a SNOMED CT concept ID.
///
/// This setting controls which term is displayed alongside the concept ID
/// when using the replace hotkey feature.
enum ReplaceTermFormat: String, CaseIterable {
    /// Use the Fully Specified Name (FSN) — the unambiguous term with semantic tag.
    ///
    /// Example: "Paracetamol (product)"
    case fsn = "Fully Specified Name (FSN)"

    /// Use the Preferred Term (PT) — the commonly used clinical term.
    ///
    /// Example: "Paracetamol"
    case pt = "Preferred Term (PT)"
}

/// Manages the replace feature settings.
///
/// `ReplaceSettings` stores user preferences for the replace hotkey feature,
/// including the term format to use when replacing selected concept IDs.
///
/// ## Thread Safety
///
/// This class is marked `@MainActor` and should be accessed from the main
/// thread.
///
/// ## Usage
///
/// ```swift
/// let settings = ReplaceSettings.shared
///
/// // Get current format
/// let format = settings.termFormat
///
/// // Update format
/// settings.termFormat = .pt
/// ```
@MainActor
final class ReplaceSettings: ObservableObject {
    /// The UserDefaults key for the term format setting.
    private static let termFormatKey = "replace.termFormat"

    /// The UserDefaults key for the inactive prefix setting.
    private static let prefixInactiveKey = "replace.prefixInactive"

    /// Shared singleton instance.
    static let shared = ReplaceSettings()

    /// The term format to use when replacing concept IDs.
    ///
    /// Defaults to FSN (Fully Specified Name).
    @Published var termFormat: ReplaceTermFormat {
        didSet {
            UserDefaults.standard.set(termFormat.rawValue, forKey: Self.termFormatKey)
        }
    }

    /// Whether to prefix inactive concepts with "INACTIVE - " when replacing.
    ///
    /// When enabled, inactive concepts will be replaced as:
    /// `123456789 | INACTIVE - Some term |`
    ///
    /// Defaults to `true`.
    @Published var prefixInactive: Bool {
        didSet {
            UserDefaults.standard.set(prefixInactive, forKey: Self.prefixInactiveKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.termFormatKey),
           let format = ReplaceTermFormat(rawValue: saved) {
            self.termFormat = format
        } else {
            self.termFormat = .fsn
        }

        // Default to true if not set
        if UserDefaults.standard.object(forKey: Self.prefixInactiveKey) == nil {
            self.prefixInactive = true
        } else {
            self.prefixInactive = UserDefaults.standard.bool(forKey: Self.prefixInactiveKey)
        }
    }
}
