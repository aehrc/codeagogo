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

import XCTest
@testable import Codeagogo

/// Tests for WelcomeView static properties and WelcomeWindowController behavior.
@MainActor
final class WelcomeViewTests: XCTestCase {

    // MARK: - URL Constants

    func testMailingListURL_isValid() {
        let url = WelcomeView.mailingListURL
        XCTAssertEqual(
            url.absoluteString,
            "https://lists.csiro.au/mailman3/lists/codeagogo.lists.csiro.au/",
            "Mailing list URL should match the CSIRO Mailman page"
        )
    }

    func testMailingListURL_usesHTTPS() {
        let url = WelcomeView.mailingListURL
        XCTAssertEqual(url.scheme, "https", "Mailing list URL should use HTTPS")
    }

    func testGitHubURL_isValid() {
        let url = WelcomeView.gitHubURL
        XCTAssertEqual(
            url.absoluteString,
            "https://github.com/aehrc/codeagogo",
            "GitHub URL should match the aehrc/codeagogo repository"
        )
    }

    func testGitHubURL_usesHTTPS() {
        let url = WelcomeView.gitHubURL
        XCTAssertEqual(url.scheme, "https", "GitHub URL should use HTTPS")
    }

    func testGitHubIssuesURL_isValid() {
        let url = WelcomeView.gitHubIssuesURL
        XCTAssertEqual(
            url.absoluteString,
            "https://github.com/aehrc/codeagogo/issues",
            "GitHub issues URL should point to the issues page"
        )
    }

    // MARK: - Dismiss Callback

    func testWelcomeView_onDismiss_callbackInvoked() {
        var dismissed = false
        let view = WelcomeView(onDismiss: { dismissed = true })
        view.onDismiss()
        XCTAssertTrue(dismissed, "onDismiss callback should be invoked")
    }

    // MARK: - WelcomeSettings Integration

    func testWelcomeSettings_markAsShown_setsFlag() {
        let settings = WelcomeSettings.shared
        settings.reset()
        XCTAssertFalse(settings.hasShown)
        settings.markAsShown()
        XCTAssertTrue(settings.hasShown)
    }

    func testWelcomeSettings_reset_clearsFlag() {
        let settings = WelcomeSettings.shared
        settings.markAsShown()
        settings.reset()
        XCTAssertFalse(settings.hasShown)
    }
}
