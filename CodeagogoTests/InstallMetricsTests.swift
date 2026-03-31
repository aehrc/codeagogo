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

/// Tests for anonymous install metrics identifier generation and persistence.
final class InstallMetricsTests: XCTestCase {

    private let installIdKey = "metrics.installId"

    // MARK: - ID Generation

    @MainActor
    func testInstallId_isNotEmpty() {
        let metrics = InstallMetrics.shared
        XCTAssertFalse(metrics.installId.isEmpty, "Install ID should not be empty")
    }

    @MainActor
    func testInstallId_isValidUUID() {
        let metrics = InstallMetrics.shared
        XCTAssertNotNil(
            UUID(uuidString: metrics.installId),
            "Install ID should be a valid UUID, got: \(metrics.installId)"
        )
    }

    // MARK: - Persistence

    @MainActor
    func testInstallId_isPersistedInUserDefaults() {
        let metrics = InstallMetrics.shared
        // Ensure the key is set by writing the current value
        UserDefaults.standard.set(metrics.installId, forKey: installIdKey)
        let stored = UserDefaults.standard.string(forKey: installIdKey)
        XCTAssertEqual(metrics.installId, stored, "Install ID should be persisted in UserDefaults")
    }

    @MainActor
    func testInstallId_isStableAcrossAccesses() {
        let metrics = InstallMetrics.shared
        let first = metrics.installId
        let second = metrics.installId
        XCTAssertEqual(first, second, "Install ID should be stable across accesses")
    }

    // MARK: - Thread-Safe Accessor

    func testCurrentInstallId_isNotEmpty() {
        let id = InstallMetrics.currentInstallId
        XCTAssertFalse(id.isEmpty, "Static currentInstallId should not be empty")
    }

    func testCurrentInstallId_isValidUUID() {
        let id = InstallMetrics.currentInstallId
        XCTAssertNotNil(
            UUID(uuidString: id),
            "Static currentInstallId should be a valid UUID, got: \(id)"
        )
    }

    func testCurrentInstallId_matchesSharedInstance() async {
        let staticId = InstallMetrics.currentInstallId
        let sharedId = await InstallMetrics.shared.installId
        XCTAssertEqual(staticId, sharedId, "Static accessor should return same ID as shared instance")
    }

    // MARK: - Reset

    @MainActor
    func testResetInstallId_producesNewId() {
        let metrics = InstallMetrics.shared
        let original = metrics.installId
        metrics.resetInstallId()
        XCTAssertNotEqual(
            original, metrics.installId,
            "Reset should produce a different install ID"
        )
    }

    @MainActor
    func testResetInstallId_persistsNewId() {
        let metrics = InstallMetrics.shared
        metrics.resetInstallId()
        let stored = UserDefaults.standard.string(forKey: installIdKey)
        XCTAssertEqual(
            metrics.installId, stored,
            "Reset install ID should be persisted in UserDefaults"
        )
    }

    @MainActor
    func testResetInstallId_newIdIsValidUUID() {
        let metrics = InstallMetrics.shared
        metrics.resetInstallId()
        XCTAssertNotNil(
            UUID(uuidString: metrics.installId),
            "Reset install ID should be a valid UUID, got: \(metrics.installId)"
        )
    }
}
