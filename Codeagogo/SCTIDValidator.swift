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

/// Validates SNOMED CT identifiers using the Verhoeff check digit algorithm.
///
/// SNOMED CT identifiers (SCTIDs) are 6-18 digit numeric strings that include
/// a Verhoeff check digit as the last digit. This validator verifies both the
/// format and the check digit.
///
/// ## Example
///
/// ```swift
/// SCTIDValidator.isValidSCTID("73211009")  // true - valid SNOMED concept
/// SCTIDValidator.isValidSCTID("73211000")  // false - invalid check digit
/// SCTIDValidator.isValidSCTID("12345")     // false - too short
/// SCTIDValidator.isValidSCTID("8867-4")    // false - not numeric (LOINC code)
/// ```
///
/// - SeeAlso: [SNOMED CT Technical Implementation Guide](https://confluence.ihtsdotools.org/display/DOCRELFMT)
enum SCTIDValidator {
    /// Validates that a string is a valid SNOMED CT identifier.
    ///
    /// A valid SCTID:
    /// - Contains only digits (0-9)
    /// - Is between 6 and 18 characters long
    /// - Passes Verhoeff check digit validation
    ///
    /// - Parameter candidate: The string to validate
    /// - Returns: `true` if the string is a valid SNOMED CT identifier
    static func isValidSCTID(_ candidate: String) -> Bool {
        // Must be 6-18 digits only
        guard candidate.count >= 6, candidate.count <= 18,
              candidate.allSatisfy({ $0.isNumber }) else {
            return false
        }
        return verhoeffCheck(candidate)
    }

    /// Checks whether a valid SCTID uses the short format (no namespace), indicating
    /// it is a core International Edition concept.
    ///
    /// SNOMED CT identifiers encode a partition identifier in the 2nd and 3rd last digits.
    /// Short-format IDs have `0` as the 3rd-last digit (no namespace embedded),
    /// meaning they originate from the International Edition. Long-format IDs have `1`
    /// as the 3rd-last digit and include a 7-digit namespace identifier.
    ///
    /// - Parameter sctid: A validated SCTID string (must pass `isValidSCTID` first)
    /// - Returns: `true` if the SCTID is short-format (International/core), `false` if namespaced
    static func isCoreSCTID(_ sctid: String) -> Bool {
        guard sctid.count >= 6 else { return false }
        let thirdFromEnd = sctid[sctid.index(sctid.endIndex, offsetBy: -3)]
        return thirdFromEnd == "0"
    }

    // MARK: - Verhoeff Algorithm

    /// Verhoeff check digit validation using dihedral group D5 multiplication.
    ///
    /// The Verhoeff algorithm is based on the dihedral group D5 (the symmetry
    /// group of a regular pentagon). It can detect all single-digit errors and
    /// all adjacent transposition errors.
    ///
    /// - Parameter s: The numeric string to validate
    /// - Returns: `true` if the string passes Verhoeff validation (check digit is 0)
    private static func verhoeffCheck(_ s: String) -> Bool {
        // D5 multiplication table
        let d: [[Int]] = [
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
            [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
            [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
            [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
            [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
            [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
            [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
            [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
            [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
            [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
        ]

        // Permutation table
        let p: [[Int]] = [
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
            [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
            [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
            [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
            [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
            [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
            [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
            [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]
        ]

        let digits = s.reversed().compactMap { $0.wholeNumberValue }
        var c = 0
        for (i, digit) in digits.enumerated() {
            c = d[c][p[i % 8][digit]]
        }
        return c == 0
    }
}
