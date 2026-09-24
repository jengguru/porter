import XCTest
@testable import PorterCore

final class HotkeyTests: XCTestCase {
    func testDefaultShortcut() {
        XCTAssertEqual(Hotkey.default.displayString, "⌃⌥⌘B")
        XCTAssertEqual(Hotkey.default.menuKeyEquivalent, "b")
        XCTAssertTrue(Hotkey.default.isValid)
    }

    func testShortcutNeedsCommandOptionOrControl() {
        XCTAssertFalse(Hotkey(keyCode: 11, modifiers: []).isValid)
        XCTAssertFalse(Hotkey(keyCode: 11, modifiers: [.shift]).isValid)
        XCTAssertTrue(Hotkey(keyCode: 11, modifiers: [.option]).isValid)
    }

    func testUnknownKeysAreInvalid() {
        XCTAssertFalse(Hotkey(keyCode: 53, modifiers: [.command]).isValid) // Esc
        XCTAssertFalse(Hotkey(keyCode: 999, modifiers: [.command]).isValid)
    }

    func testNonCharacterKeysHaveNoMenuEquivalent() {
        XCTAssertEqual(Hotkey(keyCode: 122, modifiers: [.command]).displayString, "⌘F1")
        XCTAssertNil(Hotkey(keyCode: 122, modifiers: [.command]).menuKeyEquivalent)
        XCTAssertNil(Hotkey(keyCode: 123, modifiers: [.command]).menuKeyEquivalent)
    }
}
