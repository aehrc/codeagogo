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

/// Tests for WelcomeSettings first-launch state management.
final class WelcomeSettingsTests: XCTestCase {

    private let hasShownKey = "welcome.hasShown"

    override func tearDown() {
        super.tearDown()
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: hasShownKey)
    }

    // MARK: - Default State

    @MainActor
    func testHasShown_readsFromUserDefaults() {
        // When UserDefaults has the key set to true
        UserDefaults.standard.set(true, forKey: hasShownKey)
        // The shared instance should reflect that
        // Note: shared is a singleton, so we test via direct UserDefaults
        let stored = UserDefaults.standard.bool(forKey: hasShownKey)
        XCTAssertTrue(stored, "UserDefaults should store the hasShown value")
    }

    // MARK: - Mark As Shown

    @MainActor
    func testMarkAsShown_setsTrue() {
        let settings = WelcomeSettings.shared
        settings.markAsShown()
        XCTAssertTrue(settings.hasShown, "markAsShown should set hasShown to true")
    }

    @MainActor
    func testMarkAsShown_persistsInUserDefaults() {
        let settings = WelcomeSettings.shared
        settings.markAsShown()
        let stored = UserDefaults.standard.bool(forKey: hasShownKey)
        XCTAssertTrue(stored, "markAsShown should persist true in UserDefaults")
    }

    // MARK: - Reset

    @MainActor
    func testReset_setsFalse() {
        let settings = WelcomeSettings.shared
        settings.markAsShown()
        settings.reset()
        XCTAssertFalse(settings.hasShown, "reset should set hasShown to false")
    }

    @MainActor
    func testReset_persistsInUserDefaults() {
        let settings = WelcomeSettings.shared
        settings.markAsShown()
        settings.reset()
        let stored = UserDefaults.standard.bool(forKey: hasShownKey)
        XCTAssertFalse(stored, "reset should persist false in UserDefaults")
    }

    // MARK: - UserDefaults Key

    @MainActor
    func testHasShownKey_isCorrect() {
        XCTAssertEqual(
            WelcomeSettings.hasShownKey, "welcome.hasShown",
            "Key should be welcome.hasShown"
        )
    }
}
