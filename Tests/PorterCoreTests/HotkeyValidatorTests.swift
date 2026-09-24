import XCTest
@testable import PorterCore

final class HotkeyValidatorTests: XCTestCase {
    private func problem(_ keyCode: UInt32, _ modifiers: Hotkey.Modifiers, system: [Hotkey] = []) -> HotkeyProblem? {
        HotkeyValidator.problem(for: Hotkey(keyCode: keyCode, modifiers: modifiers), systemShortcuts: system)
    }

    func testDefaultShortcutIsFree() {
        XCTAssertNil(HotkeyValidator.problem(for: .default, systemShortcuts: []))
    }

    func testSingleModifierIsRejected() {
        XCTAssertEqual(problem(11, [.command]), .needsTwoModifiers)
        XCTAssertEqual(problem(11, [.option, .shift]), .needsTwoModifiers)
    }

    func testUnsupportedKeyIsRejected() {
        XCTAssertEqual(problem(53, [.control, .option, .command]), .unsupportedKey)
    }

    func testEnabledSystemShortcutIsRejected() {
        let system = [Hotkey(keyCode: 11, modifiers: [.control, .option, .command])]
        XCTAssertEqual(HotkeyValidator.problem(for: .default, systemShortcuts: system), .reservedBySystem)
    }

    func testCommonAppShortcutsAreRejected() {
        XCTAssertEqual(problem(11, [.option, .command]), .commonShortcut(name: "Show Bookmarks (Safari, Chrome)"))
        XCTAssertEqual(problem(12, [.control, .command]), .commonShortcut(name: "Lock Screen"))
        XCTAssertEqual(problem(4, [.option, .command]), .commonShortcut(name: "Hide Others"))
    }

    func testCommonListOnlyHoldsShortcutsTheModifierRuleAllows() {
        for known in HotkeyValidator.commonShortcuts {
            XCTAssertTrue(known.hotkey.isValid, known.name)
        }
    }
}
