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
import os

enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "SNOMEDLookup"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let selection = Logger(subsystem: subsystem, category: "selection")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let general = Logger(subsystem: subsystem, category: "general")

    // UserDefaults key for debug logging
    static let debugKey = "debugLoggingEnabled"

    static var isDebugEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: debugKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: debugKey)
            general.info("Debug logging \(newValue ? "enabled" : "disabled", privacy: .public)")
        }
    }

    // Convenience wrappers to reduce noise unless debug is enabled
    static func debug(_ logger: Logger, _ message: String) {
        guard isDebugEnabled else { return }
        logger.debug("DEBUG: \(message, privacy: .public)")
    }

    static func info(_ logger: Logger, _ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func warning(_ logger: Logger, _ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    static func error(_ logger: Logger, _ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func snippet(_ s: String, limit: Int = 2000) -> String {
        if s.count <= limit { return s }
        return String(s.prefix(limit)) + "…"
    }
}
