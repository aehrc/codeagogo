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

/// Tests for SNOMED CT ID validation using the Verhoeff algorithm.
final class SCTIDValidatorTests: XCTestCase {

    // MARK: - Valid SCTID Tests

    func testValidSCTID_DiabetesMellitus() {
        // 73211009 = Diabetes mellitus (disorder)
        XCTAssertTrue(SCTIDValidator.isValidSCTID("73211009"))
    }

    func testValidSCTID_ClinicalFinding() {
        // 404684003 = Clinical finding (finding)
        XCTAssertTrue(SCTIDValidator.isValidSCTID("404684003"))
    }

    func testValidSCTID_InternationalModule() {
        // 900000000000207008 = SNOMED CT core module (18 digits)
        XCTAssertTrue(SCTIDValidator.isValidSCTID("900000000000207008"))
    }

    func testValidSCTID_Aspirin() {
        // 387458008 = Aspirin (substance)
        XCTAssertTrue(SCTIDValidator.isValidSCTID("387458008"))
    }

    func testValidSCTID_FSNDesignationCode() {
        // 900000000000003001 = Fully Specified Name designation code
        XCTAssertTrue(SCTIDValidator.isValidSCTID("900000000000003001"))
    }

    // MARK: - Invalid Check Digit Tests

    func testInvalidCheckDigit_DiabetesWrong() {
        // 73211009 with wrong check digit (0 instead of 9)
        XCTAssertFalse(SCTIDValidator.isValidSCTID("73211000"))
    }

    func testInvalidCheckDigit_InternationalModuleWrong() {
        // Wrong check digit
        XCTAssertFalse(SCTIDValidator.isValidSCTID("900000000000207000"))
    }

    func testInvalidCheckDigit_OffByOne() {
        // 73211008 - off by one from valid 73211009
        XCTAssertFalse(SCTIDValidator.isValidSCTID("73211008"))
    }

    // MARK: - Length Validation Tests

    func testTooShort_5Digits() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("12345"))
    }

    func testTooShort_4Digits() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("1234"))
    }

    func testTooShort_1Digit() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("1"))
    }

    func testTooLong_19Digits() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("1234567890123456789"))
    }

    func testTooLong_20Digits() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("12345678901234567890"))
    }

    func testEmpty() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID(""))
    }

    // MARK: - Non-Numeric Input Tests

    func testAlphanumeric_LOINCCode() {
        // LOINC code format
        XCTAssertFalse(SCTIDValidator.isValidSCTID("8867-4"))
    }

    func testAlphanumeric_ICD10Code() {
        // ICD-10 code format
        XCTAssertFalse(SCTIDValidator.isValidSCTID("J45.901"))
    }

    func testAlphanumeric_LettersOnly() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("ABCDEFGH"))
    }

    func testAlphanumeric_MixedLettersAndDigits() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("ABC123456"))
    }

    func testContainsSpaces() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("73211 009"))
    }

    func testContainsSpecialCharacters() {
        XCTAssertFalse(SCTIDValidator.isValidSCTID("73211!009"))
    }

    // MARK: - Edge Cases

    func testBoundaryLength_18Digits() {
        // Maximum valid length (18 digits)
        // 900000000000207008 is the SNOMED CT core module ID
        XCTAssertTrue(SCTIDValidator.isValidSCTID("900000000000207008"))
    }

    func testShortNumericString_RejectsInvalidCheckDigit() {
        // A 6-digit number with invalid check digit should fail
        XCTAssertFalse(SCTIDValidator.isValidSCTID("123456"))
    }

    func testRealSNOMEDCTIDs_Pass() {
        // All real SNOMED CT concept IDs should pass Verhoeff
        let validIds = [
            "73211009",      // Diabetes mellitus
            "404684003",     // Clinical finding
            "387458008",     // Aspirin
            "385804009",     // Diabetic care
            "138875005",     // SNOMED CT root concept
            "48176007",      // Social context
        ]

        for id in validIds {
            XCTAssertTrue(SCTIDValidator.isValidSCTID(id), "Expected \(id) to be valid")
        }
    }

    func testRealSNOMEDCTIDs_ModifiedDigitFails() {
        // Changing any digit in a valid SCTID should make it invalid
        // Original: 73211009, modified last digit
        XCTAssertFalse(SCTIDValidator.isValidSCTID("73211000"))
        XCTAssertFalse(SCTIDValidator.isValidSCTID("73211001"))
        XCTAssertFalse(SCTIDValidator.isValidSCTID("73211002"))
    }

    // MARK: - Core SCTID (Namespace) Tests

    func testIsCoreSCTID_internationalConcept() {
        // 73211009: 3rd-last digit is '0' → core/International
        XCTAssertTrue(SCTIDValidator.isCoreSCTID("73211009"))
    }

    func testIsCoreSCTID_internationalAttribute() {
        // 127489000: 3rd-last digit is '0' → core/International
        XCTAssertTrue(SCTIDValidator.isCoreSCTID("127489000"))
    }

    func testIsCoreSCTID_namespacedAustralian() {
        // 929360061000036106: 3rd-last digit is '1' → namespaced (Australian)
        XCTAssertFalse(SCTIDValidator.isCoreSCTID("929360061000036106"))
    }

    func testIsCoreSCTID_namespacedAustralianAMT() {
        // 21415011000036108: 3rd-last digit is '1' → namespaced (Australian)
        XCTAssertFalse(SCTIDValidator.isCoreSCTID("21415011000036108"))
    }

    func testIsCoreSCTID_internationalModuleId() {
        // 900000000000207008: 3rd-last digit is '0' → core
        XCTAssertTrue(SCTIDValidator.isCoreSCTID("900000000000207008"))
    }

    func testIsCoreSCTID_tooShort() {
        XCTAssertFalse(SCTIDValidator.isCoreSCTID("12345"))
    }
}
