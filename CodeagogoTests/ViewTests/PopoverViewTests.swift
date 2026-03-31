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

/// Tests for PopoverView data models verifying the concept result properties
/// that drive the view's display logic.
@MainActor
final class PopoverViewTests: XCTestCase {

    // MARK: - Helpers

    private func makeSNOMEDResult() -> ConceptResult {
        ConceptResult(
            conceptId: "73211009",
            branch: "International (20240101)",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: true,
            effectiveTime: "20020131",
            moduleId: "900000000000207008",
            system: "http://snomed.info/sct"
        )
    }

    private func makeLOINCResult() -> ConceptResult {
        ConceptResult(
            conceptId: "8867-4",
            branch: "LOINC (2.81)",
            fsn: nil,
            pt: "Heart rate",
            active: true,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://loinc.org"
        )
    }

    // MARK: - Model State Tests

    /// Verifies SNOMED result properties for display.
    func testPopoverView_snomedResult_modelValues() {
        let result = makeSNOMEDResult()
        XCTAssertEqual(result.conceptId, "73211009")
        XCTAssertTrue(result.isSNOMEDCT)
        XCTAssertEqual(result.pt, "Diabetes mellitus")
        XCTAssertEqual(result.fsn, "Diabetes mellitus (disorder)")
        XCTAssertEqual(result.active, true)
    }

    /// Verifies LOINC result properties for non-SNOMED display.
    func testPopoverView_loincResult_modelValues() {
        let result = makeLOINCResult()
        XCTAssertFalse(result.isSNOMEDCT)
        XCTAssertEqual(result.systemName, "LOINC")
        XCTAssertEqual(result.pt, "Heart rate")
    }

    /// Verifies inactive concept result for status row display.
    func testPopoverView_inactiveResult_modelValues() {
        let result = ConceptResult(
            conceptId: "73211009",
            branch: "International (20240101)",
            fsn: "Diabetes mellitus (disorder)",
            pt: "Diabetes mellitus",
            active: false,
            effectiveTime: "20020131",
            moduleId: "900000000000207008",
            system: "http://snomed.info/sct"
        )
        XCTAssertEqual(result.active, false)
    }

    /// Verifies SNOMED result has expected branch/edition.
    func testPopoverView_snomedResult_hasBranch() {
        let result = makeSNOMEDResult()
        XCTAssertEqual(result.branch, "International (20240101)")
    }

    /// Verifies LOINC result has nil FSN.
    func testPopoverView_loincResult_nilFSN() {
        let result = makeLOINCResult()
        XCTAssertNil(result.fsn)
    }

    /// Verifies result with all fields populated.
    func testPopoverView_fullResult_allFieldsPopulated() {
        let result = makeSNOMEDResult()
        XCTAssertNotNil(result.effectiveTime)
        XCTAssertNotNil(result.moduleId)
        XCTAssertNotNil(result.system)
    }
}
