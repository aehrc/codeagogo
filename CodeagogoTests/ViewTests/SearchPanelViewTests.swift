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

/// Tests for SearchPanelView data models verifying the search result properties
/// that drive the view's display logic.
@MainActor
final class SearchPanelViewTests: XCTestCase {

    // MARK: - SearchResult Model Tests

    /// Verifies SearchResult display text.
    func testSearchResult_display() {
        let result = SearchResult(
            code: "73211009",
            display: "Diabetes mellitus",
            fsn: "Diabetes mellitus (disorder)",
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/900000000000207008/version/20240101",
            editionName: "International"
        )
        XCTAssertEqual(result.code, "73211009")
        XCTAssertEqual(result.display, "Diabetes mellitus")
    }

    /// Verifies SearchResult FSN and edition.
    func testSearchResult_fsnAndEdition() {
        let result = SearchResult(
            code: "73211009",
            display: "Diabetes mellitus",
            fsn: "Diabetes mellitus (disorder)",
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/900000000000207008/version/20240101",
            editionName: "International"
        )
        XCTAssertEqual(result.fsn, "Diabetes mellitus (disorder)")
        XCTAssertEqual(result.editionName, "International")
    }

    /// Verifies SearchResult formatted output for ID|PT format.
    func testSearchResult_formattedIdPipePT() {
        let result = SearchResult(
            code: "73211009",
            display: "Diabetes mellitus",
            fsn: "Diabetes mellitus (disorder)",
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/900000000000207008/version/20240101",
            editionName: "International"
        )
        XCTAssertEqual(result.formatted(as: .idPipePT), "73211009 | Diabetes mellitus |")
    }

    /// Verifies SearchResult formatted output for code only.
    func testSearchResult_formattedIdOnly() {
        let result = SearchResult(
            code: "73211009",
            display: "Diabetes mellitus",
            fsn: nil,
            system: "http://snomed.info/sct",
            version: "http://snomed.info/sct/900000000000207008/version/20240101",
            editionName: "International"
        )
        XCTAssertEqual(result.formatted(as: .idOnly), "73211009")
        // When FSN is nil, fsnOnly format falls back to display
        XCTAssertEqual(result.formatted(as: .fsnOnly), "Diabetes mellitus")
    }
}
