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

@MainActor
final class UpdateCheckerTests: XCTestCase {

    private let checker = UpdateChecker.shared

    // MARK: - Version Comparison

    func testIsNewer_majorBump() {
        XCTAssertTrue(checker.isNewer("2.0.0", than: "1.0.0"))
    }

    func testIsNewer_minorBump() {
        XCTAssertTrue(checker.isNewer("1.1.0", than: "1.0.0"))
    }

    func testIsNewer_patchBump() {
        XCTAssertTrue(checker.isNewer("1.0.1", than: "1.0.0"))
    }

    func testIsNewer_sameVersion() {
        XCTAssertFalse(checker.isNewer("1.0.0", than: "1.0.0"))
    }

    func testIsNewer_olderMajor() {
        XCTAssertFalse(checker.isNewer("1.0.0", than: "2.0.0"))
    }

    func testIsNewer_olderMinor() {
        XCTAssertFalse(checker.isNewer("1.0.0", than: "1.1.0"))
    }

    func testIsNewer_olderPatch() {
        XCTAssertFalse(checker.isNewer("1.0.0", than: "1.0.1"))
    }

    func testIsNewer_higherMajorLowerMinor() {
        XCTAssertTrue(checker.isNewer("2.0.0", than: "1.9.9"))
    }

    func testIsNewer_differentLengths_newerHasMore() {
        XCTAssertTrue(checker.isNewer("1.0.0.1", than: "1.0.0"))
    }

    func testIsNewer_differentLengths_currentHasMore() {
        XCTAssertFalse(checker.isNewer("1.0.0", than: "1.0.0.1"))
    }

    func testIsNewer_twoPartVersions() {
        XCTAssertTrue(checker.isNewer("1.1", than: "1.0"))
        XCTAssertFalse(checker.isNewer("1.0", than: "1.1"))
    }

    func testIsNewer_largeVersionNumbers() {
        XCTAssertTrue(checker.isNewer("10.20.30", than: "10.20.29"))
        XCTAssertFalse(checker.isNewer("10.20.29", than: "10.20.30"))
    }
}
