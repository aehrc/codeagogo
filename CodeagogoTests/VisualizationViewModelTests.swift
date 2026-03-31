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

/// Tests for VisualizationViewModel with a mock client.
@MainActor
final class VisualizationViewModelTests: XCTestCase {

    // MARK: - Mock Client

    private class MockPropertyClient: ConceptPropertyLookup {
        var lookupWithPropertiesResult: Result<[ConceptProperty], Error> = .success([])
        var lookupResult: Result<ConceptResult, Error> = .success(
            ConceptResult(conceptId: "73211009", branch: "International", fsn: "Diabetes mellitus (disorder)",
                          pt: "Diabetes mellitus", active: true, effectiveTime: "20020131",
                          moduleId: "900000000000207008")
        )

        func lookupWithProperties(conceptId: String, system: String, version: String) async throws -> [ConceptProperty] {
            return try lookupWithPropertiesResult.get()
        }

        func lookup(conceptId: String) async throws -> ConceptResult {
            return try lookupResult.get()
        }

        func lookupPreferredTerm(conceptId: String, system: String) async throws -> String? {
            let result = try lookupResult.get()
            return result.pt ?? result.fsn
        }
    }

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

    // MARK: - Tests

    /// Verifies that loadProperties populates visualizationData on success.
    func testLoadProperties_setsVisualizationData() async {
        let mockClient = MockPropertyClient()
        let properties = [
            ConceptProperty(code: "effectiveTime", value: .string("20020131"), display: nil),
            ConceptProperty(code: "sufficientlyDefined", value: .boolean(true), display: nil),
        ]
        mockClient.lookupWithPropertiesResult = .success(properties)

        let viewModel = VisualizationViewModel(client: mockClient)
        await viewModel.loadProperties(for: makeSNOMEDResult())

        XCTAssertNotNil(viewModel.visualizationData)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.visualizationData?.properties.count, 2)
    }

    /// Verifies isLoading transitions true → false during loadProperties.
    func testLoadProperties_loadingStateTransitions() async {
        let mockClient = MockPropertyClient()
        let viewModel = VisualizationViewModel(client: mockClient)

        XCTAssertFalse(viewModel.isLoading)
        await viewModel.loadProperties(for: makeSNOMEDResult())
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after completion")
    }

    /// Verifies that an error from the client sets the error message.
    func testLoadProperties_onError_setsErrorMessage() async {
        let mockClient = MockPropertyClient()
        mockClient.lookupWithPropertiesResult = .failure(NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Network timeout"]
        ))

        let viewModel = VisualizationViewModel(client: mockClient)
        await viewModel.loadProperties(for: makeSNOMEDResult())

        XCTAssertNotNil(viewModel.error)
        XCTAssertNil(viewModel.visualizationData)
    }

    /// Verifies SNOMED CT version URI is constructed with moduleId.
    func testExtractVersion_snomedCT_usesModuleId() async {
        let mockClient = MockPropertyClient()
        var receivedVersion: String?

        // Capture the version parameter
        class CapturingClient: ConceptPropertyLookup {
            var capturedVersion: String?

            func lookupWithProperties(conceptId: String, system: String, version: String) async throws -> [ConceptProperty] {
                capturedVersion = version
                return []
            }

            func lookup(conceptId: String) async throws -> ConceptResult {
                return ConceptResult(conceptId: conceptId, branch: "", fsn: nil, pt: nil,
                                     active: nil, effectiveTime: nil, moduleId: nil)
            }

            func lookupPreferredTerm(conceptId: String, system: String) async throws -> String? {
                return nil
            }
        }

        let capturingClient = CapturingClient()
        let viewModel = VisualizationViewModel(client: capturingClient)
        await viewModel.loadProperties(for: makeSNOMEDResult())

        XCTAssertEqual(capturingClient.capturedVersion, "http://snomed.info/sct/900000000000207008")
    }

    /// Verifies non-SNOMED concepts use branch as version.
    func testExtractVersion_nonSNOMED_usesBranch() async {
        class CapturingClient: ConceptPropertyLookup {
            var capturedVersion: String?

            func lookupWithProperties(conceptId: String, system: String, version: String) async throws -> [ConceptProperty] {
                capturedVersion = version
                return []
            }

            func lookup(conceptId: String) async throws -> ConceptResult {
                return ConceptResult(conceptId: conceptId, branch: "", fsn: nil, pt: nil,
                                     active: nil, effectiveTime: nil, moduleId: nil)
            }

            func lookupPreferredTerm(conceptId: String, system: String) async throws -> String? {
                return nil
            }
        }

        let capturingClient = CapturingClient()
        let viewModel = VisualizationViewModel(client: capturingClient)

        let loincResult = ConceptResult(
            conceptId: "8867-4",
            branch: "LOINC (2.81)",
            fsn: nil,
            pt: "Heart rate",
            active: true,
            effectiveTime: nil,
            moduleId: nil,
            system: "http://loinc.org"
        )

        await viewModel.loadProperties(for: loincResult)

        XCTAssertEqual(capturingClient.capturedVersion, "LOINC (2.81)")
    }
}
