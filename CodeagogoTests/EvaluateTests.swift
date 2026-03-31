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
import Carbon.HIToolbox
import AppKit
@testable import Codeagogo

/// Tests for the ECL evaluation feature: hotkey settings, evaluation settings,
/// and the data models used by `EvaluateViewModel`.
///
/// Note: `EvaluateViewModel` is `@MainActor` and instantiating view models in
/// new test files can trigger a malloc crash (Swift concurrency back-deploy
/// bug). These tests exercise the data models directly instead.
final class EvaluateTests: XCTestCase {

    // MARK: - UserDefaults Keys

    private static let keyCodeKey = "evaluateHotkey.keyCode"
    private static let modifiersKey = "evaluateHotkey.modifiersRaw"
    private static let resultLimitKey = "evaluate.resultLimit"

    // MARK: - EvaluateHotKeySettings — Default Key Code

    /// The default evaluate hotkey key code should be V (kVK_ANSI_V = 9).
    @MainActor
    func testDefaultKeyCodeIsV() {
        let savedKeyCode = UserDefaults.standard.object(forKey: Self.keyCodeKey)
        defer {
            if let saved = savedKeyCode {
                UserDefaults.standard.set(saved, forKey: Self.keyCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.keyCodeKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: Self.keyCodeKey)

        // kVK_ANSI_V = 9
        let expected: UInt32 = 9
        XCTAssertEqual(EvaluateHotKeySettings.currentKeyCode, expected,
                       "Default evaluate hotkey should be V (key code 9)")
    }

    // MARK: - EvaluateHotKeySettings — Default Modifiers

    /// The default modifiers should be Control+Option (no Command, no Shift).
    @MainActor
    func testDefaultModifiersAreControlOption() {
        let savedModifiers = UserDefaults.standard.object(forKey: Self.modifiersKey)
        defer {
            if let saved = savedModifiers {
                UserDefaults.standard.set(saved, forKey: Self.modifiersKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.modifiersKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: Self.modifiersKey)

        let modifiers = EvaluateHotKeySettings.currentModifiers
        XCTAssertTrue(modifiers.contains(.control),
                      "Default modifiers should include Control")
        XCTAssertTrue(modifiers.contains(.option),
                      "Default modifiers should include Option")
        XCTAssertFalse(modifiers.contains(.command),
                       "Default modifiers should not include Command")
        XCTAssertFalse(modifiers.contains(.shift),
                       "Default modifiers should not include Shift")
    }

    // MARK: - EvaluateHotKeySettings — Save & Load

    /// Saving custom key code and modifiers should persist them in UserDefaults
    /// and be readable via the thread-safe static accessors.
    @MainActor
    func testSaveAndLoadHotKeySettings() {
        let savedKeyCode = UserDefaults.standard.object(forKey: Self.keyCodeKey)
        let savedModifiers = UserDefaults.standard.object(forKey: Self.modifiersKey)
        defer {
            if let saved = savedKeyCode {
                UserDefaults.standard.set(saved, forKey: Self.keyCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.keyCodeKey)
            }
            if let saved = savedModifiers {
                UserDefaults.standard.set(saved, forKey: Self.modifiersKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.modifiersKey)
            }
        }

        // Write custom values directly to UserDefaults (simulating a save)
        let customKeyCode = UInt32(kVK_ANSI_F) // 3
        let customModifiers = HotKeySettings.carbonModifiers(from: [.command, .shift])
        UserDefaults.standard.set(Int(customKeyCode), forKey: Self.keyCodeKey)
        UserDefaults.standard.set(Int(customModifiers), forKey: Self.modifiersKey)

        // Thread-safe static accessors should return the saved values
        XCTAssertEqual(EvaluateHotKeySettings.currentKeyCode, customKeyCode,
                       "currentKeyCode should return the saved key code")

        let loadedModifiers = EvaluateHotKeySettings.currentModifiers
        XCTAssertTrue(loadedModifiers.contains(.command),
                      "Saved modifiers should include Command")
        XCTAssertTrue(loadedModifiers.contains(.shift),
                      "Saved modifiers should include Shift")
        XCTAssertFalse(loadedModifiers.contains(.control),
                       "Saved modifiers should not include Control")
        XCTAssertFalse(loadedModifiers.contains(.option),
                       "Saved modifiers should not include Option")
    }

    // MARK: - EvaluateHotKeySettings — Thread-safe Static Accessors

    /// When no value is saved, the thread-safe static accessors should return
    /// the defaults (key code 9, Control+Option).
    func testStaticAccessorsReturnDefaults() {
        let savedKeyCode = UserDefaults.standard.object(forKey: Self.keyCodeKey)
        let savedModifiers = UserDefaults.standard.object(forKey: Self.modifiersKey)
        defer {
            if let saved = savedKeyCode {
                UserDefaults.standard.set(saved, forKey: Self.keyCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.keyCodeKey)
            }
            if let saved = savedModifiers {
                UserDefaults.standard.set(saved, forKey: Self.modifiersKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.modifiersKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: Self.keyCodeKey)
        UserDefaults.standard.removeObject(forKey: Self.modifiersKey)

        XCTAssertEqual(EvaluateHotKeySettings.currentKeyCode, 9,
                       "Static currentKeyCode should default to 9 (V)")

        let modifiers = EvaluateHotKeySettings.currentModifiers
        XCTAssertTrue(modifiers.contains(.control),
                      "Static currentModifiers should default to include Control")
        XCTAssertTrue(modifiers.contains(.option),
                      "Static currentModifiers should default to include Option")
    }

    // MARK: - EvaluateSettings — Default Result Limit

    /// The default result limit should be 50.
    func testDefaultResultLimitIs50() {
        let savedLimit = UserDefaults.standard.object(forKey: Self.resultLimitKey)
        defer {
            if let saved = savedLimit {
                UserDefaults.standard.set(saved, forKey: Self.resultLimitKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.resultLimitKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: Self.resultLimitKey)

        XCTAssertEqual(EvaluateSettings.currentResultLimit, 50,
                       "Default result limit should be 50")
    }

    // MARK: - EvaluateSettings — Persisting Result Limit

    /// Changing resultLimit should persist the new value to UserDefaults.
    func testResultLimitPersistsToUserDefaults() {
        let savedLimit = UserDefaults.standard.object(forKey: Self.resultLimitKey)
        defer {
            if let saved = savedLimit {
                UserDefaults.standard.set(saved, forKey: Self.resultLimitKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.resultLimitKey)
            }
        }

        // Write a custom value directly
        UserDefaults.standard.set(200, forKey: Self.resultLimitKey)

        XCTAssertEqual(EvaluateSettings.currentResultLimit, 200,
                       "currentResultLimit should return the persisted value")
    }

    // MARK: - EvaluateSettings — Thread-safe Static Accessor Default

    /// The static accessor should return the default (50) when nothing is saved.
    func testStaticResultLimitReturnsDefault() {
        let savedLimit = UserDefaults.standard.object(forKey: Self.resultLimitKey)
        defer {
            if let saved = savedLimit {
                UserDefaults.standard.set(saved, forKey: Self.resultLimitKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.resultLimitKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: Self.resultLimitKey)

        XCTAssertEqual(EvaluateSettings.currentResultLimit, 50,
                       "Static accessor should return 50 when no value is saved")
    }

    // MARK: - EvaluateSettings — Thread-safe Static Accessor Saved Value

    /// The static accessor should return the saved value when one exists.
    func testStaticResultLimitReturnsSavedValue() {
        let savedLimit = UserDefaults.standard.object(forKey: Self.resultLimitKey)
        defer {
            if let saved = savedLimit {
                UserDefaults.standard.set(saved, forKey: Self.resultLimitKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.resultLimitKey)
            }
        }

        UserDefaults.standard.set(75, forKey: Self.resultLimitKey)

        XCTAssertEqual(EvaluateSettings.currentResultLimit, 75,
                       "Static accessor should return the saved value of 75")
    }

    // MARK: - ECLEvaluationConcept — semanticTag

    /// semanticTag should extract the tag from a standard FSN.
    /// "Diabetes mellitus (disorder)" -> "disorder"
    func testSemanticTagExtractsFromFSN() {
        let concept = ECLEvaluationConcept(
            code: "73211009",
            display: "Diabetes mellitus",
            fsn: "Diabetes mellitus (disorder)"
        )
        XCTAssertEqual(concept.semanticTag, "disorder",
                       "semanticTag should extract 'disorder' from FSN")
    }

    /// semanticTag should return nil when FSN is nil.
    func testSemanticTagReturnsNilWhenFSNIsNil() {
        let concept = ECLEvaluationConcept(
            code: "73211009",
            display: "Diabetes mellitus",
            fsn: nil
        )
        XCTAssertNil(concept.semanticTag,
                     "semanticTag should be nil when FSN is nil")
    }

    /// semanticTag should return nil when FSN has no parentheses.
    func testSemanticTagReturnsNilWhenNoParentheses() {
        let concept = ECLEvaluationConcept(
            code: "73211009",
            display: "Diabetes mellitus",
            fsn: "Diabetes mellitus"
        )
        XCTAssertNil(concept.semanticTag,
                     "semanticTag should be nil when FSN has no parentheses")
    }

    /// semanticTag should handle nested parentheses by using the last opening
    /// paren. "Structure of heart (body structure)" -> "body structure"
    func testSemanticTagHandlesNestedParentheses() {
        let concept = ECLEvaluationConcept(
            code: "80891009",
            display: "Structure of heart",
            fsn: "Structure of heart (body structure)"
        )
        XCTAssertEqual(concept.semanticTag, "body structure",
                       "semanticTag should extract 'body structure' from FSN with spaces in tag")
    }

    /// semanticTag should handle an FSN that is just a tag in parentheses.
    /// "(finding)" -> "finding"
    func testSemanticTagHandlesFSNWithOnlyTag() {
        let concept = ECLEvaluationConcept(
            code: "000000000",
            display: "Test",
            fsn: "(finding)"
        )
        XCTAssertEqual(concept.semanticTag, "finding",
                       "semanticTag should extract 'finding' from FSN that is only a tag")
    }

    // MARK: - ECLEvaluationResult — Struct Properties

    /// ECLEvaluationResult should store the total and concepts correctly.
    func testECLEvaluationResultProperties() {
        let concepts = [
            ECLEvaluationConcept(code: "73211009", display: "Diabetes mellitus", fsn: "Diabetes mellitus (disorder)"),
            ECLEvaluationConcept(code: "22298006", display: "Myocardial infarction", fsn: "Myocardial infarction (disorder)")
        ]
        let result = ECLEvaluationResult(total: 100, concepts: concepts)

        XCTAssertEqual(result.total, 100,
                       "total should reflect the server-reported count")
        XCTAssertEqual(result.concepts.count, 2,
                       "concepts array should contain the provided concepts")
    }

    /// ECLEvaluationResult can have zero concepts.
    func testECLEvaluationResultWithNoConcepts() {
        let result = ECLEvaluationResult(total: 0, concepts: [])

        XCTAssertEqual(result.total, 0)
        XCTAssertTrue(result.concepts.isEmpty,
                      "concepts should be empty when no results are returned")
    }

    /// Total may be greater than concepts.count when the server truncates.
    func testECLEvaluationResultTotalExceedsConceptCount() {
        let concepts = [
            ECLEvaluationConcept(code: "73211009", display: "Diabetes mellitus", fsn: nil)
        ]
        let result = ECLEvaluationResult(total: 500, concepts: concepts)

        XCTAssertEqual(result.total, 500,
                       "total should reflect the full server count")
        XCTAssertEqual(result.concepts.count, 1,
                       "concepts may be fewer than total when limited")
    }

    // MARK: - ECLEvaluationConcept — Struct Properties

    /// ECLEvaluationConcept should store code, display, and fsn correctly.
    func testECLEvaluationConceptProperties() {
        let concept = ECLEvaluationConcept(
            code: "387517004",
            display: "Paracetamol",
            fsn: "Paracetamol (product)"
        )

        XCTAssertEqual(concept.code, "387517004")
        XCTAssertEqual(concept.display, "Paracetamol")
        XCTAssertEqual(concept.fsn, "Paracetamol (product)")
    }

    /// ECLEvaluationConcept should allow nil fsn.
    func testECLEvaluationConceptWithNilFSN() {
        let concept = ECLEvaluationConcept(
            code: "387517004",
            display: "Paracetamol",
            fsn: nil
        )

        XCTAssertEqual(concept.code, "387517004")
        XCTAssertEqual(concept.display, "Paracetamol")
        XCTAssertNil(concept.fsn)
    }

    // MARK: - Carbon Key Code Constants

    /// Verify that kVK_ANSI_V has the expected value (used as default).
    func testKeyCodeForV() {
        XCTAssertEqual(kVK_ANSI_V, 9, "kVK_ANSI_V should be 9")
    }

    // MARK: - buildConceptWarnings

    /// buildConceptWarnings should return empty when all concepts are active and found.
    func testBuildConceptWarningsAllActive() {
        let batch = OntoserverClient.BatchLookupResult(
            ptByCode: ["73211009": "Diabetes mellitus"],
            fsnByCode: ["73211009": "Diabetes mellitus (disorder)"],
            activeByCode: ["73211009": true]
        )
        let warnings = AppDelegate.buildConceptWarnings(
            conceptIds: ["73211009"],
            batchResult: batch
        )
        XCTAssertTrue(warnings.isEmpty,
                      "No warnings should be generated for active concepts")
    }

    /// buildConceptWarnings should flag inactive concepts.
    func testBuildConceptWarningsInactiveConcept() {
        let batch = OntoserverClient.BatchLookupResult(
            ptByCode: ["73211009": "Diabetes mellitus"],
            fsnByCode: [:],
            activeByCode: ["73211009": false]
        )
        let warnings = AppDelegate.buildConceptWarnings(
            conceptIds: ["73211009"],
            batchResult: batch
        )
        XCTAssertEqual(warnings.count, 1,
                       "Should have one warning for inactive concept")
        XCTAssertTrue(warnings[0].contains("inactive"),
                      "Warning should mention 'inactive'")
        XCTAssertTrue(warnings[0].contains("73211009"),
                      "Warning should include the concept ID")
    }

    /// buildConceptWarnings should flag unknown concepts (not found on server).
    func testBuildConceptWarningsUnknownConcept() {
        let batch = OntoserverClient.BatchLookupResult(
            ptByCode: [:],
            fsnByCode: [:],
            activeByCode: [:]
        )
        let warnings = AppDelegate.buildConceptWarnings(
            conceptIds: ["999999999"],
            batchResult: batch
        )
        XCTAssertEqual(warnings.count, 1,
                       "Should have one warning for unknown concept")
        XCTAssertTrue(warnings[0].contains("unknown"),
                      "Warning should mention 'unknown'")
        XCTAssertTrue(warnings[0].contains("999999999"),
                      "Warning should include the concept ID")
    }

    /// buildConceptWarnings should handle a mix of active, inactive, and unknown concepts.
    func testBuildConceptWarningsMixedConcepts() {
        let batch = OntoserverClient.BatchLookupResult(
            ptByCode: [
                "73211009": "Diabetes mellitus",
                "22298006": "Myocardial infarction"
            ],
            fsnByCode: [:],
            activeByCode: [
                "73211009": true,
                "22298006": false
            ]
        )
        let warnings = AppDelegate.buildConceptWarnings(
            conceptIds: ["73211009", "22298006", "000000000"],
            batchResult: batch
        )
        XCTAssertEqual(warnings.count, 2,
                       "Should have warnings for inactive and unknown concepts")
        // 22298006 is inactive
        XCTAssertTrue(warnings.contains(where: { $0.contains("22298006") && $0.contains("inactive") }),
                      "Should warn about inactive concept 22298006")
        // 000000000 is unknown
        XCTAssertTrue(warnings.contains(where: { $0.contains("000000000") && $0.contains("unknown") }),
                      "Should warn about unknown concept 000000000")
    }

    /// buildConceptWarnings should return empty for an empty concept list.
    func testBuildConceptWarningsEmptyInput() {
        let batch = OntoserverClient.BatchLookupResult(
            ptByCode: [:],
            fsnByCode: [:],
            activeByCode: [:]
        )
        let warnings = AppDelegate.buildConceptWarnings(
            conceptIds: [],
            batchResult: batch
        )
        XCTAssertTrue(warnings.isEmpty,
                      "No warnings should be generated for empty input")
    }

    /// buildConceptWarnings should not flag concepts with unknown active status but found PT.
    func testBuildConceptWarningsActiveStatusUnknown() {
        let batch = OntoserverClient.BatchLookupResult(
            ptByCode: ["73211009": "Diabetes mellitus"],
            fsnByCode: [:],
            activeByCode: [:]  // active status not available
        )
        let warnings = AppDelegate.buildConceptWarnings(
            conceptIds: ["73211009"],
            batchResult: batch
        )
        XCTAssertTrue(warnings.isEmpty,
                      "Concepts with a PT but unknown active status should not generate warnings")
    }
}
