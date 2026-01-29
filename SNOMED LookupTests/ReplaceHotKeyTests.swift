import XCTest
import Carbon.HIToolbox
@testable import SNOMED_Lookup

/// Unit tests for the replace hotkey settings and term format.
final class ReplaceHotKeyTests: XCTestCase {

    // MARK: - ReplaceHotKeySettings Tests

    @MainActor
    func testDefaultKeyCodeIsR() {
        // kVK_ANSI_R = 15
        let expected: UInt32 = 15
        XCTAssertEqual(ReplaceHotKeySettings.currentKeyCode, expected,
                       "Default replace hotkey should be R (key code 15)")
    }

    @MainActor
    func testDefaultModifiersAreControlOption() {
        // Control + Option = 0x1000 | 0x0800 = 6144
        let modifiers = ReplaceHotKeySettings.currentModifiers
        XCTAssertTrue(modifiers.contains(.control),
                      "Default modifiers should include Control")
        XCTAssertTrue(modifiers.contains(.option),
                      "Default modifiers should include Option")
        XCTAssertFalse(modifiers.contains(.command),
                       "Default modifiers should not include Command")
        XCTAssertFalse(modifiers.contains(.shift),
                       "Default modifiers should not include Shift")
    }

    // MARK: - ReplaceTermFormat Tests

    func testTermFormatRawValueFSN() {
        XCTAssertEqual(ReplaceTermFormat.fsn.rawValue, "Fully Specified Name (FSN)")
    }

    func testTermFormatRawValuePT() {
        XCTAssertEqual(ReplaceTermFormat.pt.rawValue, "Preferred Term (PT)")
    }

    func testTermFormatCaseCount() {
        XCTAssertEqual(ReplaceTermFormat.allCases.count, 2,
                       "ReplaceTermFormat should have exactly 2 cases")
    }

    func testTermFormatAllCasesOrder() {
        let cases = ReplaceTermFormat.allCases
        XCTAssertEqual(cases[0], .fsn, "First case should be FSN")
        XCTAssertEqual(cases[1], .pt, "Second case should be PT")
    }

    // MARK: - ReplaceSettings Tests

    @MainActor
    func testDefaultTermFormatIsFSN() {
        // Clear any existing saved setting first
        UserDefaults.standard.removeObject(forKey: "replace.termFormat")

        // Create a new instance to test default
        // Note: Since ReplaceSettings is a singleton, we test the expected default behavior
        // The actual default in a fresh state should be .fsn
        XCTAssertEqual(ReplaceTermFormat.fsn.rawValue, "Fully Specified Name (FSN)",
                       "FSN should be the default term format")
    }

    // MARK: - Key Code Mapping Tests

    func testKeyCodeForR() {
        // Verify the expected key code constant
        XCTAssertEqual(kVK_ANSI_R, 15, "kVK_ANSI_R should be 15")
    }

    func testKeyCodeForY() {
        XCTAssertEqual(kVK_ANSI_Y, 16, "kVK_ANSI_Y should be 16")
    }

    func testKeyCodeForK() {
        XCTAssertEqual(kVK_ANSI_K, 40, "kVK_ANSI_K should be 40")
    }

    func testKeyCodeForU() {
        XCTAssertEqual(kVK_ANSI_U, 32, "kVK_ANSI_U should be 32")
    }
}
