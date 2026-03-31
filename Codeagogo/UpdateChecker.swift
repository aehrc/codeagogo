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

/// Checks for new releases on GitHub and publishes update availability.
///
/// Queries the GitHub Releases API for the latest release tag, compares it
/// against the app's current `MARKETING_VERSION`, and sets `updateAvailable`
/// when a newer version exists. Checks automatically on launch and every
/// 24 hours, with a manual "Check for Updates" option.
@MainActor
final class UpdateChecker: ObservableObject {

    /// Shared singleton instance.
    static let shared = UpdateChecker()

    /// Whether a newer version is available on GitHub.
    @Published private(set) var updateAvailable = false

    /// The latest version string from GitHub (e.g., "1.1.0"), or nil if not checked.
    @Published private(set) var latestVersion: String?

    /// The URL to the latest release page on GitHub.
    @Published private(set) var releaseURL: URL?

    /// Whether a check is currently in progress.
    @Published private(set) var isChecking = false

    /// The last time an update check completed successfully.
    @Published private(set) var lastCheckDate: Date?

    /// GitHub repository owner and name.
    private static let repoOwner = "aehrc"
    private static let repoName = "codeagogo"

    /// How often to check automatically (24 hours).
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    /// UserDefaults keys for persisting state.
    private static let lastCheckKey = "updateChecker.lastCheckDate"
    private static let latestVersionKey = "updateChecker.latestVersion"
    private static let releaseURLKey = "updateChecker.releaseURL"

    /// Timer for periodic checks.
    private var timer: Timer?

    private init() {
        // Restore persisted state
        lastCheckDate = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        latestVersion = UserDefaults.standard.string(forKey: Self.latestVersionKey)
        if let urlString = UserDefaults.standard.string(forKey: Self.releaseURLKey) {
            releaseURL = URL(string: urlString)
        }

        // Re-evaluate update availability from persisted state
        if let latest = latestVersion {
            updateAvailable = isNewer(latest, than: currentVersion)
        }
    }

    /// The app's current marketing version.
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Starts automatic update checking on launch and on a 24-hour timer.
    func startPeriodicChecks() {
        Task {
            await checkForUpdates()
        }

        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates()
            }
        }
    }

    /// Stops automatic update checking.
    func stopPeriodicChecks() {
        timer?.invalidate()
        timer = nil
    }

    /// Manually triggers an update check.
    @discardableResult
    func checkForUpdates() async -> Bool {
        guard !isChecking else { return updateAvailable }
        isChecking = true
        defer { isChecking = false }

        do {
            let (version, url) = try await fetchLatestRelease()
            latestVersion = version
            releaseURL = url
            lastCheckDate = Date()
            updateAvailable = isNewer(version, than: currentVersion)

            // Persist
            UserDefaults.standard.set(lastCheckDate, forKey: Self.lastCheckKey)
            UserDefaults.standard.set(version, forKey: Self.latestVersionKey)
            UserDefaults.standard.set(url?.absoluteString, forKey: Self.releaseURLKey)

            if updateAvailable {
                AppLog.info(AppLog.general, "Update available: v\(version) (current: v\(currentVersion))")
            } else {
                AppLog.debug(AppLog.general, "App is up to date (v\(currentVersion))")
            }
        } catch {
            AppLog.warning(AppLog.general, "Update check failed: \(error.localizedDescription)")
        }

        return updateAvailable
    }

    // MARK: - GitHub API

    /// Fetches the latest release version and URL from the GitHub Releases API.
    private func fetchLatestRelease() async throws -> (String, URL?) {
        let url = URL(string: "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest")!

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Codeagogo/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw UpdateError.httpError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateError.parseError
        }

        guard let tagName = json["tag_name"] as? String else {
            throw UpdateError.parseError
        }

        // Strip leading "v" from tag (e.g., "v1.1.0" → "1.1.0")
        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        let htmlURL = (json["html_url"] as? String).flatMap(URL.init(string:))

        return (version, htmlURL)
    }

    // MARK: - Version Comparison

    /// Returns true if `latest` is a newer semver than `current`.
    func isNewer(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(latestParts.count, currentParts.count) {
            let latestPart = i < latestParts.count ? latestParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            if latestPart > currentPart { return true }
            if latestPart < currentPart { return false }
        }
        return false
    }
}

/// Errors that can occur during update checking.
enum UpdateError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .httpError(let code):
            return "GitHub returned HTTP \(code)"
        case .parseError:
            return "Could not parse release information"
        }
    }
}
