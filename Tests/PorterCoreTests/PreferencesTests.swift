import XCTest
@testable import PorterCore

final class PreferencesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PorterTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaults() {
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.favoriteA, KnownBrowsers.chrome)
        XCTAssertEqual(prefs.favoriteB, KnownBrowsers.safari)
        XCTAssertEqual(prefs.hotkey, .default)
        XCTAssertTrue(prefs.hotkeyEnabled)
        XCTAssertEqual(prefs.iconStyle, .color)
        XCTAssertFalse(prefs.setsHTMLHandler)
        XCTAssertFalse(prefs.autoConfirmDialog, "Accessibility automation must be opt-in")
        XCTAssertFalse(prefs.showsNotification)
    }

    func testValuesPersist() {
        let prefs = Preferences(defaults: defaults)
        prefs.favoriteA = KnownBrowsers.brave
        prefs.menuOrder = [KnownBrowsers.safari, KnownBrowsers.brave]
        prefs.hiddenInMenu = ["com.google.chrome"]
        prefs.hotkey = Hotkey(keyCode: 45, modifiers: [.command, .shift])
        prefs.iconStyle = .monochrome
        prefs.autoConfirmDialog = true

        let reloaded = Preferences(defaults: defaults)
        XCTAssertEqual(reloaded.favoriteA, KnownBrowsers.brave)
        XCTAssertEqual(reloaded.menuOrder, [KnownBrowsers.safari, KnownBrowsers.brave])
        XCTAssertEqual(reloaded.hiddenInMenu, ["com.google.chrome"])
        XCTAssertEqual(reloaded.hotkey, Hotkey(keyCode: 45, modifiers: [.command, .shift]))
        XCTAssertEqual(reloaded.iconStyle, .monochrome)
        XCTAssertTrue(reloaded.autoConfirmDialog)
    }

    func testTamperedValuesFallBackToDefaults() {
        defaults.set("/Applications/Evil.app; rm -rf", forKey: "favoriteA")
        defaults.set(["ok.id", "not ok"], forKey: "menuOrder")
        defaults.set(11, forKey: "hotkeyKeyCode")
        defaults.set(0, forKey: "hotkeyModifiers") // no modifier: would swallow typing
        defaults.set("sparkly", forKey: "iconStyle")

        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.favoriteA, KnownBrowsers.chrome)
        XCTAssertEqual(prefs.menuOrder, ["ok.id"])
        XCTAssertEqual(prefs.hotkey, .default)
        XCTAssertEqual(prefs.iconStyle, .color)
    }
}
