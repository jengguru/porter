import XCTest
@testable import PorterCore

final class HotkeyTests: XCTestCase {
    func testDefaultShortcut() {
        XCTAssertEqual(Hotkey.default.displayString, "⌃⌥⌘B")
        XCTAssertEqual(Hotkey.default.menuKeyEquivalent, "b")
        XCTAssertTrue(Hotkey.default.isValid)
    }

    func testShortcutNeedsTwoOfCommandOptionControl() {
        XCTAssertFalse(Hotkey(keyCode: 11, modifiers: []).isValid)
        XCTAssertFalse(Hotkey(keyCode: 11, modifiers: [.shift]).isValid)
        XCTAssertFalse(Hotkey(keyCode: 11, modifiers: [.option]).isValid, "⌥B types ∫")
        XCTAssertFalse(Hotkey(keyCode: 11, modifiers: [.command]).isValid, "⌘B is Bold everywhere")
        XCTAssertFalse(Hotkey(keyCode: 8, modifiers: [.control]).isValid, "⌃C interrupts in Terminal")
        XCTAssertFalse(Hotkey(keyCode: 11, modifiers: [.command, .shift]).isValid, "⇧ doesn't count")
        XCTAssertTrue(Hotkey(keyCode: 11, modifiers: [.option, .command]).isValid)
    }

    func testUnknownKeysAreInvalid() {
        XCTAssertFalse(Hotkey(keyCode: 53, modifiers: [.command, .option]).isValid) // Esc
        XCTAssertFalse(Hotkey(keyCode: 999, modifiers: [.command, .option]).isValid)
    }

    func testNonCharacterKeysHaveNoMenuEquivalent() {
        XCTAssertEqual(Hotkey(keyCode: 122, modifiers: [.command]).displayString, "⌘F1")
        XCTAssertNil(Hotkey(keyCode: 122, modifiers: [.command]).menuKeyEquivalent)
        XCTAssertNil(Hotkey(keyCode: 123, modifiers: [.command]).menuKeyEquivalent)
    }
}
