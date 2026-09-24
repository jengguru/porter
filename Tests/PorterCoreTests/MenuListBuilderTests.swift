import XCTest
@testable import PorterCore

final class MenuListBuilderTests: XCTestCase {
    private func browser(_ app: FakeWorkspace.App) -> Browser {
        Browser(bundleID: app.bundleID, name: app.name, url: app.url)
    }

    private var installed: [Browser] {
        // Alphabetical, as discovery returns them.
        [Fixtures.brave, Fixtures.chrome, Fixtures.safari].map(browser)
    }

    func testSavedOrderWins() {
        let result = MenuListBuilder.ordered(installed, savedOrder: [KnownBrowsers.safari, KnownBrowsers.chrome, KnownBrowsers.brave])
        XCTAssertEqual(result.map(\.name), ["Safari", "Google Chrome", "Brave Browser"])
    }

    func testNewBrowsersGoLastAndUninstalledEntriesAreIgnored() {
        let result = MenuListBuilder.ordered(installed, savedOrder: [KnownBrowsers.duckDuckGo, KnownBrowsers.safari])
        XCTAssertEqual(result.map(\.name), ["Safari", "Brave Browser", "Google Chrome"])
    }

    func testHiddenBrowsersAreLeftOut() {
        let result = MenuListBuilder.menuItems(installed: installed, savedOrder: [], hidden: [KnownBrowsers.brave], currentDefault: KnownBrowsers.safari)
        XCTAssertEqual(result.map(\.name), ["Google Chrome", "Safari"])
    }

    func testCurrentDefaultIsShownEvenIfHidden() {
        let result = MenuListBuilder.menuItems(installed: installed, savedOrder: [], hidden: [KnownBrowsers.brave.lowercased()], currentDefault: KnownBrowsers.brave)
        XCTAssertEqual(result.map(\.name), ["Brave Browser", "Google Chrome", "Safari"])
    }
}
